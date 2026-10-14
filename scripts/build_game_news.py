#!/usr/bin/env python3
"""Bundle the first two RSS pages of each game News Feed in the saved menu."""

import json
import re
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "BuildContent" / "SeedContent.json"
OUTPUT = ROOT / "BuildContent" / "GameNews.json"
HEADERS = {"User-Agent": "SerenesForestCompanion/1.0 (bundled native game news)"}
CONTENT_NS = "{http://purl.org/rss/1.0/modules/content/}encoded"


class Links(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.href = None
        self.label = []
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.href = dict(attrs).get("href")
            self.label = []

    def handle_data(self, data):
        if self.href is not None:
            self.label.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self.href is not None:
            self.links.append(("".join(self.label).strip(), self.href))
            self.href = None


def read_feed(url):
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(request, timeout=20) as response:
                data = response.read(5_000_001)
            if len(data) > 5_000_000:
                raise ValueError("RSS response exceeded 5 MB")
            return ET.fromstring(data).findall("./channel/item")
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def main():
    pages = json.loads(SOURCE.read_text(encoding="utf-8"))
    feeds = {}
    for page in pages:
        if page["category"] != "Game":
            continue
        parser = Links()
        parser.feed(page["html"])
        for label, url in parser.links:
            parsed = urlparse(url)
            if label.lower() == "news feed" and parsed.hostname == "serenesforest.net" and parsed.path.startswith("/category/"):
                feeds[page["gameSlug"]] = url.rstrip("/") + "/feed/"

    records = {}
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    for slug, feed in feeds.items():
        for number in (1, 2):
            url = feed if number == 1 else feed + "?paged=" + str(number)
            items = read_feed(url)
            for item in items:
                article_url = (item.findtext("link") or "").strip()
                parsed = urlparse(article_url)
                if parsed.hostname != "serenesforest.net" or not re.match(r"^/20\d\d/", parsed.path):
                    continue
                article_url = article_url.split("?", 1)[0]
                content = item.findtext(CONTENT_NS) or item.findtext("description") or ""
                if not content.strip():
                    continue
                published = (item.findtext("pubDate") or "").strip()
                date = datetime.strptime(published, "%a, %d %b %Y %H:%M:%S %z")
                if article_url not in records:
                    records[article_url] = {
                        "url": article_url, "title": (item.findtext("title") or "").strip(),
                        "html": content, "publishedAt": date.astimezone(timezone.utc).isoformat(),
                        "archivedAt": stamp, "gameSlugs": [],
                    }
                records[article_url]["gameSlugs"].append(slug)
            print(f"{slug}: page {number}, {len(items)} entries", flush=True)
    output = sorted(records.values(), key=lambda item: item["publishedAt"], reverse=True)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(output, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Saved {len(output)} articles for {len(feeds)} feeds, {OUTPUT.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
