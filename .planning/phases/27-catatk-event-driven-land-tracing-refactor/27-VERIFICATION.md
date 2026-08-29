---
phase: 27-catatk-event-driven-land-tracing-refactor
verified: 2026-08-29T02:58:09Z
status: human_needed
score: 18/20
behavior_unverified: 2
overrides_applied: 0
behavior_unverified_items:
  - truth: "Fail is final and wins regardless of arrival order: it consumes the intent, records failTable as before, and revokes any land the intent produced (debug decision #2)"
    test: "In-game: run /mt Category Q after the addon loads (or observe the ~0.5s post-PLAYER_ENTERING_WORLD auto-run); Q-05 (fail after land revokes via removeMatch) and Q-06 (fail before apply — no late pairing) must be green. No Lua interpreter exists locally, so the state-transition invariant could only be verified statically."
    expected: "Q-05 and Q-06 green; finalizeFail consumes exactly the newest pending-or-landed intent within LAND_INTENT_TTL, revokes the exact landAt entry, and marks it failed in both arrival orders."
    why_human: "Order-independent state transitions (fail wins over an earlier land) are runtime semantics; presence + wiring were verified but the repo has no Lua interpreter or CI to execute the transitions."
  - truth: "A Ferocious Bite land event immediately rewrites the Rake and Rip land entries with land = FB event time; the GetComboPoints()>0 condition is REMOVED (debug decision #3)"
    test: "In-game: Q-08 (listener presence) and Q-10 (numeric renewal) plus the dummy-fight smoke run — Rip/Rake up, land Ferocious Bite, observe the 'Renewing rake.../rip... left:' lines, then confirm ripLeft/rakeLeft restart from the hit moment (no ~0.4s window lag, no combo-point gate)."
    expected: "Each FB hit/crit line immediately advances the Rake and Rip land stacks with the numeric FB event time when the bleed is present; the renewal contains zero GetComboPoints calls (verified statically) and behaves that way in-game."
    why_human: "Event-driven state rewrites on the live combat stream can only be observed on the game machine; static verification proved the wiring and the absence of the CP condition, not the runtime renewal cadence."
human_verification:
  - test: "End-of-phase UAT on the game machine: pull the phase commits, Cygwin `bash build.sh` (expect exit 0), copy SM_Extend.lua, /reload, run /mt (note: SelfTest auto-runs ~0.5s after entering the world; a later /mt before the next /reload is a silent no-op due to the run-once _selfTestRan guard)."
    expected: "All 9 planned Category Q tests (Q-01..Q-09) green, zero [DIAG]/[RAWDIAG] output anywhere, no Lua errors; then the dummy-fight smoke run: cast Rip (aura-apply land pairs the cast intent within 2s), land Ferocious Bite hits (event-driven 'Renewing rake.../rip... left:' lines restart the 16.2s/18s clocks from the hit moment), and verify no premature Rip recast over a lagged/extended session."
    why_human: "No Lua interpreter and no CI exist in the repo; the phase's behavioral layer was deliberately deferred to in-game Category Q selftests (plan 27-03 design)."
  - test: "Developer decision on verification finding V-01: at a fresh out-of-combat /reload, Category Q runs with macroTorch.context == nil (combat_context.lua creates context only on onCombatEnter), so Q-10's renewal drive reaches ripLeft's `macroTorch.context.lastRipAtCp` and the inner pcall fails — the test reports the identical 'Q-10 pcall failed' warning both on the fixed code and on CR-01-broken code, so its regression-discriminator assertion (numeric land tops) is never reached in that flow. Suggested hardening (3 lines, CR-01 pattern already established in the test): snapshot and stub macroTorch.context with a fake table alongside loginContext/target/show, and restore it before the asserts. Decision options: (a) accept as-is and note the transient warning in the UAT runbook, (b) apply the hardening so Q-10 discriminates in every session."
    expected: "Developer picks (a) or (b); if (b), Q-10 then runs green on a fresh session and its `type(rakeTop) == 'number'` assert genuinely fails on any future listener-argument regression."
    why_human: "The failure depends on game-client session state (nil context before first combat entry; WoW 1.12 ReloadUI event re-fire behavior for in-combat reloads is unknowable without the game machine), which static analysis cannot execute; the production code is correct either way."
