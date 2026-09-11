---
phase: 29-landing
fixed_at: 2026-09-11T18:07:34Z
review_path: .planning/phases/29-landing/29-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 29: Code Review Fix Report (focused re-review — DELTA 1 announcement colors + DELTA 2 bite silent-landing chain)

**Fixed at:** 2026-09-11T18:07:34Z
**Source review:** `.planning/phases/29-landing/29-REVIEW.md` (focused re-review, 2026-09-11, status `issues_found` — 2 warnings, 4 info)
**Iteration:** 1 (second review cycle for this phase; the first cycle's report is preserved in git history at commit d7caee0)

**Summary:**
- Findings in scope: 2 (WR-01, WR-02; fix_scope=critical_warning — Info items out of scope)
- Fixed: 2
- Skipped: 0 in scope (IN-01 and IN-04 explicitly skipped per user adjudication, documented below)

**Verdict-first pass (user mandate):** Both in-scope findings were adjudicated REAL by
the orchestrator's verification with mandatory fix shapes. WR-01 is an honest rename
only — the pink rendering RGB `{r = 0.86, g = 0.44, b = 0.58}` is FINAL and byte-identical
(a user ruling forbids any pixel change). WR-02 replaces the numeric-equality
discriminator with an explicit origin marker. The fold-ins IN-02 (Q-19 marker seeding)
and IN-03 (comment rewrites) were delivered inside the WR-02 commit as directed; no
separate fixes. The `coffee` arm and the D-02/D-03/D-04/D-06 locked semantics were left
untouched (the guard only gains an AND-clause).

## Fixed Issues

### WR-01: 'violet' arm RGB is red-dominant — violates the D-14 hue-matching contract

**Verdict:** real. `{r = 0.86, g = 0.44, b = 0.58}` renders pink/rose, so the label
'violet' lied about the rendered hue.

**Files modified:** `interface_debug.lua`, `classes/druid/Druid.lua`
**Commit:** d87685a
**Applied fix:** Honest rename of the color KEY from 'violet' to 'pink' at the three
mandated sites, with zero RGB change and zero visual change (user ruling: the pink
rendering is final):
1. `interface_debug.lua:103-104` — arm label `'pink' == col` and id `'custom_pink'` (RGB literal untouched).
2. `interface_debug.lua:112` — the `@param color` comment list now ends `"coffee", "pink"`.
3. `classes/druid/Druid.lua:1516` — the safeFF `macroTorch.show(...)` call site now passes `'pink'`.

The 'coffee' arm is correct as-is and was not touched. A repo-wide grep confirms no
'violet' reference remains outside the untracked build artifact (SM_EXTEND.lua, not
modified), and no pre-existing 'pink' key collision.

### WR-02: anchor-equality discriminator drops legitimate first evidence for a bridge-lost follow-up cast

**Verdict:** real. `lastLand == lastCast` is produced by three flows (inference anchor,
stale-coverage rescue restamp, same-frame bridge/line coincidence), so numeric equality
cannot tell an inferred anchor from real same-frame rescue evidence. A repeated F1 race
(consecutive bridge-losses, spacing > ttl) made the rescue pair of cast A silently drop
the first evidence of cast B — no land, no announcement, no listener dispatch, no
inference for B — the same silent-bite symptom family reopened through a narrower route.

**Files modified:** `core/spell_trace_core.lua`, `classes/druid/selftest.lua`
**Commit:** a30f5fb
**Applied fix:** Explicit origin marker instead of value-equality inference:
1. New state `macroTorch.loginContext.inferredAnchors` — per-spell per-mob
   `LRUStack` (maxSize 100), lazy-initialized with the same shape as
   castTable/landTable; it holds only landTimes written by the inference path and is
   cleared with the context on entering world (no new teardown needed).
2. `computeLandTable` marks the anchor immediately AFTER the existing
   `recordLandEvent(spell, lastCast)` call (frame is single-threaded, and the pre-call
   `lastLand >= lastCast` guard ensures the write happens). Hunter-sting paths
   (intentTtl=2) flow through the same function, so the marker covers them.
   `recordLandEventRenewal` pushes do NOT mark — plain renewals — and a renewal push
   breaks the equality pair anyway, leaving the guard inert there.
3. `isAnchorCoveredPair(spell)` redefined: still requires `lastLand == lastCast`, AND
   `lastLand` must be present in the spell's `inferredAnchors` stack (existing
   `LRUStack.anyMatch`). Unmarked rescue pairs `[t, t]` no longer trip the guard, so the
   original rescue path (restamp + green announcement + land record + listener dispatch)
   runs for them — restoring correct handling of repeated F1 races. The peek-helper
   guards already establish `loginContext` and the current target, so the marker read is
   nil-safe.
