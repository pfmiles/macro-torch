---
phase: 260619-qbj-add-faerie-fire-insect-swarm-debuff-and-
reviewed: 2026-06-19T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/combo.lua
  - texture_map.lua
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 260619-qbj: Code Review Report

**Reviewed:** 2026-06-19
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed two files comprising the Faerie Fire / Insect Swarm debuff priority chain in `casterAtk()` and the corresponding texture map entries. The core logic is sound: a 3-debuff priority chain (Moonfire -> Faerie Fire -> Insect Swarm) followed by Wrath/Starfire alternation via a context toggle. No critical bugs were found. Two warnings cover naming convention drift and a missing nil-safety guard; two informational items cover texture map ordering and potential debuff detection inconsistency across the codebase.

## Warnings

### WR-01: `_starfireNext` naming convention violates existing context field convention

**File:** `classes/druid/combo.lua:15,17,20`
**Issue:** All existing fields on `macroTorch.context` use camelCase naming: `ffTimer`, `lastProcessedBiteEvent`, `attackSlot`, `burstFlags`, `lastRipEquippedSavagery`, `lastRakeEquippedSavagery`, `lastRipAtCp`. The new `_starfireNext` field uses snake_case with a leading underscore prefix, which is inconsistent with the established convention. The leading underscore conventionally signals "private" but no other context field uses this convention despite many being equally "internal." This makes the codebase harder to scan and maintain, as developers must remember two different naming schemes for the same data structure.

**Fix:** Rename to `starfireNext` to match the existing camelCase convention:

```lua
elseif macroTorch.context.starfireNext then
    macroTorch.player.starfire()
    macroTorch.context.starfireNext = false
else
    macroTorch.player.wrath()
    macroTorch.context.starfireNext = true
end
```

### WR-02: No defensive nil-check on `macroTorch.context` before accessing `_starfireNext`

**File:** `classes/druid/combo.lua:15`
**Issue:** `casterAtk()` accesses `macroTorch.context._starfireNext` without first verifying that `macroTorch.context` is non-nil. While in practice this is low-risk (the function is only reached via `druidAtk()` -> `casterAtk()` during combat, and `onCombatEnter()` initializes context), there is a theoretical race if the macro fires between combat entry detection and the `PLAYER_REGEN_DISABLED` event handler. Other code paths in the codebase get this right — `biz_util.lua:106-107` does a nil-check before accessing `macroTorch.context.attackSlot`, and `core/spell_trace_immune.lua:70` returns early if context is nil.

**Fix:** Add a defensive nil-check or lazy-initialize context, matching the pattern used in `biz_util.lua`:

```lua
function macroTorch.casterAtk()
    if not macroTorch.context then
        macroTorch.context = {}
    end
    if not macroTorch.target.isCanAttack then
        return
    end
    -- ... rest of function
end
```

## Info

### IN-01: Faerie Fire debuff detection uses `buffed()` in `casterAtk()` but `hasBuff()` in `isFFPresent()` — inconsistent detection methods

**File:** `classes/druid/combo.lua:11` vs `classes/druid/Druid.lua:1140`
**Issue:** `casterAtk()` detects Faerie Fire with `macroTorch.target.buffed('Faerie Fire', 'Spell_Nature_FaerieFire')` (dual name+texture check), while `isFFPresent()` in the cat/bear rotation detects the same debuff with `macroTorch.target.hasBuff('Spell_Nature_FaerieFire')` (texture-only direct check). These two detection methods could theoretically disagree — the `buffed()` name-check path could return true via the global API while `hasBuff()` misses the texture, or vice versa. In practice they should agree since both ultimately compare against the same texture string, but the inconsistency between how the caster and feral rotations check for the same debuff is worth noting for future maintainability.

**Fix:** Consider standardizing on one detection method. Since `hasBuff()` is simpler and already verified in the feral rotation's `isFFPresent()`, using it in `casterAtk()` would simplify:

```lua
elseif not macroTorch.target.hasBuff('Spell_Nature_FaerieFire') then
    macroTorch.player.faerie_fire()
```

### IN-02: New texture entries inserted between existing druid and warrior sections

**File:** `texture_map.lua:20-21`
**Issue:** The new entries `['Faerie Fire']` and `['Insect Swarm']` were added at lines 20-21, between the existing Moonfire entry (line 19) and the `--- druid end` comment (line 22). The `--- warrior start` / `--- warrior end` section begins at line 23. While technically in the correct section, the `druid start/end` boundary comment now sits directly adjacent to `--- warrior start` with no visual separation. This is purely cosmetic and does not affect functionality.

**Fix:** No code change needed. The entries are in the correct section.

---

_Reviewed: 2026-06-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_