---
phase: 21-catAtk-maintainability
plan: "01"
subsystem: comments
tags: [catatk, druid, comments, killslot, maintainability]

# Dependency graph
requires: []
provides:
  - catAtk module call comments numbered continuously 0-12 matching execution order (combo.lua)
  - KillShot dual-entry design intent documented at oocMod/termMod call sites (combo.lua) and function heads (cat.lua)
affects: [21-02, 21-03]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - classes/druid/combo.lua
    - classes/druid/cat.lua

key-decisions:
  - "D-01: Fixed comment numbering from inverted 7/6 to correct 6/7 matching execution sequence 0-12 per catAtk-core-principles.md Rule 7 priority table"
  - "D-02: Added KillShot dual-entry design intent comments at oocMod/termMod call sites and function heads explaining OoC-priority-then-normal-GCD pattern"
  - "D-03: Combined Items 1 and 2 into single plan, executed as separate atomic commits per task type (tracer then auto)"

patterns-established: []

requirements-completed: [REQ-21-COMMENTS]

coverage:
  - id: D1
    description: "catAtk module call comments renumbered continuously 0-12 in combo.lua"
    requirement: REQ-21-COMMENTS
    verification:
      - kind: other
        ref: "grep -nE '^[[:space:]]*--[[:space:]]*[0-9]+\\.' classes/druid/combo.lua"
        status: pass
      - kind: other
        ref: "./build.sh exits 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "KillShot dual-entry design intent comments added to combo.lua call sites and cat.lua function heads"
    requirement: REQ-21-COMMENTS
    verification:
      - kind: other
        ref: "grep -c KillShot classes/druid/combo.lua classes/druid/cat.lua"
        status: pass
      - kind: other
        ref: "./build.sh exits 0 and KillShot comments survive concatenation in SM_Extend.lua"
        status: pass
    human_judgment: false

# Metrics
duration: 21min
completed: 2026-07-29
status: complete
---

# Phase 21 Plan 01: catAtk comment numbering fix and KillShot design intent comments

**Fix catAtk module call comment numbering continuity (7/6 swapped to 6/7, producing full 0-12 sequence) and document the KillShot dual-entry design intent across combo.lua and cat.lua call sites and function definitions.**

## Performance

- **Duration:** 21 min
- **Started:** 2026-07-29T13:31:11Z
- **Completed:** 2026-07-29T13:52:32Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed inverted comment numbering at oocMod (7->6) and termMod (6->7) call sites in catAtk main entry (combo.lua), producing continuous 0-12 numbering matching execution order
- Added KillShot design intent comments to oocMod call site explaining "OoC triggered free-skill KillShot/Bite" priority
- Added KillShot design intent comment to termMod call site documenting "KillShot > 5CP Bite, skip if OoC already consumed"
- Added termMod function head comment in cat.lua documenting "KillShot 斩杀优先 > 5CP Bite" termination logic
- Added oocMod function head comment in cat.lua documenting "Omen of Clarity free-skill strategy with KillShot priority"

## Task Commits

Each task was committed atomically:

1. **Task 1 (tracer): Fix catAtk comment numbering 7/6 swap to 6/7 in combo.lua** - `38980b1` (docs)
2. **Task 2 (auto): Add KillShot dual-entry design intent comments in combo.lua and cat.lua** - `85769df` (docs)

## Files Modified
- `classes/druid/combo.lua` - Fixed oocMod/termMod comment numbering (7/6 -> 6/7) and updated both call site comments with KillShot design intent
- `classes/druid/cat.lua` - Added function head comments above termMod and oocMod documenting KillShot dual-entry design

## Decisions Made
Followed decisions D-01, D-02, and D-03 from 21-CONTEXT.md exactly as specified:
- Comment numbering corrected to match catAtk-core-principles.md Rule 7 priority table
- KillShot dual-entry pattern documented at both call sites and function definitions
- Combined items into single plan with separate commits per task type

## Deviations from Plan
None - plan executed exactly as written. Both tasks are pure comment changes with zero behavior impact.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
Plan 21-02 (isPseudoInfiniteEnergy centralization) and 21-03 (keepRake ATK burst annotation) are ready to proceed. Both operate on the same files (combo.lua, cat.lua, Druid.lua) and are independent of the comment changes made in this plan.

---
*Phase: 21-catAtk-maintainability*
*Completed: 2026-07-29*