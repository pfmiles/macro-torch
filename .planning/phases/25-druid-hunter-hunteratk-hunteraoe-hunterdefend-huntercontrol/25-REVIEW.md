---
phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol
reviewed: 2026-08-19T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - classes/hunter/Hunter.lua
  - classes/hunter/combo.lua
  - build_order.txt
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-08-19
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the Hunter class implementation (`Hunter.lua`) and one-button combo macros (`combo.lua`), along with the build order file. The code follows established Druid patterns and is generally well-structured with proper skill definitions, SpellTrace registrations, and SelfTest coverage. However, one critical bug was identified (incorrect debuff texture causing Scorpid Sting to always be recast), along with a shift-gate violation in the burst module and several code quality issues. `build_order.txt` contains no actionable issues (it is a configuration manifest).

---

## Critical Issues

### CR-01: Scorpid Sting debuff texture uses generic placeholder icon — debuff detection always fails

**File:** `classes/hunter/Hunter.lua:158` and `classes/hunter/combo.lua:75`
**Issue:** The Scorpid Sting SpellTrace registration and `buffed()` check both use `'INV_Misc_QuestionMark'` as the debuff texture. This is the default WoW UI "unknown item" placeholder icon — no real debuff in WoW Classic uses this texture. As a result, `target.buffed('Scorpid Sting', 'INV_Misc_QuestionMark')` (combo.lua line 75) always returns false/nil, causing Scorpid Sting to be recast on every keystroke while the sting module is active, even when the debuff is already present on the target.

**Impact:**
- Mana waste from unnecessary recasts
- GCD (global cooldown) wasted on a debuff that is already applied
- Debuff slot contention from premature refresh

**Evidence:** The Druid class (`classes/druid/Druid.lua`) registers debuff textures with specific, real ability icons (e.g., `Spell_Nature_FaerieFire`, `Ability_Druid_Disembowel`, `Ability_GhoulFrenzy`). The generic `INV_Misc_QuestionMark` stands out as an obvious placeholder that was never replaced with the correct texture.

**Fix:** Replace `'INV_Misc_QuestionMark'` with the correct Scorpid Sting debuff texture. In both files:

```lua
-- classes/hunter/Hunter.lua line 158
macroTorch.SpellTrace:register('Scorpid Sting', {
    spellName = 'Scorpid Sting', land = true,
    immune = true, debuffTexture = 'Ability_Hunter_Pet_ScorpidSting'  -- verify in-game
})

-- classes/hunter/combo.lua line 75
and not target.buffed('Scorpid Sting', 'Ability_Hunter_Pet_ScorpidSting') then
```

The correct texture must be verified in-game by inspecting the Scorpid Sting debuff icon. Common candidates in WoW Classic: `Ability_Hunter_Pet_ScorpidSting` or `Ability_Hunter_Quickshot`.

---

## Warnings

### WR-01: Burst module (`burstFlags`) persists after Shift release — Aimed Shot fires without Shift held

**File:** `classes/hunter/combo.lua:27-54`
**Issue:** The burst module (Module 4) in `hunterAtkRanged()` creates `macroTorch.context.burstFlags` when `IsShiftKeyDown()` is true, but only clears it after all flags are consumed (line 53). If the user releases Shift between keystrokes, `burstFlags` persists in `macroTorch.context`, allowing subsequent burst skills to fire without Shift being held.

**Reproduction:**
1. Hold Shift, press key: `burstFlags` created, Rapid Fire cast, `rapidFire = true`, return
2. Release Shift, press key: `burstFlags` still exists, Rapid Fire flag already consumed, **Aimed Shot cast without Shift**
3. Press key again (no Shift): both flags consumed, `burstFlags = nil`

This violates the D-05 "Shift-gated burst" design requirement. Aimed Shot is a 3-second cast-time skill — triggering it without the user holding Shift is a significant control violation.

**Fix:** Gate the entire burst execution block on `IsShiftKeyDown()`, and clear `burstFlags` when Shift is released:

```lua
-- Module 4: burstMod -- Shift-gated burst per D-05
if IsShiftKeyDown() then
    if not macroTorch.context.burstFlags then
        macroTorch.context.burstFlags = {}
    end
    -- ... existing burst logic (lines 33-53) ...
else
    -- Shift released: clean up any stale burst state
    macroTorch.context.burstFlags = nil
end
```

