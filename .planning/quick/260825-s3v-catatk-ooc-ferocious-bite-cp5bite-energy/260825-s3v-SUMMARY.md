---
phase: quick-260825-s3v
plan: 01
subsystem: gameplay-automation
tags: [wow-addon, lua, catAtk, feral-druid, ooc, cp5bite, energy-discharge]

# Dependency graph
requires: []
provides:
  - "OoC-discharge-only cp5Bite path: rejected discharge casts can no longer fall through into a free Ferocious Bite"
  - "Per-frame discharge-attempt dedup via clickContext.isDischarged (covers termMod-after-oocMod double entry and quickKeepRip)"
affects: [catAtk rotation behavior, Ferocious Bite energy economics]

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 160    # 640 added chars / 4 over classes/druid/cat.lua
  tasks: 3
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-frame cast dedup via a clickContext marker field (isDischarged) instead of module-level state"

key-files:
  created: []
  modified:
    - classes/druid/cat.lua

key-decisions:
  - "Guard placed inside the shouldDischarge block, after the discharge call, so shouldDischarge=false direct-bite branches (isPseudoInfiniteEnergy, ripLeft <= 2.3) still reach readyBite/safeBite unchanged"
  - "isDischarged marker set only after a discharge cast attempt; frame-scoped by per-keystroke clickContext rebuild (combo.lua line 55), so no reset logic is needed"
  - "Followed the plan's single-atomic-commit specification (Task 3) instead of per-task commits; SM_Extend.lua (gitignored build artifact) excluded from staging"

patterns-established:
  - "Frame-scoped dedup guard: entry `if clickContext.isDischarged then return end` plus post-cast marker per discharge branch"

requirements-completed:
  - QUICK-260825-S3V

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Fix the unintended OoC free Ferocious Bite path: cp5Bite becomes discharge-only on OoC frames, and energyDischargeBeforeBite dedups same-frame discharge attempts"
    requirement: QUICK-260825-S3V
    verification:
      - kind: other
        ref: "bash build.sh (exit 0); grep gate: '^ *if clickContext.isDischarged then' == 1, 'clickContext.isDischarged = true' == 2, cp5Bite-body ooc checks == 2; diff -U0 hunks confined to cp5Bite + energyDischargeBeforeBite"
        status: pass
      - kind: manual_procedural
        ref: "in-game /mt self-test — 'P: cp5Bite triggers bite at 5CP in fast battle without Rip or immunity' (core/selftest.lua:783-815)"
        status: unknown
    human_judgment: true
    rationale: "No headless Lua runtime exists in this environment (Phase 26 convention) — the full self-test suite only runs in-game via /mt. Non-blocking; confirmed on the user's next login."

# Metrics
duration: 10min
completed: 2026-08-25
status: complete
---

# Quick 260825-s3v: catAtk OoC Ferocious Bite Fix Summary

OoC 5CP frames now discharge-only inside cp5Bite with per-frame discharge dedup, so a discharge the game silently rejects can never fall through into a free Ferocious Bite — the bite verdict is re-sampled on the next click from a fresh player.isOoc.

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-08-25
- **Tasks:** 3 completed
- **Files modified:** 1 (classes/druid/cat.lua, +14 lines, 0 deletions)

## Accomplishments

- `macroTorch.cp5Bite`: after the `energyDischargeBeforeBite(clickContext)` attempt, `if clickContext.ooc then return end` discharges-only on OoC frames; non-OoC 5CP frames still fall through to safeBite, and shouldDischarge=false frames still reach readyBite/safeBite directly
- `macroTorch.energyDischargeBeforeBite`: entry guard `if clickContext.isDischarged then return end` plus `clickContext.isDischarged = true` set after each discharge cast attempt — a same-click double entry (termMod after oocMod, or quickKeepRip) makes at most one discharge attempt
- build.sh exits 0; the P-06 selftest (core/selftest.lua:783-815) is semantically unaffected — its ctx (ooc=false, isPseudoInfiniteEnergy=true) never enters the shouldDischarge block and stubs energyDischargeBeforeBite, so both asserts keep passing

## Task Commits

The plan's locked Task 3 spec requires a single atomic commit for the whole change (not per-task commits):

1. **Tasks 1-3: guard insertions + regression verification + diff-scope gate** — `ebca501` (fix(cat): OoC frames only discharge in cp5Bite; dedup discharge attempts per frame)

**Plan metadata:** `f5abb67` (docs, pre-dispatch — handled by the quick-task orchestrator)

## Files Created/Modified
- `classes/druid/cat.lua` — 14-line additive change confined to two functions: OoC guard in cp5Bite's shouldDischarge block, isDischarged dedup in energyDischargeBeforeBite

## Decisions Made
None — the locked design (six decisions from planning) was implemented exactly as written: inside-block guard placement, `clickContext.ooc` condition instead of unconditional return, marker set only after a cast attempt, frame-scoped marker with no reset logic, no edits to any other function, no selftest edits

## Deviations from Plan

None of substance — plan executed exactly as written. One cosmetic note: a blank line was added after the Task 2 entry-guard `end` (part of insertion (a)) to keep the function's visual block separation consistent; it changes no existing line and adds no logic.

## Automotive Verification Summary

- `bash build.sh` → exit 0
- `sed -n '113,145p' classes/druid/cat.lua | grep -c 'if clickContext.ooc then'` → 2 (new guard + unchanged selection)
- `grep -c '^ *if clickContext.isDischarged then'` → 1; `grep -c 'clickContext.isDischarged = true'` → 2
- `git diff -U0` hunks: 4 hunks, all inside cp5Bite / energyDischargeBeforeBite (new-file lines 136-178); zero changes in any other function
- Commit contains only classes/druid/cat.lua; SM_Extend.lua confirmed gitignored (`!!`) and excluded

## Pending Human Check (non-blocking)

- In-game `/mt` self-test run on next login: "P: cp5Bite triggers bite at 5CP in fast battle without Rip or immunity" must stay green together with the rest of the suite (core/selftest.lua:783-815, unchanged)

## Self-Check: PASSED

- `classes/druid/cat.lua` exists and contains all three guard insertions (verified via sed/grep windows)
- Commit `ebca501` verified in `git log` with exactly 1 file changed, +14/-0