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
  warning: 3
  info: 5
  total: 9
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed 5 files from the Druid skill method refactoring phase. The new `_castSpell` / `_isInRange` / `_hasResource` infrastructure in `entity/Player.lua` is well-structured, but contains a critical bug where `self:cast()` silently ignores the `onSelf` parameter, breaking all Type C self-targetable skills. Several `safe*` wrapper functions in `cat.lua` have a pre-existing locale mismatch between manual `isSpellReady` calls (hardcoded English names) and the locale-resolved `_castSpell` flow. Two call sites (`ravage()`, `berserk()`) call skill methods without a mode parameter, skipping resource checks. No dangling references to deleted wrapper functions were found — all call sites have been properly migrated.

## Critical Issues

### CR-01: `self:cast()` completely ignores `onSelf` parameter, breaking all Type C (flexible-target) skills

**File:** `entity/Player.lua:29-31`
**Issue:** The `obj.cast(spellName, onSelf)` method accepts `onSelf` but never uses it. It calls `macroTorch.castSpellByName(spellName, 'spell')` which resolves to `CastSpell(spellId, 'spell')`. The WoW 1.12.1 `CastSpell` by ID does NOT support an `onSelf` parameter — only `CastSpellByName` supports `onSelf`.

This means ALL Type C skills (healing_touch, regrowth, rejuvenation, remove_curse, abolish_poison, cure_poison, mark_of_the_wild, gift_of_the_wild, thorns) that pass `onSelf=true` will cast on the current target instead of self. When a hostile target is selected, these friendly-only spells will fail silently.

Affected call sites in the reviewed files:
- `classes/druid/utility.lua:4` — `macroTorch.player.mark_of_the_wild(nil, true)` — buff cast on wrong target
- `classes/druid/utility.lua:7` — `macroTorch.player.thorns(nil, true)` — buff cast on wrong target
- All Type B self-buff skills with `onSelf=true` (like bear_form, cat_form, prowl, etc.) happen to be self-only spells that the client auto-redirects, so they are coincidentally not affected.

**Fix:**
The `cast()` method must actually use `onSelf`. Two approaches:

**Option A: Use `CastSpellByName` when casting on self (preferred — matches WoW 1.12.1 API):**
```lua
function obj.cast(spellName, onSelf)
    if onSelf then
        CastSpellByName(spellName, true)
    else
        macroTorch.castSpellByName(spellName, 'spell')
    end
end
```

**Option B: Always use `CastSpellByName`:**
```lua
function obj.cast(spellName, onSelf)
    CastSpellByName(spellName, onSelf or false)
end
```

Option B simplifies the code but deviates from `CastSpell(id, 'spell')` which is the established pattern for non-self spells. Option A keeps the ID-based path for target spells.

## Warnings

### WR-01: `safe*` wrapper functions use hardcoded English spell names in manual `isSpellReady` checks, which fail on zhCN clients

**Files:** `classes/druid/cat.lua:307,319,337,345,356,364,294` and `classes/druid/utility.lua:22,36,39,44` and `classes/druid/Druid.lua:1192`
**Issue:** The `safeRake`, `safeRip`, `readyBite`, `safeTigerFury`, `readyCower`, `readyReshift`, `safeFF`, and `druidDefend`/`druidStun` functions call `macroTorch.player.isSpellReady('EnglishSpellName')` with hardcoded English names. On zhCN clients, `GetSpellName` returns Chinese names, so `getSpellIdByName('Rake', 'spell')` fails to find a match. This means ALL `safe*` functions that do a manual `isSpellReady` check before calling the skill method will return `false` on zhCN clients, completely disabling these functions.

Note that `_castSpell` correctly resolves locale FIRST (line 42-48 of Player.lua), so the actual cast would work — but the wrapper function short-circuits before reaching `_castSpell`.

**Fix:** The `safe*` and `ready*` wrapper functions should either:
1. Rely entirely on `_castSpell`'s built-in checks by calling the skill method with `'safe'` or `nil` mode, removing the manual `isSpellReady` calls; OR
2. Use locale tables for the manual checks (e.g., `isSpellReady('Rake', '斜掠')` via a locale-aware helper).

Example fix for `safeRake` relying on `_castSpell` (approach 1):
```lua
function macroTorch.safeRake(clickContext)
    if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        if macroTorch.player.rake('safe') then
            macroTorch.show('Rake!!! ...')
            return true
        end
    end
    return false
end
```

This removes the redundant `isSpellReady` and `mana >=` checks since `_castSpell` in `'safe'` mode handles both.

### WR-02: `ravage()` call site in opener mod skips energy resource check

**File:** `classes/druid/Druid.lua:392`
**Issue:** `player.ravage()` is called without a mode parameter (defaults to `nil`/ready mode). The ready mode skips distance and resource checks. If the player has less than 50 energy, the cast attempt will fail silently at the WoW client level. The opener module already checks `isNearBy` before calling `pounce`, but the `ravage` branch has no such proximity or energy guard.

**Fix:** Either pass `'safe'` mode or (if the intent is to be lenient for the opener) add explicit commentary:
```lua
player.ravage('safe')
```

