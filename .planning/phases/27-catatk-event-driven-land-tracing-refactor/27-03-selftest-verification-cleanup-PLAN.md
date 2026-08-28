---
phase: 27-catatk-event-driven-land-tracing-refactor
plan: 03
type: execute
wave: 3
depends_on:
  - 27-01
  - 27-02
files_modified:
  - classes/druid/selftest.lua
autonomous: true
requirements: []          # no requirement IDs assigned for phase 27 (recorded visible skip)

estimate:
  tokens: 25000
  raw_tokens: 25000
  tasks: 2
  confidence: low         # derived: 0 calibration samples

must_haves:
  truths:
    - "Category Q selftests registered in classes/druid/selftest.lua (inside the Druid guard, all isOptional=true) prove: landSource registry state, aura-apply pairing + TTL expiry, target-guid mismatch rejection, fail revocation in both arrival orders, self-hit land, FB renewal listener presence, and runtime absence of the deleted machinery"
    - "Every stubbing test follows the Phase-26 CR-01 save/restore discipline: compute into locals, restore global stubs by raw assignment, only then assert — a failing assert can never leave a polluted session"
    - "Phase-wide verification battery passes: bbcheck BALANCED on all 7 touched files, ./build.sh builds SM_Extend.lua with all new symbols, leftover sweep (9 identifiers) returns zero, diff scope is exactly the 7 intended source files, git diff --check clean"
    - "isRipPresent and ripLeft computation diff byte-for-byte except removed diagnostics; entity/Unit.lua hasBuff untouched (debug decision #4); build_order.txt unchanged (no new files)"
    - "Lua 5.0 syntactic conventions hold across all changed hunks (debug decision #7); SM_Extend.lua never committed"
  artifacts:
    - classes/druid/selftest.lua (Category Q: Q-01..Q-09)
    - 27-01-SUMMARY.md / 27-02-SUMMARY.md counterparts: 27-03-SUMMARY.md (executor output)
  key_links:
    - Q-02/Q-05/Q-06 assertions -> pairLandIntent/processRawAuraApply/finalizeFail + LRUStack:removeMatch (plan 27-01)
    - Q-08 -> onLandEvent('Ferocious Bite') listener (plan 27-02)
    - Q-09 -> runtime proof of decision-#5 deletions
---

<objective>
Register the behavioral regression layer (Category Q selftests) for the event-driven land framework, then run the phase-wide static verification battery and close the phase.

Purpose: The repo has no Lua interpreter and no CI; truth lives in (a) in-game SelfTest registrations the user runs via /mt and (b) deterministic static gates. Category Q encodes the decision-#2/#5 correctness predicates so future regressions surface in the client rather than as heisenbug DPS behavior.
Output: classes/druid/selftest.lua extended; full phase verification report in the plan summary; phase closed.
</objective>

