p = "tools/build_engine2.py"
s = open(p, encoding="utf-8").read()
old = '    ]\n\n    # capture the big grass ground plane as coreGround'
new = '    ]\n\n    text = "\\n".join(main_chunks)\n\n    # capture the big grass ground plane as coreGround'
assert old in s
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
print("ok")
PY