---
phase: 22-catatk-selftest-catatk-core-principles-md-d
reviewed: 2026-07-31T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/selftest.lua
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-07-31
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed `classes/druid/selftest.lua` (585 lines, 43 SelfTest registrations for catAtk principle regression tests across two batches). No security vulnerabilities or data-loss risks found. Three warning-level issues were identified: incomplete clickContext tables in the R6 test series can cause Lua nil-arithmetic runtime errors when the player has Tiger's Fury active; dead code in R8-04 where `erps` is computed but never used; and incomplete context tables in R8-05/R8-06 passed to `shouldDoReshift`, which internally calls `getNextAbilityCost` with missing required fields. Three informational items cover code duplication, indentation inconsistency, and the systemic silent-test-skip pattern.

Note: `macroTorch.player.isInCombat` was traced to `entity/Unit.lua:226-228` where it is defined as a metatable `__index` function that auto-resolves to a boolean on property access. This is the intended pattern across the codebase (verified by `core/selftest.lua:344-345`). The property access without `()` seen throughout the file is correct.

---

## Warnings

### WR-01: R6-01 through R6-05 -- incomplete clickContext causes nil-arithmetic error in computeErps when Tiger's Fury is active

**File:** `classes/druid/selftest.lua:328-393`

**Issue:** Tests R6-01 through R6-05 call `macroTorch.shouldUseShred(ctx)` which unconditionally invokes `macroTorch.computeErps(ctx)` (Druid.lua:699). The ctx objects in these five tests omit the baseline fields required by `computeErps()`:

Missing fields: `AUTO_TICK_ERPS`, `TIGER_ERPS`, `RAKE_ERPS`, `RIP_ERPS`, `POUNCE_ERPS`, `BERSERK_ERPS`, `berserk`, `hasEssenceOfTheRed`, `isTigerPresent`.

In `computeErps()` (Druid.lua:801-829), line 807 initializes `erps = clickContext.AUTO_TICK_ERPS` (nil when absent). When the player has Tiger's Fury active, `macroTorch.isTigerPresent(clickContext)` (Druid.lua:978-983) falls back to querying live game state (since `clickContext.isTigerPresent` is nil), and returns true. Line 809 then evaluates `erps + clickContext.TIGER_ERPS` which is `nil + nil`, producing a Lua runtime error: "attempt to perform arithmetic on a nil value".

When Tiger's Fury is NOT active, `computeErps` returns nil without error, and the early-return paths in `shouldUseShred` (line 706 for R6-01/02/03, line 726 for R6-04, line 728 for R6-05) prevent the nil result from being used in later arithmetic. The nil return is also cached as `clickContext.computeErps = nil` (line 828), which could cause downstream issues if the ctx is reused.

R6-06 (line 395) correctly includes the full computeErps baseline and serves as a reference for the canonical set of fields.

**Fix:** Add the computeErps baseline fields to R6-01 through R6-05. Using R6-06 as the canonical reference:

```lua
-- Add to R6-01 ctx (lines 329-337), R6-02 ctx (lines 344-350),
-- R6-03 ctx (lines 357-364), R6-04 ctx (lines 370-377),
-- and R6-05 ctx (lines 382-390):

AUTO_TICK_ERPS = 10,
TIGER_ERPS = 10 / 3,
RAKE_ERPS = 0,
RIP_ERPS = 0,
POUNCE_ERPS = 0,
BERSERK_ERPS = 10,
berserk = false,
hasEssenceOfTheRed = false,
isTigerPresent = false,
```

Setting `isTigerPresent = false` prevents the live-state fallback query, making the test deterministic regardless of buff state.

---

### WR-02: Dead code -- `erps` computed but never used in R8-04

**File:** `classes/druid/selftest.lua:511-512`

**Issue:** Lines 511-512 compute `erps` from `computeErps(ctx)` and apply a nil-guard fallback of 10, but the variable `erps` is never referenced anywhere in the rest of the R8-04 test body. The subsequent logic only uses `minAbilityCost` (from `getNextAbilityCost`) and `macroTorch.player.mana`. This is a vestigial computation, likely copied from the R8-05/R8-06 test structure where `erps` is legitimately used for energy projection and wait-window calculation. In R8-04, computing `erps` also triggers the same incomplete-ctx issue as WR-01 if Tiger's Fury is active (ctx has only `{ ooc = false }`).

**Fix:** Remove lines 511-512:

```lua
-- Remove lines 511-512:
-- local erps = macroTorch.computeErps(ctx)
-- if erps == nil then erps = 10 end
```

