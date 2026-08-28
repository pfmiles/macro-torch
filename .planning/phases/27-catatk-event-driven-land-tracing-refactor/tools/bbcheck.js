// Lua-aware bracket balance check (repo has no Lua interpreter; this is the
// automated syntax sanity gate used across phase 27 verification).
// Strips block comments, long strings, line comments, and short string
// literals before balancing (), [], {}.
const fs = require('fs');
let fail = 0;
for (const f of process.argv.slice(2)) {
  let s = fs.readFileSync(f, 'utf8');
  s = s.replace(/--\[\[[\s\S]*?\]\]/g, ' ');          // block comments
  s = s.replace(/\[=*\[[\s\S]*?(\]=*\])/g, ' "s" ');  // long strings
  s = s.replace(/--[^\n]*/g, ' ');                    // line comments
  s = s.replace(/"(?:\\.|[^"\\])*"/g, ' "s" ').replace(/'(?:\\.|[^'\\])*'/g, " 's' ");
  const st = []; const open = { '[': ']', '(': ')', '{': '}' };
  let ok = true;
  for (const c of s) {
    if (c in open) st.push(open[c]);
    else if (c === ']' || c === ')' || c === '}') { if (st.pop() !== c) { ok = false; break; } }
  }
  if (!ok || st.length !== 0) { fail = 1; console.log(f + ': MISMATCH'); } else console.log(f + ': BALANCED');
}
process.exit(fail);