---
phase: 17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr
plan: 02
status: complete
tags: [integration, spellId-correction, current-casting-spell, druid-migration, selftest]
requires:
  - "17-01"
provides:
  - "current_casting_spell lifecycle"
  - "UNIT_CASTEVENT spellId dynamic correction"
  - "Druid SpellTrace:register spellName migration"
  - "Category K self-tests"
affects:
  - _castSpell
  - UNIT_CASTEVENT event handler
  - Druid spell tracing
tech-stack:
  added: []
  patterns:
    - "current_casting_spell bridge: _castSpell set -> UNIT_CASTEVENT check/clear"
    - "SM_EXTEND.spellIdMap lazy-init (same pattern as loadImmuneTable)"
    - "tracingSpells key migration on spellId correction (old key -> new key)"
    - "SpellTrace:register spellName -> resolveSpellId -> setSpellTracing(spellId)"
key-files:
  modified:
    - entity/Player.lua
    - core/events.lua
    - classes/druid/Druid.lua
    - core/selftest.lua
decisions:
  - "current_casting_spell set only when mode ~= 'ready' (availability checks do not cast)"
  - "current_casting_spell cleared only on CAST event match (FAILED/INTERRUPTED do not clear, as they don't generate CAST events)"
  - "SM_EXTEND.spellIdMap lazy-init uses loadImmuneTable pattern for consistency"
  - "loginContext.spellIdMap sync on correction (handles race condition with loadSpellIdMap timing)"
  - "tracingSpells key migration: new event spellId key gets old staticId's value, old key deleted"
  - "Faerie Fire (Feral) SpellTrace:register unchanged (land=false, no spellId/spellName needed)"
metrics:
  task_count: 2
  file_count: 4
  duration_seconds: 209
  completed_date: "2026-06-29"
  completed: "2026-06-29T10:54:20Z"
---

# Phase 17 Plan 02: current_casting_spell Lifecycle, spellId Dynamic Correction, Druid spellName Migration Summary

**One-liner:** Bridged _castSpell spellName to UNIT_CASTEVENT spellId via current_casting_spell variable, implemented runtime spellId correction with SM_EXTEND persistence and tracingSpells key migration, migrated 4 Druid land-tracing spells from hardcoded spellId to name-driven registration, and added 5 Category K self-tests.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | _castSpell current_casting_spell + UNIT_CASTEVENT correction + Druid migration | `5fd4ce5` | `entity/Player.lua`, `core/events.lua`, `classes/druid/Druid.lua` |
| 2 | Category K self-tests for spellId mapping system | `b2e24e0` | `core/selftest.lua` |

## Architecture Overview

### current_casting_spell Lifecycle

```
_castSpell(spellName, mode, ...)
  └── if mode ~= 'ready':
        macroTorch.current_casting_spell = spellName  (set before cast)
      
      [CastSpellByName / obj.cast executes]
      
UNIT_CASTEVENT (castType == 'CAST'):
  └── if macroTorch.current_casting_spell:
        staticSpellId = resolveSpellId(current_casting_spell)
        if staticSpellId and staticSpellId ~= spellId:
          → persist correction to SM_EXTEND.spellIdMap[playerCls][spellName]
          → sync to loginContext.spellIdMap (if initialized)
          → migrate tracingSpells key: old staticId → new event spellId
          → chat notification
        macroTorch.current_casting_spell = nil  (always clear)
```

### Key Design Decisions

1. **mode ~= 'ready' guard**: `_castSpell` with `mode='ready'` only checks spell availability without casting -- no `current_casting_spell` is set. When `mode` is `nil` (default, i.e. 'safe') or `'raw'`, the spell IS being cast, so `current_casting_spell` is set.

2. **Clear only on CAST**: `current_casting_spell` is cleared only when UNIT_CASTEVENT reports `castType == 'CAST'`. SPELLCAST_FAILED/INTERRUPTED do not produce a CAST event, so clearing on them would leave stale state -- `_castSpell` overwrites the variable on every actual cast attempt.

3. **SM_EXTEND lazy-init follows loadImmuneTable pattern**: The correction block initializes `SM_EXTEND`, `SM_EXTEND.spellIdMap`, and `SM_EXTEND.spellIdMap[playerCls]` identically to how `loadImmuneTable` initializes `SM_EXTEND.immuneTable`.

4. **loginContext sync**: When a correction is made, if `loginContext.spellIdMap` already exists (loaded via `loadSpellIdMap()` in `onPlayerEnteringWorld`), the correction is also written there immediately. This prevents a race where the reference is already bound but the new key is missing.

5. **tracingSpells key migration**: When a spellId mismatch is detected, the event's spellId becomes the new authoritative key. The old static key in `tracingSpells` is replaced: `tracingSpells[eventSpellId] = tracingSpells[staticSpellId]`, then `tracingSpells[staticSpellId] = nil`.

### Druid SpellTrace:register Migration

| Spell | Old (hardcoded) | New |
|-------|----------------|-----|
| Pounce | `spellId = 9827` | `spellName = 'Pounce'` |
| Rake | `spellId = 1822` | `spellName = 'Rake'` |
| Rip | `spellId = 9492` | `spellName = 'Rip'` |
| Ferocious Bite | `spellId = 22557` | `spellName = 'Ferocious Bite'` |
| Faerie Fire (Feral) | unchanged | unchanged (land=false) |

### Category K Self-Tests

| ID | Test | Core/Optional |
|----|------|---------------|
| K1 | SPELL_NAME_TO_ID table with all 8 keys (EN+ZH) | core (`false`) |
| K2 | resolveSpellId resolves 4 known spells correctly | core (`false`) |
| K3 | resolveSpellId returns nil for unknown spell | optional (`true`) |
| K4 | loadSpellIdMap function callable without error | core (`false`) |
| K5 | current_casting_spell variable defined | optional (`true`) |

## Verify

```bash
./build.sh
grep -c "macroTorch.current_casting_spell" SM_Extend.lua      # >= 3
grep -c "spellName = 'Pounce'" SM_Extend.lua                  # >= 1
grep -c "spellName = 'Ferocious Bite'" SM_Extend.lua          # >= 1
grep -c "resolveSpellId" SM_Extend.lua                        # >= 1
grep -c 'register.*K:' SM_Extend.lua                          # >= 5
```

## Deviations from Plan

None -- plan executed exactly as written. All 2 tasks completed with no deviations.

## Known Stubs

None -- all data wired, all functions fully implemented, all guard conditions connected.

## Threat Flags

None -- no new network endpoints, auth paths, file access patterns, or trust boundary crossings introduced beyond the threat model's accepted dispositions (T-17-03 through T-17-SC).

## Self-Check: PASSED

- `entity/Player.lua` has `macroTorch.current_casting_spell` (1 match)
- `core/events.lua` has `macroTorch.current_casting_spell` check + clear + resolveSpellId invocation (6 matches)
- `classes/druid/Druid.lua` has 4 `spellName` fields, 0 hardcoded `spellId = [0-9]` in SpellTrace region
- `core/selftest.lua` has 5 Category K SelfTest registrations
- `./build.sh` succeeds, all symbols present in `SM_Extend.lua`
- Commits verified: `5fd4ce5`, `b2e24e0`