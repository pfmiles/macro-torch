---
phase: 20-spell-id-auto-correct-spellid
plan: 01
subsystem: core
tags: [lua, wow-addon, spellid, feature-toggle]

# Dependency graph
requires: []
provides:
  - macroTorch.SPELL_ID_AUTO_CORRECT global toggle variable (defaults to true)
  - Guarded resolveSpellId() that skips runtime-corrected spellIdMap when switch is off
  - Guarded loadSpellIdMap() that early-returns when switch is off
affects:
  - 20-spell-id-auto-correct-spellid-02 (Player.lua _castSpell bridge guard)
  - 20-spell-id-auto-correct-spellid-03 (events.lua UNIT_CASTEVENT branch guard)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Feature toggle pattern: single global boolean variable guards multiple function entry points"
    - "Early-return guard pattern for idempotent function gate"

key-files:
  created: []
  modified:
    - macro_torch.lua
    - core/spell_trace_core.lua
    - core/spell_trace_immune.lua

key-decisions:
  - "Default SPELL_ID_AUTO_CORRECT to true for full backward compatibility"
  - "Use outer if-guard rather than conditional assignment inside resolveSpellId() for clarity"
  - "Use early-return pattern in loadSpellIdMap() to skip all loading and migration logic atomically"

patterns-established:
  - "Feature toggle pattern: single global boolean variable (macroTorch.SPELL_ID_AUTO_CORRECT) defaults to true, guards multiple function entry points across files"

requirements-completed:
  - REQ-20-VARIABLE
  - REQ-20-RESOLVE
  - REQ-20-LOADMAP

# Metrics
duration: 42s
completed: 2026-07-10
status: complete
---

# Phase 20 Plan 01: Global spellId auto-correction feature toggle

**Define SPELL_ID_AUTO_CORRECT global switch and guard resolveSpellId/loadSpellIdMap entry points**

## Performance

- **Duration:** 42s
- **Started:** 2026-07-10T18:56:33Z
- **Completed:** 2026-07-10T18:58:40Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Defined macroTorch.SPELL_ID_AUTO_CORRECT = true in macro_torch.lua with comprehensive comment explaining all guarded behaviors
- Guarded resolveSpellId() in spell_trace_core.lua so it skips loginContext.spellIdMap lookup when switch is false, falling through to static SPELL_NAME_TO_ID
- Guarded loadSpellIdMap() in spell_trace_immune.lua with early-return when switch is false, skipping all SM_EXTEND loading and tracingSpells key migration

## Task Commits

Each task was committed atomically:

1. **Task 1: Define SPELL_ID_AUTO_CORRECT in macro_torch.lua** - `7697199` (feat)
2. **Task 2: Guard resolveSpellId() in core/spell_trace_core.lua** - `8876042` (feat)
3. **Task 3: Guard loadSpellIdMap() in core/spell_trace_immune.lua** - `bb7fe4e` (feat)

## Files Created/Modified

- `macro_torch.lua` - Added SPELL_ID_AUTO_CORRECT global toggle variable with explanatory comment (10 lines added, after debug init message)
- `core/spell_trace_core.lua` - Wrapped resolveSpellId() loginContext.spellIdMap lookup in outer SPELL_ID_AUTO_CORRECT guard (6 inserted, 4 deleted)
- `core/spell_trace_immune.lua` - Added early-return guard as first statement in loadSpellIdMap() (1 line inserted)

## Decisions Made

None - followed plan exactly as specified.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The toggle defaults to true, preserving full backward compatibility.

## Next Phase Readiness

Ready for Plan 02 (Player.lua _castSpell bridge guard) and Plan 03 (events.lua UNIT_CASTEVENT branch guard). Both plans depend on the SPELL_ID_AUTO_CORRECT variable defined in this plan.

## Self-Check: PASSED

- 20-01-SUMMARY.md: FOUND
- Commit 7697199: FOUND
- Commit 8876042: FOUND
- Commit bb7fe4e: FOUND

---
*Phase: 20-spell-id-auto-correct-spellid*
*Completed: 2026-07-10*