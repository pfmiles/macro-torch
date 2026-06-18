---
phase: quick-260618-safe-default-mode
reviewed: 2026-06-18T23:30:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - entity/Player.lua
  - classes/druid/Druid.lua
  - classes/druid/bear.lua
  - classes/druid/cat.lua
  - classes/druid/combo.lua
  - classes/druid/utility.lua
  - classes/hunter/combat.lua
  - classes/mage/combat.lua
  - classes/priest/combat.lua
  - classes/priest/utility.lua
  - classes/rogue/combat.lua
  - classes/warrior/combat.lua
  - classes/warrior/utility.lua
  - core/selftest.lua
findings:
  critical: 1
  warning: 1
  info: 2
  total: 4
status: issues_found
---

# Phase quick-260618-safe-default-mode: Code Review Report

**Reviewed:** 2026-06-18
**Depth:** standard (per-file analysis + cross-file call chain tracing, mode propagation audit)
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Reviewed the refactor that changes `_castSpell` default mode from `'ready'` (readiness check only) to `'safe'` (readiness + range + resource checks). The core change is `if mode == 'safe'` to `if mode ~= 'ready' and mode ~= 'raw'` in `entity/Player.lua`, making `nil` now walk the safe path. All 22 `'safe'` removals and all 35 `'ready'` additions across 12 call-site files were traced through wrapper definitions back into `_castSpell`. No argument ordering bugs, no missing `'ready'` conversions, no dynamic mode construction. The Lua comparison `nil ~= 'ready'` correctly evaluates to `true`, so nil (the new default) reliably triggers the range+resource check block.

However, the selftest file (`core/selftest.lua`) was not updated and still passes the now-obsolete literal `'safe'` as a mode argument. This is a stale test that no longer exercises a distinct codepath from passing `nil`. Additionally, a stale comment in `cat.lua` references the old nil=ready semantics.

### Call site verification results

| Category | Count | Verified |
|----------|-------|----------|
| `'safe'` -> `nil`/`()` (adopting new default) | 22 | All safe -- new nil triggers same checks old 'safe' did |
| `nil`/`()` -> `'ready'` (preserving old behavior) | 35 | All safe -- 'ready' skips range+resource as old nil did |
| `'raw'` (untouched) | 2 | N/A |

### Key deep traces verified

1. **Druid heal range checks (`combo.lua:56-71`):** `healing_touch(nil, false)` passes `range=40` via method definition. Under new condition, nil triggers `_isInRange(40)`. This runs correctly against `macroTorch.target` (set by `TargetUnit(lowestUnit)` just above). Previously `('safe', false)` also ran this check. No regression.

2. **Druid self-heal bypass (`combo.lua:64-71`):** `rejuvenation(nil, true)` -- `onSelf=true` causes the range check bypass (`not onSelf` is false at Player.lua:59). Self-buffs correctly skip range even with new default=safe.

3. **Priest heal (`priest/utility.lua:55,57`):** `heal('ready', onSelf)` -- method has `range=nil, resourceCost=nil`, so range+resource checks are no-ops regardless of mode. The readiness check (step 2) still fires for 'ready'. Behavior identical to old `heal(nil, onSelf)`.

4. **Cat ooc path (`cat.lua:51,57`):** `shred('ready')`/`claw('ready')` correctly preserves the old "ooc means no resource cost, skip resource check" behavior. Without this explicit 'ready', nil would trigger `_hasResource(computeShred_E())` -- which would fail since `self.mana` (energy) might be low with Omen of Clarity active.

5. **Cat pounce (`Druid.lua:387`):** `pounce()` now uses new default=safe, triggering `_hasResource(50)` and no range check (range=nil). Old `('safe')` did the same. Identical behavior.

6. **Warrior/Rogue/Mage/Hunter conversions:** All `nil -> 'ready'` conversions verified against method definitions. Most have `range=nil, resourceCost=nil` making range+resource checks no-ops. No behavior change.

## Critical Issues

### CR-01: Self-test still passes hardcoded 'safe' string after mode semantics changed -- stale codepath

