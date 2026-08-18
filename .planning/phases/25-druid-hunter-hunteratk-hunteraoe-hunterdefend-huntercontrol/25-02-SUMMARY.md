---
phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol
plan: 02
subsystem: hunter
tags: [combo-macro, hunter, wow-addon, lua, distance-routing]

# Dependency graph
requires:
  - phase: 25-01
    provides: Hunter.lua with 25 skill methods, SpellTrace, SelfTest
provides:
  - classes/hunter/combo.lua — 5 Hunter one-button combo macro functions
  - hunterAtk() — distance routing entry (<8yd melee, >=8yd ranged) with 8+6 module chains
  - hunterAoe() — distance routing AoE (ranged Multi-Shot/Volley, melee Explosive/Immolation Trap)
  - hunterDefend() — Deterrence-only defense
  - hunterControl() — distance routing control (melee Wing Clip/Freezing Trap, ranged Concussive/Scatter Shot)
  - hunterMobTagging() — PvP-filtered mob tagging with auto-chain to hunterAtk()
  - 5 SelfTest registrations (all isOptional=true + UnitClass guard)
affects: [25-03, hunter-keybinding, hunter-ui]

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 3084
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Distance routing (<8yd melee / >=8yd ranged) replaces Druid form routing
    - 8-module priority chain for ranged attack (urgentHP -> targetEnemy -> startAutoShoot -> burstMod -> openerMod -> stingMod -> coreDPSMod -> otMod)
    - 6-module priority chain for melee attack (urgentHP -> targetEnemy -> startAutoAtk -> burstMod(no Aimed) -> coreMeleeMod -> otMod)
    - burstMod Shift-gated pattern with macroTorch.context.burstFlags state machine
    - hunterMobTagging PvP filter with ClearTarget() double-check pattern (aligned with druidMobTagging)
    - Auto-chain pattern: tag confirmed via target.isAttackingMe -> transition to hunterAtk()

key-files:
  created:
    - classes/hunter/combo.lua (316 lines) — Hunter one-button combo macro functions + SelfTest
  modified: []

key-decisions:
  - "Task 1: hunterAtk distance routing with 8+6 module chains, no Aspect/Pet/Trap logic per D-06/D-07/D-08"
  - "Task 2: hunterAoe/hunterControl/hunterMobTagging all follow distance routing pattern, SelfTest extended to 5"

patterns-established:
  - "Distance routing: target.distance < 8 as the Hunter equivalent of Druid form-routing"
  - "burstMod with burstFlags state machine: Shift to set, then consume flags in priority order"

requirements-completed: [H-03, H-04, H-05, H-06, H-07, H-08, D-01, D-02, D-03, D-04, D-05, D-06, D-07, D-08, D-13, D-14, D-15, D-16, D-17, D-18, D-19]

# Coverage metadata (#1602) — one entry per shipped deliverable. Drives DETERMINISTIC UAT routing in verify-work.
coverage:
  - id: D1
    description: "hunterAtk() distance routing entry — routes to hunterAtkMelee (<8yd) or hunterAtkRanged (>=8yd)"
    requirement: D-01
    verification:
      - kind: unit
        ref: "grep 'function macroTorch.hunterAtk()' classes/hunter/combo.lua + grep 'distance < 8'"
        status: pass
    human_judgment: false
  - id: D2
    description: "hunterAtkRanged() 8-module priority chain — combatUrgentHPRestore, targetEnemy, startAutoShoot, burstMod, openerMod, stingMod, coreDPSMod, otMod"
    requirement: D-02
    verification:
      - kind: unit
        ref: "grep 'function macroTorch.hunterAtkRanged()' classes/hunter/combo.lua — 8 modules present"
        status: pass
    human_judgment: false
  - id: D3
    description: "hunterAtkMelee() 6-module priority chain — combatUrgentHPRestore, targetEnemy, startAutoAtk, burstMod, coreMeleeMod, otMod"
    requirement: D-03
    verification:
      - kind: unit
        ref: "grep 'function macroTorch.hunterAtkMelee()' classes/hunter/combo.lua — 6 modules present"
        status: pass
    human_judgment: false
  - id: D4
    description: "hunterAoe() distance routing — ranged Multi-Shot->Volley, melee Explosive Trap->Immolation Trap"
    requirement: D-13
    verification:
      - kind: unit
        ref: "grep 'function macroTorch.hunterAoe()' classes/hunter/combo.lua"
        status: pass
    human_judgment: false
  - id: D5
    description: "hunterDefend() — Deterrence-only defense check"
    requirement: D-14
    verification:
      - kind: unit
        ref: "grep 'function macroTorch.hunterDefend()' classes/hunter/combo.lua"
        status: pass
    human_judgment: false
  - id: D6
    description: "hunterControl() distance routing — melee Wing Clip/Freezing Trap, ranged Concussive Shot/Scatter Shot"
    requirement: D-15
    verification:
      - kind: unit
        ref: "grep 'function macroTorch.hunterControl()' classes/hunter/combo.lua"
        status: pass
    human_judgment: false
  - id: D7
    description: "hunterMobTagging() PvP filter + distance tag (Arcane Shot R1 ranged, Wing Clip melee) + auto-chain to hunterAtk()"
    requirement: D-16
    verification:
      - kind: unit
        ref: "grep 'function macroTorch.hunterMobTagging()' classes/hunter/combo.lua + grep 'ClearTarget' + grep 'isAttackingMe'"
        status: pass
    human_judgment: false
  - id: D8
    description: "5 SelfTest registrations (hunterAtk, hunterAoe, hunterDefend, hunterControl, hunterMobTagging), all isOptional=true + UnitClass guard"
    requirement: D-20
    verification:
      - kind: unit
        ref: "grep -c 'SelfTest:register' classes/hunter/combo.lua returns 5"
        status: pass
    human_judgment: false

