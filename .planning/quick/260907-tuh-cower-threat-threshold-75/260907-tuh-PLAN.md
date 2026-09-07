---
phase: quick-260907-tuh-cower-threat-threshold-75
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - macro_torch.lua
  - classes/druid/Druid.lua
autonomous: true
requirements:
  - QUICK-260907-TUH
user_setup:
  - service: wow-client
    why: "In-game smoke test on the user's Windows+Cygwin machine (this host cannot run WoW 1.12/SuperWoW). After the code lands: (1) run build.sh on the game machine to regenerate SM_Extend.lua into the AddOns dirs (established quick-task convention - do NOT rebuild it in this repo); (2) log in - after the selftest diagnostics the config banner prints all three entries, the new one showing current=75 default=75 plus its /run setter; (3) run /run macroTorch.COWER_THREAT_THRESHOLD=80 then /mt - the banner now shows 80 for the threshold entry; (4) confirm the counterexample: a /reload re-arms the banner value back to 75 (per-session semantics, identical to cpBuildLog and rawdiag2Enabled)."
estimate:
  tokens: 12000
  raw_tokens: 6000
  tasks: 2
  confidence: med
must_haves:
  truths:
    - "Configurable and visible: after login/reload the banner prints a third entry - macroTorch.COWER_THREAT_THRESHOLD = 75 (default: 75) with its /run setter line; /run macroTorch.COWER_THREAT_THRESHOLD=80 in-game takes effect immediately for the rest of the session (per-session semantics identical to cpBuildLog/rawdiag2Enabled; no SavedVariables persistence), and /reload re-arms 75"
    - "Single source of truth: the only numeric default assignment of COWER_THREAT_THRESHOLD in the entire repo is the nil-guard block in macro_torch.lua; Druid.lua:909 holds only a pointer comment at the default definition; the cat.lua:99 consumption expression (player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD) is byte-identical, so an override changes the Cower decision threshold immediately with zero combat-path edits"
    - "Behavior unchanged at defaults: with no /run override the threshold is 75 - the same value the removed Druid.lua:909 assignment used to provide - so in-game worldboss Cower behavior is identical to the pre-task build"
    - "Purity and syntax: the macro_torch.lua diff is strictly additive; the Druid.lua diff is exactly one replaced line (assignment becomes comment); bbcheck reports BALANCED for both files; every added line passes the Lua 5.0 token gate (no # character - even in comments - no goto, no ::, no # length operator); LF endings preserved (no CR); git diff --check clean; cat.lua and the printConfigBanner function body have zero diff"
  artifacts:
    - macro_torch.lua
    - classes/druid/Druid.lua
  key_links:
    - "The third nil-guard block (macro_torch.lua, inserted after the rawdiag2Enabled guard end at 36, before the probe-warned reset comment at 37) is the single default writer; it re-arms 75 on every login because macro_torch.lua runs at addon load"
    - "The third CONFIG_OPTIONS entry (appended after the rawdiag2Enabled entry close at 60, before the registry-close brace at 61) is consumed by the untouched generic printConfigBanner ipairs loop (66-75), whose pcall + tostring formatting prints a numeric default correctly - zero banner-code change"
    - "cat.lua:99 worldboss threat check - the only consumer repo-wide (verified: grep hits only cat.lua:99 and Druid.lua:909) - reads the namespace global each evaluation, so /run overrides are live on the very next otMod pass"
    - "Druid.lua:909 (post-change comment) points at the macro_torch.lua nil-guard, so the default exists in exactly one place and can never drift into a duplicate assignment"
---

<objective>
Make the Cower worldboss threat threshold user-configurable: the hardcoded
assignment `macroTorch.COWER_THREAT_THRESHOLD = 75` at classes/druid/Druid.lua:909
moves to a nil-guard default in macro_torch.lua (same per-session pattern as the
cpBuildLog and rawdiag2Enabled options), and a third entry is appended to the
macroTorch.CONFIG_OPTIONS registry so the existing login config banner surfaces
it automatically. The combat-path consumer in cat.lua is not touched.

