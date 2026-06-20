---
phase: 13-catatk-60-dps
reviewed: 2026-06-20T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/cat.lua
findings:
  critical: 0
  warning: 5
  info: 3
  total: 8
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-06-20T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed `classes/druid/Druid.lua` (1436 lines) and `classes/druid/cat.lua` (418 lines), which together implement the Druid class definition, cat form combat rotation (`catAtk`), buff/debuff duration tracking, energy regeneration computation, reshift logic, relic/idol management, kill shot prediction, and numerous helper functions for feral DPS optimization.

No critical (BLOCKER) issues were found. The code logic is generally correct for the intended WoW 1.12.1/Turtle WoW environment. Five warnings and three info-level items were identified, primarily around null safety inconsistency, type convention violations, and dead code.

## Warnings

### WR-01: Missing `loginContext` null guard in `tigerLeft` (inconsistent with sibling functions)

**File:** `classes/druid/Druid.lua:1089`
**Issue:** `tigerLeft` accesses `macroTorch.loginContext.tigerTimer` without checking whether `macroTorch.loginContext` is nil first. This is inconsistent with sibling functions in the same file that DO check for `macroTorch.loginContext` before accessing it:

- `computeRake_Erps` at line 628: `if macroTorch.loginContext and macroTorch.loginContext.lastRakeEquippedSavagery then`
- `computeRip_Erps` at line 645: `if macroTorch.loginContext and macroTorch.loginContext.lastRipEquippedSavagery then`
- `tigerSelfGCD` at line 1248: `if not macroTorch or not macroTorch.loginContext or not macroTorch.loginContext.tigerTimer then`

The `not not` pattern on line 1089 only tests whether `tigerTimer` has a truthy value, but does not protect against `loginContext` itself being nil. While `loginContext` is normally initialized in `onPlayerEnteringWorld` (combat_context.lua:39), inconsistent guarding creates a maintenance hazard.

**Fix:**
```lua
function macroTorch.tigerLeft(clickContext)
    if clickContext.tigerLeft == nil then
        local tigerLeft = 0
        if macroTorch.loginContext and macroTorch.loginContext.tigerTimer then
            tigerLeft = clickContext.TIGER_DURATION - (GetTime() - macroTorch.loginContext.tigerTimer)
            if tigerLeft < 0 then
                tigerLeft = 0
            end
        end
        clickContext.tigerLeft = tigerLeft
    end
    return clickContext.tigerLeft
end
```

---

### WR-02: Missing `context` null guard in `ffLeft` (inconsistent with sibling functions)

**File:** `classes/druid/Druid.lua:1177`
**Issue:** `ffLeft` accesses `macroTorch.context.ffTimer` without checking whether `macroTorch.context` is nil. The comparable `isBehindAttackJustFailed` field function in `entity/Player.lua:600-601` does guard against nil:

```lua
['isBehindAttackJustFailed'] = function(self)
    return macroTorch.context and macroTorch.context.behindAttackFailedTime and
            (GetTime() - macroTorch.context.behindAttackFailedTime) <= 0.5
end,
```

While `context` is initialized at combat start and `ffLeft` is only called during combat flow, inconsistent guarding is a maintenance risk.

**Fix:**
```lua
function macroTorch.ffLeft(clickContext)
    if clickContext.ffLeft == nil then
        local ffLeft = 0
        if macroTorch.context and macroTorch.context.ffTimer then
            ffLeft = clickContext.FF_DURATION - (GetTime() - macroTorch.context.ffTimer)
            if ffLeft < 0 then
                ffLeft = 0
            end
        end
        clickContext.ffLeft = ffLeft
    end
    return clickContext.ffLeft
end
```

---

### WR-03: `isTargetDummy` assigned mixed type (inconsistent with codebase `toBoolean` convention)

**File:** `classes/druid/Druid.lua:361-362`
**Issue:** The `isTargetDummy` field is assigned via a raw `string.find` expression without `macroTorch.toBoolean()` wrapping, producing a value that can be `false`, `nil`, or a number:

```lua
clickContext.isTargetDummy = macroTorch.target.isCanAttack and
        string.find(macroTorch.target.name, 'Training Dummy')
```

This results in: `false` when target is not attackable, `nil` when target is attackable but not a training dummy, or a numeric index when it is a training dummy. While `if clickContext.isTargetDummy then` at the call site (`otMod` line 69) works correctly because nil/false/0 are falsy and positive numbers are truthy, this violates the codebase convention of using `macroTorch.toBoolean()` for all boolean-like fields (established throughout the codebase e.g., `isHostile`, `isAttackingMe`, `isFriendly`, and even other `clickContext` fields like `isImmuneRake`).

**Fix:**
```lua
clickContext.isTargetDummy = macroTorch.toBoolean(
    macroTorch.target.isCanAttack and
    string.find(macroTorch.target.name, 'Training Dummy')
)
```