# Metrics
duration: not tracked (continuation agent)
completed: 2026-08-19
status: complete
---

# Phase 25 Plan 02: Hunter combo.lua Summary

**Created 5 Hunter one-button combo macro functions with distance-routing architecture, aligned with Druid combo.lua patterns**

## Performance

- **Duration:** Not tracked (executed as continuation agent)
- **Tasks:** 2
- **Files modified:** 1 (316 lines total)

## Accomplishments
- hunterAtk() distance routing entry with 14 total priority chain modules (8 ranged + 6 melee)
- hunterAoe() / hunterControl() / hunterMobTagging() all using distance routing pattern
- hunterDefend() Deterrence-only defense, minimal implementation per D-14
- hunterMobTagging() with PvP filter (ClearTarget for player targets) and auto-chain to hunterAtk()
- 5 SelfTest registrations covering all public combo functions, all isOptional=true + UnitClass guard
- No Aspect, Pet, or Trap logic in hunterAtk modules (D-06/D-07/D-08 compliant)

## Task Commits

Each task was committed atomically:

1. **Task 1: combo.lua 核心架构 — hunterAtk 距离路由 + hunterAtkRanged 模块链 + hunterAtkMelee + hunterDefend** - `ac77456` (feat)
2. **Task 2: combo.lua 扩展 — hunterAoe + hunterControl + hunterMobTagging + 完整 SelfTest** - `f4141bd` (feat)

## Files Created/Modified
- `classes/hunter/combo.lua` (316 lines) — 5 public Hunter one-button combo macro functions + 2 internal helpers + 5 SelfTest registrations

### Public macro functions (5):
- `macroTorch.hunterAtk()` — distance routing entry (<8yd -> hunterAtkMelee(), >=8yd -> hunterAtkRanged())
- `macroTorch.hunterAoe()` — AoE with distance routing (ranged Multi-Shot->Volley, melee Explosive Trap->Immolation Trap)
- `macroTorch.hunterDefend()` — defense, Deterrence only
- `macroTorch.hunterControl()` — control with distance routing (melee Wing Clip/Freezing Trap, ranged Concussive Shot/Scatter Shot)
- `macroTorch.hunterMobTagging()` — mob tagging with PvP filter + distance routing tag + auto-chain to hunterAtk()

### Internal helper functions (2):
- `macroTorch.hunterAtkRanged()` — 8-module priority chain for ranged combat
- `macroTorch.hunterAtkMelee()` — 6-module priority chain for melee combat

## Decisions Made
- Followed Druid combo.lua distance-routing architecture exactly as specified in plan
- All 5 SelfTest registrations use isOptional=true + UnitClass guard as specified
- hunterAoe melee branch uses Explosive Trap first (higher priority damage), Immolation Trap as fallback
- hunterControl uses two independent actions per distance branch (both Wing Clip + Freezing Trap, or both Concussive + Scatter Shot) to maximize control output

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all verification checks passed on first attempt, build succeeded without errors.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All 5 Hunter combo macros built and verified, ready for plan 25-03 (keybinding integration)
- build.sh passes, combo.lua is registered in build_order.txt
- No blockers

---
*Phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol*
*Completed: 2026-08-19*