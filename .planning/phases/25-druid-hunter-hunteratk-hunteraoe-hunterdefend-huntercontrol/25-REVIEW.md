---
phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol
reviewed: 2026-08-19T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - build_order.txt
  - classes/hunter/combo.lua
  - classes/hunter/Hunter.lua
findings:
  critical: 1
  warning: 2
  info: 4
  total: 7
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-08-19T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed 2 Lua source files (`classes/hunter/combo.lua`, `classes/hunter/Hunter.lua`) and 1 build manifest (`build_order.txt`) for the Phase 25 Hunter combo refactor. The build order is correct: `Hunter.lua` (registering the Hunter class and all skill methods) loads at line 37 before `combo.lua` (the combo routing layer relying on those methods) at line 38.

The combo routing follows a well-structured priority-based module pattern (urgent HP restore, target acquisition, auto-attack toggle, burst, opener, stings, core DPS, threat reduction) consistent with the druid combo conventions. The Hunter.lua skill definitions are complete (25 skill methods) with correct locale-aware spell names and appropriate `onSelf`/range parameters.

One blocker-level issue identified: the burst module allows Aimed Shot to fire without the Shift modifier held, violating the D-05 design requirement. Two warnings cover incorrect debuff textures and an unsafe `string.find` call. Four informational items cover code style, duplication, and missing registrations.

---

## Critical Issues

### CR-01: Burst module persists after Shift release — Aimed Shot fires without Shift held

**File:** `classes/hunter/combo.lua:27-54`
**Issue:** The burst module shares state via the module-level `macroTorch.context.burstFlags` table. The initialization gate (lines 27-31) only creates `burstFlags` when Shift is held, but the consumption block (lines 32-53) runs whenever `burstFlags` exists — regardless of current Shift state. If the user releases Shift between keystrokes, `burstFlags` persists globally, allowing remaining burst actions (specifically Aimed Shot, a 3-second hardcast) to fire on the next keystroke without Shift held.

**Reproduction (verified by code trace):**
1. Keystroke 1 (Shift held): `burstFlags = {}`, Rapid Fire casts, `rapidFire = true`, return.
2. Keystroke 2 (Shift released): `IsShiftKeyDown()` is false so lines 27-31 are skipped, but `burstFlags` still exists from keystroke 1. Line 32 enters the execution block. `rapidFire` flag is already consumed — falls through to Aimed Shot check. If Aimed Shot exists, it casts **without Shift held**, violating D-05.

The equivalent issue exists in `hunterAtkMelee` (lines 132-151), though with lower impact since it only has Rapid Fire (no Aimed Shot). However, the `burstFlags` table is shared between both functions, creating cross-mode state leakage: a melee-initiated burst can be "completed" by the ranged function after the player moves out of melee range, and vice versa.

**Fix:** Gate the burst execution block on `IsShiftKeyDown()` and clear state when Shift is released. Both functions require the same fix:

```lua
-- Module 4: burstMod -- Shift-gated burst per D-05
if IsShiftKeyDown() then
    if not macroTorch.context.burstFlags then
        macroTorch.context.burstFlags = {}
    end
    local flags = macroTorch.context.burstFlags
    -- ... existing burst logic (lines 35-53 / 140-152) ...
else
    -- Shift released: clean up any stale burst state
    macroTorch.context.burstFlags = nil
end
```

Move the block that previously started at line 32 (`if macroTorch.context.burstFlags then`) inside the `IsShiftKeyDown()` branch. This ensures burst processing only happens while Shift is actively held and cleans up state immediately on release.

---

## Warnings

### WR-01: Incorrect Serpent Sting debuff texture — `Ability_Hunter_SniperShot` is Hunter's Mark

**File:** `classes/hunter/Hunter.lua:153-154` and `classes/hunter/combo.lua:69`
**Issue:** The Serpent Sting SpellTrace registration uses `debuffTexture = 'Ability_Hunter_SniperShot'`. In WoW Classic 1.12, this icon belongs to **Hunter's Mark**, not Serpent Sting. The `target.buffed()` call at combo.lua line 69 relies primarily on the spell name for detection (`buffed('Serpent Sting')` which checks `UnitDebuff` by name), so the immediate buff-detection behavior works correctly. However, the SpellTrace system uses `debuffTexture` for immune/land tracking — if the trace system scans debuff textures on the target to verify spell application, Serpent Sting land/immune events will not be tracked correctly.

