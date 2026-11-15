// Full engine2.html smoke test in Node (no WebGL): runs the ENTIRE inline
// script — three.js bundle + extracted main core + spec.js + init.js — with
// stubs for DOM canvas and WebGLRenderer. Catches ReferenceErrors from the
// excluded engine.html slices (shortRoad/routes, slab/plug, VILLAGE, story.js).
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const E2 = path.resolve(__dirname, "..", "App", "engine", "engine2.html");
const SPECS = path.resolve(__dirname, "..", "App", "specs.json");

const html = fs.readFileSync(E2, "utf8");
const m = html.match(/<script[^>]*>([\s\S]*?)<\/script>/);
if (!m) { console.error("no <script> block found"); process.exit(1); }
const code = m[1];

// ── stubs ─────────────────────────────────────────────────────────────────
// magic: self-returning callable proxy whose primitive value is 1 — covers
// gl.getShaderPrecisionFormat(...).precision > 0, truthiness checks, etc.
// GL numeric constants three.js reads during init
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
    if (k === "getParameter" || k === "getString") {
      // 7937=VERSION, 7938=SHADING_LANGUAGE_VERSION, 7936=VENDOR
      return (p) => (p === 7937 ? "WebGL 2.0 (stub)" : p === 7938 ? "WebGL GLSL ES 3.00 (stub)" : p === 7936 ? "stub vendor" : magic);
    }
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
    // gradients etc: return a chainable stub object
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

// whole file is one IIFE (three.js + main core + spec + init) — must run as
// one unit. Pre-inject WebGL stubs on the context; if the bundle defines its
// own, they shadow ours (fine either way).
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
  setPixelRatio() {}
  setSize() {}
  setRenderTarget() {}
  getRenderTarget() { return null; }
  render() {}
  readRenderTargetPixels() {}
  compile() {}
  dispose() {}
}
class WebGLRenderTarget { constructor(w, h) { this.width = w; this.height = h; this.texture = {}; } }
`;

const ctx = {
  console: { log: (s) => { if (/error/i.test(s)) process.stderr.write(s + "\n"); }, warn: () => {}, error: (s) => process.stderr.write("console.error: " + s + "\n") },
  document: {
    createElement: (tag) => (tag === "canvas" ? fakeCanvas() : {}),
    body: { appendChild: () => {} },
    head: { appendChild: () => {} },
    createElementNS: () => fakeCanvas(),
  },
  window: {},
  requestAnimationFrame: () => 0,
  performance: { now: () => Date.now() },
  devicePixelRatio: 1,
  XMLHttpRequest: class { open() {} send() {} },
  fetch: () => Promise.reject(new Error("no fetch in test")),
};
ctx.window = ctx;
ctx.self = ctx;
ctx.globalThis = ctx;
vm.createContext(ctx);

// Run: single unit with prelude stubs on the context.
function run(c, label) {
  try { return vm.runInContext(c, ctx, { filename: label }); }
  catch (e) { throw e; }
}

try {
  vm.runInContext(prelude, ctx, { filename: "webgl-stubs" });
  vm.runInContext(code, ctx, { filename: "engine2-full" });
} catch (e) {
  console.error("engine2 script failed: " + e.stack.split("\n").slice(0, 6).join("\n"));
  process.exit(1);
}

// load a real story spec and render-frame state at several frames
const specs = JSON.parse(fs.readFileSync(SPECS, "utf8"));
const sid = "the-lighthouse-keepers-last-log";
run(`window.loadStory(${JSON.stringify(specs[sid])})`, "loadStory");
const TOTAL = vm.runInContext("window.TOTAL", ctx);
if (vm.runInContext("window.ready", ctx) !== true) { console.error("ready not true"); process.exit(1); }

// frameState must return sane camera for sampled frames
let bad = 0;
for (const f of [0, 30, 500, 1000, 1500, TOTAL - 1]) {
  try {
    const ok = vm.runInContext(`(function(){ const S = window.frameState(${f}); return isFinite(S.cam.pos[0]) && !!S.light.sun; })()`, ctx);
    if (!ok) { console.error(`frame ${f}: bad state`); bad++; }
  } catch (e) { console.error(`frameState(${f}) threw: ${e.message}`); bad++; }
}
if (bad) process.exit(1);
console.log(`FULL ENGINE2 SMOKE PASS — TOTAL=${TOTAL}, three.js + main core + spec.js all run clean`);
