---
phase: 17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr
reviewed: 2026-06-29T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/leveling.lua
  - core/combat_context.lua
  - core/events.lua
  - core/selftest.lua
  - core/spell_id_map.lua
  - core/spell_trace_core.lua
  - core/spell_trace_immune.lua
  - entity/Player.lua
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-06-29
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 17 delivers FF prowling guard in `catLeveling`, spellId resolution infrastructure (`spell_id_map.lua` + `resolveSpellId`), `current_casting_spell` lifecycle bridge in `_castSpell`, and runtime spellId correction via `UNIT_CASTEVENT`. The overall architecture is sound — the spellId map pattern follows the existing `loadImmuneTable` persistence model, and the prowling guard correctly prevents FF casting while stealthed.

One critical issue was found: the `getKSThreshold` function's return values were halved for leveling balance, but the corresponding selftest assertions were NOT updated. All 4 sub-60 selftest assertions will fail at runtime, producing red error messages for every sub-60 Druid on every login/zone transition.

## Critical Issues

### CR-01: getKSThreshold selftest assertions are double the actual function return values

**File:** `classes/druid/Druid.lua:1317-1322`
**Issue:** The `getKSThreshold` function at line 489 was modified to return halved values for leveling balance (e.g., level >= 50 returns 725 instead of 1450), but the selftest assertions at lines 1320-1322 were NOT updated. The function body comment at line 486 explicitly says "Values halved from original design," confirming the intent. The selftest still asserts the pre-halving values, causing every sub-60 Druid to see red FAIL messages on every login and zone transition.

**Evidence from code:**
- Function body: `getKSThreshold(50)` returns `725` (line 489)
- Selftest assertion: `assert(v50 == 1450, ...)` (line 1322)
- Function body: `getKSThreshold(40)` returns `525` (line 491)
- Selftest assertion: `assert(v40 == 1050, ...)` (line 1321)
- Function body: `getKSThreshold(30)` returns `350` (line 493)
- Selftest assertion: `assert(v30 == 700, ...)` (line 1320)
- Function body: `getKSThreshold(15)` returns `100` (line 497, falls into `else` branch)
- Selftest assertion: `assert(ksVal == 200, ...)` (line 1330)

The level-60 hard guard assertion at line 1302 (`val == 1750`) is correct and will pass.

**Fix:**
```lua
-- Update selftest assertions to match the halved function return values:
assert(v30 == 350, "getKSThreshold(30) should return 350, got: " .. tostring(v30))
assert(v40 == 525, "getKSThreshold(40) should return 525, got: " .. tostring(v40))
assert(v50 == 725, "getKSThreshold(50) should return 725, got: " .. tostring(v50))
-- And line 1330:
assert(ksVal == 100, "getKSThreshold(15) should return 100, got: " .. tostring(ksVal))
```

## Warnings

### WR-01: recordCastTable / recordFailTable access loginContext without nil guard

**File:** `core/spell_trace_core.lua:99,121`
**Issue:** `recordCastTable` (line 99) and `recordFailTable` (line 121) directly access `macroTorch.loginContext.castTable` and `macroTorch.loginContext.failTable` without first checking if `macroTorch.loginContext` is non-nil. The `consumeLandEvent` and `consumeFailEvent` functions (lines 181, 191) include nil guards on `loginContext`, but the record functions do not. If a spell trace event arrives before `onPlayerEnteringWorld` initializes `loginContext`, this will crash with a Lua error.

In practice, this is unlikely because `loginContext` is set on `PLAYER_ENTERING_WORLD` and spell casting cannot happen before then. However, the `computeLandTable` function (line 145) also lacks this guard, and it runs on a 0.1s periodic timer that fires regardless of world entry state (though `maintainLandTables` gates on `macroTorch.inCombat`).

**Fix:** Add nil guard to `recordCastTable` and `recordFailTable` at the top of each function, consistent with the pattern in `consumeLandEvent`:
```lua
function macroTorch.recordCastTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext then  -- add nil guard
        return
    end
    if not macroTorch.loginContext.castTable then
        macroTorch.loginContext.castTable = {}
    end
    -- ... rest of function
end
```

### WR-02: First cast of a spell with corrected spellId is silently lost by the land table

