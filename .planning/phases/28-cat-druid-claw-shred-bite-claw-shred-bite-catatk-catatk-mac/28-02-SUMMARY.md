---
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
plan: "02"
subsystem: instrumentation
tags: [lua-5.0, raw-combatlog, json, selftest, catatk-damage-instrumentation]

# Dependency graph
requires:
  - plan: "28-01"
    provides: "cpDamageLog switch, jsonEncodeScalar encoder, cpDamageSample/cpDamageCast/pairCpDamageIntent/onCpDamageLine/cpDamageEvent chain, SELF_DAMAGE channel gate"
  - phase: 27-catatk-event-driven-land-tracing-refactor
    provides: "LAND_INTENT_TTL(=2) + LRUStack + bbcheck.js verification gate"
provides:
  - "three-skill cpDamage cast-side hooks: shred joins claw, ferocious_bite gains its first sampling structure (cpDamage-only, no cpBuild) - D-07/D-08/D-09"
  - "Category U self-tests U-01..U-09: switch default, encoder literals, fixed 11-field emit literal (28-03 decoder interop contract), pairing window, TTL purge, miss zero-emit, crit mark, Training Dummy hard gate"
affects: ["28-03 (decoder side checked against the U-03 literal)", "28-04 (user-machine UAT with the cpDamageSample x4 / Cat U x9 count anchors)"]

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 3085
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns: ["three-skill isomorphic cpDamage hook triple ('claw', computeClaw_E()) / ('shred', computeShred_E()) / ('bite', 35)", "CR-01 rawget snapshot / own-key shadow / rawset restore discipline applied across the cpDamage chain tests"]

key-files:
  created: []
  modified: ["classes/druid/Druid.lua", "classes/druid/selftest.lua"]

key-decisions:
  - "U-02/U-03 expected literals hand-derived from the 28-01 encoder/emitter contract and byte-verified offline with a node simulation of the file literals (no local Lua interpreter)"

patterns-established:
  - "Category U block styling mirrors Category S/T: header comment + stub-discipline note + per-category registration count comment at the tail"

requirements-completed: [D-03, D-05, D-06, D-07, D-08, D-09, R8]

# Coverage metadata (#1602) — one entry per shipped deliverable.
coverage:
  - id: D1
    description: "shred + ferocious_bite cpDamage hooks - three-skill cast-side sampling: token/energyCost triple ('claw', computeClaw_E()) / ('shred', computeShred_E()) / ('bite', 35); bite cpDamage-only with cpBuild range lock"
    requirement: "D-08"
    verification:
      - kind: other
        ref: "bbcheck BALANCED + build.sh + grep -c cpDamageSample/cpDamageCast SM_Extend.lua == 4 each (1 def + 3 call sites) + git diff --check"
        status: pass
    human_judgment: true
    rationale: "cast-time snapshot semantics (GCD probe ordering, live energyPool/bleedCount values, guid under SuperWoW) can only be proven on the live client; this machine has no Lua runtime - 28-04 UAT carries runtime proof"
  - id: D2
    description: "Category U self-tests U-01..U-09 - nine isOptional login-runnable assertions pinning D-03/D-05/D-06/D-07 and the encoder/emitter contract"
    verification:
      - kind: other
        ref: "bbcheck BALANCED + build.sh + grep -c 'Cat U-0' SM_Extend.lua == 9 + zero deleted old registrations + node byte-simulation of the U-02/U-03 literals == MATCH"
        status: pass
    human_judgment: true
    rationale: "the tests themselves execute on the user's machine via /mt at login; local static gates prove registration completeness and literal correctness, not runtime pass"

# Metrics
duration: 6min
completed: 2026-09-08
status: complete
---

# Phase 28 Plan 02: catAtk claw/shred/bite damage instrumentation — three-skill coverage + Category U self-test Summary

**shred and ferocious_bite join claw's proven cpDamage cast-side hook (bite as a cpDamage-only structure with literal BITE_E 35), and Category U lands 9 login-runnable assertions pinning the encoder/emitter contract and the D-03/D-05/D-06/D-07 decision surface**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-08T12:43:41Z
- **Completed:** 2026-09-08T12:49:26Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- obj.shred gains the isomorphic cpDamage pair (sample before `_castSpell` / cast after the cpBuild block, cpBuild two lines untouched); obj.ferocious_bite upgraded from a single-line return to the same three-part structure with token `'bite'` and literal energy 35 — the D-08 triple `('claw', macroTorch.computeClaw_E()) / ('shred', macroTorch.computeShred_E()) / ('bite', 35)` is now verbatim across the three skill methods
- Category U adds exactly 9 self-tests: U-01 switch default, U-02 encoder literals (quote + backslash escaping), U-03 verbatim 11-field emit literal (the 28-03 decoder interop contract), U-04 pairing window, U-05 TTL purge, U-06 hits end-to-end, U-07 miss zero-emit (D-03), U-08 crits crit=true marking, U-09 Training Dummy hard gate + non-dummy rejection (D-05)
- verification battery fully green: bbcheck BALANCED on both files, build.sh clean, SM_Extend.lua carries cpDamageSample x4 / cpDamageCast x4 (1 definition + 3 call sites) and Cat U x9, git diff --check clean, zero deleted registrations
- the hand-written contract literals (U-02 escaped string, U-03 11-field line) were byte-verified offline against node simulations of the file literals and the 28-01 encoder/emitter assembly — both matched exactly, closing the no-local-Lua verification gap for the literal-correctness half

