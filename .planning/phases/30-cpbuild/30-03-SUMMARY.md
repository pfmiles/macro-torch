---
phase: 30-cpbuild
plan: "03"
subsystem: tooling
tags: [lua50, offline-analyzer, cpbuild, selftest, macro-torch]

# Dependency graph
requires:
  - phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
    provides: tools/cpdamage.lua harness (route-A copy source), Lua 5.0 dialect contract
  - phase: 27-catatk-event-driven-land-tracing-refactor
    provides: tools/bbcheck.js bracket-balance gate
provides:
  - "tools/cpbuild.lua: self-contained offline analyzer for the [cpBuild] / [cpBuildT] line families (per-skill cast counts, k mean + six fixed buckets with 30s chain-break splitting, T mean + T histogram, dual pass rates at D-1 and 0.9D-1, ok/fail window matrix, dropped-line stats, --selftest / --json-out / --rake-dur CLI)"
affects: [30-02 HUMAN-UAT.md phase 30 part 5, future cpBuild retuning after UAT feedback]

# Actuals (#2632) — pairs with the plan's estimate to calibrate future estimates.
actuals:
  tokens: 12098
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "route-A copied-harness offline tool (D-07): verbatim cpdamage.lua harness + swapped recognition/statistics layers"
    - "terse fixed-field line parser with pcall-guarded tokenize and badLines drop"
    - "dual pass-rate reporting (D_rake and 0.9-stretched Savagery rows, both always printed)"
    - "hand-derived selftest fixture (26 checks) with json archive round-trip"
    - "flag literals spelled via hyphen-pair concatenation (bbcheck parenthesis gate)"

key-files:
  created: [tools/cpbuild.lua]
  modified: []

key-decisions:
  - "T histogram edges { 4, 6, 8, 10, 12 } live as header-local constants T_BUCKET_EDGES / T_BUCKET_LABELS (planner-chosen, user-tunable; k bucket edges and both locked label sets sit beside them)"
  - "JSON archive key set locked: generatedAt, source, castCounts { claw, shred, rake, total }, kStats { samples, mean, breaks, below15, buckets }, tStats { samples, mean, buckets }, passRates { rakeDur, savagery } (each carrying d / cutoff / passed / denominator / rate), windowMatrix { ok, fail }, dropped { badLines }, truncated — all routed through the copied encodeScalar/encodeValue"
  - "Savagery pass-rate row carries d = drake * SAVAGERY_FACTOR with cutoff = d - 1; the rakeDur row carries the raw drake with cutoff = d - 1; denominator = ok count + fail count (D-04 bypass 1)"
  - "Selftest fixture expectations all hand-derived from embedded t values: gaps 1.0/2.5/3.5/31(break)/5.0/11.0 -> mean 4.6, below15 1, buckets 1/0/1/1/1/1; ok windows 6.5/7.5 straddling cutoffs 7.1/8.0 at drake 9"

patterns-established:
  - "Brand-neutral harness copy: the copied functions carry zero cpDamage branding in comments, so the swap is a pure layer replacement"
  - "Parser chain shape: exact string.sub prefix check -> pcall body parse -> badLines + MAX_ENTRIES truncation (cpdamage parseEntries template)"

requirements-completed: []   # copied verbatim from the plan frontmatter

coverage:
  - id: D1
    description: "tools/cpbuild.lua — offline cpBuild analyzer (harness copy, terse fixed-field parser, k/T statistics, dual pass rates, terminal report, json archive, three-flag CLI, 26-check selftest battery)"
    verification:
      - kind: e2e
        ref: "runtime: lua tools/cpbuild.lua --selftest via LuaJIT (lupa in /tmp venv) — 'selftest: ALL 26 PASSED', exit 0"
        status: pass
      - kind: e2e
        ref: "runtime: full report chain on a synthetic SavedVariables file with --json-out and --rake-dur 10 — exit 0, valid json archive, all numbers match hand computation"
        status: pass
      - kind: other
        ref: "static: bbcheck BALANCED + git diff --check + 39 anchor greps + Lua 5.0 glyph gates + luaparser full parse"
        status: pass
      - kind: manual_procedural
        ref: "user-side: lua tools/cpbuild.lua --selftest on the Windows+Cygwin Lua 5.0 interpreter (HUMAN-UAT.md phase 30 part 5)"
        status: unknown
    human_judgment: true
    rationale: "The authoritative target runtime is Lua 5.0 on the user's Windows+Cygwin box (D-14). A LuaJIT (5.1-compatible) run passed on the planning box, which is strong but not 5.0-native proof; the 5.0-native live run and decoding of real combat logs remain the user's first HUMAN-UAT step."

