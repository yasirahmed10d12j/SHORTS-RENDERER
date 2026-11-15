# 3D assets (GLTF/GLB) for engine2

Drop any `.glb` (or `.gltf` + bin) file here and it ships with the app
automatically (App/engine is a folder reference in project.yml).

Use one in a story spec (App/specs.json or tools/gen_specs.py) via a prop:

    { "kind": "model", "url": "models/my-asset.glb",
      "x": 4, "z": 12, "y": 0, "ry": 0, "s": 1 }

- url is relative to engine2.html (i.e. App/engine/)
- toon shading is NOT applied to GLTF materials; pick models whose look
  fits the cartoon style, or set material overrides in spec.js buildModel
- keep each model small (< 2 MB) - total bundle size matters for IPA
- recommended CC0 sources: poly.pizza, sketchfab.com (CC0 filter),
  kenney.nl, quaternius.com

`_test-box.glb` is a 1.6 KB Khronos sample cube used only to validate the
GLTF loading pipeline end-to-end. Remove it once real assets are in place.
