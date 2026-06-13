---
phase: 05-druid-player-cast-druid
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - entity/Player.lua
  - classes/druid/Druid.lua
  - classes/druid/cat.lua
  - classes/druid/bear.lua
  - classes/druid/utility.lua
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-06-13T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 05 refactored Druid spell casting by introducing `_castSpell` / `_isInRange` / `_hasResource` helpers in `Player.lua`, adding 53 skill methods to `Druid:new()` with inline locale tables, replacing all `player.cast()` calls across cat, bear, and utility modules, and deleting ~20 safe/ready wrapper functions.

The mode system (nil=ready, safe, raw) is applied consistently. No dangling references to deleted functions remain — all call sites have been properly migrated. The combat rotation logic is functionally preserved. However, one critical spell name mismatch will cause `druidDefend` to silently fail casting Barkskin, and several call sites have latent issues with redundant or inconsistent guard patterns.

## Critical Issues

### CR-01: Barkskin spell name mismatch in `druidDefend` -- spell will silently fail to cast

**File:** `classes/druid/utility.lua:36-37`
**Issue:** `druidDefend` guards with `isSpellReady('Barkskin (Feral)')` (including the "(Feral)" suffix), but the `barkskin` skill method at `classes/druid/Druid.lua:157-158` uses the locale entry `{ en = 'Barkskin', zh = '树皮术' }` -- WITHOUT the "(Feral)" suffix. The mode is `'raw'`, which skips readiness checks inside `_castSpell`, so the internal `isSpellReady` check is not triggered. The actual spell cast goes through `macroTorch.castSpellByName('Barkskin', 'spell')` which calls `macroTorch.getSpellIdByName('Barkskin', 'spell')` -- a case-insensitive exact-match scan of the spell book. If the spell is registered as `'Barkskin (Feral)'` in the player's spell book (because it is a talent ability for feral druids), the lookup returns `nil` and `CastSpell(nil, 'spell')` silently does nothing.

The old code at this call site used `macroTorch.player.cast('Barkskin (Feral)')` which consistently used the "(Feral)" suffix for both the readiness check and the cast. The refactoring preserved the readiness check string but changed the cast name via the skill method's locale entry, breaking the alignment.

**Fix:** Verify the in-game spell name via `GetSpellName(i, 'spell')` and align both. If the spell is indeed `'Barkskin (Feral)'`:

```lua
-- classes/druid/Druid.lua:157-158
function obj.barkskin(mode)
    return self:_castSpell({ en = 'Barkskin (Feral)', zh = '树皮术' }, mode, nil, 0, true)
end
```

If the spell is simply `'Barkskin'` (without the suffix), update the guard in `druidDefend`:

```lua
-- classes/druid/utility.lua:36
if macroTorch.player.isSpellReady('Barkskin') then
    macroTorch.player.barkskin('raw')
end
```

## Warnings

### WR-01: Unused `local clickContext = {}` in `druidDefend`

**File:** `classes/druid/utility.lua:34`
**Issue:** `druidDefend` declares `local clickContext = {}` which is never referenced anywhere in the function body. This is a dead variable allocation. It was present in the pre-refactor code and was not cleaned up during this phase.

**Fix:** Remove the unused line:

```lua
function macroTorch.druidDefend()
    -- [Barkskin (Feral)][Frenzied Regeneration]
```

### WR-02: `safeFF` uses hardcoded English name in `isSpellReady` check bypassing locale resolution

**File:** `classes/druid/Druid.lua:1192`
**Issue:** `safeFF` calls `macroTorch.player.isSpellReady('Faerie Fire (Feral)')` with a hardcoded English spell name. This is consistent with the old code, but it diverges from the `_castSpell` locale resolution pattern. On a zhCN client, `isSpellReady` will resolve the name through `SpellReady('Faerie Fire (Feral)')` which uses the client's internal name mapping, so this likely works. However, the spell name used for `isSpellReady` ('Faerie Fire (Feral)') and the spell name used in `_castSpell` (locale-resolved to `'精灵之火（野性）'` on zhCN) are different strings. There's a latent risk that these diverge if one is translated differently from the other.

Since `safeFF` calls `faerie_fire_feral('raw')` which bypasses readiness checks, the actual readiness gate is entirely in this hardcoded English check. If this check passes but `getSpellIdByName` on the locale-resolved name fails, the spell silently does nothing (same pattern as CR-01).

**Fix:** Let `_castSpell` handle readiness internally by using ready mode (nil), and only keep the GCD check externally:

```lua
function macroTorch.safeFF(clickContext)
    if macroTorch.isGcdOk(clickContext) then
        if macroTorch.player.faerie_fire_feral() then  -- nil=ready mode
            macroTorch.show('FF!!! FF present: ' ..
                    tostring(macroTorch.isFFPresent(clickContext)) ..
                    ', FF left: ' ..
                    tostring(macroTorch.ffLeft(clickContext)) ..
                    ', at energy: ' .. macroTorch.player.mana .. ', cp: ' .. tostring(clickContext.comboPoints))
            macroTorch.context.ffTimer = GetTime()
            return true
        end
    end
    return false
end
```

