---
phase: 30-cpbuild
plan: 02
subsystem: testing
tags: [lua, wow-1.12, cpbuild, dki, selftest, stub-discipline, uat, instrumentation]

# Dependency graph
requires:
  - phase: 30-cpbuild
    provides: plan 01 symbols macroTorch.cpBuildDki / macroTorch.cpBuildDkiTick / macroTorch.resetCpBuildDki and the [cpBuildT] ok t= / fail line protocol the pins drive
  - phase: 30-cpbuild
    provides: plan 03 tools/cpbuild.lua CLI (selftest / json-out / rake-dur flags referenced by the UAT protocol)
  - phase: 27-catatk-event-driven-land-tracing-refactor
    provides: bbcheck.js bracket-balance static gate reused across the battery
provides:
  - Category S-05..S-12: 8 stubbed selftests (isOptional=true) pinning the six D-04 state-machine transitions, the global reset, and the D-01 zero-API switch gate under uniform CR-01 discipline
  - classes/druid/HUMAN-UAT.md Phase 30 section: six-part real-machine checklist with the D-09 target-state-loop precondition and the D-14 Windows+Cygwin protocol
  - state-hygiene fix: kill-shot returns now clear cpBuildDki.t0 so WAIT_ANCHOR is always pristine (pinned by S-09)
