---
phase: 29-landing
fixed_at: 2026-09-10T08:10:00Z
review_path: .planning/phases/29-landing/29-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 29: Code Review Fix Report

**Fixed at:** 2026-09-10T08:10:00Z
**Source review:** `.planning/phases/29-landing/29-REVIEW.md` (2nd-pass superset, status `issues_found`)
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (WR-01..WR-05; critical = 0; Info items out of scope per fix_scope=critical_warning)
- Fixed: 5
- Skipped: 0

**Verdict-first pass (user mandate):** Every in-scope finding was independently
re-verified against the current on-disk code before editing. Line anchors were
re-confirmed (all still current), the defect scenarios were re-derived from the
live code paths, and all five were adjudicated REAL — no false positives, no
design-accepted skips. Each real fix was kept to the smallest localized change;
no locked design decision (D-01..D-18) was altered, no selftest fixture was
touched, and the announce-before-recordEvent causal-order convention from
29-CONTEXT specific notes is preserved.

**Verification environment:** all edits and static gates ran inside the isolated
review-fix worktree (branch `gsd-reviewfix/29-*`, path
`.claude/worktrees/rf-29-*` under the repo root). Per-finding batteries run on
every changed file before its commit: `bbcheck.js` (BALANCED), `git diff
--check` (clean), Lua 5.0 token gate `#`/`goto `/`::` (0), CRLF scan (0),
diff-new-comment CJK gate (0), diff-new-comment English-token gate (0). Numbers
are reproducible from the committed tree (the source files are unchanged in the
main checkout, and the worktree was removed after the fast-forward).
No Lua interpreter is installed on this machine, so syntax verification relied
on the project's own bbcheck + grep battery rather than `luac`.

## Fixed Issues

### WR-01: Self-hit path announces green even when the cast-dimension dedup drops the land

**Verdict:** real.

**Files modified:** `core/spell_trace_core.lua`
**Commit:** 2c4b869
**Applied fix:** Extracted the D-02 coverage predicate into a new
`macroTorch.isCastCovered(spell)` helper (single source of truth for
`lastLand >= lastCast`). `recordLandEvent` now uses the helper for its dedup;
`onSelfDamageLine` and `processRawAuraApply` gate the green announcement on
`not isCastCovered(...)`. The announce still precedes `recordLandEvent`, so the
locked causal print order (green line before listener output, e.g. the
Ferocious Bite "Renewing..." lines) is unchanged — only the duplicate green
line for a dropped write is suppressed. The apply channel was gated too for the
same theoretical gap noted in the review (WR-01 symmetry).

### WR-02: Stale-cast inference has no epoch guard — cross-combat / retarget pollution

**Verdict:** real.

**Files modified:** `core/spell_trace_core.lua`
**Commit:** 57fad85
**Applied fix:** Added an upper bound to the inference window inside
`computeLandTable`, right after the `blip <= ttl` return: a cast whose silence
window has grown beyond `ttl * 6` is abandoned (return) instead of being
re-anchored as a ghost land. Tracked the concrete scenario from the review:
`maintainLandTables` is `inCombat`-gated (the tick freezes out of combat),
`onCombatExit` only clears `macroTorch.context` (combat_context.lua:24), and
`computeLandTable` previously bounded `blip` only from below — so a same-named
target in the next combat replayed an ancient `lastCast`. In-combat inference
fires at `blip <= ttl + one 0.1s tick`, so `ttl * 6` (5.4s druid / 12s hunter
stings) cleanly separates live inference from cross-combat carryover. All Q
fixtures that drive `computeLandTable` use blips of 1.5s and 2.0s and are
unaffected.

### WR-03: Stale "2s" comments contradict D-05/D-17 and misstate the live cpDamage window

**Verdict:** real (mandated cleanup — DESIGN-CONTEXT locked decision 5 requires
the legacy 2s wording to be updated with the refactor).

**Files modified:** `core/spell_trace_core.lua`
**Commit:** b291d19
**Applied fix:** Comments only, no code change. Line 214 area: `Reuses
macroTorch.LAND_INTENT_TTL (2s, D-02).` → `(0.9s default, D-17); samples whose
damage line lags the cast by more than the window are purged unpaired`. Line 459
area: `(<=2s land offset)` → `(<= 0.9s default land offset)`. The
`LAND_INTENT_TTL` comment-reference count stays at 10 (gate requires >= 9).
Note: the phase's historical cpDamage diff-count gate counts grep hits anywhere
in the diff text, including unchanged context lines (the hunk context shows the
`pairCpDamageIntent` function header); verified on this fix's diff that zero
changed (`+`/`-`) lines touch any cpDamage function name — D-17 honored.

### WR-04: HUMAN-UAT troubleshooting branch (b) describes output the implemented machinery cannot produce

**Verdict:** real.

**Files modified:** `classes/druid/HUMAN-UAT.md`
**Commit:** c7e378a
**Applied fix:** Rewrote Phase-29 section 6 branch (b) from "blue (inferred)
line followed by red 'was cancelled by ...'" to the actually observable
sequence: green landed line followed by red cancel (fail-wins revoking a paired
land); added the note that the blue (inferred) line is by boundary design never
revoked because evidence-less fails arrive after the window closes. Verified
the reasoning against `finalizeFail` (revoke requires intent state `'landed'`,
which only pairing produces; inference never marks an intent landed) and the
window math (`blip > ttl` at inference implies any later fail is out of window).

### WR-05: Self-hit channel has no target-ownership check — asymmetric with the apply channel's guid check

**Verdict:** real.

**Files modified:** `core/spell_trace_core.lua`
**Commit:** 0dd06b7
**Applied fix:** `onSelfDamageLine` now captures the target portion of the line
(second pattern capture) and refuses any line whose parsed target does not
match the current `macroTorch.target.name` (case-insensitive), mirroring the
apply channel's guid ownership rejection. Vanilla self-hit lines carry damage
and absorb suffixes (`for 548`, `(45 absorbed)`), so the absorb suffix is
stripped first and the damage suffix second via two Lua 5.0-legal
`string.gsub` calls (alternation is unavailable in Lua patterns). The check
sits before `pairLandIntent`/announce/record, so a retarget-in-flight line can
neither leak into the current target's ledger nor print a green line claiming
the wrong mob. Q-07's fixture line (`'Your Ferocious Bite hits QTestMob for
548.'`) passes the new check unchanged; the misattribution scenario (line names
MobA while MobB is current) is refused. The residual that even name equality
cannot close (two same-named mobs) is IN-04, out of scope by review.

---

_Fixed: 2026-09-10T08:10:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_