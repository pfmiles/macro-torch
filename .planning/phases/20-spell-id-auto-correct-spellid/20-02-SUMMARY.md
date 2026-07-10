---
phase: 20-spell-id-auto-correct-spellid
plan: 02
subsystem: spell-tracing
tags: [lua, wow-addon, spell-id, global-switch]

# Dependency graph
requires:
  - phase: 20-spell-id-auto-correct-spellid
    plan: 01
    provides: "SPELL_ID_AUTO_CORRECT global switch variable in macro_torch.lua, guarded SpellTrace:register in spell_trace_core.lua, guarded UNIT_CASTEVENT handler in spell_trace_immune.lua"
provides:
  - "SPELL_ID_AUTO_CORRECT guard on _castSpell current_casting_spell bridge in entity/Player.lua"
  - "SPELL_ID_AUTO_CORRECT guard on UNIT_CASTEVENT spellId correction block in core/events.lua"
affects: [spell-tracing, land-tracing, spell-id-auto-correct]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Global boolean gate pattern: macroTorch.SPELL_ID_AUTO_CORRECT as guard around spellId auto-correction code paths"

key-files:
  created: []
  modified:
    - entity/Player.lua
    - core/events.lua

key-decisions:
  - "None — followed plan as specified"

patterns-established:
  - "Global boolean gate: if macroTorch.SPELL_ID_AUTO_CORRECT then guards spellId auto-correction logic in _castSpell and UNIT_CASTEVENT handler"

requirements-completed:
  - REQ-20-CASTSPELL
  - REQ-20-UNITCASTEVENT

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "_castSpell() current_casting_spell bridge guarded by SPELL_ID_AUTO_CORRECT — stale detection and whitelist assignment skipped when switch is off"
    requirement: "REQ-20-CASTSPELL"
    verification:
      - kind: other
        ref: "grep -c 'if macroTorch\\.SPELL_ID_AUTO_CORRECT then' entity/Player.lua -> 1"
        status: pass
    human_judgment: true
    rationale: "Runtime behavior depends on in-game testing with both SPELL_ID_AUTO_CORRECT=true and false states — static grep verification confirms code structure but cannot validate runtime behavior"
  - id: D2
    description: "UNIT_CASTEVENT spellId correction block guarded by SPELL_ID_AUTO_CORRECT — correction skipped when switch is off, recordCastTable continues to work"
    requirement: "REQ-20-UNITCASTEVENT"
    verification:
      - kind: other
        ref: "grep -c 'if macroTorch\\.SPELL_ID_AUTO_CORRECT and macroTorch\\.current_casting_spell then' core/events.lua -> 1"
        status: pass
      - kind: other
        ref: "grep -n 'recordCastTable' core/events.lua -> line 122 (outside guarded block)"
        status: pass
      - kind: other
        ref: "./build.sh -> Build OK"
        status: pass
    human_judgment: true
    rationale: "Runtime behavior — spellId correction skipping and recordCastTable independence — requires in-game testing with SuperWow events to validate both switch states"

# Metrics
duration: ~2min
completed: 2026-07-10
status: complete
---

# Phase 20 Plan 02: SPELL_ID_AUTO_CORRECT Guard on _castSpell and UNIT_CASTEVENT

**SPELL_ID_AUTO_CORRECT guard wrapping _castSpell current_casting_spell bridge and UNIT_CASTEVENT spellId correction block, with recordCastTable preserved outside the guard**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-07-10T18:57:00Z
- **Completed:** 2026-07-10T18:59:14Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- _castSpell() current_casting_spell stale detection + whitelist assignment wrapped in `if macroTorch.SPELL_ID_AUTO_CORRECT then` guard
- UNIT_CASTEVENT spellId correction block (comparison, persistence, sync, key migration) guarded by `if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell then`
- recordCastTable() call preserved outside the guarded block — land tracing works regardless of SPELL_ID_AUTO_CORRECT state
- Build passes cleanly

## Task Commits

Each task was committed atomically:

1. **Task 1: Guard _castSpell() current_casting_spell bridge** - `d8b5db5` (feat)
2. **Task 2: Guard UNIT_CASTEVENT spellId correction** - `c29a984` (feat)

## Files Created/Modified
- `entity/Player.lua` — Added `if macroTorch.SPELL_ID_AUTO_CORRECT then` wrapper around stale detection (lines 89-106) and whitelist assignment (lines 111-113) inside _castSpell()
- `core/events.lua` — Changed UNIT_CASTEVENT correction block guard from `if macroTorch.current_casting_spell then` to `if macroTorch.SPELL_ID_AUTO_CORRECT and macroTorch.current_casting_spell then` (line 98)

## Decisions Made
None — followed plan as specified. The plan was precise about exact guard placement and scope.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Plan 02 complete — both _castSpell and UNIT_CASTEVENT paths are now guarded by SPELL_ID_AUTO_CORRECT
- Combined with Plan 01 (macro_torch.lua and spell_trace_core.lua guards), all five code paths from the Phase 20 CONTEXT.md are fully guarded
- Ready for plan 03 if additional guard locations are specified, or for Phase 20 verification

---
*Phase: 20-spell-id-auto-correct-spellid*
*Completed: 2026-07-10*