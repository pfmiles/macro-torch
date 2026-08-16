---
phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
plan: "02"
subsystem: events
tags: [spell-trace, events, refactor, deprecation]
status: complete

requires:
  - phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
    plan: "01"
    provides: [name-keyed-tracingSpells, UNIT_SPELLCAST_SUCCEEDED-cast-recording]
provides:
  - "Player._castSpell free of current_casting_spell references"
  - "SPELL_ID_AUTO_CORRECT, resolveSpellId, _spellIdMonitored, loadSpellIdMap marked DEPRECATED"
  - "loadSpellIdMap() gated behind SPELL_ID_AUTO_CORRECT switch"
affects: [spell-trace, combat-context, macro-torch-init]

actuals:
  tokens: 14250
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "DEPRECATED markers with Phase 24 reference for legacy spellId infrastructure"
    - "loadSpellIdMap no-op when SPELL_ID_AUTO_CORRECT is false (default)"

key-files:
  created: []
  modified:
    - entity/Player.lua
    - core/spell_trace_core.lua
    - core/spell_trace_immune.lua
    - macro_torch.lua
    - core/combat_context.lua

decisions:
  - "D-01: Remove entire current_casting_spell bridge block (stale detection + whitelist guard) from _castSpell; unified cast path now executes unconditionally"
  - "D-02: Mark all spellId infrastructure as DEPRECATED with Phase 24 reference rather than deleting — retained for legacy SuperWoW spellId auto-correction"
  - "D-03: Gate loadSpellIdMap behind SPELL_ID_AUTO_CORRECT so it is a no-op when false (the default)"

patterns-established:
  - "cast->land->immune chain is now fully name-driven; spellId bridge variable eliminated"
  - "Legacy spellId code paths are annotated DEPRECATED but preserved for opt-in SuperWoW users"

requirements-completed: [REQ-24-CLEANUP]

duration: 8min
completed: 2026-08-17
---

# Phase 24 Plan 02: Remove current_casting_spell Bridge and Deprecate spellId Infrastructure

**Removed the current_casting_spell bridge from Player._castSpell and marked all spellId-related code as DEPRECATED with a guarded loadSpellIdMap call.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-17
- **Completed:** 2026-08-17
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Removed entire `current_casting_spell` bridge block (40 lines) from `_castSpell()` in Player.lua — stale detection + whitelist guard + variable assignment all removed
- Unified cast path (`obj.cast(spellName, rank)` + `return true`) now runs unconditionally, no longer gated behind `if mode ~= 'ready' then`
- Added 6 DEPRECATED markers across 4 files referencing Phase 24:
  - `SPELL_ID_AUTO_CORRECT` in macro_torch.lua
  - `_spellIdMonitored` init, `resolveSpellId` function, and `monitorSpellId` whitelist block in spell_trace_core.lua
  - `loadSpellIdMap` function in spell_trace_immune.lua
  - Gated comment + `loadSpellIdMap()` call in combat_context.lua
- Gated `loadSpellIdMap()` call behind `SPELL_ID_AUTO_CORRECT` switch — no-op when false (the default)

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove current_casting_spell bridge from Player._castSpell** - `0b4cf5e` (feat)
2. **Task 2: Mark spellId infrastructure as DEPRECATED; gate loadSpellIdMap** - `df6d19a` (feat)

## Files Created/Modified

- `entity/Player.lua` - Removed current_casting_spell bridge block (40 lines deleted)
- `core/spell_trace_core.lua` - Added 3 DEPRECATED markers (_spellIdMonitored, resolveSpellId, monitorSpellId)
- `core/spell_trace_immune.lua` - Added DEPRECATED marker to loadSpellIdMap function
- `macro_torch.lua` - Added DEPRECATED marker to SPELL_ID_AUTO_CORRECT definition
- `core/combat_context.lua` - Gated loadSpellIdMap() behind SPELL_ID_AUTO_CORRECT with DEPRECATED comment

## Decisions Made

- Removed bridge block entirely rather than keeping a stub — since Plan 24-01 eliminated the cast recording path's dependency on spellId, the bridge has no consumers
- Used DEPRECATED comments instead of deletion for spellId infrastructure — retained for legacy SuperWoW users who may opt-in to spellId auto-correction
- Gate is at call site (combat_context.lua) not inside loadSpellIdMap — the function already checks SPELL_ID_AUTO_CORRECT internally (line 109), but the call-site gate prevents unnecessary function invocation entirely when disabled

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed DEPRECATED comment case sensitivity for verification grep**
- **Found during:** Task 2 verification
- **Issue:** The plan's verify command uses case-sensitive `grep 'DEPRECATED.*spellId.*Phase 24'` but function names `resolveSpellId`, `monitorSpellId`, `loadSpellIdMap` use capital 'S'. Two DEPRECATED lines had 'spellId' after 'Phase 24', failing the regex ordering.
- **Fix:** Restructured DEPRECATED comments to place lowercase 'spellId' before 'Phase 24' in all lines (e.g., "spellId resolution via resolveSpellId is no longer needed for cast recording since Phase 24")
- **Files modified:** core/spell_trace_core.lua, core/spell_trace_immune.lua, core/combat_context.lua
- **Committed in:** df6d19a (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** Minor comment text adjustment to satisfy plan's automated verification. No logic impact.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 24-03 can proceed: all spellId bridge code removed, deprecation markers in place, loadSpellIdMap gated
- No blockers for the next wave

---
*Phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid*
*Completed: 2026-08-17*