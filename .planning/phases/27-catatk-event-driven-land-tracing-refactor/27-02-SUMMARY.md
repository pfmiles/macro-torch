---
phase: 27-catatk-event-driven-land-tracing-refactor
plan: 02
subsystem: classes/druid+integration
tags: [lua50, wow112, druid, renewal, land-tracing]

# Dependency graph
requires:
  - phase: 27-catatk-event-driven-land-tracing-refactor plan 01
    provides: [macroTorch.recordLandEvent, macroTorch.onLandEvent, macroTorch.landSources registry with the 'self-hit' default, SpellTrace:register landSource support, auraApplySpellPatterns precompute, cast-intent pairing machinery]

provides:
  - classes/druid/Druid.lua: Pounce and Rip register with landSource = 'aura-apply'; Rake and Ferocious Bite keep the default 'self-hit' source (explicitness comments only)
  - classes/druid/Druid.lua: macroTorch.onLandEvent('Ferocious Bite', listener) — the FB hit event rewrites the Rake/Rip land entries with land = the FB event time, presence-gated, snapshot fields read-only, no GetComboPoints, no intent pairing
  - classes/hunter/Hunter.lua: Serpent Sting / Scorpid Sting register with landSource = 'aura-apply' (behavior-preserving migration under the new default)
  - Deletions (debug decision #5 druid half): consumeDruidBattleEvents + registerPeriodicTask('consumeDruidBattleEvents', 0.1s); ripLeft [DIAG rip-contradiction] one-shot dump; safeRip _diag stamps + [RAWDIAG] persist line; context.lastProcessedBiteEvent / _diag* fields no longer referenced anywhere in the druid layer

affects:
  - 27-03-selftest-verification-cleanup (Category Q in-game selftests: renewal listener presence Q-08, runtime absence of legacy machinery Q-09, aura-apply land evidence for rip/pounce/stings)
  - core/spell_trace_immune.lua (unchanged consumer; now fed exclusively by event-derived land events)

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 2420    # 9682 diff chars / 4 over classes/druid/Druid.lua + classes/druid/cat.lua + classes/hunter/Hunter.lua
  tasks: 3        # all three auto tasks executed in one sequential session
  commits: 5      # 3 source commits + docs(27-02) summary commit + docs(phase-27) tracking commit

# Tech tracking
tech-stack:
  added: []       # no packages installed (T-27-SC)
  patterns: [per-spell landSource config key ('self-hit' default, 'aura-apply' for DoT-only lands), onLandEvent renewal listener (event-time land rewrite, no intent pairing), diagnostics-free provenance (debug instrumentation removed in the same phase that ships the fix)]

key-files:
  created: []
  modified:
    - classes/druid/Druid.lua     # landSource configs + FB renewal listener; consumer + ripLeft DIAG block deleted
    - classes/druid/cat.lua       # safeRip debug-session diagnostics removed (judgment code untouched)
    - classes/hunter/Hunter.lua   # Serpent/Scorpid Sting landSource = 'aura-apply' (behavior-preserving)

key-decisions:
  - "Rip and Pounce land evidence is the aura-apply line (Rip has no initial direct damage; Pounce's opener bleed is aura-tracked) — landSource = 'aura-apply' with RAW intent pairing; Rake and Ferocious Bite keep the default 'self-hit' source from their own 'Your X hits/crits' lines (debug decision #3)"
  - "A Ferocious Bite land event immediately rewrites the Rake and Rip land entries with land = the FB event time; the GetComboPoints() > 0 condition is removed — the hit event itself proves the hit (debug decision #3)"
  - "The renewal listener only reads lastRipEquippedSavagery / lastRakeEquippedSavagery / context.lastRipAtCp inside the show lines and by ripLeft/rakeLeft — it never writes them, so the 16.2s/18s self-reported clock model continues from the new land time (snapshot invariant, debug decisions #3/#4)"
  - "Hunter Serpent/Scorpid Sting migrated to 'aura-apply': both stings are periodic DoTs with no 'Your X hits' direct-damage line, so the 27-01 default change would silently drop their land events and regress Hunter immune/definite-bleeding tracing (plan recorded_choice, behavior-preserving non-druid touch)"

patterns-established:
  - "Renewal-via-event: a bleed-carry-over land event (FB) rewrites the related bleeds' land entries with the event timestamp; renewal is a recordLandEvent rewrite, never a recordCastTable pseudo-cast — no intent is created or consumed"
  - "Land evidence by damage shape: skills with a self-damage hit/crit line use 'self-hit'; aura-only skills (no initial direct damage, pure bleed/sting applies) use 'aura-apply' with cast-intent pairing"
  - "Snapshot non-modification: event-driven renewal gates on isRakePresent/isRipPresent (hasBuff AND clock authority) and treats the Savagery/CP snapshot fields as read-only takeover bridges"

requirements-completed: []  # copied verbatim from plan frontmatter (phase 27 has no requirement IDs)

# Coverage metadata (#1602) — one entry per shipped deliverable.
coverage:
  - id: D1
    description: "Druid.lua landSource registrations — Pounce/Rip = 'aura-apply' (exactly 2 assignments), Rake/Ferocious Bite keep the 'self-hit' default with explicitness comments"
    verification: []
    human_judgment: true
    rationale: "Static presence is proven (grep counts, bbcheck), but whether the aura-apply land evidence actually lands Rip/Pounce in-game is behavioral truth deferred to 27-03 Category Q selftests."
  - id: D2
    description: "Ferocious Bite renewal listener — onLandEvent('Ferocious Bite') rewrites Rake/Rip land entries with land = FB event time, presence-gated, rake check before rip check, zero GetComboPoints/recordCastTable/_diag, snapshot fields read-only"
    verification: []
    human_judgment: true
    rationale: "Renewal timing and the removal of the CP condition are in-game behavioral semantics (bite rhythm vs the 16.2s clock) deferred to 27-03 Category Q selftests (Q-08/Q-09); static gates prove structure only."
  - id: D3
    description: "Druid-side legacy machinery + diagnostics deleted — consumeDruidBattleEvents + 0.1s periodic registration gone; ripLeft [DIAG rip-contradiction] dump removed with computation surviving byte-for-byte; isRipPresent untouched byte-for-byte; safeRip keeps the 'Rip!!! At cp:' show line, player.rip, lastRipEquippedSavagery and lastRipAtCp assignments with the _diag stamps and [RAWDIAG] persist line removed"
    verification:
      - kind: other
        ref: "git grep '_diagRipContradiction|_diagLastSafeRipAt|_diagLastRenewingRipAt|[DIAG|[RAWDIAG]' -- classes/druid/Druid.lua classes/druid/cat.lua (empty)"
        status: pass
      - kind: other
        ref: "git grep 'consumeDruidBattleEvents' -- classes/druid/Druid.lua (empty); diff of Druid.lua = 30 pure deletions inside the diagnostic block; cat.lua diff = 11 pure deletions (3 debug additions only)"
        status: pass
      - kind: other
        ref: "isRipPresent function text identical to git show HEAD (byte-for-byte diff); safeRip region keeps Rip!!! show line + lastRipEquippedSavagery + lastRipAtCp (grep + visual diff)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Hunter.lua Serpent/Scorpid Sting landSource = 'aura-apply' migration (single hunk limited to the two config tables + comments; no other file hunk)"
    verification: []
    human_judgment: true
    rationale: "Whether sting land events keep feeding hunter immune/definite-bleeding tracing through the RAW pairing path is in-game behavioral truth deferred to 27-03 Category Q selftests."
  - id: D5
    description: "Static verification gates pass on all three files — bbcheck BALANCED, build.sh exit 0 with listener + register sites present in SM_Extend.lua, git diff --check clean, mission-final greps empty (consumeDruidBattleEvents / _diag / [DIAG] / [RAWDIAG] / GetComboPoints-in-listener), entity/Unit.lua untouched"
    verification:
      - kind: other
        ref: "node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/Druid.lua classes/druid/cat.lua classes/hunter/Hunter.lua (all BALANCED)"
        status: pass
      - kind: other
        ref: "bash build.sh (exit 0); SM_Extend.lua contains onLandEvent (x2), Serpent Sting register site at 7921, Scorpid Sting at 7927, pattern-construction line 2604"
        status: pass
      - kind: other
        ref: "git diff --check HEAD~3 HEAD (clean); git diff --stat HEAD~3 HEAD limited to the 3 class files; entity/Unit.lua absent from stat, hasBuff count unchanged"
        status: pass
    human_judgment: false

# Metrics
duration: 2min
completed: 2026-08-29
status: complete
---

# Phase 27 Plan 02: Druid Cat Integration Summary

**Druid cat skills integrated with the event-driven land framework — Pounce/Rip land via aura-apply pairing, a Ferocious Bite land event rewrites the Rake/Rip clocks, the polling bite-renewal consumer and every debug-session diagnostic are deleted, and the two Hunter DoT stings are migrated to aura-apply so their immune tracing survives the new self-hit default**

## Performance

- **Duration:** ~2 min (single sequential session, 3 tasks)
- **Started:** 2026-08-28T17:21:53Z
- **Completed:** 2026-08-28T17:24:13Z
- **Tasks:** 3 (all executed; all acceptance criteria PASS)
- **Files modified:** 3 (classes/druid/Druid.lua, classes/druid/cat.lua, classes/hunter/Hunter.lua)

## Accomplishments

- Pounce and Rip now register with `landSource = 'aura-apply'`; their land events pair the RAW apply line with the cast intent seeded by `recordCastTable` and land at the apply event time (debug decision #3). Rake and Ferocious Bite keep the default `'self-hit'` source from their own `Your X hits/crits` lines, now documented by explicitness comments.
- The 0.1s `consumeDruidBattleEvents` periodic consumer is replaced by `macroTorch.onLandEvent('Ferocious Bite', listener)`: a bite hit instantly rewrites the Rake and Rip land entries with land = the FB event time, keeping the same 'Renewing rake.../rip... left:' message shape, with the rake check before the rip check (old order preserved).
- The renewal listener honors the full decision-#3/#4 snapshot invariant: no `GetComboPoints()`, no `recordCastTable` pseudo-casts, no `lastProcessedBiteEvent` bookkeeping, no `_diag` stamps — `lastRipEquippedSavagery` / `lastRakeEquippedSavagery` / `context.lastRipAtCp` are only read inside `tostring(...)` and by the untouched `ripLeft`/`rakeLeft` computation, so the 16.2s/18s self-reported clocks restart from the new land time.
- The druid layer now contains zero `[DIAG]`/`[RAWDIAG]` code and zero `_diag*` fields: the `ripLeft` contradiction dump and the `safeRip` _diag stamps + RAWDIAG persist line are deleted while `ripLeft` computation, `isRipPresent` (byte-for-byte), and the `safeRip` decision lines (`'Rip!!! At cp:'`, `player.rip('ready')`, `lastRipEquippedSavagery`, `lastRipAtCp`) survive unchanged — the druid half of debug decision #5.
- Hunter's Serpent Sting and Scorpid Sting migrated to `landSource = 'aura-apply'`: both are periodic DoTs with no direct-damage line, so the plan 27-01 default change would silently drop their land events and regress hunter immune/definite-bleeding tracing (plan's recorded choice, behavior-preserving).

## Verification Log (acceptance criteria + plan verification)

| Gate | Result |
|------|--------|
| Task 1 A1 — exactly 2 `landSource = 'aura-apply'` in Pounce/Rip configs | PASS (lines 684 Pounce, 695 Rip) |
| Task 1 A2 — no `consumeDruidBattleEvents` in Druid.lua | PASS (definition + periodic registration deleted together) |
| Task 1 A3 — one `onLandEvent('Ferocious Bite'` | PASS (line 713) |
| Task 1 A4 — listener block free of GetComboPoints/recordCastTable/lastProcessedBiteEvent/_diag | PASS |
| Task 1 A5 — exactly 2 recordLandEvent('Rip'/'Rake') calls; zero snapshot-field assignments in listener | PASS (719 rake, 725 rip; reads inside tostring only) |
| Task 1 A6 — Rake/FB carry no landSource key (default self-hit) | PASS |
| Task 1 A7 — bbcheck BALANCED, diff --check clean, build.sh exit 0, artifact contains listener + 2 aura-apply register sites | PASS |
| Task 2 A1 — no _diag*/[DIAG]/[RAWDIAG] in Druid.lua + cat.lua | PASS |
| Task 2 A2 — Druid.lua diff = only deletions inside the diagnostic block; computation untouched | PASS (30 pure deletions) |
| Task 2 A3 — 'Rip!!! At cp:' present; lastRipEquippedSavagery/lastRipAtCp assignments intact | PASS (line 415) |
| Task 2 A4 — isRipPresent byte-for-byte identical to pre-phase | PASS (diff clean) |
| Task 2 A5 — bbcheck BALANCED both files, build.sh exit 0 | PASS |
| Task 2 A6 — diff stat limited to Druid.lua + cat.lua | PASS (41 deletions) |
| Task 3 A1 — exactly 2 `landSource = 'aura-apply'` in Hunter.lua | PASS (lines 157, 163) |
| Task 3 A2 — Hunter.lua diff limited to the two config tables + comments | PASS (single hunk, 6 insertions) |
| Task 3 A3 — bbcheck BALANCED, build exit 0, artifact contains both sting register sites + pattern construction | PASS (7921/7927, line 2604) |
| Task 3 A4 — git diff --check clean | PASS |
| Plan V1 — bbcheck BALANCED on all 3 files | PASS |
| Plan V2 — build.sh passes; onLandEvent + Serpent Sting wiring in artifact; artifact stays uncommitted | PASS |
| Plan V3 — git diff --check clean over the plan's commits | PASS |
| Plan V4 — mission-final greps: consumeDruidBattleEvents/_diag*/[DIAG]/[RAWDIAG] absent; zero GetComboPoints in listener (only pre-existing line 320 `comboPoints` accessor elsewhere) | PASS |
| Plan V5 — entity/Unit.lua untouched (absent from diff stat; hasBuff count unchanged at 2) | PASS |
| Plan V6 — behavioral layer (renewal timing, aura-apply land evidence in-game) | Deferred by design to 27-03 Category Q selftests |

## Task Commits

Each task committed atomically (English conventional messages, source files only):

1. **Task 1: landSource registrations + FB-land-event renewal listener** — `0ac3bf7` (feat) — classes/druid/Druid.lua
2. **Task 2: Delete druid-side legacy polling consumer branch + all debug-session diagnostics** — `b3bd8c6` (fix) — classes/druid/Druid.lua + classes/druid/cat.lua
3. **Task 3: Hunter Sting landSource migration** — `31d69d1` (feat) — classes/hunter/Hunter.lua

## Files Created/Modified

- `classes/druid/Druid.lua` — Pounce/Rip register configs gain `landSource = 'aura-apply'`; Rake/FB get one-line self-hit-default comments; `consumeDruidBattleEvents` + its 0.1s periodic registration replaced by the `onLandEvent('Ferocious Bite', ...)` renewal listener; `ripLeft` [DIAG rip-contradiction] dump deleted so the function ends at `return clickContext.ripLeft` right after the computation; `isRipPresent` / `isRakePresent` / `rakeLeft` untouched.
- `classes/druid/cat.lua` — `safeRip` keeps the 'Rip!!! At cp:' show line, `player.rip('ready')`, `lastRipEquippedSavagery` and `lastRipAtCp` assignments byte-for-byte; the `_diagLastSafeRipAt` stamp, `_diagRipContradictionActive` re-arm, and the [RAWDIAG] persist log block (with comment) removed.
- `classes/hunter/Hunter.lua` — Serpent Sting / Scorpid Sting register configs gain `landSource = 'aura-apply'` each preceded by a one-line English comment; nothing else in the file changed.

## Decisions Made

- Rake stays `'self-hit'` (unchanged register call besides the explicitness comment): Rake always produces 'Your Rake hits/crits' direct-damage lines, so no RAW pairing is needed (plan recorded choice).
- Pounce joins Rip on `'aura-apply'` even though it carries initial direct damage — its land evidence is the aura-apply line per locked debug decision #3; the register config carries only the key change.
- The FB inline comment `-- FB has consumeLandEvent but NO immune tracing in original code` was kept: it references `consumeLandEvent` (still live in core, consumed by spell_trace_immune), not the deleted periodic task — no dangling reference.

## Deviations from Plan

None - plan executed exactly as written. All task boundaries, deletion ranges, listener structure/invariants, and commit contents match the plan verbatim; every acceptance criterion and plan-level verification gate passed on the first run (zero fix retries).

## Issues Encountered

- `.planning/PROJECT.md` does not exist on disk (only referenced from STATE.md; config.json does not list it) — no impact on this plan.
- The awk/sed block extraction for Task 1 criteria 4/5 needed a second pass because the listener's opener line contains parentheses; resolved by extracting the exact line range 713-727 — checks then passed cleanly.
- `auraApplySpellPatterns['Pounce'/'Rip']` literals do not appear in SM_Extend.lua because the find patterns are built at runtime by concatenation inside `SpellTrace:register` (line 2604 of the artifact) — verified via the register call sites instead; expected per the 27-01 framework design.

## User Setup Required

None.

## Next Phase Readiness

Ready for 27-03-selftest-verification-cleanup.

- Category Q-08 (renewal listener presence) and Q-09 (runtime absence of legacy machinery — assert `maintainLandTables`, `computeLandTable`, `consumeDruidBattleEvents` are nil) can now be written against live behavior; the druid half of decision #5 is fully landed.
- In-game truth for aura-apply land evidence (Rip/Pounce/Serpent Sting/Scorpid Sting) and the FB-driven renewal timing is the 27-03 selftest target, per the phase's deferred behavioral layer (plan V6).

---

*Phase: 27-catatk-event-driven-land-tracing-refactor*
*Completed: 2026-08-29*