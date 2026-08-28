---
phase: 27-catatk-event-driven-land-tracing-refactor
plan: 01
subsystem: core/game-events
tags: [lua50, wow112, combat-log, land-tracing]

# Dependency graph
requires:
  - phase: 26-catatk-fast-battle-logic
    provides: [name-keyed tracingSpells registration, UNIT_SPELLCAST_SUCCEEDED record branch, _pendingCastSpellName cast bridge]
  - phase: 27-catatk-event-driven-land-tracing-refactor-debug
    provides: [locked decisions #1-#8 including the intent state machine contract, channel evidence (CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE / _HOSTILEPLAYER_DAMAGE), ownership rules]

provides:
  - macroTorch.LAND_INTENT_TTL = 2 and loginContext.intentTable (LRUStack(32) of pending/landed/failed/expired cast intents per spell x target-name)
  - macroTorch.pairLandIntent (TTL purge + newest-pending pairing), recordLandEvent (landTable push + listener dispatch, no intent side effects), onLandEvent (listener registry)
  - macroTorch.processRawAuraApply (guid parse + case-insensitive current-target match + intent-gated land at apply time), onSelfDamageLine (pairing-free self-hit land), finalizeFail (fail-wins consumption + land revocation, hooked into recordFailTable)
  - macroTorch.landSources + auraApplySpellPatterns registries with SpellTrace:register landSource support ('self-hit' default, 'aura-apply' precompiles its find pattern)
  - macroTorch.LRUStack:removeMatch (newest-matching element removal, additive in core/periodic.lua)
  - core/events.lua production three-tier RAW_COMBATLOG land handler (channel whitelist -> O(N) precompiled-pattern find, zero allocation) + self-hit dispatch after CheckDodgeParryBlockResist
  - Deletions (debug decision #5 core half): maintainLandTables + 0.1s periodic registration, computeLandTable blip machinery, RAWDIAG recon scout (events.lua keyword table + scout branch + recordCastTable arm hook)

affects:
  - 27-02-druid-cat-integration (registers Rip/Rake with landSource='aura-apply', FB self-hit listener, deletes consumeDruidBattleEvents)
  - 27-03-selftest-verification-cleanup (Category Q in-game selftests validate this framework's behavioral truth)
  - core/spell_trace_immune.lua (unchanged consumer of land/fail events produced here)
  - classes/druid/Druid.lua (transient: consumeDruidBattleEvents pseudo-casts now seed intents that die at TTL; removed in 27-02)

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 4898   # 19593 diff chars / 4 over core/spell_trace_core.lua + core/events.lua + core/periodic.lua
  tasks: 3       # Task 1 checkpoint resolved option-a by orchestrator; Tasks 2-3 executed here
  commits: 4     # 2 source commits + docs(27-01) summary commit + docs(phase-27) tracking commit

# Tech tracking
tech-stack:
  added: []      # no packages installed (T-27-SC)
  patterns: [cast-intent state machine with 2s TTL (pending/landed/failed/expired), three-tier RAW event filter, fail-wins land revocation via LRUStack:removeMatch, per-spell landSource registry (self-hit | aura-apply), onLandEvent listener dispatch]

key-files:
  created: []
  modified:
    - core/spell_trace_core.lua   # intent framework + 6 new functions, poller deletion, arm hook removed
    - core/events.lua             # production three-tier RAW handler + self-hit dispatch, scout removed
    - core/periodic.lua           # LRUStack:removeMatch (additive)

key-decisions:
  - "Checkpoint option-a: polling land machinery (maintainLandTables + computeLandTable here, consumeDruidBattleEvents in 27-02) and the RAWDIAG scout are permanently deleted per locked debug decision #5 — recovery only via git history"
  - "Land ownership split: aura-apply lands (RAW) are target-owned and must pair with a cast intent plus a case-insensitive current-target guid match; self-hit lands ('Your <skill> hits/crits') are client-authenticated and record without pairing"
  - "Fail is final: finalizeFail consumes the newest pending/landed intent within TTL, revokes any land it produced, and marks it failed — independent of land/fail arrival order"

patterns-established:
  - "Event-driven land generation: land correctness no longer depends on machine performance (0.1s polling + 0.02-0.9s blip window eliminated); apply/fail/hits/crits events drive land/revoke directly at near-zero latency"
  - "Three-tier RAW filter: tier-1 channel whitelist on arg1, then O(N) string.find over precompiled ' is afflicted by <spell>.' patterns (embeds precheck), zero allocation on the hot path"
  - "Intent pairing contract: recordCastTable seeds pending intents; pairLandIntent never pairs failed/landed intents; finalizeFail expires nothing itself but consumes within TTL"

requirements-completed: []  # copied verbatim from plan frontmatter (phase 27 has no requirement IDs)

# Coverage metadata (#1602) — one entry per shipped deliverable.
coverage:
  - id: D1
    description: "LRUStack:removeMatch — newest-matching element removal used for land-entry revocation"
    verification: []
    human_judgment: true
    rationale: "Behavioral truth (newest-first predicate match used by finalizeFail revocation) is exercised only by the 27-03 Category Q in-game selftests; static gates here prove syntax only."
  - id: D2
    description: "recordCastTable intent seeding + intentTable state machine (pending/landed/failed/expired, 2s TTL, keyed spell x target-name in loginContext)"
    verification: []
    human_judgment: true
    rationale: "TTL expiry and fail/land consumption are runtime semantics deferred to 27-03 Category Q in-game selftests; static proof here is syntax-only."
  - id: D3
    description: "pairLandIntent — purge pass expiring stale pending intents + newest-pending pairing within TTL, never pairs failed/landed intents (fail-wins guarantee)"
    verification: []
    human_judgment: true
    rationale: "Pairing TTL correctness requires in-game event timing; plan defers behavioral proof to 27-03 Category Q selftests."
  - id: D4
    description: "recordLandEvent + onLandEvent — landTable push plus listener dispatch with zero intent side effects"
    verification: []
    human_judgment: true
    rationale: "Listener presence (27-02 registers the FB listener) and dispatch semantics are verified in game; static only here."
  - id: D5
    description: "processRawAuraApply — guid parse (string.sub), case-insensitive current-target ownership match, intent-gated land at apply time (threat T-27-01 mitigation)"
    verification: []
    human_judgment: true
    rationale: "Guid-mismatch spoofing resistance requires real RAW lines in game; deferred to 27-03 Category Q selftests."
  - id: D6
    description: "finalizeFail — fail-wins intent consumption + land revocation via removeMatch, called from recordFailTable"
    verification: []
    human_judgment: true
    rationale: "Arrival-order independence (land-before-fail vs fail-before-land) is in-game behavioral truth deferred to 27-03 Category Q."
  - id: D7
    description: "onSelfDamageLine — 'Your <skill> hits/crits <target>.' parse into pairing-free self-hit lands, dispatched after CheckDodgeParryBlockResist on CHAT_MSG_SPELL_SELF_DAMAGE"
    verification: []
    human_judgment: true
    rationale: "Pattern matching against the real localized chat stream is verified in game; static only here."
  - id: D8
    description: "events.lua production three-tier RAW_COMBATLOG handler replacing the RAWDIAG recon scout (channel whitelist + precompiled pattern loop), RAWDIAG_KEYWORDS table deleted"
    verification: []
    human_judgment: true
    rationale: "End-to-end land generation via the live RAW stream is verified in game (27-03 Category Q); static gates prove syntax only."
  - id: D9
    description: "Static verification gates pass: bbcheck BALANCED on all 3 files, build.sh strict build, git diff --check clean, grep gates (zero _rawScout/RAWDIAG refs, cast bridge hunks absent, channel counts 3/3)"
    verification:
      - kind: other
        ref: "node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js core/spell_trace_core.lua core/events.lua core/periodic.lua"
        status: pass
      - kind: other
        ref: "bash build.sh && grep -c pairLandIntent / processRawAuraApply SM_Extend.lua"
        status: pass
      - kind: other
        ref: "git diff --check HEAD~2 HEAD && git grep -n '_rawScout|RAWDIAG' -- core/*.lua (empty)"
        status: pass
    human_judgment: false

# Metrics
duration: 17min
completed: 2026-08-29
status: complete
---

# Phase 27 Plan 01: Core event-driven land framework Summary

**Polling machinery deleted; event-driven land framework with 2s cast intents, aura-apply pairing, pairing-free self-hit lands, fail-wins revocation, and a production three-tier raw combat-log handler**

## Performance

- **Duration:** ~17 min (continuation session; Task 1 checkpoint resolved by orchestrator before this session)
- **Started:** 2026-08-28T17:00:00Z (continuation handoff)
- **Completed:** 2026-08-28T17:17:00Z
- **Tasks:** 3 (Task 1 checkpoint:decision resolved option-a; Task 2, Task 3 executed)
- **Files modified:** 3 (core/spell_trace_core.lua, core/events.lua, core/periodic.lua)

## Accomplishments

- Land events for registered spells now come exclusively from game events: aura-apply land source wired end-to-end for Rip's path (RAW apply line pairs with the target-owned cast intent and lands at apply time), self-hit land source for every registered self-hit spell (client-authenticated `Your <skill> hits/crits` line, zero pairing requirement)
- The communication-tower polling pair (maintainLandTables 0.1s periodic task + computeLandTable blip window) is deleted — the root cause of premature Rip recasts on lagged machines (debug decision #5, core half)
- Fail is final across either arrival order: recordFailTable now finalizes the intent (consume pending or landed, revoke the land entry via LRUStack:removeMatch) — an early land can no longer masquerade as a success after a fail arrives
- castTable semantics unchanged for all consumers (intent seeding is additive); UNIT_CASTEVENT / UNIT_SPELLCAST_SUCCEEDED bridging stays byte-for-byte (debug decision #2)
- The RAWDIAG recon scout is fully replaced by the production handler: zero `_rawScout` / `RAWDIAG` references remain in core/*.lua

## Verification Log (acceptance criteria + plan verification)

| Gate | Result |
|------|--------|
| Task 2 A1 — 6 framework functions in spell_trace_core.lua | PASS (lines 158/194/219/233/255/291) |
| Task 2 A2 — removeMatch = definition + 1 comment line | PASS |
| Task 2 A3 — maintainLandTables/computeLandTable gone from all *.lua | PASS |
| Task 2 A4 — no RAWDIAG/_rawScout in spell_trace_core.lua | PASS |
| Task 2 A5 — bbcheck BALANCED both files, diff --check clean | PASS |
| Task 2 A6 — diff stat = exactly spell_trace_core.lua + periodic.lua | PASS |
| Task 2 A7 — build.sh exit 0, artifact contains pairLandIntent | PASS (4 hits) |
| Task 2 A8 — no 4-arg string.find in new hunks | PASS (all 2-arg) |
| Task 3 A1 — no RAWDIAG/_rawScout/RAWDIAG_KEYWORDS in events.lua | PASS |
| Task 3 A2 — 3 wire lines (pairs loop, process call, dispatch call) | PASS |
| Task 3 A3 — channel literal counts 3 / 3 | PASS |
| Task 3 A4 — CheckDodgeParryBlockResist single call site | PASS |
| Task 3 A5 — bridged hunks absent from diff | PASS |
| Task 3 A6 — bbcheck BALANCED, diff --check clean, build exit 0 | PASS |
| Task 3 A7 — processRawAuraApply definition + call site both in artifact | PASS (2771 / 4133) |
| Plan V1 — bbcheck BALANCED on all 3 files | PASS |
| Plan V2 — build.sh strict pass, pairLandIntent + processRawAuraApply in artifact | PASS |
| Plan V3 — git diff --check over plan commits | PASS |
| Plan V4 — no _rawScout/RAWDIAG in core/*.lua (post both tasks) | PASS |
| Plan V5 — diff stat limited to the 3 core files | PASS |
| Plan V6 — Lua 5.0 spot audit: no # operator (non-comment), no goto, no 4-arg string.find | PASS |
| Plan V7 — behavioral layer | Deferred by design to 27-03 Category Q in-game selftests, per plan |

## Task Commits

Each task was committed atomically:

1. **Task 1: Confirm deletion scope (checkpoint:decision)** — resolved `option-a` by orchestrator (user reply "请继续"); zero code changes, zero commits (per locked debug decision #5)
2. **Task 2: Core event-driven land framework** — `ff925bb` (feat)
3. **Task 3: Production RAW_COMBATLOG handler + self-hit dispatch** — `3c1e2db` (feat)

**Plan metadata:** `docs(27-01)` commit (SUMMARY.md) — see close-out

## Files Created/Modified

- `core/periodic.lua` — additive `obj.removeMatch(predicate)`: numeric `for` from `macroTorch.tableLen(elements)` down to 1, removes the first (newest) element satisfying the predicate, returns it or nil; exists for land-entry revocation
- `core/spell_trace_core.lua` — `LAND_INTENT_TTL = 2`; `landSources` / `auraApplySpellPatterns` registries; `SpellTrace:register` landSource support; `recordCastTable` seeds `intentTable[spell][mob]` LRUStack(32) pending intents and loses the RAWDIAG arm hook; `recordFailTable` appends `finalizeFail(spell, item[1])`; 6 new framework functions (`pairLandIntent`, `recordLandEvent`, `onLandEvent`, `processRawAuraApply`, `finalizeFail`, `onSelfDamageLine`); `maintainLandTables` + registration and `computeLandTable` deleted in full. CheckDodgeParryBlockResist (6 fail patterns), failTable push, consume/peek functions, landTableAny/AllMatch, setSpellTracing/immune helpers, DEBUFF_LAND_LAG all untouched
- `core/events.lua` — RAWDIAG_KEYWORDS table deleted; RAW_COMBATLOG branch is now the three-tier production handler (tier-1 channel whitelist, tier-2/3 precompiled-pattern loop with `if arg2` nil guard calling `processRawAuraApply` and breaking on first hit); `CHAT_MSG_SPELL_SELF_DAMAGE` gets `onSelfDamageLine(arg1, GetTime())` right after the unchanged `CheckDodgeParryBlockResist` call; all registrations and the two bridged cast branches byte-for-byte

## Decisions Made

- Task 1 checkpoint answer `option-a` recorded by the orchestrator — permanent deletion of the polling land machinery over a dead/disabled fallback (matches locked debug decision #5, keeps the phase shape)
- landSources registry default is `'self-hit'`; only `config.landSource == 'aura-apply'` precompiles an apply pattern — the two land sources have different ownership models by design
- Intent records are plain tables `{state, castAt, landAt}` mutated in place (state flips pending→landed/failed/expired, landAt stamped) — no allocation beyond the init push, cheap on the combat-log hot path

## Deviations from Plan

None - plan executed exactly as written. (Nil-brace guards on the intentTable/landTable access chains match the guard style the plan prescribed and the pre-existing consume/peek functions in the same file; no semantic deviation.)

## Issues Encountered

- `.planning/PROJECT.md` does not exist on disk (only referenced from STATE.md; config.json does not list it) — no impact on this plan
- The V6 spot audit initially flagged one line that turned out to be the comment text "decision #6" — re-run excluding comment lines; zero operator violations
- Build artifact SM_Extend.lua regenerates on every build.sh run and stays .gitignore'd — verified absent from both commits

## User Setup Required

None.

## Next Phase Readiness

Ready for 27-02-druid-cat-integration.

- Rip/Rake can now register with `landSource = 'aura-apply'` (pattern precompile + intent pairing already wired end-to-end)
- FB self-hit listener slot exists via `onLandEvent`
- Known transient (documented in plan recorded_choices): `consumeDruidBattleEvents` (Druid.lua 702-736) still runs and its pseudo-casts now seed intents that die at the 2s TTL — deleted in 27-02 before the phase reaches the live client

---

*Phase: 27-catatk-event-driven-land-tracing-refactor*
*Completed: 2026-08-29*