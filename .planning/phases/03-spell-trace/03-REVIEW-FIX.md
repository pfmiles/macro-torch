---
phase: 03-spell-trace
fixed_at: 2026-06-09T00:00:00Z
review_path: .planning/phases/03-spell-trace/03-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-06-09
**Source review:** .planning/phases/03-spell-trace/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### WR-01: `events.lua:42` references `SUPERWOW_STRING` without `nil` guard

**Files modified:** `core/events.lua`
**Commit:** ca00432
**Applied fix:** Changed `if SUPERWOW_STRING then` to `if SUPERWOW_STRING ~= nil then` to prevent Lua nil-index error when the SuperWoW addon is not installed.

### WR-02: Self-test `CLAW_E` / `SHRED_E` / `RAKE_E` reference bare globals that do not exist

**Files modified:** `SM_Extend_Druid.lua`
**Commit:** 4ab4897
**Applied fix:** Replaced bare global references to `CLAW_E`, `SHRED_E`, `RAKE_E` in self-test F3 assertions with calls to `computeClaw_E()`, `computeShred_E()`, and `computeRake_E()` respectively.

### WR-03: `computeRake_Erps()` and `computeRip_Erps()` use stale tick intervals

**Files modified:** `SM_Extend_Druid.lua`
**Commit:** 9a11d76
**Applied fix:** Moved Savagery snapshot flag writes in `safeRake` and `safeRip` from `macroTorch.context` to `macroTorch.loginContext`. Updated reads in `computeRake_Erps` and `computeRip_Erps` to use `macroTorch.loginContext` as well (`lastRipAtCp` remains in `macroTorch.context` as it is combat-scoped).

### WR-04: `ripLeft()` and `rakeLeft()` read context fields unconditionally

**Files modified:** `SM_Extend_Druid.lua`
**Commit:** d434657
**Applied fix:** Added nil guard for `macroTorch.context.lastRipAtCp` in `ripLeft()` (extract to local `cp` variable, only perform arithmetic if non-nil). Added nil guard for `macroTorch.loginContext.lastRakeEquippedSavagery` in `rakeLeft()` and `macroTorch.loginContext.lastRipEquippedSavagery` in `ripLeft()` (aligned with WR-03 migration to loginContext).

### WR-05: `SpellTrace:register()` does not validate `config.spellId`

**Files modified:** `core/spell_trace_core.lua`
**Commit:** 6fb44e8
**Applied fix:** Added validation check: when `config.land` is true but `config.spellId` is nil, log an error via `macroTorch.show()` and return early instead of silently storing a nil key.

### WR-06: `computeNormalRelic()` accesses `macroTorch.player` before guaranteed to exist

**Files modified:** `SM_Extend_Druid.lua`
**Commit:** eda6200
**Applied fix:** Added nil-guard at top of `computeNormalRelic()`: if `macroTorch.player` is nil, return default `'Idol of Savagery'` immediately.

---

_Fixed: 2026-06-09_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_