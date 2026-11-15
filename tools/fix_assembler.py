import re
p = "tools/build_engine2.py"
lines = open(p, encoding="utf-8").read().splitlines()
# find the misplaced lines
for i, l in enumerate(lines):
    if "gltf = (Path" in l:
        print("gltf line idx", i)
# remove lines 67-69 (0-based 66-68)
start = next(i for i, l in enumerate(lines) if "gltf = (Path" in l) - 1
end = start + 3
del lines[start:end]
# insert gltf read right before 'parts = [text]'
for i, l in enumerate(lines):
    if l.strip() == "parts = [text]":
        lines.insert(i, "    gltf = (Path(__file__).resolve().parent / \"engine2\" / \"GLTFLoader.js\").read_text(encoding=\"utf-8\")")
        lines.insert(i + 1, "    parts = [text, gltf]")
        # remove original parts = [text] line (now at i+2)
        del lines[i + 2]
        break
open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("done")