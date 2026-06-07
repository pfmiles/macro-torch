---
phase: 01-classmetatable-entity
plan: 05
subsystem: entity
tags: [lua, classMetatable, entity-migration, metatable-refactor]

# Dependency graph
requires:
  - phase: 01-classmetatable-entity
    plan: 01
    provides: macroTorch.classMetatable factory in core/class.lua
provides:
  - entity/Pet.lua with classMetatable(self, "PET_FIELD_FUNC_MAP")
  - entity/TargetTarget.lua with classMetatable(self, nil)
  - entity/TargetPet.lua with classMetatable(self, nil)
  - entity/PetTarget.lua with classMetatable(self, nil)
  - entity/Group.lua (empty shell, unchanged content)
  - entity/Raid.lua (empty shell, unchanged content)
affects: [02-event-system-split, 03-config-spell-trace, 04-class-reorg-build]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "classMetatable(self, fieldMapName) replaces hand-written setmetatable+__index templates"
    - "classMetatable(self, nil) replaces setmetatable(obj, self) + self.__index = self pattern for subclasses without own FIELDMAP"

key-files:
  created:
    - entity/Pet.lua
    - entity/TargetTarget.lua
    - entity/TargetPet.lua
    - entity/PetTarget.lua
    - entity/Group.lua
    - entity/Raid.lua
  modified: []

key-decisions:
  - "classMetatable(self, nil) is semantically equivalent to setmetatable(obj, self) + self.__index = self for classes with no own FIELDMAP"
  - "Group.lua and Raid.lua are empty shells with no class or metatable — pure file moves, content unchanged"

patterns-established:
  - "All entity files now live in entity/ directory, metatables use classMetatable factory"

requirements-completed: [R1, R6]

# Metrics
duration: 3min
completed: 2026-06-08
---

# Phase 1 Plan 5: Entity Migration Wave 2 Summary

**Migrated 6 entity files to entity/ directory with unified classMetatable metatable pattern — Pet (FIELDMAP), TargetTarget/TargetPet/PetTarget (nil FIELDMAP), Group/Raid (empty shell)**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-06-08T00:09:00Z
- **Completed:** 2026-06-08T00:12:00Z
- **Tasks:** 3
- **Files created:** 6
- **Files deleted:** 6 (root originals)

## Accomplishments

- Pet.lua migrated to entity/Pet.lua with hand-written metatable replaced by classMetatable(self, "PET_FIELD_FUNC_MAP") — singleton, PET_FIELD_FUNC_MAP, and all instance methods preserved
- TargetTarget.lua migrated to entity/TargetTarget.lua with setmetatable(obj, self) + self.__index = self replaced by classMetatable(self, nil)
- TargetPet.lua, PetTarget.lua migrated with same classMetatable(self, nil) pattern replacement
- Group.lua and Raid.lua migrated as pure file moves — empty shell content unchanged
- All 6 root files deleted after migration

## Task Commits

Each task was committed atomically:

1. **Task 1: 迁移 Pet.lua to entity/Pet.lua，替换 metatable** - `4bdc9b0` (feat)
2. **Task 2: 迁移 TargetTarget.lua to entity/TargetTarget.lua，替换 setmetatable(obj, self) 模式** - `4859614` (feat)
3. **Task 3: 批量迁移 TargetPet, PetTarget, Group, Raid 到 entity/** - `23fa32b` (feat)

## Files Created/Modified

- `entity/Pet.lua` — Pet class with classMetatable(self, "PET_FIELD_FUNC_MAP"), PET_FIELD_FUNC_MAP, singleton macroTorch.pet
- `entity/TargetTarget.lua` — TargetTarget class with classMetatable(self, nil), inherits Unit metatable chain
- `entity/TargetPet.lua` — TargetPet class with classMetatable(self, nil)
- `entity/PetTarget.lua` — PetTarget class with classMetatable(self, nil)
- `entity/Group.lua` — Empty shell macroTorch.group = {}
- `entity/Raid.lua` — Empty shell macroTorch.raid = {}

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

All 6 entity files from wave 2 are in entity/ directory with unified classMetatable pattern. This completes the entity/ migration for all 9 entity files (3 from wave 1 + 6 from wave 2). Ready for Phase 2 event system split.

---
*Phase: 01-classmetatable-entity*
*Completed: 2026-06-08*