---
phase: quick-260907-vve-add-macrotorch-log-max-size-global-confi
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - macro_torch.lua
  - interface_debug.lua
  - classes/druid/selftest.lua
autonomous: true
requirements:
  - QUICK-260907-VVE
user_setup:
  - service: wow-client
    why: "In-game smoke test on the user's Windows+Cygwin machine (this host cannot run WoW 1.12/SuperWoW and has no lua binary). After the code lands: (1) run build.sh ON THE GAME MACHINE to regenerate SM_Extend.lua into the AddOns dirs (established quick-task convention - never rebuild it in this repo); (2) log in - after the selftest diagnostics the config banner prints all four entries, the new one showing macroTorch.LOG_MAX_SIZE = 500 (default: 500) plus its setter line /run macroTorch.LOG_MAX_SIZE=1000; (3) run /run macroTorch.LOG_MAX_SIZE=1000 then /mt - the banner reprints (WR-02 fix, commit 2c05c8c) with 1000; (4) confirm the counterexample: /reload re-arms 500 (per-session semantics identical to cpBuildLog/rawdiag2Enabled/COWER_THREAT_THRESHOLD); (5) OPTIONAL flood probe of the cap: /run for i=1,520 do macroTorch.log('pad '..i) end then inspect macroTorch.tableLen(MACRO_TORCH_LOG.messages) - expect exactly 500; (6) OPTIONAL edge probe: /run macroTorch.LOG_MAX_SIZE=0 then a small flood - expect the kept count to be 1 (stock Lua 5.0 truthiness: 0 is truthy, so the clamp - not the 500 fallback - handles it; see the stock-truthiness note in the context below)."
estimate:
  tokens: 16000
  raw_tokens: 8000
  tasks: 3
  confidence: med
must_haves:
  truths:
    - "Visible and configurable: after login the banner prints a fourth entry - macroTorch.LOG_MAX_SIZE = 500 (default: 500) with the /run macroTorch.LOG_MAX_SIZE=1000 setter; a /run override takes effect for the rest of the session (per-session semantics identical to the three existing options, no SavedVariables persistence of the setting itself), and /reload re-arms 500 (D-01, D-04)"
    - "Bound is always a positive number: the trim loop compares macroTorch.tableLen(messages) against a local limit that tonumber + floor + clamp guarantees is a number >= 1, so no override value can ever produce a mixed-type relational comparison error or an unbounded trim loop; nil or non-numeric overrides fall back to the 500 default, 0 and negative overrides clamp to 1 (stock Lua 5.0 truthiness - the locked rationale's '0 falls back to 500' does not hold on the stock Lua 5.0 interpreter, where 0 is truthy; the locked guard code is safe either way because the clamp is what prevents the hang) (D-02)"
    - "Saved schema and callers untouched: MACRO_TORCH_LOG.maxSize remains ONLY in the two init guards (interface_debug.lua old lines 19 and 107) and is referenced nowhere else; macroTorch.log's signature function macroTorch.log(a, color) and its show-then-append observable behavior are unchanged, with zero diff in all four caller files (core/events.lua, core/spell_trace_core.lua, classes/druid/Druid.lua, classes/druid/cat.lua) (D-03)"
    - "Single source of truth and accurate registry: the only functional assignment of LOG_MAX_SIZE is the macro_torch.lua nil-guard; CONFIG_OPTIONS holds exactly 4 entries in declaration order (cpBuildLog, rawdiag2Enabled, COWER_THREAT_THRESHOLD, LOG_MAX_SIZE); the stale 'exactly these two entries' count clause now reads four; printConfigBanner needs zero edits (D-01, D-04, D-05)"
    - "Purity and syntax: the aggregate diff is strictly additive except exactly two replaced lines (the count word on macro_torch.lua:52 and the old trim condition on interface_debug.lua:111); bbcheck prints BALANCED for all three edited files; every added line passes the Lua 5.0 token gate (no #, no goto, no ::); LF preserved; git diff --check clean; SM_Extend.lua untouched; LOG_MAX_SIZE confined to exactly these three files"
    - "Regression coverage: Cat T-01 (optional, isOptional=true) asserts macroTorch.LOG_MAX_SIZE == 500 at selftest time, mirroring Cat S-01; its failure on a session with a deliberate override is expected and informative (D-07)"
  artifacts:
    - macro_torch.lua
    - interface_debug.lua
    - classes/druid/selftest.lua
  key_links:
    - "macro_torch.lua fourth nil-guard block (inserted between line 45, the `end` closing the COWER_THREAT_THRESHOLD guard, and line 46, the probe-warned comment) is the single default writer; it re-arms 500 on every login because macro_torch.lua runs at addon load"
    - "interface_debug.lua trim loop (the while at old line 111) is the only cap consumer; it now reads the sanitized local `limit` - the raw MACRO_TORCH_LOG.maxSize field is dead outside the two schema init guards"
    - "macro_torch.lua fourth CONFIG_OPTIONS entry (inserted between line 76 `    },` closing the COWER entry and line 77 `}` closing the table) feeds the untouched generic printConfigBanner (core/selftest.lua) - zero banner-code change"
    - "classes/druid/selftest.lua Category T block (between line 1084, the Category S registration-count comment, and line 1085, the final `end` closing the UnitClass Druid wrapper) rides the existing /mt invocation; the assert reads the real global so it fails the moment the nil-guard default drifts"
