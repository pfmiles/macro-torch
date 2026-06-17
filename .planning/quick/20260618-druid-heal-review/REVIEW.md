---
phase: quick-druid-heal-review
reviewed: 2026-06-18T12:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/combo.lua
findings:
  critical: 2
  warning: 5
  info: 6
  total: 13
status: issues_found
---

# Phase Quick: Druid Heal Code Review Report

**Reviewed:** 2026-06-18T12:00:00Z
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed the new `findMostDamagedGroupMember()` function and the rewritten `druidHeal()` function in `classes/druid/combo.lua`. Two critical bugs were found: (1) `druidHeal()` uses `isInGroup` instead of `isInRaid` for the group-healing branch, which means raid members are never healed; (2) the heal spell buff textures are swapped in the solo branch. Five warnings and six informational items were also identified, spanning distance check mismatches, missing buff checks on group members, and code quality concerns.

---

## Critical Issues

### CR-01: Group/Raid Membership Check Uses Wrong Field — Raid Members Never Healed

**File:** `classes/druid/combo.lua:78`
**Issue:** `macroTorch.player.isInGroup` returns `true` only for 5-man parties (via `GetNumPartyMembers() > 0`). In WoW 1.12.1, `GetNumPartyMembers()` returns 0 when the player is in a raid. Therefore, when in a raid, `druidHeal()` falls through to the solo branch and never heals raid members. Despite `findMostDamagedGroupMember()` correctly handling both party and raid (via `macroTorch.player.isInRaid`), the caller never reaches `findMostDamagedGroupMember()` when in a raid.

**Fix:** Replace the guard with a check that covers both parties and raids:
```lua
if macroTorch.player.isInGroup or macroTorch.player.isInRaid then
```
This matches the existing pattern used in `biz_util.lua:filterGroupMates` (line 206-223), which explicitly checks both conditions and uses the appropriate prefix.

### CR-02: Regrowth HoT Buff Texture Is Wrong — Causes False Misses

**File:** `classes/druid/combo.lua:96`
**Issue:** In solo mode, the code checks `macroTorch.player.buffed(nil, 'Spell_Nature_ResistNature')` to determine if Regrowth's HoT is active. `Spell_Nature_ResistNature` is the texture for Mark of the Wild, not Regrowth's HoT. In vanilla WoW 1.12.1, Regrowth's HoT buff uses `Spell_Nature_ResistNature` only in certain game versions — the correct texture is `Spell_Nature_Regenerate` for the HoT portion. If the player has Mark of the Wild (which they almost always will), the check will incorrectly think Regrowth is active, skip re-casting it, and waste the HoT opportunity.

**Fix:**
```lua
if not macroTorch.player.buffed(nil, 'Spell_Nature_Regenerate') then
```

---

## Warnings

### WR-01: No HoT Buff Check on Group Healing Targets — Potential Wasted Casts

**File:** `classes/druid/combo.lua:84-90`
**Issue:** In the group/raid healing branch, after selecting the lowest-HP target, the code casts Rejuvenation (at HP 70-89%), Regrowth (at HP 50-69%), or Healing Touch (below 50%) without checking whether the target already has the relevant HoT active. Repeated calls will re-apply the same HoT on the same target, overwriting the existing one and wasting mana. The solo branch correctly checks for existing buffs before casting.

**Fix:** Add buff checks for the target before casting in the group branch. This requires using `macroTorch.target` after `TargetUnit()` is called:
```lua
TargetUnit(lowestUnit)
local target = macroTorch.target
if lowestHp < 50 then
    macroTorch.player.healing_touch('safe', false)
elseif lowestHp < 70 then
    if not target.buffed(nil, 'Spell_Nature_ResistNature') then
        macroTorch.player.regrowth('safe', false)
    end
else
    if not target.buffed(nil, 'Spell_Nature_Rejuvenation') then
        macroTorch.player.rejuvenation('safe', false)
    end
end
```

### WR-02: findMostDamagedGroupMember Does Not Exclude the Player — Self-Healing via Round-Trip

**File:** `classes/druid/combo.lua:36-63`
**Issue:** When the player is the most damaged group member, `findMostDamagedGroupMember()` returns `"player"`, then `druidHeal()` calls `TargetUnit("player")` and casts with `onSelf=false`. This works (the spell ends up self-cast via the target resolution) but is an unnecessary round-trip: `TargetUnit()` changes the client's target, and then `CastSpell()` casts on "target" (which is now "player"). This is a code smell — self-healing should use `onSelf=true` directly, or the player should be excluded from the candidate pool and handled separately.

**Fix:** Either exclude the player from `findMostDamagedGroupMember()`'s search, or handle the self-target case explicitly after the function returns. The existing `filterGroupMates` in `biz_util.lua:209` correctly uses `not UnitIsUnit(unitId, "player")` to exclude the player from group member searches — this pattern should be replicated here.

### WR-03: findMostDamagedGroupMember Runs 40-Iteration Loop Even When Solo

**File:** `classes/druid/combo.lua:40-60`
**Issue:** When `macroTorch.player.isInRaid` is `false` and `macroTorch.player.isInGroup` is also `false` (solo mode), the function enters the `else` branch with `maxMembers = 4` and `prefix = "party"`. It then loops through `party1` through `party4`, all of which won't exist in solo mode, wasting API calls. The function is only called from `druidHeal()` at line 79, which guards with `macroTorch.player.isInGroup`. However, `findMostDamagedGroupMember()` is a publicly-accessible function that could be called from other contexts, so it should handle the solo case cleanly.