4. Comment blocks rewritten (IN-03 folded in): the guard comment at
   `spell_trace_core.lua:336-360` now describes the three producers and the
   marker-based discriminator (the old "different frame clocks" wording was wrong —
   both sides read the same `GetTime()` clock, making the equality collapse a same-frame
   artifact), and the rescue call-site comment at the stale-coverage branch now states
   that unmarked equality pairs are real evidence and take the rescue path.
5. D-02/D-03/D-04/D-06 Phase-29 locked semantics preserved: the guard only gains the
   AND-clause; every early return before `recordLandEvent` in `computeLandTable` is
   untouched; `isCastCovered`, `recordLandEvent`, and the rescue path are unchanged for
   every non-anchor flow.
6. Folded IN-02: `classes/druid/selftest.lua` Q-19 now seeds
   `fakeLoginContext.inferredAnchors` alongside its bare equality pair (same minimal
   planting style as the cast/land seeds); the planted comment documents that full
   computeLandTable-path fidelity (silent cast → polled inference → marked anchor →
   late line) remains a known fixture limitation, covered compositionally by Q-18
   (inference + dispatch) plus Q-19 (guard response).

**Status note:** this was verified statically only — see the battery below; the
behavior change is a logic-level discriminator fix and needs in-game re-verification of
the two-rescue chain before the phase closes (`fixed: requires human verification`).

## Out-of-scope findings (Info tier — explicitly skipped per user adjudication)

### IN-01: T-02 hue test does not cover the two new arms

**File:** `classes/druid/selftest.lua:2020-2062` (in the current tree)
**Reason:** Out of scope (fix_scope=critical_warning) and an explicit adjudication
skip: test-coverage augmentation, not a defect. The WR-01 rename keeps the D-14
label-hue contract without any RGB edit, so no T-02 change accompanies it. Left for a
future test-suite pass.

### IN-04: Q-17's `fbCastTop >= fbLandTop` assertion silently accepts the equality signature

**File:** `classes/druid/selftest.lua:1372-1373`
**Reason:** Explicit adjudication skip — NOT a defect: the rescue's same-frame restamp
legitimately produces cast == land, so `>=` is fixture-accurate for Q-17's scenario.
The equality-signature ambiguity it documented is the very thing the WR-02 marker
redesign eliminates; no standalone edit.

## Verification environment and static battery

Where verification ran: inside the isolated review-fix worktree
(`.claude/worktrees/rf-29-375913-*`, branch `gsd-reviewfix/29-375913`) — gates were run
on the worktree's copy, not the main checkout; the main checkout was left untouched
until the cleanup fast-forward, so the numbers below are reproducible from the
committed tree after the fast-forward. The worktree carries no toolchain
(`node_modules`, Lua), so no interpreter-backed checks were possible.

- bbcheck: NOT available in this repo or on PATH at fix time (the first cycle's report
  referenced `bbcheck.js`; it is not present now) — this gate was skipped and is noted
  plainly rather than approximated.
- CRLF scan: 0 CR characters across all four modified files (`core/spell_trace_core.lua`,
  `classes/druid/selftest.lua`, `interface_debug.lua`, `classes/druid/Druid.lua`) — LF
  line endings held per the repo `.gitattributes` convention.
- Lua 5.0 token gate on the delta (WoW 1.12 client): 0 hits for the `#` length
  operator, `goto`, or `::` labels in any added line.
- Bracket/terminator balance on the added delta lines alone: `[`18/18, `(`6/6, `{`4/4 —
  balanced. (A whole-file naive scan flags pre-existing Lua find-pattern brackets inside
  string literals; those imbalances predate this run and are unchanged by it.)
- Selftest registry consistency: Q-17, Q-18, Q-19, and T-02 are still registered with
  their exact names and in their original categories; Category T untouched (2 tests,
  T-02 assertion set unchanged per the IN-01 skip). Q-17's assertions still match
  behavior (its stale pair is non-equal, so the new AND-clause leaves it on the rescue
  path; `>=` stays fixture-accurate per IN-04). Q-18 unaffected (the marker push emits
  no announcement and follows `recordLandEvent`). Q-19 assertions are unchanged and now
  reproduce the marker-guarded drop via the planted mark.
- Build artifact: SM_EXTEND.lua NOT touched (generated on the user's machine).
- In-game tests: cannot run on this machine — static verification only, stated plainly.

---

_Fixed: 2026-09-11T18:07:34Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_