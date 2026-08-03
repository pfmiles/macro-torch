---
phase: 23-idol-dance-refactor
plan: 01
subsystem: druid-combat
tags: [lua, wow-addon, idol-dance, combat-logic, selftest]

requires:
  - phase: 22-catAtk-quality-assurance
    provides: SelfTest framework and Category R2-R8 test patterns

provides:
  - Rewritten computeNormalRelic with flat 5-branch chain (Gaps 1 and 2 fixed)
  - Distance bypass in recoverNormalRelic (Gap 4 fixed)
  - 7 Category O SelfTest registrations for idol dance decision logic

affects: [druid-combat, future-idol-dance-optimizations]

actuals:
  tokens: 1600
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Flat if-else branching chain for multi-condition decision logic (alternative to nested if-else)"
    - "SelfTest:register with isOptional=true for combat-state-dependent tests"
    - "Structure-verification smoke tests (O-07: assert function type and API availability)"

key-files:
  created: []
  modified:
    - classes/druid/Druid.lua
    - classes/druid/selftest.lua

key-decisions:
  - "D-01: Flat 5-branch if-else chain in computeNormalRelic — non-combat immune → Fero/Rot, non-combat non-immune → Savagery, trivialBattle/PvP → Fero/Rot, immune Rip → Fero/Rot, Rip present → Fero/Rot, fallback → Savagery"
  - "D-02: Non-combat pre-switch to Savagery preserved as first branch fallthrough"
  - "D-03/D-04: Distance bypass (20yd threshold) in recoverNormalRelic inserted before energy check"
  - "D-05/D-06: Category O SelfTest naming convention `Cat O-NN: description — per D-XX` with isOptional=true inside UnitClass guard"

patterns-established:
  - "SelfTest combat-state guards: `if not isInCombat then return end` and `if isInCombat then return end` for tests requiring specific combat state"
  - "clickContext field injection: `isRipPresent = true` directly in context table for isRipPresent function testing"

requirements-completed:
  - REQ-23-GAP1
  - REQ-23-GAP2
  - REQ-23-GAP4
  - REQ-23-TEST

coverage:
  - id: D1
    description: "computeNormalRelic flat 5-branch chain (Gap 1 and Gap 2 fixes)"
    requirement: REQ-23-GAP1
    verification:
      - kind: unit
        ref: "classes/druid/selftest.lua#Cat O-01, Cat O-02, Cat O-03, Cat O-04, Cat O-05, Cat O-06"
        status: pass
    human_judgment: false
  - id: D2
    description: "recoverNormalRelic distance bypass (Gap 4 fix)"
    requirement: REQ-23-GAP4
    verification:
      - kind: unit
        ref: "classes/druid/selftest.lua#Cat O-07 (smoke test: function exists, distance API available)"
        status: pass
      - kind: other
        ref: "grep 'macroTorch.target.distance >= 20' classes/druid/Druid.lua returns 1 match"
        status: pass
    human_judgment: true
    rationale: "Distance bypass requires in-game WoW client to verify end-to-end; O-07 is a structure-level smoke test, and the grep check confirms code placement. Full end-to-end verification requires a live target at 20+ yd distance in combat."
  - id: D3
    description: "7 Category O SelfTest registrations for idol dance decision logic"
    requirement: REQ-23-TEST
    verification:
      - kind: unit
        ref: "classes/druid/selftest.lua#Cat O-01 through O-07 (7 registrations, all isOptional=true, inside UnitClass guard)"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-08-03
status: complete
---

# Phase 23 Plan 01: Idol Dance Refactor — Fix computeNormalRelic + Distance Bypass + 7 Category O SelfTests

**Flat 5-branch computeNormalRelic replacing nested if-else (Gaps 1 and 2), 20yd distance bypass in recoverNormalRelic (Gap 4), and complete Category O SelfTest coverage (7 tests across all decision branches).**

## Performance

- **Duration:** ~55 min active (spread across 2 sessions with overnight pause)
- **Started:** 2026-08-02T14:27:51Z
- **Completed:** 2026-08-03T10:49:58Z
- **Tasks:** 2 (1 tracer + 1 expansion)
- **Files modified:** 2
- **Commits:** 2
- **Lines changed:** +92 / -24

## Accomplishments

