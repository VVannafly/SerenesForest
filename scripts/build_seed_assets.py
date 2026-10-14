#!/usr/bin/env python3
"""Bundle source images for the app's article database."""

import argparse
import base64
import gzip
import html
import json
import mimetypes
import re
import subprocess
import tempfile
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from build_seed import ARCHIVE, canonical


def image_urls(page: dict) -> list[str]:
    found = []
    for tag in re.findall(r"<img\b[^>]*>", page["html"], re.I):
        source = re.search(r'\bdata-(?:lazy-)?src=["\']([^"\']+)["\']', tag, re.I)
        source = source or re.search(r'\bsrc=["\']([^"\']+)["\']', tag, re.I)
        if not source:
            continue
        raw = source.group(1)
        url = canonical(raw, page["url"])
        if not url and page["url"].startswith("https://wiki.serenesforest.net/"):
            candidate = urllib.parse.urljoin(page["url"], html.unescape(raw))
            parts = urllib.parse.urlsplit(candidate)
            if parts.scheme == "https" and parts.hostname in {"wiki.serenesforest.net", "s3-wiki.serenesforest.net"}:
                url = urllib.parse.urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))
        if url and Path(url).suffix.lower() in (".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".avif") and url not in found:
            found.append(url)
    return found


def fetch_asset(url: str) -> tuple[bytes, str]:
    sources = [(url, 12)]
    if urllib.parse.urlsplit(url).hostname in {"serenesforest.net", "www.serenesforest.net"}:
        sources.append((ARCHIVE + url, 15))
    last_error: Exception | None = None
    for source, timeout in sources:
        try:
            with tempfile.TemporaryDirectory(prefix="serenes-asset-") as directory:
                target = Path(directory) / "asset"
                result = subprocess.run(
                    ["curl", "-f", "-sS", "-L", "--max-time", str(timeout), "-o", str(target), "-w", "%{url_effective}", source],
                    capture_output=True, text=True, timeout=timeout + 5, check=True,
                )
                data = target.read_bytes()
                if data.startswith(b"\x1f\x8b"):
                    data = gzip.decompress(data)
                if not data or len(data) > 8_000_000:
                    raise ValueError("image empty or over 8 MB")
                if data[:100].lower().startswith((b"<!doctype", b"<html")):
                    raise ValueError("server returned HTML")
                return data, result.stdout.strip()
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
            last_error = error
    raise last_error or RuntimeError("unreachable")


def build(page_file: Path, output: Path, limit: int, games_only: bool, all_images: bool,
          workers: int, page_urls: set[str] | None = None) -> None:
    pages = json.loads(page_file.read_text(encoding="utf-8"))
    if page_urls is not None:
        pages = [page for page in pages if page["url"] in page_urls]
    if games_only:
        pages = [page for page in pages if page.get("gameSlug")]
    priority = {"Game": 0, "Guide": 1, "Media": 2, "News": 3, "General": 4}
    pages.sort(key=lambda page: priority.get(page["category"], 5))
    seen: set[str] = set()
    if output.exists():
        with output.open(encoding="utf-8") as saved:
            for line in saved:
                if line.strip():
                    seen.add(json.loads(line)["url"])
    saved_count = len(seen)
    candidates: list[tuple[str, dict]] = []
    page_images = [(page, image_urls(page)) for page in pages]
    image_rounds = range(max((len(images) for _, images in page_images), default=0)) if games_only or all_images else range(2)
    for position in image_rounds:
        for page, images in page_images:
            per_page = 2 if page["category"] in ("Game", "Media") else 1
            if position >= len(images) or (not (games_only or all_images) and position >= per_page):
                continue
            url = images[position]
            if url in seen:
                continue
            seen.add(url)
            candidates.append((url, page))
    print(f"Resuming from {saved_count} images; {len(candidates)} images queued", flush=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=workers) as pool, output.open("a", encoding="utf-8") as saved:
        for offset in range(0, len(candidates), workers * 30):
            if limit and saved_count >= limit:
                break
            batch = candidates[offset:offset + workers * 30]
            futures = {pool.submit(fetch_asset, url): (url, page) for url, page in batch}
            for future in as_completed(futures):
                url, page = futures[future]
                if limit and saved_count >= limit:
                    continue
                try:
                    data, capture_url = future.result()
                    timestamp = re.search(r"/web/(\d{14})", capture_url)
                    record = {
                        "url": url,
                        "title": Path(url).name,
                        "sourcePageURL": page["url"],
                        "mimeType": mimetypes.guess_type(url)[0] or "application/octet-stream",
                        "dataBase64": base64.b64encode(data).decode("ascii"),
                        "archivedAt": timestamp.group(1) if timestamp else page["archivedAt"],
                    }
                    saved.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
                    saved_count += 1
                    print(f"{saved_count:4d} {len(data):7d} {url}", flush=True)
                except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
                    print(f"SKIP {url}: {error}", flush=True)
            saved.flush()
            print(f"Progress: {saved_count} saved, {len(candidates) - offset - len(batch)} queued", flush=True)
    print(f"Saved {saved_count} images to {output} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pages", type=Path, default=Path("BuildContent/SeedContent.json"))
    parser.add_argument("--output", type=Path, default=Path("BuildContent/SeedAssets.jsonl"))
    parser.add_argument("--limit", type=int, default=40, help="maximum images; 0 means all")
    parser.add_argument("--games-only", action="store_true", help="bundle all images referenced by game pages")
    parser.add_argument("--all", action="store_true", help="bundle all images referenced by every saved page")
    parser.add_argument("--page-list", type=Path, help="only bundle images used by these article URLs, one per line")
    parser.add_argument("--workers", type=int, default=2, help="concurrent archive downloads")
    args = parser.parse_args()
    page_urls = set(args.page_list.read_text().splitlines()) if args.page_list else None
    build(args.pages, args.output, args.limit, args.games_only, args.all,
          max(1, min(args.workers, 8)), page_urls)
