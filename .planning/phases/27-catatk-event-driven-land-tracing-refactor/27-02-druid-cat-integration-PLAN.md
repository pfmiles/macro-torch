---
phase: 27-catatk-event-driven-land-tracing-refactor
plan: 02
type: execute
wave: 2
depends_on:
  - 27-01
files_modified:
  - classes/druid/Druid.lua
  - classes/druid/cat.lua
  - classes/hunter/Hunter.lua
autonomous: true
requirements: []          # no requirement IDs assigned for phase 27 (recorded visible skip)

estimate:
  tokens: 26000
  raw_tokens: 26000
  tasks: 3
  confidence: low         # derived: 0 calibration samples

must_haves:
  truths:
    - "Rip and Pounce register with landSource='aura-apply' (no initial direct damage for Rip); Rake and Ferocious Bite use the default 'self-hit' (debug decision #3)"
    - "A Ferocious Bite land event immediately rewrites the Rake and Rip land entries with land = FB event time; the GetComboPoints()>0 condition is REMOVED — the hit event itself proves the hit (debug decision #3, user's Tortoise-WoW talent explanation)"
    - "Bite renewal never writes lastRipEquippedSavagery/lastRakeEquippedSavagery — the 16.2s/18s self-reported clock model continues from the new land time (debug decision #3/#4)"
    - "isRipPresent = hasBuff('Ability_GhoulFrenzy') AND ripLeft>0 keeps byte-for-byte semantics; ripLeft/rakeLeft duration models untouched; ONLY the land timestamp source changes (debug decision #4)"
    - "entity/Unit.lua hasBuff internals untouched (user forbids touching debuff-icon detection); no tick/fade-based expiry introduced — the self-reported clock remains the expiry predictor (debug decision #4)"
    - "consumeDruidBattleEvents and its registerPeriodicTask are deleted; all [DIAG]/[RAWDIAG] debug-session logging (rip-contradiction dump, _diag* stamps, safeRip RAWDIAG persist line) is removed — druid half of debug decision #5"
    - "Lua 5.0 compliance and LF endings (debug decision #7); no build_order.txt change needed (no new files)"
  artifacts:
    - classes/druid/Druid.lua (register configs + FB renewal listener; deleted legacy consumer)
    - classes/druid/cat.lua (safeRip diagnostics removed)
    - classes/hunter/Hunter.lua (landSource migration for the two DoT stings)
  key_links:
    - onLandEvent('Ferocious Bite', listener) -> isRipPresent/isRakePresent gate -> recordLandEvent('Rip'/'Rake', FB event time) -> ripLeft/rakeLeft clocks
    - SpellTrace:register landSource entries -> landSources/auraApplySpellPatterns in core (plan 27-01) -> events.lua RAW handler
---

<objective>
Integrate druid cat skills (and the two Hunter DoT stings that already land-trace) with the event-driven framework from plan 27-01: set landSource per skill, replace the periodic bite-renewal chain with an FB-land-event listener, and delete every remaining piece of the old polling machinery plus all debug-session diagnostic code from the druid layer.

Purpose: Complete the end-to-end behavioral rework from debug decisions #2-#5 so the phase is coherent as a whole — no polling task, no bite-renewal windows, no diagnostic noise — and the ripLeft/rakeLeft self-reported clocks are fed exclusively by events.
Output: Three class files updated; druid-side deletions complete; hunter immune-tracing land semantics preserved under the new default.
</objective>

