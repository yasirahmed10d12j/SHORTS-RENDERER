  // ── spec2.js — data-driven story layer ─────────────────────────────────────
  // window.loadStory(spec) builds sets + shots from a JSON spec. All 20 stories
  // render through this: sets are template-built, scenes map to camera/actor
  // scripts declaratively. Narration is the voice; captions drawn per scene.

  // ── lighting presets ──────────────────────────────────────────────────────
  var LPR = {
    day:     { az: 112, el: 50, sun: [1.2, 1.12, 0.97], amb: [0.36, 0.37, 0.46], gnd: [0.32, 0.27, 0.2], top: "#3f80d4", mid: "#8fb7e6", hor: "#c4d8ee", fog: [120, 1300], sat: 1.1, lift: [0.02, 0.025, 0.05], gain: [1, 1, 1], card: [1, 1, 1], cloud: [1, 1, 1], disc: 0 },
    morning: { az: 28, el: 20, sun: [1.38, 1.04, 0.74], amb: [0.34, 0.34, 0.47], gnd: [0.3, 0.24, 0.19], top: "#4f8ad8", mid: "#a6c3e4", hor: "#f0dcbc", fog: [110, 1200], sat: 1.12, lift: [0.025, 0.02, 0.05], gain: [1.02, 1, 0.97], card: [1.03, 0.98, 0.93], cloud: [1, 0.93, 0.86], disc: 3e-3 },
    golden:  { az: 168, el: 10, sun: [1.62, 0.98, 0.52], amb: [0.31, 0.28, 0.48], gnd: [0.27, 0.21, 0.19], top: "#6d7cc4", mid: "#e6a98e", hor: "#ffcf8e", fog: [90, 1100], sat: 1.14, lift: [0.03, 0.02, 0.06], gain: [1.04, 0.99, 0.94], card: [1.06, 0.94, 0.82], cloud: [1, 0.84, 0.72], disc: 4e-3 },
    night:   { az: 135, el: 42, sun: [0.34, 0.44, 0.72], amb: [0.15, 0.19, 0.34], gnd: [0.08, 0.09, 0.15], top: "#0d1838", mid: "#1f3058", hor: "#34496f", fog: [80, 900], sat: 0.82, lift: [0.01, 0.02, 0.05], gain: [0.95, 1, 1.08], card: [0.56, 0.63, 0.88], cloud: [0.32, 0.4, 0.58], disc: 0 },
    moonlit: { az: 135, el: 55, sun: [0.55, 0.62, 0.85], amb: [0.2, 0.24, 0.4], gnd: [0.1, 0.11, 0.18], top: "#0b1430", mid: "#22345c", hor: "#3a4d74", fog: [90, 950], sat: 0.78, lift: [0.01, 0.02, 0.06], gain: [0.95, 1, 1.1], card: [0.62, 0.68, 0.9], cloud: [0.36, 0.44, 0.6], disc: 0 },
    lamp:    { az: 90, el: 60, sun: [0.85, 0.66, 0.42], amb: [0.26, 0.2, 0.16], gnd: [0.12, 0.08, 0.05], top: "#0c0c14", mid: "#241a18", hor: "#452c1c", fog: [30, 220], sat: 1.02, lift: [0.02, 0.012, 0.01], gain: [1.05, 0.98, 0.9], card: [1.05, 0.92, 0.78], cloud: [0.2, 0.16, 0.14], disc: 0 },
    fluoro:  { az: 90, el: 60, sun: [0.72, 0.78, 0.82], amb: [0.3, 0.32, 0.34], gnd: [0.14, 0.15, 0.16], top: "#101418", mid: "#1e262c", hor: "#33404a", fog: [30, 200], sat: 0.85, lift: [0.01, 0.015, 0.02], gain: [0.98, 1, 1.04], card: [0.95, 1, 1.05], cloud: [0.2, 0.22, 0.24], disc: 0 },
    dawnsea: { az: 30, el: 12, sun: [1.3, 0.85, 0.62], amb: [0.3, 0.28, 0.4], gnd: [0.16, 0.14, 0.16], top: "#243a66", mid: "#7c6f96", hor: "#e8a97c", fog: [70, 900], sat: 1.05, lift: [0.03, 0.02, 0.05], gain: [1.04, 0.97, 0.95], card: [1.05, 0.9, 0.82], cloud: [0.8, 0.7, 0.66], disc: 3e-3 },
    cave:    { az: 90, el: 40, sun: [0.5, 0.55, 0.7], amb: [0.12, 0.14, 0.2], gnd: [0.05, 0.05, 0.08], top: "#05070c", mid: "#0c1220", hor: "#182238", fog: [20, 130], sat: 0.8, lift: [0.005, 0.008, 0.015], gain: [0.9, 0.95, 1.1], card: [0.6, 0.66, 0.85], cloud: [0.1, 0.1, 0.12], disc: 0 },
    street:  { az: 135, el: 42, sun: [0.4, 0.42, 0.6], amb: [0.16, 0.17, 0.24], gnd: [0.08, 0.08, 0.1], top: "#0d1328", mid: "#1c2842", hor: "#334058", fog: [60, 500], sat: 0.85, lift: [0.01, 0.015, 0.03], gain: [0.95, 0.98, 1.08], card: [0.7, 0.72, 0.88], cloud: [0.25, 0.28, 0.36], disc: 0 },
    memory:  { az: 160, el: 13, sun: [1, 0.66, 0.58], amb: [0.23, 0.25, 0.43], gnd: [0.15, 0.14, 0.21], top: "#2a3a72", mid: "#7c6f96", hor: "#d29a84", fog: [80, 900], sat: 0.7, lift: [0.03, 0.03, 0.07], gain: [1, 0.97, 1.02], card: [0.85, 0.79, 0.88], cloud: [0.72, 0.6, 0.7], disc: 3e-3 }
  };
  var hexMix = (a, b, t) => {
    const A = parseInt(a.slice(1), 16), B = parseInt(b.slice(1), 16);
    const ch = (s) => Math.round((A >> s & 255) * (1 - t) + (B >> s & 255) * t).toString(16).padStart(2, "0");
    return `#${ch(16)}${ch(8)}${ch(0)}`;
  };
  var blendL = (a, b, t) => {
    const o = {};
    for (const k of Object.keys(a)) {
      const x = a[k], y = b[k];
      o[k] = typeof x === "string" ? hexMix(x, y, t) : Array.isArray(x) ? x.map((v, i) => lerp3(v, y[i], t)) : lerp3(x, y, t);
    }
    let d = b.az - a.az;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    o.az = a.az + d * t;
    return o;
  };
  var lightMix = (name, f) => {
    const seq = name;
    if (typeof seq === "string") return LPR[seq] || LPR.night;
    if (f <= seq[0][0]) return LPR[seq[0][1]] || LPR.night;
    for (let i = 0; i < seq.length - 1; i++) if (f <= seq[i + 1][0]) return blendL(LPR[seq[i][1]] || LPR.night, LPR[seq[i + 1][1]] || LPR.night, smooth(lin(seq[i][0], seq[i + 1][0], f)));
    return LPR[seq[seq.length - 1][1]] || LPR.night;
  };
  var sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  var norm = (a) => {
    const l = Math.hypot(...a) || 1;
    return a.map((v) => v / l);
  };
  var cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  var dist = (a, b) => Math.hypot(...sub(a, b));
  var camRight = (c) => norm(cross(sub(c.look, c.pos), [0, 1, 0]));
  var camUp = (c) => norm(cross(camRight(c), sub(c.look, c.pos)));
  var lightAng = (c, L, mirror = 1) => {
    const d = [Math.cos(L.el * Math.PI / 180) * Math.cos(L.az * Math.PI / 180), Math.sin(L.el * Math.PI / 180), Math.cos(L.el * Math.PI / 180) * Math.sin(L.az * Math.PI / 180)];
    const r = camRight(c), u = camUp(c);
    const sx = (d[0] * r[0] + d[1] * r[1] + d[2] * r[2]) * mirror, sy = d[0] * u[0] + d[1] * u[1] + d[2] * u[2];
    return q(Math.atan2(-Math.max(0.25, sy), sx), 0.35);
  };
  var mirrorOf = (c, dir) => {
    const r = camRight(c);
    return dir[0] * r[0] + dir[1] * r[2] < 0 ? -1 : 1;
  };
  var strike = (f, fi, down = 5, raise = 14, from = 1) => {
    if (f >= fi) return 1 - 0.12 * Math.sin(Math.min(1, (f - fi) / 6) * Math.PI);
    if (f >= fi - down) return easeIn((f - (fi - down)) / down);
    if (f >= fi - down - raise) return lerp3(from, 0, smooth((f - (fi - down - raise)) / raise));
    return from;
  };
  var ext = (f, a, b) => f >= a && f < b;
  var ht = (x, z, p) => groundAt(x, z, p);
  var headPt = (c, pos, mirror, fwd = 0.8, up = 0.95) => {
    const r = camRight(c);
    return [pos[0] + r[0] * fwd * mirror, pos[1] + up, pos[2] + r[2] * fwd * mirror];
  };
  var CAMNOW = null;
  var pullTo = (p, d = 0.9) => {
    if (!CAMNOW) return p;
    const v = sub(CAMNOW.pos, p), l = Math.hypot(...v) || 1;
    return add3(p, v.map((x) => x * Math.min(d, l * 0.5) / l));
  };
  var fxHit = (out, id, f, fi, p0, size = 1.1, seed = 1) => {
    const p = pullTo(p0);
    if (f >= fi && f < fi + 9) out.push({ id: id + "b", kind: "burst", pos: p, size, t: q((f - fi + 1) / 9, 0.11) });
    if (f >= fi && f < fi + 14) out.push({ id: id + "c", kind: "chips", pos: p, size: size * 1.3, t: q((f - fi + 1) / 14, 0.07), seed });
    if (f >= fi + 1 && f < fi + 22) out.push({ id: id + "p", kind: "puff", pos: [p0[0], p0[1] - 0.55, p0[2]], size: size, t: q((f - fi) / 22, 0.05), alpha: 0.75 });
  };
  var walkPhase = (d) => q(d / 1.25, 1 / 24);
  // engine2 sets are flat (GY = 0): trees/ribbons/props placed by the core
  // helpers must land on y=0 too, so groundAt is routed through flatGround.
  var groundAtFull = (typeof groundAt === "function") ? groundAt : (() => 0);
  groundAt = (x, z, p) => (window.STORY && window.STORY.flatGround) ? 0 : groundAtFull(x, z, p);
  var GY = (x, z) => (window.STORY && STORY.flatGround) ? 0 : groundAt(x, z, 0);
  var hammerCycle = (f, period, off = 0) => {
    const t = ((f - off) % period + period) % period / period;
    if (t < 0.12) return 1;
    if (t < 0.72) return 1 - smooth((t - 0.12) / 0.6);
    return easeIn((t - 0.72) / 0.28);
  };

  // ── set builders ──────────────────────────────────────────────────────────
  // Each builder constructs meshes ONCE per story load. All go through addS()
  // so a new story can clear them. Anchors placed at spec-driven positions.

  var storyMeshes = [];
  var addS = (mesh, cast = true, recv = true) => {
    mesh.castShadow = cast;
    mesh.receiveShadow = recv;
    storyMeshes.push(mesh);
    return mesh;
  };
  var clearStory = () => {
    for (const m of storyMeshes) {
      scene.remove(m);
      const i = world.indexOf(m);
      if (i >= 0) world.splice(i, 1);
    }
    storyMeshes = [];
  };

  var boxS = (w, h, d, mat, x, y, z, ry = 0) => {
    const m = addS(new Mesh(new BoxGeometry(w, h, d), mat));
    m.position.set(x, y, z);
    m.rotation.y = ry;
    return m;
  };

  // scatter: deterministic per-set random placement helper
  var scatter = (n, rd, fn) => { for (let i = 0; i < n; i++) fn(rd); };

  // interior set: room | corridor | morgue | bus (style param)
  var buildInterior = (s) => {
    const st = s.style || "room";
    const wallMat = toon({ color: s.wall ? s.wall : st === "bus" ? "#3a4152" : "#57503f" });
    const ceilMat = toon({ color: st === "bus" ? "#c8bfae" : "#8a8072" });
    const wallC = s.wallC ?? "#6b6152";
    const R = s.room || { w: 9, d: 9, h: 3.4 };
    const cx = s.cx ?? 0, cz = s.cz ?? 0;
    const mkWall = (x, y, z, w, h, d, mat) => {
      const m = addS(new Mesh(new BoxGeometry(w, h, d), mat || wallMat));
      m.position.set(cx + x, y, cz + z);
      return m;
    };
    if (st === "corridor" || st === "morgue") {
      const len = s.len ?? 40, wid = s.wid ?? 4.4, hh = s.hh ?? 3.2;
      const floor = addS(new Mesh(new PlaneGeometry(wid, len), toon({ color: st === "morgue" ? "#9aa2a8" : "#7a6f5c" })));
      floor.rotation.x = -Math.PI / 2;
      floor.position.set(cx, 0.01, cz);
      const ceil = addS(new Mesh(new PlaneGeometry(wid, len), ceilMat));
      ceil.rotation.x = Math.PI / 2;
      ceil.position.set(cx, hh, cz);
      mkWall(-wid / 2, hh / 2, 0, 0.3, hh, len, wallMat);
      mkWall(wid / 2, hh / 2, 0, 0.3, hh, len, wallMat);
      mkWall(0, hh / 2, -len / 2, wid, hh, 0.3, wallMat);
      const doorMat = st === "morgue" ? toon({ color: "#aab4bc" }) : toon({ color: s.doorCol ?? "#4a3a28" });
      const doors = s.doors ?? 6;
      for (let i = 0; i < doors; i++) {
        const dz = -len / 2 + 3 + (len - 6) * i / Math.max(1, doors - 1);
        for (const sd of [-1, 1]) {
          const d = new Mesh(new BoxGeometry(0.12, 2.2, 1.05), doorMat);
          d.position.set(cx + sd * (wid / 2 - 0.16), 1.1, cz + dz);
          addS(d, false, true);
          const nTex = (() => {
            const c = document.createElement("canvas");
            c.width = 128; c.height = 64;
            const g = c.getContext("2d");
            g.fillStyle = st === "morgue" ? "#2a3238" : "#d8cfb8";
            g.fillRect(0, 0, 128, 64);
            g.fillStyle = st === "morgue" ? "#cfe2ea" : "#3a2f20";
            g.font = "bold 40px Arial";
            g.textAlign = "center"; g.textBaseline = "middle";
            g.fillText(String(s.doorStart ?? 1 + i).padStart(2, "0"), 64, 34);
            return ctex(c, false);
          })();
          const pl = new Mesh(new PlaneGeometry(0.4, 0.2), new MeshBasicMaterial({ map: nTex }));
          pl.position.set(cx + sd * (wid / 2 - 0.24), 2, cz + dz + 0.62);
          addS(pl, false, false);
        }
        const lampM = new Mesh(new PlaneGeometry(1.3, 0.28), new MeshBasicMaterial({ color: 16775684 }));
        lampM.rotation.x = Math.PI / 2;
        lampM.position.set(cx, hh - 0.25, cz + dz);
        addS(lampM, false, false);
      }
      if (st === "morgue" && (s.drawers ?? true)) {
        for (let r = 0; r < 4; r++) for (let c2 = 0; c2 < 6; c2++) {
          const dr = boxS(1.15, 0.55, 0.5, toon({ color: "#b8c2c8" }), cx + wid / 2 - 0.45, 0.6 + r * 0.62, cz - len / 2 + 1.4 + c2 * 1.25);
          dr.rotation.y = Math.PI / 2;
          if (r === 2 && c2 === 3) dr.rotation.y = Math.PI / 2 + 0.5; // one drawer ajar
        }
      }
      if (s.gurney) {
        boxS(0.9, 0.12, 2.1, toon({ color: "#d8dee2" }), cx - 0.8, 0.85, cz + 3);
        for (const [gx, gz] of [[-1.2, 2.1], [-0.4, 2.1], [-1.2, 3.9], [-0.4, 3.9]]) boxS(0.08, 0.8, 0.08, toon({ color: "#5a6066" }), cx + gx, 0.4, cz + gz);
      }
      if (s.endLight) {
        const gl = new Mesh(new SphereGeometry(0.3, 10, 8), new MeshBasicMaterial({ color: 16769796 }));
        gl.position.set(cx, 1.4, cz - len / 2 + 0.4);
        addS(gl, false, false);
      }
      return;
    }
    if (st === "bus") {
      const len = s.len ?? 12, wid = s.wid ?? 3.2, hh = s.hh ?? 2.9;
      const floor = addS(new Mesh(new PlaneGeometry(wid, len), toon({ color: "#4a4238" })));
      floor.rotation.x = -Math.PI / 2;
      floor.position.set(cx, 0.01, cz);
      const ceil = addS(new Mesh(new PlaneGeometry(wid, len), ceilMat));
      ceil.rotation.x = Math.PI / 2;
      ceil.position.set(cx, hh, cz);
      mkWall(-wid / 2, hh / 2, 0, 0.3, hh, len, wallMat);
      mkWall(wid / 2, hh / 2, 0, 0.3, hh, len, wallMat);
      mkWall(0, hh / 2, -len / 2, wid, hh, 0.3, wallMat);
      mkWall(0, hh / 2, len / 2, wid, hh, 0.3, toon({ color: "#22262e" }));
      for (let i = 0; i < 7; i++) {
        const zz = -len / 2 + 1.6 + i * (len - 3) / 6;
        for (const sd of [-1, 1]) {
          boxS(0.9, 0.5, 1.1, toon({ color: "#8a4a3c" }), cx + sd * (wid / 2 - 1), 0.55, cz + zz);
          boxS(0.9, 0.6, 0.14, toon({ color: "#8a4a3c" }), cx + sd * (wid / 2 - 1), 1.1, cz + zz - 0.48);
          const win = new Mesh(new PlaneGeometry(1.2, 0.9), new MeshBasicMaterial({ color: 34052 }));
          win.position.set(cx + sd * (wid / 2 - 0.05), 1.7, cz + zz);
          win.rotation.y = sd * Math.PI / 2;
          addS(win, false, false);
        }
        const pole = new Mesh(new CylinderGeometry(0.045, 0.045, hh - 0.5, 6), toon({ color: "#b8bcc0" }));
        pole.position.set(cx, (hh - 0.5) / 2, cz + zz + 0.55);
        addS(pole, false, true);
      }
      return;
    }
    // room
    const floorM = addS(new Mesh(new PlaneGeometry(R.w, R.d), toon({ color: s.floorCol ?? "#6a5a42" })));
    floorM.rotation.x = -Math.PI / 2;
    floorM.position.set(cx, 0.01, cz);
    const ceil2 = addS(new Mesh(new PlaneGeometry(R.w, R.d), ceilMat));
    ceil2.rotation.x = Math.PI / 2;
    ceil2.position.set(cx, R.h, cz);
    mkWall(-R.w / 2, R.h / 2, 0, 0.3, R.h, R.d, wallMat);
    mkWall(R.w / 2, R.h / 2, 0, 0.3, R.h, R.d, wallMat);
    mkWall(0, R.h / 2, R.d / 2, R.w, R.h, 0.3, wallMat);
    mkWall(0, R.h / 2, -R.d / 2, R.w, R.h, 0.3, wallMat);
    // window (emissive pane + curtains) on back wall
    const wy = s.windowY ?? 1.6;
    const win = new Mesh(new PlaneGeometry(1.7, 1.3), new MeshBasicMaterial({ color: s.windowCol ?? 12169248 }));
    win.position.set(cx + (s.windowX ?? -1.6), wy, cz + R.d / 2 - 0.16);
    addS(win, false, false);
    for (const sd of [-1, 1]) {
      const cur = new Mesh(new PlaneGeometry(0.5, 1.7), toon({ color: s.curtainCol ?? "#5a4a3a" }));
      cur.position.set(cx + (s.windowX ?? -1.6) + sd * 1.05, wy + 0.1, cz + R.d / 2 - 0.12);
      addS(cur, false, false);
    }
    // door
    const d2 = new Mesh(new BoxGeometry(1, 2.2, 0.12), toon({ color: s.doorCol ?? "#4a3a28" }));
    d2.position.set(cx + (s.doorX ?? 2.6), 1.1, cz - R.d / 2 + 0.18);
    addS(d2, false, true);
    // bed
    if (s.bed ?? true) {
      const bx = s.bedX ?? -2.6, bz = s.bedZ ?? -1.4;
      boxS(1.7, 0.45, 2.3, toon({ color: "#5a4a38" }), cx + bx, 0.32, cz + bz);
      boxS(1.6, 0.22, 2.2, toon({ color: "#c8bca8" }), cx + bx, 0.62, cz + bz);
      boxS(1.3, 0.2, 0.6, toon({ color: "#e2d8c4" }), cx + bx, 0.78, cz + bz - 0.7);
      boxS(1.7, 0.9, 0.14, toon({ color: "#5a4a38" }), cx + bx, 0.75, cz + bz - 1.2);
    }
    // side table + lamp
    if (s.lamp ?? true) {
      const lx = s.lampX ?? 3.2, lz = s.lampZ ?? -3.2;
      boxS(0.7, 0.6, 0.7, toon({ color: "#4a3c2c" }), cx + lx, 0.3, cz + lz);
      const st2 = new Mesh(new CylinderGeometry(0.04, 0.07, 0.5, 6), toon({ color: "#3a3028" }));
      st2.position.set(cx + lx, 0.85, cz + lz);
      addS(st2, false, true);
      const sh = new Mesh(new ConeGeometry(0.32, 0.42, 10, 1, true), toon({ color: "#e8d8a8", side: DoubleSide }));
      sh.position.set(cx + lx, 1.24, cz + lz);
      addS(sh, false, false);
      const glow = new Mesh(new SphereGeometry(0.22, 8, 6), new MeshBasicMaterial({ color: 16774628 }));
      glow.position.set(cx + lx, 1.2, cz + lz);
      addS(glow, false, false);
    }
    if (s.tv ?? false) {
      boxS(1.6, 0.9, 0.1, toon({ color: "#14161c" }), cx, 1.6, cz - R.d / 2 + 0.25);
      boxS(1.2, 0.5, 0.4, toon({ color: "#3a3228" }), cx, 0.3, cz - R.d / 2 + 0.4);
    }
    if (s.rug ?? true) {
      const rug = addS(new Mesh(new PlaneGeometry(3.4, 2.2), toon({ color: "#7a4438" })), false, true);
      rug.rotation.x = -Math.PI / 2;
      rug.position.set(cx, 0.03, cz + 0.6);
    }
    // wardrobe on left wall + framed picture on right wall
    if (s.wardrobe ?? true) {
      boxS(0.75, 2.1, 1.25, toon({ color: "#5a4634" }), cx - R.w / 2 + 0.45, 1.05, cz + 1.6);
      boxS(0.04, 1.9, 0.05, toon({ color: "#3a2e20" }), cx - R.w / 2 + 0.85, 1.05, cz + 1.6);
    }
    if (s.picture ?? true) {
      const pic = new Mesh(new PlaneGeometry(0.8, 0.6), toon({ color: "#c8a860" }));
      pic.position.set(cx + R.w / 2 - 0.17, 1.75, cz - 1.2);
      pic.rotation.y = -Math.PI / 2;
      addS(pic, false, false);
      boxS(0.06, 0.72, 0.92, toon({ color: "#4a3826" }), cx + R.w / 2 - 0.19, 1.75, cz - 1.2);
    }
  };

  // outdoor set: forest | road | town | tower | ridge
  var buildOutdoor = (s) => {
    const st = s.style || "forest";
    const rd = rng((s.seed ?? 7) * 9973 + 11);
    if (st === "forest") {
      scatter(s.trees ?? 90, rd, (r) => {
        const x = -70 + r() * 140, z = -55 + r() * 110;
        if (Math.hypot(x, z - 20) < 8) return; // clearing for actors
        blobTree(x, z, 0.9 + r() * 1.6, r() < 0.5 ? MAT.leaf : MAT.leaf2);
      });
      if (s.path ?? true) ribbon([[0, -50], [0.4, -20], [-0.3, 10], [0.5, 40], [0.2, 70]], 3.2, MAT.dirt);
      if (s.cabin) house(-9, 14, 5.5, 4.4, 2.9, Math.PI / 2.4, 1);
      scatter(s.rocks ?? 14, rd, (r) => {
        const x = -60 + r() * 120, z = -50 + r() * 100;
        const m = new Mesh(new DodecahedronGeometry(1, 0), MAT.boulder);
        const sc = 0.5 + r() * 1.4;
        m.scale.set(sc, sc * 0.7, sc);
        m.rotation.set(r() * 3, r() * 3, r() * 3);
        m.position.set(x, 0.15, z);
        addS(m);
      });
    } else if (st === "road" || st === "town") {
      const roadPts = [[0, -80], [0.5, -40], [-0.6, 0], [0.7, 40], [0, 80]];
      ribbon(roadPts, 7, MAT.lane, 0.06);
      const hn = s.houses ?? (st === "town" ? 8 : 3);
      for (let i = 0; i < hn; i++) {
        const side = i % 2 ? 1 : -1, zz = -60 + i * (120 / hn);
        house(side * (9 + rd() * 4), zz, 5 + rd() * 2.5, 4.2 + rd() * 1.5, 2.9 + rd() * 0.8, side < 0 ? Math.PI / 2 : -Math.PI / 2, Math.floor(rd() * 3));
      }
      scatter(s.lamps ?? 4, rd, (r) => {
        const zz = -50 + r() * 100;
        const p = new Mesh(new CylinderGeometry(0.09, 0.12, 5.2, 6), MAT.trunk);
        p.position.set(5.6, 2.6, zz);
        addS(p);
        const head2 = new Mesh(new SphereGeometry(0.3, 8, 6), new MeshBasicMaterial({ color: 16774628 }));
        head2.position.set(5.6, 5.3, zz);
        addS(head2, false, false);
      });
      scatter(s.trees ?? 20, rd, (r) => blobTree(-60 + r() * 120, -70 + r() * 140, 1 + r() * 1.2, MAT.leaf, 1.6));
    } else if (st === "tower") {
      if (s.fence ?? true) {
        for (let i = 0; i < 14; i++) {
          const a = i / 14 * Math.PI * 2;
          boxS(0.12, 1.5, 0.12, toon({ color: "#6a6a72" }), Math.cos(a) * 16, 0.75, Math.sin(a) * 16 + 6);
        }
      }
      const legs = 4, R2 = 1.7, H2 = 22;
      for (let lv = 0; lv < 10; lv++) {
        const y = lv * (H2 / 10), r3 = R2 * (1 - lv / 14);
        for (let l = 0; l < legs; l++) {
          const a = l / legs * Math.PI * 2 + (lv % 2) * 0.3;
          const bar = new Mesh(new CylinderGeometry(0.06, 0.06, H2 / 10 + 0.4, 5), toon({ color: "#8a2a24" }));
          bar.position.set(Math.cos(a) * r3, y + H2 / 20, Math.sin(a) * r3);
          addS(bar);
        }
      }
      const beacon = new Mesh(new SphereGeometry(0.35, 10, 8), new MeshBasicMaterial({ color: 16580352 }));
      beacon.position.set(0, H2 + 0.5, 0);
      addS(beacon, false, false);
      // shed
      boxS(3, 2.4, 2.6, toon({ color: "#7a7468" }), 8, 1.2, -4);
      boxS(3.4, 0.18, 3, toon({ color: "#4a4038" }), 8, 2.5, -4);
      boxS(0.9, 1.8, 0.08, toon({ color: "#3a3630" }), 8, 0.9, -2.65);
      scatter(s.rocks ?? 10, rd, (r) => {
        const m = new Mesh(new DodecahedronGeometry(1, 0), MAT.boulder);
        const sc = 0.4 + r() * 1.1;
        m.scale.set(sc, sc * 0.6, sc);
        m.rotation.set(r() * 3, r() * 3, r() * 3);
        m.position.set(-30 + r() * 60, 0.12, -30 + r() * 60);
        addS(m);
      });
    }
  };

  // sea set: lighthouse on rocks + beam
  var buildSea = (s) => {
    const rd = rng((s.seed ?? 3) * 7717 + 5);
    // sea plane
    const sea = addS(new Mesh(new PlaneGeometry(1200, 1200), toon({ color: s.seaCol ?? "#1d4e6e" })), false, true);
    sea.rotation.x = -Math.PI / 2;
    sea.position.set(0, 0.02, 0);
    // rock island
    for (let i = 0; i < 16; i++) {
      const m = new Mesh(new DodecahedronGeometry(1, 0), MAT.boulder);
      const sc = 2 + rd() * 5;
      m.scale.set(sc, sc * (0.5 + rd() * 0.4), sc * (0.7 + rd() * 0.6));
      m.rotation.set(rd() * 3, rd() * 3, rd() * 3);
      m.position.set(-8 + rd() * 16, sc * 0.1 - 1 + rd() * 1.6, -8 + rd() * 16);
      addS(m);
    }
    // lighthouse tower
    const H3 = s.towerH ?? 16, TR = 2.1;
    for (let i = 0; i < 7; i++) {
      const seg = new Mesh(new CylinderGeometry(TR * (1 - i / 12), TR * (1 - (i - 1) / 12), H3 / 7, 12), i % 2 ? toon({ color: "#e8e2d2" }) : toon({ color: "#b5402e" }));
      seg.position.set(0, i * H3 / 7 + H3 / 14, 0);
      addS(seg);
    }
    const gal = new Mesh(new CylinderGeometry(TR + 0.7, TR + 0.7, 0.35, 12), toon({ color: "#3a3f46" }));
    gal.position.set(0, H3, 0);
    addS(gal);
    const lampRoom = new Mesh(new CylinderGeometry(1.1, 1.1, 1.5, 10), new MeshBasicMaterial({ color: 16775684 }));
    lampRoom.position.set(0, H3 + 0.9, 0);
    addS(lampRoom, false, false);
    const cap = new Mesh(new ConeGeometry(1.5, 1.1, 10), toon({ color: "#2a3038" }));
    cap.position.set(0, H3 + 2.2, 0);
    addS(cap, false, true);
    // rotating beam (two opposite cones, additive)
    const beamMat = new MeshBasicMaterial({ color: 16776128, transparent: true, opacity: 0.22, blending: AdditiveBlending, depthWrite: false, side: DoubleSide });
    const beamGrp = new Group();
    for (const dir of [1, -1]) {
      const cone = new Mesh(new ConeGeometry(2.6, 90, 10, 1, true), beamMat);
      cone.rotation.z = dir * Math.PI / 2;
      cone.position.x = dir * 45;
      beamGrp.add(cone);
    }
    beamGrp.position.set(0, H3 + 0.9, 0);
    scene.add(beamGrp);
    storyMeshes.push(beamGrp);
    world.push(beamGrp);
    STORY.beam = beamGrp; // frameState rotates it
    // dock + cottage
    if (s.dock ?? true) {
      boxS(1.8, 0.22, 9, MAT.trunk, 7.5, 0.55, 13);
      for (const [dx, dz] of [[6.8, 10], [8.2, 10], [6.8, 16], [8.2, 16]]) boxS(0.22, 1.6, 0.22, MAT.trunk, dx, -0.2, dz);
      buildProp({ kind: "crate", x: 7.4, z: 14.5, s: 1 });
      buildProp({ kind: "barrel", x: 8, z: 11.6, s: 0.9 });
    }
    buildProp({ kind: "buoy", x: -4.5, z: -3, s: 1 });
    if (s.cottage ?? true) {
      house(9, -9, 4.4, 3.6, 2.6, -Math.PI / 4, 0);
    }
    // waves fx handled in scene fx
  };

  // lake set: still water, dock, fence, reeds
  var buildLake = (s) => {
    const rd = rng((s.seed ?? 5) * 3313 + 9);
    const water = addS(new Mesh(new PlaneGeometry(900, 900), toon({ color: s.waterCol ?? "#24344a" })), false, true);
    water.rotation.x = -Math.PI / 2;
    water.position.set(0, 0.02, -20);
    // shore
    const shore = addS(new Mesh(new PlaneGeometry(80, 40), MAT.grass));
    shore.rotation.x = -Math.PI / 2;
    shore.position.set(0, 0.04, 18);
    if (s.dock ?? true) {
      boxS(2, 0.2, 10, MAT.trunk, 0, 0.5, 8);
      for (const [dx, dz] of [[-0.8, 4], [0.8, 4], [-0.8, 11], [0.8, 11]]) boxS(0.2, 1.4, 0.2, MAT.trunk, dx, -0.2, dz);
    }
    if (s.fence ?? true) {
      for (let i = 0; i < 9; i++) {
        const zz = 4 + i * 0.9;
        boxS(0.14, 1.4, 0.14, toon({ color: "#6a6050" }), -6, 0.7, zz - 4);
        if (i > 0) boxS(0.06, 0.1, 0.95, toon({ color: "#6a6050" }), -6, 1.1, zz - 4.45);
      }
    }
    scatter(s.reeds ?? 26, rd, (r) => {
      const cone = new Mesh(new ConeGeometry(0.08, 1.4 + r() * 1.2, 5), MAT.leaf2);
      cone.position.set(-14 + r() * 28, 0.7, 6 + r() * 8);
      cone.rotation.z = (r() - 0.5) * 0.3;
      addS(cone);
    });
    scatter(s.trees ?? 10, rd, (r) => blobTree(-40 + r() * 80, 24 + r() * 16, 1.4 + r() * 1.4, MAT.leaf, 2));
    if (s.boat ?? true) {
      const hull = new Mesh(new SphereGeometry(1, 10, 8), MAT.trunk);
      hull.scale.set(1.6, 0.5, 3);
      hull.position.set(-6, 0.15, -6);
      addS(hull, false, true);
    }
    buildProp({ kind: "lantern", x: 1.5, z: 12.6, s: 0.9 });
    if (s.cabin) house(-12, 20, 5, 4, 2.8, Math.PI / 5, 1);
  };

  // cave set: tunnel walls, pool, gear shelf
  var buildCave = (s) => {
    const rd = rng((s.seed ?? 11) * 947 + 3);
    const pool = addS(new Mesh(new PlaneGeometry(60, 60), toon({ color: "#123244" })), false, true);
    pool.rotation.x = -Math.PI / 2;
    pool.position.set(0, 0.02, 0);
    // large dark rock floor so the cave reads enclosed to the horizon
    const caveFloor = addS(new Mesh(new PlaneGeometry(240, 240), toon({ color: "#1a2430" })), false, true);
    caveFloor.rotation.x = -Math.PI / 2;
    caveFloor.position.set(0, -0.02, 0);
    for (let i = 0; i < 22; i++) {
      const m = new Mesh(new DodecahedronGeometry(1, 0), MAT.rock);
      const sc = 3 + rd() * 8;
      m.scale.set(sc * 0.6, sc, sc * 0.7);
      m.rotation.set(rd() * 3, rd() * 3, rd() * 3);
      const side = i % 2 ? 1 : -1;
      m.position.set(side * (5 + rd() * 7), sc * 0.5 - 0.5, -24 + rd() * 44);
      addS(m);
    }
    // ceiling rocks
    for (let i = 0; i < 12; i++) {
      const m = new Mesh(new DodecahedronGeometry(1, 0), MAT.rock);
      const sc = 2.5 + rd() * 5;
      m.scale.set(sc, sc * 0.5, sc);
      m.position.set(-8 + rd() * 16, 6.5 + rd() * 3, -20 + rd() * 40);
      addS(m);
    }
    if (s.gear ?? true) {
      const shelf = boxS(2.4, 0.14, 1.1, MAT.trunk, 4.4, 1.5, -8);
      boxS(0.2, 1.5, 0.2, MAT.trunk, 3.6, 0.75, -8);
      boxS(0.2, 1.5, 0.2, MAT.trunk, 5.2, 0.75, -8);
      for (let i = 0; i < 8; i++) {
        const h = new Mesh(new SphereGeometry(0.32, 8, 6), toon({ color: i % 2 ? "#c8b830" : "#3a6ab5" }));
        h.position.set(3.5 + i * 0.26, 1.72, -8 + (rd() - 0.5) * 0.3);
        addS(h, false, true);
      }
    }
    if (s.rope ?? true) {
      for (let i = 0; i < 9; i++) {
        const rope = new Mesh(new CylinderGeometry(0.035, 0.035, 0.5, 5), toon({ color: "#d8c878" }));
        rope.position.set(-4.6, 4.5 - i * 0.42, -2);
        addS(rope, false, false);
      }
    }
  };

  // ── story-synced props ───────────────────────────────────────────────────
  // Small composite props placed per story via spec.props: [{kind, x, z, ry, s}]
  var buildProp = (p) => {
    const k = p.kind, x = p.x ?? 4, z = p.z ?? 6, ry = p.ry ?? 0, s = p.s ?? 1;
    const M = (geo, col, px, py, pz) => {
      const m = addS(new Mesh(geo, toon({ color: col })));
      m.position.set(px, py, pz);
      return m;
    };
    switch (k) {
      case "crate":
        M(new BoxGeometry(1 * s, 1 * s, 1 * s), "#8a6a42", x, 0.5 * s, z).rotation.y = ry;
        M(new BoxGeometry(1.06 * s, 0.14 * s, 1.06 * s), "#6d5233", x, 0.92 * s, z).rotation.y = ry + 0.2;
        break;
      case "barrel":
        M(new CylinderGeometry(0.42 * s, 0.42 * s, 1 * s, 10), "#7a5a38", x, 0.5 * s, z);
        M(new CylinderGeometry(0.45 * s, 0.45 * s, 0.08 * s, 10), "#4a3826", x, 0.75 * s, z);
        M(new CylinderGeometry(0.45 * s, 0.45 * s, 0.08 * s, 10), "#4a3826", x, 0.28 * s, z);
        break;
      case "campfire": {
        for (let i = 0; i < 6; i++) {
          const a = i / 6 * Math.PI * 2;
          const st = M(new DodecahedronGeometry(0.22 * s, 0), "#6a6a66", x + Math.cos(a) * 0.55 * s, 0.12 * s, z + Math.sin(a) * 0.55 * s);
          st.rotation.set(i, i * 0.7, 0);
        }
        for (const [lx, lz, r] of [[0.25, 0, 0.4], [-0.2, 0.2, 1.2], [0, -0.25, 2.2]]) {
          const log = M(new CylinderGeometry(0.09 * s, 0.09 * s, 0.9 * s, 6), "#5a4028", x + lx * s, 0.12 * s, z + lz * s);
          log.rotation.z = Math.PI / 2;
          log.rotation.y = r;
        }
        const flame = new Mesh(new ConeGeometry(0.3 * s, 0.7 * s, 8), new MeshBasicMaterial({ color: 16747520 }));
        flame.position.set(x, 0.45 * s, z);
        addS(flame, false, false);
        break;
      }
      case "tent":
        M(new ConeGeometry(1.5 * s, 1.9 * s, 4), "#c8783a", x, 0.95 * s, z).rotation.y = ry + Math.PI / 4;
        M(new BoxGeometry(0.5 * s, 0.8 * s, 0.06 * s), "#3a2c1e", x + Math.sin(ry) * 1.05 * s, 0.4 * s, z + Math.cos(ry) * 1.05 * s).rotation.y = ry;
        break;
      case "bench":
        M(new BoxGeometry(1.8 * s, 0.1 * s, 0.5 * s), "#7a5a3a", x, 0.45 * s, z).rotation.y = ry;
        M(new BoxGeometry(1.8 * s, 0.55 * s, 0.09 * s), "#7a5a3a", x - Math.sin(ry) * 0.22 * s, 0.7 * s, z - Math.cos(ry) * 0.22 * s).rotation.y = ry;
        for (const d of [-0.7, 0.7]) M(new BoxGeometry(0.09 * s, 0.45 * s, 0.45 * s), "#5a4028", x + Math.cos(ry) * d * s, 0.22 * s, z - Math.sin(ry) * d * s).rotation.y = ry;
        break;
      case "desk":
        M(new BoxGeometry(1.7 * s, 0.08 * s, 0.9 * s), "#6d5233", x, 0.75 * s, z).rotation.y = ry;
        for (const [dx, dz] of [[-0.75, -0.35], [0.75, -0.35], [-0.75, 0.35], [0.75, 0.35]])
          M(new BoxGeometry(0.09 * s, 0.75 * s, 0.09 * s), "#5a4028", x + Math.cos(ry) * dx * s - Math.sin(ry) * dz * s, 0.37 * s, z + Math.sin(ry) * dx * s + Math.cos(ry) * dz * s);
        M(new BoxGeometry(0.45 * s, 0.03 * s, 0.32 * s), "#e8e2d2", x + Math.sin(ry) * 0.2 * s, 0.8 * s, z + Math.cos(ry) * 0.2 * s).rotation.y = ry;
        break;
      case "crib": {
        const w = 1.3 * s, d = 0.8 * s, h = 1 * s;
        for (const [cx2, cz2] of [[-w / 2, -d / 2], [w / 2, -d / 2], [-w / 2, d / 2], [w / 2, d / 2]])
          M(new BoxGeometry(0.07 * s, h, 0.07 * s), "#e0d8c8", x + cx2, h / 2, z + cz2);
        for (const sd of [-1, 1]) {
          M(new BoxGeometry(w, 0.05 * s, 0.05 * s), "#e0d8c8", x, h - 0.1 * s, z + sd * d / 2);
          M(new BoxGeometry(w, 0.05 * s, 0.05 * s), "#e0d8c8", x, 0.25 * s, z + sd * d / 2);
          M(new BoxGeometry(0.05 * s, h, d), "#e0d8c8", x + sd * w / 2, h / 2, z);
        }
        M(new BoxGeometry(w - 0.1, 0.12 * s, d - 0.1), "#f0e8dc", x, 0.3 * s, z);
        break;
      }
      case "gravestone":
        M(new BoxGeometry(0.6 * s, 0.9 * s, 0.16 * s), "#9a9a96", x, 0.45 * s, z).rotation.y = ry;
        M(new CylinderGeometry(0.3 * s, 0.3 * s, 0.16 * s, 10, 1, false, 0, Math.PI), "#9a9a96", x, 0.9 * s, z).rotation.set(Math.PI / 2, ry, 0);
        break;
      case "car": {
        M(new BoxGeometry(3.4 * s, 0.75 * s, 1.6 * s), "#a83a30", x, 0.62 * s, z).rotation.y = ry;
        M(new BoxGeometry(1.8 * s, 0.62 * s, 1.45 * s), "#b8443a", x - Math.sin(ry) * 0.2 * s, 1.25 * s, z - Math.cos(ry) * 0.2 * s).rotation.y = ry;
        for (const [wx, wz] of [[-1.15, 0.72], [1.15, 0.72], [-1.15, -0.72], [1.15, -0.72]]) {
          const wh = M(new CylinderGeometry(0.33 * s, 0.33 * s, 0.2 * s, 10), "#22242a", x + Math.cos(ry) * wx * s - Math.sin(ry) * wz * s, 0.33 * s, z + Math.sin(ry) * wx * s + Math.cos(ry) * wz * s);
          wh.rotation.z = Math.PI / 2;
          wh.rotation.y = ry;
        }
        break;
      }
      case "sign":
        M(new CylinderGeometry(0.06 * s, 0.08 * s, 2.4 * s, 6), "#7a6a52", x, 1.2 * s, z);
        M(new BoxGeometry(1.5 * s, 0.6 * s, 0.07 * s), "#c8b28a", x + Math.sin(ry) * 1.15 * s, 2 * s, z + Math.cos(ry) * 1.15 * s).rotation.y = ry;
        break;
      case "elevDoors": {
        // two metal panels on a corridor side wall (x = wall offset, faces -x)
        const wallX = x;
        for (const sd of [-1, 1]) {
          const d2 = M(new BoxGeometry(0.1, 2.2, 0.65 * s), "#8a949c", wallX, 1.1, z + sd * 0.34 * s);
          d2.rotation.y = 0;
        }
        M(new BoxGeometry(0.14, 2.5, 1.5 * s), "#5a646c", wallX, 1.25, z);
        break;
      }
      case "cart":
        M(new BoxGeometry(1.2 * s, 0.1 * s, 2 * s), "#6a727a", x, 0.45 * s, z).rotation.y = ry;
        for (const [wx, wz] of [[-0.5, -0.7], [0.5, -0.7], [-0.5, 0.7], [0.5, 0.7]]) {
          const wh = M(new CylinderGeometry(0.2 * s, 0.2 * s, 0.08 * s, 10), "#3a3e44", x + wx * s, 0.2 * s, z + wz * s);
          wh.rotation.z = Math.PI / 2;
        }
        M(new BoxGeometry(0.55 * s, 0.75 * s, 0.4 * s), "#8a5a48", x - 0.25 * s, 0.85 * s, z - 0.4 * s).rotation.y = ry;
        M(new BoxGeometry(0.5 * s, 0.55 * s, 0.35 * s), "#4a6a8a", x + 0.2 * s, 0.75 * s, z + 0.3 * s).rotation.y = ry;
        break;
      case "lantern":
        M(new CylinderGeometry(0.05 * s, 0.07 * s, 2.1 * s, 6), "#3a352c", x, 1.05 * s, z);
        M(new SphereGeometry(0.16 * s, 8, 6), 16774628, x, 2.15 * s, z);
        break;
      case "buoy":
        M(new CylinderGeometry(0.3 * s, 0.4 * s, 0.8 * s, 8), "#c8452e", x, 0.2 * s, z);
        M(new SphereGeometry(0.14 * s, 8, 6), 16774628, x, 0.7 * s, z);
        break;
      case "stump":
        M(new CylinderGeometry(0.35 * s, 0.45 * s, 0.5 * s, 8), "#6a4a2e", x, 0.25 * s, z);
        break;
      default:
        break;
    }
  };

  var SETS = {
    interior: buildInterior,
    outdoor: buildOutdoor,
    sea: buildSea,
    lake: buildLake,
    cave: buildCave
  };

  // ── camera shot templates ────────────────────────────────────────────────
  // spec cam: {type, ...params} — all return {pos, look, fov} for local t & f.
  var camFromSpec = (c, t, lf) => {
    c = c || { type: "static" };
    const e = smoother(t);
    switch (c.type) {
      case "pushIn":
        return { pos: lerp32(c.from, c.to, e), look: c.look, fov: lerp3(c.fov ?? 42, (c.fov ?? 42) - 4, e) };
      case "pullOut":
        return { pos: lerp32(c.from, c.to, e), look: c.look, fov: lerp3(c.fov ?? 40, (c.fov ?? 40) + 5, e) };
      case "pan": {
        const pos = c.pos;
        return { pos, look: lerp32(c.lookFrom, c.lookTo, e), fov: c.fov ?? 44 };
      }
      case "orbit": {
        const a0 = (c.a0 ?? 0) * Math.PI / 180, a1 = (c.a1 ?? 40) * Math.PI / 180;
        const r = c.r ?? 6, h = c.h ?? 1.7;
        const ang = lerp3(a0, a1, e);
        const ctr = c.center ?? [0, 0, 0];
        return { pos: [ctr[0] + Math.cos(ang) * r, h + (c.rise ?? 0) * e, ctr[2] + Math.sin(ang) * r], look: c.look ?? [ctr[0], 1.4, ctr[2]], fov: c.fov ?? 44 };
      }
      case "rise": {
        const from = c.from, to = c.to;
        return { pos: lerp32(from, to, e), look: lerp32(c.lookFrom, c.lookTo, e), fov: c.fov ?? 44 };
      }
      case "track": {
        return { pos: lerp32(c.from, c.to, e), look: c.look ?? lerp32(c.lookFrom ?? c.from, c.lookTo ?? c.to, e), fov: c.fov ?? 40 };
      }
      case "static":
      default: {
        const jitter = c.jitter ? [0.05 * Math.sin(lf * 0.31), 0.04 * Math.sin(lf * 0.23 + 1.7), 0] : [0, 0, 0];
        return { pos: add3(c.pos ?? [4, 1.7, 6], jitter), look: c.look ?? [0, 1.4, 0], fov: c.fov ?? 44 };
      }
    }
  };

  // ── actors ────────────────────────────────────────────────────────────────
  var OUTFITS = {
    man:    { top: "#3f6fb5", kurta: true, dhoti: "#efe8d8", skin: "#c58c5e", moustache: "#2a1f1a", barefoot: true },
    old:    { top: "#6a6a5c", kurta: true, dhoti: "#e8e0cc", skin: "#b97d52", beard: "#d8d4c8", beardSize: 1.2, barefoot: true },
    woman:  { sari: "#8a4a6a", border: "#e8c84a", top: "#6a3460", skin: "#c3875a", hairCol: "#221816", barefoot: true },
    keeper: { top: "#1e3a5c", kurta: true, dhoti: "#26344a", skin: "#c09060", beard: "#3a2c20", beardSize: 1, moustache: "#3a2c20", barefoot: true },
    hiker:  { top: "#c8452e", kurta: true, dhoti: "#3a4250", skin: "#c8a078", hair: "#241a14", barefoot: false },
    nurse:  { sari: "#d8e2e8", border: "#b8ccd8", top: "#e8f0f4", skin: "#c3875a", hairCol: "#2a1e18", barefoot: false },
    mother: { sari: "#4a6a8a", border: "#d8e2ea", top: "#3a5068", skin: "#c3875a", hairCol: "#1e1614", barefoot: false },
    worker: { top: "#5a6248", kurta: true, dhoti: "#4a4636", skin: "#b88058", moustache: "#2a201a", barefoot: true },
    teen:   { build: "kid", top: "#e8823c", short: true, shorts: "#3b5b9a", hair: "#1f1715", skin: "#c08454", barefoot: true },
    kid:    { build: "kid", top: "#f0c83c", short: true, shorts: "#7a4a9a", hair: "#241a14", skin: "#c09068", barefoot: true },
    cop:    { top: "#2a3a4c", kurta: true, dhoti: "#222e3c", skin: "#c08858", moustache: "#241a14", barefoot: false },
    diver:  { top: "#1a1e28", kurta: true, dhoti: "#14181f", skin: "#b89068", hair: "#181210", barefoot: false },
    clerk:  { top: "#8a8a92", kurta: true, dhoti: "#5a5a62", skin: "#c08858", hair: "#2a2018", barefoot: false },
    villager1: { top: "#3f6fb5", kurta: true, dhoti: "#efe8d8", pagri: "#e0b84a", skin: "#c58c5e", moustache: "#2a1f1a", barefoot: true },
    villager2: { sari: "#3f8f5a", border: "#e8608a", top: "#e0b84a", skin: "#b8794c", hairCol: "#1e1614", barefoot: true },
    villager3: { top: "#b5653f", kurta: true, dhoti: "#efe8d9", skin: "#a86d44", moustache: "#ece8df", beard: "#ece8df", beardSize: 0.6, barefoot: true }
  };
  var outfitOf = (id) => OUTFITS[id] || OUTFITS.man;

  var actorOpts = (a, lf, cam, L, mir, home) => {
    const o = { expr: a.expr || "calm", blink: blinkAt(lf, a.seed ?? 3), seed: a.seed ?? 3, light: a.lightAng === false ? (a.light ?? -2.4) : lightAng(cam, L, mir) };
    if (a.mode === "walk") {
      o.mode = "walk";
      const spd = a.speed ?? 1.2;
      const d = spd * lf / 30;
      o.phase = walkPhase(d);
    } else if (a.mode === "sit") {
      o.mode = "sit";
      o.armL = "knee"; o.armR = "knee";
    } else if (a.mode === "hammer") {
      o.mode = "hammer";
      o.k = q(hammerCycle(lf, a.period ?? 12, a.off ?? 2), 0.1);
    } else {
      o.mode = "stand";
      const id = idle(lf, a.seed ?? 3);
      o.tilt = q(id.tilt * 0.7, 0.5);
      o.headTilt = q(id.head * 0.6, 1);
    }
    if (a.armL) o.armL = a.armL;
    if (a.armR) o.armR = a.armR;
    if (a.pot) o.pot = true;
    if (a.hammer) o.hammer = a.hammer;
    if (a.look !== undefined) o.look = a.look;
    return o;
  };

  // ── fx ────────────────────────────────────────────────────────────────────
  var fxFromSpec = (list, lf, cam, mir) => {
    const out = [];
    for (const e of list) {
      const at = e.at ?? [0.5, 1];
      if (lf / 30 < at[0] || lf / 30 > at[1]) continue;
      const kind = e.kind || "glow";
      const t = q((lf / 30 - at[0]) / Math.max(0.1, at[1] - at[0]), 0.03);
      out.push({
        id: "fx" + e._i, kind,
        pos: e.pos || [0, 1, 0],
        size: e.size ?? 3,
        t: e.cycle ? q((lf * 0.012 + (e.seed ?? 0) * 0.27) % 1, 0.02) : t,
        alpha: e.alpha ?? 1,
        seed: e.seed ?? 1,
        rot: e.rot ?? 0,
        flat: e.flat
      });
      if (e.pull) out[out.length - 1].pos = pullTo(out[out.length - 1].pos);
    }
    return out;
  };

  // ── frame state ───────────────────────────────────────────────────────────
  var frameState = (f) => {
    const S = window.STORY;
    if (!S || !S._shots) return { shot: "none", cam: { pos: [4, 1.7, 6], look: [0, 1.4, 0], fov: 44 }, light: LPR.night, actors: [], fx: [], world: { progress: 0 }, flash: 0, vign: 0.22, dof: { focus: 8, cInf: 0 }, shadow: { c: [0, 0, 0], r: 12 } };
    let sc = S._shots[S._shots.length - 1];
    for (const s of S._shots) if (f >= s._a && f < s._b) { sc = s; break; }
    const lf = f - sc._a;
    const cam = camFromSpec(sc.cam, clamp3((f - sc._a) / (sc._b - sc._a)), lf);
    CAMNOW = cam;
    const L = lightMix(sc.light || "night", f);
    const mir = mirrorOf(cam, [0, -1]);
    const actors = [];
    (sc.actors || []).forEach((a, ai) => {
      if (a.showFrom !== undefined && lf / 30 < a.showFrom) return;
      if (a.showTo !== undefined && lf / 30 >= a.showTo) return;
      const pos = [a.pos[0], a.pos[1]];
      actors.push({
        id: "a" + ai, kind: a.kind || "front",
        outfit: a.outfit ? outfitOf(a.outfit) : outfitOf("man"),
        pos, dir: a.dir || [0, 1],
        wide: a.wide, pull: a.pull,
        opts: actorOpts(a, lf, cam, L, mir, pos)
      });
    });
    const fx = fxFromSpec(sc.fx || [], lf, cam, mir).map((e, i) => (e.id = sc._a + "f" + i, e));
    if (STORY.beam) STORY.beam.rotation.y = f * (STORY.beamSpeed ?? 0.006);
    const lookPt = sc.cam.look || (actors[0] ? [actors[0].pos[0], 1.4, actors[0].pos[1]] : cam.look);
    return {
      shot: sc.n ?? "s", cam, light: L, actors, fx,
      world: { progress: sc.p ?? 0 },
      flash: sc.flashAt !== undefined ? (ext(lf, sc.flashAt, sc.flashAt + 6) ? [0.5, 0.32, 0.18, 0.1, 0.05, 0.02][Math.min(5, lf - sc.flashAt)] : 0) : 0,
      kicks: sc.kickAt !== undefined ? [{ f: sc.kickAt, a: sc.kickA ?? 0.02 }] : [],
      vign: sc.vign ?? 0.24,
      dof: { focus: dist(cam.pos, lookPt), cInf: sc.cInf ?? 8 },
      shadow: { c: actors[0] ? [actors[0].pos[0], 0, actors[0].pos[1]] : cam.look, r: sc.shadowR ?? 16 }
    };
  };

  // ── captions ──────────────────────────────────────────────────────────────
  var drawCaptions = (ctx, f) => {
    const S = window.STORY;
    if (!S || !S._caps) return;
    let cap = null, lf = 0, len = 1;
    for (const c of S._caps) if (f >= c._a && f < c._b) { cap = c; lf = f - c._a; len = c._b - c._a; break; }
    if (!cap || !cap.text) return;
    const fade = Math.min(1, lf / 8, (len - lf) / 8);
    ctx.save();
    ctx.globalAlpha = Math.max(0, Math.min(1, fade)) * (cap.alpha ?? 0.96);
    const fs = cap.style === "hook" ? 74 : 54;
    ctx.font = `bold ${fs}px -apple-system, Arial`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const maxW = 940;
    const words = cap.text.split(" ");
    const lines = [];
    let cur = "";
    for (const w of words) {
      const test = cur ? cur + " " + w : w;
      if (ctx.measureText(test).width > maxW && cur) { lines.push(cur); cur = w; } else cur = test;
    }
    if (cur) lines.push(cur);
    const y0 = 1920 - 200 - (lines.length - 1) * (fs * 1.18);
    lines.forEach((ln, i) => {
      const y = y0 + i * fs * 1.18;
      ctx.lineWidth = fs * 0.16;
      ctx.strokeStyle = "rgba(0,0,0,0.9)";
      ctx.strokeText(ln, 540, y);
      ctx.fillStyle = cap.style === "hook" ? "#ffd94a" : "#ffffff";
      ctx.fillText(ln, 540, y);
    });
    ctx.restore();
  };

  // ── build story ───────────────────────────────────────────────────────────
  var buildStory = (spec) => {
    clearStory();
    STORY.flatGround = spec.flatGround !== false;
    STORY.beam = null;
    const set = spec.set || { type: "outdoor", style: "forest" };

    // core ground policy: outdoor sets keep the grass plane + distant hills;
    // sea/lake/cave/interior bring their own ground, so core terrain (ridge,
    // boulders, baked trees) and the grass plane are hidden entirely.
    const outdoor = set.type === "outdoor";
    if (typeof coreGround !== "undefined" && coreGround) coreGround.visible = outdoor;
    if (typeof ridge !== "undefined" && ridge) ridge.visible = false;
    for (const m of (typeof CORE_HILLS !== "undefined" ? CORE_HILLS : [])) if (m) m.visible = outdoor;

    const builder = SETS[set.type];
    if (builder) builder(set);
    for (const p of spec.props || []) buildProp(p);

    const scenes = spec.scenes || [];
    let acc = 0;
    spec._shots = [];
    spec._caps = [];
    for (let i = 0; i < scenes.length; i++) {
      const sc = scenes[i];
      const d = Math.round((sc.dur ?? 8) * 30);
      const clone = { ...sc, _a: acc, _b: acc + d };
      spec._shots.push(clone);
      spec._caps.push({ _a: acc + 4, _b: acc + d - 2, text: sc.caption || "", style: sc.capStyle || (i === 0 ? "hook" : "normal") });
      acc += d;
    }
    window.TOTAL = Math.max(1, acc);
  };

