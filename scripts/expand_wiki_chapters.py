#!/usr/bin/env python3
"""Add game chapter and act articles to the bundled native wiki snapshot.

Existing full articles are kept. Category membership is recorded for every game
that shares an article, so remakes can show the same source page in both guides.
"""

import base64
import html
import json
import re
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote, unquote, urljoin, urlparse

import build_wiki_full_content as full
import build_wiki_images as images
import build_wiki_library as wiki

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "BuildContent" / "WikiLibrary.json"
ASSETS = ROOT / "BuildContent" / "WikiAssets.jsonl"

CATEGORIES = dict(wiki.CHAPTER_CATEGORIES)
CATEGORIES.update({
    "gaiden": "Acts of Fire Emblem Gaiden",
    "fire-emblem-echoes-shadows-valentia": "Acts of Fire Emblem Echoes: Shadows of Valentia",
})
ACT_GAMES = {"gaiden", "fire-emblem-echoes-shadows-valentia"}


def members(category):
    result = []
    continuation = {}
    while True:
        data = wiki.request_api({"action": "query", "list": "categorymembers",
                                 "cmtitle": "Category:" + category, "cmnamespace": 0,
                                 "cmlimit": 500, **continuation})
        result.extend(item["title"] for item in data["query"]["categorymembers"])
        continuation = data.get("continue", {})
        if not continuation:
            return result


def selected_titles():
    games = defaultdict(set)
    for slug, category in CATEGORIES.items():
        if not category.startswith("Acts of "):
            category = "Chapters of " + category
        titles = members(category)
        # Heroes has an open-ended live-service chapter catalog. Keep a useful
        # bounded snapshot and its index; the other games include all chapters.
        if slug == "fire-emblem-heroes":
            titles = [title for title in titles if title.startswith("List of ")] + [
                title for title in titles if not title.startswith("List of ")][:48]
        for title in titles:
            games[title].add(slug)
        print(f"{slug}: {len(titles)} chapter/act pages", flush=True)
    return games


def metadata(titles):
    pages = {}
    for start in range(0, len(titles), 35):
        batch = titles[start:start + 35]
        data = wiki.request_api({"action": "query", "prop": "revisions|info", "inprop": "url",
                                 "rvprop": "timestamp", "redirects": 1,
                                 "titles": "|".join(batch)})["query"]
        aliases = {item["from"]: item["to"] for item in data.get("redirects", [])}
        normalized = {item["from"]: item["to"] for item in data.get("normalized", [])}
        by_title = {page["title"]: page for page in data["pages"].values() if "missing" not in page}
        for title in batch:
            resolved = normalized.get(title, title)
            resolved = aliases.get(resolved, resolved)
            page = by_title.get(resolved)
            if page:
                pages[title] = page
    return pages


def make_article(page, slugs):
    title = page["title"]
    source = page.get("fullurl") or "https://fireemblemwiki.org/wiki/" + quote(title.replace(" ", "_"), safe="/:()'-,")
    stamp = page.get("revisions", [{}])[0].get("timestamp", "")
    modified = datetime.fromisoformat(stamp.replace("Z", "+00:00")) if stamp else datetime.now(timezone.utc)
    record = {"url": source, "title": title, "gameSlug": sorted(slugs)[0],
              "gameSlugs": sorted(slugs),
              "category": "Wiki · Acts" if set(slugs) <= ACT_GAMES else "Wiki · Chapters",
              "archivedAt": modified.strftime("%Y%m%d%H%M%S"), "html": "", "plainText": ""}
    parts = full.fetch(record)
    appendix = wiki.article_html("", source)
    record["html"] = "\n".join(parts) + "\n" + appendix
    record["plainText"] = html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", " ".join(parts)))).strip()
    return record


