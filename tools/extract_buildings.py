import zipfile, os, struct, json

z = zipfile.ZipFile(r'C:\Users\yasir ahmed\Downloads\kenney_modular-buildings.zip')
out_dir = 'App/engine/models/buildings'
os.makedirs(out_dir, exist_ok=True)

count = 0
for info in z.infolist():
    if info.filename.lower().endswith('.glb'):
        data = z.read(info)
        if data[:4] != b'glTF':
            print(f'SKIP bad magic: {info.filename}')
            continue
        name = info.filename.split('/')[-1]
        open(os.path.join(out_dir, name), 'wb').write(data)
        count += 1

print(f'Extracted {count} GLB files to {out_dir}')

# Quick analysis of sample house/tower models
def analyze(path):
    data = open(path, 'rb').read()
    pos = 12; json_data = None
    while pos + 8 <= len(data):
        clen = struct.unpack('<I', data[pos:pos+4])[0]
        ctype = struct.unpack('<I', data[pos+4:pos+8])[0]
        if ctype == 0x4E4F534A: json_data = data[pos+8:pos+8+clen].decode('utf-8')
        pos += 8 + clen
    d = json.loads(json_data)
    accs = d.get('accessors', [])
    # Find largest bounding box from POSITION accessors
    best_extents = [0,0,0]
    for ai, acc in enumerate(accs):
        mn, mx = acc.get('min'), acc.get('max')
        if mn and mx and len(mn) >= 3:
            ext = [mx[i]-mn[i] for i in range(3)]
            if sum(ext) > sum(best_extents):
                best_extents = ext
    tris = 0
    for m in d.get('meshes', []):
        for prim in m.get('primitives', []):
            idx = prim.get('indices')
            if isinstance(idx, int) and idx < len(accs):
                tris += accs[idx].get('count', 0) // 3
    print(f'  {os.path.basename(path):40s} nodes={len(d["nodes"])} meshes={len(d["meshes"])} tris={tris:>5d} bounds=[{best_extents[0]:.1f},{best_extents[1]:.1f},{best_extents[2]:.1f}]')

samples = ['building-sample-house-a.glb', 'building-sample-house-b.glb', 
           'building-sample-house-c.glb', 'building-sample-tower-a.glb',
           'building-sample-tower-b.glb', 'building-sample-tower-d.glb',
           'door-brown.glb', 'window-white-large.glb', 'roof-gable.glb']
for f in samples:
    fp = out_dir + '/' + f
    if os.path.exists(fp):
        analyze(fp)
    else:
        print(f'  MISSING: {f}')