<recorded_choices>
- Selftests are written against the real framework functions with local stubbing (fake loginContext / fake target) rather than pure-function extraction, because plan 27-01's functions are production-shaped (they read macroTorch.target and loginContext). The save/restore discipline mandated below is what makes that safe — this exact pattern caused a session-wide freeze in Phase 26 (P-02, CR-01) and is the phase's accepted risk control.
- Verification via user game machine (build + /reload + /mt) is end-of-phase user work, recorded in success_criteria; the executor cannot run it.
</recorded_choices>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/debug/catatk-premature-rip-recast.md (decisions #2/#5 — framework contract and deletion list)
@classes/druid/selftest.lua (existing 51 registrations; single top-level `if UnitClass('player') == 'Druid' then` guard; file ends with one `end` closing it — insert Category Q before that final `end`)
@core/selftest.lua (SelfTest:register(name, fn, isOptional) framework — pcall-wrapped per test, optional tests report warnings)
@core/spell_trace_core.lua (plan 27-01 APIs under test)
@classes/druid/Druid.lua (plan 27-02 listener + registrations)
@.planning/STATE.md (Phase 26-03 CR-01 lesson: raw stub/restore discipline)

Key facts (verified at planning time):
- SelfTest:run is wired on PLAYER_ENTERING_WORLD and the /mt slash flow; all existing druid tests pass isOptional=true (trailing `true` argument).
- The stub targets for Category Q: macroTorch.loginContext (fake table with intentTable/landTable buckets) and macroTorch.target (plain table with isCanAttack=true, name='QTestMob'). All framework functions take explicit time parameters (pairLandIntent(spell, landTime), processRawAuraApply(spellName, rawText, targetGuid, now), finalizeFail(spell, failTime), onSelfDamageLine(eventMsg, now)) — designed so tests can drive fake timelines without touching GetTime.
- recordCastTable requires macroTorch.target.isCanAttack and macroTorch.target.name and macroTorch.loginContext — stubbing both globals as plain tables satisfies every guard on the full path (Q-02 exercises the real recordCastTable -> intent -> apply-pair -> land chain).
- Precondition: plans 27-01 and 27-02 fully landed (assert via git grep for recordLandEvent and onLandEvent('Ferocious Bite'); halt on unmet).
</context>

<tasks>

<task type="auto">
  <name>Task 1: Category Q selftest registrations (Q-01..Q-09) in classes/druid/selftest.lua</name>
  <files>classes/druid/selftest.lua</files>
  <precondition>Plans 27-01 and 27-02 have landed: git grep 'function macroTorch%.recordLandEvent' and git grep 'onLandEvent%(.Ferocious Bite.' in the repo both return hits; halt and report if either is absent.</precondition>
  <read_first>
Read classes/druid/selftest.lua — head (guard + naming convention) and tail (final `end` insertion point).
Read core/selftest.lua (SelfTest framework: register(name, fn, isOptional)).
Read core/spell_trace_core.lua (exact signatures of the 6 new functions + LAND_INTENT_TTL).
Read .planning/STATE.md Phase 26-03 entry (CR-01: rawget snapshot / raw-assignment restore pattern).
  </read_first>
  <action>
Insert 9 registrations into classes/druid/selftest.lua immediately BEFORE the file's final `end` (the one closing the `if UnitClass('player') == 'Druid'` guard), each named "Cat Q-0N: <behavior>" with trailing `true` (isOptional). English test names and messages. Behavior per test:

Q-01 landSource registry state (no stubs): assert macroTorch.landSources['Rip'] == 'aura-apply', ['Pounce'] == 'aura-apply', ['Rake'] == 'self-hit', ['Ferocious Bite'] == 'self-hit', ['Serpent Sting'] == 'aura-apply', ['Scorpid Sting'] == 'aura-apply'.

Q-02 aura-apply full pair chain (stubbed): snapshot real macroTorch.loginContext and macroTorch.target into locals; install fake loginContext = {} and fake target = { isCanAttack = true, name = 'QTestMob' }; call macroTorch.recordCastTable('Rip') (drives intent push through the real bridge function); local intent = macroTorch.processRawAuraApply('Rip', '0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 1000.5) (case-different guid); capture results (intent non-nil, intent.state, landTable top value, intent.landAt) into locals; RESTORE both globals by raw assignment (nil where originally nil — CR-01); only then assert: intent ~= nil, state=='landed', landAt==1000.5, and the fake landTable['Rip']['QTestMob'].top == 1000.5.

Q-03 target guid mismatch rejected (stubbed, same restore discipline): seed one pending intent via recordCastTable('Rip') on the fake target, then processRawAuraApply('Rip', '0xF1300000000000AB is afflicted by Rip.', '0xDEADBEEF00000000', 7.0) must return nil and leave the intent state=='pending' and landTable empty.

Q-04 TTL expiry (stubbed): on the fake context, seed intentTable['Rip']['QTestMob'] directly (macroTorch.LRUStack:new(32), push {state='pending', castAt=1.0, landAt=nil}); pairLandIntent('Rip', 5.0) must return nil AND the seeded intent state must be 'expired' (lazy purge). 5.0 - 1.0 > macroTorch.LAND_INTENT_TTL.

Q-05 fail revocation after land (stubbed): seed pending intent {state='pending', castAt=9.0}; pair via processRawAuraApply('Rip', '0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 9.1) (lands, landAt=9.1); then macroTorch.finalizeFail('Rip', 9.3); assert landTable['Rip']['QTestMob'].top ~= 9.1 (entry revoked via removeMatch) and intent state=='failed'.

Q-06 fail-before-apply wins (stubbed): seed pending intent castAt=10.0; call macroTorch.finalizeFail('Rip', 10.4) first (state -> 'failed'); then processRawAuraApply('Rip', '0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 10.5) must return nil (no pending intent left — fail is final regardless of order).

Q-07 self-hit land (stubbed): fake target; no intents seeded; macroTorch.onSelfDamageLine('Your Ferocious Bite hits QTestMob for 548.', 5.0) must land without any intent: fake landTable['Ferocious Bite']['QTestMob'].top == 5.0. Negative arm: macroTorch.onSelfDamageLine('Your Autumn Harvest hits QTestMob for 1.', 5.0) must not create any landTable entry (tracingSpells['Autumn Harvest'] is nil — assert landTable['Autumn Harvest'] == nil).

Q-08 FB renewal listener presence (no stubs): assert type(macroTorch.landListeners) == 'table' and macroTorch.tableLen(macroTorch.landListeners['Ferocious Bite'] or {}) >= 1.

Q-09 deleted machinery absent at runtime (no stubs): assert macroTorch.maintainLandTables == nil and macroTorch.computeLandTable == nil and macroTorch.consumeDruidBattleEvents == nil — the decision-#5 deletion list enforced inside the client.

MANDATORY discipline (enforced by review, not just convention): every stubbed test (Q-02..Q-07) follows compute-into-locals, restore-globals-by-raw-assignment, then assert. No assert statement may precede the restore. No test may write to macroTorch.tracingSpells, macroTorch.landSources, macroTorch.landListeners, or any real loginContext sub-table. Lua 5.0: no # operator, macroTorch.tableLen for lengths; English comments. Do not renumber or alter any existing registration.
  </action>
  <verify>
    <automated>node /home/admin/workspace/macro-torch/.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/selftest.lua; git -C /home/admin/workspace/macro-torch diff --check; grep -c 'Cat Q-0' classes/druid/selftest.lua</automated>
  </verify>
  <done>Nine Category Q registrations appended before the guard's final end; every stub restored before any assert; file passes bbcheck.</done>
  <acceptance_criteria>
1) grep -c 'Cat Q-0' classes/druid/selftest.lua returns 9 (Q-01 through Q-09) and every one ends with `end, true)`.
2) git diff of classes/druid/selftest.lua is pure addition (no existing hunks; diff lines starting with '-' zero).
3) Order audit: in each of Q-02..Q-07 the restore statements (raw `macroTorch.loginContext = savedX` style) appear BEFORE the first assert call — verified by reading the new block.
4) grep for writes to real registries inside the new block returns nothing (no 'macroTorch.landSources[', 'macroTorch.landListeners[', 'macroTorch.tracingSpells[' assignment inside test bodies).
5) bbcheck BALANCED; git diff --check empty.
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Phase-wide verification battery + final commit</name>
  <files>core/spell_trace_core.lua, core/events.lua, core/periodic.lua, classes/druid/Druid.lua, classes/druid/cat.lua, classes/druid/selftest.lua, classes/hunter/Hunter.lua</files>
  <read_first>
