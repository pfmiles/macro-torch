---
phase: 19-druidControl-bash-druidcharge
reviewed: 2026-07-08T14:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/combo.lua
  - core/selftest.lua
findings:
  critical: 3
  warning: 2
  info: 4
  total: 9
status: issues_found
---

# Phase 19: Code Review Report (druidControl Bash 拆分为 druidCharge)

**Reviewed:** 2026-07-08T14:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed 2 files: `classes/druid/combo.lua` (the Druid combo macro routing layer containing `druidControl`, `druidCharge`, and related functions) and `core/selftest.lua` (the self-test framework with new Category M tests for the druidControl/druidCharge split).

Found 3 critical issues (2 in combo.lua, 1 in selftest.lua), 2 warnings (both in combo.lua), and 4 info items (3 in combo.lua, 1 in selftest.lua). The critical issues involve: (1) a nil reference risk in `druidControl` when `hibernate` or `entangling_roots` methods are called on a target that may not exist after `targetEnemy()`, (2) incomplete `target.isCanAttack` re-validation in `druidControl` after `targetEnemy()` compared to the pattern in `druidCharge`, and (3) a Category M selftest that invokes `druidControl` via pcall without guarding against non-Druid classes accessing `isBeastOrDragonkin` (which depends on `UnitCreatureType`).

## Critical Issues

### CR-01: `druidControl` calls `target.isBeastOrDragonkin()` without re-validating `target.isCanAttack` after `targetEnemy()`

**File:** `classes/druid/combo.lua:257-268`
**Issue:** The `druidControl` function re-checks `target.isCanAttack` and returns early if the target is still invalid after `targetEnemy()`, but if `targetEnemy()` successfully acquires a new target, the code falls through to line 264 without re-checking that the new target is attackable. This means `isBeastOrDragonkin()` will be called on the refreshed target unconditionally, but if the new target happens to be non-attackable (a rare but possible edge case given how `targetEnemy` is typically implemented), the subsequent `hibernate()` or `entangling_roots()` calls would execute against an invalid target.

Contrast this with `druidCharge` (lines 274-279) which has an identical pattern but follows it with an `isInBearForm` guard before proceeding — which is defensively acceptable. The issue is more pronounced in `druidControl` because there is no further guard after the `if not target.isCanAttack` block and the `isBeastOrDragonkin` branch.

**Fix:** Add a defensive re-check after the `targetEnemy()` block:
```lua
function macroTorch.druidControl()
    local target = macroTorch.target

    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end

    -- Defensive: if somehow target became invalid between the check above and now
    if not target.isCanAttack then
        return
    end

    if target.isBeastOrDragonkin() then
        macroTorch.player.hibernate()
    else
        macroTorch.player.entangling_roots()
    end
end
```

### CR-02: Category M selftest `druidControl` pcall test may crash on non-Druid classes due to `isBeastOrDragonkin` calling `UnitCreatureType`

**File:** `core/selftest.lua:767-771`
**Issue:** The test "M: druidControl invocable via pcall" calls `pcall(macroTorch.druidControl)` which internally calls `macroTorch.target.isBeastOrDragonkin()`. This method invokes `UnitCreatureType(obj.ref)` on line 78 of `entity/Target.lua`. While `pcall` captures Lua-level errors (nil arithmetic, type mismatches), it does NOT protect against C-level API errors from `UnitCreatureType` or the `macroTorch.player.hibernate()` / `macroTorch.player.entangling_roots()` calls which may trigger WoW client API calls. In environments where these WoW API functions can error at the C level (e.g., when called with an invalid unit reference), the pcall may not capture the error, resulting in a client crash.

Worse, while the test has `if UnitClass('player') ~= 'Druid' then return end`, the `druidControl` function still executes actual WoW API calls (`targetEnemy`, `isBeastOrDragonkin` -> `UnitCreatureType`, then `hibernate` or `entangling_roots`). Running this test on a Druid with no valid target or a protected frame could trigger unexpected behavior.

**Fix:** Either limit the test scope to only verify the function is callable without side effects, or add additional guards:
```lua
macroTorch.SelfTest:register("M: druidControl invocable via pcall (elseif->if promotion valid per D-07)", function()
    if UnitClass('player') ~= 'Druid' then return end
    -- Verify type only; full invocation via pcall has side effects (targetEnemy, spell casts)
    assert(type(macroTorch.druidControl) == "function",
        "druidControl is not a function after refactor")
end, true)
```

### CR-03: `druidControl` has no fallback when both `isBeastOrDragonkin()` branches cannot execute

**File:** `classes/druid/combo.lua:264-268`
**Issue:** The `druidControl` function always calls either `hibernate()` or `entangling_roots()` after confirming the target is attackable. However, there is no check for whether the player is actually in a state where they can cast these spells (e.g., silenced, in cat/bear form, out of mana). While the individual spell-cast methods likely have internal readiness checks, the function lacks the defensive pattern used elsewhere in the codebase (e.g., `druidHeal` at line 192-202 checks form state before proceeding). If `druidControl` is invoked while the Druid is shapeshifted, the spell casts will silently fail without feedback.

**Fix:** Add a form check at the top, similar to `druidAtk`:
```lua
function macroTorch.druidControl()
    -- Cannot cast control spells while shapeshifted
    if macroTorch.player.isInCatForm or macroTorch.player.isInBearForm then
        return
    end

    local target = macroTorch.target
    -- ... rest of function ...
end
```

## Warnings

### WR-01: `druidControl` redundant `targetEnemy` call pattern inconsistent with `casterAtk`

