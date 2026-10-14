#!/usr/bin/env python3
"""Bundle the game guides linked from Serenes Forest's spin-off wiki indexes."""

import argparse
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlsplit

from build_seed import make_record, save_records


WIKI = "https://wiki.serenesforest.net/index.php/"
SPIN_OFFS = {
    "fire-emblem-warriors": "Fire_Emblem_Warriors",
    "warriors-three-hopes": "Fire_Emblem_Warriors:_Three_Hopes",
    "tokyo-mirage-sessions": "Tokyo_Mirage_Sessions_♯FE",
}


def wiki_url(title: str) -> str:
    return WIKI + quote(unquote(title), safe="/:_()'-")


def get(url: str) -> str:
    result = subprocess.run(
        ["curl", "-f", "-sS", "-L", "--max-time", "15", "--max-filesize", "5000000", url],
        capture_output=True, timeout=20, check=True,
    )
    return result.stdout.decode("utf-8", "replace")


class WikiLinks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.urls: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if tag == "div" and "mw-parser-output" in (attributes.get("class") or ""):
            self.depth = 1
        elif tag == "div" and self.depth:
            self.depth += 1
        if not self.depth or tag != "a":
            return
        href = attributes.get("href") or ""
        if not href.startswith("/index.php?title="):
            return
        query = parse_qs(urlsplit(href.replace("&amp;", "&")).query)
        if "action" in query or "redlink" in query:
            return
        title = query.get("title", [""])[0]
        if not title or title.split(":", 1)[0] in {"User", "Category", "Special", "Talk", "Template", "File"}:
            return
        url = wiki_url(title)
        if url not in self.urls:
            self.urls.append(url)

    def handle_endtag(self, tag: str) -> None:
        if tag == "div" and self.depth:
            self.depth -= 1


def build(output: Path, workers: int) -> None:
    records = json.loads(output.read_text(encoding="utf-8"))
    by_url = {record["url"]: record for record in records}
    links_by_slug: dict[str, list[str]] = {}
    for slug, title in SPIN_OFFS.items():
        root = wiki_url(title)
        document = get(root)
        links = WikiLinks()
        links.feed(document)
        links_by_slug[slug] = links.urls
        record = make_record(root, document, root)
        record["category"] = "Game"
        record["gameSlug"] = slug
        record["archivedAt"] = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        if root in by_url:
            by_url[root].update(record)
        else:
            records.append(record)
            by_url[root] = record
        print(f"{slug}: {len(links.urls)} linked guide pages", flush=True)

    needed = {url: slug for slug, links in links_by_slug.items() for url in links if url not in by_url}

    def download(url: str, slug: str) -> dict:
        document = get(url)
        if "mw-parser-output" not in document or "There is currently no text in this page" in document:
            raise ValueError("wiki page has no article")
        record = make_record(url, document, url)
        if len(record["plainText"]) < 20:
            raise ValueError("wiki page has no text")
        record["category"] = "Guide"
        record["gameSlug"] = slug
        record["archivedAt"] = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        return record

    with ThreadPoolExecutor(max_workers=workers) as pool:
        pending = {pool.submit(download, url, slug): (url, slug) for url, slug in needed.items()}
        for future in as_completed(pending):
            url, slug = pending[future]
            try:
                record = future.result()
                records.append(record)
                by_url[url] = record
                print(f"OK {slug}: {url}", flush=True)
            except Exception as error:
                print(f"SKIP {slug}: {url}: {error}", flush=True)
    save_records(records, output)
    for slug in SPIN_OFFS:
        print(f"{slug}: {sum(record.get('gameSlug') == slug for record in records)} saved pages", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("BuildContent/SeedContent.json"))
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args()
    build(args.output, max(1, min(args.workers, 12)))