---

<objective>
Make the macroTorch.log persistence buffer cap user-configurable via a new
per-session global macroTorch.LOG_MAX_SIZE (nil-guarded default 500 in
macro_torch.lua, fourth CONFIG_OPTIONS registry entry so the existing login
banner surfaces it with zero banner edits), move the trim limit in
macroTorch.log (interface_debug.lua) onto a sanitized read of that global
(tonumber + floor + clamp to at least 1, per D-02), sync the two stale/missing
comments (D-05, D-06), leave MACRO_TORCH_LOG.maxSize untouched (D-03), and add
one optional default-value selftest (D-07).

Purpose: today the 500-entry cap is hardcoded twice (both init guards write
maxSize = 500) and invisible to the user - a napkin-analysis session that
floods the buffer must decide whether a full /reload is worth cleaning it,
with no way to raise the cap mid-session. This quick closes that loop with the
same machinery proven by quick 260907-tuh: nil-guard default re-armed on every
login, /run override live for the session, registry-driven banner visibility.
The locked consumer guard (D-02) exists because the old line compared
tableLen against the raw saved field - a mixed-type compare error or an
unbounded trim loop must be impossible for ANY value a user could /run,
including 0, negatives, strings, and tables.

Output: macro_torch.lua gains a fourth nil-guard block (default 500) and a
fourth CONFIG_OPTIONS entry (name/default/desc/cmd/get) plus a one-word comment
fix; interface_debug.lua gains the two-line sanitized-limit read and two
English comment syncs; classes/druid/selftest.lua gains one optional Category T
test. The only edited existing lines are the count word on macro_torch.lua:52
and the trim while-condition on interface_debug.lua:111.
</objective>

<execution_context>@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>@macro_torch.lua
@interface_debug.lua
@classes/druid/selftest.lua
@.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js

Grounding facts, verified live at planning time (2026-09-07):

- macro_torch.lua is 93 lines, LF-terminated, 4-space indent. Existing pattern to
  copy byte-style: three nil-guard blocks (cpBuildLog 22-28, rawdiag2Enabled
  29-36, COWER_THREAT_THRESHOLD 37-45) - each is a comment block starting `--` at
  column 0 stating the quick ID, the default value, the mid-session setter, the
  nil-guard re-arm rule, and per-session semantics, then `if macroTorch.X == nil
  then` / `    macroTorch.X = <default>` / `end`. INSERTION POINT A: between line
  45 (`end` of the COWER guard) and line 46 (`-- Per-login re-arm of the one-time
  GCD-probe diagnostic...`). Do NOT touch lines 46-49 or any existing guard.
- macro_torch.lua registry: comment 51-54 (stale count on line 52:
  `-- survey of user-tunable globals yields exactly these two entries; a future
  option` - fix ONLY the count word: two -> four). CONFIG_OPTIONS table 55-77
  with three entries; each entry field line ends with a trailing comma (including
  behind the get field). INSERTION POINT B: between line 76 (`    },` closing the
  COWER entry) and line 77 (`}` closing the table). Banner comment 78-79, generic
  printConfigBanner at 80-93 (untouched - pcall(opt.get) + tostring prints a
  numeric `default = 500` correctly with zero banner edits).
