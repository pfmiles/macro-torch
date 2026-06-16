---
phase: 10-druid-combo-methods
reviewed: 2026-06-17T12:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - classes/druid/combo.lua
  - classes/druid/Druid.lua
  - classes/druid/utility.lua
  - build_order.txt
findings:
  critical: 1
  warning: 5
  info: 1
  total: 7
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-06-17T12:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Phase 10 introduces five Druid combo macro methods in `combo.lua` (`druidAtk`, `druidAoe`, `druidHeal`, `druidDefend`, `druidControl`) that route to form-specific methods via if-elseif chains. It also removes bear form routing from `catAtk()` in `Druid.lua`, deletes three obsolete functions (`druidStun`, old `druidDefend`, old `druidControl`) from `utility.lua`, and adds `combo.lua` to `build_order.txt`.

The review found 1 critical issue (build order dependency on a function that references a removed `clickContext` field), 5 warnings (edge cases and consistency concerns), and 1 informational item. The routing logic itself is structurally sound, with `druidAtk()` correctly dispatching to `catAtk()` or `bearAtk()` based on current form.

## Critical Issues

### CR-01: `burstMod()` in `cat.lua` references `clickContext.isInBearForm` which is no longer set by `catAtk()`

**File:** `classes/druid/Druid.lua:348` (line removed), `classes/druid/cat.lua:26`
**Issue:** The diff removes the assignment `clickContext.isInBearForm = player.isInBearForm` from `catAtk()`, and also removes the bear form routing guard (`if clickContext.isInBearForm then bearAtk(); return end`). However, `burstMod()` in `cat.lua:26` still references `clickContext.isInBearForm`:

```lua
if not player.hasBuff('INV_Misc_MonsterScales_17') and not clickContext.isInBearForm
    and player.hasItem('Juju Flurry') and player.isItemInBagCooledDown('Juju Flurry')
    and not target.isPlayerControlled then
```

With the assignment removed, `clickContext.isInBearForm` is `nil`. In Lua, `not nil` evaluates to `true`, so the guard becomes a no-op -- Juju Flurry usage is no longer suppressed when in bear form. In normal flow through `druidAtk()`, `catAtk()` is only called in cat form (bear form routes to `bearAtk()`), so this is benign. However, if any code path calls `catAtk()` directly while in bear form, the function will now proceed into cat-form-specific logic (opener mod, oocMod, termMod, debuffMod, etc.) without the previous bear form bail-out, leading to incorrect behavior and potential errors from accessing cat-form-only state.

**Fix:** Add a defensive form guard at the top of `catAtk()`:
```lua
function obj.catAtk(rough)
    if not macroTorch.player.isInCatForm then
        return
    end
    local clickContext = {}
    -- ... rest of function
end
```

## Warnings

### WR-01: `druidAoe` uses `macroTorch.player.mana` instead of `humanFormMana` and does not guard against non-caster animal forms

**File:** `classes/druid/combo.lua:14-16`
**Issue:** The condition `not macroTorch.player.isInCatForm and not macroTorch.player.isInBearForm` passes for Travel Form, Aquatic Form, and Moonkin Form -- all of which prevent Hurricane casting. In those forms, `player.mana` returns mana (correct for the gate check), but `hurricane('ready')` silently fails because the spell is not castable. Additionally, the project convention is to use `player.humanFormMana` (defined in `DRUID_FIELD_FUNC_MAP` at `Druid.lua:458`) to always read mana regardless of form shape.

**Fix:**
```lua
function macroTorch.druidAoe()
    if macroTorch.player.isInBearForm then
        macroTorch.bearAoe()
    elseif macroTorch.player.isInCasterForm then
        if macroTorch.player.humanFormMana >= 880 then
            macroTorch.player.hurricane('ready')
        end
    end
end
```
Note: `isInCasterForm` returns a boolean from line 455-457 of `Druid.lua` (currently returns true for Moonkin Form; if no Moonkin, it returns false, meaning caster form druids without Moonkin would not reach this path). Consider adding a dedicated `isInCasterForm` check that also returns `true` when not in any shapeshift form, or use explicit form negations.

### WR-02: `druidDefend` -- `frenzied_regeneration` called with `'ready'` mode does not validate rage resource

