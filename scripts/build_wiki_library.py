#!/usr/bin/env python3
"""Build the curated, attributed Fire Emblem Wiki article snapshot.

The wiki is GNU FDL 1.3 licensed. Keep its license text in the app bundle and
the original article and history links beside every excerpt. All requests have
an explicit timeout; this script is run when updating the bundled snapshot.
"""

import html
import json
import re
import time
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "BuildContent" / "WikiLibrary.json"
API = "https://fireemblemwiki.org/w/api.php"
HEADERS = {"User-Agent": "SerenesForestCompanion/1.0 (bundled wiki content; source attribution in app)"}

# These are article titles, not guessed page URLs. Missing and empty articles
# are rejected by the MediaWiki response validation below.
ARTICLES = {
    "shadow-dragon-and-blade-of-light": {
        "Characters": "Marth|Caeda|Jagen|Tiki|Medeus|Nyna|Camus",
        "World": "Archanea|Altea|Dolhr|Falchion",
        "Mechanics": "Shadow Dragon & the Blade of Light/Gameplay|Manakete",
    },
    "gaiden": {
        "Characters": "Alm|Celica|Mila|Duma|Rudolf|Berkut",
        "World": "Valentia|Zofia|Rigel",
        "Mechanics": "Mila's Turnwheel|Combat arts",
    },
    "mystery-of-the-emblem": {
        "Characters": "Hardin|Minerva|Kris|Elice|Gharnef",
        "World": "War of Heroes|Fire Emblem (Archanea)|Fane of Raman",
        "Mechanics": "Star shards|Dismounting",
    },
    "genealogy-of-the-holy-war": {
        "Characters": "Sigurd|Seliph|Deirdre|Arvis|Quan|Ethlyn|Julia",
        "World": "Jugdral|Grannvale|Loptous|Twelve Crusaders",
        "Mechanics": "Holy Blood|Inheritance|Arena",
    },
    "thracia-776": {
        "Characters": "Leif|Nanna|Finn|Eyvel|Raydrik|August",
        "World": "Munster District|Thracia|Liberation Army",
        "Mechanics": "Capture|Fatigue|Movement stars",
    },
    "binding-blade": {
        "Characters": "Roy|Lilina|Guinivere|Zephiel|Fae|Idunn",
        "World": "Elibe|Bern|Lycia|The Scouring|The Binding Blade (weapon)",
        "Mechanics": "Divine weapons|Support",
    },
    "blazing-sword": {
        "Characters": "Lyn|Eliwood|Hector|Ninian|Nergal|Athos",
        "World": "Sacae|Caelin|Black Fang|Dragon's Gate",
        "Mechanics": "Tactician|Affinity",
    },
    "the-sacred-stones": {
        "Characters": "Eirika|Ephraim|Lyon|Myrrh|Seth|L'Arachel",
        "World": "Magvel|Grado|Renais|The Sacred Stones (objects)",
        "Mechanics": "Creature Campaign|Tower of Valni|Branching promotion",
    },
    "path-of-radiance": {
        "Characters": "Ike|Elincia|Soren|Titania|Ashnard|Mist",
        "World": "Tellius|Crimea|Daein|Greil Mercenaries|Laguz",
        "Mechanics": "Bonus experience|Biorhythm|Base conversations",
    },
    "radiant-dawn": {
        "Characters": "Micaiah|Sothe|Sanaki|Sephiran|Yune|Ashera",
        "World": "Dawn Brigade|Begnion|Serenes Forest|Blood pact",
        "Mechanics": "Third tier classes|Mastery skill|Authority stars",
    },
    "shadow-dragon": {
        "Characters": "Marth|Caeda|Tiki|Nagi",
        "World": "War of Shadows|Archanea|Khadein",
        "Mechanics": "Reclassing|Forging|Online Shop",
    },
    "light-and-shadow": {
        "Characters": "Kris|Marth|Hardin|Katarina|Clarisse",
        "World": "War of Heroes|Assassins (New Mystery of the Emblem)",
        "Mechanics": "Drill Grounds|Casual Mode|Base conversations",
    },
    "awakening": {
        "Characters": "Chrom|Robin|Lucina|Lissa|Frederick|Grima",
        "World": "Ylisse|Plegia|Valm|Shepherds",
        "Mechanics": "Pair Up|Second Seal|Child character|Skill inheritance",
    },
    "fire-emblem-fates": {
        "Characters": "Corrin|Azura|Xander|Ryoma|Camilla|Takumi|Anankos",
        "World": "Hoshido|Nohr|Valla|Bottomless Canyon",
        "Mechanics": "Dragon Vein|My Castle|Heart Seal|Attack Stance",
        "Classes": "Nohr Noble|Hoshido Noble|Malig Knight|Kinshi Knight",
    },
    "fire-emblem-echoes-shadows-valentia": {
        "Characters": "Alm|Celica|Berkut|Conrad|Saber|Rinea",
        "World": "Valentia|Thabes Labyrinth|Temple of Mila",
        "Mechanics": "Mila's Turnwheel|Combat arts|Dungeon",
    },
    "three-houses": {
        "Characters": "Byleth|Edelgard|Dimitri|Claude|Rhea|Sothis|Seteth|Flayn",
        "World": "Fódlan|Garreg Mach Monastery|Church of Seiros|Adrestian Empire|Holy Kingdom of Faerghus|Leicester Alliance",
        "Mechanics": "Crests|Class mastery|Battalion|Gambit|Professor level|Adjutant",
        "Classes": "Enlightened One|Emperor|Barbarossa|War Master|Dark Flier",
        "Chapters": "Three Houses/Chapter 1|Three Houses/Chapter 2|Three Houses/Chapter 11",
    },
    "engage": {
        "Characters": "Alear|Veyle|Lumera|Alfred|Diamant|Ivy|Timerra|Sombron",
        "World": "Elyos|Lythos|Firene|Brodia|Elusia|Solm|Somniel",
        "Mechanics": "Emblem Ring|Emblem|Engage attack|Bond level|Skirmish",
        "Classes": "Divine Dragon (class)|Avenir|Successeur|Picket|Tireur d'élite",
    },
    "fire-emblem-heroes": {
        "Characters": "Alfonse|Sharena|Anna|Veronica|Bruno|Gullveig",
        "World": "Askr|Embla|Nifl|Múspell",
        "Mechanics": "Summoning|Aether Raids|Arena (Heroes)|Skill inheritance",
    },
    "fire-emblem-warriors": {
        "Characters": "Rowan|Lianna|Darios|Yelena",
        "World": "Aytolis|Gristonne",
        "Mechanics": "History Mode|Warriors (gameplay)|Pair Up",
    },
    "warriors-three-hopes": {
        "Characters": "Shez|Arval|Edelgard|Dimitri|Claude|Byleth",
        "World": "Fódlan|Abyss|Garreg Mach Monastery",
        "Mechanics": "Warriors: Three Hopes/Gameplay|Battalion|Adjutant",
    },
    "tokyo-mirage-sessions": {
        "Characters": "Itsuki Aoi|Tsubasa Oribe|Touma Akagi|Kiria Kurono|Yashiro Tsurugi",
        "World": "Idolasphere|Fortuna Entertainment|Mirage",
        "Mechanics": "Session attack|Carnage Unity|Stage Rank",
    },
    None: {
        "Series": "Fire Emblem|Weapon triangle|Permanently dead|Promotion|Growth rate|Critical hit|Terrain|Movement|Support|Rescue|Fog of war|Difficulty",
        "Classes": "Lord|Pegasus Knight|Wyvern Rider|Paladin|Swordmaster|Sniper|Dancer|Dark Mage|Great Knight|Trickster",
    },
}

