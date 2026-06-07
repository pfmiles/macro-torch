---
phase: 01-classmetatable-entity
plan: "06"
plan-name: build_order.txt + build.sh declaration-based build system
type: execute
wave: 3
status: complete
depends_on: [01-01, 01-02, 01-03, 01-04, 01-05]
requirements: [R7]
started: "2026-06-07T18:31:01Z"
completed: "2026-06-07T18:31:01Z"
duration-s: 180
tasks-total: 2
tasks-completed: 2
commits:
  - df4317f
  - ed3df22
files-created:
  - build_order.txt
files-modified:
  - build.sh
tech-stack:
  added: []
  patterns:
    - declaration-based build file list
    - fault-tolerant shell script (skip missing files)
    - while IFS= read -r line loop
key-decisions:
  - "build_order.txt contains all Phase 1-4 file paths including future files per D-09"
  - "build.sh uses [ -f \"$line\" ] fault-tolerant guard per D-10; switches to strict mode in Phase 4"
  - "printf '\n' before each cat ensures file separation in concatenated output"
tags: [build-system, shell, refactoring, R7]
---

# Phase 1 Plan 06: build_order.txt + build.sh Declaration-Based Build System Summary

One-liner: Replaced grep -v blacklist build.sh with a 44-line declaration-based build_order.txt and fault-tolerant while-read loop that concatenates only existing files.

## Tasks Executed

### Task 1: Create build_order.txt with full Phase 1-4 file list
- **Commit:** `df4317f`
- **Action:** Created 44-line `build_order.txt` containing all Phase 1 current files (core/, entity/, SM_Extend_*.lua, battle_event_queue.lua, texture_map.lua, etc.) and all Phase 2-4 future files (core/events.lua, core/combat_context.lua, core/spell_trace.lua, core/selftest.lua, classes/Druid/*, classes/*.lua)
- **Dependency order:** macro_torch.lua -> impl_util.lua -> biz_util.lua -> core/ -> entity/ -> battle_event_queue.lua -> texture_map.lua -> interface_debug.lua -> SM_Extend_*.lua -> future core/ Phase 2-3 -> future classes/ Phase 4
- **Key ordering guarantees:** core/ before entity/ (metatable + periodic deps), entity/Unit.lua before subclasses (inheritance), comment sections separate logical groups

### Task 2: Rewrite build.sh to read build_order.txt with fault-tolerant mode
- **Commit:** `ed3df22`
- **Action:** Completely rewrote build.sh to replace hardcoded file list and grep -v blacklist with a while-read loop that processes build_order.txt. Each line: skip empty/comment, `[ -f "$line" ]` guard, then `printf '\n'` + `cat` to target. Cygwin copy logic preserved.
- **Verification:** `./build.sh` runs successfully, produces 196KB SM_Extend.lua with classMetatable, initPlayer, and registerPeriodicTask symbols present
- **Threat mitigations:** T-01-06a (tampering) accepted - static file paths with no injection points. T-01-06b (DoS from missing files) mitigated - `[ -f "$line" ]` guard skips Phase 2-4 files not yet created

## Verification Results

| Check | Expected | Actual |
|-------|----------|--------|
| build_order.txt line count | > 25 | 44 |
| First line | macro_torch.lua | macro_torch.lua |
| core/ entries | >= 4 | 6 |
| entity/ entries | >= 9 | 9 |
| classes/ entries | >= 8 | 10 |
| SM_Extend_*.lua entries | = 7 | 7 |
| future Phase 2-4 paths | >= 8 | 16 |
| build.sh grep -v | none | none |
| build.sh while-read-loop | present | present |
| build.sh fault-tolerant guard | present | present |
| Cygwin logic | preserved | preserved |
| ./build.sh exit code | 0 | 0 |
| SM_Extend.lua exists | yes | yes |
| classMetatable in output | >= 1 | 1 |
| initPlayer in output | >= 1 | 1 |
| registerPeriodicTask in output | >= 1 | 1 |

## Deviations from Plan

None - plan executed exactly as written.

## Threat Flags

None - threat model mitigations verified (T-01-06a static file paths, T-01-06b fault-tolerant guard).

## Known Stubs

None - no hardcoded empty values, placeholders, or unwired data sources in any file created by this plan.

## Self-Check

- [x] build_order.txt exists and is 44 lines
- [x] build.sh contains while-read-loop and fault-tolerant guard
- [x] ./build.sh completes with exit code 0
- [x] SM_Extend.lua exists and contains key symbols
- [x] df4317f commit exists on branch
- [x] ed3df22 commit exists on branch