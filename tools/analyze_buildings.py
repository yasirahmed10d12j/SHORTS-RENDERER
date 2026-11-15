import struct, json, os

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
    best_extents = [0,0,0]
    for ai, acc in enumerate(accs):
        mn, mx = acc.get('min'), acc.get('max')
        if mn and mx and len(mn) >= 3:
            ext = [mx[i]-mn[i] for i in range(3)]
            if sum(ext) > sum(best_extents):
                best_extents = ext
    tris = sum(sum(p.get('indices',[])//3 for p in m.get('primitives',[]) if isinstance(p.get('indices'),int)) for m in d.get('meshes',[]))
    return {
        'name': os.path.basename(path),
        'nodes': len(d.get('nodes',[])),
        'meshes': len(d.get('meshes',[])),
        'tris': tris,
        'bounds': best_extents,
        'size_kb': len(data)//1024
    }

folder = 'App/engine/models/buildings'
files = sorted(os.listdir(folder))
results = []
for f in files:
    if not f.endswith('.glb'): continue
    try:
        r = analyze(folder+'/'+f)
        results.append(r)
    except: pass

# Sort by total bounds (biggest first)
results.sort(key=lambda x: sum(x['bounds']), reverse=True)
print("Top 20 biggest buildings:")
for r in results[:20]:
    print(f"  {r['name']:45s} {r['size_kb']:4d}KB nodes={r['nodes']} meshes={r['meshes']} tris={r['tris']:5d} bounds=[{r['bounds'][0]:.1f},{r['bounds'][1]:.1f},{r['bounds'][2]:.1f}]")

print("\nTotal:", len(results), "buildings,", sum(r['size_kb'] for r in results), "KB total")
