---
phase: s1v-reshift-minabilitycost-nextabilitycost-r
plan: 01
status: complete
subsystem: Druid combat (reshift logic)
tags: [rename, refactor, log-enhancement, druid]
requires: []
provides:
  - getNextAbilityCost (semantic rename)
  - readyReshift earning log field
affects:
  - classes/druid/Druid.lua
  - classes/druid/cat.lua
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified:
    - classes/druid/Druid.lua
    - classes/druid/cat.lua
decisions:
  - "Renamed getMinimumAffordableAbilityCost -> getNextAbilityCost for semantic clarity at all call sites (3 in Druid.lua, 1 in cat.lua)"
  - "Renamed minAbilityCost local var/param -> nextAbilityCost in cat.lua reshift functions"
  - "Added 'earning' log field: RESHIFT_ENERGY - currentMana - TIGER_E to show net energy gain from reshift"
  - "Druid.lua:849 local minAbilityCost was NOT renamed (plan scope: cat.lua only)"
metrics:
  duration_seconds: ~120
  completed_date: 2026-07-25
---

# Quick Task 260725-s1v: Rename getMinimumAffordableAbilityCost → getNextAbilityCost + Reshift Log Enhancement

**One-liner:** Renamed `getMinimumAffordableAbilityCost` to `getNextAbilityCost` across all call sites, renamed `minAbilityCost` → `nextAbilityCost` in cat.lua reshift functions, and added `earning` field to reshift log for net energy gain visibility.

## Task Summary

| Task | Name | Status | Commit |
|------|------|--------|--------|
| 1 | Rename getMinimumAffordableAbilityCost → getNextAbilityCost; rename minAbilityCost → nextAbilityCost; add earning to reshift log | ✅ Complete | c371482 |

## Changes Made

### Druid.lua
- **Line 871:** `function macroTorch.getMinimumAffordableAbilityCost(...)` → `function macroTorch.getNextAbilityCost(...)`
- **Line 849:** `macroTorch.getMinimumAffordableAbilityCost(clickContext)` → `macroTorch.getNextAbilityCost(clickContext)` (Rule 2: missed call site from prior `shouldDoSiphonReshift`-like function)
- **Lines 1285-1297:** Selftest registration name, function call, and 4 assert messages all updated from `getMinimumAffordableAbilityCost` to `getNextAbilityCost`

### cat.lua
- **Line 190:** `minAbilityCost` → `nextAbilityCost` in reshiftMod local destructuring
- **Line 210:** `minAbilityCost` → `nextAbilityCost`, function call updated to `getNextAbilityCost`
- **Line 214:** Return statement: two `minAbilityCost` → `nextAbilityCost`
- **Line 325:** Function signature parameter: `minAbilityCost` → `nextAbilityCost`
- **Line 332:** Log field `nextMoveCost` → `nextAbilityCost`
- **Line 333:** Added `earning` field: `clickContext.RESHIFT_ENERGY - macroTorch.player.mana - clickContext.TIGER_E`

## Verification Results

| Check | Result |
|-------|--------|
| `grep 'getMinimumAffordableAbilityCost'` across both files | ✅ Zero hits |
| `grep 'minAbilityCost'` in cat.lua | ✅ Zero hits |
| `grep 'nextMoveCost'` in cat.lua | ✅ Zero hits |
| `grep 'getNextAbilityCost'` across both files | ✅ 8 hits (definition + 3 callers + 5 selftest refs) |
| `grep 'earning.*RESHIFT_ENERGY'` in cat.lua | ✅ earning field exists |
| `./build.sh` | ✅ Build passes |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Call Site] Renamed missed getMinimumAffordableAbilityCost call on Druid.lua:849**
- **Found during:** Task 1 verification
- **Issue:** Plan's context section identified line 871, 1285-1298 (Druid.lua) and cat.lua calls, but missed line 849 in Druid.lua which also called the old function name
- **Fix:** Updated `macroTorch.getMinimumAffordableAbilityCost(clickContext)` to `macroTorch.getNextAbilityCost(clickContext)`
- **Files modified:** `classes/druid/Druid.lua`
- **Commit:** c371482

None - plan executed exactly as written with one auto-fix.

## Self-Check: PASSED

- [x] `classes/druid/Druid.lua` modified and committed (c371482)
- [x] `classes/druid/cat.lua` modified and committed (c371482)
- [x] Commit c371482 exists in git log
- [x] SUMMARY.md written to disk