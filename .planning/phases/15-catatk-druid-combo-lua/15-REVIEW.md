---
phase: 15-catatk-druid-combo-lua
reviewed: 2026-06-20T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/combo.lua
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-06-20
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Phase 15 relocates `catAtk()` from a per-instance method defined in `Druid:new()` (`obj.catAtk`) to a global function `macroTorch.catAtk()` in `combo.lua`. The function body was moved verbatim with no logic changes. The routing in `druidAtk()` was updated from `macroTorch.player.catAtk(rough)` to `macroTorch.catAtk(rough)`. A new selftest was added to verify `macroTorch.catAtk` exists as a function.

### Verified Ok
- The function body contains zero `self` or `obj` references -- it exclusively uses `macroTorch.*` globals and local variables. The relocation from instance method to global function is safe.
- `druidAtk()` routing correctly calls `macroTorch.catAtk(rough)`.
- No residual references to `obj.catAtk` or `macroTorch.player.catAtk` exist anywhere in the codebase.
- The selftest registration follows the established pattern (opting out for non-Druid classes with `isOptional=true`).
- Both files are already present in `build_order.txt` in the correct order (Druid.lua before combo.lua), so `macroTorch.catAtk` will be defined before `druidAtk` calls it.

### Key Concern

With `catAtk` removed from `Druid:new()`, any future `Druid` instance will NOT have a `catAtk` method on its metatable chain. This is the intended change, but it means if any code path ever does `someDruidObj.catAtk()`, it would `nil`-error. The grep confirms zero such references today, but this is a silent contract change worth noting for future work.

## Info

### IN-01: Stub comment line is syntactically misleading

**File:** `classes/druid/Druid.lua:297`
**Issue:** The comment line `-- stub: function obj.catAtk(rough)` looks like Lua syntax in a comment. It could mislead a developer into thinking `obj.catAtk` still exists as a valid function. The `--` prefix makes it a comment, but the phrasing "stub" suggests something that might still be callable, when in fact it is completely removed.
**Fix:** Replace with a clearer comment that unambiguously states the function no longer exists:
```lua
-- catAtk moved to classes/druid/combo.lua as macroTorch.catAtk(rough)
-- NOTE: obj.catAtk no longer exists; call macroTorch.catAtk(rough) instead.
```

### IN-02: Selftest comment references `catAtk()` but cannot actually test the function

**File:** `classes/druid/Druid.lua:1203-1204`
**Issue:** The selftest comment reads `"Verify that catAtk() sets RESHIFT_ENERGY via computeReshiftEnergy (not hardcoded 60)"` followed by `"We cannot call catAtk() directly in selftest, but we can verify the function exists"`. The actual selftest body only tests `computeReshiftEnergy()`, not `catAtk()`. After the relocation, this comment is in Druid.lua while `catAtk` is now defined in combo.lua, making the cross-file reference stale.
**Fix:** Update the comment to reflect the relocated function:
```lua
-- Verify that computeReshiftEnergy() returns a dynamic value (Furor + Wolfshead Helm)
-- catAtk() (now in combo.lua) sets RESHIFT_ENERGY via computeReshiftEnergy()
```

---

_Reviewed: 2026-06-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_