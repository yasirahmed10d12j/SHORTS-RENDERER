// Headless smoke test for engine2's spec layer (no WebGL).
//
// Extracts the pure-JS parts of engine.html (terrain.js, motion.js, rng) and
// evaluates the assembled spec.js + init.js against three.js class stubs, then:
//   1. loads a test story spec (loadStory)
//   2. samples frameState at many frames (catches ReferenceError / logic bugs)
//   3. checks TOTAL, shot boundaries, actor opts sanity
//
// Usage:  node tools/test_spec_layer.js  (after python tools/build_engine2.py)
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ROOT = path.resolve(__dirname, "..");
const ENGINE = path.join(ROOT, "App", "engine", "engine.html");
const E2 = path.join(ROOT, "App", "engine", "engine2.html");

const src = fs.readFileSync(ENGINE, "utf8").split("\n");
const slice = (a, b) => src.slice(a - 1, b).join("\n");

// pure-JS engine parts: terrain.js .. motion.js end (22638-22755), rng (22365-22368)
const pure = [
  slice(22365, 22368),
  slice(22638, 22755),
].join("\n");

// three.js + canvas stubs: enough surface for spec.js to run
class FakeObj {
  constructor(...a) { this.args = a; this.position = { set: () => {}, copy: () => {} }; this.rotation = { set: () => {} }; this.scale = { set: () => {}, setScalar: () => {} }; this.visible = true; this.userData = {}; }
  add() {}
  remove() {}
  traverse() {}
}
const three = {};
for (const C of ["Scene", "Mesh", "Group", "PlaneGeometry", "BoxGeometry", "CylinderGeometry",
  "ConeGeometry", "SphereGeometry", "DodecahedronGeometry", "IcosahedronGeometry", "BufferGeometry",
  "ShaderMaterial", "MeshToonMaterial", "MeshBasicMaterial", "Color", "Vector2", "Vector3",
  "CanvasTexture", "DataTexture", "WebGLRenderTarget", "OrthographicCamera", "PerspectiveCamera",
  "Fog", "Object3D", "BufferAttribute", "CatmullRomCurve3"]) {
  three[C] = class extends FakeObj { constructor(...a) { super(...a); if (C === "Scene") this.fog = {}; } };
}
three.Shape = class { constructor() {} };
three.DoubleSide = 2;
three.AdditiveBlending = 2;
three.BackSide = 1;
three.SRGBColorSpace = "srgb";
three.LinearSRGBColorSpace = "linear";
three.RedFormat = 1;
three.NearestFilter = 1;
three.RepeatWrapping = 1;
three.HalfFloatType = 1;
three.FloatType = 1;
three.PCFSoftShadowMap = 1;

const ctx = {
  console: { log: () => {}, warn: () => {}, error: (m) => { process.stderr.write("console.error: " + m + "\n"); } },
  document: {
    createElement: () => ({ width: 0, height: 0, getContext: () => stub2d() }),
  },
  window: {},
  Math,
  ...three,
};
function stub2d() {
  return new Proxy({}, { get: (t, k) => (k === "measureText" ? () => ({ width: 100 }) : () => {}) });
}
ctx.window = ctx; // window === globalThis in engine code pattern
vm.createContext(ctx);

function run(code, label) {
  try {
    vm.runInContext(code, ctx, { filename: label });
  } catch (e) {
    console.error(`FAILED in ${label}: ${e.stack}`);
    process.exit(1);
  }
}

run(pure, "terrain+motion+rng");

// stubs the spec layer expects from main core (in the real engine these are
// defined BEFORE spec.js — keep the same order here)
run(`
  var scene = new Scene();
  var world = [];
  var MAT = new Proxy({}, { get: () => new MeshToonMaterial({}) });
  var addW = (m) => { world.push(m); return m; };
  var toon = (o) => new MeshToonMaterial(o);
  var ctex = () => new CanvasTexture();
  var house = () => new Group();
  var blobTree = () => new Group();
  var ribbon = () => {};
  var routeLine = () => ({ mesh: new Mesh(), mat: { uniforms: {} } });
  var W = 1080, H = 1920, PX = 1;
  window.__errors = [];
`, "stubs");

// engine2 spec layer + init: everything after the extracted main core
const e2 = fs.readFileSync(E2, "utf8");
const specStart = e2.indexOf("// ── spec2.js");
const initAnchor = e2.indexOf("engine2 loaded");
const closeTag = e2.indexOf("})();", initAnchor);
if (specStart < 0 || initAnchor < 0 || closeTag < 0) { console.error("engine2.html markers missing — rebuild first"); process.exit(1); }
run(e2.slice(specStart, closeTag), "spec.js+init.js");

