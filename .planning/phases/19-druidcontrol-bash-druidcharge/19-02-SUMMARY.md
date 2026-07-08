---
phase: 19-druidcontrol-bash-druidcharge
plan: 02
subsystem: selftest
tags: [self-test, verification, druidControl, druidCharge, Category M]
complexity: 1
lines_changed: 35
requires:
  - 19-01
provides:
  - Category M self-test registrations (druidControl/druidCharge verification)
affects:
  - core/selftest.lua
tech-stack:
  added: []
  patterns:
    - SelfTest:register with UnitClass guard and isOptional=true
key-files:
  created: []
  modified:
    - core/selftest.lua
decisions:
  - "Category M tests placed after Category L count comment (line 746) and before Module 4 (rest at line 784)"
  - "M2 (druidControl Bash-free) uses code-review assertion only; WoW 1.12.1 Lua has no filesystem access for runtime source inspection"
  - "M2 combined with M3 pcall: M2 documents requirement, M3 proves druidControl still runs without error after elseif->if promotion"
metrics:
  duration: 150
  completed_date: 2026-07-08
status: complete
---

# Phase 19 Plan 02: Category M Self-Test Registrations Summary

**One-liner:** Register 4 optional Category M self-tests in selftest.lua to verify druidControl/druidCharge split structural correctness on login.

## What was built

Inserted a Category M self-test block in `core/selftest.lua` containing 4 `SelfTest:register()` calls, all with `isOptional=true` and `UnitClass('player') ~= 'Druid'` guards. The block is placed between the Category L registration count comment (line 746) and the Module 4 header (line 784).

### Tests registered

| Test | Name | Verifies |
|------|------|----------|
| M1 | `"M: druidCharge function exists"` | `macrotorch.druidCharge` is a function |
| M2 | `"M: druidControl does not call bash (code-review verified per D-06)"` | druidControl function exists; code-review documents Bash branch removal |
| M3 | `"M: druidControl invocable via pcall (elseif->if promotion valid per D-07)"` | druidControl invocation via pcall succeeds (no error from elseif->if promotion) |
| M4 | `"M: druidControl skill methods present (Hibernate + Entangling Roots per D-07)"` | `player.hibernate` and `player.entangling_roots` are functions |

### Design decisions

- **M2 runtime limitation:** WoW 1.12.1 Lua addons cannot read files at runtime, so the Bash branch removal cannot be verified by inspecting source. M2 asserts `type(macrotorch.druidControl) == "function"` and documents code-review verification. M3 complements M2 by proving druidControl still runs without error.
- **All optional:** All 4 tests use `isOptional=true` (third arg), producing yellow warnings not red errors. Druid-only guards ensure silent skip on non-Druid characters.
- **Convention consistency:** Category header format, count comment, M: prefix, SelfTest:register API all match existing Category J/K/L patterns.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Insert Category M self-test block in selftest.lua (D-05, D-06, D-07) | 9623ea7 | core/selftest.lua |

## Verification Results

- `grep -c "Category M:" core/selftest.lua` = 1 (pass)
- `grep -c "M: druidCharge function exists" core/selftest.lua` = 1 (pass)
- `grep -c "M: druidControl does not call bash" core/selftest.lua` = 1 (pass)
- `grep -c "M: druidControl invocable via pcall" core/selftest.lua` = 1 (pass)
- `grep -c "M: druidControl skill methods present" core/selftest.lua` = 1 (pass)
- All 4 registrations pass `true` as third argument (isOptional) (pass)
- All 4 registrations contain `if UnitClass('player') ~= 'Druid' then return end` guard (pass)
- Category M block inserted at line 749 (after Category L count at 746, before Module 4 at 784) (pass)
- `./build.sh` exit code 0 (pass)
- `grep -c "M: druidCharge function exists" SM_Extend.lua` = 1 (pass)

## Deviations from Plan

None -- plan executed exactly as written. The single task was completed with all acceptance criteria passing on first attempt.

## Self-Check: PASSED

- `core/selftest.lua` modified and committed: 9623ea7 exists
- `SM_Extend.lua` generated successfully with all 4 tests present
- All grep-based acceptance criteria verified