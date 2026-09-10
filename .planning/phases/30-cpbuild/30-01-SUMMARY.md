---
phase: 30-cpbuild
plan: 01
subsystem: instrumentation
tags: [lua, wow-1.12, cpbuild, dki, periodic-poll, double-keep, instrumentation]

# Dependency graph
requires:
  - phase: 28-cpdamage
    provides: macroTorch.cpBuildLog switch, cpBuildLogSample/cpBuildLogEvent emitters, macroTorch.log dual-write channel, static verification tooling precedent
  - phase: 27-catatk-event-driven-land-tracing-refactor
    provides: bbcheck.js bracket-balance gate (reused for the D-12 verification battery)
provides:
  - macroTorch.cpBuildDki state table (state/t0/prevCp) living outside macroTorch.context
  - macroTorch.cpBuildDkiTick 0.1s poll driver with locked cheap-first gate order
  - macroTorch.resetCpBuildDki global reset (D-04 bypass 2)
  - load-time registered periodic task 'cpBuildDkiPoll'
  - [cpBuildT] ok t=<sec> / [cpBuildT] fail persisted-line protocol via macroTorch.log
affects:
  - phase 30-cpbuild plan 02 (Category S-05..S-12 stubbed selftests pin this state machine)
  - phase 30-cpbuild plan 03 (tools/cpbuild.lua offline parser consumes the [cpBuildT] ok t= / fail line protocol)

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 1383
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "0.1s registerPeriodicTask poll with locked cheap-first gate order (switch check, combat check, then API call) — D-01/D-05 zero-cost off path"
    - "dedicated measurement state table outside macroTorch.context, cleared by explicit reset hooks wired into existing event branches"
    - "persisted telemetry line protocol with fixed 3-decimal t token for cross-artifact parser stability (D-06)"

key-files:
  created: []
  modified:
    - classes/druid/Druid.lua - DKI block: state init, resetCpBuildDki, cpBuildDkiTick, static 'cpBuildDkiPoll' registration (inserted after cpBuildLogEvent, before the cpDamage comment block)
    - core/events.lua - two D-04 bypass-2 reset calls inside the existing PLAYER_TARGET_CHANGED and PLAYER_REGEN_ENABLED branches

key-decisions:
  - "DKI state lives in a dedicated macroTorch.cpBuildDki table, not macroTorch.context — onCombatExit swaps the whole context table and would destroy the in-flight window (D-04/D-15 sibling decision)"
  - "all [cpBuildT] persistence flows through macroTorch.log and is gated by macroTorch.cpBuildLog; with the switch off the poll tick is two field reads and returns before GetComboPoints — zero client API calls (D-01)"
  - "the locked D-04 transition table was implemented verbatim: BUILDING cp>=5 checked before the down-jump branch; mid-window down-jump counts the fail denominator and re-anchors (kill-shot-on-dying-target variant logs fail once but does not re-anchor); DONE stays fully silent until the next down-jump"
  - "cp=0 back-look disambiguation via macroTorch.toBoolean(macroTorch.target.isCanAttack) evaluated only when a down-jump lands on 0 (short-circuit)"

patterns-established:
  - "Cheap-first gate ordering for poll ticks: switch read, then combat-idle read, only then GetComboPoints (mirrors cpDamageSample)"
  - "Global reset hooks join existing event branches only — zero new RegisterEvent, event surface frozen at 20"

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "DKI instrumentation block in classes/druid/Druid.lua — state table, reset function, poll driver with locked gate order and D-04 transition table, static 'cpBuildDkiPoll' registration"
    verification:
      - kind: other
        ref: "node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/Druid.lua (BALANCED)"
        status: pass
      - kind: other
        ref: "8 presence anchors grep battery + API-call census (GetComboPoints x1 / GetTime x4 / macroTorch.log x2) + registerPeriodicTask count = 1"
        status: pass
      - kind: other
        ref: "Lua 5.0 gates: no goto/label file-wide, zero added lines with the length-operator glyph; git diff --check clean"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-04 bypass-2 reset wiring in core/events.lua — reset first-statement of PLAYER_TARGET_CHANGED branch and post-onCombatExit line of PLAYER_REGEN_ENABLED branch, RegisterEvent surface frozen at 20"
    verification:
      - kind: other
        ref: "region/count grep gates: 2 call sites total, exactly 1 per branch region, RegisterEvent token count = 20"
        status: pass
      - kind: other
        ref: "node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js core/events.lua (BALANCED)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Runtime [cpBuildT] telemetry behavior — window measurement, ok/fail emissions and both reset paths as observed in-game (switch on, combat active)"
    verification: []
    human_judgment: true
    rationale: "No Lua runtime on this machine (D-14): the tick's runtime semantics are pinned by the planned Category S-05..S-12 stubbed selftests and the HUMAN-UAT.md Phase 30 observation protocol, both landing in plan 30-02 and executed on the user's Windows+Cygwin environment"

# Metrics
duration: 2 min
completed: 2026-09-10
status: complete
---

# Phase 30 Plan 01: cpBuild DKI Live Timer (tracer) Summary

**DKI (double-keep instrumentation) three-state 0.1s poll measuring bite-anchor-to-5-combo-points time, persisting `[cpBuildT] ok t=<sec>` / `[cpBuildT] fail` lines through macroTorch.log behind the existing macroTorch.cpBuildLog switch, with global-reset hooks on target change and combat exit.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-09-10T14:27:31Z
- **Completed:** 2026-09-10T14:29:17Z
- **Tasks:** 2 (1 tracer + 1 auto)
- **Files modified:** 2 (107 lines added, 0 deleted)

## Accomplishments

