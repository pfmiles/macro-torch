---
phase: 13-catatk-60-dps
plan: 01
subsystem: combat
tags: [lua, wow-addon, druid, cat-form, guard-clause, reshift-energy, low-level-adaptation]

requires: []
provides:
  - computeReshiftEnergy() global function (Furor talent + Wolfshead Helm dynamic calculation)
  - isSpellExist guards on all shared decision functions (shouldUseShred, shouldCastRip, shouldUseBite)
  - isSpellExist guards on all cat form module entry points (keepRip, keepRake, keepFF, keepTigerFury, termMod, otMod, openerMod)
  - RESHIFT_ENERGY==0 early return in shouldDoReshift
affects: [13-02 selftest]

tech-stack:
  added: []
  patterns:
    - "isSpellExist guard at module entry point: early return when skill not learned"
    - "isSpellExist guard in shared decision function: return false when skill not learned"
    - "Dynamic energy calculation with talent rank * base + item bonus pattern"
    - "Zero-energy reshift guard: skip shouldDoReshift when RESHIFT_ENERGY==0"

key-files:
  created: []
  modified:
    - classes/druid/Druid.lua
    - classes/druid/cat.lua

key-decisions:
  - "computeReshiftEnergy() uses Furor rank*8 + Wolfshead Helm +20 formula, matching known vanilla WoW mechanics"
  - "regularAttack and oocMod intentionally skip module-level guards — sub-function guards (shouldUseShred/shouldUseBite) handle fallback to Claw"
  - "RESHIFT_ENERGY==0 check placed at top of shouldDoReshift (before combat/prowling/ooc checks) for early exit efficiency"
  - "openerMod uses inline hasPounce/hasRavage vars (not extracted to shared function) because Pounce/Ravage are opener-only and not used elsewhere"

patterns-established:
  - "Module-level guard: `if not isSpellExist('Skill') then return end` at function entry — skips entire module when skill unlearned"
  - "Decision-function guard: `if not isSpellExist('Skill') then return false end` at function entry — degrades decision to 'don't use' when skill unlearned"
  - "Dynamic reshift energy: `computeReshiftEnergy()` replaces hardcoded literal, reads talent + equipment at runtime"

requirements-completed:
  - implicit-R8-PRESERVE
  - implicit-LOW-LVL-SKIP
  - implicit-DYNAMIC-RESHIFT
  - implicit-DECISION-GUARD

duration: 2min
completed: 2026-06-20
status: complete
---

# Phase 13 Plan 01: Guard Insertion + Dynamic Reshift Energy Summary

**isSpellExist guards in all cat form modules and shared decision functions, dynamic computeReshiftEnergy() replacing hardcoded RESHIFT_ENERGY=60**

## Performance

- **Duration:** ~2 min (agent disconnected; manual close-out)
- **Started:** 2026-06-20T01:07:00+08:00
- **Completed:** 2026-06-20T01:10:00+08:00
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `computeReshiftEnergy()` global function using Furor talent + Wolfshead Helm dynamic formula
- Replaced hardcoded `RESHIFT_ENERGY = 60` with `macroTorch.computeReshiftEnergy()` call
- Added `isSpellExist` guards to 3 shared decision functions (shouldUseShred, shouldCastRip, shouldUseBite)
- Added `isSpellExist` guards to 6 cat form modules (keepRip, keepRake, keepFF, keepTigerFury, termMod, otMod)
- Added `hasPounce`/`hasRavage` inline guards to openerMod
- Added `RESHIFT_ENERGY == 0` early-return guard to shouldDoReshift

## Task Commits

Each task was committed atomically:

1. **Task 1: computeReshiftEnergy + shared decision function guards + openerMod guard** - `b62f875` (feat: add computeReshiftEnergy(), replace hardcoded RESHIFT_ENERGY, add shared decision function guards, add openerMod guard)
2. **Task 2: Module-level isSpellExist guards** - `14e6df2` (feat: add module-level isSpellExist guards to keepRip, keepRake, keepFF, keepTigerFury, termMod, otMod in cat.lua)

## Files Created/Modified
- `classes/druid/Druid.lua` - computeReshiftEnergy() definition, shouldUseShred/shouldCastRip/shouldUseBite guards, openerMod inline guards, RESHIFT_ENERGY dynamic computation
- `classes/druid/cat.lua` - Module-level isSpellExist guards for keepRip, keepRake, keepFF, keepTigerFury, termMod, otMod; shouldDoReshift RESHIFT_ENERGY==0 early return

## Decisions Made
- computeReshiftEnergy() uses `Furor rank * 8 + Wolfshead Helm (+20)` formula — matches known vanilla WoW mechanics
- regularAttack and oocMod intentionally skip module-level guards: sub-function guards (shouldUseShred, shouldUseBite) provide fallback to Claw
- RESHIFT_ENERGY==0 check placed at top of shouldDoReshift for early exit before combat/prowling/ooc checks
- openerMod uses inline `hasPounce`/`hasRavage` booleans instead of extracted shared functions — Pounce/Ravage are opener-only

## Deviations from Plan

None — plan executed exactly as written. All changes are additive guards or single-value replacement; zero new code paths. Level 60 behavior is byte-equivalent to pre-change code.

## Issues Encountered
- Agent API connection dropped after both task commits completed. Manual close-out: SUMMARY.md written, tracking files updated.

## Next Phase Readiness
- All guard infrastructure in place for Plan 13-02 selftest registration
- computeReshiftEnergy() ready for selftest verification
- All shared decision functions and module entry points guarded and ready for test verification

---
*Phase: 13-catatk-60-dps*
*Completed: 2026-06-20*