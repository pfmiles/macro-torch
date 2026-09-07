---
phase: quick-260907-mhh-rip-landing-rawdiag-forensics-build
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - core/events.lua
  - core/spell_trace_core.lua
  - classes/druid/cat.lua
autonomous: true
requirements:
  - QUICK-260907-MHH
user_setup:
  - service: wow-client
    why: "Forensics evidence can only be produced in game, on the user's Windows+Cygwin machine (this host cannot run WoW 1.12/SuperWoW). After the code lands: (1) run build.sh on Windows+Cygwin to regenerate SM_Extend.lua into the two AddOns dirs; (2) login a druid, run /mt — all selftests including Category Q and Category S must pass (instrumentation is gated off out of combat, so expected output is unchanged); (3) execute the R0~R3 sampling protocol from .planning/todos/pending/druid-rip-land-forensics-next-cd.md on training dummies with 1-2 other feral cats: R0 solo baseline, R1 decisive test — our Rip cast while another cat's Rip is ALREADY active on the target, R2 self-refresh, R3 cast after natural expiry; keep >=5s spacing between different casters' casts and cast no Ferocious Bite during the test (bite renews Rip on this server and falsifies the window); each Rip cast auto-arms the 60s/150-line window and prints [RAWDIAG2] armed/ctx/pair lines in chat plus the raw arg dump; (4) logout/reload and copy back WTF/Account/<account>/SavedVariables/SuperMacro.lua (MACRO_TORCH_LOG.messages holds all [RAWDIAG2] lines, 500-line rotating buffer) for offline arbitration: ctx line with hasBuff=false + ripLeft=0 + landTop=nil + no following pair-ok line + keyword dump silent about Rip applies while another cat's Rip is active = client-side apply-line suppression confirmed; hasBuff=true in the ctx line = debuff-view leg instead. Companion protocol steps (green-landed-line count, listDebuffs/hasBuff/peekLandEvent probes) from the same todo run unchanged alongside."
must_haves:
  truths:
    - "Disarmed is invisible: when macroTorch.context is absent or _rawdiag2Active falsy, the RAW_COMBATLOG branch spends exactly one boolean test on the scout and skips it — the tier-1 channel whitelist and every downstream handler are untouched, so production behavior is byte-identical to today"
    - "Arming: every recorded in-combat Rip cast (all three record paths — UNIT_CASTEVENT bridge, UNIT_SPELLCAST_SUCCEEDED, and any future call — funnel through recordCastTable) resets _rawdiag2Lines/_rawdiag2Samples to 0, sets _rawdiag2Active, restarts the 60s window, and appends one '[RAWDIAG2] scout armed' line; a repeat cast inside a live window re-anchors the full 60s/150-line budget"
    - "Dumping: while armed, every RAW_COMBATLOG line (all channels — the scout runs BEFORE the channel whitelist) is serialized arg-by-arg nil-safe (arg1..arg12 via _G lookups, stop at first nil) and persisted through macroTorch.log iff it matches one of Rip/Rake/Bite/afflicted/fades or is among the first 20 samples of the current arm; every dumped line carries the '[RAWDIAG2] line=<n> t=<time>' prefix"
    - "Auto-disarm: window age > 60s or >= 150 dumped lines sets _rawdiag2Active=false and appends the '[RAWDIAG2] scout disarmed' line with the dumped count; every counter and flag lives only in macroTorch.context (combat exit wipes them) — nothing but the log text itself enters SavedVariables"
    - "Pair ledger: while armed, every aura-apply line that reaches processRawAuraApply (Rip or Pounce) appends exactly one '[RAWDIAG2 pair] <Spell> pair-ok|no-pair:<reason>' line naming the outcome and the reason (no-apply-marker / guid-mismatch / no-intent)"
    - "Decision ctx: every accepted safeRip cast appends exactly one '[RAWDIAG2 ctx] hasBuff= ripLeft= landTop= intentDepth= cp= t=' line reading the decision inputs BEFORE macroTorch.player.rip('ready') fires"
    - "Neutrality: the git diff of the three files is strictly additive (no existing line modified, so no branch, return value, guard or scheduling changes); no macroTorch.cpBuildLog reference is added (fully independent gating); all existing selftests keep passing because every new log path is gated on armed in-combat state that an out-of-combat /mt run cannot produce (arm requires macroTorch.inCombat; pair logs require _rawdiag2Active which combat-exit wipes and selftests never set; no selftest calls safeRip)"
  artifacts:
    - core/events.lua
    - core/spell_trace_core.lua
    - classes/druid/cat.lua
  key_links:
    - "recordCastTable (spell_trace_core.lua:86, the single choke point every Rip cast record flows through — events.lua:125 UNIT_CASTEVENT bridge and events.lua:158 UNIT_SPELLCAST_SUCCEEDED) -> macroTorch.context._rawdiag2Active/_rawdiag2Start/_rawdiag2Lines/_rawdiag2Samples -> events.lua RAW_COMBATLOG scout placed ABOVE the tier-1 channel whitelist -> macroTorch.log (interface_debug.lua:103) -> MACRO_TORCH_LOG SavedVariables, flushed to SuperMacro.lua on logout"
    - "events.lua aura-apply pattern loop (lines 147-154) -> processRawAuraApply (spell_trace_core.lua:238) -> armed pair ledger: the apply line that proves whether the CLIENT emitted a Rip apply after our cast (the decisive suppression signal is the ledger's silence after an armed ctx line)"
    - "safeRip (cat.lua:417) decision inputs: macroTorch.target.hasBuff('Ability_GhoulFrenzy') (Unit.lua:26 UnitDebuff 1..40 scan), macroTorch.ripLeft(clickContext) (memoized clickContext cache), macroTorch.peekLandEvent('Rip'), macroTorch.rawdiag2IntentDepth('Rip') (new read-only helper), clickContext.comboPoints -> one [RAWDIAG2 ctx] line before the cast"