### WR-02: Hunter's Mark and Serpent Sting share the same debuff texture — potential false match in `buffed()`

**File:** `classes/hunter/Hunter.lua:153-154` and `classes/hunter/combo.lua:59, 69`
**Issue:** Both Hunter's Mark check (combo.lua line 59) and Serpent Sting check (combo.lua line 69) use `'Ability_Hunter_SniperShot'` as the debuff texture. If the `buffed()` implementation matches on both name and texture (likely, given how SpellTrace is structured), having two different debuffs share the same texture could cause cross-contamination depending on how `buffed()` resolves texture-only queries.

**Impact:** If `buffed()` internally uses texture as a primary key, the Serpent Sting debuff could cause `buffed("Hunter's Mark", ...)` to return a false positive, preventing Hunter's Mark from being applied. Conversely, Hunter's Mark could mask Serpent Sting detection.

**Mitigation:** This is a warning rather than critical because:
1. The `buffed()` function likely matches by name first (based on the Druid usage pattern where unregistered spells like Moonfire are checked successfully)
2. In WoW Classic, Hunter's Mark and Serpent Sting actually do use different textures (`Ability_Hunter_SniperShot` for Hunter's Mark, a different icon for Serpent Sting)

**Fix:** Verify the correct Serpent Sting debuff texture in-game and update the SpellTrace registration at Hunter.lua line 154. The two debuffs should not share the same texture identifier.

---

## Info

### IN-01: Reserved placeholder map with no entries — dead configuration

**File:** `classes/hunter/Hunter.lua:143-146`
**Issue:** `macroTorch.HUNTER_FIELD_FUNC_MAP` is defined as an empty table with commented-out placeholder descriptions but no actual entries. While this follows the Druid pattern and reserves space for future class-specific lazy-computed fields, the current implementation is dead code that adds no value.

```lua
macroTorch.HUNTER_FIELD_FUNC_MAP = {
    -- basic props (none currently needed)
    -- conditional props (reserved for future class-specific lazy-computed fields)
}
```

**Fix:** Either populate the map with actual reserved key names (even if nil) to document the intended structure, or remove the comments that suggest incomplete implementation. Example:
```lua
macroTorch.HUNTER_FIELD_FUNC_MAP = {
    -- reserved for future class-specific lazy-computed fields
}
```

### IN-02: Magic number `8` for melee/ranged distance threshold repeated 4 times

**File:** `classes/hunter/combo.lua:181, 204, 236, 274`
**Issue:** The melee range threshold of 8 yards appears as a literal `8` in four locations: `hunterAtk()` (line 181), `hunterAoe()` (line 204), `hunterControl()` (line 236), and `hunterMobTagging()` (line 274). While 8 is the standard WoW melee range and unlikely to change, defining it once would improve maintainability.

**Fix:** Define a module-local constant:
```lua
local MELEE_RANGE = 8  -- yards, standard WoW melee attack range
```
Then replace all four occurrences with `MELEE_RANGE`.

### IN-03: Inconsistent `isTargetDummy` computation — missing `toBoolean()` wrapper vs. Druid pattern

**File:** `classes/hunter/combo.lua:6-7, 110-111`
**Issue:** The `isTargetDummy` flag is computed as:
```lua
clickContext.isTargetDummy = macroTorch.target.isCanAttack
        and string.find(macroTorch.target.name, 'Training Dummy')
```

This returns `nil`/`false` when not a dummy, or two numbers (start, end positions) when matched. The Druid pattern (`classes/druid/combo.lua:105`) wraps this with `macroTorch.toBoolean()`. While Lua's truthiness rules make the current code functionally correct (any non-nil/false value is truthy), the type inconsistency could cause issues if downstream code compares with `== true`.

**Fix:** Wrap with `macroTorch.toBoolean()` for consistency with the Druid pattern:
```lua
clickContext.isTargetDummy = macroTorch.toBoolean(
    macroTorch.target.isCanAttack
    and string.find(macroTorch.target.name, 'Training Dummy')
)
```

---

## build_order.txt

No issues found. This is a build manifest listing Lua source files in dependency order for concatenation. The Hunter entries (lines 37-38) are correctly placed and follow the established file format.

---

_Reviewed: 2026-08-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_