---
phase: 29-landing
reviewed: 2026-09-11T17:50:42Z
depth: deep
files_reviewed: 5
files_reviewed_list:
  - core/spell_trace_core.lua
  - classes/druid/selftest.lua
  - interface_debug.lua
  - classes/druid/cat.lua
  - classes/druid/Druid.lua
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 29: Focused Re-Review (DELTA 1 announcement colors + DELTA 2 bite silent-landing fix chain)

**Reviewed:** 2026-09-11T17:48:34Z
**Depth:** deep
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Focused re-review of two deltas on top of the Phase-29/30 codebase. Context files read for cross-module tracing: `core/events.lua` (event dispatch, not in scope list), `classes/hunter/Hunter.lua` (sting registrations), `.planning/phases/29-landing/29-04-SUMMARY.md` (D-14 color contract history).

**DELTA 1 (57cfba8 + 50dfcbe) verdict — structurally clean, one hue-contract violation.** Both new arms use the exact `{r, g, b, id}` shape of the existing blue/green arms; the values are 0..1 floats that `AddMessage` accepts unchanged, so rendering is crash-safe. No behavioral leakage: `macroTorch.show` is pure-render and no decision logic reads color labels. Lua 5.0 compliant (plain literals/elseif). The `macroTorch.log` @param list was updated consistently. Two residuals: the violet RGB is not hue-dominant for its label (violates the file's own D-14 color-label contract, WR-01), and the T-02 hue test was not extended to the new arms (IN-01).

**DELTA 2 (95cbb6e + 881594c) verdict — the M1 fix is real and the dispatch asymmetry it addresses is closed, but the discriminator used by 881594c is overbroad.** The inference fallback now routes through `recordLandEvent`, restoring listener dispatch parity with both evidence channels — verified against all three call paths. Q-17/Q-18/Q-19 fixtures are well-formed under the CR-01 discipline (snapshot/install/pcall/restore before assert) and reproduce their named scenarios faithfully. However, `isAnchorCoveredPair` uses numeric equality `lastLand == lastCast` as the anchor signature, and that signature is also produced by real-evidence flows — most importantly by the stale-coverage rescue itself (which restamps cast and land in the same frame, `events.lua:116` passes `GetTime()` and `recordCastTable` calls `GetTime()` again). A bridge-lost follow-up cast whose line arrives past the window is then silently dropped as an "inferred duplicate" even though it is first evidence — the same landing-silent symptom family this chain was fixing, via a narrower route (WR-02). No locked Phase-29 semantics (D-02 dedup, D-03 inference fallback, D-04 fail veto, D-06 fail-wins) regress: the fail veto still precedes the inference anchor in time by construction (an in-window fail always exists in `failTable` before `blip > ttl` fires), the D-02 predicate is evaluated identically, and fail-wins reachability is unchanged.

## Mandatory Generalization Question

**Does the anchor-equality guard + stale-coverage machinery protect ALL traced spells from the double-booking / phantom-cast failure?**

Path census (verified source-level):

| Spell | Self-hit rescue path (`onSelfDamageLine`) | Inference (`computeLandTable`, 0.1s poll) | Aura-apply channel (`processRawAuraApply`) | Land listener |
|---|---|---|---|---|
| Ferocious Bite | Yes — its only real-evidence channel | Yes | No (no debuff pattern; `immune=false`) | Yes (Rake/Rip renewal) |
| Rake | Yes (dual channel) | Yes | Yes | No (but is a renewal *target*) |
| Rip | No self-hit line exists in game | Yes | Yes — its natural channel | No (renewal target) |
| Pounce | Yes (dual channel) | Yes | Yes | No |
| Serpent/Scorpid Sting (intentTtl=2) | No self-hit line exists | Yes | Yes | No |
| Claw/Shred | Not traced (`land=false`-like: never `setSpellTracing`d) | No | No | No |

Audit results:

1. **Self-hit spells (FB, Rake, Pounce): protected by the guard, with one over-trigger hole.** The M1 mode (inference anchor, then late line) is correctly dropped. But the guard discriminates `lastLand == lastCast`, and that signature has three producers: (a) the inference anchor, (b) the stale-coverage rescue itself (cast restamped via `recordCastTable`'s `GetTime()` and land at the caller's `GetTime()` — identical frame clock, so equal), (c) a same-frame bridge-stamp + hit-line coincidence. On producers (b)/(c) a subsequent bridge-lost cast whose line delays past the window is silently dropped — WR-02 below.
2. **Aura-apply-only spells (Rip, stings, and the apply channel of Rake/Pounce): protected structurally, M1 cannot reach them.** A late apply after an inferred anchor fails intent pairing (`pairLandIntent` purge: `now - castAt > ttl` → expired) → returns nil → no write, no announce. An apply inside the window pairs the still-pending intent, but `recordLandEvent`'s D-02 dedup drops the write (`lastLand` = anchor `>= lastCast`) and the coverage-gated announce stays silent. No double ledger, no phantom cast. The guard is never even consulted, so spells without self-hit lines are immune to both the M1 failure and the WR-02 over-trigger.
3. **Listener-dispatch asymmetry between rescue and inference paths: closed, for real evidence.** Both the self-hit path (including the rescue restamp leg) and the inference path now dispatch through `recordLandEvent`, and both announce before dispatching (green before listeners; blue `(inferred)` before listeners). The apply path is already symmetric. The only skip is the guard-drop path itself, which is correct when the anchor genuinely came from inference (listeners already ran at anchor-write) but lossy when the drop is a WR-02 false positive — that drop is then the only remaining dispatch asymmetry, and it is a defect-adjacent one, not a deliberate design.
4. **Remote-inference anchors (stings, intentTtl=2): unaffected.** Their inference threshold is 2s; a 1s-late apply lands as real evidence (`landAt > castAt`, Q-16 pins this), so no equality pair forms from the normal channel.

**Verdict:** No spell/landing-source combination fully bypasses the protection: self-hit spells are guarded (with the WR-02 over-trigger hole), apply-only spells are protected by channel design. The single residual failure mode is a false-positive drop of a bridge-lost cast's first evidence when the previous coverage pair carries the equality signature for a reason other than inference.

## Warnings

### WR-01: 'violet' arm RGB is red-dominant — violates the D-14 hue-matching contract

**File:** `interface_debug.lua:103-104`
**Issue:** The D-14 contract comment on the same function (lines 87-89) requires every named arm to be a *hue-dominant literal whose label matches the rendered hue* — the exact discipline that phase 29-04 introduced to fix the OFFICER-channel blue/green inversion (`29-04-SUMMARY.md` G-29-3). `{ r = 0.86, g = 0.44, b = 0.58 }` is red-dominant (r ≈ 0.86 > b ≈ 0.58): it renders pink/rose, not violet. A T-02-style hue assertion for the violet arm (`b >= r and b >= g`, the same form T-02 uses for the other arms at `selftest.lua:2047-2050`) would fail against these values. The user asked for a violet announcement and will see a pink line — a miniature repeat of the G-29-3 inversion class this contract exists to prevent. (Coffee `{0.82, 0.71, 0.55}` IS red-dominant and matches its brown label; the violet arm is the only violation.)
**Fix:**
```lua
elseif 'violet' == col then
    c = { r = 0.55, g = 0.27, b = 0.93, id = 'custom_violet' }
```
Any b-dominant literal works (e.g. the classic `{ r = 0.54, g = 0.17, b = 0.89 }`). Then extend T-02 to assert this arm's blue dominance so a future edit cannot silently invert it again.

### WR-02: anchor-equality discriminator drops legitimate first evidence for a bridge-lost follow-up cast

**File:** `core/spell_trace_core.lua:350-360` (guard) and `core/spell_trace_core.lua:643-653` (rescue call site)
**Issue:** The M1 guard treats `lastLand == lastCast` as the inferred-anchor signature, but the stale-coverage rescue produces the identical signature with real evidence. `events.lua:116` invokes `onSelfDamageLine(arg1, GetTime())`; the rescue leg calls `recordCastTable(spell)`, which stamps `push(GetTime())` (`spell_trace_core.lua:120`) — same frame clock, so the rescued pair collapses to `cast == land`. Q-17's own assertion `fbCastTop >= fbLandTop` (`selftest.lua:1372-1373`) implicitly ratifies the equality-signature outcome and cannot tell the producers apart. The comment at lines 336-346 acknowledges the rescue "restamps the same way" and then treats *every* equality pair as an inferred anchor anyway.

Concrete failure scenario: FB cast A racy (bridge lost the record race) → rescue restamps cast=land=T (equality pair, real evidence). FB cast B cast ~4s later, its bridge record lost again (same race, already demonstrated in the field session this chain fixes); B's hit line arrives at T+4.2s. `isStaleCoveredPair` → true (4.2 > 0.9); `isAnchorCoveredPair` → true (T == T) → the line is dropped silently: no green landed line, no land entry, no listener dispatch for B. The FB renewal never runs → Rake/Rip clocks count down from stale anchors → premature Rip re-cast risk. This is the same bite-landing-silent symptom family the chain was created to eliminate, re-opened through a narrower route. Severity is mitigated by the compounding preconditions (a second consecutive bridge race AND a line delay beyond the ttl of the previous stamp), but the discriminator cannot in principle distinguish the producers, and Q-17 pins the confusing signature as acceptable.
**Fix:** mark inference anchors explicitly instead of inferring them from numeric equality. In `computeLandTable` (before `recordLandEvent(spell, lastCast)` at line 503), record a producer marker, e.g.:
```lua
if not macroTorch.loginContext.inferredAnchors then
    macroTorch.loginContext.inferredAnchors = {}
end
if not macroTorch.loginContext.inferredAnchors[spell] then
    macroTorch.loginContext.inferredAnchors[spell] = {}
end
macroTorch.loginContext.inferredAnchors[spell][macroTorch.target.name] = lastCast
```
and change `isAnchorCoveredPair` to consult the marker (`inferredAnchors[spell][mob] == lastLand`) instead of testing `lastLand == lastCast`. Rescue-stamped and same-frame coincidental equality pairs then correctly take the original rescue path, and a Q-20 test can drive the two-rescue chain: rescue cast A → bridge-lost cast B with a late line → assert B is rescued (announced green, land recorded), not dropped.

## Info

### IN-01: T-02 hue test does not cover the two new arms

**File:** `classes/druid/selftest.lua:2009-2051`
**Issue:** T-02's comment claims "a hue inverted in any arm turns this test red/yellow", but it only asserts the default/red/yellow/blue/green arms. The two arms added in 57cfba8 have zero automated hue coverage — WR-01 ships green under the current suite. Extend T-02 with `macroTorch.show('probe', 'coffee')` / `'violet'` calls plus hue-dominance asserts (r-dominant for coffee, b-dominant for violet). This also converts WR-01 from a latent to a caught defect.

### IN-02: Q-19 seeds the anchor by direct push instead of through the inference

**File:** `classes/druid/selftest.lua:1460-1479`
**Issue:** The M1 fixture pushes `anchor` straight into the land table rather than generating it via `computeLandTable`, so the end-to-end chain (silent cast → inference fires → anchor written → late self-hit dropped) is only covered compositionally by Q-18 (inference + dispatch) and Q-19 (guard response). A single end-to-end test would pin the full interaction and would have surfaced the WR-02 ambiguity class earlier. Consider a Q-20 that runs a real `computeLandTable('Ferocious Bite')` on a stale silent cast and then feeds the late line, asserting zero captures and an unchanged cast stamp.

### IN-03: isAnchorCoveredPair comment misdescribes the clocks

**File:** `core/spell_trace_core.lua:336-338`
**Issue:** The comment states "the cast-record bridge and the combat-log line read different frame clocks". Both the bridge (`recordCastTable` via `events.lua:139`) and the dispatcher (`events.lua:116`, `events.lua:175`) read the same `GetTime()` frame clock — the equality collapse is a same-frame artifact, not a cross-clock one. Reword the comment to describe the real producer set (inference anchor, rescue restamp, same-frame bridge/line coincidence) so future maintainers see why the WR-02 marker fix matters.

### IN-04: Q-17's `fbCastTop >= fbLandTop` assertion silently accepts the equality signature

**File:** `classes/druid/selftest.lua:1372-1373`
**Issue:** The graded `>=` is correct for a fixture that cannot control `GetTime()` ordering, but it means the test passes equally for `cast > land` (clean real-evidence pair) and `cast == land` (anchor-equality signature) — the exact state WR-02 depends on. After the marker fix (WR-02), tighten this assertion or add a companion assert that the rescue did not create an inference-marker entry, so the confusing signature stops being an accepted fixture outcome.