CHAPTER_CATEGORIES = {
    "shadow-dragon-and-blade-of-light": "Fire Emblem: Shadow Dragon & the Blade of Light",
    "gaiden": "Fire Emblem Gaiden",
    "mystery-of-the-emblem": "Fire Emblem: Mystery of the Emblem",
    "genealogy-of-the-holy-war": "Fire Emblem: Genealogy of the Holy War",
    "thracia-776": "Fire Emblem: Thracia 776",
    "binding-blade": "Fire Emblem: The Binding Blade",
    "blazing-sword": "Fire Emblem: The Blazing Blade",
    "the-sacred-stones": "Fire Emblem: The Sacred Stones",
    "path-of-radiance": "Fire Emblem: Path of Radiance",
    "radiant-dawn": "Fire Emblem: Radiant Dawn",
    "shadow-dragon": "Fire Emblem: Shadow Dragon",
    "light-and-shadow": "Fire Emblem: New Mystery of the Emblem",
    "awakening": "Fire Emblem Awakening",
    "fire-emblem-fates": "Fire Emblem Fates",
    "three-houses": "Fire Emblem: Three Houses",
    "engage": "Fire Emblem Engage",
    "fire-emblem-heroes": "Fire Emblem Heroes",
    "fire-emblem-warriors": "Fire Emblem Warriors",
    "warriors-three-hopes": "Fire Emblem Warriors: Three Hopes",
    "tokyo-mirage-sessions": "Tokyo Mirage Sessions ♯FE",
}