**Impact:**
- SpellTrace immune/land verification for Serpent Sting is non-functional
- Same texture used for two different debuffs (Hunter's Mark at combo.lua:59 also passes `'Ability_Hunter_SniperShot'`) — any texture-only debuff lookup path could produce false matches

**Fix:** Update the SpellTrace registration with the correct Serpent Sting debuff texture (verify in-game via `/fstack` or debuff inspection):

```lua
macroTorch.SpellTrace:register('Serpent Sting', {
    spellName = 'Serpent Sting', land = true,
    immune = true,
    debuffTexture = 'Ability_Hunter_Quickshot'  -- verify in WoW Classic client
})
```

Update combo.lua line 69 to match:
```lua
and not target.buffed('Serpent Sting', 'Ability_Hunter_Quickshot') then
```

### WR-02: Unsafe `string.find` on potentially nil `macrotorch.target.name`

**File:** `classes/hunter/combo.lua:7, 111`
**Issue:** Both `hunterAtkRanged` and `hunterAtkMelee` compute `clickContext.isTargetDummy` via:

```lua
clickContext.isTargetDummy = macroTorch.target.isCanAttack
        and string.find(macroTorch.target.name, 'Training Dummy')
```

The short-circuit `and` protects against nil when `isCanAttack` is false. However, if `isCanAttack` evaluates to true but `target.name` is nil (possible for certain WoW unit types such as game objects or nameplates in edge states), `string.find(nil, ...)` throws a Lua error, crashing the macro execution.

**Fix:** Add an explicit nil guard:

```lua
clickContext.isTargetDummy = macroTorch.toBoolean(
        macroTorch.target.isCanAttack
        and macroTorch.target.name
        and string.find(macroTorch.target.name, 'Training Dummy'))
```

The `macroTorch.toBoolean()` wrapper also normalizes the result to a clean boolean, matching the druid convention (druid/combo.lua:105-107).

---

## Info

### IN-01: Scorpid Sting debuff texture uses placeholder icon `INV_Misc_QuestionMark`

**File:** `classes/hunter/Hunter.lua:158` and `classes/hunter/combo.lua:75`
**Issue:** Both the SpellTrace registration and `buffed()` check for Scorpid Sting use `'INV_Misc_QuestionMark'` as the debuff texture. This is the WoW default "unknown item" placeholder icon — no real debuff uses this texture. The `buffed()` name-based check (`buffed('Scorpid Sting')` at Unit.lua:38) works correctly, so the debuff is detected. However, the SpellTrace system's texture-based verification and the `hasBuff()` fallback path (Unit.lua:43) are non-functional for this spell.

**Note:** This is classified Info rather than Warning because the name-based check provides correct debuff detection. The texture mismatch affects only secondary verification paths.

**Fix:** Replace with the correct Scorpid Sting debuff texture (verify in-game):
```lua
debuffTexture = 'Spell_Nature_CorrosiveBreath'  -- common candidate; verify in WoW Classic
```

### IN-02: No SpellTrace registration for Hunter's Mark

**File:** `classes/hunter/Hunter.lua` (missing entry; Serpent Sting at line 152, Scorpid Sting at line 156)
**Issue:** `hunterAtkRanged` checks for the Hunter's Mark debuff at combo.lua line 59. SpellTrace registrations exist for Serpent Sting and Scorpid Sting, but not for Hunter's Mark. Since Hunter's Mark cannot be resisted or become immune in WoW Classic (it is a non-damaging debuff that always applies), the practical impact is zero. The omission is a consistency concern rather than a functional defect.

**Fix:** Either add a registration for completeness, or document the intentional exclusion:
```lua
macroTorch.SpellTrace:register("Hunter's Mark", {
    spellName = "Hunter's Mark", land = true,
    immune = false,  -- Hunter's Mark cannot be resisted in Classic
    debuffTexture = 'Ability_Hunter_SniperShot'
})
```

### IN-03: Duplicate `clickContext` construction in `hunterAtkRanged` and `hunterAtkMelee`

**File:** `classes/hunter/combo.lua:4-10, 108-114`
**Issue:** Both functions construct identical `clickContext` tables and local variable aliases:

```lua
local clickContext = {}
clickContext.PLAYER_URGENT_HP_THRESHOLD = 15
clickContext.isTargetDummy = macroTorch.target.isCanAttack
        and string.find(macroTorch.target.name, 'Training Dummy')
local player = macroTorch.player
local target = macroTorch.target
```

This duplication creates a maintenance hazard: any change to the context structure must be applied in both locations.

**Fix:** Extract into a shared helper:
```lua
local function _initClickContext()
    local ctx = {}
    ctx.PLAYER_URGENT_HP_THRESHOLD = 15
    ctx.isTargetDummy = macroTorch.toBoolean(
            macroTorch.target.isCanAttack
            and macroTorch.target.name
            and string.find(macroTorch.target.name, 'Training Dummy'))
    return ctx
end
```

Use `local clickContext = _initClickContext()` in both `hunterAtkRanged` and `hunterAtkMelee`.

### IN-04: Magic number `8` for melee/ranged distance threshold repeated 4 times

**File:** `classes/hunter/combo.lua:181, 204, 236, 274`
**Issue:** The melee range threshold of 8 yards appears as a literal `8` in `hunterAtk()` (line 181), `hunterAoe()` (line 204), `hunterControl()` (line 236), and `hunterMobTagging()` (line 274). While 8 is the standard WoW melee range and unlikely to change, defining it once reduces the risk of inconsistent updates and clarifies intent.

**Fix:** Define a module-local constant:
```lua
local MELEE_RANGE = 8  -- yards, standard WoW melee attack range
```

---

## build_order.txt

No issues found. The build manifest is a configuration file listing Lua source files in dependency order. The Hunter entries (lines 37-38) are correctly ordered (`Hunter.lua` before `combo.lua`) and follow the established file format.

---

_Reviewed: 2026-08-19T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_