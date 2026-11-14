#!/usr/bin/env python3
"""Copy shared JSON into the Godot project. The web app reads shared/data directly."""

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "shared" / "data"
DST = ROOT / "godot" / "data"


def main():
    DST.mkdir(parents=True, exist_ok=True)
    for path in SRC.glob("*.json"):
        shutil.copy2(path, DST / path.name)
        print(path.name)


if __name__ == "__main__":
    main()