**File:** `classes/druid/combo.lua:50-52`
**Issue:** `frenzied_regeneration('ready')` uses `'ready'` mode which only checks `isSpellReady` (cooldown and spell availability), not whether the player has the required 10 rage (cost defined in `Druid.lua:186`). If the player lacks 10 rage, the macro silently consumes a cycle attempting a cast that cannot succeed. The old code in `utility.lua` also used no explicit mode (treated as `'safe'` by default), but the new `'ready'` mode is intentionally more aggressive. Ensure this is the desired behavior; otherwise switch to `'safe'` mode.

**Fix:** Either use `'safe'` mode or explicitly check rage:
```lua
if macroTorch.player.isInBearForm and macroTorch.player.mana >= 10
        and macroTorch.player.isSpellReady('Frenzied Regeneration') then
    macroTorch.player.frenzied_regeneration('ready')
end
```

### WR-03: `druidControl` -- `hibernate` and `entangling_roots` cast without checking if target is already CC'd

**File:** `classes/druid/combo.lua:73-76`
**Issue:** The function casts Hibernate or Entangling Roots on the target without verifying whether the target is already affected by that crowd control. Re-casting CC on an already-CC'd target wastes a global cooldown and, in PvP, may trigger diminishing returns. The old `druidControl` in `utility.lua` had the same pattern, so this is not a regression, but it is a missed optimization.

**Fix:** Add debuff presence checks with the appropriate texture strings:
```lua
if target.type == 'Beast' or target.type == 'Dragonkin' then
    if not target.hasBuff('Spell_Nature_Sleep') then  -- Hibernate debuff texture
        macroTorch.player.hibernate('safe')
    end
else
    if not target.hasBuff('Spell_Nature_StrangleVines') then  -- Entangling Roots texture
        macroTorch.player.entangling_roots('safe')
    end
end
```

### WR-04: `druidControl` -- stale local `target` variable after `targetEnemy()` call

**File:** `classes/druid/combo.lua:57-62`
**Issue:** Line 57 caches `macroTorch.target` in a local variable `target`. After `player.targetEnemy()` on line 60 (which may change the WoW client target), line 61 re-checks `target.isCanAttack`. Currently this works because `macroTorch.target` is a singleton Target object and the local is a reference to the same table. However, if `targetEnemy()` ever reassigns `macroTorch.target` to a new object, the local `target` would be stale and the re-check on line 61 would read from the old Target instance.

**Fix:** Either re-read `macroTorch.target` after `targetEnemy()`, or remove the local and use `macroTorch.target` directly throughout:
```lua
function macroTorch.druidControl()
    local clickContext = {}
    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not macroTorch.target.isCanAttack then
            return
        end
    end
    if macroTorch.player.isInBearForm then
        -- ...
    end
end
```

### WR-05: `druidAoe` has no cat form path -- silently does nothing in cat form

**File:** `classes/druid/combo.lua:11-19`
**Issue:** When in cat form, `isInBearForm` is `false` (bypasses line 12-13) and `not isInCatForm and not isInBearForm` is also `false` (bypasses line 14-17), so the function silently returns `nil` without doing anything. While cat form druids have no AoE abilities in vanilla WoW 1.12, the silent no-op may confuse users who expect the macro to do something useful. The old code had the same limitation in its `druidAoe` equivalent.

**Fix:** Add an explicit guard and return comment for clarity:
```lua
function macroTorch.druidAoe()
    if macroTorch.player.isInCatForm then
        return  -- No cat form AoE in vanilla WoW
    end
    -- ... rest of function
end
```

## Info

### IN-01: `druidControl` -- `clickContext` table created but used only for `isNearBy` cache key

**File:** `classes/druid/combo.lua:56, 67`
**Issue:** `local clickContext = {}` is created on line 56 but only passed to `macroTorch.isNearBy(clickContext)` on line 67, which uses it as a cache container for `clickContext.isNearBy`. This is consistent with the pattern used in `bear.lua`'s `bearAoe()` (line 65), where a minimal `clickContext` is created for the same purpose. No functional issue, but the table allocation on every call is a minor overhead for a single cache field.

**Fix:** No change needed. If this pattern expands, consider using a dedicated lightweight cache pattern.

---

_Reviewed: 2026-06-17T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_