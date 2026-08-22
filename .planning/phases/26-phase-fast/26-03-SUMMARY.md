---
phase: 26-phase-fast
plan: 03
subsystem: testing
tags: [lua, world-of-warcraft, druid, self-test, fast-battle, gap-closure]

# Dependency graph
requires:
  - phase: 26-phase-fast
    provides: "Plan 26-01: macroTorch.isFastBattleNotPvp judgment (D-01/D-02, PvP-first exclusion, lazy per-frame cache)"
  - phase: 26-phase-fast
    provides: "Plan 26-02: remaining four Category P SelfTests (P-03..P-06) with stub/restore discipline"
  - phase: 26-phase-fast
    provides: "26-REVIEW.md findings CR-01/WR-01/IN-01..IN-04 — the source of truth for every fix"
provides:
  - "CR-01 fix: P-02 rawget snapshot / raw restore — /mt can no longer shadow the function-computed macroTorch.target.isPlayerControlled"
  - "WR-01 fix: getNextAbilityCost skips Bite/Rip/Rake in fast battles — reshift/FF consumers benchmark real castable costs (Tiger/Shred/Claw)"
  - "IN-04 fix: isFastBattleNotPvp caches false for missing/dead targets (isCanAttack precondition)"
  - "IN-03 fix: P-06 stubs the judgment function instead of pre-seeding the lazy-cache field"
  - "IN-01/IN-02 fixes: corrected Rip-duration comment and Category P header"
affects: [26-phase-fast, catAtk-60-dps]

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 2187
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns: [rawget-snapshot-raw-restore, stub-judgment-not-cache-internals]

key-files:
  created: []
  modified:
    - core/selftest.lua
    - classes/druid/Druid.lua

key-decisions:
  - "P-02 snapshots via rawget (nil => own-key absent => __index accessor live) and restores via raw assignment, so a nil restore deletes the own-key umbrella over FIELD_FUNC_MAP isPlayerControlled (CR-01)"
  - "WR-01 is fixed only inside getNextAbilityCost — the single shared reporter for the 60-level catAtk chain; shouldCastRip/shouldUseBite/shouldUseShred stay untouched so the catLeveling anchor holds (D-09/D-13)"
  - "isFastBattleNotPvp caches false when macroTorch.target.isCanAttack is false, after the D-01 PvP exclusion, before either judgment arm (IN-04); P-03/P-05 gain the same skip guard P-04 already had"

patterns-established:
  - "rawget-snapshot / raw-restore: snapshots read the own-key state of __index-computed fields; a nil raw restore re-exposes the live accessor"
  - "stub-the-judgment: self-tests stub macroTorch.isFastBattleNotPvp like every other collaborator instead of pre-seeding lazy-cache fields (IN-03)"

requirements-completed: [D-01, D-04, D-05, D-08, D-09, D-12, D-13]

# Coverage metadata (#1602)
coverage:
  - id: CR-01
    description: "P-02 PvP-exclusion self-test rewritten with rawget snapshot / raw restore of macroTorch.target.isPlayerControlled so running /mt deletes the own-key instead of shadowing the functional accessor"
    requirement: D-01
    verification:
      - kind: other
        ref: "grep -c \"rawget(macroTorch.target, 'isPlayerControlled')\" core/selftest.lua == 1; grep -c \"macroTorch.target.isPlayerControlled = rawOrigPvp\" == 1"
        status: pass
      - kind: unit
        ref: "./build.sh exits 0"
        status: pass
    human_judgment: true
    rationale: "Own-key deletion semantics are runtime behavior; no Lua interpreter exists in this environment. In-game confirmation of the PvP shadow-field observation is already persisted in 26-UAT.md."
  - id: WR-01
    description: "getNextAbilityCost resolves macroTorch.isFastBattleNotPvp(clickContext) once per click and skips the Bite/Rip/Rake steps when true, so shouldDoReshift and shouldCastFFDuringWaitWindow benchmark real castable costs"
    requirement: D-04
    verification:
      - kind: other
        ref: "grep -c \"local fastBattle = macroTorch.isFastBattleNotPvp(clickContext)\" classes/druid/Druid.lua == 1; grep -c \"not fastBattle\" == 3; \"and not fastBattle\" == 1"
        status: pass
      - kind: other
        ref: "git diff HEAD -- classes/druid/leveling.lua empty (D-13 anchor); shouldCastRip/shouldUseBite/shouldUseShred zero diff hunks"
        status: pass
      - kind: unit
        ref: "./build.sh exits 0"
        status: pass
    human_judgment: true
    rationale: "Decision economics depend on live game state; structural checks pass but fast-battle reshift/FF behavior in-game is a 26-UAT.md observation item for the user."
  - id: IN-01..IN-04
    description: "isFastBattleNotPvp caches false when macroTorch.target.isCanAttack is false (IN-04); Rip-duration comment corrected to 'at least 10s (18s at 5 CP)' (IN-01); Category P header corrected to 6 tests (IN-02); P-06 judgment-function stub replaces the lazy-cache pre-seed (IN-03); P-03/P-05 gain the isCanAttack skip guard"
    requirement: D-12
    verification:
      - kind: other
        ref: "sed -n '/^function macroTorch.isFastBattleNotPvp/,/^end/p' | grep -c isCanAttack == 1; grep -c \"localFastDieTime = 8.5\" == 1; grep -c \"if not macroTorch.target.isCanAttack then return end\" core/selftest.lua == 3; grep -c \"P: isFastBattleNotPvp|P: fast battle|P: cp5Bite\" == 6"
        status: pass
      - kind: unit
        ref: "./build.sh exits 0"
        status: pass
    human_judgment: true
    rationale: "Dead/missing-target verdict behavior and P-06 in-game state transitions require the WoW client; the behavioral rows remain open in 26-UAT.md per the plan's verification note."

