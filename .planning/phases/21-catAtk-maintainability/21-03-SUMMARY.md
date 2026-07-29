---
phase: 21-catAtk-maintainability
plan: "03"
subsystem: comments
tags: [catatk, druid, keeprake, atkburst, maintainability]

# Dependency graph
requires:
  - phase: "21-02"
    provides: "isPseudoInfiniteEnergy centralization in clickContext across combo.lua + cat.lua + Druid.lua"
provides:
  - keepRake ATK burst side-effect documented with [SIDE EFFECT] comment block explaining design rationale
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - classes/druid/cat.lua

key-decisions:
  - "D-08: Scheme A — comment block annotation only, zero code changes. Documents why atkPowerBurst is called in keepRake: (1) AP snapshot maximizes Rake bleed, (2) burstMod handles manual Shift-key coordination while this is automated optimization for high-value targets"
  - "D-09: Third and final commit of Phase 21: docs(catAtk): annotate ATK burst side effect in keepRake"

patterns-established: []

requirements-completed: [REQ-21-KEEPRAKE-CLEANUP]

# Coverage metadata
coverage:
  - id: D1
    description: "keepRake ATK burst side-effect annotated with 6-line [SIDE EFFECT] comment block above atkPowerBurst call"
    requirement: REQ-21-KEEPRAKE-CLEANUP
    verification:
      - kind: other
        ref: "./build.sh exits 0, SM_Extend.lua non-empty (8318 lines)"
        status: pass
      - kind: other
        ref: "grep 'SIDE EFFECT' classes/druid/cat.lua returns 1, grep 'SIDE EFFECT' SM_Extend.lua returns 1"
        status: pass
      - kind: other
        ref: "git diff shows only -- comment line additions in keepRake, executable code unchanged"
        status: pass
      - kind: other
        ref: "Cross-file verification: 0-12 numbering, KillShot 11 occurrences, isPseudoInfiniteEnergy 6 refs, zero old comparisons, 3 preserved functions intact"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase 21 final verification — all 4 items complete across all 3 files, build passes"
    verification:
      - kind: other
        ref: "All 8 verification greps pass (comment numbering, KillShot count, isPseudoInfiniteEnergy refs, old comparison absence, SIDE EFFECT presence, preserved functions, build output)"
        status: pass
    human_judgment: false

# Metrics
duration: 4min
completed: 2026-07-29
status: complete
---

# Phase 21 Plan 03: keepRake ATK burst side-effect annotation

**Annotate the ATK burst side-effect in keepRake with a 6-line [SIDE EFFECT] comment block explaining why atkPowerBurst is called here for high-value targets, completing Phase 21's 4 maintainability improvements.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-29T14:28:46Z
- **Completed:** 2026-07-29T14:32:42Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Added 6-line [SIDE EFFECT] comment block above the atkPowerBurst call in keepRake, documenting: (1) AP snapshot maximizes Rake bleed damage for entire duration, (2) placed in keepRake rather than burstMod because burstMod handles manual Shift-key coordination while this is an automated optimization for high-value targets
- Zero executable code changes — the git diff shows only comment line replacements in keepRake
- `./build.sh` exits 0, SIDE EFFECT comment survives concatenation in SM_Extend.lua
- Phase 21 complete — all 4 items implemented, 3 commits total matching D-09 commit strategy

## Task Commits

Each task was committed atomically:

1. **Task 1 (auto): Add [SIDE EFFECT] comment block above atkPowerBurst call in keepRake** - `1f7facc` (docs)
2. **Task 2 (auto): Final cross-file verification — all 4 Phase 21 items complete** - verification-only (no code changes)

## Files Modified
- `classes/druid/cat.lua` — Replaced simple comment `-- boost attack power to rake when fighting world boss` with 6-line [SIDE EFFECT] comment block at lines 312-317 of keepRake function

## Decisions Made
Followed decisions D-08 and D-09 from 21-CONTEXT.md exactly as specified:
- D-08: Scheme A — comment block annotation only, zero code changes, keeping the atkPowerBurst call in keepRake but documenting why it belongs here rather than in burstMod
- D-09: Third and final commit `docs(catAtk): annotate ATK burst side effect in keepRake` completes the 3-commit strategy

## Deviations from Plan
None — plan executed exactly as written. Both tasks passed all acceptance criteria on first attempt.

## Phase 21 Final Verification

All 8 cross-file verification checks passed:

| # | Check | Result |
|---|-------|--------|
| 1 | `./build.sh` exit 0 | PASS |
| 2 | Comment numbering 0-12 continuous in combo.lua | PASS |
| 3 | KillShot comments: 11 total (cat.lua: 9, combo.lua: 2) | PASS |
| 4 | isPseudoInfiniteEnergy: 6 refs (1 assign + 5 reads) | PASS |
| 5 | Zero remaining old `computeErps >= SHRED_E` comparisons | PASS |
| 6 | SIDE EFFECT annotation: 1 occurrence in cat.lua | PASS |
| 7 | 3 preserved functions (shouldDoReshift, shouldCastFFDuringWaitWindow, recoverNormalRelic) unchanged | PASS |
| 8 | Build output: isPseudoInfiniteEnergy (6x) and SIDE EFFECT (1x) survive concatenation | PASS |

## Issues Encountered
None.

## Known Stubs
None — this is a pure comment addition with zero behavior impact. No placeholders, TODO markers, or unwired data sources were introduced.

## Next Phase Readiness
Phase 21 (catAtk maintainability) is complete. All 4 items implemented across 3 commits:
1. `38980b1` — docs(catAtk): fix comment numbering and add KillShot design intent comments (Wave 1)
2. `12aac43` — refactor(catAtk): centralize isPseudoInfiniteEnergy in clickContext (Wave 2)
3. `1f7facc` — docs(catAtk): annotate ATK burst side effect in keepRake (Wave 3)

---
*Phase: 21-catAtk-maintainability*
*Completed: 2026-07-29*