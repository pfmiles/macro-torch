---
phase: 02-events-system
plan: "01"
status: complete
tasks: 2/2
---

## Summary

Created Phase 2 foundation layer: `core/combat_context.lua` (combat state management) and `core/spell_trace_core.lua` (spell trace core data layer), extracting from `battle_event_queue.lua`.

### Task 1: core/combat_context.lua

- 3 functions: `onCombatExit()`, `onCombatEnter()`, `onPlayerEnteringWorld()`
- No WoW event global variable references
- ~36 lines with Apache 2.0 license header

### Task 2: core/spell_trace_core.lua

- 16 macroTorch.* functions migrated with exact signatures preserved
- DEBUFF_LAND_LAG constant, tracingSpells/traceSpellImmunes initialization
- `registerPeriodicTask('maintainLandTables', ...)` registration
- `spellsImmuneTracing`, `loadImmuneTable`, `loadDefiniteBleedingTable` excluded (in spell_trace_immune.lua)
- `eventHandle` excluded (in events.lua)
- 294 lines

### Key Files Created

- `core/combat_context.lua` — combat enter/exit state management + player entering world
- `core/spell_trace_core.lua` — spell trace table management + dodge/parry/block/resist detection

### Commits

- `ad416d7`: feat(02-events-system-01): create core/combat_context.lua
- `c06b6a9`: feat(02-events-system): create core/spell_trace_core.lua

## Self-Check: PASSED