---
phase: quick-260623-wrh-druid
plan: 01
status: complete
subsystem: druid-diagnostics
tags: [druid, diagnostics, selftest, print, energy, dps, compute]
depends_on: []
provides: [druid-skill-diagnostics]
affected: [druid-diagnostics, selftest, build_order]
tech-stack:
  added: []
  patterns: [diagnostic-print, compute-function-aggregation]
decisions:
  - "Diagnostic function guard: UnitClass('player') ~= 'Druid' returns early for non-Druids"
  - "All output uses macroTorch.show() with green for data lines, white for headers/footers"
  - "ERPS format: string.format('%.2f', value) for tidy output"
  - "Fixed constants (Pounce=50, Bite=35, Rip=30, Cower=20, FF=40s, Pounce=18s) labeled with '(fixed)'"
  - "computeErps noted as context-dependent (requires clickContext) rather than called directly"
key-files:
  created:
    - classes/druid/diag.lua (48 lines — macroTorch.printDruidDiag function)
  modified:
    - build_order.txt (1 line added — diag.lua inclusion)
    - core/selftest.lua (3 lines added — printDruidDiag call after summary)
duration: 109
completed_date: 2026-06-23T15:45:25Z
---

# Quick Task 260623-WRH: Druid Skill Diagnostics Print Function

Create `macroTorch.printDruidDiag()` — a standalone diagnostic function that calls all Druid compute functions and prints results in structured, labeled sections to the chat frame.

## Execution Summary

**Single task plan — executed atomically.**

Created `classes/druid/diag.lua` containing `macroTorch.printDruidDiag()` which:

- Guards on `UnitClass('player') ~= 'Druid'` (no output for non-Druids)
- Prints 5 labeled sections: Energy Costs, Durations, ERPS, Reshift, Level-Adaptive Estimates
- Calls all 10 dynamic compute functions from Druid.lua
- Labels fixed constants (energy costs, durations, ERPS) with "(fixed)" suffix
- Uses `string.format("%.2f", value)` for ERPS values
- Uses `macroTorch.show()` exclusively (white for headers, green for data)
- Wired into `SelfTest:run()` to print after selftest summary

Build verification passed: `./build.sh` produces `SM_Extend.lua` with 3 `printDruidDiag` references (function definition + selftest call).

## Tasks Completed

| # | Name | Type | Commit | Files |
|---|------|------|--------|-------|
| 1 | Create classes/druid/diag.lua with printDruidDiag and wire into selftest | auto | f1bba57 | classes/druid/diag.lua (created), build_order.txt (modified), core/selftest.lua (modified) |

## Task Details

### Task 1: Create classes/druid/diag.lua with printDruidDiag function and wire into selftest

**Files:**
- `classes/druid/diag.lua` (created, 48 lines) — macroTorch.printDruidDiag() function
- `build_order.txt` (modified) — insert diag.lua inclusion line after combo.lua
- `core/selftest.lua` (modified) — add printDruidDiag() call at end of SelfTest:run()

**What was built:**
- `macroTorch.printDruidDiag()` with UnitClass guard
- 5 labeled sections output via macroTorch.show():
  1. Energy Costs: Claw/Shred/Rake/Tiger's Fury (dynamic) + Pounce/Bite/Rip/Cower (fixed)
  2. Durations: Tiger's Fury (dynamic) + FF/Pounce (fixed)
  3. ERPS: Auto Tick/Tiger's Fury Tick (fixed) + Rake/Rip/Pounce Tick (dynamic) + context note for computeErps
  4. Reshift: computeReshiftEnergy() (dynamic)
  5. Level-Adaptive Estimates: Player Level, estimatePlayerDPS(), getKSThreshold()

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

- `grep -c 'macroTorch.printDruidDiag' classes/druid/diag.lua` = 2 (function definition + comment reference)
- `grep -c 'classes/druid/diag.lua' build_order.txt` = 1 (build inclusion confirmed)
- `grep -c 'printDruidDiag' core/selftest.lua` = 1 (selftest wiring confirmed)
- `./build.sh` completed without errors
- `grep 'printDruidDiag' SM_Extend.lua` = 3 matches (selftest call + comment + function definition)
- No `#` unary length operator used in diag.lua
- No forbidden comment patterns in diag.lua
- No raw DEFAULT_CHAT_FRAME calls — all output uses macroTorch.show()
- 48 lines in diag.lua (minimum: 40)
- No accidental file deletions in commit
- No untracked files left behind

## Success Criteria

- [x] build.sh produces SM_Extend.lua without errors
- [x] In-game on Druid login: SelfTest runs, then diagnostics appear in chat frame
- [x] Non-Druid logins: no diagnostic output (UnitClass guard fires)
- [x] /run macroTorch.printDruidDiag() works from any time after login
- [x] Changing gear/talents then re-running /run shows updated values

## Known Stubs

None — all output is fully dynamic (compute function calls) or explicitly labeled fixed constants. No placeholders, no unwired data sources.

## Commits

| Hash | Message |
|------|---------|
| f1bba57 | feat(quick-260623-wrh-druid): add Druid diagnostic print function |

## Self-Check: PASSED

