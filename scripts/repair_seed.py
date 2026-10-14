#!/usr/bin/env python3
"""Fill missing game-guide articles without refreshing saved valid pages."""

import argparse
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from build_seed import GAME_PATHS, LinkParser, SITE, fetch, is_challenge, is_page, make_record, save_records

EXTRA_GAME_PAGES = {
    f"{SITE}/three-houses-support-conversations/": "three-houses",
}


def repair(output: Path, workers: int) -> None:
    records = json.loads(output.read_text(encoding="utf-8"))
    by_url = {record["url"]: record for record in records}
    needed = {url for url, record in by_url.items() if record.get("gameSlug") and is_challenge(record)}

    for slug in GAME_PATHS:
        root = f"{SITE}/{slug}/"
        if root not in by_url or is_challenge(by_url[root]):
            needed.add(root)
            continue
        links = LinkParser(root)
        links.feed(by_url[root]["html"])
        needed.update(url for url in links.links if url.startswith(root) and is_page(url) and
                      (url not in by_url or is_challenge(by_url[url])))
    needed.update(url for url in EXTRA_GAME_PAGES if url not in by_url or is_challenge(by_url[url]))

    print(f"Checking {len(needed)} missing or invalid game pages", flush=True)

    def download(url: str) -> dict:
        document, capture_url = fetch(url)
        record = make_record(url, document, capture_url)
        if url in EXTRA_GAME_PAGES:
            record["category"] = "Guide"
            record["gameSlug"] = EXTRA_GAME_PAGES[url]
        if is_challenge(record) or (len(record["plainText"]) < 20 and "<img" not in record["html"].lower()):
            raise ValueError("no article content")
        return record

    repaired = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        pending = {pool.submit(download, url): url for url in sorted(needed)}
        for future in as_completed(pending):
            url = pending[future]
            try:
                record = future.result()
                if url in by_url:
                    by_url[url].update(record)
                else:
                    records.append(record)
                    by_url[url] = record
                repaired += 1
                print(f"OK {url}", flush=True)
            except Exception as error:
                print(f"SKIP {url}: {error}", flush=True)
    valid_records = [record for record in records if not is_challenge(record)]
    if repaired or len(valid_records) != len(records):
        save_records(valid_records, output)
    print(f"Repaired {repaired}/{len(needed)} pages; saved {len(valid_records)} valid records", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("BuildContent/SeedContent.json"))
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args()
    repair(args.output, max(1, min(args.workers, 12)))