---

### WR-04: Fragile selftest context for `getMinimumAffordableAbilityCost`

**File:** `classes/druid/Druid.lua:1396-1399`
**Issue:** The selftest at line 1392 creates a minimal `ctx` table that omits many fields expected by the functions called within `getMinimumAffordableAbilityCost`:

```lua
local ctx = {
    BITE_E = 35, TIGER_E = 30, RIP_E = 30, RAKE_E = 40, SHRED_E = 60, CLAW_E = 45,
    ooc = false, comboPoints = 3,
}
```

The `shouldUseBite(ctx)` call inside `getMinimumAffordableAbilityCost` invokes `isKillShotOrLastChance(ctx)`, `isTrivialBattleOrPvp(ctx)`, and `isRipPresent(ctx)` -- all of which access fields not present on `ctx` (e.g., `clickContext.isImmuneRip`, `clickContext.rough`, `clickContext.isRipPresent`). While these evaluate as nil in Lua (which is falsy/0 in most contexts), the behavior is fragile and depends on implicit nil coercion. Changes to the called functions could cause this test to produce unexpected results.

**Fix:** Provide a more complete context:
```lua
local ctx = {
    BITE_E = 35, TIGER_E = 30, RIP_E = 30, RAKE_E = 40, SHRED_E = 60, CLAW_E = 45,
    ooc = false, comboPoints = 3, isImmuneRip = false, isImmuneRake = false,
    rough = false,
}
```

Additionally, note that `getMinimumAffordableAbilityCost` at step 2 checks `not macroTorch.isTigerPresent(clickContext)` and returns `"Tiger"` even when Tiger's Fury is not learned. The function has no `isSpellExist` guard for Tiger's Fury, which is a pre-existing design gap (not a phase 13 regression) but should be documented.

---

### WR-05: Global mutation as side effect inside `catAtk`

**File:** `classes/druid/Druid.lua:321-322, 335`
**Issue:** The `catAtk` function mutates module-level globals as side effects during each execution:

```lua
-- Line 321-322:
macroTorch.RIP_BASE_DURATION = 10
macroTorch.RAKE_DURATION = 9

-- Line 335:
macroTorch.COWER_THREAT_THRESHOLD = 75
```

These are shared global values that are also set in `showEnergyUsageSet` (lines 248-255). Mutating them inside the hot path of `catAtk` (which runs on every key press) is redundant -- these values are already set at initialization when `showEnergyUsageSet` is called. The repeated writes also create a race-like behavior if other parts of the code read these values expecting different defaults.

**Fix:** Move these initializations out of `catAtk` to module load time, alongside the other global defaults already set at lines 817-834. If they need to be per-click, store them in `clickContext` instead (similar to how `clickContext.RIP_E = 30` is handled at line 315).

---

## Info

### IN-01: Dead code -- `computeRake_Duration` is defined but never called

**File:** `classes/druid/Druid.lua:596-602`
**Issue:** The function `computeRake_Duration()` is defined but has zero call sites anywhere in the codebase. Rake duration is instead computed inline in `rakeLeft` (line 1152-1154) using `macroTorch.RAKE_DURATION` directly.

**Fix:** Either remove the unused function, or refactor `rakeLeft` to use it (providing a single point of truth for rake duration computation).

---

### IN-02: Dead code -- `raidNum` assigned but only used in commented-out debug block

**File:** `classes/druid/Druid.lua:870`
**Issue:** The `raidNum` variable is fetched from `macroTorch.player.raidMemberCount` but is only referenced in a commented-out debug `macroTorch.show()` call at lines 872-873:

```lua
local raidNum = macroTorch.player.raidMemberCount or 0
-- if nearMateNum < raidNum - 1 then
--     macroTorch.show('raidNum: ' .. tostring(raidNum) .. ', nearMateNum: ' .. tostring(nearMateNum))
-- end
```

**Fix:** Remove the unused variable declaration, or uncomment the debug block if it provides useful runtime diagnostics. If the debug block is preserved, consider gating it behind a debug flag.

---

### IN-03: Commented-out debug code

**File:** `classes/druid/Druid.lua:850-852, 872-874` and `classes/druid/cat.lua:377-379`
**Issue:** Multiple blocks of commented-out `macroTorch.show()` debug code remain in the source. While commented-out debug code can be useful during development, it accumulates and creates noise. Examples:

- Druid.lua:850-852 -- nearMateNum debug in group battle kill shot
- Druid.lua:872-874 -- raidNum debug in raid kill shot
- cat.lua:377-379 -- Tiger fury debug

**Fix:** Remove commented-out debug blocks that are no longer needed, or gate active debug logging behind a configurable debug flag.

---

_Reviewed: 2026-06-20T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_