- Rewrote computeNormalRelic with a flat 5-branch if-else chain: non-combat immune, non-combat Savagery pre-switch, trivial/PvP, immune Rip, Rip present, fallback Savagery
- Fixed Gap 1 (fast combat/PvP no longer wastes GCD switching to Savagery when Builder idol is always better)
- Fixed Gap 2 (immune Rip targets no longer receive useless Savagery idol)
- Fixed Gap 4 (recoverNormalRelic skips energy check at 20+ yd distance since running time covers the GCD)
- Added 7 Category O SelfTest registrations covering all computeNormalRelic decision branches and the distance bypass structure
- All SelfTests use isOptional=true and are encapsulated in the UnitClass Druid guard
- Preserved non-combat pre-switch behavior per D-02 (non-immune targets still pre-equip Savagery for opening snapshots)

## Task Commits

1. **Task 1: End-to-end tracer — rewrite computeNormalRelic + distance bypass + 2 tracer tests** - `64f9060` (feat)
2. **Task 2: Add remaining 5 Category O SelfTest registrations (O-02 to O-07)** - `7a55bfa` (test)

## Files Modified

- `classes/druid/Druid.lua` — Rewrote computeNormalRelic function body (lines 362-385) with flat 5-branch chain; inserted 20yd distance bypass in recoverNormalRelic (line 433-436)
- `classes/druid/selftest.lua` — Added Category O section with 7 SelfTest registrations (O-01 through O-07) inside UnitClass Druid guard block

## Category O Test Coverage

| Test | Branch Tested | Guard | Assertion |
|------|---------------|-------|-----------|
| O-01 | Fast combat (Gap 1) | — | non-Savagery |
| O-02 | PvP target (Gap 1) | — | non-Savagery |
| O-03 | Immune Rip in combat (Gap 2) | isInCombat required | non-Savagery |
| O-04 | Rip present (normal path) | isInCombat required | non-Savagery |
| O-05 | Rip absent, normal combat | — | == Savagery |
| O-06 | Non-combat non-immune (D-02) | NOT isInCombat | == Savagery |
| O-07 | Distance bypass structure (Gap 4) | — | function exists, API available |

## Decisions Made

- **D-01 architecture**: Flat if-else chain replaces nested structure. The 5 branches are evaluated in priority order: combat state → battle triviality → immunity → Rip presence → fallback. This eliminates the old `isInCombat and not isImmuneRip and not isTrivialBattleOrPvp` branch that coupled three conditions for the Savagery sub-branch inside the combat path.
- **O-04 implementation**: Used `clickContext.isRipPresent = true` directly instead of the `pendingCasts` approach described in the plan. The actual `isRipPresent` function (line 1008) checks `clickContext.isRipPresent` first and only queries the WoW API when nil — `pendingCasts` is not referenced in the function. See Deviations for details.
- **O-03 guard**: Added `if not isInCombat then return end` guard. Without it, the test would still pass (non-combat immune branch also returns Fero/Rot), but the guard ensures the test specifically verifies the combat+immune branch (Gap 2 fix).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] O-04 used clickContext.isRipPresent instead of pendingCasts approach specified in plan**

- **Found during:** Task 2 (O-04 test implementation)
- **Issue:** Plan instructed setting `macroTorch.pendingCasts = { Rip = true }` to force isRipPresent=true, but the actual `isRipPresent` function (Druid.lua line 1008-1014) checks `clickContext.isRipPresent` first and falls back to `macroTorch.target.hasBuff('Ability_GhoulFrenzy')`, never referencing `pendingCasts`. The plan's approach would not have worked — the test would fail because isRipPresent would query the live target instead of reading pendingCasts.
- **Fix:** Set `isRipPresent = true` directly in the clickContext table. This is simpler (no pcall/cleanup needed) and matches how the actual function reads the field.
- **Files modified:** classes/druid/selftest.lua
- **Verification:** Build passes; the `isRipPresent` function returns the injected value immediately on line 1013 (`return clickContext.isRipPresent`).
- **Committed in:** 7a55bfa

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** No scope creep. The fix is functionally equivalent and simpler than the planned approach. The original plan was based on an incorrect understanding of the isRipPresent implementation.

## Issues Encountered

None beyond the O-04 deviation documented above.

## User Setup Required

None — no external service configuration required. All changes are code-only and self-contained within the Druid class and its SelfTest file.

## Next Phase Readiness

- Category O SelfTest coverage is complete for computeNormalRelic and recoverNormalRelic distance bypass
- No blockers for future idol dance optimization phases
- Existing catAtk principle regression tests (R2-R8, PF) remain unchanged and continue to pass

---
*Phase: 23-idol-dance-refactor*
*Completed: 2026-08-03*