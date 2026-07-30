---
phase: 22-catatk-selftest-catatk-core-principles-md-d
plan: "02"
subsystem: testing
tags: [selftest, catatk, druid, lua, regression-tests, principles]

# Dependency graph
requires:
  - phase: "22-01"
    provides: "Batch 1 SelfTest registrations (PF-01~07, R9-01~03) + selftest.lua scaffold"
provides:
  - "43 total SelfTest registrations (10 Batch 1 + 33 Batch 2) covering R2, R4+R5, R6, R7, R8 design principles"
  - "Complete catAtk regression test suite for all boolean decision functions"
affects: []
tech-stack:
  added: []
  patterns:
    - "Pattern A: Pure function tests with direct input/output assertion"
    - "Pattern B: clickContext preset tests bypassing game state via cached fields"
    - "Pattern C: Conditional skip guards for game-state-dependent test preconditions"

key-files:
  created: []
  modified:
    - classes/druid/selftest.lua

key-decisions:
  - "All 43 tests use isOptional=true (Druid-only, non-blocking for other classes)"
  - "Game-state-dependent tests use Pattern C conditional skip guards instead of mocking"
  - "R2-06/R2-07 and R8-05/R8-06 are complementary pairs — exactly one asserts per run based on current player.mana"
  - "isTigerPresent=true preset forces getNextAbilityCost past Tiger check in R2-06/R2-07"
  - "All energy cost fields (CLAW_E, SHRED_E, BITE_E, etc.) included in ctx for getNextAbilityCost stability"

patterns-established:
  - "SelfTest:register with clickContext preset and conditional skip guards"
  - "Principle R<n>-<nn> naming convention for principle-to-test traceability"

requirements-completed:
  - PF-01
  - PF-02
  - PF-03
  - PF-04
  - PF-05
  - PF-06
  - PF-07
  - R2-01
  - R2-02
  - R2-03
  - R2-04
  - R2-05
  - R2-06
  - R2-07
  - R4-01
  - R4-02
  - R4-03
  - R4-04
  - R5-01
  - R5-02
  - R5-03
  - R5-04
  - R6-01
  - R6-02
  - R6-03
  - R6-04
  - R6-05
  - R6-06
  - R7-01
  - R7-02
  - R7-03
  - R7-04
  - R7-05
  - R7-06
  - R8-01
  - R8-02
  - R8-03
  - R8-04
  - R8-05
  - R8-06
  - R9-01
  - R9-02
  - R9-03

# Coverage metadata
# Note: Tests cannot execute outside WoW client; verification status is 'unknown' until human runs /mt in-game.
coverage:
  - id: D1
    description: "43 SelfTest registrations covering catAtk conditional decision functions (shouldDoReshift, shouldCastRip, shouldUseShred, shouldUseBite, shouldCastFFDuringWaitWindow) across 6 design principles (R2, R4, R5, R6, R7, R8)"
    verification:
      - kind: unit
        ref: "classes/druid/selftest.lua — 43 SelfTest:register calls with assert-based validation"
        status: unknown
      - kind: other
        ref: "./build.sh — syntax validation (passes)"
        status: pass
    human_judgment: true
    rationale: "Tests execute inside WoW client via /mt command. Cannot be run in CI — requires Druid login and in-game context. Build script only validates Lua syntax; assertion logic must be verified by human in-game."

# Metrics
duration: 8min
completed: 2026-07-30
status: complete
---

# Phase 22 Plan 02: Batch 2 Conditional Decision Tests Summary

**43 SelfTest registrations covering catAtk boolean decision functions across Rules 2/4/5/6/7/8 with clickContext presets and conditional skip guards**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-30T15:38:55Z
- **Completed:** 2026-07-30T15:46:55Z
- **Tasks:** 2
- **Files modified:** 1 (classes/druid/selftest.lua — 584 lines)

## Accomplishments

- Batch 2A: 15 tests covering R2 reshift decisions (R2-01~07) and R4+R5 bleed primacy (R4-01~04, R5-01~04)
- Batch 2B: 18 tests covering R6 builder choice (R6-01~06), R7 bite trigger (R7-01~06), and R8 FF fill (R8-01~06)
- Combined with Batch 1 from Plan 22-01: 43 total SelfTest registrations across 10 principle tests + 7 pure function tests + 26 conditional decision tests
- All tests follow Pattern B (clickContext preset) or Pattern C (conditional skip) from 22-CONTEXT.md
- All tests use `"Principle R<n>-<nn>: description"` naming per D-03 convention
- Single `if UnitClass('player') == 'Druid' then` guard block with `isOptional = true` for all 43 tests
- Build succeeds: `./build.sh` produces valid SM_Extend.lua with no syntax errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Append Batch 2A — R2 reshift + R4+R5 bleed primacy tests** - `62133ef` (test)
2. **Task 2: Append Batch 2B — R6 builder choice + R7 bite trigger + R8 FF fill tests** - `0f8fd38` (test)

## Files Created/Modified

- `classes/druid/selftest.lua` — 584 lines, 43 SelfTest registrations. Batch 1 (PF-01~07, R9-01~03: 10 tests), Batch 2 (R2-01~07, R4-01~04, R5-01~04, R6-01~06, R7-01~06, R8-01~06: 33 tests). Ordered by rule number 2->4->5->6->7->8 per D-01.

## Decisions Made

- None — followed plan as specified. Minor fixes applied via deviation rules (see Deviations section).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] isTigerPresent preset corrected from false to true in R2-06/R2-07**

