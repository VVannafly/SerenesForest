#!/usr/bin/env python3
"""Build the text library and asset URL index from temporary BuildContent inputs."""

import os
import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
CONTENT = Path(os.environ.get("SERENES_SOURCE_CONTENT_DIR", ROOT / "BuildContent")).resolve()
RESOURCE = ROOT / "Resources" / "PreloadedLibrary"
INPUTS = (
    "SeedContent.json",
    "SeedAssets.jsonl",
    "WikiLibrary.json",
    "WikiAssets.jsonl",
    "GameNews.json",
)


def source_counts() -> tuple[int, int]:
    urls: set[str] = set()
    for name in ("SeedContent.json", "WikiLibrary.json", "GameNews.json"):
        with (CONTENT / name).open(encoding="utf-8") as source:
            urls.update(record["url"] for record in json.load(source))
    assets = 0
    for name in ("SeedAssets.jsonl", "WikiAssets.jsonl"):
        with (CONTENT / name).open("rb") as source:
            assets += sum(bool(line.strip()) for line in source)
    return len(urls), assets


def validate(store: Path, expected_pages: int, expected_assets: int) -> tuple[int, int]:
    database = sqlite3.connect(store)
    try:
        integrity = database.execute("PRAGMA quick_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"SwiftData store failed integrity check: {integrity}")
        pages = database.execute("SELECT count(*) FROM ZCONTENTPAGE").fetchone()[0]
        assets = database.execute("SELECT count(*) FROM ZCONTENTASSET").fetchone()[0]
        games = database.execute("SELECT count(*) FROM ZGAME").fetchone()[0]
        stored_images = database.execute(
            "SELECT count(*) FROM ZCONTENTASSET WHERE ZDATA IS NOT NULL OR ZFETCHEDAT IS NOT NULL"
        ).fetchone()[0]
        database.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    finally:
        database.close()
    if pages != expected_pages or assets != expected_assets or games != 22:
        raise RuntimeError(
            f"Incomplete library: {pages}/{expected_pages} pages, "
            f"{assets}/{expected_assets} assets, {games}/22 games"
        )
    if stored_images:
        raise RuntimeError(f"Bundled library still contains {stored_images} downloaded images")
    return pages, assets


def build() -> None:
    missing = [name for name in INPUTS if not (CONTENT / name).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing generated inputs in {CONTENT}: {', '.join(missing)}")
    expected_pages, expected_assets = source_counts()

    with tempfile.TemporaryDirectory(prefix="serenes-preload-") as temporary:
        work = Path(temporary)
        optimized_content = work / "BuildContent"
        optimized_content.mkdir()
        for name in ("SeedContent.json", "WikiLibrary.json", "GameNews.json"):
            (optimized_content / name).symlink_to(CONTENT / name)
        for name in ("SeedAssets.jsonl", "WikiAssets.jsonl"):
            with (CONTENT / name).open(encoding="utf-8") as source, \
                    (optimized_content / name).open("w", encoding="utf-8") as target:
                for line in source:
                    if line.strip():
                        record = json.loads(line)
                        record.pop("dataBase64", None)
                        target.write(json.dumps(record, ensure_ascii=False) + "\n")
        derived = work / "DerivedData"
        store = work / "Library.store"
        subprocess.run(
            ["xcodebuild", "-quiet", "-project", "SerenesForest.xcodeproj",
             "-scheme", "SerenesForest", "-configuration", "Debug",
             "-destination", "generic/platform=macOS",
             "-derivedDataPath", str(derived), "CODE_SIGNING_ALLOWED=NO", "build"],
            cwd=ROOT, check=True,
        )
        executable = derived / "Build/Products/Debug/SerenesForest.app/Contents/MacOS/SerenesForest"
        environment = os.environ.copy()
        environment["SERENES_BUILD_STORE_PATH"] = str(store)
        environment["SERENES_BUILD_CONTENT_DIR"] = str(optimized_content)
        subprocess.run([str(executable)], cwd=ROOT, env=environment, check=True)

        pages, assets = validate(store, expected_pages, expected_assets)
        stage = Path(tempfile.mkdtemp(prefix=".preloaded-next-", dir=RESOURCE.parent))
        backup = RESOURCE.with_name("PreloadedLibrary.previous")
        try:
            shutil.copy2(store, stage / "Library.store")
            if backup.exists():
                raise RuntimeError(f"Remove stale backup before rebuilding: {backup}")
            if RESOURCE.exists():
                RESOURCE.rename(backup)
            stage.rename(RESOURCE)
        except Exception:
            if backup.exists() and not RESOURCE.exists():
                backup.rename(RESOURCE)
            raise
        finally:
            if stage.exists():
                shutil.rmtree(stage)
        if backup.exists():
            shutil.rmtree(backup)
        print(f"Installed preloaded library: {pages} pages, {assets} assets")


if __name__ == "__main__":
    build()
