// Validate every story spec in App/specs.json against the engine2 spec layer.
// Same harness as test_spec_layer.js but loops all 20 stories and samples
// frames across the FULL timeline of each (catches shot-boundary bugs).
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ROOT = path.resolve(__dirname, "..");
const ENGINE = path.join(ROOT, "App", "engine", "engine.html");
const E2 = path.join(ROOT, "App", "engine", "engine2.html");
const SPECS = path.join(ROOT, "App", "specs.json");

const src = fs.readFileSync(ENGINE, "utf8").split("\n");
const slice = (a, b) => src.slice(a - 1, b).join("\n");
const pure = [slice(22365, 22368), slice(22638, 22755)].join("\n");

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

const stub2d = () => new Proxy({}, { get: (t, k) => (k === "measureText" ? () => ({ width: 100 }) : () => {}) });
const ctx = {
  console: { log: () => {}, warn: () => {}, error: (m) => process.stderr.write("console.error: " + m + "\n") },
  document: { createElement: () => ({ width: 0, height: 0, getContext: () => stub2d() }) },
  Math,
  ...three,
};
ctx.window = ctx;
vm.createContext(ctx);
const run = (code, label) => {
  try { vm.runInContext(code, ctx, { filename: label }); }
  catch (e) { console.error(`FAILED in ${label}: ${e.stack}`); process.exit(1); }
};

run(pure, "terrain+motion+rng");
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

const e2 = fs.readFileSync(E2, "utf8");
const specStart = e2.indexOf("// ── spec2.js");
const initAnchor = e2.indexOf("engine2 loaded");
const closeTag = e2.indexOf("})();", initAnchor);
run(e2.slice(specStart, closeTag), "spec.js+init.js");

const specs = JSON.parse(fs.readFileSync(SPECS, "utf8"));
let fail = 0;
for (const [sid, spec] of Object.entries(specs)) {
  try {
    run(`window.loadStory(${JSON.stringify(spec)})`, sid);
    const total = vm.runInContext("window.TOTAL", ctx);
    const frames = [];
    for (let f = 0; f < total; f += 11) {
      const s = vm.runInContext(`JSON.stringify((() => { const S = frameState(${f}); return { cam: S.cam.pos.concat(S.cam.look), light: !!S.light.sun, actors: S.actors.length, fx: S.fx.length }; })())`, ctx);
      const j = JSON.parse(s);
      if (!j.cam.every(isFinite) || !j.light) { console.error(`${sid} frame ${f}: bad state`); fail++; break; }
      frames.push(j);
    }
    const caps = vm.runInContext("STORY._caps.length", ctx);
    console.log(`${sid}: OK total=${total} sampled=${frames.length} caps=${caps} meshes=${vm.runInContext("storyMeshes.length", ctx)}`);
  } catch (e) {
    console.error(`${sid} FAILED: ${e.message}`);
    fail++;
  }
}
if (fail) { console.error(`${fail} story(ies) failed`); process.exit(1); }
console.log(`\nALL ${Object.keys(specs).length} SPECS PASS`);
