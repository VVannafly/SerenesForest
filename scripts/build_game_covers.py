"""Extract the site's game overview artwork into small, immediately available UI assets."""

import base64
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "BuildContent" / "SeedAssets.jsonl"
DESTINATION = ROOT / "Resources" / "GameCovers"

# The overview image on each game's landing page is a landscape illustration.
# Keep the selection explicit so a new image in the archive cannot change a cover.
COVERS = {
    "shadow-dragon-and-blade-of-light": "overview-art.png",
    "gaiden": "fe2title-300x145.png",
    "mystery-of-the-emblem": "top3_2.png",
    "genealogy-of-the-holy-war": "top4-300x145.png",
    "thracia-776": "top5.png",
    "binding-blade": "top6.png",
    "blazing-sword": "top7.png",
    "the-sacred-stones": "top8.png",
    "path-of-radiance": "top9-300x145.png",
    "radiant-dawn": "fe10-radiant-dawn.png",
    "shadow-dragon": "fe11-shadow-dragon.png",
    "light-and-shadow": "new-mystery-of-the-emblem.png",
    "awakening": "awakening-overview.jpg",
    "fire-emblem-fates": "mainvisual-p.jpg",
    "fire-emblem-echoes-shadows-valentia": "echoes-front.jpg",
    "three-houses": "three-houses-banner3-300x145.jpg",
    "engage": "fe-engage-splash.jpg",
    "fortunes-weave": "fefw-main-image2b-300x169.jpg",
    "fire-emblem-heroes": "heroes-front-1.jpg",
}

def main():
    DESTINATION.mkdir(exist_ok=True)
    remaining = set(COVERS)
    with SOURCE.open(encoding="utf-8") as records:
        for line in records:
            record = json.loads(line)
            slug = record["sourcePageURL"].removeprefix("https://serenesforest.net/").strip("/")
            if slug in remaining and record["title"] == COVERS[slug]:
                suffix = Path(record["title"]).suffix.lower()
                (DESTINATION / f"{slug}{suffix}").write_bytes(base64.b64decode(record["dataBase64"]))
                remaining.remove(slug)
    if remaining:
        raise RuntimeError(f"Missing artwork: {', '.join(sorted(remaining))}")
    print(f"Extracted {len(COVERS)} covers into {DESTINATION}")


if __name__ == "__main__":
    main()
