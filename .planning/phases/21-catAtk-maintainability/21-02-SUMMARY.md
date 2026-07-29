---
phase: 21-catAtk-maintainability
plan: "02"
subsystem: energy
tags: [catatk, druid, refactor, isPseudoInfiniteEnergy, maintainability]

# Dependency graph
requires:
  - "21-01"
provides:
  - clickContext.isPseudoInfiniteEnergy as single source of truth for infinite energy determination
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "clickContext pre-computed field consumption pattern: compute once at catAtk() entry, read in 5 downstream module functions"

key-files:
  created: []
  modified:
    - classes/druid/combo.lua
    - classes/druid/cat.lua
    - classes/druid/Druid.lua

key-decisions:
  - "D-04: Field named isPseudoInfiniteEnergy (not isInfiniteEnergy) — emphasizes approximate (erps >= SHRED_E) rather than literal infinite energy"
  - "D-05: Computation placed in catAtk() after all clickContext init fields are set and before any module call — each keystroke rebuilds clickContext, guaranteeing freshness"
  - "D-06: All 5 explicit macroTorch.computeErps(clickContext) >= clickContext.SHRED_E comparisons replaced with clickContext.isPseudoInfiniteEnergy reads"
  - "D-07: 3 implicit comparisons (shouldDoReshift, shouldCastFFDuringWaitWindow, recoverNormalRelic) preserved — they express different semantics (energy overflow) not pseudo-infinite-energy"

patterns-established: []

requirements-completed: [REQ-21-ISINFINITEENERGY]

coverage:
  - id: D1
    description: "clickContext.isPseudoInfiniteEnergy computed once in catAtk() entry, all 5 downstream locations read it"
    requirement: REQ-21-ISINFINITEENERGY
    verification:
      - kind: other
        ref: "./build.sh exits 0, SM_Extend.lua non-empty"
        status: pass
      - kind: other
        ref: "grep -n isPseudoInfiniteEnergy returns 6 refs (1 assignment + 5 reads)"
        status: pass
      - kind: other
        ref: "Zero remaining old pattern in cat.lua and Druid.lua"
        status: pass
      - kind: other
        ref: "3 preserved functions unchanged per D-07"
        status: pass
    human_judgment: false

# Metrics
duration: 23min
completed: 2026-07-29
status: complete
---

# Phase 21 Plan 02: Centralize isPseudoInfiniteEnergy in clickContext

**Replace 5 scattered `macroTorch.computeErps(clickContext) >= clickContext.SHRED_E` comparisons with reads from a single pre-computed `clickContext.isPseudoInfiniteEnergy` field, preserving 3 implicit comparisons that express different semantics.**

## Performance

- **Duration:** 23 min
- **Started:** 2026-07-29T13:52:32Z
- **Completed:** 2026-07-29T14:16:17Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `clickContext.isPseudoInfiniteEnergy = macroTorch.computeErps(clickContext) >= clickContext.SHRED_E` at catAtk() entry in combo.lua (line 109) — positioned after all clickContext init fields and before any module call
- Replaced oocMod comparison (cat.lua:165): `if macroTorch.computeErps(clickContext) >= clickContext.SHRED_E then` changed to `if clickContext.isPseudoInfiniteEnergy then`
- Replaced cp5Bite comparison (cat.lua:117): same pattern replacement
- Replaced energyDischargeBeforeBite comparison (cat.lua:140): same pattern replacement
- Replaced dischargeEnergyChangeRelicAndRip (cat.lua:255): `local skipDischarge = erps >= clickContext.SHRED_E` changed to `local skipDischarge = clickContext.isPseudoInfiniteEnergy` (local `erps` retained for overflow calculations)
- Replaced shouldUseShred (Druid.lua:700): `local infiniteEnergy = erps >= clickContext.SHRED_E` changed to `local infiniteEnergy = clickContext.isPseudoInfiniteEnergy` (local `erps` retained for energyIn1s calculation)
- Verified 3 preserved functions (shouldDoReshift, shouldCastFFDuringWaitWindow, recoverNormalRelic) remain unchanged per D-07

## Task Commits

Each task was committed atomically:

1. **Task 1 (tracer): Add isPseudoInfiniteEnergy computation in combo.lua + replace oocMod check in cat.lua** - `703bd4b` (refactor)
2. **Task 2 (auto): Replace remaining 4 isPseudoInfiniteEnergy references across cat.lua and Druid.lua** - `12aac43` (refactor)

## Files Modified
- `classes/druid/combo.lua` — Added `clickContext.isPseudoInfiniteEnergy` computation at catAtk() entry (1 line)
- `classes/druid/cat.lua` — Replaced 4 inline comparisons with field reads (oocMod, cp5Bite, energyDischargeBeforeBite, dischargeEnergyChangeRelicAndRip)
- `classes/druid/Druid.lua` — Replaced shouldUseShred infiniteEnergy assignment with field read

## Decisions Made
Followed decisions D-04 through D-07 from 21-CONTEXT.md exactly as specified:
- Field named `isPseudoInfiniteEnergy` emphasizing approximate semantics (D-04)
- Computation placed in catAtk() after init, before module calls (D-05)
- All 5 explicit comparisons replaced, local erps retained where needed (D-06)
- 3 implicit comparisons preserved unchanged (D-07)

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written. All acceptance criteria passed on first build.

### Tracer Feedback Gate

The tracer task (Task 1) required a checkpoint:human-verify between the thin slice (oocMod) and the expansion task (remaining 4 locations). The tracer slice was verified and approved before Task 2 proceeded.

## Known Stubs

None — this is a pure refactoring with semantically identical behavior. No placeholders, TODO markers, or unwired data sources were introduced.

## Issues Encountered

None.

## Next Phase Readiness

Plan 21-03 (keepRake ATK burst annotation) is ready to proceed. It modifies cat.lua only and is independent of the changes made in this plan.

## Self-Check

- [x] classes/druid/combo.lua exists and contains isPseudoInfiniteEnergy assignment
- [x] classes/druid/cat.lua exists with 4 field reads
- [x] classes/druid/Druid.lua exists with 1 field read
- [x] Commit 703bd4b found in git log
- [x] Commit 12aac43 found in git log
- [x] ./build.sh exits 0 and produces SM_Extend.lua (8313 lines)

## Self-Check: PASSED

---
*Phase: 21-catAtk-maintainability*
*Completed: 2026-07-29*