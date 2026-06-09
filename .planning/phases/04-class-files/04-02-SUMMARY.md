---
phase: 04-class-files
plan: 02
subsystem: classes
tags: [lua, git-mv, class-migration, hunter, metatable]

requires:
  - phase: 04-class-files
    plan: 01
    provides: "classes/ directory structure, classes/druid/ subdirectory"
provides:
  - "6 non-Druid class files in classes/ directory with preserved git history"
  - "Hunter.lua with TODO marker for future metatable migration"
affects: [04-class-files-03, build-system]

tech-stack:
  added: []
  patterns:
    - "git mv preserves git history for file renames"

key-files:
  created:
    - classes/Hunter.lua
    - classes/Mage.lua
    - classes/Priest.lua
    - classes/Rogue.lua
    - classes/Warlock.lua
    - classes/Warrior.lua
  modified:
    - classes/Hunter.lua

key-decisions:
  - "Git mv used over plain mv to preserve file history per PATTERNS.md D-04"
  - "SM_Extend_Druid.lua intentionally preserved at root for Plan 03 build system finalization"

requirements-completed:
  - R6
  - R8

duration: 2min
completed: 2026-06-09
---

# Phase 4 Plan 2: Non-Druid Class File Migration Summary

**6 non-Druid SM_Extend_*.lua files migrated to classes/ via git mv; Hunter.lua annotated with TODO for future metatable migration**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-09T04:25:01Z
- **Completed:** 2026-06-09T04:26:33Z
- **Tasks:** 2
- **Files modified:** 7 (6 moved, 1 edited)

## Accomplishments
- Migrated Hunter, Mage, Priest, Rogue, Warlock, and Warrior files to classes/ directory via git mv
- Git rename tracking preserves full file history for all 6 files
- Added `-- TODO(Phase-N): migrate to macroTorch.classMetatable` above Hunter's hand-written metatable
- SM_Extend_Druid.lua intentionally preserved at root for Plan 03 (build system finalization)
- All 5 non-Druid, non-Hunter files are exact copies with zero content changes

## Task Commits

1. **Task 1: git mv 6 non-Druid files to classes/ directory** - `f2afc2f` (feat)
2. **Task 2: Add TODO comment to classes/Hunter.lua** - `bf06487` (feat)

## Files Created/Modified
- `classes/Hunter.lua` - Hunter class (git mv + TODO comment added at line 33)
- `classes/Mage.lua` - Mage class (git mv, no content changes)
- `classes/Priest.lua` - Priest class (git mv, no content changes)
- `classes/Rogue.lua` - Rogue class (git mv, no content changes)
- `classes/Warlock.lua` - Warlock class (git mv, no content changes)
- `classes/Warrior.lua` - Warrior class (git mv, no content changes)

## Decisions Made
- None beyond plan specification. Followed plan exactly: git mv for history preservation, single-comment TODO for Hunter metatable.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## Known Stubs
- `classes/Hunter.lua` line 33: `-- TODO(Phase-N): migrate to macroTorch.classMetatable` - Intentional marker for future metatable refactoring. This is the only Hunter-specific change per D-04.

## Threat Flags
None. This plan performs only file relocation (git mv) and a single comment-line addition. No new code surface, network endpoints, or auth paths introduced.

## Next Phase Readiness
- All 6 non-Druid class files are now in classes/ directory
- SM_Extend_Druid.lua remains at root, ready for Plan 03 (Druid split + build system finalization)
- Hunter TODO comment marks the metatable for future migration to macroTorch.classMetatable factory

---
*Phase: 04-class-files*
*Completed: 2026-06-09*