affects:
  - phase 30-cpbuild plan 03 verification flow (the in-game /mt battery and the UAT checklist feed the verifier's 30-UAT.md round-up)
  - any future refactor of the DKI state machine (the pins catch silent transition changes on the user's client)

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 4642
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CR-01 uniform stub-test shape: seven-global snapshot (savedGCP/savedGTime/savedLog/savedInCombat/savedCpBuildLog/savedTarget/savedDki) -> fresh-table state shadow -> pcall-wrapped drive -> restore all seven BEFORE the first assert"
    - "scripted multi-tick drives: per-call script via a calls counter (seeding tick, transition tick) with fixed GetTime stubs so anchor arithmetic is byte-exact"

key-files:
  created: []
  modified:
    - classes/druid/selftest.lua - Category S-05..S-12 registrations (8 tests) with updated 12-test count comment and the S-05+ banner
    - classes/druid/HUMAN-UAT.md - appended Phase 30 section (six numbered parts + 完成信号 line)
    - classes/druid/Druid.lua - deviation fix (Rule 2): t0 cleared at both kill-shot WAIT_ANCHOR returns

key-decisions:
  - "S-09 pin conflict resolved toward the plan's pinned contract: the shipped 30-01 machine left a stale t0 at both kill-shot WAIT_ANCHOR returns, which would red-line the plan-mandated 't0 nil' assert on the user's client; the machine now fully resets to a pristine WAIT_ANCHOR instead of weakening the pin to the stale behavior"
  - "runtime evidence stays user-side per D-14: the eight pins and the UAT protocol execute on the user's Windows+Cygwin box; static gates (bbcheck, restore-discipline greps, diff --check, Lua 5.0 scan) are the only evidence this host can certify"

patterns-established:
  - "Pinning tests assert observable state-table outcomes only (state / t0 / prevCp / captured lines) — no implementation details beyond the locked contract"

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Category S-05..S-12 — 8 stubbed selftests pinning the six D-04 state-machine transitions, the global reset (D-04 bypass 2), and the D-01 zero-API switch gate under uniform CR-01 restore-before-assert discipline"
    verification:
      - kind: other
        ref: "static gates: 8-title count; 7 restore literals x8 diff-scoped; per-body restore-before-assert order (scripted); Lua 5.0 goto/::-free and zero added length-glyph lines; bbcheck BALANCED; git diff --check clean"
        status: pass
    human_judgment: true
    rationale: "the machine behavior the pins assert can only execute in the WoW 1.12 client on the user's Windows+Cygwin box (D-14); the source discipline is statically certified here but the zero-red-lines /mt battery is user-side via HUMAN-UAT.md Phase 30"
  - id: D2
    description: "HUMAN-UAT.md Phase 30 section — six-part real-machine closed loop embedding the D-09 target-state-loop precondition and the D-14 Windows+Cygwin runtime protocol"
    verification:
      - kind: other
        ref: "anchor gates: '## Phase 30:' heading last-in-file; 目标态循环; Windows+Cygwin; lua tools/cpbuild.lua --selftest; macroTorch.cpBuildLog=false; [cpBuildT] ok t= / [cpBuildT] fail"
        status: pass
    human_judgment: true
    rationale: "protocol adequacy is a judgment: the checklist is exercised end-to-end by the user on the real machine, and this host cannot validate its steps (D-14)"

# Metrics
duration: 4 min
completed: 2026-09-10
status: complete
---

# Phase 30 Plan 02: cpBuild DKI State-Machine Pinning Tests + Real-Machine UAT Protocol Summary

**Eight CR-01-disciplined stubbed selftests pin every D-04 transition of macroTorch.cpBuildDkiTick (anchor, milestone, truncation re-anchor, cp=0 disambiguation, kill-shot variant, DONE silence), the global reset, and the D-01 zero-API switch gate, plus the Phase 30 HUMAN-UAT checklist carrying the D-09 target-state-loop precondition and the D-14 Windows+Cygwin protocol.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-09-10T15:05:07Z
- **Completed:** 2026-09-10T15:08:43Z
- **Tasks:** 2
- **Files modified:** 3 (selftest.lua +394/-1, HUMAN-UAT.md +49, Druid.lua +7/-3)

## Accomplishments

- The DKI state machine now has its only executable verification surface: 8 stubbed tests driving `macroTorch.cpBuildDkiTick` with captured globals. What each pins:
  1. **Cat S-05** (3-to-1 down-jump) — WAIT_ANCHOR anchors into BUILDING at the stubbed time, zero lines.
  2. **Cat S-06** (cp=0 back-look, two sub-drives) — alive target anchors; dead target cancels, t0 stays nil, no lines.
  3. **Cat S-07** (BUILDING re-reach of 5) — exactly one `[cpBuildT] ok t=6.500` line, machine goes DONE, silent on the next tick.
  4. **Cat S-08** (mid-window down-jump) — exactly one `[cpBuildT] fail` line, stays BUILDING, re-anchors t0.
  5. **Cat S-09** (kill-shot truncation) — one fail line, returns to a pristine WAIT_ANCHOR with t0 nil.
  6. **Cat S-10** (DONE silence) — steady 5 stays silent; the next down-jump re-anchors into BUILDING.
  7. **Cat S-11** (global reset) — `resetCpBuildDki()` discards state/t0/prevCp, zero lines.
  8. **Cat S-12** (zero-API gate) — switch off and combat-idle both produce zero GetComboPoints calls; the control arm counts exactly one.
- Uniform CR-01 discipline across all 8: snapshot `savedGCP` / `savedGTime` / `savedLog` / `savedInCombat` / `savedCpBuildLog` / `savedTarget` / `savedDki`, shadow with own stubs (macroTorch.log captured into a local array, macroTorch.cpBuildDki replaced with a fresh state table so no domain value leaks across tests), drive inside `pcall`, restore all seven via plain assignment BEFORE the first assert.
- Category S count comment updated to 12 tests; the D-01 switch gate is pinned as the D-01 gate in the tick body (return before GetComboPoints).
- HUMAN-UAT.md Phase 30 section appended as the last section: six numbered checkbox parts (prerequisites with the full D-09 precondition, /mt pre-test, collection protocol, switch-gate verification, analyzer run, expected outcomes/troubleshooting) closing with the 完成信号 line feeding the verifier's 30-UAT.md.

## Task Commits

Each task was committed atomically:

1. **Task 1 (deviation fix pre-commit)** - `d78d6a2` (fix: clear stale DKI t0 on kill-shot WAIT_ANCHOR returns)
2. **Task 1: Category S-05..S-12 stubbed DKI selftests** - `997f443` (feat)
3. **Task 2: HUMAN-UAT.md Phase 30 section + phase-wide battery** - `b3d86d3` (docs)

**Plan metadata:** committed after the SUMMARY (docs commit).

## Files Created/Modified

- `classes/druid/selftest.lua` - banner comment, 8 Category S registrations (isOptional=true) after S-04, count comment updated to "adds 12 tests (quick 260907-0ya + WR-01 fix + phase 30 DKI 8 tests)"
- `classes/druid/HUMAN-UAT.md` - appended `## Phase 30:` section (50 added lines; the 1-line diff deletion is the pre-existing missing-EOF-newline being re-terminated, zero content loss)
- `classes/druid/Druid.lua` - kill-shot branches now blank t0 before returning to WAIT_ANCHOR (Rule 2 deviation, see below)

## Decisions Made

- The S-09 pin spec (`t0 nil` after kill-shot truncation) conflicted with the shipped 30-01 machine, which left the seeded t0 in place at both kill-shot returns. Resolved toward the plan's pinned contract (authoring S-09 verbatim) by clearing `macroTorch.cpBuildDki.t0` at both sites — semantics unchanged since t0 is never read in WAIT_ANCHOR, and Druid.lua stays inside the phase's allowed five-file diff set.
- Runtime battery is recorded as user-side per D-14; no fabricated "tests passed" claim for the in-game run.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Clear stale DKI t0 on kill-shot WAIT_ANCHOR returns**
- **Found during:** Task 1 (authoring Cat S-09 against the shipped cpBuildDkiTick)
- **Issue:** The plan mandates S-09 assert `state 'WAIT_ANCHOR', t0 nil` after the kill-shot truncation, but the 30-01 implementation only reset `state` at both kill-shot returns, leaving the seeded t0 (99.0) in place — the pin would red-line on the user's client with zero-red-lines expected.
- **Fix:** Added `macroTorch.cpBuildDki.t0 = nil` before `state = 'WAIT_ANCHOR'` at both sites (BUILDING kill-shot branch and DONE kill-shot branch), making WAIT_ANCHOR permanently pristine. No D-04 transition semantics changed — t0 was never read while WAIT_ANCHOR.
- **Files modified:** classes/druid/Druid.lua (+2 lines, 2 comment lines adjusted)
- **Verification:** bbcheck BALANCED; S-09 drives the patched machine — exactly one `[cpBuildT] fail` line, state WAIT_ANCHOR, t0 nil; all Task 1/2 gates green including the allowed-diff-set battery (Druid.lua is one of the five phase files).
- **Committed in:** d78d6a2

---
**Total deviations:** 1 auto-fixed (Rule 2 missing critical)
**Impact on plan:** State hygiene required by the plan's own pinned contract. No scope creep; the phase diff remains inside the five allowed files.

## Issues Encountered

One tooling quirk, inherited from plan 30-01 and not a plan deviation: the local `grep` binary is ugrep, which rejects the POSIX `'^+++'` exclusion pattern; the two affected gates (restore-discipline counts, added-line `#` scan) were re-run with an equivalent awk filter (`awk '/^\+/ && !/^\+\+\+/'`), same semantics — all counts hold at exactly 8 per restore literal and 0 length-glyph lines.

## Verification Results (plan-level battery, re-run post-commit)

- Title count gate: 8/8 locked titles present — PASS
- Restore-discipline gate: all seven restore literals appear exactly 8 times across the diff-added lines — PASS
- Per-body restore-before-assert order: scripted check over all 8 bodies (first assert line strictly after the last restore line) — 8/8 ORDER-OK
- Count comment "Category S adds 12 tests" present; no "adds 4 tests" remains; 8/8 register calls carry the trailing `true` third argument inside the Druid-only wrapper — PASS
- Lua 5.0 gates: no goto/label file-wide; zero added lines carry the length-operator glyph — PASS
- bbcheck BALANCED on selftest.lua, Druid.lua, events.lua, tools/cpbuild.lua; git diff --check clean — PASS
- Read-only fence (tools/cpdamage.lua, classes/druid/cat.lua, macro_torch.lua, core/periodic.lua, interface_debug.lua) byte-untouched; SM_Extend.lua porcelain empty; phase diff restricted to the five allowed files (this plan added only selftest.lua + HUMAN-UAT.md + Druid.lua) — PASS
- Runtime checks (user-side, per D-14): in-game /mt suite including S-05..S-12 on Windows+Cygwin — **recorded, not runnable on this host; Human-UAT-deferred** via the HUMAN-UAT.md Phase 30 checklist.

## D-09 / D-14 Runtime Note

The D-09 target-state-loop precondition is written out in the UAT section's part 1 and recorded here for the user's real-machine run: instrumentation must run in the target-state rotation — the double-bleed loop maintained by bite refresh — not the current rotation that hard-casts Rake each window for +1 star at a 32e entry cost, which would systematically under-estimate the true T̄ and confound the energy profile. The user-side protocol: rebuild via Windows+Cygwin `./build.sh`, in-game `/mt` (S-05..S-12 all green), hot-enable `/run macroTorch.cpBuildLog=true`, target-state loop on a skull dummy, off-gate zero-line check, then `lua tools/cpbuild.lua --selftest` and the SavedVariables analysis run.

## Known Stubs

None — the 8 tests are fully wired to the real state machine (fresh-table shadow, scripted captures); HUMAN-UAT.md contains no mock data. The only non-executed surface is the user-side runtime battery, tracked as an unrun-verify entry in the cross-phase windows ledger, not as a stub.

## Next Phase Readiness

- Phase 30 delivered: plan 01 (DKI timer) + plan 02 (pins + UAT protocol) + plan 03 (offline analyzer) all have summaries; the remaining phase-level item is the user's real-machine run feeding the verifier's 30-UAT.md.
- No blockers: static gates all green; the D-14-deferred runtime battery has an explicit protocol (HUMAN-UAT.md Phase 30) and a windows-ledger entry so the ship gate sees it.

---
*Phase: 30-cpbuild*
*Completed: 2026-09-10*

## Self-Check: PASSED