---
phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol
plan: 03
subsystem: hunter
tags: [build-system, file-cleanup, wow-addon, lua]

# Dependency graph
requires:
  - phase: 25-02
    provides: classes/hunter/combo.lua with 5 Hunter one-button combo macro functions
provides:
  - build_order.txt — Hunter block updated: combo.lua added, combat.lua/utility.lua removed
  - Deleted deprecated classes/hunter/combat.lua and classes/hunter/utility.lua
  - Build verification: SM_Extend.lua contains 25 skill methods + 5 combo functions, no old symbols
affects: []

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 1158
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - build_order.txt — Hunter comment line updated to reflect Phase 25 combo refactor history
  deleted:
    - classes/hunter/combat.lua — deprecated, logic migrated to combo.lua
    - classes/hunter/utility.lua — deprecated, logic migrated to combo.lua

key-decisions:
  - "Build_order.txt was already partially restructured (combo.lua in place, combat/utility absent) — adjusted to comment-only update instead of 4-line block replacement"

patterns-established: []

requirements-completed:
  - H-11
  - H-12

coverage:
  - id: D1
    description: "build_order.txt Hunter block reflects new Druid-aligned architecture (Hunter.lua + combo.lua, no deprecated combat.lua/utility.lua)"
    requirement: H-11
    verification:
      - kind: unit
        ref: "grep verification: combo.lua line > Hunter.lua line, combat.lua/utility.lua absent"
        status: pass
    human_judgment: false
  - id: D2
    description: "Deprecated files (combat.lua, utility.lua) deleted; SM_Extend.lua build output verified: 25 skill methods + 5 combo functions, no old symbols"
    requirement: H-12
    verification:
      - kind: integration
        ref: "./build.sh && grep verification of SM_Extend.lua symbol integrity"
        status: pass
    human_judgment: false

# Metrics
duration: 2min
completed: 2026-08-18
status: complete
---

# Phase 25 Plan 03: File Cleanup and Build Verification Summary

**build_order.txt updated for Phase 25 Hunter combo refactor — deprecated combat.lua/utility.lua deleted, build verified with 25 skill methods + 5 combo functions**

## Performance

- **Duration:** 2 min
- **Started:** 2026-08-18T16:12:31Z
- **Completed:** 2026-08-18T16:15:14Z
- **Tasks:** 2
- **Files modified:** 1 (build_order.txt)
- **Files deleted:** 2 (combat.lua, utility.lua)

## Accomplishments

- build_order.txt Hunter comment updated to `# classes/ — Hunter (Phase 8 / Phase 25 combo refactor)` to record architectural history
- Deprecated classes/hunter/combat.lua and classes/hunter/utility.lua permanently deleted (logic migrated to combo.lua in Plan 25-02)
- Build verification passed: SM_Extend.lua contains 25 Hunter skill methods + 5 combo macro functions, zero old symbol references
- Threat T-25-08 (build order) and T-25-09 (deprecated file cleanup) both mitigated

## Task Commits

Each task was committed atomically:

1. **Task 1: build_order.txt comment update** - `e2bf81a` (chore)
2. **Task 2: Delete deprecated files + build verification** - `8da2184` (chore)

## Files Created/Modified

- `build_order.txt` — Hunter block comment line updated to reflect Phase 25 combo refactor history

## Files Deleted

- `classes/hunter/combat.lua` — 74 lines, contained legacy hunterAtk() and htOtMod() functions
- `classes/hunter/utility.lua` — 32 lines, contained legacy hunterSting() and hunterCtrl() functions

## Decisions Made

- **Comment-only update instead of block replacement:** build_order.txt was already restructured (combo.lua in place, combat.lua/utility.lua absent) from prior work in Plan 25-02. Adjusted to update only the comment line to document the Phase 25 history, which achieves the plan's objective without redundant changes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan assumed 4-line block in build_order.txt, actual file already restructured**

- **Found during:** Task 1 (build_order.txt update)
- **Issue:** Plan described replacing a 4-line block (`comment + Hunter.lua + combat.lua + utility.lua`) but the actual file already had combo.lua in place and the deprecated entries removed (likely done during Plan 25-02 execution)
- **Fix:** Reduced scope to comment-only update — changing `# classes/ — Hunter (Phase 8)` to `# classes/ — Hunter (Phase 8 / Phase 25 combo refactor)`, which fully satisfies the plan's objective of documenting the architectural change
- **Files modified:** build_order.txt
- **Verification:** grep verification confirmed combo.lua after Hunter.lua and combat.lua/utility.lua absent from build_order.txt
- **Committed in:** e2bf81a

**2. [Rule 3 - Blocking] Broken shell syntax in PLAN.md verify section**

- **Found during:** Task 1 (verification execution)
- **Issue:** PLAN.md verify script used `grep ... | head -1 | read VAR` pattern, which does not set shell variables due to pipeline subshell isolation in bash
- **Fix:** Changed to `VAR=$(grep ... | head -1)` pattern for correct variable assignment
- **Files modified:** 25-03-PLAN.md (verify section)
- **Verification:** Verification script ran successfully with corrected syntax
- **Committed in:** e2bf81a

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both deviations were minimal blocking issues handled by adjusting to actual file state and fixing script syntax. No scope creep. Plan objectives fully achieved.

## Issues Encountered

- rm with interactive prompt required `-f` flag for non-interactive deletion

## Next Phase Readiness

- Phase 25 file structure reorganization complete — Hunter now follows Druid-aligned architecture (Hunter.lua + combo.lua)
- No blockers. Phase 25 is complete (3/3 plans).

---
*Phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol*
*Completed: 2026-08-18*