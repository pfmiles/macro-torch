---
phase: 06
reviewed: 2026-06-14T15:10:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - entity/Player.lua
  - classes/druid/Druid.lua
  - core/selftest.lua
  - classes/druid/HUMAN-UAT.md
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Code Review -- Phase 06: Fix _castSpell Colon/Dot Syntax Mismatch

**Reviewed:** 2026-06-14T15:10:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed 4 files changed in Phase 06: `entity/Player.lua`, `classes/druid/Druid.lua`, `core/selftest.lua`, and `classes/druid/HUMAN-UAT.md`. The core fix replaces colon-syntax calls (`self:xxx()`) with dot-syntax (`obj.xxx()`) inside the `_castSpell` closure, and replaces `self:_castSpell(...)` with `obj._castSpell(...)` in all 53 Druid skill methods. The 15 new Category F selftest tests verify metatable chain integrity.

**Verification summary:**
- Colon-to-dot fix is complete: zero remaining `self:xxx()` calls in `_castSpell` (verified via grep), zero remaining `self:_castSpell` calls in Druid.lua (verified via grep).
- All 53 Druid skill methods correctly use `obj._castSpell(...)` via dot syntax.
- All 15 Category F selftest tests have proper `UnitClass('player') ~= 'Druid'` guards and exercise Type A (enemy), Type B (self), and Type C (flexible-target) skills through `'raw'` and `'safe'` modes.
- No WoW 1.12.1 `#` unary length operator used in any reviewed file.
- No hardcoded secrets, no eval/injection vectors, no empty catch blocks found.

**Key findings:**
- A WARNING-level inconsistency: the `obj.cast()` method at Player.lua:29 accepts an `onSelf` parameter but ignores it, while the `_castSpell` closure has two divergent casting paths (`CastSpellByName` directly vs. `macroTorch.castSpellByName` via `obj.cast`).
- A WARNING: `_hasResource` at Player.lua:102 uses `self.mana` via multi-hop closure capture -- functionally correct but fragile and undocumented.
- Three INFO findings: stale registration count comment in selftest.lua, `resourceCost=0` instead of `nil` in several Druid skill methods (pre-existing from Phase 5), and a minor documentation gap in HUMAN-UAT.md.
- One design-consistency INFO: `player.ravage()` at Druid.lua:392 is called without a mode parameter (defaults to 'ready'), while `player.pounce('safe')` at line 389 uses explicit 'safe' mode.

## Warnings

### WR-01: obj.cast ignores onSelf parameter, creating divergent casting paths

**File:** `entity/Player.lua:29-31, 76-79`
**Issue:** The `obj.cast(spellName, onSelf)` method at line 29 accepts an `onSelf` parameter but always calls `macroTorch.castSpellByName(spellName, 'spell')` regardless of its value. Meanwhile, `_castSpell` at line 77 uses `CastSpellByName(spellName, true)` directly for the self-target path. This creates two divergent casting codepaths:

1. **onSelf=true** (line 77): `CastSpellByName(spellName, true)` -- raw WoW API, no spell-ID lookup
2. **onSelf=false** (line 79): `obj.cast(spellName, false)` -> `macroTorch.castSpellByName(spellName, 'spell')` -> `CastSpell(getSpellIdByName(...), 'spell')` -- goes through spell-ID lookup via `biz_util.lua:52-54`

If `getSpellIdByName` returns nil for a spell name, the self-target path (direct `CastSpellByName`) might still work while the enemy-target path (via `CastSpell` with ID) would fail. While this is unlikely in practice for valid spell names, the asymmetry is a maintenance hazard and makes the casting behavior harder to reason about.

**Fix:** Either (a) make `obj.cast` actually handle `onSelf`, or (b) unify both paths to use `macroTorch.castSpellByName`:
```lua
-- Option A: Make obj.cast fully handle self-targeting
function obj.cast(spellName, onSelf)
    if onSelf then
        CastSpellByName(spellName, true)
    else
        macroTorch.castSpellByName(spellName, 'spell')
    end
end

-- Then simplify _castSpell to a single execution path:
-- obj.cast(spellName, onSelf)
```

Note: This is a pre-existing design issue, not introduced by Phase 6, but Phase 6 touches the `_castSpell` closure and this asymmetry is now more visible.

### WR-02: _hasResource self.mana closure resolution chain is undocumented and fragile

**File:** `entity/Player.lua:101-103`
**Issue:** The `_hasResource` function uses `self.mana` where `self` is a closure upvalue captured from `macroTorch.Player:new(self)`. The resolution chain is:
1. `self` = `macroTorch.Player` (the Player prototype, a Unit instance with `ref="player"`)
2. `self.mana` resolves through `__index` -> `UNIT_FIELD_FUNC_MAP["mana"]` -> `UnitMana("player")`

