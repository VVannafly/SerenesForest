#!/usr/bin/env python3
"""Bundle images retained in the native wiki articles, including maps and sprites."""

import base64
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

import build_wiki_images as images

ROOT = Path(__file__).resolve().parent.parent
ARTICLES = ROOT / "BuildContent" / "WikiLibrary.json"
ASSETS = ROOT / "BuildContent" / "WikiAssets.jsonl"


class ImageReferences(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        if tag == "img":
            url = dict(attrs).get("src", "")
            parsed = urlparse(url)
            name = unquote(parsed.path.rsplit("/", 1)[-1])
            if parsed.scheme == "https" and parsed.hostname == "cdn.fireemblemwiki.org":
                self.urls.append((url, name))


def main():
    records = json.loads(ARTICLES.read_text(encoding="utf-8"))
    existing = set()
    with ASSETS.open(encoding="utf-8") as source:
        for line in source:
            existing.add(json.loads(line)["url"])
    references = {}
    for record in records:
        parser = ImageReferences()
        parser.feed(record["html"])
        for url, name in parser.urls:
            references.setdefault(url, (name, record["url"]))
    missing = [(url, url, name) for url, (name, _) in references.items() if url not in existing]
    print(f"Found {len(references)} inline images; {len(missing)} need bundling", flush=True)
    downloaded = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(images.download_image, item): item[0] for item in missing}
        for index, future in enumerate(as_completed(futures), 1):
            result = future.result()
            if result:
                downloaded[result[0]] = result
            if index % 100 == 0 or index == len(futures):
                print(f"Images {index}/{len(futures)}; {len(downloaded)} downloaded", flush=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    with ASSETS.open("a", encoding="utf-8") as output:
        for url in sorted(downloaded):
            _, _, name, mime, data = downloaded[url]
            output.write(json.dumps({"url": url, "title": name,
                                     "sourcePageURL": references[url][1], "mimeType": mime,
                                     "dataBase64": base64.b64encode(data).decode("ascii"),
                                     "archivedAt": stamp}, ensure_ascii=False,
                                    separators=(",", ":")) + "\n")
    print(f"Bundled {len(downloaded)} inline images; {len(missing) - len(downloaded)} unavailable")


if __name__ == "__main__":
    main()