**File:** `core/events.lua:93-115`
**Issue:** In the `UNIT_CASTEVENT` handler, the `recordCastTable` lookup at line 94 (`macroTorch.tracingSpells[spellId]`) happens BEFORE the spellId correction logic at lines 99-115. When a spell has a mismatched static-to-event spellId (i.e., the client's spellId differs from the static baseline), the first cast lookup fails because `tracingSpells` is keyed by the old (static) ID. The correction then migrates the key at lines 114-115 (`tracingSpells[spellId] = tracingSpells[staticSpellId]`), but the current cast event was already lost.

This is self-correcting — the second and subsequent casts will work correctly — but the first cast of each corrected spell per session is silently missing from the land table. This affects `ripLeft`, `rakeLeft`, `pounceLeft` accuracy for the first cast.

**Fix:** Move the `recordCastTable` call to AFTER the spellId correction block, or perform the spellId correction BEFORE the recordCastTable call:
```lua
-- In events.lua UNIT_CASTEVENT handler:
if unitId == macroTorch.player.guid and castType == 'CAST' then
    -- spellId correction (moved BEFORE recordCastTable)
    if macroTorch.current_casting_spell then
        local staticSpellId = macroTorch.resolveSpellId(macroTorch.current_casting_spell)
        if staticSpellId and staticSpellId ~= spellId then
            -- ... correction + migration ...
        end
        macroTorch.current_casting_spell = nil
    end
    -- NOW recordCastTable with updated tracingSpells
    if spellId and macroTorch.tracingSpells[spellId] then
        macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
    end
end
```

### WR-03: getOpenerHealthThreshold called without level argument in leveling.lua (not a bug, but risky pattern)

**File:** `classes/druid/leveling.lua:74`
**Issue:** `getOpenerHealthThreshold()` is called without any arguments at line 74 of `leveling.lua`. The function body in Druid.lua line 502 has a nil guard (`if not level then level = UnitLevel('player') end`) that handles this correctly. However, this creates a hidden dependency — the function call lacks the explicit `level` parameter that other similar functions (`getKSThreshold`, `estimatePlayerDPS`) receive when called from `catAtk`. If the nil guard is ever removed or refactored, this would silently break. The pattern is inconsistent with other level-adaptive functions.

**Fix:** Make the call explicit for consistency:
```lua
and target.health >= macroTorch.getOpenerHealthThreshold(UnitLevel('player'))
```
Or, alternatively, pass `clickContext.playerLevel` if that field becomes available.

## Info

### IN-01: peekCastEvent returns inconsistent nil types

**File:** `core/spell_trace_core.lua:198,202`
**Issue:** `peekCastEvent` uses a bare `return` at line 198 (returns nil) for the early exit when `spell` is nil or target is not attackable, but uses explicit `return nil` at line 202 for the missing cast table case. Both effectively return nil, but the inconsistency is confusing and the bare `return` at line 198 does not clearly convey intent.

**Fix:** Use explicit `return nil` for both:
```lua
if not spell or not macroTorch.target.isCanAttack then
    return nil
end
```

### IN-02: spell_id_map.lua has dual-key entries without validation

**File:** `core/spell_id_map.lua:21-31`
**Issue:** The `SPELL_NAME_TO_ID` table maps both English and Chinese spell names to the same numeric IDs. If a new spell is added with only one locale entry, the other locale would silently return nil. There is no validation that both locale entries exist for each spell.

Additionally, the `SpellTrace:register` calls in Druid.lua (lines 614-633) use `spellName` (English only) for resolution. If the client is set to Chinese locale, `_castSpell` would set `current_casting_spell` to the Chinese name, and `resolveSpellId` at events.lua:100 would correctly find it in `SPELL_NAME_TO_ID`. This works correctly, but the dual-key entries are entirely redundant if only used for resolution — they are only needed for events.lua's `current_casting_spell` lookup. Consider adding a comment explaining the dual-key design rationale.

### IN-03: computeLandTable uses magic number blip thresholds

**File:** `core/spell_trace_core.lua:158`
**Issue:** The blip calculation at lines 157-158 uses magic numbers `0.02` and `0.9` as thresholds. These represent "minimum time before a fail event could arrive" and "maximum age of a cast event we still track". These should be named constants for readability and maintainability.

**Fix:**
```lua
-- At top of spell_trace_core.lua:
macroTorch.MIN_FAIL_DELAY = 0.02   -- minimum seconds before a fail event could arrive
macroTorch.MAX_CAST_LAG = 0.9      -- maximum seconds a cast event is still trackable

-- In computeLandTable:
if blip <= macroTorch.MIN_FAIL_DELAY or blip > macroTorch.MAX_CAST_LAG then
```

---

_Reviewed: 2026-06-29T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_