def request_api(params):
    url = API + "?" + urlencode({"format": "json", **params})
    for attempt in range(3):
        try:
            with urlopen(Request(url, headers=HEADERS), timeout=20) as response:
                return json.load(response)
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


class ParagraphReader(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip = 0
        self.in_paragraph = False
        self.current = []
        self.paragraphs = []

    def handle_starttag(self, tag, attrs):
        if tag in ("table", "style", "script"):
            self.skip += 1
        elif tag == "p" and not self.skip:
            self.in_paragraph = True
            self.current = []

    def handle_endtag(self, tag):
        if tag in ("table", "style", "script") and self.skip:
            self.skip -= 1
        elif tag == "p" and self.in_paragraph:
            value = re.sub(r"\s+", " ", "".join(self.current)).strip()
            value = re.sub(r"\[\s*\d+\s*\]", "", value)
            if len(value) >= 70 and "It has been requested that" not in value:
                self.paragraphs.append(value)
            self.in_paragraph = False

    def handle_data(self, data):
        if self.in_paragraph and not self.skip:
            self.current.append(data)


def supplementary_text(title, section=1):
    try:
        parsed = request_api({"action": "parse", "page": title, "prop": "text", "section": section,
                              "disabletoc": 1, "disableeditsection": 1})["parse"]
        reader = ParagraphReader()
        reader.feed(parsed["text"]["*"])
        return "\n\n".join(reader.paragraphs)[:7000]
    except (KeyError, ValueError):
        return ""


def introduction(title):
    data = request_api({"action": "query", "prop": "extracts", "explaintext": 1,
                        "exintro": 1, "titles": title})
    return next(iter(data.get("query", {}).get("pages", {}).values()), {}).get("extract", "").strip()


def clean_extract(value):
    value = re.sub(r"\n{3,}", "\n\n", value).strip()
    chunks = []
    for part in value.split("\n\n"):
        part = part.strip()
        if not part or part.startswith(("References", "External links", "Gallery")):
            break
        chunks.append(part)
        if sum(map(len, chunks)) >= 8000:
            break
    return "\n\n".join(chunks)


def article_html(text, source):
    chunks = []
    for part in text.split("\n\n"):
        part = part.strip()
        if not part:
            continue
        if "\n" not in part and len(part) < 65 and not part.endswith((".", ":", ";")):
            chunks.append(f"<h2>{html.escape(part)}</h2>")
        else:
            chunks.append(f"<p>{html.escape(part).replace(chr(10), '<br>')}</p>")
    history = source + "?action=history"
    chunks.append('<h2>Source and license</h2>')
    chunks.append('<p>Article text from Fire Emblem Wiki. Licensed under the '
                  '<a href="https://www.gnu.org/licenses/fdl-1.3.html">GNU Free Documentation License 1.3</a>. '
                  f'<a href="{html.escape(source, quote=True)}">Original article</a> · '
                  f'<a href="{html.escape(history, quote=True)}">Authors and revision history</a>. '
                  'A copy of the license is included in the app.</p>')
    return "\n".join(chunks)


def add_related_articles(records):
    by_game = {}
    for record in records:
        by_game.setdefault(record["gameSlug"], []).append(record)
    for record in records:
        peers = [item for item in by_game[record["gameSlug"]] if item["url"] != record["url"]]
        peers.sort(key=lambda item: (item["category"] != record["category"], item["title"]))
        if not peers:
            continue
        links = "".join(f'<li><a href="{html.escape(item["url"], quote=True)}">'
                        f'{html.escape(item["title"])}</a></li>' for item in peers[:5])
        related = "<h2>Related articles</h2><ul>" + links + "</ul>\n"
        record["html"] = record["html"].replace("<h2>Source and license</h2>",
                                                 related + "<h2>Source and license</h2>", 1)


def main():
    selections = {}
    for slug, groups in ARTICLES.items():
        for group, names in groups.items():
            for title in names.split("|"):
                selections.setdefault(title, (slug, group))
    for slug, category in CHAPTER_CATEGORIES.items():
        members = request_api({"action": "query", "list": "categorymembers",
                               "cmtitle": "Category:Chapters of " + category,
                               "cmlimit": 100, "cmnamespace": 0})["query"]["categorymembers"]
        chapters = [item["title"] for item in members
                    if "/" not in item["title"] and not item["title"].startswith("List of ")]
        for title in chapters[:6]:
            selections.setdefault(title, (slug, "Chapters"))
    titles = list(selections)
    records = []
    rejected = []
    for start in range(0, len(titles), 12):
        batch = titles[start:start + 12]
        data = request_api({"action": "query", "prop": "extracts|revisions|info", "inprop": "url",
                            "rvprop": "timestamp", "explaintext": 1,
                            "redirects": 1, "titles": "|".join(batch)})["query"]
        aliases = {item["from"]: item["to"] for item in data.get("redirects", [])}
        normalized = {item["from"]: item["to"] for item in data.get("normalized", [])}
        for requested in batch:
            resolved = aliases.get(normalized.get(requested, requested), normalized.get(requested, requested))
            page = next((p for p in data["pages"].values() if p.get("title") == resolved), None)
            if not page or "missing" in page:
                rejected.append(requested)
                continue
            title = page["title"]
            intro = clean_extract(page.get("extract", ""))
            if len(intro) < 1100:
                lead = clean_extract(introduction(title))
                if len(lead) > len(intro):
                    intro = lead
                more = supplementary_text(title)
                if more and more not in intro:
                    intro = (intro + "\n\n" + more).strip()[:10000]
            if len(intro) < 500:
                for section in (2, 3, 4):
                    more = supplementary_text(title, section)
                    if more and more not in intro:
                        intro = (intro + "\n\n" + more).strip()[:10000]
                    if len(intro) >= 500:
                        break
            if len(intro) < 500 or "(disambiguation)" in title.lower():
                rejected.append(requested)
                continue
            source = page.get("fullurl") or "https://fireemblemwiki.org/wiki/" + quote(title.replace(" ", "_"), safe="/:()'-,")
            stamp = page.get("revisions", [{}])[0].get("timestamp", "")
            modified = datetime.fromisoformat(stamp.replace("Z", "+00:00")) if stamp else datetime.now(timezone.utc)
            slug, group = selections[requested]
            records.append({"url": source, "title": title, "html": article_html(intro, source),
                            "plainText": intro, "category": "Wiki · " + group,
                            "gameSlug": slug, "archivedAt": modified.strftime("%Y%m%d%H%M%S")})
        print(f"{min(start + 12, len(titles))}/{len(titles)} queried; {len(records)} accepted", flush=True)
    records = list({record["url"]: record for record in reversed(records)}.values())
    records.sort(key=lambda x: ((x["gameSlug"] or "~"), x["category"], x["title"]))
    add_related_articles(records)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(records, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Saved {len(records)} articles ({OUTPUT.stat().st_size:,} bytes). Rejected: {rejected}")


if __name__ == "__main__":
    main()
