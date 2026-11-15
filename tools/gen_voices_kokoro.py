"""Generate bundled voiceovers for stories.json using Kokoro TTS.

Reads App/stories.json, synthesizes each scene narration with Kokoro
(voice: am_michael — deep male US narrator), converts to 128k mono MP3
via ffmpeg, and writes to App/voices/<story-id>/scene-XX.mp3.

Resumable: existing MP3s are skipped.
Usage:  python tools/gen_voices_kokoro.py
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import soundfile as sf
import torch
from kokoro import KPipeline

ROOT = Path(__file__).resolve().parent.parent
STORIES = ROOT / "App" / "stories.json"
OUTDIR = ROOT / "App" / "voices"

VOICE = "am_michael"   # deep, calm US male — good for suspense narration
SPEED = 0.95           # slightly slow = more dramatic
SR = 24000             # kokoro sample rate

def synth(text: str) -> "torch.Tensor":
    chunks = [r.audio for r in pipe(text, voice=VOICE, speed=SPEED) if r.audio is not None]
    if not chunks:
        raise RuntimeError("no audio produced")
    return torch.cat(chunks)

def to_mp3(wav_path: Path, mp3_path: Path):
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
         "-codec:a", "libmp3lame", "-b:a", "128k", "-ac", "1", str(mp3_path)],
        check=True,
    )

def main():
    global pipe
    print("loading kokoro pipeline…")
    t0 = time.time()
    pipe = KPipeline(lang_code='a')
    print(f"ready in {time.time()-t0:.1f}s")

    stories = json.loads(STORIES.read_text(encoding="utf-8"))
    total_scenes = sum(len(s["scenes"]) for s in stories)
    done = 0
    total_dur = 0.0
    t_start = time.time()
    failures = []

    for story in stories:
        sid = story["id"]
        folder = OUTDIR / sid
        folder.mkdir(parents=True, exist_ok=True)
        for sc in story["scenes"]:
            done += 1
            mp3 = folder / f"scene-{sc['n']:02d}.mp3"
            if mp3.exists() and mp3.stat().st_size > 10_000:
                total_dur += 0  # duration counted below for new only
                continue
            tag = f"[{done}/{total_scenes}] {sid}/scene-{sc['n']:02d}"
            try:
                t0 = time.time()
                audio = synth(sc["narration"])
                wav = mp3.with_suffix(".wav")
                sf.write(wav, audio.numpy(), SR)
                to_mp3(wav, mp3)
                wav.unlink()
                dur = len(audio) / SR
                total_dur += dur
                print(f"{tag}  {dur:5.1f}s  ({time.time()-t0:.1f}s)")
            except Exception as e:
                failures.append(f"{tag}: {e}")
                print(f"{tag}  FAILED: {e}")

    size_mb = sum(f.stat().st_size for f in OUTDIR.rglob("*.mp3")) / 1e6
    print(f"\nDone in {time.time()-t_start:.0f}s — {size_mb:.1f} MB total in App/voices/")
    if failures:
        print(f"{len(failures)} FAILURES:")
        for f in failures:
            print(" ", f)
        sys.exit(1)

if __name__ == "__main__":
    main()