Purpose: the threshold is a hardcoded magic number, invisible to the user and
uneditable without a source edit. This task closes that loop using the already
proven machinery from quick 260907-sz4: the nil-guard re-arms the default on
every login, /run overrides it for the session (per-session semantics, matching
the two existing options - no SavedVariables persistence), and the generic
printConfigBanner reads the registry so the option appears on the banner with
zero banner-code change.

Output: macro_torch.lua gains a third nil-guard block (default 75) and a third
CONFIG_OPTIONS entry (name/default/desc/cmd/get); classes/druid/Druid.lua replaces
the line-909 assignment with a pointer comment. Everything additive except that
single one-line replacement. cat.lua:99 and the printConfigBanner body stay
byte-identical.
</objective>

<execution_context>@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>@macro_torch.lua
@classes/druid/Druid.lua
@classes/druid/cat.lua
@.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js

Grounding facts, verified by reading at planning time (2026-09-07), live anchors:

- macro_torch.lua is 77 lines, LF-terminated, 4-space indent discipline. Pattern to copy: nil-guard comment block + 2-line guard for cpBuildLog at 22-28 and rawdiag2Enabled at 29-36 (both report "default ... by default" in comments, use `if macroTorch.X == nil then / macroTorch.X = <default> end`, and state the nil-guard re-arms the default on every login). Probe-warned reset comment at 37-39, reset line 40. CONFIG_OPTIONS registry comment 42-45 ("a future option is surfaced by appending one registry entry" - that clause stays true; do NOT edit it or any existing line), registry table 46-61 with entry1 at 47-53 (`    {` ... `    },` each field line trailing-comma) and entry2 at 54-60; table-close `}` at 61. Banner comment 62-63, `function macroTorch.printConfigBanner()` at 64, generic ipairs loop at 66-75 (reads only via pcall(opt.get), prints `opt.name = <current> (default: <tostring(opt.default)>) - <desc>` and `set: <cmd>`), function end at 77. A numeric `default = 75` prints correctly through the untouched `tostring(opt.default)` at line 73.
- INSERTION POINT A (nil-guard block): between line 36 (`end` of the rawdiag2Enabled guard) and line 37 (`-- Per-login re-arm of the one-time GCD-probe diagnostic...`). INSERTION POINT B (registry entry): between line 60 (`    },` closing entry2) and line 61 (`}` closing the table).
- classes/druid/Druid.lua: constants block at 906-909 (`macroTorch.RIP_BASE_DURATION = 10`, RAKE 9, POUNCE 18, then line 909 `macroTorch.COWER_THREAT_THRESHOLD = 75`). Line 909 is the ONLY functional reference in the file (verified: non-comment occurrence count = 1), so replacing it with one comment line leaves zero functional references in Druid.lua. Siblings 906-908 stay byte-identical. The surrounding file mixes Chinese comments (UTF-8) - the replacement comment must be English (repo convention from user instructions) and plain ASCII.
- classes/druid/cat.lua:99 consumption, verified text: `    if target.isAttackingMe or (target.classification == 'worldboss' and player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD) then` - reads the namespace global; NO edit to cat.lua, zero cat.lua diff is a gate.
- Repo-wide symbol scan (excluding SM_Extend.lua, a build artifact per user memory sm-extend-is-build-artifact - never rebuild or analyze it here): today only cat.lua:99 and Druid.lua:909 reference COWER_THREAT_THRESHOLD. After this task the set is macro_torch.lua + Druid.lua + cat.lua (exactly 3 files).
- bbcheck.js exists at .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js and is the repo-established syntax gate (no lua/luac on this host). Runs `node $BB <file...>`, prints `<file>: BALANCED` per file, exit 0; accepts multiple files in one call. Prior quick plans (sz4, 0ya, mhh) use it in every gate.
- Lua 5.0 / WoW 1.12 token constraints (user memory wow-lua50-syntax): NO `#` character in ANY added line (including comments - write "75 percent", never "75%"), NO `goto`, NO `::`, NO `#` length operator. The FINAL gate negative-greps every added diff line for these. File line endings are LF (.gitattributes, user builds on Windows+Cygwin - user memory cygwin-build-and-lf-convention); a CR grep gates this.
- Per-session semantics rule (locked by the task definition, do not revisit): /run-assigned plain globals do not survive /reload because addon Lua re-runs and the nil-guard re-arms the default. This matches cpBuildLog/rawdiag2Enabled exactly. Do NOT add SavedVariables persistence in this task.
- Selftest/banner interplay: core/selftest.lua already calls macroTorch.printConfigBanner() at the tail of SelfTest:run() (landed in quick 260907-sz4) - NO selftest change in this task. printConfigBanner is registry-generic, so the new entry appears with no banner edit; do not touch lines 62-77 beyond what strict additive insertion into the registry implies (i.e. nothing).
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add third nil-guard block + third CONFIG_OPTIONS entry to macro_torch.lua</name>
  <files>macro_torch.lua</files>
  <action>Two strictly additive insertions into macro_torch.lua (currently 77 lines), both
