#!/usr/bin/env python3
"""Replace the bundled SwiftData store with its article text and asset URL index."""

from pathlib import Path
import shutil
import sqlite3
import tempfile


ROOT = Path(__file__).resolve().parent.parent
LIBRARY = ROOT / "Resources" / "PreloadedLibrary"
STORE = LIBRARY / "Library.store"


def counts(database: sqlite3.Connection) -> tuple[int, int, int]:
    return tuple(database.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
                 for table in ("ZCONTENTPAGE", "ZCONTENTASSET", "ZGAME"))


def main() -> None:
    if not STORE.is_file():
        raise FileNotFoundError(STORE)
    backup = LIBRARY.with_name("PreloadedLibrary.previous")
    if backup.exists():
        raise RuntimeError(f"Previous backup exists: {backup}")

    stage = Path(tempfile.mkdtemp(prefix=".preloaded-next-", dir=LIBRARY.parent))
    try:
        source = sqlite3.connect(f"file:{STORE}?mode=ro", uri=True)
        target = sqlite3.connect(stage / "Library.store")
        try:
            original = counts(source)
            source.backup(target)
            target.execute("UPDATE ZCONTENTASSET SET ZDATA = NULL, ZFETCHEDAT = NULL, "
                           "ZLASTATTEMPT = NULL, ZLASTERROR = NULL")
            target.commit()
            target.execute("VACUUM")
            if target.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise RuntimeError("Compacted store failed integrity check")
            if counts(target) != original:
                raise RuntimeError("Compaction changed library record counts")
            if target.execute("SELECT count(*) FROM ZCONTENTASSET "
                              "WHERE ZDATA IS NOT NULL OR ZFETCHEDAT IS NOT NULL").fetchone()[0]:
                raise RuntimeError("Image bytes remain in the compacted store")
        finally:
            source.close()
            target.close()

        LIBRARY.rename(backup)
        try:
            stage.rename(LIBRARY)
        except Exception:
            backup.rename(LIBRARY)
            raise
        shutil.rmtree(backup)
        print(f"Compacted library: {original[0]} pages, {original[1]} image URLs, "
              f"{original[2]} games; {STORE.stat().st_size:,} bytes")
    finally:
        if stage.exists():
            shutil.rmtree(stage)


if __name__ == "__main__":
    main()
