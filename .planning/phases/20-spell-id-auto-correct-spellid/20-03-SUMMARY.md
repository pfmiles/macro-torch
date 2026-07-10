---
phase: 20-spell-id-auto-correct-spellid
plan: 03
subsystem: testing
tags: [selftest, spellid, auto-correct, druid]

requires:
  - phase: 20-spell-id-auto-correct-spellid
    plan: 01
    provides: SPELL_ID_AUTO_CORRECT global variable in macro_torch.lua
  - phase: 20-spell-id-auto-correct-spellid
    plan: 02
    provides: SPELL_ID_AUTO_CORRECT guard logic in _castSpell, events.lua, resolveSpellId, loadSpellIdMap
provides:
  - Category N selftest registrations (N1-N5) verifying SPELL_ID_AUTO_CORRECT switch behavior
  - N1: default value is true verification
  - N2: resolveSpellId returns static value when switch is false
  - N3: resolveSpellId returns corrected value when switch is true
  - N4: loadSpellIdMap function existence and callability verification
  - N5: current_casting_spell nil after mode='ready' _castSpell verification
affects: [testing, selftest]

key-files:
  modified:
    - core/selftest.lua

key-decisions:
  - "Category N uses isOptional=true for all 5 tests following the pattern established by Category M (Druid-specific features)"
  - "N2 and N3 use pcall with state restoration in both success and error paths to prevent selftest pollution"
  - "N5 uses player.rake('ready') with an explicit guard for method existence before invocation"

requirements-completed:
  - REQ-20-SELFTEST

metrics:
  duration: 1.5min
  completed: 2026-07-10
  status: complete
---

# Phase 20 Plan 03: Category N selftest registrations for SPELL_ID_AUTO_CORRECT Summary

**5 self-test registrations (Category N) verifying SPELL_ID_AUTO_CORRECT switch behavior: default value, resolveSpellId both modes, loadSpellIdMap callability, and _castSpell ready-mode no-bridge**

## Performance

- **Duration:** ~1.5 min
- **Started:** 2026-07-10T19:05:00Z
- **Completed:** 2026-07-10T19:06:38Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Registered 5 Category N selftests in core/selftest.lua between Category M and Module 4
- N1 verifies SPELL_ID_AUTO_CORRECT defaults to true
- N2 verifies resolveSpellId() returns static SPELL_NAME_TO_ID value when switch is false (pcall-guarded state restoration)
- N3 verifies resolveSpellId() returns corrected loginContext.spellIdMap value when switch is true (pcall-guarded cleanup)
- N4 verifies loadSpellIdMap() exists as a function and is callable without error (loginContext guard)
- N5 verifies current_casting_spell stays nil after mode='ready' _castSpell (Druid + skill method guards)
- All tests are isOptional=true, following the Category K/L/M pattern for Druid-specific tests

## Task Commits

1. **Task 1: Register Category N selftests for SPELL_ID_AUTO_CORRECT** - `90787d3` (feat)

## Files Created/Modified
- `core/selftest.lua` - Added Category N section (90 lines) with 5 selftest registrations after Category M

## Decisions Made
- Used `player.rake('ready')` for N5 as it's a Druid skill method with defined locale names; added guard for method existence to avoid nil access on non-Druid logins or missing skill methods
- N2 restores SPELL_ID_AUTO_CORRECT in success path and has a defensive restore in the error path
- N3 temporarily creates a spellIdMap entry for "Rake" with staticId + 10000, then cleans up (restores previous value or sets nil) in both success and error paths
- All 5 tests follow the `isOptional=true` pattern established by Category M (all isOptional) for Druid-specific tests

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness
- Category N selftests are registered and ready for in-game verification via `/mt`
- No blocking issues; selftests are isOptional so they will not cause red errors on non-Druid logins if guards fail

---
*Phase: 20-spell-id-auto-correct-spellid*
*Completed: 2026-07-10*

## Self-Check: PASSED
- SUMMARY.md exists
- core/selftest.lua exists
- commit 90787d3 confirmed in git history