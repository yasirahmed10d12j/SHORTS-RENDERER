import re
p = "tools/engine2/GLTFLoader.js"
s = open(p, encoding="utf-8").read()
s = re.sub(r"import\s*\{[^}]*\}\s*from\s*'three';\s*\n", "", s, flags=re.S)
s = re.sub(r"import\s*\{[^}]*\}\s*from\s*'\.\./utils/BufferGeometryUtils\.js';\s*\n", "", s, flags=re.S)
s = "var toTrianglesDrawMode = (geometry, mode) => geometry;\n" + s
open(p, "w", encoding="utf-8").write(s)
print("done; lines:", s.count(chr(10)))