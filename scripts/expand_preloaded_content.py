#!/usr/bin/env python3
"""Export the current bundled store and add missing game pages to rebuild it.

The generated JSON files live outside the repository and are only inputs to
build_preloaded_library.py. The application ships the rebuilt SQLite store.
"""

import argparse
import json
import re
import sqlite3
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_seed import LinkParser, classify, fetch, make_record
from build_wiki_library import article_html, clean_extract, request_api


WIKI_CATEGORIES = {
    "three-houses": {
        "Characters": "Playable characters in Fire Emblem: Three Houses",
        "Classes": "Classes in Fire Emblem: Three Houses",
    },
    "engage": {
        "Characters": "Playable characters in Fire Emblem Engage",
        "Classes": "Classes in Fire Emblem Engage",
    },
    "awakening": {"Characters": "Playable characters in Fire Emblem Awakening"},
    "shadow-dragon": {"Characters": "Playable characters in Fire Emblem: Shadow Dragon"},
    "light-and-shadow": {
        "Characters": "Playable characters in Fire Emblem: New Mystery of the Emblem"
    },
}
MECHANICS = {
    "awakening": "Pair Up|Second Seal|SpotPass|Reclassing|Support|Barracks|Weapon triangle|Critical hit|Growth rate|Promotion|Terrain|Movement|Skirmish|Renown|World map|Weapon level",
    "shadow-dragon": "Reclassing|Forging|Online Shop|Weapon triangle|Support|Critical hit|Growth rate|Promotion|Terrain|Movement|Weapon level|Arena|Gaiden chapter",
    "light-and-shadow": "Casual Mode|Base conversations|Reclassing|Support|Gaiden chapter|Weapon triangle|Critical hit|Growth rate|Promotion|Terrain|Movement|Weapon level|Arena",
    "engage": "Emblem Ring|Engage attack|Bond level|Skirmish|Engage (mechanic)",
}
APPLE_EPOCH = 978307200


def timestamp(value):
    return datetime.fromtimestamp((value or 0) + APPLE_EPOCH, timezone.utc).strftime("%Y%m%d%H%M%S")


def iso_timestamp(value):
    return datetime.fromtimestamp((value or 0) + APPLE_EPOCH, timezone.utc).isoformat()


def export(store: Path, directory: Path):
    database = sqlite3.connect(f"file:{store}?mode=ro", uri=True)
    database.row_factory = sqlite3.Row
    memberships = defaultdict(list)
    orders = defaultdict(dict)
    for row in database.execute("SELECT m.ZGAMESLUG, m.ZCHAPTERPOSITION, m.ZCHAPTERLABEL, p.ZURL "
                                "FROM ZWIKIGAMEPAGE m JOIN ZCONTENTPAGE p ON m.ZPAGE=p.Z_PK"):
        memberships[row["ZURL"]].append(row["ZGAMESLUG"])
        if row["ZCHAPTERPOSITION"] is not None:
            orders[row["ZURL"]][row["ZGAMESLUG"]] = {
                "position": row["ZCHAPTERPOSITION"], "label": row["ZCHAPTERLABEL"] or ""
            }
    seed, wiki, news, homes = [], [], [], {}
    known = set()
    for row in database.execute("SELECT ZURL,ZTITLE,ZHTML,ZPLAINTEXT,ZCATEGORY,ZGAMESLUG,"
                                "ZFETCHEDAT,ZNEWSPUBLISHEDAT,ZNEWSGAMESLUGS,ZISDOWNLOADED "
                                "FROM ZCONTENTPAGE"):
        if not row["ZISDOWNLOADED"]:
            continue
        url = row["ZURL"]
        known.add(url)
        record = dict(url=url, title=row["ZTITLE"], html=row["ZHTML"],
                      plainText=row["ZPLAINTEXT"], category=row["ZCATEGORY"],
                      gameSlug=row["ZGAMESLUG"], archivedAt=timestamp(row["ZFETCHEDAT"]))
        if record["category"].startswith("Wiki · "):
            record["gameSlugs"] = sorted(set(memberships[url]))
            if orders[url]:
                record["chapterOrders"] = orders[url]
            wiki.append(record)
        elif record["category"] == "News":
            news.append(dict(url=url, title=record["title"], html=record["html"],
                             archivedAt=record["archivedAt"],
                             publishedAt=iso_timestamp(row["ZNEWSPUBLISHEDAT"] or row["ZFETCHEDAT"]),
                             gameSlugs=[s for s in (row["ZNEWSGAMESLUGS"] or "").split("|") if s]))
        else:
            seed.append(record)
            if record["category"] == "Game":
                homes[record["gameSlug"]] = record
    with (directory / "SeedAssets.jsonl").open("w") as output:
        for row in database.execute("SELECT ZURL,ZTITLE,ZSOURCEPAGEURL,ZMIMETYPE FROM ZCONTENTASSET"):
            output.write(json.dumps(dict(url=row["ZURL"], title=row["ZTITLE"],
                                         sourcePageURL=row["ZSOURCEPAGEURL"],
                                         mimeType=row["ZMIMETYPE"] or ""), ensure_ascii=False) + "\n")
    (directory / "WikiAssets.jsonl").touch()
    database.close()
    return seed, wiki, news, homes, known