### WR-03: Duplicate `isSpellReady` checks in `safe*`/`ready*` wrapper functions

**Files:** `classes/druid/cat.lua:307,319,337,345,356,364,294`
**Issue:** Several remaining wrapper functions (`safeRake`, `safeRip`, `readyBite`, `safeTigerFury`, `readyCower`, `readyReshift`) call `isSpellReady` with hardcoded English names BEFORE calling the skill method (e.g., `player.rake('ready')`). The skill method in 'ready' mode ALSO calls `isSpellReady` internally via `_castSpell` (using the locale-resolved name). This means:

1. Readiness is checked twice (once manually with English name, once inside `_castSpell` with locale-resolved name)
2. The manual check short-circuits BEFORE `_castSpell` can log/show any debug info
3. The two checks use different spell name strings (English vs locale-resolved)

This is not a functional bug (both checks should agree on zhCN clients since the server provides the spell name mapping), but it violates the single-point-of-truth principle and adds unnecessary code.

**Fix:** Remove the manual `isSpellReady` checks from all wrapper functions, relying on `_castSpell` to handle readiness. Keep only the checks that `_castSpell` cannot perform (`isGcdOk`):

Example for `safeRake`:
```lua
function macroTorch.safeRake(clickContext)
    if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        return macroTorch.player.rake('safe')  -- safe mode handles isSpellReady + mana
    end
    return false
end
```

Note: This change would remove the `macroTorch.show('Rake!!! ...')` debug output on failures that are caught before `_castSpell` (GCD/range), but this is acceptable since those failures are not actionable debug information.

### WR-04: `druidControl` calls ranged spells without range guard

**File:** `classes/druid/utility.lua:50-57`
**Issue:** `druidControl` calls `player.hibernate()` and `player.entangling_roots()` with nil mode (ready mode only). Both skills have `range=30` in their `Druid.lua` definitions, but ready mode does NOT perform range checks -- only 'safe' mode does. If the target is beyond 30 yards, the spells will attempt to cast and fail silently at the WoW client level. This is a pre-existing issue from the old `player.cast('Hibernate')` calls, but the new infrastructure provides the tooling to fix it.

**Fix:** Use 'safe' mode to get the built-in range check:
```lua
function macroTorch.druidControl()
    if macroTorch.target.type == 'Beast' or macroTorch.target.type == 'Dragonkin' then
        macroTorch.player.hibernate('safe')
    else
        macroTorch.player.entangling_roots('safe')
    end
end
```

Note: Both skills have `resourceCost=nil` so 'safe' mode would only add a range check, no resource check. This is appropriate since these are mana-cost spells that use the caster's mana pool (coverage outside this review's scope).

## Info

### IN-01: `regularAttack` has repeated if-else pattern that could be consolidated

**File:** `classes/druid/cat.lua:46-61`
**Issue:** The function duplicates the `if clickContext.ooc then ... else ... 'safe' ... end` pattern for both Shred and Claw branches. The logic is correct and clear, but a mode variable would reduce lines and eliminate the duplication:

```lua
function macroTorch.regularAttack(clickContext)
    local mode = clickContext.ooc and nil or 'safe'
    if macroTorch.shouldUseShred(clickContext) then
        macroTorch.player.shred(mode)
    else
        macroTorch.player.claw(mode)
    end
end
```

### IN-02: `_isInRange` returns `true` for nil/zero range even when target doesn't exist

**File:** `entity/Player.lua:83-91`
**Issue:** The method first checks `if not macroTorch.target or not macroTorch.target.isExist then return false end`, correctly rejecting the case where no target exists. Then it checks `if type(range) ~= 'number' or range <= 0 then return true`. The ordering is correct: target existence is checked first, then the nil/melee shortcut. However, the comment `nil/0 range = melee, always considered in range if target exists` is misleading -- the method does NOT verify melee range (<= 3 yards), it simply assumes proximity if the target exists. This silently assumes the target is in melee range, which may not be true. For the current set of callers, this is fine because external `isNearBy` checks or the `if range and ...` guard in `_castSpell` prevent the method from being called for melee-range spells. But the method's documented contract and actual behavior differ for nil-range checks.

**Fix:** Either update the comment or add an actual melee distance check:
```lua
-- nil/0 range = melee, consider in range if target exists and within 3 yards
if type(range) ~= 'number' or range <= 0 then
    return macroTorch.target.distance <= 3  -- explicit melee range check
end
```

Note: Adding this check changes behavior for callers that rely on `_isInRange(nil)` returning `true` when the target is just barely in range. Since `_castSpell` only calls `_isInRange` when `range` is a number > 0 (due to the `if range and not self:_isInRange(range)` guard), this change would NOT affect `_castSpell` behavior. It would only affect external callers of `_isInRange` directly (none found in this review scope).

---

_Reviewed: 2026-06-13T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_