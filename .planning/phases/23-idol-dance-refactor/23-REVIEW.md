---
phase: 23-idol-dance-refactor
reviewed: 2026-08-04T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/Druid.lua
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-08-04T00:00:00Z
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed the diff for `classes/druid/Druid.lua` in which the `isTrivialBattleOrPvp` guard was moved from its prior position inside the in-combat branch to the very top of `computeNormalRelic()`.

**Before (prior code):** Non-combat checks ran first (lines 370-375), then `isTrivialBattleOrPvp` was checked only after confirming the player was in combat.

**After (current code):** `isTrivialBattleOrPvp` is the first check (line 366), above both non-combat branches.

**Behavioral change:** When `isTrivialBattleOrPvp` is true AND the player is out of combat AND the target is not immune to Rip, the prior code would return Savagery (non-combat -> non-immune path). The current code returns Builder (top-level guard fires first). This is consistent with the Gap 1 fix intent: trivial-fast or PvP targets should never waste GCD on Savagery swaps.

**Verdict:** The logic change is correct. All branches are exhaustive and the precedence order (trivial/PvP > non-combat > combat) is sound. One selftest (O-06) has a flakiness risk because it depends on the current target not being trivial.

## Warnings

### WR-01: Self-test O-06 is flaky — no trivial-target guard on test context

**File:** `classes/druid/selftest.lua:720-727`
**Issue:** Test "Cat O-06: Non-combat non-immune returns Savagery (D-02 preserved)" asserts that `computeNormalRelic` returns `'Idol of Savagery'` when the player is out of combat and the target is not immune to Rip. However, the test context does not set `isTrivialBattle = false`. With the moved top-level guard, `isTrivialBattleOrPvp(ctx)` now runs first. If the currently targeted enemy is trivial (low enough health for `willDieInSeconds(25)` to return true, or `healthMax` under the DPS threshold), `isTrivialBattle()` evaluates to true, the new top-level guard fires, and `computeNormalRelic` returns Builder instead of Savagery — causing a false assertion failure.

The test already has a combat-state guard (`if macroTorch.player.isInCombat then return end`), but that does not prevent the trivial-target case from triggering. The test outcome now depends on which enemy the player happens to be targeting at selftest time.

**Fix:** Pin `isTrivialBattle = false` in the test context:

```lua
macroTorch.SelfTest:register("Cat O-06: Non-combat non-immune returns Savagery (D-02 preserved) — per D-01", function()
    if macroTorch.player.isInCombat then return end
    local ctx = {
        isImmuneRip = false,
        isTrivialBattle = false,   -- ensure normal-battle path, not short-circuited by trivial guard
    }
    assert(macroTorch.computeNormalRelic(ctx) == 'Idol of Savagery',
        "expected Savagery for non-combat non-immune, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)
```

## Info

### IN-01: `isTrivialBattleOrPvp` does not cache on clickContext (inconsistent memoization pattern)

**File:** `classes/druid/Druid.lua:744-747`
**Issue:** Most boolean predicates in this module cache their result on `clickContext` (see `isNearBy` at line 981, `isTigerPresent` at line 992, `isRipPresent` at line 1015). `isTrivialBattleOrPvp` does not cache, recomputing `macroTorch.target.isPlayerControlled` on every call. Its inner helper `isTrivialBattle` does cache via `clickContext.isTrivialBattle`, so only the `isPlayerControlled` half lacks caching. This is functionally harmless (the property is cheap) but inconsistent with the module's established pattern.

**Fix (optional):** Cache the result if consistency is desired:

```lua
function macroTorch.isTrivialBattleOrPvp(clickContext)
    if clickContext.isTrivialBattleOrPvp == nil then
        clickContext.isTrivialBattleOrPvp = macroTorch.target.isPlayerControlled or
                macroTorch.isTrivialBattle(clickContext)
    end
    return clickContext.isTrivialBattleOrPvp
end
```

### IN-02: Redundant conditional in `selectFerocityOrEmeraldRot`

**File:** `classes/druid/Druid.lua:411`
**Issue:** The condition `if hasFerocity and hasEmeraldRot then` on line 411 is the only remaining input state by the time execution reaches it. Lines 403 and 406 exhaust the single-ownership cases (`(hasFerocity, not hasEmeraldRot)` and `(not hasFerocity, hasEmeraldRot)`). Line 420 catches the zero-ownership case (`(not hasFerocity, not hasEmeraldRot)`). The explicit boolean AND on line 411 is logically redundant — it always evaluates to true when reached.

**Fix:** Simplify to `else` or `elseif hasFerocity then`:

```lua
    -- If both exist, choose based on 8/8 Cenarion T1
    if player.countEquippedItemNameContains('Cenarion') >= 8 then
        return IDOL_FEROCITY
    else
        return IDOL_EMERALD_ROT
    end
```

### IN-03: Tests O-01 and O-02 have vestigial in-combat guards

**File:** `classes/druid/selftest.lua:670, 680`
**Issue:** Both O-01 ("fast combat" test) and O-02 ("PvP target" test) guard with `if not macroTorch.player.isInCombat then return end`. These guards were necessary when `isTrivialBattleOrPvp` was only checked inside the in-combat branch — out-of-combat calls would take the non-combat Savagery path and fail. After moving the guard to the top of `computeNormalRelic`, these tests would pass correctly in either combat state. The guards are harmless but create the false impression that the tested behavior (fast combat/PvP always returns Builder) only applies in combat, which is no longer accurate.

**Fix:** Either remove the guards (if the test environment supports out-of-combat testing) or add a comment explaining they are legacy:

```lua
-- Legacy guard: no longer required since computeNormalRelic checks isTrivialBattleOrPvp first,
-- but retained to avoid running on unintended targets outside of dedicated test environments.
if not macroTorch.player.isInCombat then return end
```

---

_Reviewed: 2026-08-04T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_