# Metrics
duration: 3min
completed: 2026-08-22
status: complete
---

# Phase 26 Plan 03: Gap-Closure Summary

**Closed all six Phase 26 review findings: CR-01 P-02 own-key shadow over the function-computed `macroTorch.target.isPlayerControlled`, WR-01 phantom Bite/Rip/Rake cost reporting in fast battles, and IN-01..IN-04 info findings — build green, diff bounded to `core/selftest.lua` and `classes/druid/Druid.lua`.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-21T18:43:40Z
- **Completed:** 2026-08-21T18:46:35Z
- **Tasks:** 3
- **Files modified:** 2 (core/selftest.lua, classes/druid/Druid.lua)

## Accomplishments

- **CR-01 closed** — P-02 (`core/selftest.lua`) now snapshots with `rawget(macroTorch.target, 'isPlayerControlled')` and restores with a raw assignment. The normal nil restore deletes the own-key, re-exposing the `__index`-computed accessor (`FIELD_FUNC_MAP`), so running `/mt` at login can no longer freeze session-wide PvP detection (`isTrivialBattleOrPvp`, `isFightStarted`, `otMod`, mob-tagging, burst gating).
- **WR-01 closed** — `getNextAbilityCost` (`classes/druid/Druid.lua`) resolves the fast-battle verdict once per click (lazy-cached, D-11) and skips the Bite/Rip/Rake steps when true; the fall-through reports real castable costs (Tiger 30, Shred 60 / Claw 45). `shouldDoReshift` and `shouldCastFFDuringWaitWindow` now budget against honest abilities; `shouldCastRip`/`shouldUseBite`/`shouldUseShred` and `catLeveling` are untouched (D-09/D-13 anchors).
- **IN-04 closed** — `isFastBattleNotPvp` caches `false` when `macroTorch.target.isCanAttack` is false (missing/dead target where `UnitHealthMax` is 0), removing the `0 <= teamDPS*8.5 → true` vector. The D-01 PvP exclusion remains the first statement; the `localFastDieTime = 8.5` literal and both judgment arms are unchanged inside the else branch.
- **IN-03 closed** — P-06 stubs `macroTorch.isFastBattleNotPvp` like its four cast-chain collaborators instead of pre-seeding `ctx.isFastBattleNotPvp`; the test now verifies cp5Bite's guard composition (D-08) without coupling to lazy-cache internals.
- **IN-01 / IN-02 closed** — Rip-duration comment corrected to "Rip at least 10s (18s at 5 CP)" and the Category P header to "(6 tests, 2 from 26-01 + 4 from 26-02)"; P-03/P-05 gained the same `isCanAttack` skip guard P-04 already had, so the suite stays green on logins with no valid target.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix P-02 shadow-field corruption (CR-01) and P-06 lazy-cache coupling (IN-03) in core/selftest.lua** — `306cd1e` (test)
2. **Task 2: Guard getNextAbilityCost against phantom fast-battle abilities (WR-01) in Druid.lua** — `a3559d5` (fix)
3. **Task 3: Add isCanAttack precondition (IN-04), fix Rip-duration comment (IN-01), stale header (IN-02), and P-03/P-05 guards** — `5d46a78` (fix)

**Plan metadata:** combined in the final `docs(26-03)` commit.

## Files Created/Modified

- `core/selftest.lua` — P-02 rewritten (rawget snapshot / raw restore), P-06 judgment-function stub replacing the ctx pre-seed (IN-03), P-03/P-05 isCanAttack skip guards, corrected Category P header (IN-02)
- `classes/druid/Druid.lua` — `getNextAbilityCost` fast-battle guard on Bite/Rip/Rake steps (WR-01), `isFastBattleNotPvp` isCanAttack precondition caches false (IN-04), corrected Rip-duration comment (IN-01)

## Decisions Made

See frontmatter `key-decisions`: rawget-snapshot/raw-restore pattern (CR-01), reporter-only WR-01 fix preserving catLeveling (D-09/D-13), post-PvP isCanAttack precondition with coherent test guards (IN-04).

## Deviations from Plan

None - plan executed exactly as written. All fixes applied per 26-REVIEW.md corrected snippets with no drift.

## Issues Encountered

None. All verification greps passed on first run; `./build.sh` exited 0 at every gate.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 26 is now at 3/3 plans with all six review findings closed; the phase is complete from the code side.
- Remaining human-verification items (NOT code gaps): per the plan's verification section, truth #10 P-06 in-game behavior (D-08 state transition), the PvP shadow-field observation, and fast-to-normal frame switching require the WoW client and remain open for the user in `26-UAT.md`.

## Self-Check: PASSED

- Files exist: `.planning/phases/26-phase-fast/26-03-SUMMARY.md`, `core/selftest.lua`, `classes/druid/Druid.lua`
- Commits exist: `306cd1e` (Task 1), `a3559d5` (Task 2), `5d46a78` (Task 3), `0115a80` (SUMMARY)
- Final `./build.sh` exits 0; working tree clean apart from pre-existing untracked GSD files

---
*Phase: 26-phase-fast*
*Completed: 2026-08-22*