---

# Phase 27: catAtk event-driven land tracing refactor — Verification Report

**Phase Goal:** Replace polling-based land generation with an event-driven land-tracing mechanism (cast intent state machine + RAW_COMBATLOG aura-apply pairing + fail-as-final revocation + self-hit default source), integrated into druid cat skills with FB-land-event renewal, all debug-session diagnostics removed, Category Q selftests registered — eliminating the machine-lag root cause of premature Rip recasts without touching isRipPresent/hasBuff semantics or the self-reported duration clocks.

**Verified:** 2026-08-29T02:58:09Z
**Status:** human_needed
**Re-verification:** No — initial verification (no prior VERIFICATION.md existed in the phase directory)

## Verification Approach

Spec-less phase per ROADMAP.md ("Requirements: none assigned"). The requirement surface is the `must_haves.truths` frontmatter of the three PLAN files (8 + 7 + 5 = 20 truths), sourced from the locked debug-session decisions #1-#8 archived at `.planning/debug/catatk-premature-rip-recast.md`. REQUIREMENTS.md contains zero `Phase 27` references — the expected traceability skip is recorded as visible (grep count = 0; plan frontmatter `requirements: []` on all three plans).

**Static-only verification** per repo convention: no Lua interpreter, no CI. Evidence = direct file reads, `git diff 17d0c7a..HEAD` (phase-start commit 17d0c7a → HEAD) byte comparisons, the static battery re-run (bbcheck.js on all 7 files, `bash build.sh`, leftover sweep, scope gate, Lua 5.0 audit, `git diff --check`). Summary claims were re-derived from code, never trusted.

## Goal Achievement

### Observable Truths (must-haves verdict table)

