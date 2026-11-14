# SHORTS-RENDERER — cartoon-audio-short engine on iPhone

Windows/Mac-free iOS app: bundles the **cartoon-audio-short** kit's browser engine
(three.js WebGL toon world) in a `WKWebView` and renders 1080x1920 @ 30 fps straight
into an MP4 with `AVAssetWriter` — the phone's GPU does what SwiftShader did on the PC.

**Phase 1 (this repo):** the bundled "Mountain Man" example story renders end to end
and lands in Photos as `short.mp4`.

## Repo layout

```
project.yml            XcodeGen project definition (xcodegen generate -> .xcodeproj)
codemagic.yaml         Codemagic workflow: unsigned IPA, no dev account needed
prepare_engine.sh      rebuilds App/engine/app.js from engine_src/web (optional; bundle is committed)
engine_src/web/        the kit's engine sources (main.js patched with window.TOTAL bridge)
App/                   SwiftUI app: engine loader, render loop, MP4 writer
third_party/           attribution for MIT-licensed code
```

## Build on Codemagic (from Windows)

1. Push this repo to GitHub (already done via git push).
2. Sign up at https://codemagic.io with GitHub, add application -> **Other** ->
   select this repo -> workflow **`unsigned-ipa`** -> Start build.
3. When it finishes, download **`build/CartoonShort-unsigned.ipa`** from the build's
   artifact list (or from the emailed link).

## Install on your iPhone 11 Pro Max (free Apple ID signing)

⚠️ Free-Apple-ID signing facts: the app **expires every 7 days** (re-sign to keep
using it), max **3 signed apps** per Apple ID, and reinstalling with the same
Apple ID + bundle id keeps the app's data.

- **3uTools** (Windows): Apps -> Self-sign / Normal sign -> pick the IPA -> enter
  your Apple ID + password -> install. 3uTools is third-party and closed-source;
  only use it if you accept entering your Apple ID credentials there.
- **Sideloadly** (open-source alternative, same free-Apple-ID 7-day signing).
- **AltStore / SideStore** (on-device re-signing via AltServer).

## Phase 2 (next)

- Voiceover: record in-app (AVAudioRecorder) + SFSpeechRecognizer word timings
  (replaces `timing.py`)
- Music/SFX synths (`dsp.py`, `instruments.py`) ported to Swift or OfflineAudioContext
- Mix rule: music/SFX at 50% of voice gated RMS; final MP4 = video + audio track

## Phase 3

LLM-generated `story.js`/`cast.js` injected into the WKWebView per new topic —
the engine takes every story as pure functions of the frame, so hot-swapping is safe.
