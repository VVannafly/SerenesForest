#!/usr/bin/env python3
"""Generate temporary article inputs for the bundled SwiftData library.

Run from the SerenesForest directory. build_preloaded_library.py imports the
generated JSON into the distributable store before the app is built.
"""

import argparse
import gzip
import html
import json
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
from datetime import datetime, timezone
from collections import deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from html.parser import HTMLParser
from pathlib import Path


SITE = "https://serenesforest.net"
ARCHIVE = "https://web.archive.org/web/20261001id_/"
GAME_PATHS = [
    "shadow-dragon-and-blade-of-light", "gaiden", "mystery-of-the-emblem",
    "genealogy-of-the-holy-war", "thracia-776", "binding-blade",
    "blazing-sword", "the-sacred-stones", "path-of-radiance", "radiant-dawn",
    "shadow-dragon", "light-and-shadow", "awakening", "fire-emblem-fates",
    "fire-emblem-echoes-shadows-valentia", "three-houses", "engage",
    "fortunes-weave", "fire-emblem-heroes",
]
ROOTS = [SITE + "/"] + [f"{SITE}/{path}/" for path in GAME_PATHS] + [
    f"{SITE}/general/", f"{SITE}/gallery/", f"{SITE}/music/", f"{SITE}/videos/",
]
ASSET_EXTENSIONS = {"jpg", "jpeg", "png", "gif", "webp", "svg", "pdf", "mp3", "m4a", "ogg", "mp4", "webm", "zip"}