| # | Truth (source plan) | Status | Evidence |
|---|---------------------|--------|----------|
| 1 | Land events generated by game events only; 0.1s OnUpdate polling gone from core (27-01, d#5) | ✓ VERIFIED | `maintainLandTables`/`computeLandTable`/0.1s registration absent from core/spell_trace_core.lua; call-site audit: the only `recordLandEvent` producers are `processRawAuraApply` (RAW apply line), `onSelfDamageLine` (chat hit/crit line), and the FB renewal listener — no periodic task calls it; remaining `registerPeriodicTask` = only `spellsImmuneTracing` (pre-existing, out of scope) |
| 2 | Cast bridging untouched: UNIT_CASTEVENT + _pendingCastSpellName and UNIT_SPELLCAST_SUCCEEDED keep exact semantics (27-01, d#2) | ✓ VERIFIED | Byte-compare of the UNIT_CASTEVENT/UNIT_SPELLCAST_SUCCEEDED region vs 17d0c7a: identical; the events.lua phase diff touches only the RAW branch, the self-damage dispatch addition, and the RAWDIAG_KEYWORDS deletion |
| 3 | Intent state machine (pending/landed/failed/expired, 2s expiry) keyed spell × target-name in loginContext (27-01, d#2) | ✓ VERIFIED | `LAND_INTENT_TTL = 2` (core/spell_trace_core.lua:15); `recordCastTable` seeds `{state='pending', castAt, landAt=nil}` into `intentTable[spell][mob]` LRUStack(32) on the same success path as the castTable push; `pairLandIntent` purge/pair passes and `finalizeFail` flip all four states |
| 4 | Fail is final and wins regardless of arrival order; consumes intent, records failTable as before, revokes produced land (27-01, d#2) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Code present and wired: `finalizeFail` newest-match scan over pending/landed intents within TTL, exact-`landAt` revocation via `LRUStack:removeMatch`, hooked as the ONLY added line in `recordFailTable` (byte-diff vs 17d0c7a = `25a26 > macroTorch.finalizeFail(spell, item[1])`). Arrival-order transitions are runtime-only; Q-05/Q-06 exercise them but need the in-game /mt run. See behavior_unverified_items |
| 5 | Production RAW_COMBATLOG handler obeys the three-tier filter; no per-event allocation/logging (27-01, d#6) | ✓ VERIFIED | core/events.lua:136-154 read: tier-1 channel whitelist (early return without touching arg2), tier-2/3 `pairs` loop + `string.find` over precompiled patterns + break on first hit; handler body contains no `macroTorch.log`, no table construction; RAWDIAG_KEYWORDS and the scout are gone |
| 6 | self-hit lands pairing-free from 'Your <skill> hits/crits'; aura-apply requires intent pairing within 2s and stamps land with the apply event time (27-01, d#2) | ✓ VERIFIED | `onSelfDamageLine` records unconditionally after tracingSpells/landSource guards (pairing best-effort only); `processRawAuraApply` = marker find + case-insensitive current-target guid match + `pairLandIntent` gate + `recordLandEvent(spellName, now)` — the land timestamp IS the apply event time |
| 7 | Lua 5.0 / WoW 1.12 compliance, English comments (27-01, d#7) | ✓ VERIFIED | Zero `#` length operator in added lines (only comment text "decision #N"); zero goto/labels repo-wide (git grep empty); every new `string.find` is 2-argument (no 4-arg plain mode); all 7 files LF endings; new comments English |
| 8 | SM_Extend.lua remains a regenerated, uncommitted build artifact (27-01, d#7) | ✓ VERIFIED | `git ls-files` negative for SM_Extend.lua; `git check-ignore` confirms it; `bash build.sh` exit 0 regenerates it with all new symbols (pairLandIntent/recordLandEvent/processRawAuraApply/onSelfDamageLine/finalizeFail/onLandEvent/removeMatch/LAND_INTENT_TTL present); phase commits contain source + planning files only |
| 9 | Rip/Pounce landSource='aura-apply'; Rake/FB default 'self-hit' (27-02, d#3) | ✓ VERIFIED | classes/druid/Druid.lua:682-702 read: exactly 2 `landSource = 'aura-apply'` (Pounce 684, Rip 695); Rake (688) and Ferocious Bite (699) carry no landSource key with self-hit-default comments; Hunter.lua adds exactly 2 more (Serpent Sting 157, Scorpid Sting 163) — 4 total in the build artifact |
| 10 | FB land event rewrites Rake/Rip land entries with land = FB event time; GetComboPoints()>0 condition REMOVED (27-02, d#3) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Wiring verified: `onLandEvent('Ferocious Bite', function(spell, landTime) ... end)` at Druid.lua:718 calls `recordLandEvent('Rake', landTime)` / `recordLandEvent('Rip', landTime)` with the event time; listener block contains zero GetComboPoints/recordCastTable/lastProcessedBiteEvent/_diag. Event-driven rewrite cadence is runtime-only (Q-08/Q-10 + smoke run in-game). See behavior_unverified_items |
| 11 | Renewal never writes lastRipEquippedSavagery/lastRakeEquippedSavagery — clock model continues from new land time (27-02, d#3/#4) | ✓ VERIFIED | Listener block grep: the two Savagery fields appear only inside `tostring(macroTorch.loginContext....)` reads; their only assignments repo-wide are pre-existing `safeRake`/`safeRip` in cat.lua (unchanged verification surface); `context.lastRipAtCp` also read-only in the listener path |
| 12 | isRipPresent = hasBuff('Ability_GhoulFrenzy') AND ripLeft>0 byte-for-byte; duration models untouched; only land timestamp source changes (27-02, d#4) | ✓ VERIFIED | `git show 17d0c7a` vs HEAD diff of the isRipPresent/ripLeft/rakeLeft region: zero changed computation lines; the only deletions are the 30-line [DIAG rip-contradiction] dump block, after which ripLeft ends at `return clickContext.ripLeft` immediately following the computation |
| 13 | entity/Unit.lua hasBuff internals untouched; no tick/fade-based expiry introduced (27-02, d#4) | ✓ VERIFIED | Scope gate: `git diff 17d0c7a..HEAD -- entity/Unit.lua` empty; hasBuff function unchanged; no fade/tick handling added to any changed file; ripLeft/rakeLeft remain the sole expiry predictors |
| 14 | consumeDruidBattleEvents + periodic registration deleted; all [DIAG]/[RAWDIAG] logging removed (27-02, d#5 druid half) | ✓ VERIFIED | Repo-wide leftover sweep for the 9 identifiers (maintainLandTables/computeLandTable/consumeDruidBattleEvents/RAWDIAG/_rawScout/_diagRipContradiction/_diagLastSafeRipAt/_diagLastRenewingRipAt/lastProcessedBiteEvent) returns ONLY the Q-09 nil-assert guard lines in selftest.lua (the planned runtime enforcers); cat.lua diff = 11 pure deletions (stamp, re-arm, [RAWDIAG] persist line) with 'Rip!!! At cp:' show + assignments intact |
| 15 | Lua 5.0 + LF endings; no build_order.txt change (27-02, d#7) | ✓ VERIFIED | All 3 class files LF; `git diff 17d0c7a..HEAD -- build_order.txt` empty; no goto/#-operator in new hunks |
| 16 | Category Q selftests registered in classes/druid/selftest.lua inside the Druid guard, all isOptional=true, covering the listed behaviors (27-03) | ✓ VERIFIED | 10 registrations (Q-01..Q-09 from the plan + Q-10 from the CR-01/WR-01 review fix), all `end, true)`, all inside the `if UnitClass('player') == 'Druid'` guard before its final `end` (diff = 231 pure-insertion lines); behavior map: registry state Q-01, pairing chain Q-02, guid mismatch Q-03, TTL expiry Q-04, fail-after-land Q-05, fail-before-apply Q-06, self-hit + ignore Q-07, listener presence Q-08, deleted-machinery absence Q-09, numeric renewal Q-10. The PROVING itself is the in-game run (see human_verification) |
| 17 | Every stubbing test follows the Phase-26 CR-01 save/restore discipline (27-03) | ✓ VERIFIED | Read of Q-02..Q-07 + Q-10: fake loginContext/target (and show in Q-10) built before install, framework calls inside pcall, results in locals, raw-assignment restores (`macroTorch.loginContext = savedLoginContext`, `macroTorch.target = savedTarget`, `macroTorch.show = savedShow`) BEFORE the first assert in every stubbed test; zero writes to real landSources/landListeners/tracingSpells/loginContext sub-tables |
| 18 | Phase-wide battery: bbcheck BALANCED on 7 files, build.sh with all symbols, leftover sweep zero, scope exactly 7 files, diff --check clean (27-03) | ✓ VERIFIED | Re-run by verifier: bbcheck 7/7 BALANCED; `bash build.sh` exit 0 with all symbols + FB listener (`onLandEvent('Ferocious Bite', function(spell, landTime)` at artifact line 4877) + 4 aura-apply register sites in SM_Extend.lua; sweep clean outside Q-09 guards; `git diff --stat 17d0c7a..HEAD -- '*.lua'` = exactly the 7 intended files (231/469 insertions, 179 deletions); `git diff --check` clean on worktree and phase range; worktree clean |
| 19 | isRipPresent/ripLeft diff byte-for-byte except removed diagnostics; Unit.lua, build_order.txt untouched (27-03, d#4) | ✓ VERIFIED | Same evidence as #12/#13: entity/Unit.lua, build_order.txt, core/spell_trace_immune.lua, core/selftest.lua all absent from the phase diff stat |
| 20 | Lua 5.0 across all changed hunks; SM_Extend.lua never committed (27-03, d#7) | ✓ VERIFIED | 4-arg string.find audit (all new calls 2-arg), goto/label grep empty, #-operator grep empty on added lines, LF on all 7 files, git diff --check clean; SM_Extend.lua not in `git ls-files` |

**Score:** 18/20 truths verified, 2 present-but-behavior-unverified (fail-wins revocation ordering, FB renewal runtime cadence — both need the in-game /mt + smoke run the phase itself planned).

### Launcher cross-checks (CR-01 / Q-10)

| Cross-check | Status | Evidence |
|-------------|--------|----------|
| CR-01 landed: FB renewal listener declares `function(spell, landTime)` matching `listener(spell, landTime)` dispatch in `recordLandEvent` | ✓ VERIFIED | Dispatcher: core/spell_trace_core.lua:214 `listener(spell, landTime)`. Listener: classes/druid/Druid.lua:718 `macroTorch.onLandEvent('Ferocious Bite', function(spell, landTime)` with the CR-01 explanatory comment; identical in the build artifact (line 4877); shipped by commit 9c09300 `fix(27)` which also closed WR-01 |
| Q-10 drives the renewal path | ✓ VERIFIED (wiring) / ⚠️ WARNING V-01 (runtime) | Q-10 seeds numeric Rake/Rip lands, dispatches the real FB listener via `recordLandEvent('Ferocious Bite', fbNow)` with a hasBuff=true stub, asserts `type(rakeTop) == 'number' and rakeTop == fbNow` (would fail on CR-01-broken code). Finding V-01 below flags its session-state dependency |
| Selftest discipline vs Phase-26 CR-01 (P-02 lecture) | ✓ VERIFIED | Truth #17 evidence; Q-10 additionally stubs/restores `macroTorch.show` |

### Code Review (27-REVIEW.md) dispositions

- **CR-01 (critical)**: FIXED — commit 9c09300, verified in the live file and the artifact.
- **WR-01 (false-green coverage)**: FIXED — Q-10 added in the same commit; with the V-01 caveat on when it executes.
- **WR-02 (cross-caster false-pair)**: ACCEPTED design trade-off per launcher — the review's "at minimum document the residual caveat" half was not added to `processRawAuraApply`'s comment; advisory only.
- **IN-01 (pattern metacharacter escaping)**: latent only — all four current aura-apply names are metacharacter-free; unchanged.
- **IN-02 (pairs() mutation hazard)**: registrations are load-time only; unchanged.
- **IN-03 (Pounce spellName)**: moot — live config at Druid.lua:683 carries `spellName = 'Pounce'` and the pre-phase file already had it; the phase diff adds only `landSource = 'aura-apply'`.

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| core/spell_trace_core.lua | Intent framework + 6 new functions, poller deletion, arm-hook removal | ✓ VERIFIED | Read in full: LAND_INTENT_TTL, landSources, auraApplySpellPatterns, register landSource extension, intent seeding, pairLandIntent (purge/pair), recordLandEvent + dispatch, onLandEvent, processRawAuraApply, onSelfDamageLine, finalizeFail; maintainLandTables/computeLandTable absent; recordFailTable = pre-phase + exactly the finalizeFail line |
| core/events.lua | Three-tier RAW handler + self-hit dispatch, scout removed | ✓ VERIFIED | Read in full; bridge branches byte-identical; RAWDIAG_KEYWORDS gone |
| core/periodic.lua | LRUStack:removeMatch additive | ✓ VERIFIED | Definition + 1 comment line only; push/pop/anyMatch/allMatch untouched (compared vs pre-phase) |
| classes/druid/Druid.lua | landSource configs + FB listener; consumer + DIAG block deleted | ✓ VERIFIED | Read + diffed |
| classes/druid/cat.lua | safeRip diagnostics removed | ✓ VERIFIED | Diff = 11 pure deletions |
| classes/hunter/Hunter.lua | Both stings → aura-apply | ✓ VERIFIED | Diff = 6 insertions, exactly the two config tables + comments |
| classes/druid/selftest.lua | Category Q Q-01..Q-09 (+ Q-10) | ✓ VERIFIED | 231 pure-insertion lines, all optional, CR-01 restore discipline audit passed |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| recordCastTable | loginContext.intentTable push | intent seeding on castTable push success path | WIRED | spell_trace_core.lua:113-122 (after 0.2s dedup, same success path) |
| pairLandIntent → recordLandEvent → landTable top | ripLeft/rakeLeft (peekLandEvent consumers) | processRawAuraApply gate / onSelfDamageLine / FB listener | WIRED | peekLandEvent reads the same landTable stacks; the consumers' computation is byte-identical to pre-phase |
| events.lua RAW_COMBATLOG branch | auraApplySpellPatterns → processRawAuraApply → pair/record | channel whitelist + pattern find + break | WIRED | events.lua:130-154; target.guid accessor exists (entity/Unit.lua:103) |
| recordFailTable → finalizeFail | intent state flip → landTable revocation | LRUStack:removeMatch (exact landAt equality) | WIRED | spell_trace_core.lua:151 + 255-286 + periodic.lua removeMatch |
| onLandEvent('Ferocious Bite') listener | recordLandEvent('Rake'/'Rip', FB event time) | isRakePresent/isRipPresent gate | WIRED | Druid.lua:718-732; CR-01 signature now matches the (spell, landTime) dispatch contract |
| SpellTrace:register landSource entries | landSources/auraApplySpellPatterns → events.lua RAW handler | register-time precompile | WIRED | register at spell_trace_core.lua:60-68; 4 aura-apply registrations in the artifact |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|----------|---------------|--------|--------------------|--------|
| ripLeft/rakeLeft | lastLandedRipTime / lastLandedRakeTime | peekLandEvent → landTable ← recordLandEvent ← game events (RAW apply line, own hit/crit line, FB renewal) | Yes — every production landTable writer is event-fed with GetTime()/apply-event timestamps | ✓ FLOWING |
| FB renewal listener | landTime | dispatch argument from recordLandEvent (numeric event time) | Yes — no static fallback, no mock in the production path | ✓ FLOWING |
| events.lua RAW handler | arg2/arg1 | RAW_COMBATLOG event args | Yes — grep-verified; no hardcoded data, no scout persistence | ✓ FLOWING |
| landSources/auraApplySpellPatterns | registry entries | declarative `SpellTrace:register` configs (Druid/Hunter load-time) | Yes — 4 aura-apply + 2 self-hit entries populated at load | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Bracket balance, all 7 files | `node .../tools/bbcheck.js <file> ×7` | 7× BALANCED | ✓ PASS |
| Build + artifact symbol set | `bash build.sh` (exit 0); grep 8 symbols + FB listener + 4 aura-apply sites in SM_Extend.lua | all present | ✓ PASS |
| Deletion completeness | leftover sweep 9 identifiers, repo-wide `*.lua` | only Q-09 guard lines | ✓ PASS |
| Scope fidelity | `git diff --stat 17d0c7a..HEAD -- '*.lua'` | exactly the 7 intended files | ✓ PASS |
| Computation fidelity | byte-diff of isRipPresent/ripLeft region + recordFailTable + bridge branches | only planned additions/deletions | ✓ PASS |
| Lua 5.0 audit | goto/labels grep, #-operator on added lines, string.find arity | zero violations | ✓ PASS |
| EOL gate | `git diff --check` (worktree + phase range); CR-byte scan of the 7 files | clean, all LF | ✓ PASS |
| In-game behavioral (Q green, renewal cadence) | requires game client | N/A — no Lua interpreter/CI | ? SKIP → human_verification |

## Probe Execution

No `scripts/*/tests/probe-*.sh` exist and the phase plans declare none (repo convention: bbcheck.js + build.sh as the static battery). The battery itself was re-run end-to-end by the verifier — recorded above under Behavioral Spot-Checks.

## Requirements Coverage

Phase 27 has no requirement IDs (ROADMAP.md "Requirements: none assigned"; all three PLAN frontmatter `requirements: []`; `grep -c "Phase 27" .planning/REQUIREMENTS.md` = 0). REQUIREMENTS.md is a visible skip for this phase, recorded here per orchestrator instruction. Correctness predicates live in the PLAN `must_haves.truths` (verified in the table above) and the locked debug-session decisions #1-#8 at `.planning/debug/catatk-premature-rip-recast.md`. No orphaned requirement IDs exist for this phase.

## Anti-Patterns / Findings

| # | Severity | Finding |
|---|----------|---------|
| V-01 | ⚠️ WARNING (escalated for developer decision) | **Q-10 cannot run green on the standard verification flow.** The renewal path Q-10 drives reaches `ripLeft` → `local cp = macroTorch.context.lastRipAtCp` (Druid.lua:1110). `macroTorch.context` is created ONLY by `onCombatEnter` (core/combat_context.lua:10/30) and is nil from a fresh `/reload` until the first combat entry; nothing else in selftest.lua assigns it (grep-verified). SelfTest runs once, ~0.5s after PLAYER_ENTERING_WORLD (run-once `_selfTestRan` guard, core/selftest.lua:51 — a later `/mt` before the next `/reload` is a silent no-op), which on the planned UAT flow ("/reload, run /mt") is always out of combat. Result: Q-10's inner pcall fails at the nil-context index, the test throws `Q-10 pcall failed` (yellow, isOptional), and its CR-01-discriminator assert (`type(rakeTop) == 'number' ... == fbNow`) is never reached — the test fails with the identical message on CR-01-broken code, so the WR-01 closure is structural only. The production code itself is correct (the listener signature fix and all must-haves verify); only the selftest's execution precondition is undeclared. Suggested hardening (3 lines, same CR-01 pattern already used): snapshot `macroTorch.context` with the other globals, install `fakeContext = {}`, restore before the asserts. Decision item — see human_verification. |
| — | ℹ️ INFO | WR-02 accepted trade-off (multi-caster false-pair inside the 2s TTL) — the review's "document the residual caveat at processRawAuraApply" half was not applied; the comment there describes the ownership check but not the residual window. Cosmetic. |
| — | ℹ️ INFO | `finalizeFail` accepts `failTime < castAt` within the negative TTL delta (marks the newest pending/landed intent failed). Latent edge (cast bridge latency > fail event latency); upstream fail parsing order makes it unlikely, and the fail-wins direction is conservative. Not a truth violation. |

Debt-marker gate: zero TBD/FIXME/XXX/PLACEHOLDER/“coming soon” markers in any of the 7 phase files. No stubs: every producer/consumer pair traced above terminates in game-event data.

## Human Verification Required

1. **In-game Category Q + smoke UAT** — pull commits, Cygwin `bash build.sh`, /reload; expect Q-01..Q-09 green (and Q-10 per the V-01 decision below), zero `[DIAG]`/`[RAWDIAG]` output; then the dummy-fight smoke: Rip/Pounce lands via aura-apply pairing, FB hits produce event-driven `Renewing rake.../rip... left:` lines that restart the self-reported clocks from the hit moment, and the premature Rip recast does not recur on a lagged/extended run. (Auto-run note: SelfTest fires ~0.5s after entering the world; `/mt` after that is a no-op until the next /reload due to `_selfTestRan`.)
2. **V-01 decision (developer)** — see WARNING above: accept the transient `Q-10 pcall failed` yellow at fresh sessions or apply the 3-line context stubbing so Q-10 discriminates in every session and meets the "all Category Q green including Q-10" UAT expectation as written.
3. **Behavior-unverified truths (#4 fail-wins both orders, #10 FB renewal rewrite)** — Q-05/Q-06/Q-10 plus the smoke run are the in-game proof; green Q results close both.

## Gaps Summary

No gaps. Phase goal achieved at the code level: all 20 must-have truths are VERIFIED or present-but-behavior-unverified, the CR-01 signature mismatch is fixed and shipped with the Q-10 regression test, all decision-#5 deletions are complete repo-wide, and the static battery is fully green on re-run. The two remaining truths need only the user-side in-game UAT this phase always planned; finding V-01 is a WARNING escalated for developer decision, not a goal-blocking defect (production behavior is correct either way).

---

_Verified: 2026-08-29T02:58:09Z_
_Verifier: Claude (gsd-verifier)_