Read nothing new — this task executes checks only. The battery below is self-contained; read .planning/debug/catatk-premature-rip-recast.md decision order if any gate fails and triage is needed.
  </read_first>
  <action>
Run the phase-wide battery in order; fix nothing silently — any failure halts the task and goes to the plan summary as a verification finding:

1. Syntax/balance gate: `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js core/spell_trace_core.lua core/events.lua core/periodic.lua classes/druid/Druid.lua classes/druid/cat.lua classes/hunter/Hunter.lua classes/druid/selftest.lua` — all 7 must print BALANCED.
2. Build gate: `bash /home/admin/workspace/macro-torch/build.sh` exits 0. Grep the produced SM_Extend.lua for the new symbol set: pairLandIntent, recordLandEvent, processRawAuraApply, onSelfDamageLine, finalizeFail, onLandEvent, removeMatch — each present; and for 'Ferocious Bite' listener registration present. Confirm SM_Extend.lua is NOT staged (git status — it is ignored).
3. Leftover sweep (decision #5, whole repo, source only): `git grep -n -E 'maintainLandTables|computeLandTable|consumeDruidBattleEvents|RAWDIAG|_rawScout|_diagRipContradiction|_diagLastSafeRipAt|_diagLastRenewingRipAt|lastProcessedBiteEvent' -- '*.lua'` returns NOTHING. (If a hit is a pure comment, remove the comment too — the sweep must be clean.)
4. Scope gate: `git diff --stat` (or `git status` for staged) shows exactly these 7 files modified relative to the phase start commit: the three core files, three class files, druid selftest — plus the planning artifacts (.planning/). entity/Unit.lua, build_order.txt, spell_trace_immune.lua, core/selftest.lua must NOT appear.
5. Fidelity gate: `git diff` for classes/druid/Druid.lua around isRipPresent and ripLeft contains ONLY deletions inside the old diagnostic block (gate 3 confirms no diag identifiers remain); the surviving expressions match git show HEAD (assert: no changed computation line).
6. Lua 5.0 audit on all changed hunks: `git diff` reviewed by eye for — the `#` length operator on table/string expressions; `goto` or `::label::`; any string.find call with a 4th argument. Zero occurrences. (Automated assist: `git grep -n 'goto\|::[a-zA-Z_]*::' -- '*.lua'` must stay empty repo-wide.)
7. Whitespace/EOL gate: `git diff --check` empty.
8. Commit gate: stage ONLY the 7 source files (plus the .planning phase files already committed by the planner); commit with an English conventional message, e.g. `feat(27): event-driven land tracing for spell trace, druid cat integration`. A second commit may split selftest additions (`test(27): Category Q land-framework selftests`) per repo multi-commit convention — both messages in English.
9. Record in 27-03-SUMMARY.md: battery results table, remaining user-side step (build on game machine, /reload, run /mt, expect all Category Q green — end-of-phase UAT).
  </action>
  <verify>
    <automated>export FAIL=0; for f in core/spell_trace_core.lua core/events.lua core/periodic.lua classes/druid/Druid.lua classes/druid/cat.lua classes/hunter/Hunter.lua classes/druid/selftest.lua; do node /home/admin/workspace/macro-torch/.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js "$f" | grep -q BALANCED || FAIL=1; done; bash /home/admin/workspace/macro-torch/build.sh || FAIL=1; O=$(git -C /home/admin/workspace/macro-torch grep -n -E 'maintainLandTables|computeLandTable|consumeDruidBattleEvents|RAWDIAG|_rawScout|_diag' -- '*.lua'); [ -z "$O" ] || FAIL=1; git -C /home/admin/workspace/macro-torch diff --check || FAIL=1; echo "BATTERY_FAIL=$FAIL"</automated>
  </verify>
  <done>All 9 battery steps pass; one or two English-message commits contain exactly the 7 source files; plan summary written with the user-side in-game UAT step recorded.</done>
  <acceptance_criteria>
1) Battery output ends BATTERY_FAIL=0.
2) git show --stat HEAD (and, where split, the second commit) contain only the 7 source files; git status after commit is clean except ignored/build artifacts.
3) 27-03-SUMMARY.md exists and contains the battery results plus the user-side UAT line (build + /mt expecting Category Q green).
4) Commit messages match ^(feat|test|docs)\(27\) with English bodies.
  </acceptance_criteria>