- interface_debug.lua is 115 lines, LF-terminated, 4-space indent inside the log
  function. Line 17 is an existing Chinese comment (kept byte-identical; do not
  translate): `-- 持久化日志缓冲区（依赖 SuperMacro .toc: ## SavedVariables:
  MACRO_TORCH_LOG）` - INSERTION POINT C is the three-line English sync
  immediately after it, before line 18 (`if not MACRO_TORCH_LOG then`).
- interface_debug.lua log function: signature line 103 `function
  macroTorch.log(a, color)` (byte-identical after the task); Chinese guard
  comment 104-105 and init guard 106-108 stay byte-identical (`MACRO_TORCH_LOG =
  { messages = {}, maxSize = 500 }` at line 107 - keep per D-03); line 110
  `local messages = MACRO_TORCH_LOG.messages` stays byte-identical; line 111 is
  the REPLACEMENT POINT: the old while-condition `while
  macroTorch.tableLen(messages) >= MACRO_TORCH_LOG.maxSize do` is replaced by the
  new comment + two locals + the new while (see Task 2 exact text). Lines
  112-115 (table.remove / end / table.insert) stay byte-identical.
- STOCK-TRUTHINESS NOTE (load-bearing for comment wording): WoW 1.12 embeds the
  stock Lua 5.0 interpreter, where 0 is TRUTHY (only nil and false are falsy).
  The locked guard `local limit = n and math.max(1, math.floor(n)) or 500` is
  safe for every input on stock semantics, but its actual behavior is: nil /
  non-numeric n -> 500; n = 0 or negative -> clamp to 1; fractional -> floor.
  The locked rationale's claim that 0 falls back to 500 does NOT hold on the
  stock interpreter. Write NO comment claiming zero falls back to 500; the
  truthful wording is the one prescribed in Task 2. The locked code line itself
  is implemented verbatim - this note governs documentation only. This
  discrepancy is also surfaced to the user in the planner's return message.
- classes/druid/selftest.lua is 1085 lines, tab-indented, and the ENTIRE body
  sits inside `if UnitClass('player') == 'Druid' then` (line 19) closing with the
  final `end` at column 0 on line 1085. Category S precedent at 987-1084 (S-01 at
  991 is the exact style to mirror: simple default-value assert, read-only, no
  stubs, `end, true)` optional). Line 1084 is `-- Registration count: Category S
  adds 4 tests (quick 260907-0ya + WR-01 fix)`. INSERTION POINT D: between line
  1084 and line 1085 - strictly additive, zero deleted lines in this file.
  Category letters in use repo-wide: A-F, J, K, M, O, Q, S - letter T is free.
- bbcheck.js exists at .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js
  and is the repo-established syntax gate: runs `node $BB <file...>`, prints
  `<file>: BALANCED` per file, exit 0; accepts multiple files. This host has NO
  lua/luac binary, so bbcheck + grep gates are the only automatable checks.
- Lua 5.0 / WoW 1.12 token constraints (user memory wow-lua50-syntax): NO `#`
  character in any added line (including comments), NO `goto`, NO `::`, NO `#`
  length operator. The FINAL gate negative-greps every added diff line. The
  prescribed texts below already comply - do not reword in ways that reintroduce
  them. File line endings are LF (.gitattributes; user builds on Windows+Cygwin -
  user memory cygwin-build-and-lf-convention); a CR grep gates this.
- SM_Extend.lua is untracked build artifact (verified: `git ls-files SM_Extend.lua`
  is empty). Never read it as source of truth and never edit it; the gate is
  `git status --porcelain -- SM_Extend.lua` being empty.
- Caller inventory, verified live by grep: macroTorch.log call sites live in
  core/events.lua (149, 153, 176), core/spell_trace_core.lua (140, 277, 284,
  306, 310), classes/druid/cat.lua (447), classes/druid/Druid.lua (354,
  cpBuildLogEvent path). None of these four files may change (zero diff is a
  hard gate); the signature and the show-then-append behavior stay identical.
- Repo-wide symbol scan (excluding SM_Extend.lua): zero pre-existing references
  to LOG_MAX_SIZE anywhere - after the task exactly three files reference it.
</context>

