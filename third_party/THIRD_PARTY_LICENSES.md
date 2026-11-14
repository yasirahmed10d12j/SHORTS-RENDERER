# Third-party licenses

- `engine_src/web/toonbase.js` — the `toon.ts` Pen library from
  https://github.com/mromidev/claude-animated-shorts (MIT), types stripped.
- `engine_src/web/dsp.py`, `instruments.py`, `sfx_gen.py` (not used in Phase 1) —
  same origin (MIT).
- `three.js` r160 — MIT (https://github.com/mrdoob/three.js).
- `esbuild` — MIT (build tool only).

The bundled `App/engine/app.js` is built from these files plus the engine
(`main.js`, `story.js`, `paint.js`, `motion.js`, `terrain.js`, `cast.js`,
`castdefs.js`) shipped with the cartoon-audio-short kit.
