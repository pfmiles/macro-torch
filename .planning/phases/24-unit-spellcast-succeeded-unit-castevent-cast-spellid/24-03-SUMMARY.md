---
phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
plan: "03"
subsystem: testing
tags: [selftest, tracingSpells, spellId, deprecated]

requires:
  - phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
    provides: name-keyed tracingSpells, deprecated spellId infrastructure
provides:
  - Updated Category K tests validating name-keyed tracingSpells architecture
  - Updated Category N tests acknowledging spellId infrastructure deprecation
affects: []

actuals:
  tokens: 27000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Selftest registration: SelfTest:register(label, fn, isOptional)"

key-files:
  created: []
  modified:
    - core/selftest.lua

key-decisions:
  - "Category K tests now validate name-keyed tracingSpells (spellName → true) instead of spellId-keyed map"
  - "Category N tests acknowledge SPELL_ID_AUTO_CORRECT as deprecated but preserve legacy correction path verification"
  - "Old N5 (current_casting_spell lifecycle test) removed — bridge variable no longer exists after 24-02"

requirements-completed: [REQ-24-SELFTEST]

duration: 3min
completed: 2026-08-17
status: complete
---

# Phase 24 Plan 03: Selftest Updates Summary

**Updated Category K (spell trace registration) and Category N (SPELL_ID_AUTO_CORRECT) to reflect Phase 24 name-keyed refactoring**

## Performance

- **Duration:** 3 min
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Category K: 5 tests rewritten to validate name-keyed tracingSpells structure, setSpellTracing single-arg signature, and legacy spellId infrastructure retention
- Category N: 4 tests updated to acknowledge SPELL_ID_AUTO_CORRECT deprecation, preserve legacy resolveSpellId behavior checks, removed current_casting_spell lifecycle test
- All tests pass via `./build.sh` (build produces valid SM_Extend.lua)

## Task Commits

1. **Task 1: Update Category K selftests** — `c1c4e99` (test)
2. **Task 2: Update Category N selftests** — `c1c4e99` (test)

**Plan metadata:** to be committed

## Files Modified
- `core/selftest.lua` — Rewrote Category K (lines 613-668) and Category N (lines 789-877)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.