**Fix:** Add an early return for solo mode:
```lua
function macroTorch.findMostDamagedGroupMember()
    if not macroTorch.player.isInGroup and not macroTorch.player.isInRaid then
        return "player", macroTorch.getUnitHealthPercent("player")
    end
    -- rest of function
end
```

### WR-04: CheckInteractDistance Uses Index 4 (Trade Distance ~28yd) — Too Restrictive for 40-Yard Heals

**File:** `classes/druid/combo.lua:52`
**Issue:** `CheckInteractDistance(unitId, 4)` checks trade distance (~28 yards). Healing spells have a 40-yard range, so group members at 29-40 yards — who are perfectly healable — are excluded. This is too conservative and could miss valid healing targets, especially in spread-out raid encounters.

**Fix:** The distance check should match the maximum healing range (40 yards). Since WoW 1.12.1 does not have a direct "is within 40 yards" check, consider using `UnitXP("distanceBetween", "player", unitId) <= 40` or use `CheckInteractDistance(unitId, 1)` (inspect distance, ~28 yards) and accept the limitation, or implement custom range checking via `UnitXP` if available (SuperWoW-dependent). Alternatively, skip the range check in `findMostDamagedGroupMember()` and let the spell's own range check in `_castSpell` handle it — the `mode='safe'` flag in heal spell calls already triggers `_isInRange(40)` which uses the more accurate `macroTorch.target.distance`.

### WR-05: UnitHealth > 1 Check Excludes Nearly-Dead Group Members

**File:** `classes/druid/combo.lua:51`
**Issue:** The condition `UnitHealth(unitId) > 1` means a unit with exactly 1 HP is skipped. A heal at 1 HP is still viable (especially Healing Touch), but this filter prevents it. The intent may be to avoid wasting mana on someone about to die, but this threshold is too aggressive — a unit at 1 HP could still be saved by a fast-cast Regrowth or instant Rejuvenation.

**Fix:** Either remove the `> 1` condition entirely (relying on `not UnitIsDead` alone), or lower it to `>= 1`. If the intent is to skip GHOST units (which some addons report as having 1 HP), use `not UnitIsGhost(unitId)` instead.

---

## Info

### IN-01: Use of `isInGroup` Inconsistent With `findMostDamagedGroupMember`

**File:** `classes/druid/combo.lua:78` vs `combo.lua:41`
**Issue:** `druidHeal()` uses `macroTorch.player.isInGroup` (which is party-only), while `findMostDamagedGroupMember()` uses `macroTorch.player.isInRaid` (which covers raids). The caller and callee use different membership checks, creating an asymmetry. Even after CR-01 is fixed, a third reviewer may be confused by which check does what.

**Fix:** After fixing CR-01, add a comment explaining the two-tier check, or refactor both to use a single helper (e.g., `macroTorch.player.isInGroup or macroTorch.player.isInRaid`).

### IN-02: `findMostDamagedGroupMember` Default Return Value Is Undocumented

**File:** `classes/druid/combo.lua:37-38`
**Issue:** If no group member passes the filter (all dead, all out of range, or all at <=1 HP), the function returns `"player"`. This fallback is undocumented and not immediately obvious from the code. A developer reading the code might assume the function always returns a group member.

**Fix:** Add a comment block explaining the default fallback behavior.

### IN-03: HP Threshold Ordering (50 < 70 < 90) Is Non-Intuitive

**File:** `classes/druid/combo.lua:80-90`
**Issue:** The thresholds are checked as `>=90` (no action) -> `<50` -> `<70` -> else (<90). This works correctly because of the `return` at line 81 and the `elseif` chain, but the mental model is "high-to-low" filtering rather than "low-to-high" which is the conventional way to express triage logic. A reader unfamiliar with Lua's short-circuit evaluation may pause at this.

**Fix:** Reorder for clarity:
```lua
if lowestHp >= 90 then return end
if lowestHp < 50 then
    -- ...
elseif lowestHp < 70 then
    -- ...
else
    -- lowestHp >= 70 and < 90
end
```
This is functionally identical but avoids the "wait, why is 50 before 70?" question.

### IN-04: Magic Number Thresholds Should Be Named Constants

**File:** `classes/druid/combo.lua:80,84,86`
**Issue:** The HP percentage thresholds (90, 70, 50) are hardcoded. If tuning is needed later, a developer must find and replace scattered magic numbers. The codebase's existing pattern uses descriptive function names but not constants, so this is a minor style note.

**Fix:** Consider defining local constants at the top of the function:
```lua
local HP_NO_ACTION = 90
local HP_REJUV = 70
local HP_HEAVY = 50
```

### IN-05: No `TableLen` Usage Issue In Loop — Correctly Uses Numeric For

**File:** `classes/druid/combo.lua:49`
**Issue:** The `for i = 1, maxMembers` loop is correct. However, WoW 1.12.1 Lua does not support the `#` length operator, and this code correctly avoids it. This is a positive finding — the code follows project conventions. Noted here for completeness since the CLAUDE.md explicitly warns about this.

### IN-06: Missing Guard for `GetNumPartyMembers() == 0 and not isInRaid` — Solo Is Handled but Could Be Cleaner

**File:** `classes/druid/combo.lua:40-47`
**Issue:** When not in a group or raid, `findMostDamagedGroupMember()` enters the `else` branch with `prefix="party"` and loops 4 times. This is handled at the caller site (`druidHeal` line 78) but the function itself does not guard against this. While not a correctness issue (all UnitExists checks fail, returning the player default), it's wasted work. Suggested fix is in WR-03.

---

_Reviewed: 2026-06-18T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_