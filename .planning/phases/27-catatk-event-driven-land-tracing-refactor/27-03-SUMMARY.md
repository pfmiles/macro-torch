---
phase: 27-catatk-event-driven-land-tracing-refactor
plan: 03
subsystem: verification/selftest
tags: [lua50, wow112, selftest, verification]

# Dependency graph
requires:
  - plan: 27-01
    provides: [pairLandIntent, recordLandEvent, onLandEvent, processRawAuraApply, onSelfDamageLine, finalizeFail, LRUStack:removeMatch, LAND_INTENT_TTL, landSources/auraApplySpellPatterns registries]
  - plan: 27-02
    provides: [Druid/Hunter landSource registrations (Rip/Pounce/Serpent/Scorpid Sting aura-apply), Ferocious Bite renewal listener via onLandEvent]

provides:
  - Category Q selftests (Q-01..Q-09) in classes/druid/selftest.lua — in-game regression layer encoding the decision #2/#5 correctness predicates (pairing, TTL, guid ownership, fail-wins order independence, self-hit land, deletion-list absence), all isOptional=true with the Phase-26 CR-01 stub/restore discipline
  - Phase-wide 9-step static verification battery report covering all three plans of phase 27 as a unit
  - User-side UAT handoff: game machine build + /reload + /mt expecting all 9 Category Q green

affects:
  - none downstream — final plan of phase 27; the verifier phase gate consumes this battery report

# Actuals (#2632) — same scale as the plan's `estimate` (chars/4 over the realized diff).
actuals:
  tokens: 2773    # 11095 diff chars / 4 over classes/druid/selftest.lua (this plan's only source change)
  tasks: 2
  commits: 3      # test(27) source + docs(27-03) summary + docs(phase-27) tracking

# Tech tracking
tech-stack:
  added: []       # no packages installed (T-27-SC)
  patterns: [CR-01 stub/restore selftest discipline (local fake context/target, framework calls under pcall, raw-assignment restore before any assert), fake-clock alignment for GetTime-stamped intent seeding, local fake tables carrying stubbed accessors so real event listeners stay no-ops during fake drives]

key-files:
  created: []
  modified:
    - classes/druid/selftest.lua   # Category Q block (203 lines of pure addition) before the Druid guard's final end

key-decisions:
  - "Q-02 timeline alignment: recordCastTable stamps cast intents with the real client clock, which can never sit inside the [998.5, 1000.5] pair window of the fake 1000.5 apply time — the seeded intent's castAt is aligned to 999.0 on the fake context so the full recordCastTable -> intent -> apply-pair -> land chain stays real and the test becomes deterministic"
  - "Q-07 fake target carries hasBuff=false: recordLandEvent dispatches the real Ferocious Bite renewal listener and criterion 4 forbids stubbing macroTorch.landListeners, so the stub accessor makes the dispatched real listener a safe no-op inside the fake drive"
  - "Leftover-sweep reconciliation: the battery's 9-identifier grep necessarily hits Q-09's nil-assert guards — the plan's own runtime enforcers (must_haves truth #4), not leftover code; the sweep is verified clean everywhere except those three guard lines"

patterns-established:
  - "CR-01 restore discipline scales to cross-global swaps: snapshot macroTorch.loginContext/macroTorch.target by reference, run every framework call under pcall, restore by raw assignment, and only then assert — a failing assert can never leave a polluted session"
  - "In-game behavioral regression layer: static gates prove syntax and shape; SelfTest registrations encode the state-machine predicates for the client to verify at /mt; every stubbed test seeds via the public LRUStack push API and the .top accessor"

requirements-completed: []  # copied verbatim from plan frontmatter (phase 27 has no requirement IDs)

# Coverage metadata (#1602) — one entry per shipped deliverable.
coverage:
  - id: D1
    description: "Category Q selftest registrations Q-01..Q-09 (all isOptional=true): land-source registry values, aura-apply full pair chain with case-different guid, foreign-guid rejection, TTL lazy purge, fail-after-land revocation, fail-before-apply finality, pairing-free self-hit land + unregistered-spell ignore, FB renewal listener presence, runtime absence of the deleted machinery"
    verification: []
    human_judgment: true
    rationale: "in-game /mt run required — user-side UAT. The battery proves static correctness (bracket balance, discipline ordering, pure-addition diff); the pass/fail of the nine behavioral predicates is only established when the user runs /mt on the game machine."
  - id: D2
    description: "Phase-wide 9-step static verification battery green: bbcheck BALANCED on all 7 phase files; build.sh exit 0 with all 7 new symbols + the FB listener registration in SM_Extend.lua (artifact stays ignored/unstaged); leftover sweep clean except Q-09's nil-assert guards; scope = exactly the 7 intended source files; isRipPresent byte-identical and ripLeft diff = 30 pure deletions of the DIAG block; Lua 5.0 audit clean; git diff --check clean; all source committed with English conventional messages, no empty commits"
    verification:
      - kind: other
        ref: "node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js <all 7 phase files> — all print BALANCED"
        status: pass
      - kind: other
        ref: "bash build.sh (exit 0); SM_Extend.lua contains pairLandIntent/recordLandEvent/processRawAuraApply/onSelfDamageLine/finalizeFail/onLandEvent/removeMatch and the Ferocious Bite listener registration (line 4872); artifact confirmed gitignored and unstaged"
        status: pass
      - kind: other
        ref: "leftover sweep (9 identifiers) clean outside Q-09 nil-assert guards; repo-wide goto/label grep empty"
        status: pass
      - kind: other
        ref: "scope gate: git diff --stat 17d0c7a HEAD -- '*.lua' = exactly the 7 intended files; entity/Unit.lua, build_order.txt, spell_trace_immune.lua, core/selftest.lua absent"
        status: pass
      - kind: other
        ref: "fidelity gate: isRipPresent function byte-identical to phase start (diff empty); ripLeft region diff = 30 pure deletions of the [DIAG rip-contradiction] block with return clickContext.ripLeft and all computation intact"
        status: pass
      - kind: other
        ref: "Lua 5.0 audit: zero # operator uses (3 hits are comment text 'decision #N'), zero goto/labels repo-wide, zero 4-arg string.find; git diff --check clean (working tree and phase range); git status clean after commits"
        status: pass
    human_judgment: false