using 4-space indentation and plain ASCII English, matching the two existing
blocks byte-style. Do NOT modify, wrap, reorder, or recomment any existing line:
guard blocks 22-36, probe-warned lines 37-40, registry comment 42-45, the two
existing registry entries 47-60, and the banner 62-77 stay byte-identical
(note: the 42-45 comment's "exactly these two entries" clause is intentionally
left as-is - the locked constraint is that this task's only non-additive change
is the Druid.lua:909 line; within THIS file the diff must be strictly additive).
LF endings; one trailing newline at EOF preserved.

INSERTION A - the third nil-guard block, immediately AFTER line 36 (the
`end` closing the rawdiag2Enabled guard) and BEFORE line 37 (the probe-warned
reset comment). Six comment lines plus the 2-line guard, exact text:

    `-- Cower worldboss threat threshold (quick 260907-tuh): 75 percent by default,`
    `-- set macroTorch.COWER_THREAT_THRESHOLD = 80 in game (SuperMacro body) to tune`
    `-- the threat percent at which a worldboss catAtk answers with Cower. The`
    `-- nil-guard re-arms the default on every login; a /run override lasts only`
    `-- for the current session (no SavedVariables persistence), same as the two`
    `-- boolean options above.`
    `if macroTorch.COWER_THREAT_THRESHOLD == nil then`
    `    macroTorch.COWER_THREAT_THRESHOLD = 75`
    `end`

Comment lines start `--` at column 0 exactly like the existing blocks; the two
guard lines carry the 4-space `if`/assignment/`end` shape of lines 26-27 and
34-36. The guard is the ONLY `macroTorch.COWER_THREAT_THRESHOLD = <number>`
assignment in this file.

INSERTION B - the third registry entry, immediately AFTER line 60 (`    },`
closing the rawdiag2Enabled entry) and BEFORE line 61 (`}` closing the
macroTorch.CONFIG_OPTIONS table). Six lines, exact text:

    `    {`
    `        name = 'macroTorch.COWER_THREAT_THRESHOLD',`
    `        default = 75,`
    `        desc = 'worldboss Cower threat percent trigger threshold (Cower fires when threat is at or above it)',`
    `        cmd = '/run macroTorch.COWER_THREAT_THRESHOLD=80',`
    `        get = function() return macroTorch.COWER_THREAT_THRESHOLD end,`
    `    },`

Every field line ends with a trailing comma (including the last field), mirroring
entries 1 and 2 so future single-entry appends stay uniform. `default = 75,` is a
NUMBER literal - it must equal the nil-guard value and is printed by the generic
banner via its untouched `tostring(opt.default)`. `get` is an explicit function
reference, never string-keyed resolution. The entry is appended at registry
position 3 (after rawdiag2Enabled), preserving declaration order cpBuildLog ->
rawdiag2Enabled -> COWER_THREAT_THRESHOLD.

