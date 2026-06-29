---
phase: 17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr
plan: 01
status: complete
tags: [infrastructure, spell-tracing, druid, spellid-map, prowling-guard]
requires: []
provides:
  - SPELL_NAME_TO_ID
  - resolveSpellId
  - loadSpellIdMap
affects:
  - SpellTrace:register
  - catLeveling FF module
tech-stack:
  added: []
  patterns:
    - "Flat dual-key name-to-spellId table (SPELL_NAME_TO_ID)"
    - "SavedVariable reference binding (SM_EXTEND.spellIdMap → loginContext.spellIdMap)"
    - "SpellId resolution chain: runtime correction > static baseline"
    - "Prowling guard pattern: not player.isProwling before ability cast"
key-files:
  created:
    - core/spell_id_map.lua
  modified:
    - build_order.txt
    - core/spell_trace_core.lua
    - classes/druid/leveling.lua
    - core/spell_trace_immune.lua
    - core/combat_context.lua
decisions:
  - "D-02: Flat dual-key table for spellName → spellId (EN + ZH keys pointing to same Global Spell ID)"
  - "D-03/D-04: SM_EXTEND.spellIdMap[playerCls] persistence, loaded in onPlayerEnteringWorld via loadSpellIdMap()"
  - "D-10: SpellTrace:register extends config with spellName field, resolveSpellId chain, config.spellId retained as legacy fallback"
  - "D-01: FF prowling guard — not player.isProwling condition in catLeveling Module 9"
  - "D-11: 60-level static baseline: Pounce=9827, Rake=1822, Rip=9492, Ferocious Bite=22557 (with Chinese locale names verified from Druid.lua)"
metrics:
  task_count: 3
  file_count: 6
  duration_seconds: 192
  completed_date: "2026-06-29"
  completed: "2026-06-29T10:43:00Z"
---

# Phase 17 Plan 01: Global SpellId Mapping Infrastructure + FF Prowling Guard Summary

**One-liner:** Established `SPELL_NAME_TO_ID` static mapping table, `resolveSpellId()` name-to-spellId resolution chain, `loadSpellIdMap()` persistence layer, and added prowling guard to catLeveling FF module.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create core/spell_id_map.lua + insert into build_order.txt | `8b84479` | `core/spell_id_map.lua` (created), `build_order.txt` |
| 2 | FF prowling guard + resolveSpellId + SpellTrace:register spellName support | `c414e89` | `core/spell_trace_core.lua`, `classes/druid/leveling.lua` |
| 3 | loadSpellIdMap + onPlayerEnteringWorld integration | `7b26aa2` | `core/spell_trace_immune.lua`, `core/combat_context.lua` |

## Architecture Overview

### SpellId Resolution Chain

```
resolveSpellId(spellName)
  ├── loginContext.spellIdMap[spellName]  (runtime correction, persisted via SM_EXTEND)
  └── SPELL_NAME_TO_ID[spellName]         (static baseline, 60-level Turtle WoW)
```

### Data Flow

```
ADDON INIT (build_order.txt):
  core/spell_id_map.lua → SPELL_NAME_TO_ID table available
  core/spell_trace_core.lua → resolveSpellId() ready, SpellTrace:register supports spellName

PLAYER_ENTERING_WORLD:
  combat_context.lua: loadSpellIdMap()
    → SM_EXTEND.spellIdMap[playerCls] reference bound to loginContext.spellIdMap
    → Persisted corrections take effect

RUNTIME:
  _castSpell → current_casting_spell = spellName (set before cast)
  UNIT_CASTEVENT → resolveSpellId(current_casting_spell) vs event.spellId
    → If mismatch: persist correction to SM_EXTEND.spellIdMap, update tracingSpells key
```

### Key Deliverables

1. **`core/spell_id_map.lua`** — New file. Apache 2.0 header, direct table assignment `macroTorch.SPELL_NAME_TO_ID` with 8 entries: 4 English + 4 Chinese names mapping to 4 Global Spell IDs (Pounce/9827, Rake/1822, Rip/9492, Ferocious Bite/22557). Faerie Fire (Feral) intentionally excluded (land=false, immune tracing only).

2. **`macroTorch.resolveSpellId(spellName)`** — New function in `core/spell_trace_core.lua`. Two-stage resolution: checks `loginContext.spellIdMap` (runtime corrections) first, falls back to `SPELL_NAME_TO_ID` static baseline.

3. **`SpellTrace:register` extension** — Now supports `config.spellName` field. When `land=true` and `spellName` is present, resolves via `resolveSpellId()`. Falls back to `config.spellId` for backward compatibility. Both nil → red error message.

4. **`macroTorch.loadSpellIdMap()`** — New function in `core/spell_trace_immune.lua`. Follows `loadImmuneTable()` pattern identically. Binds `SM_EXTEND.spellIdMap[playerCls]` reference to `macroTorch.loginContext.spellIdMap` (session-scoped, NOT combat-scoped — corrections survive combat exit).

5. **FF Prowling Guard** — Added `not player.isProwling` condition to catLeveling Module 9 (FF). Module 9 is the last module, so falling through after the guard is safe — no subsequent modules are affected.

6. **`build_order.txt`** — `core/spell_id_map.lua` inserted after `core/combat_context.lua` and before `core/spell_trace_core.lua`, ensuring `SPELL_NAME_TO_ID` is available when `SpellTrace:register` runs.

## Verify

```bash
./build.sh
grep -c "SPELL_NAME_TO_ID" SM_Extend.lua      # >= 1
grep -c "function macroTorch.resolveSpellId" SM_Extend.lua  # >= 1
grep -c "function macroTorch.loadSpellIdMap" SM_Extend.lua  # >= 1
grep -c "not player.isProwling" SM_Extend.lua  # >= 1
```

## Deviations from Plan

None — plan executed exactly as written. All 3 tasks completed with no deviations.

## Decisions Made

- Used `texture_map.lua` pattern (no `if not ... then` guard) for `SPELL_NAME_TO_ID` assignment, consistent with existing data files
- `loadSpellIdMap()` uses `loginContext` (not `context`) binding target — spellId corrections must survive combat exit/re-entry
- Resolved spell names checked against actual `_castSpell` locale tables in Druid.lua to ensure correct Chinese names (突袭/斜掠/撕扯/凶猛撕咬)
- `resolveSpellId` placed between `SpellTrace = {}` and `SpellTrace:register` in spell_trace_core.lua for logical grouping with its primary consumer

## Known Stubs

None — all data wired, all functions fully implemented, all guard conditions connected.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or trust boundary crossings introduced.

## Self-Check: PASSED

- `core/spell_id_map.lua` exists
- `build_order.txt` has `core/spell_id_map.lua` at line 21 (between combat_context.lua and spell_trace_core.lua)
- `./build.sh` succeeds with all new symbols in `SM_Extend.lua`
- All 3 commits verified in git history: `8b84479`, `c414e89`, `7b26aa2`