<recorded_choices>
- Hunter Sting landSource: Serpent Sting / Scorpid Sting are DoTs with no 'Your X hits' self-damage line, so under the new default ('self-hit') their land events would silently stop and Hunter immune/definite-bleeding tracing would regress. Migration to landSource='aura-apply' preserves today's behavior through the new framework. This is planner judgment within the generic opt-in framework of debug decision #2 (any class any spell), not a locked decision; it is called out here as the phase's one behavior-preserving non-druid touch.
- Rake keeps the default 'self-hit' (unchanged register call besides the explicitness comment): Rake always produces 'Your Rake hits/crits' direct-damage lines, so no RAW pairing is needed for it.
</recorded_choices>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/debug/catatk-premature-rip-recast.md  (locked decisions #3/#4/#5)
@core/spell_trace_core.lua  (functions introduced by plan 27-01: recordLandEvent, onLandEvent, landSources, auraApplySpellPatterns)
@classes/druid/Druid.lua
@classes/druid/cat.lua
@classes/hunter/Hunter.lua

Key facts (verified at planning time):
- Druid.lua register block at lines 680-700 declares Pounce/Rake/Rip/Ferocious Bite (land=true, immune per current config) and Faerie Fire (Feral) (land=false).
- consumeDruidBattleEvents (lines 702-736): periodic 0.1s task; consumes Ferocious Bite land events through a 0.4s window + GetComboPoints()>0 gate + lastProcessedBiteEvent dedup + isRipPresent/isRakePresent self-lock, then pseudo-casts via recordCastTable('Rake'/'Rip'); stamps _diagLastRenewingRipAt.
- ripLeft (1106-1160) and isRipPresent (1097-1103): computation at 1106-1128 must survive verbatim; the [DIAG rip-contradiction] one-shot dump block at 1129-1158 is debug-session code scheduled for deletion.
- cat.lua safeRip (413-433): keep the 'Rip!!!' show line + lastRipEquippedSavagery + context.lastRipAtCp writes; delete lines 425-426 (_diagLastSafeRipAt stamp, _diagRipContradictionActive re-arm) and 427-431 ([RAWDIAG] safeRip fired persist line).
- Hunter.lua register block at lines 151-160 declares Serpent Sting / Scorpid Sting with land=true, immune=true.
- Plan 27-01 made recordCastTable seed 2s-expiring intents; consumeDruidBattleEvents' pseudo-casts would therefore be misread by the new framework if left alive — deletion here is load-bearing, not cosmetic.
- Precondition: plan 27-01 functions (recordLandEvent, onLandEvent) exist; if they do not, halt and report 27-01 incomplete.
</context>

<tasks>

<task type="auto">
  <name>Task 1: landSource registrations + FB-land-event renewal listener in Druid.lua</name>
  <files>classes/druid/Druid.lua</files>
  <precondition>plan 27-01 executors have landed recordLandEvent and onLandEvent in core/spell_trace_core.lua (assert with git grep 'function macroTorch%.recordLandEvent\|function macroTorch%.onLandEvent' before starting; halt on unmet).</precondition>
  <read_first>
Read classes/druid/Druid.lua lines 680-745 (register block + consumeDruidBattleEvents to be replaced).
Read .planning/debug/catatk-premature-rip-recast.md decisions #2/#3/#4 (landSource enum, renewal semantics, snapshot rule).
Read core/spell_trace_core.lua (recordLandEvent/onLandEvent signatures — listener receives (spell, landTime)).
  </read_first>
  <action>
1. Register config updates (lines 681-700): add landSource = 'aura-apply' to the Pounce register config table and landSource = 'aura-apply' to the Rip register config table (both are aura-only lands — Rip has no initial direct damage; decision #3). Leave Rake and Ferocious Bite config tables untouched except adding a one-line English comment above them stating they use the default 'self-hit' source (direct-damage hit/crit lines). Do not touch the Faerie Fire (Feral) entry.
2. Replace the whole consumeDruidBattleEvents block — the function definition (lines 703-733) AND its trailing macroTorch.registerPeriodicTask('consumeDruidBattleEvents', { interval = 0.1, task = macroTorch.consumeDruidBattleEvents }) line — with a single English-commented registration using the plan-27-01 API:
   macroTorch.onLandEvent('Ferocious Bite', function(landTime) ... end)
   Listener body, in order:
   a. local clickContext = {}
   b. if macroTorch.isRakePresent(clickContext) then — show the same 'Renewing rake... left: ' message shape as today (rakeLeft(clickContext) plus lastRakeEquippedSavagery read), then macroTorch.recordLandEvent('Rake', landTime)
   c. if macroTorch.isRipPresent(clickContext) then — show the same 'Renewing rip... left: ' message shape as today (ripLeft(clickContext) plus lastRipEquippedSavagery read), then macroTorch.recordLandEvent('Rip', landTime)
   INVARIANTS (decision #3/#4): NO GetComboPoints() call anywhere in the listener — the FB hit event is the proof of the hit; NO context.lastProcessedBiteEvent bookkeeping; NO recordCastTable pseudo-casts; NO _diagLastRenewingRipAt stamp; the takeover bridge fields lastRipEquippedSavagery / lastRakeEquippedSavagery / context.lastRipAtCp are only READ (in the show lines / by ripLeft), never written — the 16.2s/18s clock model continues from land = the FB event time. The rake check stays before the rip check (matches the old order).
3. Do NOT touch isRipPresent (1097-1103), isRakePresent, the computation part of ripLeft/rakeLeft, or anything else in this file in this task — deletion of the ripLeft diagnostic block is Task 2's job; the renewal listener must call recordLandEvent directly (it is a renewal, not a cast — no intent pairing occurs).
4. Lua 5.0 conventions: no # length operator, no goto; English comments; LF endings.
  </action>
  <verify>
    <automated>node /home/admin/workspace/macro-torch/.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/Druid.lua; git -C /home/admin/workspace/macro-torch diff --check</automated>
  </verify>
  <done>Rip/Pounce carry landSource='aura-apply'; the FB renewal listener replaces the periodic consumer with the exact decision-#3 semantics; Druid.lua passes bbcheck.</done>
  <acceptance_criteria>
1) grep -n "landSource = 'aura-apply'" classes/druid/Druid.lua returns exactly 2 lines, inside the Pounce and Rip register config tables (verify by viewing lines 681-700).
2) git grep -n 'consumeDruidBattleEvents' -- classes/druid/Druid.lua returns nothing (definition and periodic registration deleted together).
3) grep -n "onLandEvent('Ferocious Bite'" classes/druid/Druid.lua returns 1 line.
4) Between the listener's opening and its closing end (the block around the renewal), grep -n 'GetComboPoints\|recordCastTable\|lastProcessedBiteEvent\|_diag' returns nothing.
5) grep -n "recordLandEvent('Rip'\|recordLandEvent('Rake'" classes/druid/Druid.lua returns exactly the two listener calls, and NO line in the listener assigns lastRipEquippedSavagery or lastRakeEquippedSavagery (only reads inside tostring(...)).
6) git grep -n "landSource" -- classes/druid/Druid.lua confirms Rake/Ferocious Bite blocks have no landSource key (they inherit the default) — exactly 2 aura-apply assignments total.
7) bbcheck BALANCED; git diff --check empty; ./build.sh succeeds (bindings resolve in artifact).
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Delete druid-side legacy polling consumer branch + all debug-session diagnostics</name>
  <files>classes/druid/Druid.lua, classes/druid/cat.lua</files>
  <read_first>