<tasks>
<!-- planner-discipline-allow: LIT -->

<task type="auto">
  <name>Task 1: Fourth nil-guard + fourth CONFIG_OPTIONS entry + count-comment fix in macro_torch.lua</name>
  <files>macro_torch.lua</files>
  <action>Three edits to macro_torch.lua (currently 93 lines, LF, 4-space indent), all
plain ASCII English. Per D-01 (nil-guarded default 500 in the config area),
D-04 (fourth registry entry), D-05 (stale count-comment fix). Everything else in
the file stays byte-identical - do NOT modify, wrap, reorder, or recomment any
existing line.

EDIT A (D-01) - INSERT after line 45 (the `end` closing the COWER_THREAT_THRESHOLD
guard) and before line 46 (the probe-warned comment). Six comment lines (each
starting `--` at column 0) plus the 2-line guard, exact text:

    -- macroTorch.log persistence buffer entry cap (quick 260907-vve): 500 by default,
    -- set macroTorch.LOG_MAX_SIZE = 1000 in game (SuperMacro body) to keep more log
    -- lines before the macroTorch.log trim loop drops entries. The nil-guard re-arms
    -- the default on every login; a /run override lasts only for the current session
    -- (no SavedVariables persistence), same as the three options above. The consumer
    -- sanitizes the value (tonumber plus a clamp to at least 1) in macroTorch.log,
    -- so the trim loop can never hang on an odd override.
    if macroTorch.LOG_MAX_SIZE == nil then
        macroTorch.LOG_MAX_SIZE = 500
    end

The two guard lines carry the 4-space `if`/assignment/`end` shape of the three
existing guards. This guard is the ONLY functional `macroTorch.LOG_MAX_SIZE =
<number>` assignment in the whole repo - no other file writes the default.

EDIT B (D-05) - on line 52 only, the stale registry-comment count clause reads
'yields exactly these two entries'; change the single count word so it reads
'yields exactly these four entries' (accurate after EDIT C lands). No other
character on the line changes, and lines 51/53/54 stay byte-identical.

EDIT C (D-04) - INSERT after line 76 (`    },` closing the COWER entry) and
before line 77 (`}` closing the table). Six lines, exact text:

    {
        name = 'macroTorch.LOG_MAX_SIZE',
        default = 500,
        desc = 'macroTorch.log persistence buffer entry cap',
        cmd = '/run macroTorch.LOG_MAX_SIZE=1000',
        get = function() return macroTorch.LOG_MAX_SIZE end,
    },

Every field line ends with a trailing comma (including the get line), mirroring
the three existing entries. `default = 500,` is a NUMBER literal equal to the
nil-guard value; `get` is an explicit function reference, never string-keyed
resolution. Declaration order ends cpBuildLog -> rawdiag2Enabled ->
COWER_THREAT_THRESHOLD -> LOG_MAX_SIZE (position 4).

Contract: no `#`, no `goto`, no `::` in any added character; no trailing
whitespace; the printConfigBanner body (80-93) is not edited in any way.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB macro_torch.lua && test "$(grep -cF 'if macroTorch.LOG_MAX_SIZE == nil then' macro_torch.lua)" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cE '^[[:space:]]*macroTorch\.LOG_MAX_SIZE[[:space:]]*=[[:space:]]*500[[:space:]]*$')" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF "name = 'macroTorch.LOG_MAX_SIZE',")" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF 'default = 500,')" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF "cmd = '/run macroTorch.LOG_MAX_SIZE=1000',")" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF 'get = function() return macroTorch.LOG_MAX_SIZE end,')" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF "name = 'macroTorch.")" = "4" && test "$(grep -cF 'yields exactly these four entries' macro_torch.lua)" = "1" && test "$(grep -cE 'yields exactly these (two|three) entries' macro_torch.lua)" = "0" && N_L=$(grep -nF "name = 'macroTorch.LOG_MAX_SIZE'," macro_torch.lua | cut -d: -f1) && N_C=$(grep -nF "name = 'macroTorch.COWER_THREAT_THRESHOLD'," macro_torch.lua | cut -d: -f1) && test "$N_L" -gt "$N_C" && echo 'G1 LOG_MAX OPTION OK'</automated>
  </verify>
  <done>bbcheck prints `macro_torch.lua: BALANCED` (exit 0). The G1 chain echoes `G1 LOG_MAX OPTION OK`: exactly one nil-guard line and exactly one functional `macroTorch.LOG_MAX_SIZE = 500` assignment (the guard - no duplicate writer); the fourth registry entry carries the prescribed name/default=500/cmd/get literals exactly once each (comment lines filtered); the registry holds exactly four `name = 'macroTorch.*'` entries; the count comment now says four with no stale two/three variant remaining; and the LOG_MAX_SIZE entry sits at a line number greater than the COWER entry (position 4, declaration order preserved).</done>
