import struct, json, os

folder = 'App/engine/models/cars'
files = sorted(f for f in os.listdir(folder) if f.endswith('.glb'))
grand_total_tris = 0
for f in files:
    data = open(folder+'/'+f, 'rb').read()
    pos = 12; json_data = None
    while pos + 8 <= len(data):
        clen = struct.unpack('<I', data[pos:pos+4])[0]
        ctype = struct.unpack('<I', data[pos+4:pos+8])[0]
        if ctype == 0x4E4F534A:
            json_data = data[pos+8:pos+8+clen].decode('utf-8')
        pos += 8 + clen
    d = json.loads(json_data)
    accs = d.get('accessors', [])
    tris = 0
    for m in d.get('meshes', []):
        for prim in m.get('primitives', []):
            idx = prim.get('indices')
            if isinstance(idx, int) and idx < len(accs):
                count = accs[idx].get('count', 0)
                mode = accs[idx].get('mode', 4)  # 4=TRIANGLES
                tris += count // (2 if mode == 6 else 1)  # LINES=6 -> 2 verts per line
    grand_total_tris += tris
    print(f'{f:30s} nodes={len(d["nodes"])} meshes={len(d["meshes"])} tris={tris:>6d} {len(data)//1024:>5d}KB')
print(f'\ntotal: {len(files)} glbs, ~{sum(len(open(folder+"/"+x,"rb").read()) for x in files)/1024/1024:.1f} MB, {grand_total_tris:,} triangles all cars')