# Metrics
duration: 13min
completed: 2026-08-29
status: complete
---

# Phase 27 Plan 03: Selftest Verification Cleanup Summary

**Category Q behavioral regression layer (Q-01..Q-09) registered with the Phase-26 CR-01 stub/restore discipline, the 9-step phase-wide verification battery fully green, and the phase closed with a user-side in-game UAT handoff**

## Performance

- **Duration:** ~13 min (sequential session, 2 tasks)
- **Started:** 2026-08-29T01:18:00+08:00
- **Completed:** 2026-08-29T01:35:00+08:00
- **Tasks:** 2 (both executed; all acceptance criteria PASS)
- **Files modified:** 1 (classes/druid/selftest.lua, +203 pure-addition lines)

## Accomplishments

- Nine Category Q registrations inserted before the Druid guard's final `end`; the 51 pre-existing registrations are untouched (zero renumbering, diff = 203 insertions / 0 deletions).
- The decision #2/#5 correctness predicates are now client-enforced regression tests: Q-01 landSource registry values; Q-02 the full recordCastTable -> intent -> apply-pair -> land chain (case-different guid accepted, landAt == apply event time); Q-03 foreign-guid rejection; Q-04 TTL lazy purge; Q-05 fail-after-land revocation via removeMatch; Q-06 fail-before-apply finality; Q-07 pairing-free self-hit land + unregistered-spell ignore; Q-08 FB renewal listener presence; Q-09 runtime absence of the deleted polling machinery.
- Every stubbed test (Q-02..Q-07) follows the Phase-26 CR-01 discipline verbatim: fake loginContext/target built as locals before install, all framework calls inside a pcall, both globals restored by raw assignment (`macroTorch.loginContext = savedLoginContext`, `macroTorch.target = savedTarget`), and only then do asserts run — satisfying threat T-27-07's mitigation at the code level; zero writes to macroTorch.tracingSpells / landSources / landListeners or any real loginContext sub-table.
- The phase-wide battery validates all three plans of phase 27 as one unit: syntax/balance on the 7 touched files, the artifact symbol set, decision-#5 deletion completeness, exact 7-file scope, byte-precise computation fidelity, and Lua 5.0 conformance.

## Verification Log

### Task 1 acceptance criteria

| Criterion | Gate | Result |
|-----------|------|--------|
| 1 | `grep -c 'Cat Q-0'` = 9, every registration ends `end, true)` | PASS (9/9 at lines 745-940) |
| 2 | diff is pure addition (zero lines starting with '-') | PASS (203 insertions, 0 deletions) |
| 3 | restore statements precede the first assert in Q-02..Q-07 (CR-01) | PASS (verified by line audit) |
| 4 | no registry writes inside the new block (no assignment to landSources/landListeners/tracingSpells) | PASS |
| 5 | bbcheck BALANCED; git diff --check empty | PASS |

### Task 2 phase-wide battery

| Step | Gate | Result |
|------|------|--------|
| 1 | bbcheck BALANCED on all 7 phase files | PASS (7/7) |
| 2 | build.sh exit 0; pairLandIntent/recordLandEvent/processRawAuraApply/onSelfDamageLine/finalizeFail/onLandEvent/removeMatch all present in SM_Extend.lua; FB listener registered (line 4872); artifact ignored and unstaged | PASS |
| 3 | leftover sweep — 9 identifiers repo-wide | PASS (clean outside Q-09 nil-assert guards; see Decisions) |
| 4 | scope gate — git diff vs phase start (17d0c7a) = exactly the 7 source files; entity/Unit.lua, build_order.txt, spell_trace_immune.lua, core/selftest.lua absent | PASS |
| 5 | fidelity gate — isRipPresent byte-identical; ripLeft diff = 30 pure deletions of the DIAG dump block, `return clickContext.ripLeft` and all computation intact | PASS |
| 6 | Lua 5.0 audit — zero `#` operator (3 hits are comment text), zero goto/labels repo-wide, zero 4-arg string.find | PASS |
| 7 | git diff --check — clean on working tree and across the phase range | PASS |
| 8 | commit gate — all 7 source files committed (6 in plans 27-01/27-02, 1 in this plan); nothing source-related uncommitted; no empty commit created | PASS |
| 9 | battery recorded in this summary with the user-side UAT line | PASS |

