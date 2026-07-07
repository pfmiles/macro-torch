---
phase: barkskin-fix
reviewed: 2026-07-05T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - entity/Player.lua
  - classes/druid/Druid.lua
findings:
  critical: 2
  warning: 2
  info: 1
  total: 5
status: issues_found
---

# Phase barkskin-fix: Code Review Report

**Reviewed:** 2026-07-05
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed two files changed for the barkskin fix: `entity/Player.lua` (unified self-cast path in `_castSpell`) and `classes/druid/Druid.lua` (form-aware barkskin selection, fullwidth-to-halfwidth parentheses fix).

The primary fix (removing `CastSpellByName` from the self-cast path) is well-motivated — `CastSpellByName` parses parentheses as rank specifiers, silently failing for spells like `Barkskin (Feral)`. However, two critical bugs were identified:

1. **`druidDefend()` in `combo.lua` hardcodes `'Barkskin (Feral)'` in its readiness check**, which desynchronizes from the new `barkskin()` that uses `'Barkskin'` (caster version) when not in cat/bear form. This will cause barkskin to never trigger in caster form through `druidDefend()`.

2. **`isInBearForm` catches `Dire Bear Form` but the `barkskin()` form detection does not**, creating inconsistency with the form detection pattern used everywhere else in the codebase. Travel Form and Aquatic Form also raise edge-case concerns.

## Critical Issues

### CR-01: `druidDefend()` readiness check hardcodes 'Barkskin (Feral)' — desynchronizes with form-aware `barkskin()`

**File:** `classes/druid/combo.lua:239`
**Issue:** The `druidDefend()` function checks readiness using `isSpellReady('Barkskin (Feral)')`, but the new `barkskin()` method in `Druid.lua:161-168` dynamically selects between `'Barkskin (Feral)'` (cat/bear form) and `'Barkskin'` (caster form). When the player is in caster form:
- `isInCatForm` is false and `isInBearForm` is false
- `barkskin('ready')` selects `{en = 'Barkskin', zh = '树皮术'}` — the caster version
- But the guard at line 239 checks `isSpellReady('Barkskin (Feral)')` — the feral version
- In caster form, the feral version is likely not usable/ready, so the guard returns false and barkskin never fires via `druidDefend()`

Even in cat/bear form, the string `'Barkskin (Feral)'` is duplicated (hardcoded here AND in the locale table at Druid.lua:164), creating a maintenance risk if the name ever changes (e.g., locale updates).

**Fix:** Replace the hardcoded string with the same form-detection logic used in `barkskin()`:

```lua
function macroTorch.druidDefend()
    local spellName
    if macroTorch.player.isInCatForm or macroTorch.player.isInBearForm then
        spellName = 'Barkskin (Feral)'
    else
        spellName = 'Barkskin'
    end
    if macroTorch.player.isSpellReady(spellName) then
        macroTorch.player.barkskin('ready')
        return
    end
    -- ... rest of druidDefend
end
```

Alternatively, consider extracting the form-detection logic into a shared helper (e.g., `obj._getBarkskinName()`) to avoid duplication between `Druid.lua` and `combo.lua`.

---

### CR-02: `barkskin()` form detection misses `Dire Bear Form`, inconsistent with `isInBearForm` definition

**File:** `classes/druid/Druid.lua:163, 331-332`
**Issue:** The `isInBearForm` field function (line 331-332) is defined as:
```lua
['isInBearForm'] = function(self)
    return self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')
end
```

But the `barkskin()` form detection (line 163) only checks `obj.isInCatForm or obj.isInBearForm`, and `isInBearForm` already covers Dire Bear Form. This is technically correct because `isInBearForm` catches it, BUT:

The real issue is **consistency with all other form states**. The codebase defines `isInTravelForm` (line 334-336) and `isInAquaticForm` (line 337-339) as "reserved for future expansion." When a player is in Travel Form or Aquatic Form:
- `isInCatForm` = false, `isInBearForm` = false
- `barkskin()` selects the caster version `'Barkskin'`
- In Travel/Aquatic Form, you are shapeshifted — the feral version may be the correct one (similar to cat/bear form, you are not in caster form)

