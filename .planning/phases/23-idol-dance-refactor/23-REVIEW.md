---
phase: 23-idol-dance-refactor
reviewed: 2026-08-03T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/selftest.lua
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-08-03T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed two files in the Phase 23 idol-dance refactor scope:
- `classes/druid/Druid.lua` — contains the `computeNormalRelic` refactor (simplified branching structure) and the new distance-early-return in `recoverNormalRelic`
- `classes/druid/selftest.lua` — contains 7 new Category O self-tests for the idol-dance logic

The `computeNormalRelic` refactor correctly simplifies the nested branching while preserving the original D-02 non-combat behavior and fixing Gaps 1 and 2 per D-01. However, two of the new self-tests (Cat O-01 and Cat O-02) are fragile due to missing combat-state guards, and one is a duplicate of the other.

## Warnings

### WR-01: Cat O-01 and Cat O-02 selftests fail when player is not in combat

**File:** `classes/druid/selftest.lua:669-693`
**Issue:** Both tests assert that `computeNormalRelic` returns a non-Savagery idol for fast combat/PvP scenarios. However, `computeNormalRelic` checks the non-combat branch (line 368) *before* the `isTrivialBattleOrPvp` branch (line 372). If the player happens to be out of combat when the self-test runs, the function returns `'Idol of Savagery'` at line 369, and the assertion fails.

Compare with Cat O-03 (line 696), Cat O-04 (line 706), and Cat O-06 (line 717) which all correctly guard their combat-state assumptions with `if macroTorch.player.isInCombat then return end` (or its inverse). Cat O-01 and O-02 lack these guards.

**Fix:** Add combat-state guards to both tests:

```lua
macroTorch.SelfTest:register("Cat O-01: fast combat returns Fero/Rot (Gap 1 fix) — per D-01", function()
    if not macroTorch.player.isInCombat then return end  -- <-- ADD THIS
    local ctx = {
        isTrivialBattle = true,
        isImmuneRip = false,
    }
    assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
        "expected non-Savagery for fast combat, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)

macroTorch.SelfTest:register("Cat O-02: PvP target returns Fero/Rot (Gap 1 fix) — per D-01", function()
    if not macroTorch.player.isInCombat then return end  -- <-- ADD THIS
    local ctx = {
        isTrivialBattle = true,
        isImmuneRip = false,
    }
    assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
        "expected non-Savagery for PvP target, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)
```

### WR-02: Cat O-01 and Cat O-02 are identical tests — O-02 does not test PvP-specific behavior

**File:** `classes/druid/selftest.lua:669-693`
**Issue:** Both tests create the identical context `{ isTrivialBattle = true, isImmuneRip = false }` and make the identical assertion. Cat O-02 is labeled "PvP target returns Fero/Rot" but does not exercise the PvP-specific path (`target.isPlayerControlled`) in `isTrivialBattleOrPvp`. It merely duplicates Cat O-01, which tests the `isTrivialBattle` path.

**Fix:** Either remove Cat O-02 as redundant, or modify it to test the PvP-specific code path:

```lua
macroTorch.SelfTest:register("Cat O-02: PvP target returns Fero/Rot (Gap 1 fix) — per D-01", function()
    if not macroTorch.player.isInCombat then return end
    if not macroTorch.target.isPlayerControlled then return end  -- only test on actual PvP target
    local ctx = {
        isTrivialBattle = false,       -- not a trivial fight
        isImmuneRip = false,
    }
    -- isTrivialBattleOrPvp returns true via target.isPlayerControlled path
    assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
        "expected non-Savagery for PvP target, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
end, true)
```

### WR-03: `getNextAbilityCost` has no D-03 guard for Tiger's Fury or Rake

**File:** `classes/druid/Druid.lua:889, 899`
**Issue:** The function `getNextAbilityCost` checks Tiger's Fury presence (line 889) and Rake presence (line 899) without first verifying these abilities are learned via `isSpellExist`. Compare with `shouldUseBite` (line 942), `shouldCastRip` (line 917), and `shouldUseShred` (line 687), which all include D-03 guards. A low-level druid who hasn't trained Tiger's Fury or Rake could receive misleading energy-cost predictions from `getNextAbilityCost`, which feeds into `shouldDoReshift` and `shouldCastFFDuringWaitWindow` decision-making.

**Fix:** Add `isSpellExist` guards:

```lua
-- Line 889, replace:
    if not macroTorch.isTigerPresent(clickContext) then
-- with:
    if macroTorch.isSpellExist("Tiger's Fury", 'spell') and not macroTorch.isTigerPresent(clickContext) then

-- Line 899, replace:
    if not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake then
-- with:
    if macroTorch.isSpellExist('Rake', 'spell') and not macroTorch.isRakePresent(clickContext) and not clickContext.isImmuneRake then
```

### WR-04: Cat O-07 is a weak test — does not validate `recoverNormalRelic` behavior

**File:** `classes/druid/selftest.lua:726-731`
**Issue:** The test labeled "Distance >= 20 bypass present (Gap 4 fix) — per D-03" only checks that `recoverNormalRelic` is a function and that `target.distance` is not nil. It never calls `recoverNormalRelic` or validates that the distance >= 20 early-return path actually works. The test name implies behavioral validation but only performs type/API-existence checks.

**Fix:** Add a behavioral test (requires an appropriate test fixture), or rename the test to accurately reflect its scope:

```lua
-- If retaining as a existence check:
macroTorch.SelfTest:register("Cat O-07: recoverNormalRelic function and target.distance API exist — per D-03", function()
    assert(type(macroTorch.recoverNormalRelic) == 'function',
        "recoverNormalRelic should be a function")
    assert(macroTorch.target.distance ~= nil,
        "target.distance API not available on this client")
end, true)
```

## Info

### IN-01: Redundant multiplication by 1

**File:** `classes/druid/Druid.lua:715`
**Issue:** `local energyIn1s = erps * 1` — multiplying by 1 has no effect and adds noise. The comment says "energy in 1s" which the variable name already conveys.

**Fix:** Replace with `local energyIn1s = erps`.

### IN-02: `selectFerocityOrEmeraldRot` returns relic name even when player owns neither

**File:** `classes/druid/Druid.lua:418`
**Issue:** When the player owns neither `Idol of Ferocity` nor `Idol of the Emerald Rot`, the function falls through to return `'Idol of Ferocity'` as a default. The caller `recoverNormalRelic` guards against this with a `hasItem()` check at line 429, so no equip attempt occurs for an absent relic. However, `computeNormalRelic` stores this result in `clickContext.normalRelic` (combo.lua:103) regardless of ownership, which is semantically misleading — the "normal relic" is a relic the player doesn't own.

**Fix:** Consider returning `nil` or adding a comment noting the caller's responsibility to check ownership.

---

_Reviewed: 2026-08-03T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_