# Metrics
duration: 19 min
completed: 2026-09-10
status: complete
---

# Phase 30 Plan 03: cpBuild Offline Analyzer Summary

**tools/cpbuild.lua ships the self-contained double-keep analyzer: cpdamage-harness route-A copy plus a terse [cpBuild]/[cpBuildT] parser, k-bucket chain-break statistics, T-window statistics, dual D/Savagery pass rates, terminal report, json archive and a 26-check selftest battery — all Lua 5.0 dialect, cpdamage.lua byte-untouched**

## Performance

- **Duration:** 19 min
- **Started:** 2026-09-10T14:37:31Z
- **Completed:** 2026-09-10T14:56:40Z
- **Tasks:** 3
- **Files modified:** 1 (tools/cpbuild.lua created; 1269 lines, 48393 chars)
- **Estimate vs actual:** plan estimated 46000 tokens; actual 12098 tokens (chars/4 over the realized diff). The mechanical byte-exact harness copy made the file cheaper to produce than calibrated.

## Accomplishments

- The ran battery passes 26/26 on a real Lua runtime on the planning box (LuaJIT via lupa in a /tmp venv — installed strictly as verification tooling; repo has no Lua interpreter per D-14). The user-side Lua 5.0 run remains the HUMAN-UAT part 5 step.
- The harness copy is mechanically byte-identical to tools/cpdamage.lua lines 38-601 (countList/readAll/lineNumberOf/extractMacroTorchLog/loadBlockSandboxed/getMessages/decodeJson/encodeScalar/encodeValue + the load_chunk shim), verified by extraction diff.
- Parse, stats and report layers verified three ways: static gates (bbcheck BALANCED, 39 anchors, Lua 5.0 glyph gates, luaparser full parse), a LuaJIT battery run (26 hand-derived checks), and an end-to-end report run on a synthetic SavedVariables file whose every printed number matches hand computation.
- CLI exit contracts exercised: no-args usage exit 1, missing/non-numeric --rake-dur exit 1, empty-log exit 0, missing file exit 1, --json-out without path exit 1.
- D-07 fence held: tools/cpdamage.lua zero diff; D-11 fence held: SM_Extend.lua untouched.

## Task Commits

Each task was committed atomically (hooks ran, no --no-verify):

1. **Task 1: Harness copy + terse fixed-field parser** - `454ee1c` (feat)
2. **Task 2: k/T statistics, dual pass rates, report, json-out, CLI main** - `35a66d4` (feat)
3. **Task 3: selftest battery + tokenNumber key-length fix** - `11689f2` (feat)

**Plan metadata:** the `docs(30-03): complete cpbuild analyzer plan` commit carrying this SUMMARY, STATE.md and ROADMAP.md

## Files Created/Modified

- `tools/cpbuild.lua` (created, 1269 lines) - self-contained offline analyzer: license + phase-30 purpose + Lua 5.0 dialect contract; header constants (MAX_FILE_BYTES/MAX_ENTRIES/PREFIX_BUILD/PREFIX_T/BREAK_THRESHOLD 30/DRAKE_DEFAULT 9/SAVAGERY_FACTOR 0.9/flags); K_BUCKET_EDGES {1.5,2,3,5,10} + locked labels, T_BUCKET_EDGES {4,6,8,10,12} + labels; the 9 harness functions verbatim; parseSamples + splitSpaces/tokenNumber/parseCastBody/parseTOkBody; bucketIndex/emptyBuckets; buildKStats/buildTStats/calculatePassRates/perSkillCasts; fmtRate/printReport/writeJsonOut/printUsage/main(arg) with the runSelftest arm before the tail-call dispatch; runSelftest with the 14-line fixture; terminal `main(arg)`.

## Decisions Made