**File:** `classes/druid/combo.lua:257-262`
**Issue:** `druidControl` calls `macroTorch.player.targetEnemy()` when `target.isCanAttack` is falsy, then re-checks and returns. However, `casterAtk` (line 4-5) simply returns immediately without attempting `targetEnemy()`. This inconsistency means `casterAtk` can silently do nothing when there is no valid target, while `druidControl`/`druidCharge` will attempt to auto-acquire one. If this inconsistency is intentional (control/charge should be more aggressive about target acquisition), it should be documented. If it is unintentional, it represents a behavioral regression risk.

**Fix:** If the auto-target behavior is intentional for `druidControl`/`druidCharge`, add a comment explaining the design decision:
```lua
-- Auto-acquire a target for control abilities (unlike casterAtk which requires pre-selection)
if not target.isCanAttack then
    macroTorch.player.targetEnemy()
    if not target.isCanAttack then
        return
    end
end
```

### WR-02: `druidHeal` calls `TargetUnit(lowestUnit)` but does not validate `lowestUnit` is non-nil

**File:** `classes/druid/combo.lua:205-209`
**Issue:** `findMostDamagedGroupMember()` returns `lowestUnit, lowestHp`. The code checks `lowestHp >= 90` and returns early in that case, but does not explicitly handle `lowestUnit` being nil (e.g., if `findMostDamagedGroupMember` returns nil for both values when no group member is found). Calling `TargetUnit(nil)` could result in unexpected behavior or errors in the WoW client.

**Fix:** Add a nil check for `lowestUnit`:
```lua
if macroTorch.player.isInGroup or macroTorch.player.isInRaid then
    local lowestUnit, lowestHp = macroTorch.findMostDamagedGroupMember()
    if not lowestUnit or lowestHp >= 90 then
        return
    end
    TargetUnit(lowestUnit)
    -- ... rest of healing logic ...
end
```

## Info

### IN-01: Duplicate `targetEnemy` + revalidation block between `druidControl` and `druidCharge`

**File:** `classes/druid/combo.lua:257-262` and `classes/druid/combo.lua:274-279`
**Issue:** Both `druidControl` (lines 257-262) and `druidCharge` (lines 274-279) contain an identical 6-line pattern for auto-targeting:
```lua
if not target.isCanAttack then
    macroTorch.player.targetEnemy()
    if not target.isCanAttack then
        return
    end
end
```
This is a textbook example of duplication that violates the Single Point of Truth principle documented in CLAUDE.md. If the `targetEnemy` logic or the revalidation guard needs to change, both functions must be updated independently, creating a maintenance risk.

**Fix:** Extract into a shared helper function:
```lua
-- Returns true if we have a valid attackable target (possibly after auto-acquisition)
function macroTorch.ensureTargetAttackable()
    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        return macroTorch.toBoolean(macroTorch.target.isCanAttack)
    end
    return true
end
```

### IN-02: `druidCharge` hardcoded distance threshold (8) should be a named constant

**File:** `classes/druid/combo.lua:290`
**Issue:** The value `8` (yards, the typical melee charge range for Feral Charge) is hardcoded in `if target.distance >= 8 then`. This magic number appears without explanation. Per CLAUDE.md's code conventions, magic numbers like this should be extracted into named constants or at minimum documented with an explanatory comment. Other modules in the codebase (e.g., `catAtk` in the same file) use named fields on `clickContext` for similar thresholds.

**Fix:** Either use a named constant at the top of the function or add an explanatory comment:
```lua
-- Feral Charge minimum range: 8 yards (standard for Bear charge in WoW 1.12.1)
local CHARGE_MIN_RANGE = 8
if target.distance >= CHARGE_MIN_RANGE then
```

### IN-03: `casterAtk` function lacks a `targetEnemy` auto-acquisition path like other combo functions

**File:** `classes/druid/combo.lua:3-5`
**Issue:** `casterAtk` immediately returns when `target.isCanAttack` is falsy, without attempting `targetEnemy()`. This differs from `druidControl`, `druidCharge`, and the `catAtk` pipeline (which calls `player.targetEnemy()` at line 109). For a macro that is meant to be bound as a one-button rotation, this means the caster form rotation will silently do nothing unless the player pre-selects a target. This appears to be a design choice but is inconsistent with the rest of the combo methods.

**Fix:** Consider adding `targetEnemy()` call for consistency, or document the intentional difference:
```lua
function macroTorch.casterAtk()
    -- Caster form intentionally requires pre-targeting (spells have cast times, no auto-attack)
    if not macroTorch.target.isCanAttack then
        return
    end
    -- ... rest of function ...
end
```

### IN-04: Category M selftest "druidControl does not call bash" has no meaningful runtime assertion

**File:** `core/selftest.lua:759-765`
**Issue:** The test named "M: druidControl does not call bash (code-review verified per D-06)" only checks `type(macroTorch.druidControl) == "function"` and includes a comment saying "No runtime assertion possible without filesystem access in WoW Lua." While the test name accurately describes what was verified by code review, the actual runtime assertion is a no-op — it only confirms the function exists (which is already covered by test on lines 333-336). This means the test will always pass regardless of whether `bash` is actually removed from `druidControl`, making it a "green check" that provides a false sense of security.

**Fix:** Either remove this test (it duplicates the test on lines 333-336 and adds no value) or rename it to reflect what it actually tests:
```lua
macroTorch.SelfTest:register("M: druidControl function shape verified post-Bash-split", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidControl) == "function",
        "druidControl is not a function after Bash branch removal")
end, true)
```

---

_Reviewed: 2026-07-08T14:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_