#!/usr/bin/env bash
# Rebuilds App/engine/app.js + App/engine/engine.html from engine_src/web
# (only needed after engine edits). The generated files are ALSO committed,
# so CI builds work without this step.
#
# IMPORTANT: the bundle is INLINED into engine.html — WKWebView refuses to
# load `<script type="module" src="...">` from file:// (no CORS origin).
set -e
cd "$(dirname "$0")/engine_src/web"
[ -f package.json ] || printf '{ "name": "short", "private": true, "type": "module" }\n' > package.json
# the app bridge: total frame count on window
grep -q "window.TOTAL" main.js || printf '\nwindow.TOTAL = TOTAL; // app bridge: total frame count\n' >> main.js
# voice-driven duration scaling bridge (set window.VOICE_DURATION before rendering)
grep -q "VOICE_DURATION" main.js || cat >> main.js <<'EOF'

// app bridge: optional voice-driven duration scaling (set window.VOICE_DURATION before rendering)
(() => {
  const orig = window.renderFrame;
  const storyTotal = window.TOTAL;
  window.renderFrame = (f) => {
    const vd = window.VOICE_DURATION;
    const scale = vd && vd > 0 ? storyTotal / (vd * 30) : 1;
    return orig(Math.min(Math.round(f * scale), storyTotal));
  };
})();
EOF
# the character library is toonbase.js + cast.js concatenated (see kit/tools/setup.sh)
cat toonbase.js cast.js > toon.js
npm install --no-audit --no-fund three@0.160.0 esbuild@0.24.0 >/dev/null
npx esbuild main.js --bundle --outfile=app.js --log-level=warning
OUT="$(cd "$(dirname "$0")/App/engine" && pwd)"
mkdir -p "$OUT"
# escape any literal </script inside JS strings, then inline the whole bundle
perl -0777 -pe 's/<\/script/<\\/script/g' app.js > "$OUT/.app.js.tmp"
{ printf '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#000}canvas{display:block}</style></head><body><script>'
  cat "$OUT/.app.js.tmp"
  printf '</script></body></html>'
} > "$OUT/engine.html"
rm -f "$OUT/.app.js.tmp"
echo "engine bundle ready: App/engine/app.js + App/engine/engine.html (inline)"
