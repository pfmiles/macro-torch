---
phase: quick-260707-x3d
plan: 01
subsystem: druid-leveling
tags: [bugfix, ooc, catLeveling, combo-points, guard-condition]
requires: []
provides: [M8 Builder OOC at 5 CP]
affects: [classes/druid/leveling.lua]
tech-stack:
  added: []
  patterns: [guard-condition-expansion]
key-files:
  created: []
  modified:
    - classes/druid/leveling.lua
decisions:
  - "Expand M8 Builder outer guard from `comboPoints < 5` to `comboPoints < 5 or clickContext.ooc` to eliminate OOC + 5 CP dead zone"
metrics:
  duration: 71
  completed_date: "2026-07-07"
status: complete
---

# Quick Task 260707-x3d: Fix catLeveling OOC + 5 CP Dead Zone

**One-liner:** Fix a dead zone in `catLeveling()` where Omen of Clarity procs with 5 combo points resulted in no skill being cast, by expanding the M8 Builder module outer guard to allow entry when OOC is active.

## Overview

When OOC (Omen of Clarity) is active and combo points are at 5, `catLeveling()` was stuck in a dead zone: M5 Rip, M6 Rake, and M7 Bite all skip due to their `not ooc` guards, while M8 Builder was blocked by its `comboPoints < 5` guard. No module executed, wasting the OOC proc.

## Changes

### Task: Fix M8 Builder outer guard to allow OOC entry at 5 CP

**Commit:** `045436b`

**Change:** Single-line guard condition expansion in `classes/druid/leveling.lua` line 180:

```lua
-- Before:
if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 then

-- After:
if macroTorch.isFightStarted(clickContext) and (clickContext.comboPoints < 5 or clickContext.ooc) then
```

**Rationale:**
- M5 Rip: guarded by `not ooc` — correct, don't waste OOC on a finisher
- M6 Rake: guarded by `not ooc` — correct, don't waste OOC on a refresh
- M7 Bite: guarded by `not ooc` — correct, don't waste OOC on a finisher
- M8 Builder: was guarded by `comboPoints < 5` only — BUG: blocks OOC at 5 CP
- M9 FF: guarded by `not ooc or not inCombat` — correct, FF is lowest priority

The inner OOC branch (lines 199-209) already uses `shred('ready')` / `claw('ready')` with no energy check — it needed no change. This fix only expands the entry gate.

## Verification

### Automated
```
grep -n "comboPoints < 5" classes/druid/leveling.lua
158: and clickContext.comboPoints < 5 then        # M6 Rake (unchanged, still guarded by not ooc)
180: if ... and (clickContext.comboPoints < 5 or clickContext.ooc) then  # M8 Builder FIXED
```

### Manual Scenario: OOC + 5 CP
- OOC active, CP = 5, target has Rip, in combat
- M5 Rip: skipped (OOC active via `not ooc` guard)
- M6 Rake: skipped (OOC active via `not ooc` guard + `comboPoints < 5` fails)
- M7 Bite: skipped (OOC active via `not ooc` guard)
- M8 Builder: **ENTERS** (previously blocked) -> OOC branch -> `shred('ready')` or `claw('ready')`
- M9 FF: skipped (OOC active and in combat)
- Result: free Shred/Claw cast, OOC proc used

### Build
`./build.sh` exits 0 — no syntax errors introduced.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- [x] Modified file exists: `classes/druid/leveling.lua`
- [x] Commit exists: `045436b fix(quick-260707-x3d): fix catLeveling OOC + 5 CP dead zone where no skill was cast`
- [x] Build passes: `./build.sh` exit 0