**File:** `core/selftest.lua:497-503`
**Issue:** The self-test `"F: _castSpell with safe mode does not error"` still passes the literal string `'safe'` as the mode argument to `_castSpell`. After the refactoring, the `if mode == 'safe'` branch in `_castSpell` no longer exists -- it was replaced by `if mode ~= 'ready' and mode ~= 'raw' then`. While this test happens to pass (because `'safe' ~= 'ready'` is `true` and `'safe' ~= 'raw'` is `true`, so the block still executes), the test is now redundant: it exercises the same codepath as passing `nil`. The test name is misleading because `'safe'` is no longer a documented mode string -- it is an undocumented alias that behaves identically to `nil` (the new default). This means the test provides no signal about the correctness of the refactoring. Additionally, there is no test for the explicit `'ready'` mode (readiness check only), which is the most important explicit mode after this refactor.
**Fix:** Replace the stale `'safe'` test with a nil-default test, and add a new `'ready'` mode test:

```lua
-- Replace:
macroTorch.SelfTest:register("F: _castSpell with safe mode does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player._castSpell({en='TestSpell', zh='测试技能'}, 'safe', nil, nil, false)
    end)
    assert(ok, "_castSpell('safe') pcall failed: " .. tostring(err))
end, false)

-- With:
macroTorch.SelfTest:register("F: _castSpell with nil (default safe) mode does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player._castSpell({en='TestSpell', zh='测试技能'}, nil, nil, nil, false)
    end)
    assert(ok, "_castSpell(nil) pcall failed: " .. tostring(err))
end, false)

-- And add:
macroTorch.SelfTest:register("F: _castSpell with ready mode does not error", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ok, err = pcall(function()
        macroTorch.player._castSpell({en='TestSpell', zh='测试技能'}, 'ready', nil, nil, false)
    end)
    assert(ok, "_castSpell('ready') pcall failed: " .. tostring(err))
end, false)
```

## Warnings

### WR-01: Stale comment still references old nil=ready default semantics

**File:** `classes/druid/cat.lua:48`
**Issue:** The comment reads `-- ooc doesn't consume energy, so use ready mode (nil) instead of safe mode`. After the refactor, `nil` is no longer ready mode -- it is the new safe default. The code correctly uses explicit `'ready'` strings on lines 51 and 57, but the comment's parenthetical `(nil)` contradicts the current semantics. Readers who see `(nil)` and check the current `_castSpell` JSDoc will be confused.
**Fix:**
```lua
-- ooc doesn't consume energy, so use ready mode ('ready') instead of safe mode
```

## Info

### IN-01: JSDoc `@param mode` comment underspecified regarding 'ready' vs 'raw'

**File:** `entity/Player.lua:35`
**Issue:** The `@param mode` comment reads: `nil='safe' (default), 'ready'=readiness only, 'raw'=no checks`. The phrase "readiness only" is ambiguous -- it could be interpreted as `'ready'` skipping all checks (like `'raw'`), when in fact `'ready'` still performs the spell readiness/GCD check (step 2) and only skips the distance+resource checks (step 3). The distinction between `'ready'` (readiness check + no range/resource) and `'raw'` (no checks at all) is important and should be clearer.
**Fix:**
```lua
-- @param mode string|nil nil='safe' (default: all checks), 'ready'=readiness+GCD only (skip range+resource), 'raw'=no checks at all
```

### IN-02: `healing_touch(nil, false)` in druidHeal -- explicit nil is awkward when `()` would suffice

**File:** `classes/druid/combo.lua:56-61`
**Issue:** The druidHeal function passes `nil` explicitly as the first argument to `healing_touch`, `regrowth`, and `rejuvenation`: `macroTorch.player.healing_touch(nil, false)`. Since `nil` is now the default (safe) mode, this could simply be `macroTorch.player.healing_touch(nil, false)` -- wait, actually this is the correct Lua pattern because there IS a second argument (`onSelf`). In Lua, to skip the first argument and provide the second, you MUST pass `nil` explicitly. So `healing_touch(nil, true)` is correct Lua -- no issue. This finding is withdrawn; the code is correct as-is.

---

_Reviewed: 2026-06-18T23:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_