</task>

<task type="auto">
  <name>Task 2: Sanitized trim limit + comment syncs in interface_debug.lua</name>
  <files>interface_debug.lua</files>
  <action>Three edits to interface_debug.lua (currently 115 lines, LF, 4-space indent).
Per D-02 (locked consumer guard, verbatim), D-03 (maxSize untouched), D-06
(line-17 comment sync). All added lines are plain ASCII English.

EDIT A (D-06) - INSERT after line 17 (the existing Chinese persistence-buffer
comment, kept byte-identical - do not translate or reword it) and before line
18. Three comment lines starting `--` at column 0, exact text:

    -- Entry cap is controlled by macroTorch.LOG_MAX_SIZE at the log() trim point
    -- (default 500, nil-guarded in macro_torch.lua); maxSize below is only the
    -- SavedVariables schema field and is not the trim limit.

EDIT B - the init guard lines 18-20 (including `MACRO_TORCH_LOG = { messages =
{}, maxSize = 500 }`) stay byte-identical per D-03: maxSize remains the
SavedVariables schema field and is NOT read anywhere after EDIT C.

EDIT C (D-02) - replace the single line 111 (old text `    while
macroTorch.tableLen(messages) >= MACRO_TORCH_LOG.maxSize do`) with the
following six lines, exact text (three comment lines at 4-space indent, then
two locals, then the new while):

    -- Trim cap follows macroTorch.LOG_MAX_SIZE (nil-guarded to 500 in
    -- macro_torch.lua). The clamp keeps the bound at 1 or higher so a 0 or
    -- negative override can never leave the trim loop unbounded; a nil or
    -- non-numeric value falls back to the 500 default (quick 260907-vve).
    local n = tonumber(macroTorch.LOG_MAX_SIZE)
    local limit = n and math.max(1, math.floor(n)) or 500
    while macroTorch.tableLen(messages) >= limit do

The two guard locals are the locked expression verbatim. The comment wording is
truthful on stock Lua 5.0 (0 is truthy, so 0/negatives reach the clamp and
become 1; only tonumber returning nil reaches the 500 fallback) - do NOT alter
it to claim that zero falls back to 500, which stock Lua 5.0 would contradict.
Everything else in the function stays byte-identical: the signature line
`function macroTorch.log(a, color)`, the Chinese guard comment and the second
init guard (maxSize = 500 preserved there too), `local messages =
MACRO_TORCH_LOG.messages`, and the table.remove/end/table.insert lines below.
No change to Lua 5.0 operators, no `#`, no `goto`, no `::`, no trailing
whitespace.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB interface_debug.lua && test "$(grep -cF 'maxSize = 500' interface_debug.lua)" = "2" && test "$(grep -cF 'MACRO_TORCH_LOG.maxSize do' interface_debug.lua)" = "0" && test "$(grep -cF '>= limit do' interface_debug.lua)" = "1" && test "$(grep -cF 'local n = tonumber(macroTorch.LOG_MAX_SIZE)' interface_debug.lua)" = "1" && test "$(grep -cF 'local limit = n and math.max(1, math.floor(n)) or 500' interface_debug.lua)" = "1" && test "$(grep -cF 'function macroTorch.log(a, color)' interface_debug.lua)" = "1" && test "$(grep -cF 'macroTorch.LOG_MAX_SIZE' interface_debug.lua)" = "3" && git diff --exit-code -- core/events.lua core/spell_trace_core.lua classes/druid/Druid.lua classes/druid/cat.lua && echo 'G2 CONSUMER OK'</automated>
  </verify>
  <done>bbcheck prints `interface_debug.lua: BALANCED` (exit 0). The G2 chain echoes `G2 CONSUMER OK`: exactly two `maxSize = 500` lines remain (both init guards, D-03 honored - nothing reads the field anymore); zero `MACRO_TORCH_LOG.maxSize do` references (old trim condition gone); exactly one `>= limit do` loop with the two locked locals present exactly once each; the signature `function macroTorch.log(a, color)` is unchanged; LOG_MAX_SIZE appears in exactly three lines (sync comment, trim comment, tonumber line); and all four caller files have zero diff (observable behavior for every existing macroTorch.log caller is unchanged).</done>