var capCtx = null, capCanvas = { width: 1080, height: 1920 };
var drawCaptions = () => {};

// ── test spec: covers every set type + camera types ───────────────────────
const spec = {
  id: "test", flatGround: true,
  set: { type: "sea", towerH: 16, beamSpeed: 0.006 },
  scenes: [
    { n: 1, dur: 3, set: "sea", light: "night", caption: "In 1972, a keeper wrote his final log.",
      cam: { type: "pushIn", from: [8, 2, 12], to: [6, 2, 9], look: [0, 4, 0], fov: 44 },
      actors: [{ outfit: "keeper", kind: "front", pos: [2, 6], expr: "calm", seed: 3 }],
      fx: [{ kind: "glow", pos: [0, 14, 0], size: 6, at: [0.2, 0.9] }] },
    { n: 2, dur: 2, light: "lamp", caption: "Routine at first. Weather. Fuel.",
      cam: { type: "orbit", center: [0, 0, 0], r: 8, h: 3, a0: 10, a1: 60 },
      actors: [{ outfit: "keeper", kind: "side", pos: [1, 5], dir: [0, -1], mode: "walk", seed: 4 }] },
    { n: 3, dur: 2, light: "moonlit", caption: "There is a second light on the water.",
      cam: { type: "pan", pos: [6, 2, 8], lookFrom: [0, 3, 0], lookTo: [-10, 2, -6], fov: 40 },
      actors: [] },
    { n: 4, dur: 2, light: "night", caption: "It only watches.", cam: { type: "static", pos: [4, 1.7, 6], look: [0, 1.4, 0] },
      actors: [{ outfit: "keeper", kind: "front", pos: [0, 4], mode: "stand", expr: "scared" }] },
  ],
};
const totalFrames = spec.scenes.reduce((s, x) => s + x.dur, 0) * 30;

run(`window.loadStory(${JSON.stringify(spec)})`, "loadStory");

const total = vm.runInContext("window.TOTAL", ctx);
if (total !== totalFrames) { console.error(`TOTAL mismatch: ${total} != ${totalFrames}`); process.exit(1); }

// sample every 7th frame — exercises camFromSpec, actorOpts, fxFromSpec, lightMix
let bad = 0;
for (let f = 0; f < total; f += 7) {
  try {
    const s = vm.runInContext(`JSON.stringify((() => { const S = frameState(${f}); return { shot: S.shot, camok: !!S.cam && isFinite(S.cam.pos[0]) && isFinite(S.cam.pos[1]) && isFinite(S.cam.pos[2]) && isFinite(S.cam.look[2]), actors: S.actors.length, fx: S.fx.length, lightok: !!S.light.sun, flash: S.flash }; })())`, ctx);
    const j = JSON.parse(s);
    if (!j.camok || !j.lightok) { console.error(`frame ${f}: bad state ${s}`); bad++; }
  } catch (e) {
    console.error(`frame ${f} FAILED: ${e.message}`);
    bad++;
    if (bad > 5) break;
  }
}
if (bad) { console.error(`${bad} bad frames`); process.exit(1); }

// set builder coverage: build each set type once
for (const [i, set] of [
  { type: "interior", style: "room" },
  { type: "interior", style: "corridor", doors: 6 },
  { type: "interior", style: "morgue", drawers: true, gurney: true },
  { type: "interior", style: "bus" },
  { type: "outdoor", style: "forest" },
  { type: "outdoor", style: "town", houses: 6 },
  { type: "outdoor", style: "tower" },
  { type: "sea" },
  { type: "lake" },
  { type: "cave", gear: true },
].entries()) {
  try {
    vm.runInContext(`window.loadStory({ id: "t${i}", set: ${JSON.stringify(set)}, scenes: [{ n: 1, dur: 2, caption: "x", cam: { type: "static" }, actors: [] }] })`, ctx);
    console.log(`set ${set.type}/${set.style || ""}: OK (meshes=${ctx.world ? "" : ""}${vm.runInContext("storyMeshes.length", ctx)})`);
  } catch (e) {
    console.error(`set ${set.type}/${set.style || ""} FAILED: ${e.stack}`);
    process.exit(1);
  }
}

console.log(`\nPASS — TOTAL=${total}, all sets build, ${Math.ceil(total / 7)} frames sampled clean`);
