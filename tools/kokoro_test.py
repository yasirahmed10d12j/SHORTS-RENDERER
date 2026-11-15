"""Quick kokoro test: generate one short line, save wav + mp3."""
import os, time, subprocess
from kokoro import KPipeline
import soundfile as sf
import torch

t0 = time.time()
pipe = KPipeline(lang_code='a')  # American English
print(f"pipeline ready in {time.time()-t0:.1f}s")

text = "In 1972, a lighthouse keeper wrote his final log entry. It was not found for fifty years."
t0 = time.time()
chunks = list(pipe(text, voice='am_michael', speed=1.0))
print(f"synth took {time.time()-t0:.1f}s, chunks={len(chunks)}")

audio = torch.cat([c.audio for c in chunks]).numpy()
os.makedirs("test_out", exist_ok=True)
sf.write("test_out/sample.wav", audio, 24000)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "test_out/sample.wav",
                "-codec:a", "libmp3lame", "-b:a", "128k", "-ac", "1", "test_out/sample.mp3"], check=True)
print("wav bytes:", os.path.getsize("test_out/sample.wav"), "mp3 bytes:", os.path.getsize("test_out/sample.mp3"))
print("duration:", len(audio) / 24000.0, "s")