Read classes/druid/Druid.lua lines 1097-1160 (isRipPresent + ripLeft with the diagnostic block to carve out).
Read classes/druid/cat.lua lines 413-434 (safeRip with the two diagnostic additions).
Read .planning/debug/catatk-premature-rip-recast.md file header (trigger: diagnostics inserted without touching catAtk judgment) + decision #5 deletion list.
  </read_first>
  <action>
Deletions only — no new behavior, no new functions, no edits outside the listed regions:

1. In classes/druid/Druid.lua, remove the [DIAG rip-contradiction] one-shot dump: the entire block starting at the comment line that reads '-- [DIAG catatk-premature-rip-recast] one-shot forensic dump on contradiction entry:' through the matching else-branch close of the context._diagRipContradictionActive assignment (current lines ~1129-1158), so ripLeft ends with `return clickContext.ripLeft` immediately after the clickContext.ripLeft = ripLeft computation. Verify after edit: the surviving ripLeft body is the guard (peekLandEvent('Rip') -> 0 or duration math) with zero log/context._diag* references; isRipPresent above it untouched.
2. Confirm no other _diag*/_rawScout references remain in Druid.lua (consumeDruidBattleEvents already gone via Task 1); clean any dangling comment mentioning the removed task.
3. In classes/druid/cat.lua, inside safeRip remove exactly the three debug-session additions from the return-true branch: the _diagLastSafeRipAt stamp line, the _diagRipContradictionActive re-arm line, and the [RAWDIAG] safeRip fired macroTorch.log block with its preceding comment. Keep byte-for-byte: the 'Rip!!! At cp: ...' show line, the player.rip('ready') call, the lastRipEquippedSavagery assignment, and the context.lastRipAtCp assignment.
4. Conventions: English comments, LF endings, Lua 5.0 syntax in every untouched region (no reformatting).
  </action>
  <verify>
    <automated>node /home/admin/workspace/macro-torch/.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/Druid.lua classes/druid/cat.lua; git -C /home/admin/workspace/macro-torch diff --check</automated>
  </verify>
  <done>The druid layer contains zero [DIAG]/[RAWDIAG] code and zero _diag* fields; ripLeft and isRipPresent compute exactly as before; catAtk judgment code untouched.</done>
  <acceptance_criteria>
