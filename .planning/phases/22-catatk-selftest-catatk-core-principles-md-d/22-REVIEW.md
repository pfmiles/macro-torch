---
phase: 22-catatk-selftest-catatk-core-principles-md-d
reviewed: 2026-07-31T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/selftest.lua
  - build_order.txt
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-07-31
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed `classes/druid/selftest.lua` (585 lines, 43 SelfTest registrations for catAtk principle regression tests) and `build_order.txt` (58 lines, build order manifest). One BLOCKER-level bug was found: R6-01 through R6-05 have incomplete `clickContext` objects that can cause runtime Lua arithmetic errors when the player has live buffs (Tiger's Fury, Berserk). Four WARNING-level issues cover incomplete ctx objects in R8-04, inconsistent field presets across the R4/R5 test series, silent test skipping that masks missing coverage, and indentation style inconsistency. Two INFO items note the isOptional=true assignment for pure-function tests and a test-count discrepancy between phase plan and implementation.

---

## Critical Issues

### CR-01: R6-01 through R6-05 -- Incomplete clickContext can cause nil arithmetic error in computeErps

**File:** `classes/druid/selftest.lua:328-393`
**Issue:** Tests R6-01 through R6-05 call `shouldUseShred(ctx)`, which unconditionally invokes `computeErps(ctx)` at Druid.lua line 699. The ctx objects for these five tests lack the baseline fields required by `computeErps()`:

Missing fields: `AUTO_TICK_ERPS`, `TIGER_ERPS`, `RAKE_ERPS`, `RIP_ERPS`, `POUNCE_ERPS`, `BERSERK_ERPS`, `berserk`, `hasEssenceOfTheRed`, `isTigerPresent`.

In `computeErps()` (Druid.lua:801-830):
```lua
local erps = clickContext.AUTO_TICK_ERPS  -- nil (field not in ctx)
if macroTorch.isTigerPresent(clickContext) then  -- queries live game state
    erps = erps + clickContext.TIGER_ERPS  -- nil + nil = Lua error!
end
```

When the player has Tiger's Fury active (or Berserk, or Essence of the Red), `computeErps` attempts arithmetic on nil values (`nil + nil` or `nil + number`), causing a Lua runtime error. The pcall wrapper in `SelfTest:run()` catches the error, but it produces a spurious test failure unrelated to the principle being tested.

Even when no live buffs trigger the conditional branches, `computeErps` returns nil and caches `clickContext.computeErps = nil` on the ctx object, polluting the cache for any downstream code that reuses the ctx.

R6-06 (line 395) correctly includes all computeErps fields and serves as the reference for the canonical baseline.

**Fix:**
Add the canonical computeErps baseline fields to tests R6-01 through R6-05. For R6-01 (the most impactful example):

```lua
-- R6-01: BEFORE (lines 329-337)
local ctx = {
    ooc = true,
    isBehind = true,
    isRakePresent = false,
    isRipPresent = false,
    isPouncePresent = false,
    isPseudoInfiniteEnergy = false,
    CLAW_E = 45,
}

-- R6-01: AFTER
local ctx = {
    ooc = true,
    isBehind = true,
    isRakePresent = false,
    isRipPresent = false,
    isPouncePresent = false,
    isPseudoInfiniteEnergy = false,
    CLAW_E = 45,
    -- computeErps baseline (prevents nil arithmetic)
    AUTO_TICK_ERPS = 10,
    TIGER_ERPS = 10 / 3,
    RAKE_ERPS = 0,
    RIP_ERPS = 0,
    POUNCE_ERPS = 0,
    BERSERK_ERPS = 10,
    berserk = false,
    hasEssenceOfTheRed = false,
    isTigerPresent = false,
}
```

Apply the same baseline fields to R6-02, R6-03, R6-04, and R6-05 (lines 343-393).

---

## Warnings

### WR-01: R8-04 -- Fragile ctx with incomplete fields; downstream nil arithmetic risk

**File:** `classes/druid/selftest.lua:507-517`
**Issue:** R8-04 creates ctx `{ ooc = false }` and calls `computeErps(ctx)` and `getNextAbilityCost(ctx)` with this minimal object. While line 512 includes a defensive nil-guard (`if erps == nil then erps = 10 end`), the subsequent call to `getNextAbilityCost(ctx)` can return nil for the ability cost (e.g., when `shouldUseBite` or `shouldUseShred` resolves with missing fields). When `minAbilityCost` is nil, the guard `if macroTorch.player.mana < nil then return end` evaluates to false in Lua (nil comparison always returns false), so the test does NOT skip. Execution continues into `shouldCastFFDuringWaitWindow`, which internally calls `shouldDoReshift(ctx)` with the same incomplete ctx. If the target is not immune to Faerie Fire and not in kill-shot phase, `shouldDoReshift` reaches `computeErps(ctx)` with nil `AUTO_TICK_ERPS`, triggering the same class of nil-arithmetic error described in CR-01.

The test behavior depends heavily on live game state (player mana, target immunity, kill-shot status), making it non-deterministic.

**Fix:** Either provide the full computeErps/getNextAbilityCost baseline fields in the ctx, or harden the guard to also skip when `minAbilityCost` is nil:

```lua
local minAbilityCost = macroTorch.getNextAbilityCost(ctx)
if minAbilityCost == nil or macroTorch.player.mana < minAbilityCost then return end
```

Better still, provide the canonical baseline ctx fields so the function chain operates deterministically:

```lua
local ctx = {
    ooc = false,
    AUTO_TICK_ERPS = 10,
    TIGER_ERPS = 10 / 3,
    RAKE_ERPS = 0,
    RIP_ERPS = 0,
    POUNCE_ERPS = 0,
    BERSERK_ERPS = 10,
    berserk = false,
    hasEssenceOfTheRed = false,
    isTigerPresent = false,
    isRakePresent = false,
    isRipPresent = false,
    isPouncePresent = false,
    CLAW_E = 45,
    SHRED_E = 60,
    BITE_E = 35,
    RAKE_E = 40,
    RIP_E = 30,
    TIGER_E = 30,
    comboPoints = 0,
    isImmuneRip = false,
    isImmuneRake = false,
    isTrivialBattle = false,
    isFightStarted = true,
    isNearBy = true,
    isBehind = true,
    isPseudoInfiniteEnergy = false,
    prowling = false,
    RESHIFT_ENERGY = 40,
}
```

### WR-02: Inconsistent ctx field presets across R4 and R5 test series

**File:** `classes/druid/selftest.lua:216-324`
**Issue:** Within the `shouldCastRip` test series, R4-01 explicitly presets both `rough = false` and `isTrivialBattle = false` in its ctx. However, R4-02 (line 231), R4-03 (line 244), and R4-04 (line 257) omit both fields entirely. In `shouldCastRip` (Druid.lua:923), these fields gate the battle-type path:
```lua
if macroTorch.isTrivialBattleOrPvp(clickContext) or clickContext.rough then
    -- Quick battle: 1-2 CP
else
    -- Normal battle: 5 CP
end
```
When `isTrivialBattle` is omitted (nil), the `isTrivialBattle(clickContext)` function computes it from live game state (target health, estimated DPS, nearby player count), which can differ from the intended test scenario. Similarly, when `rough` is omitted (nil, falsy), the behavior is correct by accident -- nil is falsy so the normal battle path is taken -- but it is inconsistent with R4-01 which explicitly sets it.

R5-01 through R5-04 set `isTrivialBattle` explicitly but omit `rough` (nil, defaulting to falsy).

**Fix:** Add explicit `rough = false` to all R4 and R5 ctx objects for consistency with R4-01. Add explicit `isTrivialBattle` to R4-02 through R4-04 (already set to false in R4-01; set to true in R5-01 through R5-03, and false in R5-04).

### WR-03: Test skip guards produce silent pass without assertion verification

**File:** `classes/druid/selftest.lua` -- multiple locations (see below)
**Issue:** The `SelfTest:run()` framework (core/selftest.lua:61-62) counts any pcall-successful test function execution as "passed", even if the function body returns early via a skip guard and never reaches an `assert`. This means tests that silently skip are indistinguishable from tests that actually verified their assertions.

Affected tests and their skip conditions:

| Test | Line | Skip Condition |
|------|------|----------------|
| R2-05 | 143 | `isKillShotOrLastChance(ctx)` returns false (depends on live target health) |
| R2-06 | 176 | `math.ceil(projectedEnergy) < nextAbilityCost` (depends on live player mana) |
| R2-07 | 209 | `math.ceil(projectedEnergy) >= nextAbilityCost` (depends on live player mana) |
| R7-01 | 424 | `isKillShotOrLastChance(ctx)` returns false |
| R7-02 | 430 | `isKillShotOrLastChance(ctx)` returns false |
| R8-04 | 514 | `player.mana < minAbilityCost` (depends on live mana and context) |
| R8-05 | 536-546 | Multiple guards depending on live mana and erps |
| R8-06 | 568-578 | Multiple guards depending on live mana and erps |

When these guards trigger, the test is recorded as "passed" even though no principle was verified. There is no mechanism to detect or report skipped tests, making it impossible to know whether these principles are actually being tested in any given session.

**Fix:** This is a systemic issue in the SelfTest framework design. The recommended approach for this file is to add debug-mode logging when a guard triggers a skip, so at least during development, skips are visible:

```lua
-- Example for R2-05
if not macroTorch.isKillShotOrLastChance(ctx) then
    -- macroTorch.show("[self-test] R2-05: skipped (not in kill shot phase)", 'debug')
    return
end
```

Alternatively, a separate skip counter in `SelfTest:run()` could track how many tests skipped vs. actually ran assertions. But this is a framework-level change and may be out of scope for this phase.

### WR-04: Indentation inconsistency between Batch 1 and Batch 2

**File:** `classes/druid/selftest.lua:21-108 (Batch 1) vs 110-583 (Batch 2)`
**Issue:** Batch 1 (PF-01 through R9-03) uses space indentation (2 spaces per level). Starting at line 110, Batch 2 (R2 through R8 tests) switches to tab indentation. This makes the file harder to read and maintain, and is inconsistent with the project's other Lua files which generally use 2-space indentation.

The container `if UnitClass('player') == 'Druid' then` at line 19 uses 0 indentation, but the Batch 2 tests inside it (line 110 onward) use deep tab indentation that does not align with the Batch 1 tests at the same nesting level.

**Fix:** Normalize all indentation in the file to 2-space indentation. The Batch 2 tests should be indented 1 level (2 spaces) from the `if UnitClass` guard, matching the Batch 1 test indentation.

---

## Info

### IN-01: Pure function tests marked optional could be core

**File:** `classes/druid/selftest.lua` -- all `register()` calls
**Issue:** All 43 tests in this file pass `true` as the third argument to `SelfTest:register()`, marking them all as optional. The following tests are pure functions that do not depend on live game state and should arguably be core (`isOptional=false`):

- PF-04, PF-05 (`estimatePlayerDPS`): pure level-to-DPS mapping
- PF-06, PF-07 (`computeErps`): pure arithmetic on ctx fields (all fields preset)
- R9-01, R9-02, R9-03 (`getKSThreshold`): pure level-to-threshold mapping

When marked optional, a failure in these tests produces a yellow "WARN" message rather than a red "FAIL". Since these pure functions have no external dependencies, any failure indicates a genuine regression in the principle implementation and should produce a red error.

**Fix:** Change the third argument from `true` to `false` for PF-04, PF-05, PF-06, PF-07, R9-01, R9-02, and R9-03.

### IN-02: Test count discrepancy -- 43 registrations vs. "~38" in phase plan

**File:** `classes/druid/selftest.lua` -- test count
**Issue:** The phase plan (captured in the phase directory) references "~38 SelfTest regression tests", but the file contains 43 `SelfTest:register()` calls. While "~38" uses the approximate qualifier, 43 is outside the typical ~10% tolerance for approximate counts (43 is ~13% above 38). The breakdown:

- Batch 1: PF-01..PF-07 (7) + R9-01..R9-03 (3) = 10 tests
- Batch 2: R2-01..R2-07 (7) + R4-01..R4-04 (4) + R5-01..R5-04 (4) + R6-01..R6-06 (6) + R7-01..R7-06 (6) + R8-01..R8-06 (6) = 33 tests
- Total: 43

This is likely due to R8 tests (6) being added after the initial estimate. Not a defect, but worth noting for plan-vs-implementation traceability.

---

_Reviewed: 2026-07-31T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_