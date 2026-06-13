---
phase: 05-spell-refactor
reviewed: 2026-06-14T00:00:00Z
depth: quick
files_reviewed: 1
files_reviewed_list:
  - classes/druid/Druid.lua
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-06-14
**Depth:** quick
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed a single-case fix in `classes/druid/Druid.lua` where `'DRUID'` (all caps) was corrected to `'Druid'` (proper case) across 8 locations: one `registerPlayerClass` call and seven `UnitClass('player') ~=` guards in selftest registrations. The fix is correct and complete for the lines it touches. However, a stale doc-comment in `core/class.lua` still advertises the old incorrect casing, creating a self-contradiction risk for future class additions.

## Structural Findings (fallow)

_None provided._

## Warnings

### WR-01: Stale doc-comment in `core/class.lua` references incorrect casing

**File:** `core/class.lua:41`
**Issue:** The JSDoc-style comment for `registerPlayerClass` still says `(e.g. "DRUID", "HUNTER")`, using the now-fixed all-caps form. Since `UnitClass('player')` returns proper-cased string (e.g. `"Druid"`) and `registerPlayerClass` creates a dictionary keyed by that exact string, the example in the doc comment is now misleading. A developer adding a new class (e.g. Hunter) might copy the example and register against `"HUNTER"` instead of `"Hunter"`, reintroducing the same bug for that class.

**Fix:** Update the doc-comment to use proper casing:
```lua
-- @param className  string — the UnitClass name (e.g. "Druid", "Hunter")
```

---

_Reviewed: 2026-06-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_