1) git grep -n '_diagRipContradiction\|_diagLastSafeRipAt\|_diagLastRenewingRipAt\|\[DIAG\|\[RAWDIAG\]' -- classes/druid/Druid.lua classes/druid/cat.lua returns nothing.
2) git diff of Druid.lua around ripLeft shows ONLY deletions in the diagnostic block range — no changed line inside the computation (grep the diff for lines starting '-' and confirm they all carry diag markers or the removed comment; surviving computation lines appear verbatim in pre-phase git show).
3) grep -n "Rip!!! At cp:" classes/druid/cat.lua returns 1 line and the surrounding region shows lastRipEquippedSavagery and lastRipAtCp assignments intact.
4) git grep -n "function macroTorch%.isRipPresent" -- classes/druid/Druid.lua returns 1 and the function source matches git show HEAD:classes/druid/Druid.lua for lines 1097-1103 (byte-for-byte via diff).
5) bbcheck BALANCED for both files; ./build.sh succeeds.
6) git diff --stat for this task shows only classes/druid/Druid.lua and classes/druid/cat.lua.
  </acceptance_criteria>
  <reversibility rating="costly">
Removal of debug-session instrumentation (context _diag* fields, RAWDIAG persist lines) and the last legacy consumption pathway. Rated costly, not one-way-needed-here: the 27-01 Task 1 checkpoint:decision explicitly authorized this druid half of decision #5 in its options before implementation began (single coherent gate for the whole phase's deletions; a second mid-flight pause would re-ask the same question). Recovery only via git history; flagged for reviewer attention.
  </reversibility>
</task>

<task type="auto">
  <name>Task 3: Hunter Sting landSource migration (behavior-preserving under the new default)</name>
  <files>classes/hunter/Hunter.lua</files>
  <read_first>
Read classes/hunter/Hunter.lua lines 145-165 (both register calls).
Read .planning/debug/catatk-premature-rip-recast.md decision #2 (landSource enum + default 'self-hit').
Read core/spell_trace_core.lua (register handling of landSource, plan 27-01: landSources map + auraApplySpellPatterns precompute).
  </read_first>
  <action>
