// Parse Kenney GLBs with GLTFLoader (no WebGL needed — just structural validation)
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const E2 = path.resolve(__dirname, "..", "App", "engine", "engine2.html");
const GLB_DIR = path.resolve(__dirname, "..", "App", "engine", "models", "cars");
const OUT_DIR = path.resolve(__dirname, "..", "tools", "_preview");
if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

const html = fs.readFileSync(E2, "utf8");
const m = html.match(/<script[^>]*>([\s\S]*?)<\/script>/);
if (!m) { console.error("no <script>"); process.exit(1); }
const code = m[1];

// Same magic proxy as test_engine2_full.js
const GL_ENUM = {
  VERSION: 7937, SHADING_LANGUAGE_VERSION: 7938, VENDOR: 7936, RENDERER: 7937,
  MAX_TEXTURE_SIZE: 16384, MAX_VERTEX_ATTRIBS: 16, MAX_VARYING_VECTORS: 30,
  MAX_VERTEX_UNIFORM_VECTORS: 1024, MAX_FRAGMENT_UNIFORM_VECTORS: 1024,
  MAX_TEXTURE_IMAGE_UNITS: 16, MAX_VERTEX_TEXTURE_IMAGE_UNITS: 16,
  MAX_COMBINED_TEXTURE_IMAGE_UNITS: 32, MAX_RENDERBUFFER_SIZE: 16384,
  MAX_SAMPLES: 16, UNMASKED_VENDOR_WEBGL: 37445, UNMASKED_RENDERER_WEBGL: 37446,
};
const magic = new Proxy(function () {}, {
  get: (t, k) => {
    if (k === Symbol.toPrimitive) return () => 1;
    if (k === "valueOf") return () => 1;
    if (k === "toString") return () => "1";
    if (k in GL_ENUM) return GL_ENUM[k];
    if (k === "getParameter" || k === "getString") return (p) => (p === 7937 ? "WebGL 2.0 (stub)" : p === 7938 ? "GLSL ES 3.00 (stub)" : p === 7936 ? "stub vendor" : magic);
    if (k === "getShaderPrecisionFormat") return () => ({ precision: 1, rangeMin: 127, rangeMax: 127 });
    if (k === "getExtension" || k === "getSupportedExtensions") return () => null;
    if (k === "getContextAttributes") return () => ({});
    return magic;
  },
  apply: () => magic,
});
const stub2d = () => new Proxy({}, {
  get: (t, k) => {
    if (k === "measureText") return () => ({ width: 100 });
    if (k === "canvas") return { width: 1080, height: 1920 };
    return () => stub2d();
  },
  set: () => true,
});
const fakeCanvas = () => ({
  width: 0, height: 0, style: {},
  getContext: (type) => (/webgl/i.test(type || "") ? magic : stub2d()),
  toDataURL: () => "data:image/jpeg;base64,AAAA",
  addEventListener: () => {},
});
const prelude = `
function fakeCanvas() {
  return { width: 0, height: 0, style: {}, getContext: () => stub2d(),
    toDataURL: () => "data:image/jpeg;base64,AAAA", addEventListener: () => {} };
}
class WebGLRenderer {
  constructor(opts) {
    this.shadowMap = { enabled: false, type: 0 };
    this.outputColorSpace = "";
    this.domElement = (opts && opts.canvas) || fakeCanvas();
  }
  setPixelRatio() {} setSize() {} setRenderTarget() {}
  getRenderTarget() { return null; }
  render() {} readRenderTargetPixels() {} compile() {} dispose() {}
}
class WebGLRenderTarget { constructor(w, h) { this.width = w; this.height = h; this.texture = {}; } }
`;

const ctx = {
  console: { log: (s) => {}, warn: () => {}, error: (s) => process.stderr.write("ERR: " + s + "\n") },
  document: { createElement: (tag) => (tag === "canvas" ? fakeCanvas() : {}), body: { appendChild: () => {} }, head: { appendChild: () => {} }, createElementNS: () => fakeCanvas() },
  window: {}, requestAnimationFrame: () => 0, performance: { now: () => Date.now() }, devicePixelRatio: 1,
  XMLHttpRequest: class { open() {} send() {} }, fetch: () => Promise.reject(new Error("no fetch")),
};
ctx.window = ctx; ctx.self = ctx; ctx.globalThis = ctx;
vm.createContext(ctx);

try {
  vm.runInContext(prelude, ctx, { filename: "stubs" });
  vm.runInContext(code, ctx, { filename: "engine2" });
  console.log("engine2 loaded OK\n");
} catch(e) {
  console.error("engine2 failed:", e.message);
  process.exit(1);
}

// Test GLTFLoader.parse on real GLB binary data
const loader = vm.runInContext("new GLTFLoader()", ctx);
let pass = 0, fail = 0;

const testFiles = ["sedan.glb", "suv.glb", "ambulance.glb", "taxi.glb", "police.glb"];
for (const f of testFiles) {
  const fullPath = path.join(GLB_DIR, f);
  if (!fs.existsSync(fullPath)) { console.log(`[${f}] SKIP (not found)`); continue; }
  const buf = fs.readFileSync(fullPath).buffer;
  try {
    const result = loader.parse(buf, "");
    const scene = result.scene;
    const nodeCount = scene ? scene.children.length : 0;
    let meshCount = 0;
    if (scene) scene.traverse((c) => { if (c.isMesh) meshCount++; });
    console.log(`[${f}] PARSE OK  nodes=${nodeCount} meshes=${meshCount} size=${buf.byteLength/1024}KB`);
    pass++;
  } catch(e) {
    console.error(`[${f}] PARSE FAIL: ${e.message}`);
    fail++;
  }
}

console.log(`\nResult: ${pass} passed, ${fail} failed`);

// Also test the async loadModel path from spec.js
if (pass > 0) {
  // Build a minimal spec with model prop
  const spec = {
    id: "car-preview", total: 60, flatGround: true,
    set: { type: "outdoor", style: "forest" },
    scenes: [{ n: 1, dur: 2, caption: "A sedan appears.", cam: { type: "static" }, actors: [] }],
    props: [{ kind: "model", url: "models/cars/sedan.glb", x: 0, z: 8, ry: 0, s: 1.2 }]
  };
  (async () => {
    try {
      await vm.runInContext(`window.loadStory(${JSON.stringify(spec)})`, ctx);
      const ready = vm.runInContext("window.ready", ctx);
      console.log(`\nloadStory with sedan.glb prop: ready=${ready}`);
      if (ready) {
        // Try rendering a frame
        try {
          const jpeg = vm.runInContext("window.jpegFrame(0)", ctx);
          console.log("jpegFrame returned OK (base64 JPEG)");
          // Save preview
          const base64 = jpeg.replace(/^data:image\/jpeg;base64,/, "");
          const buf2 = Buffer.from(base64, "base64");
          if (buf2.length > 100) {
            fs.writeFileSync(path.join(OUT_DIR, "frame_car_preview.jpg"), buf2);
            console.log(`Saved frame to tools/_preview/frame_car_preview.jpg (${buf2.length} bytes)`);
          }
        } catch(e2) {
          console.log("jpegFrame: " + e2.message);
        }
      }
    } catch(e) {
      console.error("loadStory failed:", e.message);
    }
  })();
}