def add_site_pages(seed, homes, known):
    candidates = set()
    for home in homes.values():
        parser = LinkParser(home["url"])
        parser.feed(home["html"])
        for url in parser.links:
            if url in known or "/category/" in url:
                continue
            candidates.add(url)
    accepted = 0
    for url in sorted(candidates):
        try:
            document, capture = fetch(url)
            record = make_record(url, document, capture)
            if len(record["plainText"]) < 20 and not (
                record["category"] == "Media" and "<a" in record["html"]
            ):
                continue
            # Shared media and articles retain their own category, while game
            # navigation resolves their URL through the shared-page index.
            seed.append(record)
            known.add(url)
            accepted += 1
        except Exception as error:
            print(f"Skipped site page {url}: {error}", file=sys.stderr, flush=True)
    print(f"Added {accepted} shared article and media pages", flush=True)


def add_wiki_pages(wiki):
    selections = defaultdict(set)
    for slug, groups in WIKI_CATEGORIES.items():
        for group, category in groups.items():
            response = request_api({"action": "query", "list": "categorymembers",
                                    "cmtitle": "Category:" + category, "cmnamespace": 0, "cmlimit": 500})
            for member in response["query"]["categorymembers"]:
                title = member["title"]
                if not title.startswith("List of ") and "(disambiguation)" not in title.lower():
                    selections[title].add((slug, group))
    for slug, titles in MECHANICS.items():
        for title in titles.split("|"):
            selections[title].add((slug, "Mechanics"))

    existing = {record["title"].casefold(): record for record in wiki}
    pending = []
    for title, targets in selections.items():
        if record := existing.get(title.casefold()):
            record["gameSlugs"] = sorted(set(record.get("gameSlugs", [])) |
                                         {slug for slug, _ in targets})
        else:
            pending.append(title)
    def read_article(requested):
        response = request_api({"action": "query", "prop": "extracts|revisions|info",
                                "inprop": "url", "rvprop": "timestamp", "explaintext": 1,
                                "redirects": 1, "titles": requested})["query"]
        page = next(iter(response["pages"].values()), None)
        if not page or "missing" in page:
            return None
        body = clean_extract(page.get("extract", ""))
        if len(body) < 200 or "(disambiguation)" in page["title"].lower():
            return None
        source = page.get("fullurl") or ("https://fireemblemwiki.org/wiki/" +
                                         page["title"].replace(" ", "_"))
        targets = sorted(selections[requested])
        slug, group = targets[0]
        stamp = page.get("revisions", [{}])[0].get("timestamp", "")
        archived = re.sub(r"\D", "", stamp)[:14] if stamp else datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        return dict(url=source, title=page["title"], html=article_html(body, source),
                    plainText=body, category="Wiki · " + group, gameSlug=slug,
                    gameSlugs=sorted({target[0] for target in targets}), archivedAt=archived)

    added = 0
    with ThreadPoolExecutor(max_workers=6) as pool:
        tasks = {pool.submit(read_article, title): title for title in pending}
        for count, task in enumerate(as_completed(tasks), 1):
            try:
                record = task.result()
                if record:
                    wiki.append(record)
                    added += 1
            except Exception as error:
                print(f"Skipped wiki article {tasks[task]}: {error}", file=sys.stderr)
            if count % 25 == 0 or count == len(tasks):
                print(f"Wiki: {count}/{len(tasks)} checked, {added} added", flush=True)
    merged = {}
    for record in wiki:
        if saved := merged.get(record["url"]):
            saved["gameSlugs"] = sorted(set(saved.get("gameSlugs", [])) |
                                        set(record.get("gameSlugs", [])))
            if len(record["plainText"]) > len(saved["plainText"]):
                saved["html"] = record["html"]
                saved["plainText"] = record["plainText"]
        else:
            merged[record["url"]] = record
    wiki[:] = merged.values()
    print(f"Expanded wiki by {added} articles", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--store", type=Path, default=Path("Resources/PreloadedLibrary/Library.store"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--wiki-only", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.wiki_only:
        path = args.output / "WikiLibrary.json"
        wiki = json.loads(path.read_text(encoding="utf-8"))
        add_wiki_pages(wiki)
        path.write_text(json.dumps(wiki, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        return
    seed, wiki, news, homes, known = export(args.store, args.output)
    add_site_pages(seed, homes, known)
    add_wiki_pages(wiki)
    for name, records in (("SeedContent", seed), ("WikiLibrary", wiki), ("GameNews", news)):
        (args.output / f"{name}.json").write_text(
            json.dumps(records, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Ready to rebuild: {len(seed)} site pages, {len(wiki)} wiki pages, {len(news)} news")


if __name__ == "__main__":
    main()