## Task Commits

1. **Task 1: Category Q land-framework selftests** — `f448b21` (`test(27)`) — classes/druid/selftest.lua (+203)
2. **Task 2: battery only** — no additional source commit required: the 6 non-selftest phase files landed in plans 27-01 (`ff925bb`, `3c1e2db`) and 27-02 (`0ac3bf7`, `b3bd8c6`, `31d69d1`); per plan, no empty commit was created.
   Plan metadata commits: `docs(27-03)` (this summary) and `docs(phase-27)` (tracking) — see close-out.

## Files Created/Modified

- `classes/druid/selftest.lua` — Category Q block (203 lines, pure addition) immediately before the `if UnitClass('player') == 'Druid' then` guard's final `end`:
  - Q-01 registry reads (no stubs): Rip/Pounce = 'aura-apply', Rake/Ferocious Bite = 'self-hit', Serpent/Scorpid Sting = 'aura-apply'
  - Q-02..Q-07 (stubbed): fake `loginContext = {}` + fake `target = {isCanAttack=true, name='QTestMob', hasBuff=false}`, framework calls under pcall, results captured to locals, globals restored by raw assignment, asserts only after restore
  - Q-08/Q-09 (no stubs): landListeners shape + FB listener count; the three deleted functions assert nil at runtime

## Decisions Made

- **Q-02 timeline alignment.** recordCastTable stamps intents with the real client clock (GetTime); pairing against the fake 1000.5 apply time requires castAt inside [998.5, 1000.5]. The seeded intent's `castAt` is aligned to 999.0 on the fake context, keeping the whole real bridge chain exercised while making the test deterministic.
- **Q-07 hasBuff stub.** recordLandEvent('Ferocious Bite') dispatches the real FB renewal listener, and acceptance criterion 4 forbids stubbing macroTorch.landListeners. The fake target therefore carries `hasBuff = function(self) return false end` so the real dispatched listener evaluates to a safe no-op.
- **Sweep reconciliation.** The battery's leftover sweep necessarily matches Q-09's own nil-assert guards — the plan's mandated runtime enforcers of the decision-#5 deletion list, not leftover code. The sweep was verified clean everywhere except those three guard lines.

## Deviations from Plan

1. **[Rule 1 - Bug] Q-02 pair timeline made deterministic.** As literally specified, `recordCastTable` seeds `castAt = GetTime()` (real clock), which can never sit in the [998.5, 1000.5] window pairLandIntent requires for the fake 1000.5 apply — the test would always return nil in-game. Fix: after the real recordCastTable bridge call, align the seeded intent's `castAt` to 999.0 on the fake context (fake-context write only). Files: classes/druid/selftest.lua. Commit: f448b21.
2. **[Rule 2 - Missing critical test safety] hasBuff stub on the fake target.** Without it, the real Ferocious Bite renewal listener (dispatched by recordLandEvent during Q-07; un-stubbable per criterion 4) crashes on the plain fake target. Fix: fake target carries a `hasBuff` accessor returning false. Files: classes/druid/selftest.lua. Commit: f448b21.
3. **[Battery step 3 reconciliation] leftover sweep vs Q-09.** The 9-identifier grep hits Q-09's nil-assert guards by design (must_haves truth #4). Scope of the sweep narrowed to: zero hits anywhere except the Q-09 guard lines, confirmed. No code change required; noted in Decisions.

## Issues Encountered

- `.planning/PROJECT.md` does not exist on disk (only referenced from STATE.md; config.json does not list it) — no impact on this plan (same as 27-01/27-02).
- The plan's precondition grep pattern `function macroTorch%.recordLandEvent` uses a Lua-style `%` escape that git's basic regex treats as a literal `%`; the precondition fact was verified with the equivalent ERE pattern (`function macroTorch\.recordLandEvent` at core/spell_trace_core.lua:194) and by direct read — precondition met.
- The plan's Task 2 `<verify>` one-liner, run literally, would report BATTERY_FAIL=1 solely because of the Q-09 guard collision above; the substantive battery (steps 1-8 above) is fully green and recorded here.

## User Setup Required

None.

## Next Phase Readiness

Phase complete — user-side UAT (build + /mt Category Q) required on the game machine.

- On the game machine: pull → Cygwin `bash build.sh` (exit 0) → `/reload` → `/mt` → expect all 9 Category Q tests green and zero `[RAWDIAG]`/`[DIAG]` output; then a dummy-fight smoke run with Rip/Rake/Ferocious Bite to observe the event-driven `Renewing ...` lines restarting the self-reported clocks from each hit event.

---

*Phase: 27-catatk-event-driven-land-tracing-refactor*
*Completed: 2026-08-29*