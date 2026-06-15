---
phase: 07-druid
reviewed: 2026-06-15T12:50:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/bear.lua
  - classes/druid/utility.lua
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-06-15T12:50:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed 3 modified files for Phase 07-druid: semantic form-detection method refactoring in DRUID_FIELD_FUNC_MAP. The implementation correctly adds 5 FIELD_FUNC_MAP entries (`isInCatForm`, `isInBearForm`, `isInTravelForm`, `isInAquaticForm`, `isInCasterForm`), replaces all 7 hardcoded `isFormActive` call sites across Druid.lua (3), bear.lua (2), and utility.lua (2), and registers 5 Category G2 SelfTest registrations. Build succeeds. `entity/Player.lua` is correctly unchanged.

Verification results confirm:
- 5 FIELD_FUNC_MAP entries present, inserted between `isBerserk` and `humanFormMana` per plan
- `isInBearForm` correctly uses OR logic: `self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')`
- 3 `-- reserved for future expansion` annotations present
- 0 `isFormActive` calls remain in bear.lua and utility.lua; only the 5 FIELD_FUNC_MAP internal delegations remain in Druid.lua
- 5 SelfTest registrations present with correct `isIn` prefix naming
- All symbols reachable in build output (`SM_Extend.lua`)

Three findings identified: 1 Warning (comment format inconsistency with RESEARCH.md target pattern) and 2 Info items (pre-existing G1 self-test style inconsistency, comment typo). No critical issues found.

## Narrative Findings (AI reviewer)

### WR-01: `-- reserved for future expansion` comment placed after `end,` instead of inside function body

**File:** `classes/druid/Druid.lua:457,460,463`

**Issue:** The RESEARCH.md target pattern (lines 144-156) shows the `-- reserved for future expansion` comment placed *inside* the function body, before the `return` statement:

```lua
-- Target pattern from RESEARCH.md:
['isInTravelForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Travel Form')
end,
```

The actual implementation places the comment after `end,`:

```lua
['isInTravelForm'] = function(self)
    return self.isFormActive('Travel Form')
end, -- reserved for future expansion
['isInAquaticForm'] = function(self)
    return self.isFormActive('Aquatic Form')
end, -- reserved for future expansion
['isInCasterForm'] = function(self)
    return self.isFormActive('Moonkin Form')
end, -- reserved for future expansion
```

**Impact:** The comment is syntactically valid either way and does not affect runtime behavior. However, trailing commas in Lua can be problematic in some environments (though not in WoW 1.12.1's embedded Lua). The comment-after-comma placement makes the comma less visible, which could cause issues if the FIELD_FUNC_MAP table were reordered. Additionally, the comment placement deviates from the documented target pattern in RESEARCH.md, which may confuse future maintainers who reference the research document.

**Fix:** Move comments inside the function body to match the documented pattern:
```lua
['isInTravelForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Travel Form')
end,
['isInAquaticForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Aquatic Form')
end,
['isInCasterForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Moonkin Form')
end,
```

---

### IN-01: Category G1 SelfTest entry `isOoc` does not use `toBoolean` wrapping (pre-existing, not introduced by this phase)

**File:** `classes/druid/Druid.lua:1257-1261`

**Issue:** The `isOoc` SelfTest at line 1259 accesses `macroTorch.player.isOoc` without wrapping in `macroTorch.toBoolean()`, and asserts `type(val) ~= "nil"` rather than `type(val) == "boolean"`. This differs from the Category G2 entries (which all use `macroTorch.toBoolean()` + `type(val) == "boolean"`) and even from its sibling `isProwling` test (line 1263-1267, which does use `toBoolean()`).

The `isBerserk` test at line 1269-1273 has the same pattern: no `toBoolean()` wrapping, `type(val) ~= "nil"` assertion.

**Impact:** If `isOoc` or `isBerserk` ever returns `nil` (edge case: `self.buffed` returns nil), these tests would still pass (`nil ~= "nil"` is false, which would fail the assert -- actually it would correctly catch nil. But the error message would be misleading since the variable is `val` not a descriptive name). The real concern is inconsistency within the same category -- G2 entries are more rigorous in verifying boolean return type.

Note: This is a pre-existing issue, not introduced by Phase 07. The new Category G2 entries correctly use `toBoolean()` + boolean type check. Listed here for awareness.

**Fix:** (Optional) Align G1 entries with G2 pattern:
```lua
macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isOoc exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isOoc)
    assert(type(val) == "boolean", "isOoc not boolean: " .. type(val))
end, true)
```

---

### IN-02: Typo in DRUID_FIELD_FUNC_MAP comment: "conditinal" should be "conditional"

**File:** `classes/druid/Druid.lua:439`

**Issue:** Line 439 reads `-- conditinal props` but should be `-- conditional props`. This is a pre-existing comment typo (visible in the RESEARCH.md source extract at line 439 of the original), not introduced by Phase 07. Noted for completeness.

**Fix:** Correct the spelling in a separate cleanup pass:
```lua
-- conditional props
```

---

_Reviewed: 2026-06-15T12:50:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_