- **Found during:** Task 1 (R2-06/R2-07 implementation)
- **Issue:** Plan specified `isTigerPresent = false` for R2-06/R2-07 ctx construction, intending to skip past the Tiger check in getNextAbilityCost. But `shouldUseBite` returns false, and `not isTigerPresent` with false would enter the Tiger branch (returning TIGER_E), not skip past it. The function `not macroTorch.isTigerPresent(ctx)` means "Tiger is NOT present" — when Tiger IS present (true), the NOT check is false and the function continues past the Tiger branch.
- **Fix:** Changed `isTigerPresent = false` to `isTigerPresent = true` so getNextAbilityCost continues past the Tiger check to ultimately return CLAW_E=45.
- **Files modified:** classes/druid/selftest.lua (R2-06 and R2-07 ctx construction)
- **Verification:** Build succeeds. Logic verified by code review of getNextAbilityCost flow: shouldUseBite→false, not isTigerPresent→false, shouldCastRip→false, shouldUseShred→false → returns CLAW_E.

**2. [Rule 1 - Bug] Missing energy cost fields in R2-06/R2-07 ctx**

- **Found during:** Task 1 (R2-06/R2-07 implementation)
- **Issue:** getNextAbilityCost reads clickContext.CLAW_E, clickContext.SHRED_E, clickContext.BITE_E, clickContext.TIGER_E, clickContext.RIP_E, clickContext.RAKE_E. Plan didn't include these fields in the ctx construction. Nil values would cause Lua comparison errors in the guard computation.
- **Fix:** Added CLAW_E=45, SHRED_E=60, BITE_E=35, RAKE_E=40, RIP_E=30, TIGER_E=30 to both R2-06 and R2-07 ctx tables.
- **Files modified:** classes/druid/selftest.lua (R2-06 and R2-07 ctx construction)
- **Verification:** Build succeeds. getNextAbilityCost returns CLAW_E=45 as expected.

**3. [Rule 2 - Missing Critical] Added in-combat guards to game-state-dependent tests**

- **Found during:** Task 1 and Task 2 (all shouldDoReshift and shouldCastFFDuringWaitWindow tests)
- **Issue:** shouldDoReshift and shouldCastFFDuringWaitWindow both read `macroTorch.player.isInCombat` directly (not from ctx). If the player is not in combat, these functions return false at early guards, making tests pass for the wrong reason (false positive). The plan mentioned in-combat guards explicitly for R2-03 and R2-04 but not for R2-05~07, R8-03~06.
- **Fix:** Added `if not macroTorch.player.isInCombat then return end` guards to R2-05, R2-06, R2-07, R8-03, R8-04, R8-05, R8-06. This ensures the test skips when the precondition (in-combat) is not met, preventing false-positive assertions.
- **Files modified:** classes/druid/selftest.lua (7 test functions)
- **Verification:** Build succeeds. Guards match Pattern C convention from CONTEXT.md.

**4. [Rule 1 - Bug] Missing computeErps context fields in R6-06**

- **Found during:** Task 2 (R6-06 implementation)
- **Issue:** R6-06 tests the "not isTrivialBattleOrPvp AND not isImmuneRip AND not isRipPresent → use Claw" branch of shouldUseShred. This branch requires `energyIn1s < CLAW_E` to not be caught by the earlier guard. computeErps needs AUTO_TICK_ERPS and related fields to produce a value < CLAW_E (45). Plan specified CLAW_E=45 but didn't include erps context fields.
- **Fix:** Added AUTO_TICK_ERPS=10, RAKE_ERPS=0, RIP_ERPS=0, POUNCE_ERPS=0, BERSERK_ERPS=10, berserk=false, hasEssenceOfTheRed=false, and isTigerPresent=false to ensure computeErps returns 10 (which is < CLAW_E=45).
- **Files modified:** classes/druid/selftest.lua (R6-06 ctx construction)
- **Verification:** Build succeeds. computeErps returns 10 (baseline only, no buffs present), energyIn1s=10 < CLAW_E=45.

---

**Total deviations:** 4 auto-fixed (3 Rule 1 bug fixes, 1 Rule 2 missing critical)
**Impact on plan:** All fixes necessary for test correctness. No scope creep. Test count is 43 (not the estimated ~38) because the plan's task actions explicitly define 33 Batch 2 tests — the ~38 was an approximation.

## Issues Encountered

None — all tasks completed without blocking issues.

## Known Stubs

None — all 43 tests have concrete assertions with expected values and are ready for in-game execution via `/mt`.

## Threat Flags

None — this plan only adds SelfTest registrations with read-only assertions. No new network endpoints, auth paths, or trust boundaries introduced.

## User Setup Required

None — no external service configuration required. Tests execute within the WoW client via the existing `/mt` slash command.

## Next Phase Readiness

- Phase 22 complete: 43 SelfTest registrations covering all testable catAtk design principles
- Batch 3 (side-effect verification tests for R1, R12) deferred to a future phase per D-02
- Ready for in-game verification: run `/mt` on a Druid character to execute all 43 registered tests

---
## Self-Check: PASSED

- SUMMARY.md exists at expected path
- Task 1 commit `62133ef` exists in git history
- Task 2 commit `0f8fd38` exists in git history
- `classes/druid/selftest.lua` exists (584 lines, 43 registrations)
- `./build.sh` succeeds

---
*Phase: 22-catatk-selftest-catatk-core-principles-md-d*
*Completed: 2026-07-30*