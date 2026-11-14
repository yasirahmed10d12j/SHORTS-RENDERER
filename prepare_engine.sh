#!/usr/bin/env bash
# Rebuilds App/engine/app.js from engine_src/web (only needed after engine edits).
# The generated bundle is ALSO committed, so CI builds work without this step.
set -e
cd "$(dirname "$0")/engine_src/web"
[ -f package.json ] || printf '{ "name": "short", "private": true, "type": "module" }\n' > package.json
# the app bridge: total frame count on window
grep -q "window.TOTAL" main.js || printf '\nwindow.TOTAL = TOTAL; // app bridge: total frame count\n' >> main.js
# the character library is toonbase.js + cast.js concatenated (see kit/tools/setup.sh)
cat toonbase.js cast.js > toon.js
npm install --no-audit --no-fund three@0.160.0 esbuild@0.24.0 >/dev/null
npx esbuild main.js --bundle --outfile=app.js --log-level=warning
mkdir -p "$(cd "$(dirname "$0")/App/engine" && pwd)"
cp app.js "$(dirname "$0")/App/engine/app.js"
echo "engine bundle ready: App/engine/app.js"
