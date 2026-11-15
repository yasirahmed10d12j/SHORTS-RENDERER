import struct, json

def analyze(path):
    data = open(path, 'rb').read()
    pos = 12; json_data = None
    while pos + 8 <= len(data):
        clen = struct.unpack('<I', data[pos:pos+4])[0]
        ctype = struct.unpack('<I', data[pos+4:pos+8])[0]
        if ctype == 0x4E4F534A: json_data = data[pos+8:pos+8+clen].decode('utf-8')
        pos += 8 + clen
    d = json.loads(json_data)
    
    print(f'\n=== {path.split("/")[-1]} ===')
    accs = d.get('accessors', [])
    # Find position accessor with range
    for ai, acc in enumerate(accs):
        mn, mx = acc.get('min'), acc.get('max')
        if mn and mx and len(mn) >= 3:
            extents = [mx[i]-mn[i] for i in range(3)]
            center = [(mx[i]+mn[i])/2 for i in range(3)]
            print(f'  acc[{ai}] POS: size={extents} center={center}')
    
    print(f'  Nodes ({len(d.get("nodes",[]))}):')
    for ni, node in enumerate(d.get('nodes', [])):
        name = node.get('name', f'n{ni}')
        mesh = node.get('mesh')
        trans = node.get('translation') or []
        scale = node.get('scale') or [1,1,1]
        parts = []
        if trans and any(v != 0 for v in trans): parts.append(f'pos({trans})')
        if scale != [1,1,1]: parts.append(f'scl({scale})')
        if mesh is not None: parts.append(f'mesh={mesh}')
        print(f'    n{ni}: "{name}" {" ".join(parts)}')

# Analyze key buildings
for f in ['building-sample-house-a.glb', 'building-sample-house-b.glb', 
          'building-sample-house-c.glb', 'building-sample-tower-a.glb']:
    analyze('App/engine/models/cars/' + f)  # will fail - need to extract buildings first