def save_records(records: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + ".tmp")
    temporary.write_text(json.dumps(records, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    temporary.replace(output)


def canonical(raw: str, base: str = SITE + "/") -> str | None:
    url = urllib.parse.urljoin(base, html.unescape(raw))
    parsed = urllib.parse.urlsplit(url)
    if parsed.hostname not in ("serenesforest.net", "www.serenesforest.net") or parsed.scheme not in ("http", "https"):
        return None
    path = parsed.path or "/"
    if not path.endswith("/") and not Path(path).suffix:
        path += "/"
    lower = path.lower()
    if any(lower.startswith(prefix) for prefix in ("/wiki", "/forums", "/wp-admin", "/wp-json", "/wp-login", "/cdn-cgi", "/xmlrpc")):
        return None
    if lower.endswith("/feed/"):
        return None
    return SITE + path


def is_page(url: str) -> bool:
    path = urllib.parse.urlsplit(url).path.lower()
    suffix = Path(path).suffix.removeprefix(".")
    return not path.startswith("/wp-content/") and suffix not in ASSET_EXTENSIONS and suffix in ("", "html", "htm")


def classify(url: str) -> tuple[str, str | None]:
    path = urllib.parse.urlsplit(url).path
    if url == SITE + "/" or re.match(r"^/20\d\d/", path):
        return "News", None
    for slug in GAME_PATHS:
        if path.startswith(f"/{slug}/"):
            return ("Game" if path == f"/{slug}/" else "Guide"), slug
    if any(path.startswith(prefix) for prefix in ("/gallery/", "/music/", "/videos/", "/scribbles/")):
        return "Media", None
    return "General", None


class LinkParser(HTMLParser):
    def __init__(self, base: str):
        super().__init__(convert_charrefs=True)
        self.base = base
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return
        raw = dict(attrs).get("href")
        if raw:
            url = canonical(raw, self.base)
            if url and is_page(url) and url not in self.links:
                self.links.append(url)


class TextParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.skip = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in ("script", "style", "noscript"):
            self.skip += 1
        if tag in ("br", "p", "div", "tr", "li", "h1", "h2", "h3"):
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in ("script", "style", "noscript") and self.skip:
            self.skip -= 1
        if tag in ("p", "div", "tr", "li", "h1", "h2", "h3"):
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        if not self.skip:
            self.parts.append(data)

    def text(self) -> str:
        value = "".join(self.parts)
        value = re.sub(r"[ \t]+", " ", value)
        return re.sub(r"\n{3,}", "\n\n", value).strip()


def entry_content(document: str) -> str:
    opening = re.search(r'<div\b[^>]*class=["\'][^"\']*\b(?:entry|mw-parser-output)\b[^"\']*["\'][^>]*>', document, re.I)
    if not opening:
        main = re.search(r"<main\b[^>]*>(.*?)</main>", document, re.I | re.S)
        return main.group(1) if main else document
    depth = 1
    for tag in re.finditer(r"</?div\b[^>]*>", document[opening.end():], re.I):
        depth += -1 if tag.group().startswith("</") else 1
        if depth == 0:
            return document[opening.end():opening.end() + tag.start()]
    return document[opening.end():]


def fetch(url: str) -> tuple[str, str]:
    sources = [(url, 12, 1), (url.replace("https://", "http://", 1), 8, 1), (ARCHIVE + url, 12, 2)]
    last_error: Exception | None = None
    for source, timeout, attempts in sources:
        for attempt in range(attempts):
            try:
                with tempfile.TemporaryDirectory(prefix="serenes-seed-") as directory:
                    target = Path(directory) / "page.html"
                    result = subprocess.run(
                        ["curl", "-f", "-sS", "-L", "--max-time", str(timeout), "-o", str(target), "-w", "%{url_effective}", source],
                        capture_output=True, text=True, timeout=timeout + 5, check=True,
                    )
                    data = target.read_bytes()
                    if len(data) > 5_000_000:
                        raise ValueError("page exceeds 5 MB")
                    if data.startswith(b"\x1f\x8b"):
                        data = gzip.decompress(data)
                    document = data.decode("utf-8", "replace")
                    lowered = document.lower()
                    if ("<html" not in lowered or "<title>just a moment" in lowered or
                            "<title>one moment, please" in lowered or
                            "please wait while your request is being verified" in lowered or
                            "checking your browser before accessing" in lowered):
                        raise ValueError("not an article")
                    return document, result.stdout.strip()
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, TimeoutError, ValueError) as error:
                last_error = error
                if attempt + 1 < attempts:
                    print(f"RETRY {url}: {error}", file=sys.stderr, flush=True)
                    time.sleep(1 + attempt)
    raise last_error or RuntimeError("unreachable")


def make_record(url: str, document: str, capture_url: str) -> dict:
    title_match = re.search(r'<h2[^>]*class=["\'][^"\']*page-title[^"\']*["\'][^>]*>(.*?)</h2>', document, re.I | re.S)
    if not title_match:
        title_match = re.search(r"<h1[^>]*>(.*?)</h1>", document, re.I | re.S)
    if not title_match:
        title_match = re.search(r"<title[^>]*>(.*?)</title>", document, re.I | re.S)
    title_parser = TextParser()
    title_parser.feed(title_match.group(1) if title_match else url.rsplit("/", 2)[-2])
    content = entry_content(document)
    content = re.sub(r"<script\b[^>]*>.*?</script>", "", content, flags=re.I | re.S)
    parser = TextParser()
    parser.feed(content)
    category, slug = classify(url)
    stamp = re.search(r"/web/(\d{14})", capture_url)
    return {
        "url": url,
        "title": title_parser.text().removesuffix(" | Serenes Forest"),
        "html": content,
        "plainText": parser.text(),
        "category": category,
        "gameSlug": slug,
        "archivedAt": stamp.group(1) if stamp else datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S"),
    }


def is_challenge(record: dict) -> bool:
    return record["title"].strip().lower().startswith(("one moment, please", "just a moment"))


def build(limit: int | None, output: Path) -> None:
    records: list[dict] = [record for record in json.loads(output.read_text(encoding="utf-8"))
                           if not is_challenge(record)] if output.exists() else []
    fetched: set[str] = {record["url"] for record in records}
    root_links: dict[str, list[str]] = {}
    for record in records:
        links = LinkParser(record["url"])
        links.feed(record["html"])
        root_links[record["url"]] = links.links
    if SITE + "/" in fetched:
        try:
            document, _ = fetch(SITE + "/")
            links = LinkParser(SITE + "/")
            links.feed(document)
            root_links[SITE + "/"] = links.links
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError, OSError):
            pass
    if records:
        print(f"Resuming from {len(records)} saved pages", flush=True)

    def add(url: str) -> None:
        if url in fetched or (limit is not None and len(records) >= limit):
            return
        fetched.add(url)
        try:
            document, capture_url = fetch(url)
            record = make_record(url, document, capture_url)
            if is_challenge(record):
                return
            if len(record["plainText"]) < 20:
                raise ValueError("empty article")
            records.append(record)
            save_records(records, output)
            links = LinkParser(url)
            links.feed(document)
            root_links[url] = links.links
            print(f"{len(records):4d} {record['category']:7s} {url}", flush=True)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, TimeoutError, ValueError, OSError) as error:
            print(f"SKIP {url}: {error}", file=sys.stderr, flush=True)
        time.sleep(1.0)

    for root in ROOTS:
        add(root)

    queue: deque[str] = deque()
    guides_by_game = []
    for slug in GAME_PATHS:
        root = f"{SITE}/{slug}/"
        guides_by_game.append([url for url in root_links.get(root, []) if url.startswith(root) and url != root])
    # Interleave games so the bundled snapshot represents the whole series.
    for guides in guides_by_game:
        queue.extend(guides[:2])
    queue.extend(url for url in root_links.get(SITE + "/", []) if re.match(rf"{SITE}/20\d\d/", url))
    for root in ROOTS[-3:] + ROOTS[-4:-3]:
        queue.extend(url for url in root_links.get(root, [])[:5] if url != root)  # media, then general
    for guides in guides_by_game:
        queue.extend(guides[2:])
    queue.extend(root_links.get(SITE + "/", []))

    while queue and (limit is None or len(records) < limit):
        url = queue.popleft()
        before = len(records)
        add(url)
        if limit is None and len(records) > before:
            queue.extend(root_links.get(url, []))

    save_records(records, output)
    print(f"Saved {len(records)} pages to {output} ({output.stat().st_size:,} bytes)")


