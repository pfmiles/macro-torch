---
phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin
plan: 01
subsystem: events
tags: [lua, wow-addon, spell-trace, whitelist, spellId]

# Dependency graph
requires:
  - phase: 17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr
    provides: "SPELL_NAME_TO_ID map, resolveSpellId, SpellTrace:register spellName support, current_casting_spell bridge"
provides:
  - "macroTorch._spellIdMonitored whitelist set table initialization"
  - "Automatic whitelist population from SpellTrace:register land branch"
  - "config.monitorSpellId optional field with nil-aware default (defaults to config.land)"
affects: [18-02 _castSpell whitelist guard, Druid spell registrations]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guarded-init pattern for global set tables (if not ... then ... = {} end)"
    - "Nil-aware boolean default resolution (if config.field ~= nil then ... else ... end)"
    - "Operational-before-administrative ordering in register flow"

key-files:
  created: []
  modified:
    - "core/spell_trace_core.lua"

key-decisions:
  - "_spellIdMonitored init position: module top level (line 21), before SpellTrace namespace (line 49), ensuring table exists before any Druid SpellTrace:register call during build_order.txt loading"
  - "Whitelist write position: inside if config.land then branch, after macroTorch.setSpellTracing (operational first, then administrative)"
  - "shouldMonitor resolution: explicit if/else nil check (if config.monitorSpellId ~= nil) matching codebase verbose style, NOT one-liner (x ~= nil) and x or default pattern"
  - "Legacy config.spellId-only registrations (no config.spellName): skipped from whitelist (per D-05)"

patterns-established:
  - "Guarded-init pattern for _spellIdMonitored: same as tracingSpells init (if not ... then ... = {} end)"
  - "Nil-aware default: monitorSpellId defaults to config.land when nil, preserves explicit false"
  - "SpellTrace:register as single entry point: operational tracing + administrative whitelist in one call"

requirements-completed: [REQ-18-D01, REQ-18-D02, REQ-18-D03]

# Coverage metadata
coverage:
  - id: D1
    description: "macroTorch._spellIdMonitored global set table initialized at module top level"
    requirement: "REQ-18-D02"
    verification:
      - kind: manual_procedural
        ref: "grep -n '_spellIdMonitored\|SpellTrace = {}' core/spell_trace_core.lua — line 21 < line 49"
        status: pass
    human_judgment: false
  - id: D2
    description: "SpellTrace:register automatically writes spellName to _spellIdMonitored when shouldMonitor=true"
    requirement: "REQ-18-D01"
    verification:
      - kind: manual_procedural
        ref: "grep -n 'spellIdMonitored\|shouldMonitor' core/spell_trace_core.lua — lines 21, 22, 88, 90, 92, 94, 95"
        status: pass
    human_judgment: false
  - id: D3
    description: "config.monitorSpellId nil-aware default: nil -> config.land, explicit false preserved"
    requirement: "REQ-18-D03"
    verification:
      - kind: manual_procedural
        ref: "Read core/spell_trace_core.lua lines 88-92 — if config.monitorSpellId ~= nil then shouldMonitor = config.monitorSpellId else shouldMonitor = config.land or false end"
        status: pass
    human_judgment: false
  - id: D4
    description: "build.sh succeeds with all changes"
    verification:
      - kind: manual_procedural
        ref: "./build.sh && echo 'Build OK'"
        status: pass
    human_judgment: false

# Metrics
duration: ~3m
completed: 2026-07-04
status: complete
---

# Phase 18 Plan 01: _spellIdMonitored whitelist infrastructure initialization

**Global whitelist set table `macroTorch._spellIdMonitored` with automatic populating from SpellTrace:register land branch — zero-config for existing Druid registrations**

## Performance

- **Duration:** ~3m
- **Started:** 2026-07-04T10:03:49Z
- **Completed:** 2026-07-04T10:06:55Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Initialized `macroTorch._spellIdMonitored` global set table at module top level (before SpellTrace namespace), using the same guarded-init pattern as `tracingSpells` — guarantees the table exists before any Druid.lua SpellTrace:register call during module loading
- Added automatic whitelist maintenance to `SpellTrace:register` land branch — when `shouldMonitor` resolves to true and `config.spellName` is present, the spell name is written to `_spellIdMonitored[config.spellName] = true`
- Implemented nil-aware `config.monitorSpellId` resolution: explicit value takes priority, otherwise defaults to `config.land`, preserving the ability to explicitly set `monitorSpellId=false`
- All 4 existing Druid registrations (Pounce, Rake, Rip, Ferocious Bite with `land=true` + `spellName`) automatically populate the whitelist at game load time — zero changes to Druid.lua required

## Task Commits

Each task was committed atomically:

1. **Task 1: Initialize _spellIdMonitored global set table in spell_trace_core.lua** - `129f2b1` (feat)
2. **Task 2: Add whitelist write logic to SpellTrace:register land branch** - `88f1695` (feat)

## Files Created/Modified
- `core/spell_trace_core.lua` - Added `macroTorch._spellIdMonitored` lazy-init (lines 18-23) and whitelist write logic in `SpellTrace:register` land branch (lines 85-96)

## Decisions Made
None — all design decisions were pre-specified in the plan (D-01/D-02/D-03 from CONTEXT.md). Execution followed plan exactly.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None — no external service configuration required. The whitelist table is initialized at module load time and populated automatically during SpellTrace:register calls.

## Next Phase Readiness
- Plan 02 (`_castSpell` whitelist guard) can proceed — `macroTorch._spellIdMonitored` table is available for O(1) lookup
- At game load time (after PLAYER_ENTERING_WORLD), `macroTorch._spellIdMonitored` will contain: `{["Pounce"]=true, ["Rake"]=true, ["Rip"]=true, ["Ferocious Bite"]=true}`
- Plan 02 will add `if macroTorch._spellIdMonitored[localeNames.en] then current_casting_spell = ...` guard in `entity/Player.lua:_castSpell`

## Known Stubs
None — the whitelist is fully wired to production code paths. All 4 Druid registrations will populate it automatically.

---
*Phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin*
*Completed: 2026-07-04*