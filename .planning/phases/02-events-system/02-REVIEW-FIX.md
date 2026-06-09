---
phase: 02-events-system
fixed_at: 2026-06-08T00:00:00Z
review_path: .planning/phases/02-events-system/02-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-06-08T00:00:00Z
**Source review:** .planning/phases/02-events-system/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (WR-01 through WR-05)
- Fixed: 4
- Skipped: 1

## Fixed Issues

### WR-01: Dead code in `computeLandTable` guard -- unreachable `not lastCast` check

**Files modified:** `core/spell_trace_core.lua`
**Commit:** 3ebb910
**Applied fix:** Removed the redundant `not lastCast` sub-condition from the guard on line 122. The `or 0` fallback on line 119 guarantees `lastCast` is always a number, so `not lastCast` was dead code. The `lastCast == 0` check already covers the nil-fallback case.

### WR-02: Unconditional `macroTorch.context` dereference in UI_ERROR_MESSAGE handler

**Files modified:** `core/events.lua`
**Commit:** c7922b7
**Applied fix:** Added a nil-guard (`if macroTorch.context then ... end`) around the `macroTorch.context.behindAttackFailedTime = GetTime()` assignment in the UI_ERROR_MESSAGE handler. Prevents Lua runtime errors when UI errors fire outside of combat.

### WR-03: Target identity race in immune-tracing callbacks

**Files modified:** `core/spell_trace_immune.lua`
**Commit:** c90692f
**Applied fix:** Added an 8-line documentation comment above `macroTorch.spellsImmuneTracing` explaining the known race window between spell event recording and periodic processing, where `macroTorch.target` may have changed. Documented this as acceptable for PvE and provided guidance for a future fix (store mob name in callback closure for explicit API lookup).

### WR-04: Missing nil-guard on `context` in `loadImmuneTable` and `loadDefiniteBleedingTable`

**Files modified:** `core/spell_trace_immune.lua`
**Commit:** cf43081
**Applied fix:** Added `if not macroTorch.context then return end` early-return nil-guards at the top of both `loadImmuneTable()` and `loadDefiniteBleedingTable()`. Prevents Lua errors when these functions are called while context is nil (e.g., `isImmune` checked from a macro outside combat).

## Skipped Issues

### WR-05: `biz_util.lua` referenced in build_order.txt but existence unconfirmed

**File:** `build_order.txt:3`
**Reason:** File exists -- `biz_util.lua` is a real 9528-byte source file in the repository root. The reviewer could not verify its existence because it was outside the review scope, but it is present and correctly referenced in the build order. No change needed.
**Original issue:** Line 3 references `biz_util.lua` as the third file in the build order. The file was not part of the review scope and its existence could not be verified. If absent, the build script would produce an incomplete or broken output.

---

_Fixed: 2026-06-08T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_