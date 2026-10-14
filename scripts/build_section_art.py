"""Extract small, game-specific guide icons from the bundled site artwork."""

import base64
import json
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "BuildContent" / "SeedAssets.jsonl"
DESTINATION = ROOT / "Resources" / "GameCovers"
GAME_SLUGS = {
    "shadow-dragon-and-blade-of-light", "gaiden", "mystery-of-the-emblem",
    "genealogy-of-the-holy-war", "thracia-776", "binding-blade", "blazing-sword",
    "the-sacred-stones", "path-of-radiance", "radiant-dawn", "shadow-dragon",
    "light-and-shadow", "awakening", "fire-emblem-fates",
    "fire-emblem-echoes-shadows-valentia", "three-houses", "engage",
    "fortunes-weave", "fire-emblem-heroes",
}
SECTION_PATHS = {
    "general": {"general"},
    "characters": {"characters"},
    "classes": {"classes"},
    "inventory": {"inventory"},
    "miscellaneous": {"miscellaneous", "monastery"},
    "scripts": {"scripts", "script"},
}
# Some games place their icon art in another guide section.
OVERRIDES = {
    ("three-houses", "general"): ("characters", "crests_01.png"),
    ("three-houses", "inventory"): ("characters", "professor-sword.png"),
    ("engage", "inventory"): ("classes", "weapon-sword.png"),
}


def main() -> None:
    selected: dict[tuple[str, str], dict] = {}
    with SOURCE.open(encoding="utf-8") as records:
        for line in records:
            record = json.loads(line)
            parts = urlparse(record["sourcePageURL"]).path.strip("/").split("/")
            if len(parts) < 2 or parts[0] not in GAME_SLUGS:
                continue
            if Path(record["title"].lower()).suffix not in {".png", ".jpg", ".jpeg", ".gif"}:
                continue
            for section, paths in SECTION_PATHS.items():
                key = (parts[0], section)
                override = OVERRIDES.get(key)
                if override is not None:
                    if (parts[1], record["title"]) == override:
                        selected[key] = record
                elif parts[1] in paths and key not in selected:
                    selected[key] = record

    DESTINATION.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="serenes-section-art-") as directory:
        temporary = Path(directory)
        for (slug, section), record in selected.items():
            source = temporary / f"{slug}-{section}{Path(record['title']).suffix.lower()}"
            source.write_bytes(base64.b64decode(record["dataBase64"]))
            output = DESTINATION / f"sectionart-{slug}-{section}.png"
            subprocess.run(["sips", "-s", "format", "png", "-Z", "144", str(source),
                            "--out", str(output)], check=True, capture_output=True)
    print(f"Extracted {len(selected)} game-specific guide icons into {DESTINATION}")


if __name__ == "__main__":
    main()