</task>

</tasks>

## Artifacts this phase produces
Created (this plan):
- Category Q selftest registrations Q-01..Q-09 in classes/druid/selftest.lua (all isOptional=true, stub/restore discipline): registry state, aura-apply pairing + TTL, guid mismatch, fail revocation both orders, self-hit land, FB listener presence, legacy machinery absence
- tools/bbcheck.js under the phase directory (Lua-aware bracket-balance gate used by every plan's automated verify)
- 27-03-SUMMARY.md (battery report + user-side UAT step)
Phase-wide symbol inventory (master list — what the phase as a whole produces):
Created: macroTorch.LAND_INTENT_TTL; macroTorch.landSources; macroTorch.auraApplySpellPatterns; macroTorch.landListeners; loginContext.intentTable (LRUStack of {state, castAt, landAt}); macroTorch.pairLandIntent; macroTorch.recordLandEvent; macroTorch.onLandEvent; macroTorch.processRawAuraApply; macroTorch.onSelfDamageLine; macroTorch.finalizeFail; macroTorch.LRUStack:removeMatch; SpellTrace:register landSource extension (config landsource + aura-apply pattern precompile); onLandEvent('Ferocious Bite') renewal listener; landSource='aura-apply' on Rip, Pounce, Serpent Sting, Scorpid Sting; Category Q selftests; tools/bbcheck.js.
Deleted: macroTorch.maintainLandTables + its periodic registration; macroTorch.computeLandTable; macroTorch.consumeDruidBattleEvents + its periodic registration; RAWDIAG scout (events.lua branch + RAWDIAG_KEYWORDS) + arm hook (recordCastTable); ripLeft [DIAG rip-contradiction] dump; safeRip [RAWDIAG] persist + _diag stamps; context._rawScout*/_diag* fields; context.lastProcessedBiteEvent; the GetComboPoints()>0 renewal condition; 0.4s bite-consumption window; (0.02,0.9] blip-window landing semantics.
Unchanged (fidelity commitments): entity/Unit.lua hasBuff internals; isRipPresent/ripLeft duration models; cast bridging (UNIT_CASTEVENT + _pendingCastSpellName, UNIT_SPELLCAST_SUCCEEDED); build_order.txt; spell_trace_immune.lua.

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| selftest execution environment | Tests run inside the user's live client session at /mt; a leaked stub or mutated global outlives the test run (Phase 26 P-02/CR-01 precedent: session-wide freeze) |
| verification commands | Repo-local node script (bbcheck.js, committed planning artifact) and build.sh — both simple, reviewable, no network |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-27-07 | Tampering | selftest stubs polluting live session state | high | mitigate | Compute-into-locals + restore-globals-before-assert discipline mandated in Task 1 and re-checked in acceptance criterion 3; all Q tests isOptional=true; SelfTest framework pcall-wraps each test; no test writes real registries |
| T-27-08 | Spoofing | verification gates gamed by stale artifacts | low | mitigate | BB-check regenerates SM_Extend.lua before greps; leftover sweep targets code identifiers (not output text); the 4-arg string.find check and goto check are independent greps over source |
| T-27-SC | Tampering | npm/pip/cargo installs | n/a | accept | No package installs — bbcheck.js uses the repo's existing node runtime |

ASVS level 1; the single high-severity threat (T-27-07) carries a concrete, code-level mitigation that Task 1 implements and Task 2 verifies.
</threat_model>

<verification>
Phase-completion level (equals Task 2 battery): bbcheck on 7 files; ./build.sh; repo-wide leftover sweep (9 identifiers) empty; diff scope = 7 source files (+planning); isRipPresent/ripLeft fidelity; Lua 5.0 audit; git diff --check; commit hygiene.
User-side (recorded, not executable by the agent): on the game machine — pull, Cygwin build.sh, /reload, run /mt, expect all 9 Category Q tests green and zero [RAWDIAG]/[DIAG] output; then a dummy-fight smoke run with Rip/Rake/FB to observe Renewing lines driven by hit events.
</verification>

<success_criteria>
- Category Q (Q-01..Q-09) registered with stub/restore discipline; phase battery fully green; leftovers zero; scope exact; fidelity gates hold.
- Artifacts this phase produces (sum): created — macroTorch.LAND_INTENT_TTL, macroTorch.landSources, macroTorch.auraApplySpellPatterns, macroTorch.landListeners, loginContext.intentTable (LRUStack of {state,castAt,landAt}), macroTorch.pairLandIntent, macroTorch.recordLandEvent, macroTorch.onLandEvent, macroTorch.processRawAuraApply, macroTorch.onSelfDamageLine, macroTorch.finalizeFail, macroTorch.LRUStack:removeMatch, SpellTrace:register landSource/aura-apply-pattern extension, FB renewal listener (Druid.lua), landSource='aura-apply' on Rip/Pounce/Serpent Sting/Scorpid Sting, Category Q selftests, tools/bbcheck.js; deleted — macroTorch.maintainLandTables, macroTorch.computeLandTable, registerPeriodicTask('maintainLandTables'), macroTorch.consumeDruidBattleEvents + its periodic task, RAWDIAG scout (events.lua) + arm hook + RAWDIAG_KEYWORDS, ripLeft [DIAG rip-contradiction] dump, safeRip [RAWDIAG] persist + _diag stamps, context._rawScout*/_diag* fields, the GetComboPoints()>0 renewal condition, the 0.4s bite window and the (0.02,0.9] blip window semantics.
- build_order.txt unchanged; entity/Unit.lua untouched; SM_Extend.lua never committed; all commits English-message.
</success_criteria>

<output>
Create .planning/phases/27-catatk-event-driven-land-tracing-refactor/27-03-SUMMARY.md when done
</output>