---
phase: 03-spell-trace
plan: 01
subsystem: self-test
tags: [self-test, infrastructure, health-check, slash-command]
requires: []
provides: [SelfTest framework, /mt SLASH command]
affects: [core/selftest.lua]
tech-stack:
  added: []
  patterns: [register/run, pcall isolation, SLASH command, session flag]
key-files:
  created: [core/selftest.lua]
  modified: []
decisions:
  - "session flag macroTorch._selfTestRan prevents repeated output on zone transitions (D-01)"
  - "/mt SLASH command serves as future mt-script DSL entry point; Phase 3 only runs self-test (D-02/D-10)"
  - "pure report mode: successful tests silent, failures red/yellow per isOptional flag (D-05)"
  - "all tests wrapped in pcall with tostring(err) detail capture (RESEARCH Pitfall 5)"
  - "Player entity does read-only property calls; Target/Pet only verify property existence (D-04)"
metrics:
  duration_seconds: 567
  completed_date: "2026-06-08"
  files_created: 1
  lines_of_code: 460
---

# Phase 03 Plan 01: SelfTest Framework + 71 Infrastructure Tests + /mt Command Summary

**One-liner:** SelfTest register/run framework with 71 infrastructure health checks across 5 categories, triggered by /mt SLASH command or PLAYER_ENTERING_WORLD.

## Commits

| Task | Name                                           | Commit   | Files Created        |
| ---- | ---------------------------------------------- | -------- | -------------------- |
| 1    | SelfTest framework + /mt SLASH command         | 8b67afe  | core/selftest.lua    |
| 2    | 71 infrastructure self-test items registration | ac21fff  | core/selftest.lua    |

## Completed Tasks

### Task 1: SelfTest Framework + /mt SLASH Command
Created `core/selftest.lua` with 4 modules:
- **Module 1:** SelfTest table initialization (`macroTorch.SelfTest = { tests = {} }`, `macroTorch._selfTestRan = nil`)
- **Module 2:** `SelfTest:register(name, fn, isOptional)` -- adds test items to the tests table
- **Module 3:** `SelfTest:run()` -- pcall-isolated execution with session flag, summary line, and color-coded failure output
- **Module 4:** `/mt` SLASH command -- no-arg runs self-test, with-arg shows reserved DSL notice

### Task 2: 71 Infrastructure Self-Test Registrations
Registered 71 tests in 5 categories between the framework and SLASH command:

| Category | Count | Type | Description |
|----------|-------|------|-------------|
| A: Lua Environment | 10 | core | type(), pcall(), setmetatable(), table.insert, string.format, ipairs, unpack, error(), math.max, string.find |
| B: WoW API | 34 | core | UnitHealth/Mana/Class, GetComboPoints, CastSpellByName, IsUsableAction, GetSpellName, GetTalentInfo, etc. |
| C: Player Entity | 20 | core | health/mana properties, isInCombat/isExist/isDead flags, method existence checks |
| D: Target/Pet | 7 | core | table + property existence verification only (per D-04) |
| E: Optional Modules | 2 | optional | UnitXP (isOptional=true), SP3 (isOptional=true) |

## Verification Results

- Build: `./build.sh` succeeded
- SelfTest:register count: 71 (plan target: >=60)
- SelfTest:run function present with _selfTestRan session flag check
- /mt SLASH command registered with SLASH_MT1 and SlashCmdList["MT"]
- pcall failures include tostring(err) detail capture
- Successful tests produce no macroTorch.show output
- Core failures use color='red', optional failures use color='yellow'
- Category A: 10/8 target met
- Category B: 34/30 target met
- Category C: 20/15 target met
- Category D: 7/7 target met
- Category E: 2/2 target met with isOptional=true

## Deviations from Plan

None -- plan executed exactly as written.

## Auth Gates

None -- no authentication or external service dependencies in this phase.

## Known Stubs

None. All code is fully functional. The /mt command with arguments defers to future mt-script DSL but this is explicitly documented as Phase 3 design (D-10).

## Threat Flags

None. All security surface is documented in the plan's threat model and handled as specified:
- T-03-01 (Spoofing): /mt msg parameter only checked for emptiness, no eval -- mitigated
- T-03-02 (Information Disclosure): pcall error output is intentional debug output for client addon -- accepted

## Self-Check: PASSED

- core/selftest.lua exists at expected path
- 8b67afe and ac21fff commits confirmed in git log
- Build output SM_Extend.lua contains 75 SelfTest:register and 4 SelfTest:run references