---

### WR-03: R8-05 and R8-06 pass incomplete context to shouldDoReshift and getNextAbilityCost

**File:** `classes/druid/selftest.lua:509 (R8-04), 519-549 (R8-05), 551-581 (R8-06)`

**Issue:** Tests R8-04, R8-05, and R8-06 construct context tables missing fields required by the downstream call chain:

- **R8-04** (line 509): ctx is `{ ooc = false }`. `getNextAbilityCost(ctx)` (Druid.lua:874-903) internally calls `shouldUseBite(ctx)` (Druid.lua:933-958). At line 940, `shouldUseBite` evaluates `clickContext.comboPoints > 0` when `isKillShotOrLastChance` returns true. With `comboPoints` absent (nil), this becomes `nil > 0`, producing a Lua error. At line 948, `clickContext.comboPoints >= 3` produces the same error.

- **R8-05** (line 536) and **R8-06** (line 568): call `shouldDoReshift(ctx)` with ctx missing: `CLAW_E`, `SHRED_E`, `BITE_E`, `RAKE_E`, `RIP_E`, `TIGER_E`, `comboPoints`, `isImmuneRake`. `shouldDoReshift` (cat.lua:197-216) calls `getNextAbilityCost(ctx)` at line 212, which triggers the same `shouldUseBite`-to-`comboPoints` nil-comparison path.

The guard conditions at lines 500/508/520/552 (`if not macroTorch.player.isInCombat then return end`) mitigate some risk — if the player is not in combat, the test skips before reaching the problematic calls. But once in combat, execution depends on live game state (target health for `isKillShotOrLastChance`, mana values for energy guards), making these tests non-deterministic and potentially error-prone.

**Fix:** Provide complete context tables for these tests. For R8-04 as the most minimal case:

```lua
local ctx = {
    ooc = false,
    -- Required by getNextAbilityCost chain
    comboPoints = 0,
    isRipPresent = false,
    isImmuneRip = false,
    isImmuneRake = false,
    isTrivialBattle = false,
    isFightStarted = true,
    isNearBy = true,
    CLAW_E = 45,
    SHRED_E = 60,
    BITE_E = 35,
    RAKE_E = 40,
    RIP_E = 30,
    TIGER_E = 30,
    -- Required by computeErps chain
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

For R8-05 and R8-06, add the ability-cost and combo-point fields to the existing ctx tables, or replace the `shouldDoReshift(ctx)` guard with an inline energy projection check that matches the computation already present in the test body.

---

## Info

### IN-01: Significant code duplication between R8-05 and R8-06

**File:** `classes/druid/selftest.lua:519-581`

**Issue:** R8-05 (wait window too short, no FF) and R8-06 (wait window sufficient, cast FF) share approximately 50 lines of nearly identical code. The only differences are the guard condition (line 546: `waitSeconds >= 1.0` vs line 578: `waitSeconds < 1.0`) and the assertion. Any change to the context construction, erps computation, energy projection, or wait time calculation must be made in two places synchronously.

**Fix:** Extract the shared logic (context construction, erps/energy/wait-time computation) into a local helper function within the test, or parameterize the diverging guard and assertion.

---

### IN-02: Code duplication between R2-06 and R2-07

**File:** `classes/druid/selftest.lua:148-212`

**Issue:** Same duplication pattern as IN-01. R2-06 (1.5s natural recovery sufficient, no reshift) and R2-07 (1.5s recovery insufficient, reshift triggered) share approximately 50 lines of identical context setup and energy projection logic, differing only in the guard condition (line 176: `math.ceil(projectedEnergy) < nextAbilityCost` vs line 209: `math.ceil(projectedEnergy) >= nextAbilityCost`) and the assertion.

**Fix:** Apply the same extraction approach suggested for IN-01.

---

### IN-03: Inconsistent indentation between test batches

**File:** `classes/druid/selftest.lua:23-108 (Batch 1) vs 110-583 (Batch 2)`

**Issue:** Batch 1 tests (PF-01 through R9-03, lines 23-108) use a single tab indentation level from the enclosing `if UnitClass('player') == 'Druid' then` block. Batch 2 tests (R2 through R8, lines 110-583) use a deeper double tab indentation level. This creates visual misalignment between the two batches at the same logical nesting depth and increases the effort required to scan the file.

**Fix:** Normalize indentation to a consistent level throughout. For example, align Batch 2 tests to the same single-tab level as Batch 1, since both are at the same depth within the `if UnitClass` guard.

---

_Reviewed: 2026-07-31T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_