def add_images(records):
    if not records:
        return
    metadata = images.image_metadata([record["title"] for record in records])
    existing_urls = set()
    if ASSETS.exists():
        with ASSETS.open(encoding="utf-8") as source:
            for line in source:
                existing_urls.add(json.loads(line)["url"])
    jobs = [(title, *item) for title, item in metadata.items()]
    downloaded = {}
    with ThreadPoolExecutor(max_workers=6) as pool:
        for future in as_completed([pool.submit(images.download_image, job) for job in jobs]):
            result = future.result()
            if result:
                downloaded[result[0]] = result
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    with ASSETS.open("a", encoding="utf-8") as output:
        for record in records:
            result = downloaded.get(record["title"])
            if not result:
                continue
            _, image_url, file_title, mime, data = result
            file_page = "https://fireemblemwiki.org/wiki/File:" + quote(file_title.replace(" ", "_"), safe="():_-.')")
            image_name = file_title.rsplit(".", 1)[0].replace("_", " ")
            figure = (f'<figure class="wiki-lead"><img src="{html.escape(image_url, quote=True)}" '
                      f'alt="{html.escape(image_name, quote=True)}">'
                      f'<figcaption>Image: <a href="{html.escape(file_page, quote=True)}">'
                      'Fire Emblem Wiki file details</a></figcaption></figure>')
            record["html"] = record["html"].replace("</p>", "</p>" + figure, 1)
            if image_url not in existing_urls:
                existing_urls.add(image_url)
                output.write(json.dumps({"url": image_url, "title": image_name,
                                         "sourcePageURL": record["url"], "mimeType": mime,
                                         "dataBase64": base64.b64encode(data).decode("ascii"),
                                         "archivedAt": stamp}, ensure_ascii=False,
                                        separators=(",", ":")) + "\n")
    print(f"Added artwork to {sum(record['title'] in downloaded for record in records)} new articles", flush=True)


def chapter_url_key(url):
    return unquote(urlparse(urljoin("https://fireemblemwiki.org", url)).path).replace("_", " ").casefold()


def natural_title_key(title):
    return tuple(int(part) if part.isdigit() else part
                 for part in re.split(r"(\d+)", title.casefold()))


def add_chapter_orders(records):
    """Read the game's chapter index, including route labels and side chapters."""
    for slug, category in CATEGORIES.items():
        acts = category.startswith("Acts of ")
        title = ("List of acts in " + category[len("Acts of "):]) if acts else ("List of chapters in " + category)
        relevant = [record for record in records
                    if record["category"] in {"Wiki · Chapters", "Wiki · Acts"} and
                    slug in (record.get("gameSlugs") or ([record["gameSlug"]] if record["gameSlug"] else []))]
        by_key = {chapter_url_key(record["url"]): record for record in relevant}
        index = next((record for record in relevant if record["title"] == title), None)
        try:
            parsed = wiki.request_api({"action": "parse", "page": title, "prop": "text"})["parse"]["text"]["*"]
        except (KeyError, ValueError):
            print(f"No chapter index for {slug}", flush=True)
            continue
        # Rebuild this game's positions: an older snapshot may have stale
        # labels or alphabetical map ordering even when the index is current.
        for record in relevant:
            record.get("chapterOrders", {}).pop(slug, None)
        if index:
            index.setdefault("chapterOrders", {})[slug] = {"position": 0, "label": "Contents"}
        reader = full.WikiDOM()
        reader.feed(parsed)
        assigned = {}
        for row in reader.root.descendants("tr"):
            cells = [cell for cell in row.children if cell.tag in {"td", "th"}]
            if len(cells) < 2:
                continue
            label = full.compact(cells[0].text().replace("\u00a0", " "))
            if not label or len(label) > 65:
                continue
            for link in row.descendants("a"):
                record = by_key.get(chapter_url_key(link.attrs.get("href", "")))
                if record and record["url"] not in assigned:
                    assigned[record["url"]] = (len(assigned) + 1) * 1000
                    record.setdefault("chapterOrders", {})[slug] = {
                        "position": assigned[record["url"]], "label": label}
                    break
        # Acts contain ordered links to their individual battles. Keep that
        # source order instead of sorting map names alphabetically.
        for parent_record in relevant:
            parent_order = parent_record.get("chapterOrders", {}).get(slug)
            if not parent_order or parent_order["position"] == 0:
                continue
            children = [record for record in relevant
                        if record["title"].startswith(parent_record["title"] + "/") and
                        slug not in record.get("chapterOrders", {})]
            if not children:
                continue
            linked = [chapter_url_key(html.unescape(match.group(1))) for match in
                      re.finditer(r'<a href="([^"]+)"', parent_record["html"])]
            first_occurrence = {}
            for position, key in enumerate(linked):
                first_occurrence.setdefault(key, position)
            children.sort(key=lambda record: (first_occurrence.get(chapter_url_key(record["url"]), 1_000_000),
                                              natural_title_key(record["title"])))
            for offset, record in enumerate(children, 1):
                record.setdefault("chapterOrders", {})[slug] = {
                    "position": parent_order["position"] + offset,
                    "label": parent_order["label"]}
        remaining = sorted((record for record in relevant if slug not in record.get("chapterOrders", {})),
                           key=lambda item: natural_title_key(item["title"]))
        for offset, record in enumerate(remaining):
            record.setdefault("chapterOrders", {})[slug] = {"position": 1_000_000 + offset, "label": ""}
        print(f"{slug}: {len(assigned)}/{len(relevant)} indexed chapters", flush=True)