</task>

<task type="auto">
  <name>Task 3: Cat T-01 default-value selftest in classes/druid/selftest.lua</name>
  <files>classes/druid/selftest.lua</files>
  <action>One strictly additive insertion into classes/druid/selftest.lua (1085 lines,
tab indentation, whole body inside the `if UnitClass('player') == 'Druid' then`
wrapper). Per D-07 (planner-included optional default-value case, Cat S-01
style).

INSERT after line 1084 (`-- Registration count: Category S adds 4 tests (quick
260907-0ya + WR-01 fix)`) and before line 1085 (the final `end` at column 0
closing the Druid wrapper). Nine lines, tab-indented like every sibling block,
exact text:

	-- Category T: macroTorch.log persistence buffer cap (quick 260907-vve, 1 test)
	-- T-01 mirrors Cat S-01: pure default-value assert, read-only, no stubs,
	-- isOptional=true. It passes on a fresh login (the macro_torch.lua nil-guard
	-- has just re-armed 500); if the session overrode the value the failure is
	-- expected and informative - the same trade-off Cat S-01 accepted.
	macroTorch.SelfTest:register("Cat T-01: LOG_MAX_SIZE defaults to 500", function()
		assert(macroTorch.LOG_MAX_SIZE == 500,
			"LOG_MAX_SIZE should default to 500, got " .. tostring(macroTorch.LOG_MAX_SIZE))
	end, true)

	-- Registration count: Category T adds 1 test (quick 260907-vve)

The assert reads the real global (never a copied literal), so it fails the
moment the nil-guard default drifts. isOptional=true matches Cat S-01. No `#`,
no `goto`, no `::` in any added line; no existing line is edited or moved - the
diff of this file must contain zero deleted lines.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB classes/druid/selftest.lua && test "$(grep -cF 'Cat T-01: LOG_MAX_SIZE defaults to 500' classes/druid/selftest.lua)" = "1" && test "$(grep -v '^[[:space:]]*--' classes/druid/selftest.lua | grep -cF 'macroTorch.LOG_MAX_SIZE == 500')" = "1" && test "$(grep -cF 'Registration count: Category T adds 1 test (quick 260907-vve)' classes/druid/selftest.lua)" = "1" && T_L=$(grep -nF '-- Category T: macroTorch.log persistence buffer cap' classes/druid/selftest.lua | cut -d: -f1) && S_L=$(grep -nF 'Registration count: Category S adds 4 tests' classes/druid/selftest.lua | cut -d: -f1) && test -n "$T_L" && test "$T_L" -gt "$S_L" && test "$(git diff -U0 -- classes/druid/selftest.lua | grep -cE '^-[^-]')" = "0" && echo 'G3 SELFTEST OK'</automated>
  </verify>
  <done>bbcheck prints `classes/druid/selftest.lua: BALANCED` (exit 0). The G3 chain echoes `G3 SELFTEST OK`: the test name registers exactly once; exactly one functional (non-comment) assert on `macroTorch.LOG_MAX_SIZE == 500`; the Category T registration-count comment exists once; the Category T header sits after the Category S count comment (correct tail position); and the file diff is strictly additive (zero deleted lines).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| In-game user -> addon (in) | /run setters mutate the addon's globals mid-session; the nil-guard remains the only code-level writer of the default |
