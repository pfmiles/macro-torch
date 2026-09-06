---
phase: quick-260907-0ya-macrotorch-false-true-macrotorch-log
plan: 01
subsystem: druid catAtk combo-point cast logging
tags: [cpBuildLog, combo-points, cast-logging, macrotorch-log, selftest, double-bleed]
status: complete
completed: 2026-09-07
---

# Quick 260907-0ya: macroTorch.cpBuildLog — opt-in Combo-point cast logging for double-keep measurement

Adds a macroTorch-namespaced boolean switch `macroTorch.cpBuildLog` (nil-guarded
default false, re-armed on every addon load, togglable live in game with no reload)
that turns on combo-point building cast logging for the cat-form DPS rotation: every
accepted Claw/Shred/Rake cast appends one persisted
`[cpBuild] <Skill> t=<GetTime()> cp=<n> e=<n>` line through the existing
`macroTorch.log` (interface_debug.lua → MACRO_TORCH_LOG SavedVariable), giving the
player offline-interval data (average wait interval k and window distribution
stratified by combo points and energy) to settle the double-bleed maintenance
criterion (双保判据). Off-state is zero-cost: the `macroTorch.cpBuildLog and ... or
nil` short-circuit in each of the three skill wrappers means the sample helper is
never invoked, no API calls, no output, and no loop-file change at all.

## Tasks

| Task | Result | Commit |
|------|--------|--------|
| T1: cpBuildLog switch (macro_torch.lua) + Claw/Shred/Rake cast-log hooks (Druid.lua) | done — 46 insertions, 3 deletions | 30ef165 |
| T2: Category S selftests S-01..S-03 (classes/druid/selftest.lua) | done — 63 insertions, 0 deletions | 90ef069 |

## Implementation Notes

- macro_torch.lua: nil-guarded block appended after the `if not macroTorch then`
  guard — `if macroTorch.cpBuildLog == nil then macroTorch.cpBuildLog = false end`.
  The nil-guard (not unconditional assignment) is load-bearing: anything the player
  sets in game later in the session wins; only a fresh addon load re-arms false.
  macro_torch.lua is the first file in build_order.txt, so the switch is armed before
  any macro body can run.
- Druid.lua wrapper shape per skill: `local cpLog = macroTorch.cpBuildLog and
  macroTorch.cpBuildLogSample() or nil` runs BEFORE `obj._castSpell(...)` (the instant
  cast starts the GCD and would falsify a post-cast GCD reading); then
  `if cast and cpLog and cpLog.gcdOk then macroTorch.cpBuildLogEvent('Claw', cpLog)`
  and `return cast`. Locale tables, computeX_E references, and Rip/FB/Pounce/... all
  byte-identical.
- Helpers inserted in the gap between `macroTorch.Druid:new()`'s closing `end` and the
  `-- player fields to function mapping` comment, one blank line each side, file
  indent level 0, 4-space body indentation.
- `cpBuildLogSample` returns `{ t = GetTime(), cp = macroTorch.player.comboPoints,
  e = macroTorch.player.mana, gcdOk = macroTorch.player.isActionCooledDown(
  'Ability_Druid_Rake') }` — the same action-slot texture scan as
  macroTorch.isGcdOk, so the log's cast-acceptance gate agrees with the rotation's
  own GCD semantics and spam-key phantom entries are excluded.
- `cpBuildLogEvent` formats the fixed field order skill t cp e through macroTorch.log,
  which both shows in chat and appends to the bounded MACRO_TORCH_LOG.messages
  SavedVariable (existing persistence, unchanged).
- Choke-point coverage: catAtk / safeRake / druidMobTagging / catLeveling all flow
  through the three hooked wrappers; no CastSpellByName bypass exists.
- Category S block inserted between the Q-10 register closer (line 985) and the
  file-closing `end` (line 987) with 1-tab register/comment indentation matching Q;
  S-01 pins the false default; S-02 pins the byte-exact
  `[cpBuild] Claw t=12.34 cp=3 e=62` line via a captured macroTorch.log stub; S-03
  drives the real obj.claw wrapper with _castSpell (returns true) + isActionCooledDown
  + log stubbed, locking on+ready logs exactly 1 / GCD-blocked logs 0 / off logs 0
  (and short-circuits the sample). CR-01 stub discipline: rawget snapshots, own-key
  shadows, restore via rawset BEFORE any assert; all `isOptional=true`.
- SM_Extend.lua NOT rebuilt (established convention: build artifact regenerated only
  on explicit project rebuild; recent quick tasks did not touch it).

## Verification

- T1 gate PASSED (initial + re-run): bbcheck `BALANCED` (exit 0) on macro_torch.lua
  and classes/druid/Druid.lua; nil-guarded `macroTorch.cpBuildLog = false` default
  present; exactly 3 `cpBuildLogSample() or nil` hook lines and 3 `cpBuildLogEvent(`
  calls; sample helper carries t/cp/e/gcdOk fields; event helper formats
  `[cpBuild] ` + skill + ` t=` + ` cp=` + ` e=` through macroTorch.log.
- T2 gate PASSED (initial + re-run): bbcheck `BALANCED` on classes/druid/selftest.lua;
  exactly 3 `"Cat S-0` registrations; `Category S adds 3 tests` comment present;
  CR-01 `rawset(player, '_castSpell', savedCast)` restore line present; byte-exact
  expected-format literal present; awk range gate confirms default-false assert,
  restore-before-asserts discipline, and nOn==1 / nGcd==0 / nOff==0 assertions.
- T3 token gate: `T3 LUA50 TOKEN GATE OK` — diff adds no `goto`, no `#` length
  operator, no labels (Lua 5.0 constraint, user memory wow-lua50-syntax).
- `git diff --check` clean (LF, no trailing whitespace); `git status --porcelain`
  shows only the three source files (both now committed; tree clean) — SM_Extend.lua
  untouched.
- R4 loop-semantics proof: `git diff --stat HEAD~2 HEAD --` on
  classes/druid/cat.lua, classes/druid/combo.lua, entity/Player.lua,
  core/events.lua, interface_debug.lua is empty — rotation/loop files byte-identical.
- In-game confirmation (S-01..S-03 on /mt, plus the manual toggle + training-dummy
  measurement and WTF SavedVariables retrieval) is the optional user_setup follow-up —
  the measurement itself is the user's intended offline analysis and cannot be
  automated here (no headless Lua 5.0 runtime exists in this repo, established
  convention).

## Deviations from Plan

None — plan executed exactly as written; all gates passed on first run. One
pre-existing untracked file `es.txt` in the repo root (created before this task's
session) was observed and left untouched — not part of this task's diff.

## Threat Flags

None. No new trust-boundary crossing; the two threats in the plan's STRIDE register
(T-quick-260907-0ya-01 information disclosure, -02 bounded-buffer DoS) remain `accept`
at low severity: the feature writes only the player's own cast metadata to their own
chat and SavedVariables, is off by default, and rotates within the pre-existing 500-
line MACRO_TORCH_LOG cap.

## Known Stubs

None. No placeholders, TODOs, or unwired data paths introduced. The switch, helpers,
and selftests are fully wired; the only "inert until toggled" behavior is the
designed off-state short-circuit.

## Self-Check: PASSED

- macro_torch.lua, classes/druid/Druid.lua committed (30ef165); classes/druid/
  selftest.lua committed (90ef069)
- SUMMARY.md present at
  `.planning/quick/260907-0ya-macrotorch-false-true-macrotorch-log/260907-0ya-SUMMARY.md`