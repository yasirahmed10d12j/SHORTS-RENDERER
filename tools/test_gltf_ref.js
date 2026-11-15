const fs = require("fs");
const vm = require("vm");
const path = require("path");

const E2 = "App/engine/engine2.html";
const GLB_DIR = "App/engine/models/cars";
const OUT_DIR = "tools/_preview";
if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

const html = fs.readFileSync(E2, "utf8");
const m = html.match(/<script[^>]*>([\s\S]*?)<\/script>/);
const code = m[1];

const GL_ENUM = { VERSION:7937, SHADING_LANGUAGE_VERSION:7938, VENDOR:7936, RENDERER:7937, MAX_TEXTURE_SIZE:16384 };
const magic = new Proxy(()=>{}, {
  get:(t,k)=>{
    if(k===Symbol.toPrimitive)return()=>1;
    if(k==="valueOf")return()=>1;
    if(k in GL_ENUM)return GL_ENUM[k];
    if(k==="getParameter"||k==="getString")return(p)=>p===7937?"WebGL 2.0":magic;
    if(k==="getShaderPrecisionFormat")return()=>({precision:1});
    if(k==="getExtension"||k==="getSupportedExtensions"||k==="getContextAttributes")return()=>null;
    return magic;
  },
  apply:()=>magic
});
const stub2d = ()=>new Proxy({}, { get:(t,k)=>(k==="measureText"?()=>({width:100}):(k==="canvas"?{width:1080,height:1920}:()=>stub2d())), set:()=>true });
const fakeCanvas = ()=>({ width:0, height:0, style:{}, getContext:(type)=>/webgl/i.test(type||"")?magic:stub2d(), toDataURL:()=>"", addEventListener:()=>{} });

const prelude = `
function fakeCanvas(){return {width:0,height:0,style:{},getContext:()=>stub2d(),toDataURL:()=>"",addEventListener:()=>{}};}
class WebGLRenderer{constructor(o){this.shadowMap={enabled:false};this.domElement=fakeCanvas();}setPixelRatio(){}setSize(){}setRenderTarget(){}getRenderTarget(){return null;}render(){}readRenderTargetPixels(){}compile(){}dispose(){}}
class WebGLRenderTarget{constructor(w,h){this.width=w;this.height=h;this.texture={};}}
`;

const ctx = {
  console:{log:s=>{},warn:()=>{},error:s=>process.stderr.write("E:"+s+"\n")},
  document:{createElement:t=>t==="canvas"?fakeCanvas():{},body:{appendChild:()=>{}},head:{appendChild:()=>{}},createElementNS:()=>fakeCanvas()},
  window:{}, requestAnimationFrame:()=>0, performance:{now:()=>Date.now()}, devicePixelRatio:1,
  XMLHttpRequest:class{open(){}send(){}}, fetch:()=>Promise.reject(new Error("no"))
};
ctx.window=ctx; ctx.self=ctx; ctx.globalThis=ctx;
vm.createContext(ctx);

try {
  vm.runInContext(prelude, ctx, {filename:"stubs"});
  vm.runInContext(code, ctx, {filename:"engine2"});
} catch(e) { console.error("load failed:", e.message); process.exit(1); }

// Load a real story spec that has a model prop + run full frame loop
const specs = JSON.parse(fs.readFileSync("App/specs.json", "utf8"));
const sid = "the-photograph-that-changed"; // uses sedan.glb
const spec = specs[sid];
console.log("Loading story:", sid, "with props:", spec.props?.filter(p=>p.kind==="model").map(p=>p.url));

(async () => {
  try {
    await vm.runInContext(`window.loadStory(${JSON.stringify(spec)})`, ctx);
    const TOTAL = vm.runInContext("window.TOTAL", ctx);
    console.log("Ready! TOTAL frames:", TOTAL);
    
    // Try rendering first few frames
    for (const f of [0, 50, 100]) {
      try {
        const result = vm.runInContext(`window.renderFrame(${f})`, ctx);
        console.log(`Frame ${f}: returned ${typeof result} (${String(result).slice(0,40)})`);
      } catch(e) {
        console.log(`Frame ${f} error: ${e.message}`);
      }
    }
  } catch(e) {
    console.error("loadStory error:", e.message);
  }
})();