| Addon -> chat frame (out) | The banner and macroTorch.log echo values and messages to chat (feature surface, not a leak) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-vve-01 | Tampering | /run macroTorch.LOG_MAX_SIZE=<anything> reaching the trim loop | low | mitigate | The locked sanitizer (tonumber + math.floor + math.max(1, ...) + 500 fallback) guarantees the comparison operand is always a number >= 1; worst case is the user shrinking their own session log, bounded by G2's gate proving the guard lines landed |
| T-vve-02 | Tampering | Default value drift (nil-guard 500 vs registry default=500 vs consumer fallback 500) | low | mitigate | G1 asserts exactly one functional 500-assignment and the registry literal; G2 asserts the fallback literal and the guard shape - three places share one semantic value, each pinned by a grep gate |
| T-vve-03 | Information Disclosure | Banner echoing the current LOG_MAX_SIZE value | low | accept | Reveals only a tuning constant already visible in the shipped source; requested visibility, same precedent as tuh T-01 |
| T-vve-SC | Tampering | npm/pip/cargo installs | n/a | n/a | No package-manager installs in this task (bbcheck runs with system node only) |

Impact basis: single value, single consumer (the trim loop in macroTorch.log), per-session scope, no network or persistence surface.
</threat_model>

<verification>
One FINAL chain covering all three tasks, additive purity, the Lua 5.0 token gate, LF hygiene, symbol confinement, and build-artifact integrity (run from the repo root):

    cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB macro_torch.lua interface_debug.lua classes/druid/selftest.lua && DIFF=$(git diff -U0 -- macro_torch.lua interface_debug.lua classes/druid/selftest.lua) && test "$(printf '%s\n' "$DIFF" | grep -cE '^-[^-]')" = "2" && if printf '%s\n' "$DIFF" | grep -E '^\+' | grep -vE '^\+\+' | grep -qE '\bgoto\b|#|::'; then echo 'LUA50 TOKEN FOUND IN DIFF'; exit 1; fi && git diff --check -- macro_torch.lua interface_debug.lua classes/druid/selftest.lua && if grep -qU $'\r' macro_torch.lua interface_debug.lua classes/druid/selftest.lua; then echo 'CR FOUND'; exit 1; else echo 'LF OK'; fi && test "$(grep -rln --include='*.lua' --exclude='SM_Extend.lua' --exclude-dir=.git --exclude-dir=.planning --exclude-dir=worktrees --exclude-dir=.claude --exclude-dir=.codegraph --exclude-dir=.gsd 'LOG_MAX_SIZE' . | sort)" = "$(printf '%s\n%s\n%s' classes/druid/selftest.lua interface_debug.lua macro_torch.lua | sort)" && test -z "$(git status --porcelain -- SM_Extend.lua)" && echo 'FINAL GATE OK'

Must print, in order: `macro_torch.lua: BALANCED`, `interface_debug.lua: BALANCED`, `classes/druid/selftest.lua: BALANCED`, `LF OK`, `FINAL GATE OK`, exit 0. Along with per-task G1/G2/G3 this proves: exactly two replaced lines repo-wide (the count word on macro_torch.lua:52 and the old trim condition on interface_debug.lua:111 - everything else strictly additive), every added line is free of the forbidden Lua 5.0 tokens (no `#`/goto/`::`), git diff --check is clean with no CR characters (LF preserved), LOG_MAX_SIZE is confined to exactly the three edited files, and SM_Extend.lua is untouched.
</verification>

<success_criteria>
- bbcheck.js prints BALANCED (exit 0) for macro_torch.lua (Task 1), interface_debug.lua (Task 2), classes/druid/selftest.lua (Task 3).
- G1 LOG_MAX OPTION OK, G2 CONSUMER OK, G3 SELFTEST OK chains exit 0.
- FINAL GATE OK: exactly two deleted lines in the aggregate diff, zero forbidden Lua 5.0 tokens in added lines, clean git diff --check, LF preserved, LOG_MAX_SIZE confined to the three expected files, SM_Extend.lua untouched (regenerated only on the user's game machine per user_setup).
- Behavior at defaults unchanged from the pre-task build: cap still 500, MACRO_TORCH_LOG.maxSize schema untouched, macroTorch.log signature and caller behavior identical (four caller files zero diff).
- In-game smoke per user_setup: banner shows the fourth entry at current=500 default=500; /run override to 1000 reflects on the next /mt; /reload re-arms 500.
</success_criteria>

<output>Create `.planning/quick/260907-vve-add-macrotorch-log-max-size-global-confi/260907-vve-SUMMARY.md` when done, then commit with message:
`feat(quick-260907-vve): make macroTorch.log persistence cap user-configurable (LOG_MAX_SIZE, default 500)`
</output>