---

<objective>
Restore a RAWDIAG-style forensics instrument set (RAWDIAG2) for the
multi-cat Rip landing suppression verdict, as a pure additive forensics build
that changes zero decision logic. Three probes: (1) a RAW_COMBATLOG scout in
core/events.lua placed BEFORE the tier-1 channel whitelist that auto-arms on
every recorded in-combat Rip cast and dumps raw event args (keyword filtered,
first-20 unconditional sampling, 60s / 150-line auto-disarm, counters reset per
arm); (2) a [RAWDIAG2 pair] ledger in processRawAuraApply naming each pairing
outcome and the no-pair reason; (3) a [RAWDIAG2 ctx] stamp in safeRip recording
the decision inputs (hasBuff / ripLeft / landTable top / intent stack depth /
cp) at the instant a Rip cast is committed.

Purpose: decide in game whether the CLIENT suppresses raw apply lines
("X is afflicted by Rip." arriving on CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE)
when any feral's Rip is already active on the target. Server-side logs show
17/17 applies, so suppression — if real — is client-line-level; only the
client-side RAW stream can arbitrate. The three probes together isolate the
moment: ctx line captures the decision state at cast time, the pair ledger
records the client's apply line outcome within the armed window, and the raw
dump shows what related raw traffic actually flowed.

Output: three files gain strictly additive blocks only (core/events.lua,
core/spell_trace_core.lua, classes/druid/cat.lua). Druid.lua stays untouched:
ripLeft/isRipPresent values are read from already-computed clickContext caches
inside safeRip, so the decision functions need no edits. interface_debug.lua is
untouched (macroTorch.log already persists) and SM_Extend.lua is NOT rebuilt
(established quick-task convention; the user rebuilds on their game machine).
</objective>

<execution_context>@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@core/events.lua
@core/spell_trace_core.lua
@classes/druid/cat.lua
@.planning/todos/pending/druid-rip-land-forensics-next-cd.md

