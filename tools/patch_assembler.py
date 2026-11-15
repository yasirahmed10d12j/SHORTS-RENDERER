p = "tools/build_engine2.py"
s = open(p, encoding="utf-8").read()
# ensure parts = [text] exists before spec layer append
old = '    # C) spec layer\n    parts.append("\\n" + SPEC.read_text(encoding="utf-8"))'
new = ('    gltf = (Path(__file__).resolve().parent / "engine2" / "GLTFLoader.js").read_text(encoding="utf-8")\n'
       '    parts = [text, gltf]\n\n'
       '    # C) spec layer\n    parts.append("\\n" + SPEC.read_text(encoding="utf-8"))')
assert old in s, "anchor missing"
s = s.replace(old, new)
open(p, "w", encoding="utf-8").write(s)
print("ok")