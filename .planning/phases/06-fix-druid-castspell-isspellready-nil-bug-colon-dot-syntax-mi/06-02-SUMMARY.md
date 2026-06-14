---
phase: 06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi
plan: 02
subsystem: testing
tags: [lua, wow-addon, uat, manual-testing, druid]

# Dependency graph
requires:
  - phase: 06-01
    provides: "Druid.lua _castSpell fix, Player.lua _castSpell fix, Category F selftests"
provides:
  - "HUMAN-UAT.md manual test checklist covering Type A/B/C Druid skills across ready/safe/raw modes"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Manual UAT checklist pattern: structured by skill type (A/B/C) x mode (ready/safe/raw) with explicit slash commands"

key-files:
  created:
    - "classes/druid/HUMAN-UAT.md — ~30 step-by-step manual test items for Druid _castSpell fix verification"
  modified: []

key-decisions:
  - "UAT checklist structured as Type A/B/C sections matching Druid skill method categorization from Phase 5 D-08"
  - "Each test item includes exact slash command (`/run ...`) for in-game execution to eliminate ambiguity"
  - "Pre-test /mt verification step included to confirm selftest Category F passes before manual testing begins"

patterns-established: []

requirements-completed: ["D-07"]

# Metrics
duration: ~5min
completed: 2026-06-14
---

# Phase 06 Plan 02: HUMAN-UAT.md Manual Test Checklist Summary

**Druid _castSpell fix manual UAT checklist with ~30 step-by-step in-game test items covering Type A/B/C skills across ready/safe/raw modes**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-14T14:43:00Z
- **Completed:** 2026-06-14T14:48:32Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created `classes/druid/HUMAN-UAT.md` with ~30 step-by-step manual test items
- Type A tests: 6 enemy-target skills (claw, shred, rake, rip, ferocious_bite, faerie_fire_feral) across 3 modes
- Type B tests: 4 self-target skills (cat_form, bear_form, prowl, tiger_fury) across 3 modes
- Type C tests: 3 flexible-target skills (healing_touch, rejuvenation, mark_of_the_wild) across 3 modes
- Integration test (catAtk one-button macro) and regression checks for external callers included
- Results summary table with checkboxes for structured sign-off

## Task Commits

1. **Task 4: Create HUMAN-UAT.md manual test checklist in classes/druid/HUMAN-UAT.md** - `a210592` (docs)

## Files Created/Modified
- `classes/druid/HUMAN-UAT.md` - Manual test checklist with ~30 step-by-step items, pre-test /mt verification, catAtk integration test, regression checks, and results summary table

## Decisions Made
- Used exact WoW slash commands (`/run macroTorch.player.claw('ready')`) for each test item so the tester has no ambiguity about what to execute
- Structured checklist following the plan's Type A/B/C categorization matching Phase 5 D-08 skill method taxonomy
- Included an explicit pre-test /mt self-test gate -- tester must confirm all Category F tests pass before proceeding with manual tests

## Deviations from Plan

None - plan executed exactly as written. The HUMAN-UAT.md content matches the plan's action template with all three skill types, all three modes, integration test, regression checks, and results summary table.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The HUMAN-UAT.md is a documentation file consumed by a human tester in-game.

## Next Phase Readiness
- HUMAN-UAT.md is ready for human tester to execute in-game after Phase 6 fixes are deployed
- Pre-test gate via `/mt` ensures Category F selftests pass before manual testing begins
- All three skill categories and all three modes are covered

---
*Phase: 06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi*
*Completed: 2026-06-14*