This works correctly because the Player prototype always reads the player's mana via `UnitMana("player")`. However, the code appears to be checking the *instance's* mana when it is actually checking the *prototype's* mana. If the metatable chain were ever restructured or if a subclass overrode `mana` in its FIELD_FUNC_MAP, this could silently break.

**Fix:** Either (a) use `macroTorch.player.mana` for explicit intent, or (b) add a comment documenting the closure capture chain:
```lua
-- self.mana resolves through Player prototype metatable to UnitMana("player")
-- This is always correct regardless of the calling instance (Player/Druid/Hunter),
-- because the Player prototype's ref is always "player".
function obj._hasResource(cost)
    return self.mana and self.mana >= cost
end
```

Note: This is pre-existing, not introduced by Phase 6, but is within the `_castSpell` call chain that Phase 6 modifies.

## Info

### IN-01: Stale self-test registration count comment

**File:** `core/selftest.lua:454`
**Issue:** The comment at line 454 states "Registration count: 74 total (A:11 + B:34 + C:20 + D:7 + E:2)" but does not account for the 15 new Category F tests (lines 464-568) registered in this file. Druid.lua also adds 7 Category G tests (lines 1237-1277). The actual total is approximately 96+ tests.
**Fix:** Update the comment:
```lua
-- Registration count: ~96 total (A:11 + B:34 + C:20 + D:7 + E:3 + F:15 + G:7)
-- Note: Categories A-E in selftest.lua, F in selftest.lua, G in classes/druid/Druid.lua;
-- other class files may register additional tests.
```

### IN-02: resourceCost=0 triggers redundant _hasResource(0) call in safe mode

**File:** `classes/druid/Druid.lua` (lines 54, 146, 150, 158, 162, 166, 178, 190, 194, 198)
**Issue:** Multiple skill methods pass `resourceCost=0` (e.g., Prowl at line 146, Dash at line 150, FF at line 54, Enrage at line 190, etc.). In Lua, `0` is truthy, so `if resourceCost then` at Player.lua:62 enters the block and calls `_hasResource(0)`, which always returns `true` (since `mana >= 0`). Per the `_castSpell` docstring ("nil = skip check"), these should use `nil` to skip the check entirely.
**Fix:** Replace `resourceCost=0` with `resourceCost=nil` for skills with no meaningful resource cost. Example:
```lua
-- Before:
function obj.faerie_fire_feral(mode)
    return obj._castSpell({ en = 'Faerie Fire (Feral)', zh = '精灵之火（野性）' }, mode, nil, 0, false)
end
-- After:
function obj.faerie_fire_feral(mode)
    return obj._castSpell({ en = 'Faerie Fire (Feral)', zh = '精灵之火（野性）' }, mode, nil, nil, false)
end
```
Note: Pre-existing from Phase 5, not introduced by Phase 6. Does not affect correctness, only micro-optimization.

### IN-03: catAtk opener module: inconsistent mode parameter usage

**File:** `classes/druid/Druid.lua:389, 392`
**Issue:** In the opener module within `catAtk()`, line 389 calls `macroTorch.player.pounce('safe')` with explicit `'safe'` mode (range + resource checks), while line 392 calls `player.ravage()` without any mode parameter (defaults to 'ready' behavior -- readiness check only, no range/resource checks). Both are 50-energy melee-range skills, so the inconsistency means ravage can be attempted without sufficient energy or from out of range.
**Fix:** Add a mode parameter to `player.ravage()` for consistency:
```lua
player.ravage('safe')
```
Note: Pre-existing logic, not introduced by Phase 6. The `ravage()` call has always lacked a mode parameter; this is surfaced because Phase 6's `_castSpell` fix makes the mode handling more explicit.

### IN-04: HUMAN-UAT.md regression section uses ambiguous Hunter test

**File:** `classes/druid/HUMAN-UAT.md:140`
**Issue:** The regression check line states: "If you have a Hunter alt, verify `/run local p = macroTorch.player; p.cast('Auto Shot', false)` works correctly (dot syntax unchanged)". The instruction says "dot syntax unchanged" but then uses `p.cast('Auto Shot', false)` which is dot syntax. The point is to verify Hunter methods still work, but the `onSelf=false` parameter in `obj.cast` is silently ignored (see WR-01), so this test doesn't actually verify that the dot syntax `obj.cast` handles the `onSelf` parameter correctly.
**Fix:** Clarify the test or use a more meaningful regression check:
```markdown
- [ ] **Hunter class unaffected** -- If you have a Hunter alt, verify `/run macroTorch.player.cast('Auto Shot', false)` works correctly. (The dot syntax `obj.cast()` on Player.lua:29 was not changed by this fix; verify no Lua errors appear.)
```
Note: The UAT document is otherwise well-structured with clear Type A/B/C categorizations, explicit mode testing ('ready'/'safe'/'raw'), and an integration test for catAtk.

---

_Reviewed: 2026-06-14T15:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_