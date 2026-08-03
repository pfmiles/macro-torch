---
phase: quick
plan: 260804-0bz-fix-pounce-savagery-duration
subsystem: druid
tags: [idol-of-savagery, pounce, bleed-mechanics, snapshot, wow-1.12.1]
requires: []
provides:
  - Pounce duration and ERPS tickInterval now respect Idol of Savagery snapshot
  - lastPounceEquippedSavagery recorded at both catAtk and catLeveling cast sites
affects: [catAtk, catLeveling]
tech-stack:
  added: []
  patterns: [savagery-snapshot]
key-files:
  created: []
  modified:
    - classes/druid/Druid.lua
    - classes/druid/combo.lua
    - classes/druid/leveling.lua
key-decisions:
  - "Followed existing Rake/Rip Savagery snapshot pattern for Pounce: pounceLeft() reduces duration by 10%, computePounce_Erps() reduces tickInterval by 10%"
  - "loginContext.lastPounceEquippedSavagery recorded at both cast sites (combo.lua catAtk opener + leveling.lua catLeveling opener), matching safeRake/safeRip pattern"
requirements-completed: []
duration: 5min
completed: 2026-08-04
status: complete
---

# Quick Task 260804-0bz: Fix Pounce Savagery Duration Summary

**Pounce duration and ERPS now account for Idol of Savagery snapshot, matching the existing Rake and Rip patterns.**

## Performance

- **Duration:** 5 min
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `pounceLeft()` now reduces Pounce duration by 10% when Savagery idol was equipped at cast time (18s -> 16.2s)
- `computePounce_Erps()` now reduces tick interval by 10% when Savagery idol was equipped at cast time
- `lastPounceEquippedSavagery` recorded at both cast sites: `combo.lua` catAtk opener and `leveling.lua` catLeveling opener

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix pounceLeft() and computePounce_Erps() in Druid.lua** - `f365098` (fix)
2. **Task 2: Record lastPounceEquippedSavagery at cast sites** - `c6f83a7` (fix)

## Files Modified
- `classes/druid/Druid.lua` - Added Savagery snapshot check to `pounceLeft()` (line ~1118) and `computePounce_Erps()` (line ~622)
- `classes/druid/combo.lua` - Record `lastPounceEquippedSavagery` after `player.pounce()` in catAtk opener (line ~139)
- `classes/druid/leveling.lua` - Record `lastPounceEquippedSavagery` after `player.pounce()` in catLeveling opener (line ~76)

## Decisions Made
- Followed existing Rake/Rip Savagery snapshot pattern for Pounce: `pounceLeft()` reduces duration by 10%, `computePounce_Erps()` reduces tickInterval by 10%, both gated by `macroTorch.loginContext.lastPounceEquippedSavagery`
- `loginContext.lastPounceEquippedSavagery` recorded at both cast sites (combo.lua catAtk opener + leveling.lua catLeveling opener), matching the `safeRake`/`safeRip` pattern in cat.lua

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

N/A - quick task, no follow-up phases.

## Self-Check: PASSED

- SUMMARY.md exists: yes
- Commit f365098 (Task 1) exists: yes
- Commit c6f83a7 (Task 2) exists: yes
- Modified files match expected (Druid.lua, combo.lua, leveling.lua): yes

---
*Phase: quick*
*Completed: 2026-08-04*