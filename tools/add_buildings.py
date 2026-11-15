import json

specs = json.load(open('App/specs.json', encoding='utf-8'))

# Map of story -> additional GLB props from Kenney buildings kit
# Buildings are 2x2x2m modular blocks - used as decorative props/scenery
BUILDINGS = {
    "the-mountain-man": [
        {"kind": "model", "url": "models/buildings/roof-gable.glb", "x": -7, "z": 16, "ry": 0, "s": 1.4},  # roof accent near cabin
        {"kind": "model", "url": "models/buildings/window-white-large.glb", "x": -9.5, "z": 14, "ry": 0, "s": 0.8},  # window detail
    ],
    "the-search-party": [
        {"kind": "model", "url": "models/buildings/door-brown.glb", "x": 5, "z": 18, "ry": 0, "s": 0.9},  # abandoned door prop
        {"kind": "model", "url": "models/buildings/detail-ac-a.glb", "x": -5, "z": 20, "ry": 0.3, "s": 1.2},  # accent detail
    ],
    "the-no-signal-forest": [
        {"kind": "model", "url": "models/buildings/building-sample-house-a.glb", "x": 8, "z": -10, "ry": 0.5, "s": 2.5},  # ruined house silhouette
        {"kind": "model", "url": "models/buildings/roof-slanted.glb", "x": -8, "z": -14, "ry": -0.3, "s": 2.0},  # fallen roof
    ],
    "the-town-that-vanished": [
        {"kind": "model", "url": "models/buildings/building-sample-house-b.glb", "x": -12, "z": -20, "ry": 0.2, "s": 2.8},  # abandoned house background
        {"kind": "model", "url": "models/buildings/building-sample-house-c.glb", "x": 14, "z": -25, "ry": -0.4, "s": 2.5},  # second ruined house
    ],
    "the-lake-that-never-freezes": [
        {"kind": "model", "url": "models/buildings/door-brown-window.glb", "x": -10, "z": 22, "ry": 0, "s": 1.5},  # cabin door detail
        {"kind": "model", "url": "models/buildings/window-white-round-top.glb", "x": -10, "z": 22, "ry": 0, "s": 1.5},  # round window
    ],
    "the-cave-divers-tape": [
        {"kind": "model", "url": "models/buildings/window-white-large.glb", "x": -8, "z": -15, "ry": 0, "s": 1.2},  # broken window in cave wall
        {"kind": "model", "url": "models/buildings/debris-door.glb", "x": 6, "z": -18, "ry": 0.8, "s": 1.0},
    ],
    "the-dog-and-the-wall": [
        {"kind": "model", "url": "models/buildings/door-white.glb", "x": 4, "z": 8, "ry": 0, "s": 1.0},  # front door near wall
        {"kind": "model", "url": "models/buildings/window-brown.glb", "x": 2, "z": 8, "ry": 0, "s": 0.9},
    ],
}

for sid, new_props in BUILDINGS.items():
    if sid not in specs:
        print(f"SKIP {sid}: not found")
        continue
    existing = specs[sid].get("props", [])
    # Don't duplicate if already present
    existing_urls = {p.get("url") for p in existing if p.get("kind") == "model"}
    added = 0
    for np in new_props:
        if np["url"] not in existing_urls:
            existing.append(np)
            added += 1
    print(f"{sid}: +{added} new GLB props ({len(existing)} total)")

with open('App/specs.json', 'w', encoding='utf-8') as f:
    json.dump(specs, f, indent=2, ensure_ascii=False)

print("\nApp/specs.json updated")
