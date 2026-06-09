---
phase: 04-class-files
fixed_at: 2026-06-09T00:00:00Z
review_path: .planning/phases/04-class-files/04-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-06-09
**Source review:** .planning/phases/04-class-files/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (2 Critical, 3 Warning)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01: Uninitialized global variable `n` in pickPocketBeforeCast

**Files modified:** `classes/Rogue.lua`
**Commit:** `145ddb2`
**Applied fix:** Namespaced the uninitialized global variable `n` to `macroTorch.pickPocketState`. The function now initializes `n` via `local n = macroTorch.pickPocketState or 0` and writes back to `macroTorch.pickPocketState` instead of the bare global `n`. This prevents state leakage across macro invocations.

### CR-02: build.sh uses bash-specific `[[ ]]` with `#!/bin/sh`

**Files modified:** `build.sh`
**Commit:** `3b8b3a6`
**Applied fix:** Replaced `[[ "$OSTYPE" == "cygwin" ]]` with POSIX-compatible `[ "$OSTYPE" = "cygwin" ]`. Shell syntax check (`sh -n`) confirmed no regressions.

### WR-01: Hunter.lua hand-written metatable

**Files modified:** `classes/Hunter.lua`
**Commit:** `3237a7d`
**Applied fix:** Replaced the 13-line hand-written `__index` metatable with the unified `macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP")` factory call. Removed the `TODO(Phase-N)` comment since the migration is now complete. The factory provides the same two-step lookup (field map then class fallback) with the added nil-guard benefit.

### WR-02: Dead nil-check in computeNormalRelic

**Files modified:** `classes/druid/Druid.lua`
**Commit:** `d199768`
**Applied fix:** Removed the unreachable `if not macroTorch.player then return 'Idol of Savagery' end` guard. `macroTorch.player` is always initialized at Player.lua:518 and reassigned on every `PLAYER_ENTERING_WORLD` event, so this nil-check can never trigger in normal operation.

### WR-03: `reapLine` unused parameter in Mage.lua

**Files modified:** `classes/Mage.lua`
**Commit:** `b67b4d6`
**Applied fix:** Renamed the unused `reapLine` parameter to `_reapLine` (Lua convention for intentionally unused parameters) in both `mageRangedAtk` and `mageMeleeAtk`. The parameter is kept in the function signature to maintain API consistency with the caller `mageAtk` and sibling classes (Warrior, Warlock) that use the same call pattern.

---

_Fixed: 2026-06-09T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_