def build_games(output: Path, workers: int) -> None:
    """Save every game page reachable from the latest game indexes."""
    records: list[dict] = [record for record in json.loads(output.read_text(encoding="utf-8"))
                           if not is_challenge(record)] if output.exists() else []
    by_url = {record["url"]: record for record in records}
    for slug in GAME_PATHS:
        root = f"{SITE}/{slug}/"
        if root in by_url:
            try:
                document, source = fetch(root)
                refreshed = make_record(root, document, source)
                if is_challenge(refreshed):
                    raise ValueError("browser verification page")
                by_url[root].update(refreshed)
                print(f"UPDATED index {root}", flush=True)
                time.sleep(0.25)
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, TimeoutError, ValueError, OSError) as error:
                print(f"KEEP saved index {root}: {error}", file=sys.stderr, flush=True)
    save_records(records, output)
    failed: set[str] = set()
    queued: set[str] = set(by_url)
    queue: deque[str] = deque()

    def game_link(url: str) -> bool:
        return is_page(url) and any(url.startswith(f"{SITE}/{slug}/") for slug in GAME_PATHS)

    def enqueue_links(record: dict) -> None:
        parser = LinkParser(record["url"])
        parser.feed(record["html"])
        for link in parser.links:
            if game_link(link) and link not in queued and link not in failed:
                queued.add(link)
                queue.append(link)

    root_candidates: list[list[str]] = []
    for slug in GAME_PATHS:
        root = f"{SITE}/{slug}/"
        if root not in by_url:
            queued.add(root)
            queue.append(root)
        else:
            parser = LinkParser(root)
            parser.feed(by_url[root]["html"])
            root_candidates.append([link for link in parser.links if game_link(link)])
    for position in range(max(map(len, root_candidates), default=0)):
        for candidates in root_candidates:
            if position < len(candidates):
                link = candidates[position]
                if link not in queued:
                    queued.add(link)
                    queue.append(link)
    # Existing article links expose deeper chapters and tables beyond the index.
    for record in records:
        if game_link(record["url"]):
            enqueue_links(record)

    print(f"Resuming from {len(records)} pages; {len(queue)} game pages queued", flush=True)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        while queue:
            batch = [queue.popleft() for _ in range(min(workers * 3, len(queue)))]
            futures = {pool.submit(fetch, url): url for url in batch}
            for future in as_completed(futures):
                url = futures[future]
                try:
                    document, capture_url = future.result()
                    record = make_record(url, document, capture_url)
                    if is_challenge(record):
                        continue
                    if not record["plainText"] and "<img" not in record["html"].lower():
                        raise ValueError("empty article")
                    by_url[url] = record
                    records.append(record)
                    enqueue_links(record)
                    print(f"{len(records):4d} {record['gameSlug'] or '-':33s} {url}", flush=True)
                except (subprocess.CalledProcessError, subprocess.TimeoutExpired, TimeoutError, ValueError, OSError) as error:
                    failed.add(url)
                    print(f"SKIP {url}: {error}", file=sys.stderr, flush=True)
                time.sleep(0.25)
            save_records(records, output)
            print(f"Progress: {len(records)} saved, {len(queue)} queued, {len(failed)} unavailable", flush=True)
    print(f"Saved {len(records)} pages to {output} ({output.stat().st_size:,} bytes); {len(failed)} unavailable")


if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser()
    argument_parser.add_argument("--limit", type=int, default=100, help="max pages to bundle; use 0 to follow all links")
    argument_parser.add_argument("--output", type=Path, default=Path("BuildContent/SeedContent.json"))
    argument_parser.add_argument("--games-only", action="store_true", help="archive every linked page within each game")
    argument_parser.add_argument("--workers", type=int, default=4, help="concurrent archive downloads for --games-only")
    args = argument_parser.parse_args()
    if args.games_only:
        build_games(args.output, max(1, min(args.workers, 8)))
    else:
        build(None if args.limit == 0 else args.limit, args.output)