- DKI state machine delivered end-to-end on the tracer slice: poll tick → three-state machine → persisted line → reset hooks, all under the D-01 switch gate.
- Locked gate order enforced (D-01/D-05): `cpBuildLog` nil-check first, `inCombat` nil-check second, then `GetComboPoints()` — with the switch off, the 0.1s tick returns after two plain field reads, zero client API calls.
- Locked D-04 transition table implemented exactly: WAIT_ANCHOR / BUILDING / DONE; down-jump predicate `prevCp > 1 and cp <= 1`; cp=0 target back-look via `macroTorch.toBoolean(macroTorch.target.isCanAttack)`; BUILDING `cp >= 5` checked before the down-jump branch; bypass 1 mid-window truncation counts the fail denominator and re-anchors (kill-shot variant logs fail once and returns to WAIT_ANCHOR without re-anchoring); bypass 2 reset wires into the existing PLAYER_TARGET_CHANGED and PLAYER_REGEN_ENABLED branches.
- Line protocol byte-exact per D-06: `[cpBuildT] ok t=` .. `string.format('%.3f', t1 - t0)` and `[cpBuildT] fail`, t always 3 decimals for the plan 30-03 parser's tonumber.
- Load-time static registration `registerPeriodicTask('cpBuildDkiPoll', { interval = 0.1, task = macroTorch.cpBuildDkiTick })` — no conditional register/unregister; the pcall-guarded periodic driver (periodic.lua 140-149) contains any tick error.

## Task Commits

Each task was committed atomically:

1. **Task 1: DKI three-state live timer — poll, anchor, ok/fail emission, load-time registration** - `704f2dd` (feat)
2. **Task 2: Global reset wiring — PLAYER_TARGET_CHANGED and combat-exit hooks in core/events.lua** - `e128acd` (feat)

**Plan metadata:** committed separately after the SUMMARY (docs commit).

## Files Created/Modified

- `classes/druid/Druid.lua` - DKI block inserted immediately after `cpBuildLogEvent` (before the phase-28 cpDamage comment): provenance comment, `macroTorch.cpBuildDki = { state = 'WAIT_ANCHOR', t0 = nil, prevCp = nil }`, `macroTorch.resetCpBuildDki()`, `macroTorch.cpBuildDkiTick()`, and the static `cpBuildDkiPoll` registration
- `core/events.lua` - `macroTorch.resetCpBuildDki()` as the first statement of the PLAYER_TARGET_CHANGED branch and on the line after `macroTorch.onCombatExit()` in the PLAYER_REGEN_ENABLED branch

## State-Home Decision

The DKI state lives in a dedicated table `macroTorch.cpBuildDki` (fields `state`/`t0`/`prevCp`), deliberately OUTSIDE `macroTorch.context`. Combat exit swaps the whole context table (core/combat_context.lua 21-27), which would silently destroy an in-flight window mid-measurement; the dedicated home survives the swap and is cleared explicitly by `resetCpBuildDki` from the events hooks. That is also why the reset hook sits after `onCombatExit()` rather than relying on the context swap for cleanup.

## Verification Results (plan-level battery)

- bbcheck BALANCED on both modified files (exit 0)
- git diff --check clean on the cumulative diff
- Lua 5.0 gates: no goto/label tokens file-wide; zero added lines carrying the length-operator glyph (the two legacy `#` comment glyphs at Druid.lua 839/840 predate this plan and are not in added lines)
- SM_Extend.lua, core/combat_context.lua, macro_torch.lua absent from the diff (all read-only targets untouched)
- all 8 presence anchors of Task 1 present; both reset call sites present at exactly 2 total; RegisterEvent surface frozen at 20 (16 active + 4 commented)
- acceptie-criteria behavior traces (scripted tick drives) verified by reasoning against the locked table: 3→1→5 yields exactly one ok line; BUILDING mid-window down-jump yields exactly one fail line and re-anchors; kill-shot-on-dying-target yields one fail line and returns to WAIT_ANCHOR; DONE is silent until the next down-jump
- API-call census of the DKI block: `GetComboPoints()` x1, `GetTime()` x4, `macroTorch.log` x2 (one ok call site, one fail call site), nothing else

## D-14 Runtime Note

This machine has no Lua runtime, so the tick's runtime semantics are verified statically only. The stubbed-and-capture selftests (Category S-05..S-12, plan 30-02) and the Phase 30 HUMAN-UAT observation protocol will exercise the machine in-game on the user's Windows+Cygwin environment; the D-09 precondition (instrumentation must run in the target-state rotation, i.e. bite-only double-bleed upkeep, not the hard-Rake-supplement rotation) applies to any real T̄ observation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

One tooling quirk, not a plan deviation: the local `grep` binary is ugrep, which rejects the POSIX `'^\+\+\+'` pattern in Task 1's verify command verbatim; the gate was re-run with an equivalent awk filter (`awk '/^\+/ && !/^\+\+\+/'`), same semantics, result 0 (no added line carries the length-operator glyph). All other verify commands ran verbatim.

## Known Stubs

None — every deliverable in this plan is a real implementation wired to real data sources (the poll reads live combo points; emissions persist through macroTorch.log). No placeholder values, no TODO/FIXME, no unwired data paths were introduced.

## Next Phase Readiness

- Ready for plan 30-02 (Category S-05..S-12 stubbed selftests pin this exact state machine; HUMAN-UAT.md Phase 30 section) and plan 30-03 (tools/cpbuild.lua offline parser consuming the `[cpBuildT] ok t=` / `[cpBuildT] fail` line protocol)
- No blockers: the tracer slice compiles through the existing gates and the runtime verification path is already scoped to 30-02

---
*Phase: 30-cpbuild*
*Completed: 2026-09-10*

## Self-Check: PASSED