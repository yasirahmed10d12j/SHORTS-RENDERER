"""Generate per-story render specs for engine2 from stories.json + bundled voices.

For every story in App/stories.json this produces a JSON spec consumed by
window.loadStory(spec) in engine2.html:
  - scene durations come from the bundled Kokoro MP3s (ffprobe) + a tail pad,
    so TOTAL matches the voiceover exactly (no setVoiceDuration scaling)
  - set / light / cast / camera templates are chosen by keyword rules with a
    per-story override table
  - captions = the narration itself (subtitle style, drawn by drawCaptions)

Output:
  tools/specs/<id>.json   (one file per story, for review)
  App/specs.json          (combined bundle resource used by the app)

Usage:  python tools/gen_specs.py
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORIES = ROOT / "App" / "stories.json"
VOICES = ROOT / "App" / "voices"
OUT_DIR = ROOT / "tools" / "specs"
BUNDLE = ROOT / "App" / "specs.json"

PAD = 1.4  # seconds of breathing room after each scene's voice line

# ── per-story override table ─────────────────────────────────────────────
# set: {type, style?, ...set params} | light: default preset name
# cast: outfit ids (1 = protagonist). lightSeq: {firstSceneN: lightFromHere}
OVERRIDES = {
    "the-lighthouse-keepers-last-log": {"set": {"type": "sea"}, "light": "night", "cast": ["keeper"]},
    "the-mountain-man": {"set": {"type": "outdoor", "style": "forest", "trees": 110, "cabin": True}, "light": "day", "cast": ["hiker", "old"], "lightSeq": {5: "golden", 7: "night"}, "props": [{"kind": "tent", "x": 5, "z": 14}, {"kind": "campfire", "x": 3, "z": 12.5}, {"kind": "sign", "x": -2.5, "z": 18, "ry": -0.4}]},
    "the-333-bus": {"set": {"type": "interior", "style": "bus"}, "light": "street", "cast": ["nurse", "man"]},
    "the-neighbor-at-3am": {"set": {"type": "interior", "style": "room"}, "light": "night", "cast": ["man", "old"]},
    "the-baby-monitor-voice": {"set": {"type": "interior", "style": "room", "bed": True}, "light": "night", "cast": ["mother", "kid"], "props": [{"kind": "crib", "x": 1.8, "z": -1.2, "s": 0.9}]},
    "the-duplicate-key": {"set": {"type": "interior", "style": "corridor", "doors": 5, "doorStart": 2}, "light": "lamp", "cast": ["clerk"], "props": [{"kind": "desk", "x": 1.15, "z": 1.8, "ry": -1.57, "s": 0.95}]},
    "the-photograph-that-changed": {"set": {"type": "outdoor", "style": "town", "houses": 7}, "light": "golden", "cast": ["old", "man"], "props": [{"kind": "model", "url": "models/cars/sedan.glb", "x": -4.5, "z": 12, "ry": 0.15, "s": 1}]},
    "the-elevator-floor-13": {"set": {"type": "interior", "style": "corridor", "doors": 8, "endLight": True}, "light": "fluoro", "cast": ["clerk"], "props": [{"kind": "elevDoors", "x": 2.05, "z": -2}]},
    "the-no-signal-forest": {"set": {"type": "outdoor", "style": "forest", "trees": 120}, "light": "day", "cast": ["hiker", "teen"], "lightSeq": {6: "night"}, "props": [{"kind": "tent", "x": 4.2, "z": 12.5}, {"kind": "sign", "x": -2.6, "z": 17}]},
    "the-last-voicemail": {"set": {"type": "interior", "style": "room", "tv": True}, "light": "night", "cast": ["woman"], "props": [{"kind": "desk", "x": 2.7, "z": 2.6, "ry": -1.57, "s": 0.9}]},
    "the-man-in-my-mirror": {"set": {"type": "interior", "style": "room", "bed": False}, "light": "lamp", "cast": ["man"]},
    "the-town-that-vanished": {"set": {"type": "outdoor", "style": "town", "houses": 10, "lamps": 6}, "light": "day", "cast": ["old", "villager1"], "lightSeq": {5: "golden", 7: "night"}, "props": [{"kind": "model", "url": "models/cars/sedan.glb", "x": 4.6, "z": 9, "ry": 1.6, "s": 1}, {"kind": "sign", "x": -3, "z": 15.5}]},
    "the-radio-tower-recording": {"set": {"type": "outdoor", "style": "tower"}, "light": "night", "cast": ["worker"], "props": [{"kind": "model", "url": "models/cars/suv.glb", "x": 7, "z": 3, "ry": -0.9, "s": 1}]},
    "the-search-party": {"set": {"type": "outdoor", "style": "forest", "trees": 100}, "light": "dawnsea", "cast": ["cop", "villager2", "villager3"], "lightSeq": {5: "night"}, "props": [{"kind": "tent", "x": 5, "z": 13.5}, {"kind": "campfire", "x": 3.2, "z": 12}, {"kind": "sign", "x": -3, "z": 16.5}]},
    "the-morgue-night-shift": {"set": {"type": "interior", "style": "morgue", "gurney": True}, "light": "fluoro", "cast": ["nurse"]},
    "the-telegram-1912": {"set": {"type": "interior", "style": "room", "tv": False}, "light": "lamp", "cast": ["old"], "props": [{"kind": "desk", "x": -3.1, "z": 2.4, "ry": 1.57, "s": 0.95}]},
    "the-cave-divers-tape": {"set": {"type": "cave", "gear": True, "rope": True}, "light": "cave", "cast": ["diver"]},
    "the-dog-and-the-wall": {"set": {"type": "interior", "style": "room", "bed": True}, "light": "lamp", "cast": ["kid", "teen"]},
    "the-hotel-door-9": {"set": {"type": "interior", "style": "corridor", "doors": 7, "doorStart": 3, "endLight": True}, "light": "lamp", "cast": ["clerk", "man"], "props": [{"kind": "cart", "x": 1.15, "z": 2.2}]},
    "the-lake-that-never-freezes": {"set": {"type": "lake", "boat": True, "cabin": True}, "light": "moonlit", "cast": ["hiker"], "lightSeq": {1: "golden", 3: "moonlit"}},
}

# ── stage anchors per set key (actor home, look point, camera base) ──────
STAGES = {
    "sea":      {"home": [2, 6],    "look": [1, 3, 3],    "cam": [7, 2.5, 11],   "scale": 1.15},
    "forest":   {"home": [0, 10],   "look": [0, 1.6, 10], "cam": [4.5, 1.8, 15], "scale": 1.0},
    "town":     {"home": [0, 10],   "look": [0, 1.6, 10], "cam": [4.5, 2, 15],   "scale": 1.0},
    "tower":    {"home": [3, 5],    "look": [1, 4, 2],    "cam": [8, 2, 9],      "scale": 1.0},
    "lake":     {"home": [0, 7],    "look": [0, 1.2, 4],  "cam": [5, 2, 12],     "scale": 1.0},
    "room":     {"home": [-1, 1],   "look": [-1, 1.3, 1], "cam": [2.8, 1.7, 4.2],"scale": 0.62},
    "corridor": {"home": [-0.9, 0], "look": [-0.6, 1.3, -4], "cam": [1.3, 1.6, 3], "scale": 0.55},
    "morgue":   {"home": [-0.9, 1], "look": [-0.6, 1.2, -3], "cam": [1.3, 1.6, 4], "scale": 0.55},
    "bus":      {"home": [0.8, 0.5], "look": [0.4, 1.2, -1], "cam": [-0.9, 1.6, 3.2], "scale": 0.55},
    "cave":     {"home": [-2, 2],   "look": [-1, 1.2, -2], "cam": [3, 1.8, 5],    "scale": 0.8},
}

# stage key for a set spec
def stage_key(setsp):
    t = setsp["type"]
    if t in ("sea", "lake", "cave"):
        return t
    return setsp.get("style", "room")

# default light when a story is not in OVERRIDES
def pick_set(narrations):
    text = " ".join(narrations).lower()
    for kw, sp in [
        ("lighthouse", {"type": "sea"}),
        ("bus", {"type": "interior", "style": "bus"}),
        ("cave", {"type": "cave"}),
        ("lake", {"type": "lake"}),
        ("morgue", {"type": "interior", "style": "morgue"}),
        ("forest", {"type": "outdoor", "style": "forest"}),
        ("town", {"type": "outdoor", "style": "town"}),
        ("tower", {"type": "outdoor", "style": "tower"}),
        ("corridor", {"type": "interior", "style": "corridor"}),
        ("hallway", {"type": "interior", "style": "corridor"}),
        ("elevator", {"type": "interior", "style": "corridor"}),
    ]:
        if kw in text:
            return sp
    return {"type": "interior", "style": "room"}

def mp3_durations(story_id, n_scenes):
    durs = []
    for i in range(1, n_scenes + 1):
        p = VOICES / story_id / f"scene-{i:02d}.mp3"
        if not p.exists():
            raise SystemExit(f"missing voice: {p}")
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", str(p)],
            capture_output=True, text=True, check=True).stdout.strip()
        durs.append(float(out))
    return durs

def build_cam(kind, st, home2, i, n):
    """kind: shot type; st: stage dict; home2: actor home (x,z); i/n: scene index."""
    sc = st["scale"]
    hx, hz = home2
    lk = list(st["look"])
    cb = list(st["cam"])
    if kind == "pushIn":
        return {"type": "pushIn", "from": [cb[0] + 1.5 * sc, cb[1] + 0.4, cb[2] + 3.5 * sc],
                "to": cb, "look": lk, "fov": 44}
    if kind == "pullOut":
        return {"type": "pullOut", "from": [cb[0] - 0.8 * sc, cb[1], cb[2] - 1.2 * sc],
                "to": [cb[0] + 1.8 * sc, cb[1] + 0.6, cb[2] + 4.5 * sc], "look": lk, "fov": 42}
    if kind == "pan":
        return {"type": "pan", "pos": [cb[0] + 2 * sc, cb[1], cb[2]],
                "lookFrom": [lk[0] + 1.6 * sc, lk[1], lk[2]],
                "lookTo": [lk[0] - 1.6 * sc, lk[1], lk[2] - 2 * sc], "fov": 46}
    if kind == "orbit":
        return {"type": "orbit", "center": [lk[0], 0, lk[2]], "r": 5.5 * sc, "h": 1.9,
                "a0": -25 + 8 * (i % 3), "a1": 30 + 10 * (i % 4),
                "look": [lk[0], lk[1], lk[2]], "fov": 44}
    if kind == "track":
        return {"type": "track", "from": [cb[0], cb[1], cb[2] + 2.5 * sc],
                "to": [cb[0], cb[1], cb[2] - 1.5 * sc], "look": lk, "fov": 40}
    if kind == "rise":
        return {"type": "rise", "from": [cb[0], max(0.6, cb[1] - 0.5), cb[2]],
                "to": [cb[0], cb[1] + 3.4 * sc, cb[2] + 1.5 * sc],
                "lookFrom": lk, "lookTo": [lk[0], lk[1] + 1.2, lk[2] - 1], "fov": 44}
    return {"type": "static", "pos": cb, "look": lk, "fov": 45, "jitter": True}

MID_SHOTS = ["pan", "orbit", "static", "pullOut", "track", "rise"]

def fx_for(setsp, light):
    key = stage_key(setsp)
    if key == "sea":
        return [{"kind": "glow", "pos": [0, (setsp.get("towerH", 16)) + 1.2, 0], "size": 6, "at": [0, 1], "cycle": True}]
    if key == "cave":
        return [{"kind": "glow", "pos": [1.5, 1.4, -4], "size": 3.5, "at": [0, 1], "cycle": True, "alpha": 0.8}]
    if key in ("room",) and light in ("lamp", "night"):
        return [{"kind": "glow", "pos": [3.2, 1.3, -3.2], "size": 2.6, "at": [0, 1], "cycle": True, "alpha": 0.7}]
    if key in ("forest", "town") and light in ("day", "golden", "dawnsea"):
        return [{"kind": "bird", "pos": [12, 14, 6], "size": 1.4, "at": [0.05, 0.6], "cycle": True}]
    return []

def light_of(ov, scene_n, default):
    seq = ov.get("lightSeq", {})
    active = default
    for start in sorted(seq):
        if scene_n >= start:
            active = seq[start]
    return active

def main():
    stories = json.loads(STORIES.read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bundle = {}
    for st in stories:
        sid = st["id"]
        scenes_in = st["scenes"]
        durs = mp3_durations(sid, len(scenes_in))
        ov = OVERRIDES.get(sid)
        if ov is None:
            ov = {"set": pick_set([s["narration"] for s in scenes_in]),
                  "light": "night", "cast": ["man"]}
        setsp = ov["set"]
        st = STAGES[stage_key(setsp)]
        cast = ov["cast"]
        default_light = ov["light"]
        scenes_out = []
        n = len(scenes_in)
        for i, sc in enumerate(scenes_in):
            sn = sc["n"]
            light = light_of(ov, sn, default_light)
            home2 = list(st["home"])
            actors = []
            for ci, outfit in enumerate(cast):
                a = {"outfit": outfit, "kind": "front" if ci == 0 else "side",
                     "pos": [home2[0] + ci * 1.9, home2[1] - ci * 1.1],
                     "expr": "calm", "seed": 3 + ci * 7}
                if ci > 0:
                    a["dir"] = [0, -1]
                if i in (1, 4) and ci == 0:
                    a["mode"] = "stand"
                actors.append(a)
            if i == 0:
                kind = "pushIn"
            elif i == n - 1:
                kind = "static"
            else:
                kind = MID_SHOTS[(i - 1) % len(MID_SHOTS)]
            scenes_out.append({
                "n": sn,
                "dur": round(durs[i] + PAD, 2),
                "light": light,
                "cam": build_cam(kind, st, home2, i, n),
                "actors": actors,
                "fx": fx_for(setsp, light),
                "caption": sc["narration"],
                "capStyle": "hook" if sn == 1 else "normal",
            })
        spec = {"id": sid, "flatGround": True, "set": setsp, "scenes": scenes_out}
        if ov.get("props"):
            spec["props"] = ov["props"]
        (OUT_DIR / f"{sid}.json").write_text(json.dumps(spec, indent=1), encoding="utf-8")
        bundle[sid] = spec
        total = round(sum(s["dur"] for s in scenes_out), 1)
        print(f"{sid}: {n} scenes, {total}s, set={setsp['type']}/{setsp.get('style','-')}")
    BUNDLE.write_text(json.dumps(bundle), encoding="utf-8")
    print(f"\nApp/specs.json written ({BUNDLE.stat().st_size / 1024:.0f} KB), {len(bundle)} stories")

if __name__ == "__main__":
    main()
