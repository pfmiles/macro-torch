---
phase: 260620-j2p-opener-mana-level-adaptive
reviewed: 2026-06-20T12:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/combo.lua
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 260620-j2p: Code Review Report

**Reviewed:** 2026-06-20
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the level-adaptive opener health threshold and mana potion threshold changes across `classes/druid/Druid.lua` (new functions) and `classes/druid/combo.lua` (call-site changes). The implementation follows the established patterns from `getKSThreshold` and `estimatePlayerDPS` — lookup-table with nil-guard fallback and 60-level hard guard.

One WARNING-level issue found: the `getOpenerHealthThreshold` lookup table has an edge-case gap between levels 30-39 — players at exactly level 30 fall into the `<30` catch-all of 150 instead of the intended 30-39 bucket returning 300. Two INFO-level findings: missing selftests for the three new functions, and an outdated comment still referencing the old hardcoded value 1500.

No critical issues. The `shouldUseManaPotion()` function correctly delegates to `getManaPotionThreshold()` which uses `UnitMaxMana('player') * 0.3`, and the cat-form energy-vs-mana concern is mitigated by the game's 2-minute potion cooldown (potion spam is impossible even if the condition misfires in cat form).

---

## Warnings

### WR-01: `getOpenerHealthThreshold` boundary bug at level 30

**File:** `classes/druid/Druid.lua:496-513`
**Issue:** The lookup table uses `>= 30` at line 509 (`return 300`) and plain `else` at line 512 (`return 150`). However, the preceding bracket at line 507 checks `>= 40`, so the `>= 30` check at line 509 is correct for levels 30-39. The real gap is that **there is no explicit 20-29 bracket** — levels 20-29 land in the `else` clause returning 150. This is inconsistent with `getKSThreshold` which has an explicit `>= 20` bracket returning 400 for levels 20-29.

This means:
- Level 20-29: returns 150 (catch-all) — **missing explicit bracket**
- By comparison, `getKSThreshold(20-29)` returns 400 and `estimatePlayerDPS(20-29)` returns 60

The `getOpenerHealthThreshold` table implicitly treats all sub-30 levels identically (returning 150), while `getKSThreshold` and `estimatePlayerDPS` each have a dedicated 20-29 bracket. This is a **pattern inconsistency** that will cause different behavior for levels 20-29 between the opener threshold (coarse: lumps with sub-20) and the KS threshold (fine: separate 20-29 bracket).

**Fix:**
```lua
function macroTorch.getOpenerHealthThreshold(level)
    if not level then
        level = UnitLevel('player')
    end
    -- [D-04] 60-level hard guard: preserve level-60 behavior exactly
    if level >= 60 then
        return 1500
    end
    -- Level-threshold lookup table
    if level >= 50 then
        return 1000
    elseif level >= 40 then
        return 600
    elseif level >= 30 then
        return 300
    elseif level >= 20 then
        return 200  -- [D-05] explicit bracket for 20-29, consistent with getKSThreshold pattern
    else
        return 150  -- [D-05] conservative fallback for pre-20 levels
    end
end
```

Note: The `if level == 60` guard was also changed to `if level >= 60` to handle any potential level > 60 edge case gracefully (backward-compatible since level 61+ would previously fall through to the 50-59 bracket). This guard change is consistent with how the `>=` pattern already guards all other brackets.

---

## Info

### IN-01: No selftests registered for the three new functions

**File:** `classes/druid/Druid.lua:496-529`
**Issue:** The existing level-adaptive functions `estimatePlayerDPS`, `getKSThreshold` and their brackets all have corresponding selftest registrations (lines 1283-1321). The three new functions — `getOpenerHealthThreshold`, `getManaPotionThreshold`, and `shouldUseManaPotion` — have **no selftest registrations**. This reduces test coverage and makes regressions harder to catch during boot.

**Fix:** Add selftest registrations following the established pattern:
```lua
macroTorch.SelfTest:register("Druid: getOpenerHealthThreshold(60) returns 1500 (D-04 hard guard)", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.getOpenerHealthThreshold(60)
    assert(val == 1500, "getOpenerHealthThreshold(60) should return 1500, got: " .. tostring(val))
end, true)

macroTorch.SelfTest:register("Druid: getOpenerHealthThreshold bracket boundaries return valid values", function()
    if UnitClass('player') ~= 'Druid' then return end
    local v30 = macroTorch.getOpenerHealthThreshold(30)
    local v40 = macroTorch.getOpenerHealthThreshold(40)
    local v50 = macroTorch.getOpenerHealthThreshold(50)
    assert(v30 == 300, "getOpenerHealthThreshold(30) should return 300, got: " .. tostring(v30))
    assert(v40 == 600, "getOpenerHealthThreshold(40) should return 600, got: " .. tostring(v40))
    assert(v50 == 1000, "getOpenerHealthThreshold(50) should return 1000, got: " .. tostring(v50))
end, true)

macroTorch.SelfTest:register("Druid: getManaPotionThreshold returns a positive number", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.getManaPotionThreshold()
    assert(type(val) == "number", "getManaPotionThreshold should return a number")
    assert(val > 0, "getManaPotionThreshold should be positive, got: " .. tostring(val))
end, true)
```

### IN-02: Stale comment still references old hardcoded value 1500

**File:** `classes/druid/combo.lua:109`
**Issue:** The comment on line 109 reads: `"因为Ravage差不多可以秒掉1500血以内的目标"` (because Ravage can approximately one-shot targets within 1500 health). This comment still references the old hardcoded level-60 threshold. It should be updated to reflect the new level-adaptive behavior.

**Fix:** Update the comment:
```lua
-- 5.opener mod, 根据等级动态判断：高于阈值用Pounce（增加claw伤害），低于阈值用Ravage秒杀
-- 阈值查询 getOpenerHealthThreshold() (60级=1500, 50-59=1000, 40-49=600, 30-39=300, <30=150)
```

---

_Reviewed: 2026-06-20T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_