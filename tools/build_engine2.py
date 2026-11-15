"""Build App/engine/engine2.html from engine.html.

Extracts the reusable core (three.js bundle, toon/paint/terrain/motion,
renderer setup, materials, set primitives, sky/lights, character card
system, post-processing chain) and replaces the hand-coded story layer
(castdefs/story/main) with the data-driven spec.js + init.js.

Line slices refer to engine.html as committed (24,047 lines).
Usage:  python tools/build_engine2.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "App" / "engine" / "engine.html"
OUT = ROOT / "App" / "engine" / "engine2.html"
SPEC = Path(__file__).resolve().parent / "engine2" / "spec.js"

def lines_of(p: Path):
    return p.read_text(encoding="utf-8", errors="replace").splitlines()

def rng(src, a, b):
    """1-indexed inclusive slice."""
    return "\n".join(src[a - 1 : b])

def main():
    src = lines_of(SRC)
    n = len(src)
    assert n > 23000, f"engine.html too small ({n} lines) — wrong file?"

    # sanity anchors
    assert "var rng = (seed)" in rng(src, 22365, 22365)
    assert "// castdefs.js" in rng(src, 22756, 22756)
    assert "// story.js" in rng(src, 22768, 22768)
    assert "// main.js" in rng(src, 23185, 23185)
    assert 'window.renderFrame = (f) => {' in rng(src, 23874, 23874)
    assert 'return canvas.toDataURL("image/jpeg", 0.95);' in rng(src, 24015, 24015)

    # A) three.js + libs + toon/paint/terrain/motion (ends before castdefs)
    main_chunks = [
        rng(src, 1, 22755),
        # renderer, scene, MAT, world/addW, ground plane, ridge terrain,
        # boulders, blobTree (+scatter), palm, roofGeo, house, haystack
        rng(src, 23186, 23479),
        # ribbon fn
        rng(src, 23496, 23517),
        # routeLine fn
        rng(src, 23520, 23554),
        # distant hills ring
        rng(src, 23558, 23564),
        # sky, clouds, hemi, sun
        rng(src, 23615, 23650),
        # character cards + fx cards system
        rng(src, 23651, 23737),
        # post chain + renderFrame start (rt, nd, ink, dof, applyLight .. setProgress)
        rng(src, 23738, 23876),
        # camera apply + applyLight + camR (slab/plug story hooks excluded)
        rng(src, 23885, 23893),
        # actors/cards/fx/clouds/sky + render passes + final export line
        # (24016 is the closing }; of renderFrame — must be included)
        rng(src, 23908, 24016),
    ]
    text = "\n".join(main_chunks)

    # edits inside extracted main code:
    # 1) actor ground height respects flat sets via GY (spec.js)
    gy_edits = [
        ("const y = a.y ?? groundAt(a.pos[0], a.pos[1], S.world.progress);",
         "const y = a.y ?? GY(a.pos[0], a.pos[1]);"),
        ("c.blob.position.set(a.pos[0], groundAt(a.pos[0], a.pos[1], S.world.progress) + 0.03, a.pos[1]);",
         "c.blob.position.set(a.pos[0], GY(a.pos[0], a.pos[1]) + 0.03, a.pos[1]);"),
    ]
    for old, new in gy_edits:
        assert old in text, f"GY edit target not found: {old[:60]}"
        text = text.replace(old, new)

    # 2) replace final toDataURL with caption-composited export
    old_ret = 'return canvas.toDataURL("image/jpeg", 0.95);'
    new_ret = (
        "capCtx.setTransform(1, 0, 0, 1, 0, 0);\n"
        "    capCtx.drawImage(canvas, 0, 0);\n"
        "    drawCaptions(capCtx, f);\n"
        "    return capCanvas.toDataURL(\"image/jpeg\", 0.95);"
    )
    assert old_ret in text, "toDataURL return not found in extracted main"
    text = text.replace(old_ret, new_ret)

    parts = [text]

    # C) spec layer
    parts.append("\n" + SPEC.read_text(encoding="utf-8"))

    # D) init: caption canvases + loadStory + ready gate
    parts.append("""
  // ── init2.js — story loader ────────────────────────────────────────────────
  var capCanvas = document.createElement("canvas");
  capCanvas.width = W;
  capCanvas.height = H;
  var capCtx = capCanvas.getContext("2d");
  window.STORY = null;
  window.ready = false;
  window.TOTAL = 1;
  window.loadStory = (spec) => {
    try {
      window.STORY = spec;
      buildStory(spec);
      window.TOTAL = Math.max(1, spec.total || window.TOTAL);
      window.ready = true;
      return "ok:" + window.TOTAL;
    } catch (e) {
      window.__errors.push("loadStory: " + (e && e.message ? e.message : e));
      window.ready = false;
      throw e;
    }
  };
  console.log("engine2 loaded, call window.loadStory(spec)");
  window.frameState = frameState; // exposed for debugging/tests
""")

    OUT.write_text("\n".join(parts) + "\n})();\n</script></body></html>\n", encoding="utf-8")
    size = OUT.stat().st_size / 1e6
    print(f"engine2.html written: {size:.1f} MB")

if __name__ == "__main__":
    main()
