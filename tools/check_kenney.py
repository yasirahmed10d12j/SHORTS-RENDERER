import struct, zipfile, os

path = r'C:\Users\yasir ahmed\Downloads\kenney_car-kit.zip'
z = zipfile.ZipFile(path)

all_ok = True
for rel in sorted(z.namelist()):
    if not rel.endswith('.glb'):
        continue
    info = z.getinfo(rel)
    data = z.read(info.filename)
    
    assert data[:4] == b'glTF', f'BAD MAGIC: {rel}'
    ver = struct.unpack('<I', data[4:8])[0]
    tot_len = struct.unpack('<I', data[8:12])[0]
    pos = 12; nchunks = 0
    while pos + 8 <= len(data):
        clen = struct.unpack('<I', data[pos:pos+4])[0]
        ctype = struct.unpack('<I', data[pos+4:pos+8])[0]
        tag = bytes([ctype&0xff,(ctype>>8)&0xff,(ctype>>16)&0xff,(ctype>>24)&0xff]).decode('ascii','replace')
        nchunks += 1
        pos += 8 + clen
    
    ok = (ver == 2 and tot_len == len(data) and pos == len(data) and nchunks == 2)
    if not ok:
        all_ok = False
    print(f'{"OK" if ok else "BAD"} {len(data)//1024:5d}KB | {os.path.basename(rel)} v{ver} chunks={nchunks}')

print(f'\n{"ALL VALID" if all_ok else "SOME INVALID"} — {sum(1 for x in z.namelist() if x.endswith(".glb"))} glbs checked')