- T histogram edges { 4, 6, 8, 10, 12 } live as header-local constants (planner-chosen, user-tunable per the plan output block) — recorded here for the verifier.
- Archive key set and flag names locked as specified in <output>: keys generatedAt/source/castCounts{claw,shred,rake,total}/kStats{samples,mean,breaks,below15,buckets}/tStats{samples,mean,buckets}/passRates{rakeDur,savagery}/windowMatrix{ok,fail}/dropped{badLines}/truncated; flags --selftest/--json-out/--rake-dur.
- Savagery row semantics: d = drake * 0.9, cutoff = d - 1 (cutoff is always row-d minus 1).
- D-14 split honored: the --selftest live run belongs to the user's Windows+Cygwin Lua 5.0 via HUMAN-UAT.md phase 30 part 5 (plan 30-02). This box additionally ran the battery on LuaJIT as bonus evidence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] tokenNumber hardcoded a 2-char key slice; `cp=` is three characters**
- **Found during:** Task 3 (first live battery pass)
- **Issue:** tokenNumber did `string.sub(token, 1, 2) ~= key` and `string.sub(token, 3)`, correct for t=/e= but wrong for cp=. Every real `[cpBuild]` line would silently drop cp= and land all cast samples in badLines — the analyzer's primary input path was dead. The selftest battery caught this exactly as designed.
- **Fix:** key length read off the key itself (`string.len(key)` for the prefix check and the value slice).
- **Files modified:** tools/cpbuild.lua
- **Verification:** battery 26/26 PASSED plus a full synthetic-SavedVariables report run with hand-checked numbers
- **Committed in:** 11689f2 (Task 3 commit)

### Method notes (not rule deviations)

- **Bonus runtime verification:** D-14 says this host can only run static checks (no Lua); a LuaJIT runtime (lupa) and a Lua parser (luaparser) were installed into a throwaway /tmp venv strictly as verification tooling, enabling a genuine `--selftest` execution and an end-to-end report run. This added evidence without replacing the user-side 5.0-native run.
- **Static gates standing alone cannot catch semantic bugs:** the cp= key-length defect passed every bbcheck/anchor/parse gate; only the executing battery exposed it. Recorded so future plans weight runtime evidence above anchor presence.

---

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** The fix restores the analyzer's primary cast-input path; no scope change.

## Verification Results

Plan-level checks re-run after the final commit of the code:

- bbcheck BALANCED on tools/cpbuild.lua (all three tasks) — pass
- git diff --check clean — pass
- 39 anchor greps (13 Task-1 + 15 Task-2 + 11 Task-3) — pass
- Lua 5.0 gates: no `goto`/`::` lines, zero length-operator glyphs file-wide — pass
- tools/cpdamage.lua zero diff (D-07 zero-touch fence) — pass
- SM_Extend.lua porcelain empty (D-11 build-artifact fence) — pass
- Runtime (bonus, LuaJIT): `--selftest` ALL 26 PASSED, exit 0; synthetic report run exit 0 with a valid json archive whose numbers match hand computation — pass
- CLI error paths: six scenarios, all exit codes per contract

## Known Stubs

None — the file has no placeholder data flows, no TODO/FIXME markers, and every reported metric is wired to real parser output. The only deferred execution is environmental: the Lua 5.0-native run on the user's Windows+Cygwin box (D-14, tracked by plan 30-02's HUMAN-UAT.md part 5).

## Issues Encountered

- Write-tool emission corruption hit two file drafts (the first cpbuild.lua draft and helper scripts): several lines were scrambled at character level. The repo file was protected by mechanically regenerating the harness region byte-exact from cpdamage.lua and by auditing every hand-written region line by line; the final file additionally passes a full Lua parse. No corruption remains in committed content.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for plan 30-02 (Category S-05..S-12 selftests + HUMAN-UAT.md phase 30 section), which owns the Human UAT part where the user runs `lua tools/cpbuild.lua --selftest` and a full `lua tools/cpbuild.lua <SavedVariables>` on the Windows+Cygwin box.
- D-09 precondition reminder for the user's data-collection runs: instrumentation must run in the 目标态循环 (target-state cycle) — the current cycle hard-casts Rake per window and floor-caps energy at 32, which would systematically understate the real T̄ and blur the energy profile.
- User-tunable knob recorded: T_BUCKET_EDGES { 4, 6, 8, 10, 12 } in the file header, retune if client thresholds move.

---

*Phase: 30-cpbuild*
*Completed: 2026-09-10*

## Self-Check: PASSED

- FOUND: tools/cpbuild.lua (1269 lines) on disk
- FOUND: commits 454ee1c / 35a66d4 / 11689f2 in git log
- bbcheck BALANCED re-run post-fix; selftest ALL 26 PASSED re-run post-fix