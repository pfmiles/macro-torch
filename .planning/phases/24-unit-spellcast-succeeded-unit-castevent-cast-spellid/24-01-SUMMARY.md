---
phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
plan: "01"
subsystem: events
tags: [spell-trace, events, refactor]
status: complete

requires: []
provides: [name-keyed-tracingSpells, UNIT_SPELLCAST_SUCCEEDED-cast-recording, recordCastTable-dedup]
affects: [spell_trace_core.lua, events.lua, Druid.lua (SpellTrace:register consumers)]

tech-stack:
  added: []
  patterns:
    - "tracingSpells name-keyed set: tracingSpells[spellName] = true"
    - "UNIT_SPELLCAST_SUCCEEDED arg2 lookup replaces UNIT_CASTEVENT spellId translation"
    - "recordCastTable 0.2s dedup window prevents double-recording"

key-files:
  created: []
  modified:
    - core/spell_trace_core.lua
    - core/events.lua

decisions:
  - "D-01 (name-keyed): tracingSpells refactored from spellId->spellName map to spellName->true set"
  - "D-02 (dedup): 0.2s window threshold based on GCD minimum of 1.0s in WoW 1.12"

metrics:
  duration: none
  completed_at: "2026-08-17"

actuals:
  tokens: 1566
  tasks: 2
  commits: 2
---

# Phase 24 Plan 01: UNIT_SPELLCAST_SUCCEEDED Cast Recording Summary

**One-liner:** Refactored spell cast recording to use standard WoW 1.12 UNIT_SPELLCAST_SUCCEEDED event (arg2=spellName) instead of SuperWoW's UNIT_CASTEVENT (arg4=spellId), eliminating dependency on SPELL_NAME_TO_ID name-to-id translation in the cast recording path.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Refactor tracingSpells to name-keyed set and wire cast recording through UNIT_SPELLCAST_SUCCEEDED | `234aa7b` | core/spell_trace_core.lua, core/events.lua |
| 2 | Add deduplication to recordCastTable | `85bb194` | core/spell_trace_core.lua |

## Verification Results

### Build
- `./build.sh` produces valid SM_Extend.lua (passed after both tasks)

### Truth Checks

| # | Truth | Status |
|---|-------|--------|
| 1 | UNIT_SPELLCAST_SUCCEEDED fires and arg2 (spellName) is recorded into castTable when spell is in tracingSpells | PASS |
| 2 | UNIT_CASTEVENT handler no longer calls recordCastTable | PASS |
| 3 | tracingSpells is keyed by spellName (string) with value true | PASS |
| 4 | SpellTrace:register land=true path calls setSpellTracing(name) without resolveSpellId | PASS |
| 5 | maintainLandTables iterates tracingSpells by name (pairs key is spellName) | PASS |
| 6 | recordCastTable skips duplicate pushes when same spellName+mob within 0.2s | PASS |
| 7 | All 4 Druid land-tracing spells (Pounce, Rake, Rip, Ferocious Bite) continue to register via name-keyed path | PASS |
| 8 | build.sh produces valid SM_Extend.lua | PASS |

### Key Links Verified

- **UNIT_SPELLCAST_SUCCEEDED -> recordCastTable:** `if arg1 == "player" and arg2 and macroTorch.tracingSpells[arg2] then macroTorch.recordCastTable(arg2) end`
- **SpellTrace:register land=true -> setSpellTracing:** `if config.land then macroTorch.setSpellTracing(name) end`
- **recordCastTable dedup -> LRUStack.top:** `local last = castTable[spell][mob].top; if last and (GetTime() - last) < 0.2 then return end`

## Deviations from Plan

### Intentional Preservations

**1. UNIT_CASTEVENT auto-correction block preserved with stale tracingSpells migration lines**
- **Found during:** Task 1
- **Issue:** The spellId auto-correction block (lines 133-135 in original events.lua) contains `tracingSpells[spellId] = tracingSpells[staticSpellId]` and `tracingSpells[staticSpellId] = nil`. After the name-keyed refactor, these are no-ops since `staticSpellId` (a number) is never a key in the name-keyed tracingSpells set.
- **Fix:** Kept as-is per plan instruction: "KEEP the spellId auto-correction block intact — it is a separate SuperWoW feature". The no-op lines are harmless and preserving the block avoids unintended side effects.
- **Files modified:** core/events.lua
- **Commit:** `234aa7b`

### Auto-fixed Issues

None — plan executed exactly as written with no unexpected issues.

## Known Stubs

None — all changes are production code with no placeholder values, TODO markers, or unwired data sources.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced beyond what the plan's threat model already covers.

## Self-Check: PASSED

- core/spell_trace_core.lua: exists, contains name-keyed tracingSpells and dedup logic
- core/events.lua: exists, contains active UNIT_SPELLCAST_SUCCEEDED handler, no recordCastTable in UNIT_CASTEVENT
- Commit `234aa7b`: exists in git log
- Commit `85bb194`: exists in git log