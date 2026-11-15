# GLTF/GLB Assets for engine2

Real 3D models from Kenney.nl (CC0). All validated as proper glTF 2.0 binary.

## Cars (`cars/`) — 50 models, ~5.4 MB total
Sedans, SUVs, trucks, buses, police cars, taxis, firetrucks, tractors, karts, wheels, debris parts.
Each model: 1-7 meshes, 6K-9K triangles, single PBR texture.

**Known issue**: `loader.load(url)` in WKWebView may fail silently due to XHR URL resolution differences between Node test env and iOS. Switching back to primitive car props for reliability. Keep GLB files for future fix.

## Buildings (`buildings/`) — 108 models, ~692 KB total
Modular 2×2×2m blocks: walls, windows, doors, roofs, corners, details.
Designed to be placed side-by-side like LEGO. Each is 1 mesh, low poly (~40-500 tris).

### Recommended usage
Place 2-4 blocks together to form larger structures:
- **House facade**: `building-corner-bottom.glb` + `window-white-large.glb` + `door-brown.glb` stacked
- **Ruined building**: Tilted `roof-slanted.glb` + rotated `building-block.glb` at angle
- **Tall tower**: Stack 2-3 `building-sample-tower-a.glb` vertically

### Already wired into stories
| Story | Props Added |
|-------|-------------|
| Mountain Man | roof-gable, window-white-large (cabin accent) |
| Search Party | door-brown, detail-ac-a (abandoned camp) |
| No Signal Forest | house-a (ruined silhouette), roof-slanted (fallen) |
| Town That Vanished | house-b, house-c (background ruins) |
| Lake | door-brown-window, window-round-top (cabin detail) |
| Cave Divers | window-white-large, debris-door (broken cave wall) |
| Dog & Wall | door-white, window-brown (house facade) |

## How to add more models
1. Drop `.glb` file into `App/engine/models/<folder>/`
2. Add to spec in `tools/gen_specs.py` OVERRIDES dict:
   ```python
   "props": [{"kind": "model", "url": "models/<folder>/<file>.glb",
              "x": 0, "z": 8, "y": 0, "ry": 0, "s": 1}]
   ```
3. Run `python tools/gen_specs.py` to regenerate specs.json
4. Commit and push → Codemagic builds new IPA