In classes/hunter/Hunter.lua, add landSource = 'aura-apply' to the Serpent Sting register config table and to the Scorpid Sting register config table, each preceded by a one-line English comment: these stings apply via periodic DoT with no 'Your X hits' direct-damage line, so 'aura-apply' (RAW 'is afflicted by' pairing) preserves the land evidence that Hunter immune/definite-bleeding tracing consumed under the old blip mechanism. Change nothing else in the file. This is the phase's only non-druid touch — required so the default change in plan 27-01 does not silently regress Hunter land events (recorded choice).
  </action>
  <verify>
    <automated>node /home/admin/workspace/macro-torch/.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/hunter/Hunter.lua; git -C /home/admin/workspace/macro-torch diff --check; bash /home/admin/workspace/macro-torch/build.sh</automated>
  </verify>
  <done>Both Hunter stings register with landSource='aura-apply'; Hunter immune tracing keeps working through the event-driven path; build passes.</done>
  <acceptance_criteria>
1) grep -n "landSource = 'aura-apply'" classes/hunter/Hunter.lua returns exactly 2.
2) git diff for Hunter.lua is limited to the two config tables plus their comments (no other hunks).
3) bbcheck BALANCED; ./build.sh succeeds; SM_Extend.lua contains 'auraApplySpellPatterns['Serpent Sting']' spelling after register (grep the artifact for 'is afflicted by Serpent Sting' pattern construction — the string ' is afflicted by ' .. name .. '%.' will materialize; at minimum grep 'Serpent Sting' in the artifact).
4) git diff --check empty.
  </acceptance_criteria>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Client chat/Raw events → druid integration | FB hit/crit lines (self-owned) and RAW apply lines (target-owned, paired with our intents in core) drive the renewal listener |
| druid logic → self-reported clocks | The listener writes landTable via recordLandEvent; consumers (ripLeft/rakeLeft) read the top — trust relationship unchanged from before |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-27-05 | Spoofing | FB renewal rewriting Rip/Rake land | medium | mitigate | Renewal fires only on the client's own 'Your Ferocious Bite hits/crits' line (self-owned channel) and is additionally gated by isRipPresent/isRakePresent — the same hasBuff + clock authority as before; removing the CP condition cannot create a false renewal because the hit event is stronger proof than CP>0 (decision #3) |
| T-27-06 | Tampering | listener mutates loginContext landTable | low | accept | Listener runs only on own-cast events; writes are timestamp pushes to per-spell stacks already consumed by the same clock code; no privilege or cross-character state touched |
| T-27-SC | Tampering | npm/pip/cargo installs | n/a | accept | No package installs in this phase |

ASVS level 1; no unmitigated high-severity threats; renewal preserves the snapshot non-modification invariant (lastRipEquippedSavagery/lastRakeEquippedSavagery never written by renewal).
</threat_model>

<verification>
Phase-plan level:
1. node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/Druid.lua classes/druid/cat.lua classes/hunter/Hunter.lua — all BALANCED.
2. ./build.sh passes; grep the SM_Extend.lua artifact for onLandEvent and 'Serpent Sting' wiring; artifact stays uncommitted.
3. git diff --check clean.
4. Mission-final greps for the druid layer: consumeDruidBattleEvents, GetComboPoints inside the renewal listener, _diag*, [DIAG], [RAWDIAG] all absent from classes/druid/Druid.lua and classes/druid/cat.lua.
5. git grep -n 'hasBuff' -- entity/Unit.lua shows the file untouched by this phase (git diff stat excludes it).
6. Behavioral layer deferred to plan 27-03 Category Q selftests (renewal listener presence Q-08; runtime absence of legacy machinery Q-09).
</verification>

<success_criteria>
- Druid cat integration matches debug decision #3 exactly: aura-apply for Rip/Pounce, self-hit default for Rake/FB, FB-land-event renewal without the CP condition, snapshots untouched.
- The old bite-renewal chain (0.4s window + CP + pseudo-cast + blip) no longer exists in any source file; debug-session logging fully removed from druid files.
- Hunter Sting land tracing preserved (recorded choice documented in <recorded_choices>).
- All modified files pass bbcheck, git diff --check, and ./build.sh; commit contains only source files with an English conventional message.
</success_criteria>

<output>
Create .planning/phases/27-catatk-event-driven-land-tracing-refactor/27-02-SUMMARY.md when done
</output>