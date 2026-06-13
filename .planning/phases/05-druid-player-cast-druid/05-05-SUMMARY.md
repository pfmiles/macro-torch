---
phase: 05-druid-player-cast-druid
plan: 05
subsystem: druid
tags: [lua, wow-addon, druid, spell-refactoring, skill-methods]

# Dependency graph
requires:
  - phase: 05-02
    provides: "Druid.lua skill method definitions (all 12 methods used by utility.lua)"
provides:
  - "utility.lua: all 13 player.cast() calls replaced with skill method calls"
  - "druidBuffs: mark_of_the_wild(nil, true), thorns(nil, true), natures_grasp()"
  - "druidStun: dire_bear_form(), reshift(), bash(), feral_charge()"
  - "druidDefend: barkskin('raw'), dire_bear_form(), enrage(), frenzied_regeneration()"
  - "druidControl: hibernate(), entangling_roots()"
affects: [D-01-utility-complete]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Barkskin 'raw' mode: when external isSpellReady check uses different spell name variant ('Barkskin (Feral)'), use raw mode to bypass _castSpell internal check"
    - "Type B self-buff methods (natures_grasp) called without onSelf parameter (hardcoded to true)"

key-files:
  modified:
    - "classes/druid/utility.lua - Druid utility functions (druidBuffs, druidStun, druidDefend, druidControl)"

key-decisions:
  - "Barkskin uses 'raw' mode because external isSpellReady('Barkskin (Feral)') check differs from skill method locale table name 'Barkskin'"
  - "Nature's Grasp called as natures_grasp() without onSelf param — Type B skill method has onSelf hardcoded to true"
  - "All utility calls use default nil mode (ready-check only) — utility functions have their own external pre-checks (form, rage, isSpellReady)"

patterns-established:
  - "Type B self-buffing skills: call without onSelf arg (implied by method signature)"
  - "Barkskin pattern: external isSpellReady + raw mode for name variant mismatch"
  - "Utility function pattern: nil (default) mode since callers handle all pre-checks"

requirements-completed: [R8, D-01, D-03, D-07]

# Metrics
duration: 4min
completed: 2026-06-13
---

# Phase 05 Plan 05: Utility.lua Skill Method Migration

**Replaced all 13 player.cast() calls in classes/druid/utility.lua with typed skill method calls, completing the D-01 full replacement in the utility module.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-13T04:47:04Z
- **Completed:** 2026-06-13
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- druidBuffs: 3 calls migrated (mark_of_the_wild, thorns, natures_grasp) — Type C with onSelf + Type B implicit
- druidStun: 4 calls migrated (dire_bear_form, reshift, bash, feral_charge) — Type B + Type A
- druidDefend: 4 calls migrated (barkskin('raw'), dire_bear_form, enrage, frenzied_regeneration) — Type B, Barkskin special-cased
- druidControl: 2 calls migrated (hibernate, entangling_roots) — Type A
- Removed unused `local clickContext = {}` from druidBuffs

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace player.cast calls in druidBuffs** - `4b3300f` (feat)
2. **Task 2: Replace all 10 player.cast calls in druidStun, druidDefend, druidControl** - `453c55c` (feat)

## Files Created/Modified
- `classes/druid/utility.lua` - All 13 player.cast() calls replaced with skill method calls, 0 remain

## Decisions Made
- **Barkskin 'raw' mode**: The external `isSpellReady('Barkskin (Feral)')` check uses a different spell name variant than the skill method's locale table (`{en='Barkskin'}`). Using 'raw' mode bypasses `_castSpell`'s internal `isSpellReady` check, avoiding potential name mismatch failures.
- **Nature's Grasp call pattern**: Called as `natures_grasp()` without onSelf parameter. This is a Type B skill method where onSelf is hardcoded to true in Druid.lua. No parameter needed.
- **All utility calls use nil (default) mode**: The utility functions already have their own external pre-checks (form detection, rage/mana checks, isSpellReady calls). Using nil mode provides the _castSpell ready check as an additional safety net without duplicating checks.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All utility.lua player.cast() calls migrated
- D-01 requirement fully satisfied for the utility module
- Phase 5 Druid skill method migration complete across all 3 wave files

---
*Phase: 05-druid-player-cast-druid*
*Completed: 2026-06-13*