### WR-03: `berserk()` in `burstMod` silently skips resource cost computation

**File:** `classes/druid/cat.lua:18`
**Issue:** `player.berserk()` is called without a mode parameter. While `berserk` has `resourceCost=0` and `onSelf=true`, and Berserk is a self-only spell, the lack of a mode parameter means any future change to `berserk`'s resource cost definition in `Druid.lua` would not trigger a resource check here. The call site should be explicit about intent.

**Fix:**
```lua
player.berserk('ready')
```

## Info

### IN-01: Redundant manual readiness/resource checks in `safe*` wrapper functions duplicate `_castSpell` logic

**Files:** `classes/druid/cat.lua:306-317` (safeRake), `classes/druid/cat.lua:318-332` (safeRip), `classes/druid/cat.lua:344-354` (safeTigerFury), `classes/druid/cat.lua:355-362` (readyCower), `classes/druid/cat.lua:363-368` (safeCower), `classes/druid/cat.lua:293-305` (readyReshift)
**Issue:** These wrapper functions perform manual `isSpellReady`, `mana >= cost`, and `isNearBy` checks BEFORE calling the skill method with `'ready'` mode. The `'ready'` mode in `_castSpell` also checks `isSpellReady`, so the readiness check is done twice. The `_isInRange` and `_hasResource` checks are skipped by ready mode but are re-implemented manually. This duplicates logic and increases maintenance burden.

**Fix:** Consider restructuring these wrapper functions to either:
- Call with `'safe'` mode and remove manual resource/range checks, keeping only the checks that `_castSpell` cannot do (like `isGcdOk`, snapshot side effects); OR
- Call with `'raw'` mode (keeping manual checks as-is) with a comment explaining why certain checks must remain manual.

Example restructuring for `safeRake`:
```lua
function macroTorch.safeRake(clickContext)
    if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        local success = macroTorch.player.rake('safe')
        if success then
            macroTorch.show('Rake!!! ...')
        end
        return success
    end
    return false
end
```

### IN-02: `_castSpell` fallback to English name has no guard against a missing `en` key

**File:** `entity/Player.lua:44-48`
**Issue:** When locale is `zhCN` and `localeNames.zh` exists, the Chinese name is used. Otherwise, the code falls through to `localeNames.en` without checking if the `en` key exists. If a caller accidentally passes a table without an `en` key, `spellName` will be `nil`, propagating into `castSpellByName(nil, 'spell')` which would behave unexpectedly.

**Fix:** Add a defensive guard:
```lua
spellName = localeNames.en
if not spellName then
    macroTorch.show("[macro-torch] WARNING: _castSpell missing locale name for key 'en'")
    return false
end
```

### IN-03: `_castSpell` doc comment says `nil='ready'` but the implementation treats `'ready'` as a string mode

**File:** `entity/Player.lua:35`
**Issue:** The doc comment `@param mode string|nil nil='ready'` is misleading. The code checks `mode ~= 'raw'` and `mode == 'safe'`. Any value that is not `'raw'` (including `nil`, `'ready'`, or any arbitrary string like `'foobar'`) will trigger the readiness check. This means `'ready'` mode and `nil` are indeed equivalent, which is what the comment intends. However, call sites use `'ready'` as a string value (e.g., `player.reshift('ready')`), which makes the `nil='ready'` comment confusing since `'ready'` is an actual string.

**Fix:** Clarify the comment and consider adding explicit handling:
```lua
-- @param mode string|nil nil or 'ready'=readiness check only, 'raw'=no checks, 'safe'=all checks
```
Or better, normalize the mode at the top of the function:
```lua
if mode == nil then
    mode = 'ready'
end
```

### IN-04: Unused local variable `clickContext` in `druidStun` and `druidControl`

**File:** `classes/druid/utility.lua:14` and `classes/druid/utility.lua:51`
**Issue:** `local clickContext = {}` is created in both functions but only used in `isNearBy(clickContext)`. The `isNearBy` function merely reads from and caches to `clickContext`, but the cached value is never read elsewhere. This creates an unnecessary table allocation.

**Fix:** Pass `nil` to functions that have optional `clickContext` parameters if caching is not needed, or restructure `isNearBy` to not require a clickContext for simple distance checks. Alternatively, consider whether the caching behavior in `isNearBy` justifies the allocation — for utility functions called infrequently, it may not matter.

### IN-05: `computeErps` is called twice in `shouldCastFFDuringWaitWindow` — once for energy projection, once for wait calculation

**File:** `classes/druid/Druid.lua:920,931`
**Issue:** `macroTorch.computeErps(clickContext)` is called on line 920 and again on line 931 within the same function, but the result is not cached locally. While `computeErps` caches its result in `clickContext.computeErps`, the second call still incurs a function call overhead for what should be a simple read.

**Fix:** Cache the result locally:
```lua
local erps = macroTorch.computeErps(clickContext)
local energyDuringGcd = erps * 1.5
-- ...
local waitSeconds = energyNeeded / erps
```

---

_Reviewed: 2026-06-13T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_