Grounding facts, all verified by reading at planning time (do not re-verify
blindly; the plan's anchors are live). Two reference commits exist in git
history and their exact shapes were diffed into this plan:

- `git show 8ffd759` — the original RAWDIAG scout (deleted later): arming hook
  inside recordCastTable plus the RAW_COMBATLOG dump block. The original's two
  flaws being fixed here: it dumped only lines that passed the tier-1 channel
  whitelist (the suppression bug lives in the CHAT_MSG_SPELL_PERIODIC_* channels
  themselves, so the scout must run BEFORE the whitelist), and it used
  `parts[#parts + 1]` — the Lua 5.0-forbidden # operator. This plan's scout
  reuses its structure (window/age/cap/sample semantics, _G['arg'..i] nil-safe
  serialization, macroTorch.log persistence) with RAWDIAG2 naming and no #.
- `git show cf5ade7` — the DIAG stamp shape adopted for the [RAWDIAG2 ctx]
  line at safeRip (success-branch stamp + context fields, pure additive).

Line anchors (current HEAD):

- core/events.lua: `local frame = CreateFrame("Frame")` at line 21 (keyword
  table goes after it). RAW_COMBATLOG branch: `elseif event == "RAW_COMBATLOG"
  then` at line 130, immediately followed by the comment `-- production
  event-driven land handler (three-tier filter, debug` at line 131 and the
  tier-1 whitelist `if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and
  arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then` at line 136.
  The scout block is inserted BETWEEN line 130 and line 131. After the
  whitelist the tier-2/3 loop (lines 147-154) iterates
  macroTorch.auraApplySpellPatterns and calls
  macroTorch.processRawAuraApply(spellName, arg2, macroTorch.target.guid,
  GetTime()) — untouched.
- core/spell_trace_core.lua: recordCastTable spans lines 86-126; the intent
  seed push `macroTorch.loginContext.intentTable[spell][mob].push({ state =
  'pending', castAt = GetTime(), landAt = nil })` is line 125 and the function
  closes with `end` at line 126 — the arm hook is inserted between them (after
  the 0.2s dedup return at lines 106-108 and all guards, so a deduped or
  non-attackable record never arms). pairLandIntent closes with `return nil` /
  `end` at lines 193-194; `-- records a land event on the landTable...` is line
  195 — the read-only depth helper is inserted between lines 194 and 195.
  processRawAuraApply spans lines 238-268: guards at 239-244 (spell/rawText
  nil, then `local markerPos = string.find(rawText, ' is afflicted by ')` +
  `if not markerPos then return nil end`), guid parse/extract + mismatch return
  at 246-249, `local intent = macroTorch.pairLandIntent(spellName, now)` at
  line 255, `if intent then ... show green ... recordLandEvent ... end` at
  256-266, `return intent` 267. All four logger insertions are additive
  statements around these exact lines; no existing line changes.
- classes/druid/cat.lua: safeRip spans lines 417-435. Inside the success branch
  the show() call ends at line 428 (`. .. macroTorch.computeRip_Duration(...) ..
  's')`) and `macroTorch.player.rip('ready')` is line 429 — the ctx stamp goes
  between lines 428 and 429, 8-space indent. safeRip is called from exactly one
  production site (cat.lua:330 via dischargeEnergyChangeRelicAndRip) and by NO
  selftest (verified: grep safeRip / player.rip over selftest.lua files = zero
  hits), so the stamp cannot pollute /mt runs.
- Selftest safety (requirement 4): Q-02/Q-03 call macroTorch.recordCastTable
  ('Rip') and Q-02/Q-05 call processRawAuraApply, all out of combat with an
  armed-gate-invisible context. Arm hook requires macroTorch.inCombat (nil
  out of combat), pair logs require context._rawdiag2Active (wiped on combat
  exit — combat_context.lua onCombatExit resets macroTorch.context = {}; never
  set by any selftest), the events.lua scout only runs on RAW_COMBATLOG events.
  Q tests assert on intent/land state and stub `show` (not log) — nothing new
  can fire there.
- macroTorch.context lifecycle: onCombatEnter creates it ({} if absent),
  onCombatExit replaces it with {} — so all _rawdiag2* state dies with combat;
  nothing is persisted (increments and caps live in macroTorch.context only,
  per the locked gating decision).
- macroTorch.log (interface_debug.lua:103) shows + appends tostring(a) to
  MACRO_TORCH_LOG.messages (500-entry rotating buffer). GetTime() is
  seconds-with-ms precision, resets per login. DO NOT modify interface_debug.lua.
- Intents are keyed by spell then target NAME: intentTable[spell][mob] is an
  LRUStack with a public .elements list (spell_trace_core.lua itself reads
  stack.elements at lines 177-190). macroTorch.tableLen(impl_util.lua:92) is
  the Lua 5.0-safe length.
- Verification tooling grounded live: node v24 +
  .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js
  (bracket-balance gate, the repo's established syntax proxy — no Lua
  interpreter exists on this host). Repo conventions: English comments, LF
  endings, Lua 5.0 only, and every ADDED line must contain no `#` character at
  all (the plan-wide token gate greps diff +lines for goto/#/::; even the line
  counter prefix must be 'line=' not '#'.)
</context>

<tasks>

<task type="auto">
  <name>Add the RAWDIAG2 forensics scout to events.lua (pre-whitelist dump) and the auto-arm hook to spell_trace_core.lua recordCastTable</name>
  <files>core/events.lua, core/spell_trace_core.lua</files>
  <action>
This task builds the window machinery: the RAW_COMBATLOG dump in core/events.lua and the arming hook in core/spell_trace_core.lua. Edit ONLY these two files. Every change is a pure insertion — no existing line may be modified, moved or deleted (the plan-wide strictly-additive gate enforces this). English comments, LF endings, Lua 5.0 only: no # operator, no goto, no labels, no long-string escapes, and no `#` character in ANY added line (comment or code — the global token gate fails on it). Do NOT reference macroTorch.cpBuildLog anywhere (requirement 5: fully independent gating). Do NOT touch interface_debug.lua, classes/druid/*, or rebuild SM_Extend.lua.

PART 1 — core/events.lua, EDIT A: insert the keyword table directly after line 21 (`local frame = CreateFrame("Frame")`), with one blank line before the block and one after (so the existing comment block at lines 23+ keeps its separation). File-indent level 0, exactly:

1. Comment: `-- [RAWDIAG2 quick 260907-mhh] keyword filter for the RAW_COMBATLOG forensics`
2. Comment: `-- dump. The scout below dumps only while macroTorch.context._rawdiag2Active is`
3. Comment: `-- armed; recordCastTable in spell_trace_core.lua arms it on a recorded Rip cast.`
4. `local RAWDIAG2_KEYWORDS = { 'Rip', 'Rake', 'Bite', 'afflicted', 'fades' }`

PART 2 — core/events.lua, EDIT B: insert the scout block into the RAW_COMBATLOG branch BETWEEN line 130 (`    elseif event == "RAW_COMBATLOG" then`) and line 131 (the `-- production event-driven land handler` comment). Do not alter the whitelist if at line 136. 8-space indent (same level as the branch's existing comment lines), exactly these lines in order:

1. Comment: `-- [RAWDIAG2 quick 260907-mhh] forensics scout, placed BEFORE the tier-1 channel`
2. Comment: `-- whitelist so it sees every RAW_COMBATLOG line while armed. Arbitration target:`
3. Comment: `-- does this client suppress raw apply lines when any feral Rip is already`
4. Comment: `-- active on the target (multi-cat)? The scout auto-disarms after a 60s window`
5. Comment: `-- or once _rawdiag2Lines reaches the 150-line cap; the first 20 events of a`
6. Comment: `-- fresh arm are dumped unconditionally as field-layout samples, after that`
7. Comment: `-- only RAWDIAG2_KEYWORDS matches. State lives in macroTorch.context (combat`
8. Comment: `-- exit wipes it, never persisted); output persists via macroTorch.log.`
9. `local scoutActive = macroTorch.context and macroTorch.context._rawdiag2Active`
10. `if scoutActive then`
11. `local scoutCtx = macroTorch.context`
12. `if (GetTime() - (scoutCtx._rawdiag2Start or GetTime())) > 60 then`
13. `scoutCtx._rawdiag2Active = false`
14. `macroTorch.log('[RAWDIAG2] scout disarmed after 60s window, dumped: ' ..`
15. `tostring(scoutCtx._rawdiag2Lines or 0) .. ' lines', 'yellow')`
16. `elseif (scoutCtx._rawdiag2Lines or 0) >= 150 then`
17. `scoutCtx._rawdiag2Active = false`
18. `macroTorch.log('[RAWDIAG2] scout disarmed after 150-line cap, dumped: ' ..`
19. `tostring(scoutCtx._rawdiag2Lines or 0) .. ' lines', 'yellow')`
20. `else`
21. Comment: `-- serialize every event arg verbatim, nil-safe: WoW 1.12 exposes event`
22. Comment: `-- args as arg1..argN globals; stop at the first nil. Lua 5.0 has no #`
23. Comment: `-- operator, so the parts list grows through table.insert and a counter.`
24. `local parts = {}`
25. `local ai = 1`
26. `while ai <= 12 and _G['arg' .. ai] ~= nil do`
27. `table.insert(parts, 'arg' .. ai .. '=' .. tostring(_G['arg' .. ai]))`
28. `ai = ai + 1`
29. `end`
30. `local serialized = table.concat(parts, ' | ')`
31. `local interesting = false`
32. `for _, kw in ipairs(RAWDIAG2_KEYWORDS) do`
33. `if string.find(serialized, kw, 1, true) then`
34. `interesting = true`
35. `break`
36. `end`
37. `end`
38. `if interesting or (scoutCtx._rawdiag2Samples or 0) < 20 then`
39. `scoutCtx._rawdiag2Lines = (scoutCtx._rawdiag2Lines or 0) + 1`
40. `scoutCtx._rawdiag2Samples = (scoutCtx._rawdiag2Samples or 0) + 1`
41. `macroTorch.log('[RAWDIAG2] line=' .. tostring(scoutCtx._rawdiag2Lines) ..`
42. `' t=' .. string.format('%.3f', GetTime()) .. ' ' .. serialized, 'green')`
43. `end`
44. `end`
45. `end`
46. Comment: `-- end of RAWDIAG2 scout block (arming hook: spell_trace_core.lua recordCastTable)`

(The dump increments both counters only when a line is actually dumped; non-matching post-sample-20 lines increment nothing — identical semantics to the removed 8ffd759 scout. The 60s/150-line checks use `or GetTime()` / `or 0` defaults so a half-armed context can never error.)

PART 3 — core/spell_trace_core.lua, EDIT A (the arm hook): insert between line 125 (the intent push ending `landAt = nil })`) and line 126 (`end`, the closer of recordCastTable). 4-space indent (the function body level), exactly:

1. Comment: `-- [RAWDIAG2 quick 260907-mhh] arm the RAW_COMBATLOG forensics scout on a`
2. Comment: `-- recorded in-combat Rip cast (pure additive state recording; no existing`
3. Comment: `-- branch, return value or scheduling is touched). The scout itself dumps in`
4. Comment: `-- events.lua's RAW_COMBATLOG branch, before the channel whitelist. Every arm`
5. Comment: `-- resets the per-window line/sample counters and restarts the 60s window, so`
6. Comment: `-- in a repeat-cast fight each cast anchors a fresh full window (the decisive`
7. Comment: `-- multi-cat overlap evidence is per-cast). State lives only in`
8. Comment: `-- macroTorch.context: combat exit wipes it, nothing is persisted, and the`
9. Comment: `-- gating is fully independent of macroTorch.cpBuildLog.`
10. `if spell == 'Rip' and macroTorch.context and macroTorch.inCombat then`
11. `macroTorch.context._rawdiag2Lines = 0`
12. `macroTorch.context._rawdiag2Samples = 0`
13. `macroTorch.context._rawdiag2Active = true`
14. `macroTorch.context._rawdiag2Start = GetTime()`
15. `macroTorch.log('[RAWDIAG2] scout armed by Rip cast record, 60s / 150-line window', 'green')`
16. `end`

Why the inCombat guard is load-bearing: in game every real Rip cast record fires while the player is in combat, so nothing is lost; but selftest Q-02/Q-03 call recordCastTable('Rip') OUT of combat, and this guard keeps the arm (and its macroTorch.log line) from ever firing during /mt runs. Why reset-on-every-arm instead of only-fresh-arm (a documented deviation from 8ffd759): the 8ffd759 scout was recon for a single window; this forensics build's decisive evidence is per-cast in a repeat-cast fight (the bug is continuous re-casting), so each cast re-anchors the full budget.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB core/events.lua && node $BB core/spell_trace_core.lua && grep -qF "local RAWDIAG2_KEYWORDS = { 'Rip', 'Rake', 'Bite', 'afflicted', 'fades' }" core/events.lua && test "$(grep -n "if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE'" core/events.lua | head -1 | cut -d: -f1)" -gt "$(grep -n '_rawdiag2Active' core/events.lua | head -1 | cut -d: -f1)" && test "$(grep -c '_rawdiag2Active = false' core/events.lua)" = "2" && grep -qF "while ai <= 12 and _G['arg' .. ai] ~= nil do" core/events.lua && grep -qF "table.insert(parts, 'arg' .. ai .. '=' .. tostring(_G['arg' .. ai]))" core/events.lua && grep -qF "if interesting or (scoutCtx._rawdiag2Samples or 0) < 20 then" core/events.lua && grep -qF "'[RAWDIAG2] line=' .. tostring(scoutCtx._rawdiag2Lines) .." core/events.lua && grep -qF "if spell == 'Rip' and macroTorch.context and macroTorch.inCombat then" core/spell_trace_core.lua && test "$(grep -c '_rawdiag2Lines = 0' core/spell_trace_core.lua)" = "1" && grep -qF "macroTorch.context._rawdiag2Active = true" core/spell_trace_core.lua && grep -qF "macroTorch.context._rawdiag2Start = GetTime()" core/spell_trace_core.lua && grep -qF "macroTorch.log('[RAWDIAG2] scout armed by Rip cast record, 60s / 150-line window', 'green')" core/spell_trace_core.lua && echo "T1 GATE OK"</automated>
  </verify>
  <done>
bbcheck prints `core/events.lua: BALANCED` and `core/spell_trace_core.lua: BALANCED` (exit 0). The keyword table literal exists. Positional gate passes: the scout's first `_rawdiag2Active` read sits at a LOWER line number than the tier-1 channel whitelist if at line 136 (scout runs before the whitelist). events.lua has exactly 2 `_rawdiag2Active = false` disarm assignments (60s branch + 150-line branch), the nil-safe arg serialization loop, the first-20 unconditional sample gate, and the `[RAWDIAG2] line=` dump statement. spell_trace_core.lua has exactly one `_rawdiag2Lines = 0` reset, the arm condition with the inCombat guard, the flag/start assignments and the `[RAWDIAG2] scout armed` log line. `git diff` of both files shows insertions only — the whitelist if, the dedup return, the intent push and every other existing line unchanged.
  </done>
</task>

<task type="auto">
  <name>Add the [RAWDIAG2 pair] ledger to processRawAuraApply and the rawdiag2IntentDepth helper to spell_trace_core.lua</name>
  <files>core/spell_trace_core.lua</files>
  <action>
Edit only core/spell_trace_core.lua (continuation of the same file; T1 lines are now in place — keep them intact). Pure insertions only; English comments; Lua 5.0; no `#` character anywhere in added lines; no macroTorch.cpBuildLog reference.

EDIT A — the read-only depth helper. Insert between line 194 (the `end` closing pairLandIntent) and line 195 (the `-- records a land event on the landTable` comment block), file-indent level 0:

1. Blank line comes free (line 194/195 already adjacent — the block goes between them, keeping the existing blank-line separation intact).
2. Comment: `-- [RAWDIAG2 quick 260907-mhh] read-only pending-intent stack depth for a spell`
3. Comment: `-- on the current target (feeds the safeRip ctx stamp's intentDepth field).`
4. Comment: `-- Pure forensics utility: zero writes, defined next to the intentTable it reads.`
5. `function macroTorch.rawdiag2IntentDepth(spell)`
6. `local mob = macroTorch.target.name`
7. `if macroTorch.loginContext and macroTorch.loginContext.intentTable and`
8. `macroTorch.loginContext.intentTable[spell] and`
9. `macroTorch.loginContext.intentTable[spell][mob] then`
10. `return macroTorch.tableLen(macroTorch.loginContext.intentTable[spell][mob].elements)`
11. `end`
12. `return 0`
13. `end`

EDIT B — the armed flag local. In processRawAuraApply, insert directly after the existing guard block (`if not spellName or not rawText then` / `return nil` / `end` at lines 239-241) and before the existing comment `-- parse the guid...`/line 242:

1. Comment: `-- [RAWDIAG2 quick 260907-mhh] pair ledger armed only inside a live scout window.`
2. Comment: `-- Combat exit wipes macroTorch.context, so the armed flag cannot leak into a`
3. Comment: `-- later fight or into a selftest run (out-of-combat /mt never arms it).`
4. `local armed = macroTorch.context and macroTorch.context._rawdiag2Active`

EDIT C — no-marker reason. Before the existing `return nil` inside the `if not markerPos then` block (the guard at lines 243-245), insert two lines (8-space indent, matching that block):
1. `if armed then`
2. `macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' no-pair:no-apply-marker', 'yellow')`
3. `end`

EDIT D — guid-mismatch reason. Before the existing `return nil` inside the guid-mismatch block (lines 247-249), insert:
1. `if armed then`
2. `macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' no-pair:guid-mismatch target=' .. tostring(targetGuid) .. ' line=' .. guid, 'yellow')`
3. `end`

EDIT E — pair-ok and no-intent. After the existing `if intent then ... macroTorch.recordLandEvent(spellName, now) ... end` block (closes at line 266) and before the existing `return intent` (line 267), insert at the function-body indent:
1. `if armed and intent then`
2. `macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' pair-ok guid=' .. guid ..`
3. `' t=' .. string.format('%.3f', now), 'green')`
4. `end`
5. `if armed and not intent then`
6. `macroTorch.log('[RAWDIAG2 pair] ' .. spellName .. ' no-pair:no-intent t=' ..`
7. `string.format('%.3f', now), 'yellow')`
8. `end`

Do NOT restructure the existing `if intent then` block with an else — the two statements in EDIT E are standalone additive ifs after it, so the pairing branch itself is untouched (requirement 4). The green pair-ok line prints after the existing show/recordLandEvent sequence, which preserves the causal print order (green landing line still comes first). In-game `now` is always GetTime() (events.lua:150) and selftests always pass a number, so string.format('%.3f', now) is safe; and in selftest runs `armed` is falsy (T1's inCombat guard means Q-02/Q-03 never arm), so none of these logs can fire during /mt.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB core/spell_trace_core.lua && grep -qF 'function macroTorch.rawdiag2IntentDepth(spell)' core/spell_trace_core.lua && test "$(grep -n 'function macroTorch.rawdiag2IntentDepth(spell)' core/spell_trace_core.lua | cut -d: -f1)" -gt "$(grep -n 'function macroTorch.pairLandIntent(spell, landTime)' core/spell_trace_core.lua | cut -d: -f1)" && grep -qF 'local armed = macroTorch.context and macroTorch.context._rawdiag2Active' core/spell_trace_core.lua && test "$(grep -v '^--' core/spell_trace_core.lua | grep -c 'RAWDIAG2 pair')" = "4" && grep -qF "' no-pair:no-apply-marker', 'yellow')" core/spell_trace_core.lua && grep -qF "' no-pair:guid-mismatch target=' .. tostring(targetGuid) .. ' line=' .. guid, 'yellow')" core/spell_trace_core.lua && grep -qF "' pair-ok guid=' .. guid .." core/spell_trace_core.lua && grep -qF "' no-pair:no-intent t=' .." core/spell_trace_core.lua && test "$(grep -n "local armed = macroTorch.context and macroTorch.context._rawdiag2Active" core/spell_trace_core.lua | cut -d: -f1)" -gt "$(grep -n 'function macroTorch.processRawAuraApply' core/spell_trace_core.lua | cut -d: -f1)" && test "$(grep -n "local armed = macroTorch.context and macroTorch.context._rawdiag2Active" core/spell_trace_core.lua | cut -d: -f1)" -lt "$(grep -n 'function macroTorch.finalizeFail' core/spell_trace_core.lua | cut -d: -f1)" && echo "T2 GATE OK"</automated>
  </verify>
  <done>
bbcheck prints `core/spell_trace_core.lua: BALANCED` (exit 0). The helper `macroTorch.rawdiag2IntentDepth(spell)` exists and sits between pairLandIntent and recordLandEvent. The `local armed = ...` declaration exists inside processRawAuraApply's body (its line number is greater than the `function macroTorch.processRawAuraApply` line and less than the `function macroTorch.finalizeFail` line). Exactly 4 `RAWDIAG2 pair` log statements exist in non-comment lines: pair-ok, no-pair:no-intent, no-pair:guid-mismatch, no-pair:no-apply-marker — each spelling the exact reason literal. `git diff` shows the existing `if intent then` block, all four existing return statements, and every guard line byte-unchanged.
  </done>
</task>

<task type="auto">
  <name>Add the [RAWDIAG2 ctx] decision stamp to safeRip in classes/druid/cat.lua</name>
  <files>classes/druid/cat.lua</files>
  <action>
Edit only classes/druid/cat.lua. Pure insertion; English comments; Lua 5.0; no `#` character in added lines.

Insert into safeRip's success branch BETWEEN line 428 (the end of the existing show() call, the line `', expDuration: ' .. tostring(macroTorch.computeRip_Duration(clickContext.comboPoints, savageryNow)) .. 's')`) and line 429 (`macroTorch.player.rip('ready')`). 8-space indent, exactly these lines in order:

1. Comment: `-- [RAWDIAG2 quick 260907-mhh] stamp the Rip cast decision inputs BEFORE the`
2. Comment: `-- cast fires: the exact state the isRipPresent contradiction is made of`
3. Comment: `-- (hasBuff / ripLeft / last land / pending-intent depth / cp) at the decision`
4. Comment: `-- instant. Pure additive logging, no existing branch, return value or`
5. Comment: `-- scheduling is touched (same one-shot stamp shape as removed commit`
6. Comment: `-- cf5ade7). Only reads: clickContext.ripLeft / clickContext.isRipPresent were`
7. Comment: `-- already computed earlier in this same click (safeRip always runs after`
8. Comment: `-- shouldCastRip), so these reads hit caches and nothing can change any`
9. Comment: `-- later decision in the click.`
10. `local rawdiag2LandTop = macroTorch.peekLandEvent('Rip')`
11. `macroTorch.log('[RAWDIAG2 ctx] hasBuff=' .. tostring(macroTorch.target.hasBuff('Ability_GhoulFrenzy')) ..`
12. `' ripLeft=' .. string.format('%.3f', macroTorch.ripLeft(clickContext)) ..`
13. `' landTop=' .. (rawdiag2LandTop and string.format('%.3f', rawdiag2LandTop) or 'nil') ..`
14. `' intentDepth=' .. tostring(macroTorch.rawdiag2IntentDepth('Rip')) ..`
15. `' cp=' .. tostring(clickContext.comboPoints) ..`
16. `' t=' .. string.format('%.3f', GetTime()), 'yellow')`

Interpretation contract for the offline arbitration (why this placement and these fields): this line fires on every accepted Rip cast, including the bug's repeat casts; hasBuff=false proves the client sees no Rip debuff on the target at the decision moment (debuff-view leg), while hasBuff=true combined with ripLeft=0 and landTop=nil proves the land-clock leg. One line per cast keeps volume bounded (only our own casts). safeRip is the chosen 决策处 over the 对立决策点 alternative because every actual cast decision culminates here exactly once per cast, and it is proven unreachable from any selftest.
  </action>
  <verify>
    <automated>cd /home/admin/workspace/macro-torch && BB=.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js && node $BB classes/druid/cat.lua && test "$(grep -v '^--' classes/druid/cat.lua | grep -c 'RAWDIAG2 ctx')" = "1" && grep -qF "local rawdiag2LandTop = macroTorch.peekLandEvent('Rip')" classes/druid/cat.lua && grep -qF "'[RAWDIAG2 ctx] hasBuff=' .. tostring(macroTorch.target.hasBuff('Ability_GhoulFrenzy')) .." classes/druid/cat.lua && grep -qF "' ripLeft=' .. string.format('%.3f', macroTorch.ripLeft(clickContext)) .." classes/druid/cat.lua && grep -qF "' landTop=' .. (rawdiag2LandTop and string.format('%.3f', rawdiag2LandTop) or 'nil') .." classes/druid/cat.lua && grep -qF "' intentDepth=' .. tostring(macroTorch.rawdiag2IntentDepth('Rip')) .." classes/druid/cat.lua && grep -qF "' cp=' .. tostring(clickContext.comboPoints) .." classes/druid/cat.lua && grep -qF "' t=' .. string.format('%.3f', GetTime()), 'yellow')" classes/druid/cat.lua && test "$(grep -n "macroTorch.player.rip('ready')" classes/druid/cat.lua | cut -d: -f1)" -gt "$(grep -n 'RAWDIAG2 ctx' classes/druid/cat.lua | head -1 | cut -d: -f1)" && echo "T3 GATE OK"</automated>
  </verify>
  <done>
bbcheck prints `classes/druid/cat.lua: BALANCED` (exit 0). Exactly one `RAWDIAG2 ctx` statement exists in non-comment lines; all six field fragments (hasBuff with the 'Ability_GhoulFrenzy' texture, ripLeft via macroTorch.ripLeft(clickContext), landTop via the rawdiag2LandTop local, intentDepth via rawdiag2IntentDepth('Rip'), cp via clickContext.comboPoints, t via GetTime) are present as the exact line-local literals; the ctx line number is LESS than the `macroTorch.player.rip('ready')` line (capture happens before the cast). `git diff` shows the safety guards, the show() call, `macroTorch.player.rip('ready')`, the savagery snapshot and `return true` lines all byte-unchanged — the stamp is append-only inside the success branch.
  </done>
</task>

</tasks>

<threat_model>## Trust Boundaries

None crossed. The instrumentation writes only to the addon's own chat echo and
MACRO_TORCH_LOG SavedVariables buffer through the existing macroTorch.log; it
reads only Raw event args and client state the addon already reads. No new
external inputs are consumed, no package installs, no privilege context, no
network surface.

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-quick-260907-mhh-01 | Information Disclosure | core/events.lua scout raw arg dump (other players' GUIDs/spell lines from the client RAW stream) | low | accept | Lines land only in the player's own MACRO_TORCH_LOG (WTF SavedVariables, local file) while the player is actively engaged in the R0~R3 sampling session with consenting helpers; the same data is already visible to the client in its own combatlog; disarmed by default and wiped on combat exit |
| T-quick-260907-mhh-02 | Denial of Service | Armed-window log volume vs the 500-line MACRO_TORCH_LOG rotating buffer | low | accept | Bounded by design: 150 dumped RAW lines per arm window + one pair/ctx/armed line per own-cast event; macroTorch.log already rotates the oldest lines at maxSize 500 (pre-existing behavior); worst case the oldest window samples rotate out, same failure mode as the production diagnostic lines |
</threat_model>

<verification>
After all three tasks, confirm the combined diff is exactly right:

```bash
cd /home/admin/workspace/macro-torch && git status --porcelain
# exactly: ` M core/events.lua`, ` M core/spell_trace_core.lua`,
# ` M classes/druid/cat.lua` — nothing else; SM_Extend.lua MUST NOT appear

cd /home/admin/workspace/macro-torch && git diff --check
# exit 0, no output — LF preserved, no trailing whitespace
```

Strictly-additive gate (only `+` lines from the diff may exist; any modified or
deleted line is a violation of requirement 4's no-decision-changes mandate):

```bash
cd /home/admin/workspace/macro-torch && N=$(git diff -U0 -- core/events.lua core/spell_trace_core.lua classes/druid/cat.lua | grep -E '^-' | grep -vc '^---'); test "$N" = "0" && echo "ADDITIVE GATE OK" || echo "ADDITIVE GATE FAILED: $N removed/modified lines"
```

Lua 5.0 token gate over the whole diff (no length #, no goto, no labels — and
therefore no `#` character is allowed in ANY added line, comments included):

```bash
cd /home/admin/workspace/macro-torch && if git diff -U0 -- core/events.lua core/spell_trace_core.lua classes/druid/cat.lua | grep -E '^\+' | grep -vE '^\+\+' | grep -qE '\bgoto\b|#|::'; then echo "TOKEN GATE FAILED"; exit 1; else echo "TOKEN GATE OK"; fi
```

Independence gate (requirement 5: gating must not couple to the cpBuildLog
facility from quick 260907-0ya):

```bash
cd /home/admin/workspace/macro-torch && if git diff -U0 -- core/events.lua core/spell_trace_core.lua classes/druid/cat.lua | grep -E '^\+' | grep -q 'cpBuildLog'; then echo "CPBUILD COUPLING FOUND"; exit 1; else echo "CPBUILD INDEPENDENCE OK"; fi
```

Re-run the T1, T2 and T3 task gates; all three must exit 0 with their `GATE OK`
echo. Selftest-safety eyeball, last line of defense: `git diff --stat --
classes/druid/selftest.lua` is empty (no test file touched) and, per the
anchors verified at planning time, the three new log paths are unreachable from
an out-of-combat /mt run (arm requires macroTorch.inCombat; pair logs require
_rawdiag2Active, wiped on combat exit and never set by selftests; no selftest
calls safeRip). In-game validation plus the R0~R3 sampling protocol and the
MACRO_TORCH_LOG copy-back are the user_setup follow-up — they run on the
Windows+Cygwin game machine and cannot be automated offline.
</verification>

<success_criteria>
- T1 gate exits 0: bbcheck BALANCED on core/events.lua and core/spell_trace_core.lua; keyword table literal present; scout's `_rawdiag2Active` read sits above the tier-1 whitelist line; exactly 2 disarm assignments; nil-safe `_G['arg' .. ai]` serialization, first-20 sample gate, `[RAWDIAG2] line=` dump, and in spell_trace_core the inCombat-guarded arm hook with counter resets, flag/start writes, and the `[RAWDIAG2] scout armed` line.
- T2 gate exits 0: bbcheck BALANCED on core/spell_trace_core.lua; `rawdiag2IntentDepth` helper sits between pairLandIntent and recordLandEvent; `local armed` declaration inside processRawAuraApply; exactly 4 non-comment `RAWDIAG2 pair` log statements with the distinct reason literals (pair-ok / no-intent / guid-mismatch / no-apply-marker).
- T3 gate exits 0: bbcheck BALANCED on classes/druid/cat.lua; exactly one `RAWDIAG2 ctx` statement; all six field fragments present; ctx line number below `macroTorch.player.rip('ready')`.
- ADDITIVE GATE prints OK: zero removed/modified lines across the three files (every decision branch, return value, guard and scheduling untouched).
- TOKEN GATE prints OK: added lines contain no goto, no `#`, no `::` (Lua 5.0 constraint, user memory wow-lua50-syntax).
- CPBUILD INDEPENDENCE OK: no added line references macroTorch.cpBuildLog.
- `git status --porcelain` shows exactly the three source files; SM_Extend.lua not rebuilt and not touched; `git diff --check` clean (LF, no trailing whitespace); classes/druid/selftest.lua and interface_debug.lua untouched.
- In-game validation is staged per user_setup (build.sh on the user's Cygwin machine, /mt selftest pass, R0~R3 dummy protocol with 1-2 helper ferals, logout copy-back of MACRO_TORCH_LOG) — the out-of-phase evidence collection, not an offline gate.
- One atomic conventional commit, e.g. `chore(druid): add RAWDIAG2 Rip landing forensics instrumentation (quick 260907-mhh)`, containing only the three allowed files.
</success_criteria>

<output>Create `.planning/quick/260907-mhh-rip-landing-rawdiag-forensics-build-1-co/260907-mhh-SUMMARY.md` when done
</output>