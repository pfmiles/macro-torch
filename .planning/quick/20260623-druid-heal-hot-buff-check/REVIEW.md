---
phase: quick-druid-heal-hot-buff-check
reviewed: 2026-06-23T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/combo.lua
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: resolved
---

# Quick Review: druidHeal() Group/Raid HoT Buff Check

**Reviewed:** 2026-06-23
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed the `druidHeal()` function's group/raid healing logic in `classes/druid/combo.lua` (lines 197-215). The change adds HoT buff checks to prevent redundant Rejuvenation/Regrowth casts on group members. While the intent is correct and the texture strings (`Spell_Nature_Rejuvenation`, `Spell_Nature_ResistNature`) are consistent with solo mode, there are correctness gaps in the fallback logic and missing edge-case handling.

## Critical Issues

### CR-01: `lowestHp < 70` branch silently wastes click when both HoTs are already active

**File:** `classes/druid/combo.lua:205-210`
**Issue:** The `elseif lowestHp < 70` branch checks Regrowth then Rejuv, but has no fallback action when both buffs are already present on the target. The click returns silently with no healing cast, wasting a global cooldown opportunity. By contrast, the solo mode at lines 216-225 has a three-tier fallback cascade: Rejuv -> Regrowth -> Healing Touch, each guarded by a buff check with `return` after each successful cast. The group mode's mid-tier branch (`lowestHp < 70`) drops this pattern halfway through.

When a group member has both Rejuvenation and Regrowth active but is between 50-70% HP, a Healing Touch would be a reasonable fallback (topping them off), or at minimum a lower-priority action should be considered. Currently the macro does nothing.

**Fix:**
```lua
elseif lowestHp < 70 then
    if not macroTorch.target.buffed(nil, 'Spell_Nature_ResistNature') then
        macroTorch.player.regrowth(nil, false)
    elseif not macroTorch.target.buffed(nil, 'Spell_Nature_Rejuvenation') then
        macroTorch.player.rejuvenation(nil, false)
    else
        -- Both HoTs are active; fall back to Healing Touch as top-off
        macroTorch.player.healing_touch(nil, false)
    end
```

## Warnings

### WR-01: `lowestHp < 50` branch casts Healing Touch unconditionally without any buff check

**File:** `classes/druid/combo.lua:203-204`
**Issue:** When `lowestHp < 50`, the code casts `healing_touch` on every click with no buff check and no consideration of whether lower-cost HoTs should be reapplied first. This means:
- If the target already has both Rejuvenation and Regrowth active, each click will only cast Healing Touch -- which may be acceptable for emergency healing.
- However, if Healing Touch is on cooldown (e.g., from Nature's Swiftness interaction) or if the player lacks sufficient mana for a max-rank Healing Touch, there is no fallback to a cheaper spell like Regrowth or Rejuvenation.
- The solo mode shows a more robust pattern where all tiers are always accessible.

This is a design concern more than a bug since sub-50% HP is an emergency threshold where direct heals take priority over HoTs. But the lack of any fallback when Healing Touch cannot be cast (cooldown, mana, interrupted) means a click could be completely wasted at a critical moment.

**Fix:** Consider adding a fallback: if `healing_touch` fails to cast (returns false from `_castSpell`), check and cast Regrowth if Regrowth HoT is absent, then Rejuv if Rejuv is absent:
```lua
if lowestHp < 50 then
    if not macroTorch.player.healing_touch(nil, false) then
        if not macroTorch.target.buffed(nil, 'Spell_Nature_ResistNature') then
            macroTorch.player.regrowth(nil, false)
        elseif not macroTorch.target.buffed(nil, 'Spell_Nature_Rejuvenation') then
            macroTorch.player.rejuvenation(nil, false)
        end
    end
```

### WR-02: `TargetUnit(lowestUnit)` return value is not checked

**File:** `classes/druid/combo.lua:202`
**Issue:** The call to `TargetUnit(lowestUnit)` has no error handling. While `findMostDamagedGroupMember` filters for existing, non-dead units within interact distance, edge cases remain:
- If `lowestUnit` is `"player"` (when the player is the most damaged group member), `TargetUnit("player")` will self-target. This is functionally correct, but the subsequent buff checks use `macroTorch.target.buffed(nil, ...)` which reads from `UnitBuff("target", ...)` -- now the player. This works but is an implicit behavior that differs from the explicit `onSelf=true` pattern used in solo mode.
- If a unit dies between the `findMostDamagedGroupMember` call and the `TargetUnit` call (race condition in combat), `TargetUnit` may fail silently, leaving the previous target selected. Subsequent buff checks and spell casts would target the wrong unit.
- The WoW 1.12.1 API `TargetUnit()` does not return a value, but the unit may not exist at call time. No `UnitExists(lowestUnit)` guard is placed before `TargetUnit`.

**Fix:** Add an existence guard before targeting:
```lua
if not UnitExists(lowestUnit) or UnitIsDead(lowestUnit) then
    return
end
TargetUnit(lowestUnit)
```

## Info

### IN-01: `lowestHp < 50` is missing Healing Touch HoT buff check unlike the other healing tiers

**File:** `classes/druid/combo.lua:203-204`
**Issue:** Every other healing tier in this function -- both group mode (`lowestHp < 70` and `lowestHp >= 70`) and solo mode (all three tiers) -- guards its cast with a buff check before casting. The `lowestHp < 50` Healing Touch cast is the only exception, casting unconditionally without verifying whether the HoT from a previous cast is still rolling. While Healing Touch is a direct heal (not a HoT), casting it redundantly on a target that was just healed wastes mana.

**Fix:** None required if this is intentional design (direct heal spam for emergency). Document the rationale if intentional.

---

_Reviewed: 2026-06-23T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---

## Resolution (2026-06-23)

| Finding | Verdict | Action |
|---------|---------|--------|
| CR-01: No fallback when both HoTs active at 50-70% | ✅ Real | Fixed in 7544b41 — added HT fallback |
| WR-01: HT unconditional at <50% | ❌ False positive | HT is direct heal (no HoT), no CD, emergency spam is correct |
| WR-02: TargetUnit unchecked | ⏭️ Pre-existing | Not introduced by this change; out of scope |
| IN-01: HT missing buff check | ❌ False positive | HT has no HoT component — nothing to check |