def main():
    records = json.loads(LIBRARY.read_text(encoding="utf-8"))
    by_url = {record["url"]: record for record in records}
    curated = defaultdict(set)
    for slug, groups in wiki.ARTICLES.items():
        if slug is not None:
            for names in groups.values():
                for title in names.split("|"):
                    curated[title].add(slug)
    for requested, page in metadata(list(curated)).items():
        url = page.get("fullurl") or "https://fireemblemwiki.org/wiki/" + quote(page["title"].replace(" ", "_"), safe="/:()'-,")
        if url in by_url:
            record = by_url[url]
            slugs = set(record.get("gameSlugs") or ([record["gameSlug"]] if record["gameSlug"] else []))
            slugs.update(curated[requested])
            record["gameSlugs"] = sorted(slugs)
    titles = selected_titles()
    pages = metadata(list(titles))
    pending = {}
    for requested, slugs in titles.items():
        page = pages.get(requested)
        if not page:
            continue
        url = page.get("fullurl") or "https://fireemblemwiki.org/wiki/" + quote(page["title"].replace(" ", "_"), safe="/:()'-,")
        if url in by_url:
            record = by_url[url]
            combined = set(record.get("gameSlugs") or ([record["gameSlug"]] if record["gameSlug"] else []))
            combined.update(slugs)
            record["gameSlugs"] = sorted(combined)
            if record["category"] == "Wiki · Chapters" and combined <= ACT_GAMES:
                record["category"] = "Wiki · Acts"
        else:
            if url in pending:
                pending[url][1].update(slugs)
            else:
                pending[url] = (page, set(slugs))
    new_records = []
    failures = []
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {pool.submit(make_article, page, slugs): page["title"] for page, slugs in pending.values()}
        for index, future in enumerate(as_completed(futures), 1):
            try:
                new_records.append(future.result())
            except Exception as error:
                failures.append((futures[future], str(error)))
            if index % 50 == 0 or index == len(futures):
                print(f"Parsed {index}/{len(futures)}, failed {len(failures)}", flush=True)
    add_images(new_records)
    records.extend(new_records)
    add_chapter_orders(records)
    records.sort(key=lambda item: ((item["gameSlug"] or "~"), item["category"], item["title"]))
    temp = LIBRARY.with_suffix(".json.tmp")
    temp.write_text(json.dumps(records, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    temp.replace(LIBRARY)
    print(f"Saved {len(records)} articles (+{len(new_records)}), {len(failures)} unavailable")
    if failures:
        print("Unavailable:", failures)


if __name__ == "__main__":
    main()