Contract: no '#', 'goto', or '::' in any added character; no Lua 5.0 `#` length
operator; no trailing whitespace; the printConfigBanner body (62-77) is not edited
in any way.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB macro_torch.lua && test "$(grep -cF 'if macroTorch.COWER_THREAT_THRESHOLD == nil then' macro_torch.lua)" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cE '^[[:space:]]*macroTorch\.COWER_THREAT_THRESHOLD[[:space:]]*=[[:space:]]*75[[:space:]]*$')" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF "name = 'macroTorch.COWER_THREAT_THRESHOLD',")" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF 'default = 75,')" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF "cmd = '/run macroTorch.COWER_THREAT_THRESHOLD=80',")" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF 'get = function() return macroTorch.COWER_THREAT_THRESHOLD end,')" = "1" && test "$(grep -v '^--' macro_torch.lua | grep -cF "name = 'macroTorch.")" = "3" && N_C=$(grep -nF "name = 'macroTorch.COWER_THREAT_THRESHOLD'," macro_torch.lua | cut -d: -f1) && N_R=$(grep -nF "name = 'macroTorch.rawdiag2Enabled'," macro_torch.lua | cut -d: -f1) && test "$N_C" -gt "$N_R" && echo 'G1 THRESHOLD OPTION OK'</automated>
  </verify>
  <done>bbcheck prints `macro_torch.lua: BALANCED` (exit 0). The G1 chain echoes `G1 THRESHOLD OPTION OK`: exactly one nil-guard line and exactly one `macroTorch.COWER_THREAT_THRESHOLD = 75` assignment in the file (the guard - no duplicate assignment); the third registry entry carries the prescribed name/default=75/cmd/get literals exactly once each (comment lines filtered); the registry now holds exactly three `name = 'macroTorch.*'` entries; and the COWER entry sits at a line number greater than the rawdiag2Enabled entry (position 3, declaration order preserved).</done>
</task>

<task type="auto">
  <name>Task 2: Replace Druid.lua:909 threshold assignment with pointer comment</name>
  <files>classes/druid/Druid.lua</files>
  <action>In classes/druid/Druid.lua, replace the single line 909
`macroTorch.COWER_THREAT_THRESHOLD = 75` with ONE English ASCII comment line, exact
text:

    `-- Cower worldboss threat threshold: nil-guarded default lives in macro_torch.lua (quick 260907-tuh); user-configurable via /run - do not re-assign here`

The comment deliberately states NO numeric literal and no assignment pattern - the
default exists in exactly one place (the macro_torch.lua nil-guard) so the two can
never drift into duplicate definitions. Keep the sibling constant lines 906-908
(`RIP_BASE_DURATION`, `RAKE_DURATION`, `POUNCE_DURATION`) and every other line in
the file byte-identical; the diff of Druid.lua must be exactly one deleted line and
one added line. Do not touch classes/druid/cat.lua at all - its line-99 read of
`macroTorch.COWER_THREAT_THRESHOLD` keeps working unchanged. LF endings; no '#' and
no trailing whitespace in the new line.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB classes/druid/Druid.lua && test "$(grep -cF 'macroTorch.COWER_THREAT_THRESHOLD = 75' classes/druid/Druid.lua)" = "0" && test "$(grep -v '^[[:space:]]*--' classes/druid/Druid.lua | grep -cE 'macroTorch\.COWER_THREAT_THRESHOLD[[:space:]]*=[[:space:]]*[0-9]')" = "0" && test "$(grep -cF 'nil-guarded default lives in macro_torch.lua' classes/druid/Druid.lua)" = "1" && test "$(git diff -U0 -- classes/druid/Druid.lua | grep -cE '^-[^-]')" = "1" && test "$(git diff -U0 -- classes/druid/Druid.lua | grep -cE '^\+[^+]')" = "1" && git diff --exit-code -- classes/druid/cat.lua && echo 'G2 DRUID OK'</automated>
  </verify>
  <done>bbcheck prints `classes/druid/Druid.lua: BALANCED` (exit 0). The G2 chain echoes `G2 DRUID OK`: zero occurrences of the old assignment literal; zero functional (non-comment) numeric assignments or references of COWER_THREAT_THRESHOLD remain in the file; the pointer comment exists exactly once; the Druid.lua diff is exactly one deleted and one added line; and cat.lua has zero diff (consumer untouched).</done>
</task>

</tasks>

