#!/usr/bin/env python3
"""Check that dig data, tools, and the Godot copy stay in sync."""

import json
import sys
import time
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
    warnings = []
    if len(dinos) < 5:
        errors.append("need at least 5 dinosaurs")
    if len(sites) < 5:
        errors.append("need at least 5 sites")
    biomes = {b["id"] for b in catalog["biomes"]}
    for key, entry in strings.items():
        if not isinstance(entry, dict) or "tr" not in entry or "en" not in entry:
            errors.append(f"string {key} needs tr and en")

    # catalog: tool tier + research branches
    for tool in catalog["tools"]:
        tier = tool.get("tier")
        if tier is None:
            warnings.append(f"tool {tool['id']} missing tier")
        elif not isinstance(tier, int) or tier < 1:
            errors.append(f"tool {tool['id']} tier must be a positive integer")

    branches = catalog.get("research_branches", [])
    if not isinstance(branches, list):
        errors.append("catalog.research_branches must be a list")
        branches = []
    for branch in branches:
        if not isinstance(branch, dict) or "id" not in branch:
            errors.append("research branch needs id")
            continue
        nodes = branch.get("nodes", [])
        if not isinstance(nodes, list):
            errors.append(f"branch {branch['id']} nodes must be a list")
            continue
        node_ids = {n.get("id") for n in nodes if isinstance(n, dict)}
        for node in nodes:
            if not isinstance(node, dict) or "id" not in node:
                errors.append(f"branch {branch['id']} node needs id")
                continue
            req = node.get("requires")
            if req is not None and req not in node_ids:
                errors.append(f"branch {branch['id']} node {node['id']} requires unknown {req}")

    # dinosaurs: facts, diet, assembly_order, bone_sockets
    for dino in dinos.values():
        if len(dino["bones"]) < 6:
            errors.append(f"{dino['id']} needs 6 bones")
        for fact in dino["facts"]:
            if "tr" not in fact or "en" not in fact:
                errors.append(f"{dino['id']} fact missing language")
        if dino["diet"] not in ("herbivore", "carnivore"):
            errors.append(f"{dino['id']} diet")
        bone_ids = {b["id"] for b in dino["bones"]}
        order = dino.get("assembly_order")
        if order is not None:
            if not isinstance(order, list):
                errors.append(f"{dino['id']} assembly_order must be a list")
            elif sorted(order) != sorted(bone_ids):
                errors.append(f"{dino['id']} assembly_order must cover all bones exactly once")
        sockets = dino.get("bone_sockets")
        if sockets is not None:
            if not isinstance(sockets, dict):
                errors.append(f"{dino['id']} bone_sockets must be an object")
            else:
                for bid in sockets:
                    if bid not in bone_ids:
                        errors.append(f"{dino['id']} socket for unknown bone {bid}")

    # sites: biome, layers, fossil_layout, spots
    for site in sites:
        if site["dino"] not in dinos:
            errors.append(f"{site['id']} unknown dino")
            continue
        if site["biome"] not in biomes:
            errors.append(f"{site['id']} biome")
        site_layers = site.get("layers")
        if site_layers is not None:
            if not isinstance(site_layers, list):
                errors.append(f"{site['id']} layers must be a list")
            else:
                for layer in site_layers:
                    if not isinstance(layer, dict):
                        errors.append(f"{site['id']} layer must be an object")
                        continue
                    if "soil" in layer and layer["soil"] not in soils:
                        errors.append(f"{site['id']} layer soil {layer['soil']}")
        layout = site.get("fossil_layout")
        if layout is not None and not isinstance(layout, dict):
            errors.append(f"{site['id']} fossil_layout must be an object")
        bones = {b["id"] for b in dinos[site["dino"]]["bones"]}
        if len(site["spots"]) != len(bones):
            errors.append(f"{site['id']} spot count")
        for spot in site["spots"]:
            if spot["bone"] not in bones:
                errors.append(f"{site['id']} bone {spot['bone']}")
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

    report = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "counts": {
            "dinos": len(dinos),
            "sites": len(sites),
            "strings": len(strings),
            "tools": len(tools),
            "research_branches": len(branches),
        },
    }
    (ROOT / "validation_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    for warning in warnings:
        print("warn:", warning)
    if errors:
        print("\n".join(errors))
        return 1
    print("data ok", len(dinos), "dinos", len(sites), "sites", len(strings), "strings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