## Task Commits

Each task was committed atomically:

1. **Task 1: shred + ferocious_bite 采样同构挂接（三技能全覆盖，D-07/D-08/D-09）** - `25d4a8f` (feat)
2. **Task 2: Category U SelfTest 9 条注册（U-01..U-09，D-03/D-05/D-06/D-07 断言固化）** - `817ebc9` (feat)

**Plan metadata:** final docs commit below (SUMMARY + STATE + ROADMAP).

## Files Created/Modified
- `classes/druid/Druid.lua` - obj.shred gains `cpDamageSample('shred', macroTorch.computeShred_E())` before `_castSpell` + `cpDamageCast` after (cpBuild lines unchanged); obj.ferocious_bite restructured to the three-part form with `cpDamageSample('bite', 35)` and no cpBuild sampling (D-06 range lock, bite never belonged to cpBuild)
- `classes/druid/selftest.lua` - Category U block (U-01..U-09) inserted after Cat T-01 inside the `UnitClass('player') == 'Druid'` guard: 9 registrations, all `isOptional=true`, CR-01 snapshot/restore discipline, U registration count comment updated at the tail

## Decisions Made
- U-02/U-03 expected literals handwritten from the 28-01 implementation contract (encoder: quote -> `\"` and backslash -> `\\`; emitter: fixed 11-field order `spell dmg crit e energyPool bleedCount isOoc isBehind cp t batch`) and machine-verified offline with node simulations decoding the exact file literals — both matched byte-exact
- U-04/U-05 leave `macroTorch.target` untouched (pairCpDamageIntent only reads loginContext.cpDamageIntents) and exercise the case-insensitive guid comparator with an uppercase seeded guid vs a lowercase damage-line guid
- U-09 stubs the full gate chain (context._cpDamageBatch, target, loginContext, log, _castSpell, isActionCooledDown) plus pins cpBuildLog=false so the cpBuild branch cannot interfere; the second run against a non-dummy asserts zero growth (stack stays at 1 element) — the "计数 0" reading interpreted as zero added intents
- U-06/U-07/U-08 seed intents with `castAt = GetTime()` and parse with `now = GetTime()` — same-frame equality keeps the intent inside the 2s window deterministically

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None blocking. The only friction was verifying the hand-written expected literals without a local Lua interpreter; resolved with node byte-simulations of the Lua 5.0 literal decoder plus the 28-01 encoder/emitter assembly (both matches confirmed before commit). Lua 5.0 `string.find` plain flag was confirmed against the downloaded official manual (string.find (s, pattern [, init [, plain]])), matching the repo precedent in Cat S-04.

## Known Stubs

None introduced by this plan. (The `tools/cpdamage.lua` `--selftest`/`--json-out` dispatch placeholders belong to 28-01 and are already tracked in 28-01-SUMMARY.md; 28-03 resolves them.)

## User Setup Required

None - no external service configuration required. Runtime-level proof of the U-tests and cast-side semantics runs on the user's machine via `/mt` plus the 28-04 UAT (this machine has no Lua interpreter, per 28-VALIDATION.md).

## Next Phase Readiness
- 28-03 can verify its decoder against the U-03 verbatim literal (11-field fixed order) and expects Category U x9 in the build product; the two count anchors for 28-04's final battery are in place (SM_Extend.lua cpDamageSample x4, Cat U x9)
- three-skill coverage complete: claw/shred/bite all embed cast-side sampling; bite's energyPool/isOoc snapshot rides the unified cpDamageSample path (D-09), zero extra code
- no blockers

## Self-Check: PASSED
- Task commits exist: 25d4a8f / 817ebc9
- bbcheck BALANCED on both modified files; build.sh exit 0
- SM_Extend.lua anchors: cpDamageSample == 4, cpDamageCast == 4, Cat U-0 == 9
- git diff --check clean; zero deleted registration lines
- U-02/U-03 literals byte-matched via node simulation (MATCH: YES each)

---
*Phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac*
*Completed: 2026-09-08*