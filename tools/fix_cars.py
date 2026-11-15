import re

p = "tools/gen_specs.py"
s = open(p, encoding="utf-8").read()

# Revert car model props back to primitive car props
repls = [
    ('{"kind": "model", "url": "models/cars/sedan.glb", "x": -4.5, "z": 12, "ry": 0.15, "s": 1}',
     '{"kind": "car", "x": -4.5, "z": 12, "ry": 0.15}'),
    ('{"kind": "model", "url": "models/cars/sedan.glb", "x": 4.6, "z": 9, "ry": 1.6, "s": 1}',
     '{"kind": "car", "x": 4.6, "z": 9, "ry": 1.6}'),
    ('{"kind": "model", "url": "models/cars/suv.glb", "x": 7, "z": 3, "ry": -0.9, "s": 1}',
     '{"kind": "car", "x": 7, "z": 3, "ry": -0.9}'),
]
for a, b in repls:
    assert a in s, f"Not found: {a[:50]}"
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("Reverted car model props back to primitives")
