#!/usr/bin/env python3
"""Bundle article thumbnails from Fire Emblem Wiki into the native library."""

import base64
import html
import json
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote, urlencode, urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
ARTICLES = ROOT / "BuildContent" / "WikiLibrary.json"
ASSETS = ROOT / "BuildContent" / "WikiAssets.jsonl"
API = "https://fireemblemwiki.org/w/api.php"
HEADERS = {"User-Agent": "SerenesForestCompanion/1.0 (attributed wiki thumbnail bundle)"}
LEAD = re.compile(r'<figure class="wiki-lead">.*?</figure>\s*', re.DOTALL)


def request_json(params):
    url = API + "?" + urlencode({"format": "json", **params})
    for attempt in range(3):
        try:
            with urlopen(Request(url, headers=HEADERS), timeout=20) as response:
                return json.load(response)
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def image_metadata(titles):
    found = {}
    for start in range(0, len(titles), 40):
        batch = titles[start:start + 40]
        query = request_json({"action": "query", "prop": "pageimages", "pithumbsize": 320,
                              "titles": "|".join(batch)})["query"]
        for page in query["pages"].values():
            thumb = page.get("thumbnail")
            if thumb and page.get("pageimage"):
                found[page["title"]] = (thumb["source"], page["pageimage"])
        print(f"Image metadata {min(start + 40, len(titles))}/{len(titles)}", flush=True)
    return found


def download_image(item):
    title, image_url, file_title = item
    parsed = urlparse(image_url)
    if parsed.scheme != "https" or parsed.hostname != "cdn.fireemblemwiki.org":
        return None
    for attempt in range(3):
        try:
            with urlopen(Request(image_url, headers=HEADERS), timeout=20) as response:
                mime = response.headers.get_content_type()
                length = int(response.headers.get("Content-Length", "0"))
                if response.status != 200 or not mime.startswith("image/") or length > 1_500_000:
                    return None
                data = response.read(1_500_001)
                if not data or len(data) > 1_500_000:
                    return None
                return title, image_url, file_title, mime, data
        except Exception:
            if attempt == 2:
                return None
            time.sleep(attempt + 1)


def main():
    articles = json.loads(ARTICLES.read_text(encoding="utf-8"))
    titles = [article["title"] for article in articles]
    metadata = image_metadata(titles)
    jobs = [(title, *metadata[title]) for title in titles if title in metadata]
    downloaded = {}
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {pool.submit(download_image, job): job[0] for job in jobs}
        for index, future in enumerate(as_completed(futures), 1):
            result = future.result()
            if result:
                downloaded[result[0]] = result
            if index % 40 == 0:
                print(f"Images {index}/{len(jobs)} downloaded", flush=True)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    written_urls = set()
    ASSETS.parent.mkdir(parents=True, exist_ok=True)
    with ASSETS.open("w", encoding="utf-8") as output:
        for article in articles:
            article["html"] = LEAD.sub("", article["html"])
            result = downloaded.get(article["title"])
            if not result:
                continue
            _, image_url, file_title, mime, data = result
            file_page = "https://fireemblemwiki.org/wiki/File:" + quote(file_title.replace(" ", "_"), safe="():_-.')")
            image_name = file_title.rsplit(".", 1)[0].replace("_", " ")
            figure = (f'<figure class="wiki-lead"><img src="{html.escape(image_url, quote=True)}" '
                      f'alt="{html.escape(image_name, quote=True)}">'
                      f'<figcaption>Image: <a href="{html.escape(file_page, quote=True)}">'
                      'Fire Emblem Wiki file details</a></figcaption></figure>')
            article["html"] = article["html"].replace("</p>", "</p>" + figure, 1)
            if image_url in written_urls:
                continue
            written_urls.add(image_url)
            output.write(json.dumps({
                "url": image_url, "title": image_name, "sourcePageURL": article["url"],
                "mimeType": mime, "dataBase64": base64.b64encode(data).decode("ascii"),
                "archivedAt": stamp,
            }, ensure_ascii=False, separators=(",", ":")) + "\n")
    ARTICLES.write_text(json.dumps(articles, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Bundled {len(written_urls)} images for {len(downloaded)} of {len(articles)} articles; {ASSETS.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