<threat_model>## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| In-game user -> addon (in) | The /run setter command mutates the COWER_THREAT_THRESHOLD global mid-session; the nil-guard remains the only code-level writer |
| Addon -> chat frame (out) | The banner echoes the threshold value and its /run command to chat (feature, not a leak surface) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-tuh-01 | Information Disclosure | macroTorch.printConfigBanner chat echo of the threshold value | low | accept | The banner reveals only a combat-tuning constant already visible in the shipped source; printing it is the requested feature and matches the printDruidDiag precedent |
| T-tuh-02 | Tampering | /run macroTorch.COWER_THREAT_THRESHOLD=<n> mid-session mutation | low | accept | This is the requested capability. Blast radius is one session (nil-guard re-arms 75 on every login), self-inflicted only (the user's own chat command), and the worst case is degraded personal threat dropping until /reload; banner readback gives immediate state visibility |
| T-tuh-03 | Tampering | Duplicate default definitions drifting apart (Druid.lua vs macro_torch.lua) | medium | mitigate | The Druid.lua:909 assignment becomes a pointer comment with no numeric literal, so the macro_torch.lua nil-guard is the single source of truth; G2's negative gate proves zero functional assignments remain in Druid.lua |
| T-tuh-SC | Tampering | npm/pip/cargo installs | n/a | n/a | No package-manager installs in this task (bbcheck runs with system node only) |

Impact basis: single value, single consumer (cat.lua:99), per-session scope, no network or persistence surface.
</threat_model>

<verification>
One FINAL chain covering both tasks, additive purity, the Lua 5.0 token gate, LF hygiene, symbol confinement, and the untouched consumer (run from the repo root):

    cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB macro_torch.lua classes/druid/Druid.lua && DIFF=$(git diff -U0 -- macro_torch.lua classes/druid/Druid.lua) && test "$(printf '%s\n' "$DIFF" | grep -cE '^-[^-]')" = "1" && if printf '%s\n' "$DIFF" | grep -E '^\+' | grep -vE '^\+\+' | grep -qE '\bgoto\b|#|::'; then echo 'LUA50 TOKEN FOUND IN DIFF'; exit 1; fi && git diff --check -- macro_torch.lua classes/druid/Druid.lua && if grep -qU $'\r' macro_torch.lua classes/druid/Druid.lua; then echo 'CR FOUND'; exit 1; else echo 'LF OK'; fi && git diff --exit-code -- classes/druid/cat.lua && test "$(grep -rln --include='*.lua' --exclude='SM_Extend.lua' 'COWER_THREAT_THRESHOLD' macro_torch.lua classes/ | wc -l)" = "3" && echo 'FINAL GATE OK'

Must print, in order: `macro_torch.lua: BALANCED`, `classes/druid/Druid.lua: BALANCED`, `LF OK`, `FINAL GATE OK`, exit 0. Along with per-task G1/G2 this proves: total deleted lines across both files is exactly 1 (the Druid.lua:909 assignment - macro_torch.lua is strictly additive), every added line is free of the forbidden Lua 5.0 tokens (no '#'/goto/::), git diff --check is clean with no CR characters (LF preserved), cat.lua carries zero diff, and exactly three repo files (macro_torch.lua, Druid.lua, cat.lua - SM_Extend.lua excluded) reference the symbol after the change.
</verification>

<success_criteria>
- bbcheck.js prints BALANCED and exits 0 for macro_torch.lua (Task 1) and classes/druid/Druid.lua (Task 2).
- G1 THRESHOLD OPTION OK and G2 DRUID OK chains exit 0.
- FINAL GATE OK: exactly one deleted line repo-wide (the replaced assignment), zero forbidden Lua 5.0 tokens in added lines, no trailing whitespace, LF preserved, cat.lua untouched, symbol confined to the three expected files.
- `git status --porcelain` shows only macro_torch.lua and classes/druid/Druid.lua modified; SM_Extend.lua untouched (regenerated only on the user's game machine per user_setup).
- Behavior at defaults unchanged from the pre-task build (threshold 75); no SavedVariables persistence added.
- In-game smoke test per user_setup: banner shows the third entry at current=75 default=75; /run override to 80 reflects on the next /mt; /reload re-arms 75.
</success_criteria>

<output>Create `.planning/quick/260907-tuh-cower-threat-threshold-75/260907-tuh-SUMMARY.md` when done, then commit with message:
`feat(quick-260907-tuh): make Cower worldboss threat threshold user-configurable (default 75)`
</output>