**This is a potential edge-case bug.** If Barkskin (Feral) is castable in Travel/Aquatic Form (it is in most WoW versions since it's the shapeshifted variant), the wrong spell would be selected.

Additionally, `isInCasterForm` (line 340-342) is misleadingly named — it only checks for Moonkin Form, not actual caster (humanoid) form. A player in humanoid/caster form would have all `isIn*Form` returning false, which correctly falls through to the `else` branch selecting `'Barkskin'`. This works but relies on implicit behavior.

**Fix:** Consider whether Barkskin (Feral) should be used for ALL shapeshifted forms (cat, bear, dire bear, travel, aquatic, moonkin) or only cat/bear. If the former:

```lua
function obj.barkskin(mode, rank)
    local spellName
    -- Use feral version in any shapeshifted form, caster version in humanoid
    if obj.isInCatForm or obj.isInBearForm or obj.isInTravelForm or obj.isInAquaticForm or obj.isInCasterForm then
        spellName = { en = 'Barkskin (Feral)', zh = '树皮术 (野性)' }
    else
        spellName = { en = 'Barkskin', zh = '树皮术' }
    end
    return obj._castSpell(spellName, mode, nil, 0, true, rank)
end
```

If only cat/bear is correct, add a comment documenting why Travel/Aquatic/Moonkin are excluded.

## Warnings

### WR-01: Stale comment in `obj.cast` documentation (line 27) contradicts the new unified behavior

**File:** `entity/Player.lua:27`
**Issue:** The comment on line 27 states:
```lua
-- for self-cast, use CastSpellByName directly (see _castSpell)
```

This is now **stale/wrong** — the fix intentionally removed `CastSpellByName` from the self-cast path and unified everything through `obj.cast` (which uses `CastSpell(spellId, 'spell')`). The stale comment will confuse future maintainers who wonder why self-cast uses `CastSpellByName` when `_castSpell` no longer does.

**Fix:**
```lua
-- cast spell by name (uses spellbook index via CastSpell, precise spell targeting)
-- self-cast and target-cast share the same path (see _castSpell)
function obj.cast(spellName, rank)
```

---

### WR-02: `isSpellReady` in `_castSpell` uses locale-resolved `spellName` — but `SpellReady()` requires the EXACT spellbook name (including parentheses)

**File:** `entity/Player.lua:44-56, 214-218`
**Issue:** The flow in `_castSpell` is:
1. Line 44-50: Resolve locale name (e.g., `'树皮术 (野性)'` on zhCN)
2. Line 54: `obj.isSpellReady(spellName)` — passes the locale-resolved name
3. `Player.lua:215`: `SpellReady(spellName)` — WoW API call with the locale name

This was already the existing behavior and is not a regression, but it's worth flagging: `SpellReady()` in WoW 1.12.1 accepts spell names and should handle locale names correctly. However, if the spellbook has the Chinese name with a different space/parenthesis character (e.g., the previous fullwidth `（野性）` vs the new halfwidth ` (野性)`), `SpellReady` would fail to match. The fix correctly changed fullwidth to halfwidth parentheses in line 164, which aligns with the actual spellbook display name.

**Fix:** This is informational — the current code appears correct with the halfwidth fix. No action needed, but testing on zhCN client is recommended to verify `SpellReady('树皮术 (野性)')` matches.

## Info

### IN-01: Old `CastSpellByName` self-cast code path left as dead code in utility functions (lines 683-715)

**File:** `entity/Player.lua:683-715`
**Issue:** Several standalone utility functions (`castIfBuffAbsent`, `castBuffOrSelf`, `castIfUnitHealthPercentLessThan`, `castIfUnitHealthPercentMoreThan`) still use `CastSpellByName` directly, including `CastSpellByName(sp, true)` at line 693 for self-targeting. These functions are outside the OOP `_castSpell`/`obj.cast` path and could be affected by the same parenthesis-parsing bug if used with spells like "Faerie Fire (Feral)" or "Barkskin (Feral)".

These are not called through the `_castSpell` path, so they are not regressions from this change — but they represent the same class of bug that may affect other code paths using these utilities with parenthesized spell names.

**Fix:** Add a FIXME comment or refactor these to use `macroTorch.castSpellByName` (the helper in `biz_util.lua:71-77` which uses `CastSpell(spellId, bookType)` via spellbook index, avoiding the parentheses issue):

```lua
function macroTorch.castBuffOrSelf(sp)
    if macroTorch.isTargetValidFriendly('target') then
        macroTorch.castSpellByName(sp, 'spell')
    else
        -- For self-cast, CastSpell auto-targets the caster for self-only spells
        macroTorch.castSpellByName(sp, 'spell')
    end
end
```

---

_Reviewed: 2026-07-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_