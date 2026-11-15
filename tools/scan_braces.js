// Brace-balance scanner for engine2.html's inline script.
// Skips strings, template literals, comments; finds mismatched brackets.
const fs = require("fs");
const html = fs.readFileSync(path2(), "utf8");
function path2() { return require("path").resolve(__dirname, "..", "App", "engine", "engine2.html"); }
const code = html.match(/<script[^>]*>([\s\S]*?)<\/script>/)[1];
const lines = code.split("\n");

const stack = [];
const state = { tpl: false, block: false, ln: 0 };

for (let li = 0; li < lines.length; li++) {
  state.ln = li + 1;
  const line = lines[li];
  let i = 0;
  let inStr = null;
  while (i < line.length) {
    const c = line[i], n = line[i + 1];
    if (inStr) {
      if (c === "\\") { i += 2; continue; }
      if (c === inStr) inStr = null;
      i++; continue;
    }
    if (state.tpl) {
      if (c === "\\") { i += 2; continue; }
      if (c === "`") { state.tpl = false; i++; continue; }
      if (c === "$" && n === "{") { stack.push({ c: "{", line: state.ln, tplOpen: true }); state.tpl = false; i += 2; continue; }
      i++; continue;
    }
    if (state.block) {
      if (c === "*" && n === "/") { state.block = false; i += 2; continue; }
      i++; continue;
    }
    if (c === "/" && n === "/") break;
    if (c === "/" && n === "*") { state.block = true; i += 2; continue; }
    // regex literal: a "/" after these tokens is division otherwise
    const prev = line.slice(0, i).replace(/[\s]*$/, "");
    const lastCh = prev ? prev[prev.length - 1] : "";
    const divAfter = /[)\]\w.$]/.test(lastCh);
    if (c === "/" && !divAfter) {
      i++;
      let inCls = false;
      while (i < line.length) {
        const rc = line[i];
        if (rc === "\\") { i += 2; continue; }
        if (rc === "[") inCls = true;
        else if (rc === "]") inCls = false;
        else if (rc === "/" && !inCls) { i++; break; }
        i++;
      }
      // skip flags
      while (i < line.length && /\w/.test(line[i])) i++;
      continue;
    }
    if (c === "'" || c === '"') { inStr = c; i++; continue; }
    if (c === "`") { state.tpl = true; i++; continue; }
    if ("([{".includes(c)) { stack.push({ c, line: state.ln }); i++; continue; }
    if (")]}".includes(c)) {
      const o = stack.pop();
      if (!o || "([{".indexOf(o.c) !== ")]}".indexOf(c)) {
        console.log(`MISMATCH line ${state.ln}: closing '${c}' but open was '${o && o.c}' from line ${o && o.line}${o && o.tplOpen ? " (template ${)" : ""}`);
        process.exit(2);
      }
      if (o.tplOpen) state.tpl = true; // resume template after ${...}
      i++; continue;
    }
    i++;
  }
}
console.log(`final depth ok=${stack.length === 0}; unclosed: ${stack.slice(-8).map((o) => o.c + "@" + o.line).join(", ") || "none"}`);
