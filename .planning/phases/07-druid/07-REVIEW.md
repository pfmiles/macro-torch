---
phase: 07-druid
reviewed: 2026-06-15T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/bear.lua
  - classes/druid/utility.lua
findings:
  blocker: 0
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-06-15
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed 3 Druid class files where Phase 07 added 5 semantic form-check methods (`isInCatForm`, `isInBearForm`, `isInTravelForm`, `isInAquaticForm`, `isInCasterForm`) to `DRUID_FIELD_FUNC_MAP` and replaced 7 hardcoded `isFormActive` calls across Druid.lua (3 sites), bear.lua (2 sites), and utility.lua (2 sites). This is described as a pure refactoring with zero behavior change.

The FIELD_FUNC_MAP additions are structurally correct and the call-site replacements are properly wired. However, one replacement at `bear.lua:66` introduces a behavior change contrary to the claim of "pure refactoring," and the `hasBuff`/`buffed` calls in `isBerserk` and `isProwling` use an inconsistent calling convention compared to `isOoc`. No blockers, critical security issues, or crash risks were found.

## Warnings

### WR-01: `bearAoe()` bear form check broadens from Dire Bear Form only to Bear Form OR Dire Bear Form (behavior change)

**File:** `classes/druid/bear.lua:66`

**Issue:** The original code at `bearAoe:66` read:
```lua
if not macroTorch.player.isFormActive('Dire Bear Form') then
```
The replacement reads:
```lua
if not macroTorch.player.isInBearForm then
```

The `isInBearForm` FIELD_FUNC_MAP entry (Druid.lua:452-453) is defined as:
```lua
['isInBearForm'] = function(self)
    return self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')
end,
```

This means the `bearAoe` guard now passes for both Bear Form and Dire Bear Form, whereas the original code only guarded on Dire Bear Form. The `bearAtk` function (line 102) had the same original pattern (`isFormActive('Dire Bear Form')`).

This is a behavior change. The original code intentionally checked only Dire Bear Form. A player in Bear Form (not Dire Bear Form) who triggers `bearAoe()` or `bearAtk()` would previously have been silently exited; now they enter the bear combat logic.

**Fix:** If the broadening is intentional, document it. If not, either:
(a) Add `isInDireBearForm` to the FIELD_FUNC_MAP and use it in bear.lua:
```lua
['isInDireBearForm'] = function(self)
    return self.isFormActive('Dire Bear Form')
end,
```
(b) Or add a separate field function that covers only Dire Bear Form and use it where the original code required Dire Bear Form specifically.

### WR-02: `isBerserk` and `isProwling` FIELD_FUNC_MAP entries call `buffed()` with inconsistent argument patterns

**File:** `classes/druid/Druid.lua:440-447`

**Issue:** The FIELD_FUNC_MAP contains three `buffed()` calls with two different argument patterns:

```lua
-- Line 440-442: two-argument call
['isOoc'] = function(self)
    return self.buffed('Clearcasting', 'Spell_Shadow_ManaBurn')
end,
-- Line 443-445: two-argument call (name + texture)
['isProwling'] = function(self)
    return self.buffed('Prowl', 'Ability_Ambush')
end,
-- Line 446-448: two-argument call (name + texture)
['isBerserk'] = function(self)
    return self.buffed('Berserk', 'Ability_Druid_Berserk')
end,
```

The `buffed()` method in `entity/Unit.lua:36-46` accepts both `buffName` (string) and `buffTexture` (string). When `buffName` is provided, it calls the global WoW API function `buffed(buffName)`. The `buffed()` WoW API function is hardcoded to check the `'player'` unit -- it does not accept a unit argument.

This is correct for the global singleton `macroTorch.player` (whose `self.ref` is `'player'` via the metatable chain). However, it is fragile: if `DRUID_FIELD_FUNC_MAP` were ever inherited by a non-player class instance, `buffed('Berserk')` would still check the player unit, not the unit represented by `self.ref`. The new form-check methods (`isInCatForm`, etc.) use `isFormActive` which similarly iterates `GetShapeshiftFormInfo()` -- also implicitly player-only.

This is not a regression from Phase 07 -- the inconsistency predates this phase. It is flagged because the Phase 07 change ships in close proximity.

**Fix:** No fix required for Phase 07 scope. Document the latent fragility that FIELD_FUNC_MAP entries are player-only by design due to WoW API limitations.

## Info

### IN-01: SelfTest registrations for `isInTravelForm`, `isInAquaticForm`, `isInCasterForm` are present but have zero current call sites

**File:** `classes/druid/Druid.lua:1294-1310`

**Issue:** Per the Phase 07 plan, `isInTravelForm`, `isInAquaticForm`, and `isInCasterForm` are "reserved for future expansion with zero current call sites" (lines 455-463). The Category G2 SelfTest registrations for these methods (lines 1294-1310) verify they return booleans, which is correct. However, with zero callers in the codebase, these tests verify that the FIELD_FUNC_MAP entries exist and return values but do not verify that any production code depends on correct behavior of these fields.

When the reserved methods eventually gain callers, ensure those callers are tested for the specific expected behavior (e.g., checking that `isInCasterForm` returns true when Moonkin Form is active, not just any boolean).

---

_Reviewed: 2026-06-15T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_