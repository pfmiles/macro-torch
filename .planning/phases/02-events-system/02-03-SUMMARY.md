---
phase: 02-events-system
plan: 03
subsystem: build
tags: [build_order, phase2-cleanup, battle_event_queue-removal]

# Dependency graph
requires:
  - phase: 02-events-system
    plan: 01
    provides: "core/combat_context.lua, core/spell_trace_core.lua"
  - phase: 02-events-system
    plan: 02
    provides: "core/spell_trace_immune.lua, core/events.lua"
provides:
  - "Updated build_order.txt with Phase 2 split reflected (battle_event_queue.lua removed, spell_trace split into two files)"
  - "Deleted battle_event_queue.lua source file (all 23 functions migrated to 4 new core/ modules)"
  - "Verified build.sh produces correct SM_Extend.lua with all migrated symbols"
affects: [03-selftest-spelltrace, 04-class-reorg-build-system]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "build_order.txt D-05 ordering: core/periodic -> combat_context -> spell_trace_core -> spell_trace_immune -> events"

key-files:
  modified:
    - "build_order.txt"
  deleted:
    - "battle_event_queue.lua"

key-decisions:
  - "Phase 2 completion confirmed: all 4 core/ modules exist and build correctly"
  - "build_order.txt D-05 order verified: periodic(6) -> combat_context(20) -> spell_trace_core(21) -> spell_trace_immune(22) -> events(23)"

patterns-established:
  - "D-05: core module loading order must respect dependency chain (periodic before combat_context before spell_trace before events)"

requirements-completed: [R3, R6]

# Metrics
duration: 5min
completed: 2026-06-08
---

# Phase 02 Plan 03: Build System Cleanup Summary

**Updated build_order.txt to reflect Phase 2 split, removed battle_event_queue.lua source file, verified build produces correct output**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-08T05:30:00Z
- **Completed:** 2026-06-08T05:35:00Z
- **Tasks:** 1
- **Files modified:** 1 (build_order.txt)
- **Files deleted:** 1 (battle_event_queue.lua)

## Accomplishments
- Removed `battle_event_queue.lua` entry and its comment from build_order.txt (lines 17-18)
- Replaced `core/spell_trace.lua` with `core/spell_trace_core.lua` + `core/spell_trace_immune.lua` at lines 21-22
- Reordered core/ files to match D-05: periodic -> combat_context -> spell_trace_core -> spell_trace_immune -> events
- Deleted `battle_event_queue.lua` (472 lines, all 23 functions migrated to 4 new core/ modules in plans 02-01 and 02-02)
- Verified `./build.sh` succeeds and SM_Extend.lua contains all key symbols

## Task Commits

1. **Task 1: Update build_order.txt and delete battle_event_queue.lua** - `83f1a65` (chore)

## Files Created/Modified
- `build_order.txt` - Removed battle_event_queue.lua entry (line 18) and comment (line 17); replaced core/spell_trace.lua with spell_trace_core.lua + spell_trace_immune.lua; reordered core/ files per D-05

## Files Deleted
- `battle_event_queue.lua` - All 23 macroTorch.* functions migrated to core/events.lua, core/combat_context.lua, core/spell_trace_core.lua, core/spell_trace_immune.lua

## Build Verification
- `./build.sh` executed successfully, SM_Extend.lua generated
- Key symbols confirmed present:
  - `function macroTorch.eventHandle` (core/events.lua)
  - `function macroTorch.CheckDodgeParryBlockResist` (core/spell_trace_core.lua)
  - `function macroTorch.loadImmuneTable` (core/spell_trace_immune.lua)
  - `function macroTorch.onCombatExit` (core/combat_context.lua)
  - `function macroTorch.onCombatEnter` (core/combat_context.lua)
  - `function macroTorch.onPlayerEnteringWorld` (core/combat_context.lua)
- All 4 core/ modules within 250-line constraint: events=115, combat_context=39, spell_trace_core=250, spell_trace_immune=93

## Decisions Made
- None — followed plan as specified

## Deviations from Plan
None — plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Phase 2 complete: all 4 core/ modules extracted from battle_event_queue.lua, old file deleted, build system updated
- Ready for Phase 3: selftest + spell_trace configuration
- All core/ files follow D-05 loading order constraint

---
*Phase: 02-events-system Plan: 03*
*Completed: 2026-06-08*