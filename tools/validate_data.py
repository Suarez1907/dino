#!/usr/bin/env python3
"""Check that dig data, tools, and the Godot copy stay in sync."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "shared" / "data"


def load(name):
    return json.loads((SHARED / name).read_text(encoding="utf-8"))


def main():
    catalog = load("catalog.json")
    dinos = {d["id"]: d for d in load("dinosaurs.json")}
    sites = load("sites.json")
    strings = load("strings.json")
    tools = {t["id"] for t in catalog["tools"]}
    soils = {s["id"] for s in catalog["soils"]}
    errors = []
    if len(dinos) < 5:
        errors.append("need at least 5 dinosaurs")
    if len(sites) < 5:
        errors.append("need at least 5 sites")
    biomes = {b["id"] for b in catalog["biomes"]}
    for key, entry in strings.items():
        if not isinstance(entry, dict) or "tr" not in entry or "en" not in entry:
            errors.append(f"string {key} needs tr and en")
    for dino in dinos.values():
        if len(dino["bones"]) < 6:
            errors.append(f"{dino['id']} needs 6 bones")
        for fact in dino["facts"]:
            if "tr" not in fact or "en" not in fact:
                errors.append(f"{dino['id']} fact missing language")
        if dino["diet"] not in ("herbivore", "carnivore"):
            errors.append(f"{dino['id']} diet")
    seen = set()
    for site in sites:
        if site["dino"] not in dinos:
            errors.append(f"{site['id']} unknown dino")
            continue
        if site["biome"] not in biomes:
            errors.append(f"{site['id']} biome")
        bones = {b["id"] for b in dinos[site["dino"]]["bones"]}
        if len(site["spots"]) != len(bones):
            errors.append(f"{site['id']} spot count")
        for spot in site["spots"]:
            if spot["bone"] not in bones:
                errors.append(f"{site['id']} bone {spot['bone']}")
            if spot["bone"] in seen and site["id"] == sites[0]["id"]:
                pass
            for layer in spot["layers"]:
                if layer["tool"] not in tools:
                    errors.append(f"tool {layer['tool']}")
                if layer["soil"] not in soils:
                    errors.append(f"soil {layer['soil']}")
    godot = ROOT / "godot" / "data"
    for path in SHARED.glob("*.json"):
        copy = godot / path.name
        if not copy.exists() or copy.read_text(encoding="utf-8") != path.read_text(encoding="utf-8"):
            errors.append(f"godot/data/{path.name} is out of sync")
    if errors:
        print("\n".join(errors))
        return 1
    print("data ok", len(dinos), "dinos", len(sites), "sites", len(strings), "strings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
