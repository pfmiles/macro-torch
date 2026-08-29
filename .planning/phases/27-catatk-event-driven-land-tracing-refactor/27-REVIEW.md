---
phase: 27-catatk-event-driven-land-tracing-refactor
reviewed: 2026-08-30T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/cat.lua
  - classes/druid/combo.lua
  - classes/druid/leveling.lua
  - classes/druid/selftest.lua
  - core/spell_trace_core.lua
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
status: issues_found
---

# Phase 27: Code Review Report (Third Incremental Pass)

**Reviewed:** 2026-08-30
**Depth:** standard (per-file analysis with language-aware checks)
**Files Reviewed:** 6
**Status:** issues_found (2 info-level; no critical/warning)

**Scope:** This is the THIRD incremental pass, scoped to `git diff 30d5c1f..HEAD` restricted to the six files above (commits 1ca4c0f through 400f0f5). The first and second passes (preserved in git history; second-pass report at commit 30bbcb8) ended clean. This report REPLACES the second-pass content entirely. Findings established in prior passes were re-verified as still fixed where the delta touches the same functions; they are not re-litigated here.

## Summary

The delta delivers four things: (1) a single-point duration-formula refactor — `computeRip_Duration` / `computeRake_Duration` / `computePounce_Duration` plus the shared `applySavageryDurationCompression` primitive, with a declared INVARIANT that default (no-args) mode reads only write-once snapshots while explicit args are the only "live door"; (2) `expDuration` logging on the four fresh-cast log sites (safeRake/safeRip in cat.lua, Pounce in combo.lua and leveling.lua) plus snapshot-mode `expDuration` on the FB renewal lines; (3) restored green landed / red cancelled land feedback in spell_trace_core.lua; (4) show()-stubbing updates to Q-02/Q-05/Q-07 selftests following the Phase-26 CR-01 restore discipline.

All five review-focus items were verified against the actual code and hold, with details below. Two dead-code observations remain (Info-level). Prior-pass fixes re-verified as not re-broken in the delta: the FB renewal listener signature `function(spell, landTime)` (CR-01, Druid.lua:718) matches the dispatch `listener(spell, landTime)` (spell_trace_core.lua:219); the selftest global-restore discipline; the nil-guard chains in the land-framework; and Lua 5.0 compatibility.

## Re-verification of Review-Focus Items

### 1. INVARIANT: default duration mode never queries live equipment — HOLDS

`computeRip_Duration` (Druid.lua:1153), `computeRake_Duration` (1172), and `computePounce_Duration` (1183) were checked for any live-query call in their default paths. None of them call `isRelicEquipped`, `hasItem`, or any equipment API; the default arm reads only `macroTorch.context.lastRipAtCp` and `macroTorch.loginContext.last{Rip,Rake,Pounce}EquippedSavagery`. All live-door (explicit-arg) call sites were enumerated and all four are fresh-cast sites, exactly as the comment declares: cat.lua safeRake:406/410, cat.lua safeRip:422/428, combo.lua Pounce:144/146, leveling.lua Pounce:79/81. No producer other than fresh casts passes live state. `applySavageryDurationCompression` (1136) is pure.

Snapshot-mode degradation is nil-safe: `macroTorch.context and macroTorch.context.lastRipAtCp` (1156) and `macroTorch.loginContext and ...` (1160, 1176, 1187) mean absent snapshots degrade to base duration (10s Rip, 9s Rake, 18s Pounce) rather than throwing. The leveling-path Rip cast (leveling.lua:150, pre-existing line, unchanged in delta) and cat.lua safeRip (431, pre-existing) write `lastRipAtCp`; all reads of it in the new code go through the nil-safe pattern. Arithmetic re-checked: Rip = 10 + (cp-1)*2, x0.9 under Savagery — at 5 CP that is exactly 16.2s Savagery vs 18s no-idol, matching the comment at 1148-1150. `macroTorch.POUNCE_DURATION = 18` now exists at file scope (Druid.lua:867) — previously it was only assigned inside the never-called `showEnergyUsageSet` (265) and per-click in combo.lua (see IN-01).

### 2. Cast-log expDuration — HOLDS

Each of the four fresh-cast sites performs exactly ONE live query (`local savageryNow = macroTorch.player.isRelicEquipped('Idol of Savagery')`) and the same frozen value is both printed (`expDuration: ...` via the live door) and written to the snapshot field. The delta actually eliminates a latent double-query inconsistency that existed in the baseline (safeRake and safeRip previously called `isRelicEquipped` twice — once inside the show string and once for the write — allowing theoretical divergence between the printed and stored values). Rip passes `(comboPoints, savageryNow)` (cat.lua:428); Pounce sites pass only `savageryNow` — no combo points anywhere, correctly, since Pounce duration is CP-independent (fixed 18s, CP only feeds the stun). Rake passes only the savagery flag (math is CP-independent). All confirmed against combo.lua:145-148 and leveling.lua:80-83.

### 3. Renewal-line expDuration reads snapshots, never writes them — HOLDS

The FB renewal listener (Druid.lua:718-734) prints `expDuration:` through default-mode calls — `computeRake_Duration()` (723) and `computeRip_Duration()` (730) — plus the frozen `bleed idol:` field read from `loginContext.last{Rake,Rip}EquippedSavagery`. Both are pure reads; the only writes the listener performs are `recordLandEvent('Rake'/'Rip', landTime)` land-table entries, never the Savagery/CP snapshot fields. Snapshot inheritance is therefore intact: a bleed refreshed by FB keeps the ORIGINAL cast's Savagery state (and thus tick interval) for both the remaining-time math and the expDuration print.

A subtlety verified: `recordLandEvent` dispatches listeners only after its own `if not macroTorch.loginContext then return end` guard (spell_trace_core.lua:202-204), so the listener's direct `macroTorch.loginContext.lastRakeEquippedSavagery` index (724) cannot hit a nil loginContext at game time. This dispatch-order reliance matches pre-existing listener expectations and was left as-is (no new finding). In Q-07/Q-10 the fake target's `hasBuff = function() return false end` short-circuits `isRipPresent`/`isRakePresent` before those fields are touched, keeping the tests hermetic.

### 4. Green/red land feedback — HOLDS

- `recordLandEvent` is confirmed silent (spell_trace_core.lua:199-222, no show call), so FB-driven Rake/Rip rewrites and pairing-free self-hit records never print a false green "landed" line.
- `processRawAuraApply` prints green only after `pairLandIntent` returns non-nil (261). `pairLandIntent` itself gates on `macroTorch.target.isCanAttack` and a non-nil `macroTorch.loginContext.intentTable`, so the print's `macroTorch.target.name` access cannot run with an invalid target or nil loginContext.
- `onSelfDamageLine` guards its green print with `if macroTorch.loginContext and macroTorch.target.isCanAttack` (338-341). This is the right shape: the event registration still records (defensive per-function guards), but user-visible output cannot run on an invalid target.
- `finalizeFail`'s new red cancellation print (303-304) sits inside the same guard staircase as the revocation itself (`not spell or not macroTorch.target.isCanAttack` at 271, loginContext/intentTable checks at 274-277), and the fail-type is rendered as `tostring(failType or 'fail')` — nil-safe (Q-05 calls `finalizeFail` with two args and passes).
- failType threading does not double-revoke: `recordFailTable` invokes `finalizeFail` exactly once per fail line (156), and `finalizeFail`'s loop returns after consuming at most ONE pending/landed intent (307-309 `return`). A second fail event arriving after the intent is already `'failed'` finds nothing (state filter at 289) and does not print a second red line. Fail-vs-FB-rewrite interplay was also traced: `removeMatch` removes only entries equal to `intent.landAt`, so a later FB rewrite entry (different timestamp) survives a revocation of the original cast — correct fail-wins semantics.
- `macroTorch.show(a, color)` (interface_debug.lua:84) supports both 'green' and 'red', so the two-arg calls are well-formed.

### 5. Selftest show()-stubs — HOLDS

Q-02 (765-766, 770, 789), Q-05 (854, 864, 878), and Q-07 (914, 921, 933) snapshot `macroTorch.show`, replace it with a raw no-op assignment, run the framework calls inside `pcall`, and restore `macroTorch.show` by raw assignment BEFORE any assert executes. Because the save/restore lines sit outside the `pcall` block, the restore is guaranteed even when the probed call throws — the Phase-26 CR-01 discipline is fully satisfied: no failing assert can leave a polluted session, and none of these tests writes to `macroTorch.tracingSpells`, `macroTorch.landSources`, `macroTorch.landListeners`, or any real loginContext sub-table. Q-06 correctly needs no stub: its `finalizeFail` hits a `'pending'` intent (no red print path) and its later aura-apply cannot pair a finalized intent (no green print path).

## Hard-Constraint Verification

- **Lua 5.0**: no `#` length operator anywhere in the six files (grep over the whole files, comment lines excluded). No goto. No 4-arg `string.find` — all occurrences are 2-arg pattern-only calls (e.g. spell_trace_core.lua:320, 322, 242). The new code introduces no varargs, no `unpack` misuse, no `..` on non-coercible types.
- **Line endings**: all six files have zero CR characters (LF throughout, per .gitattributes).
- **Comment language**: all new comments in the delta are English (the cast-site live-door notes, the INVARIANT doc block, the green/red re-store comments). Legacy Chinese comments untouched; not flagged.
- **Savagery 0.9 wording**: the term "compression" is used consistently in all new code and comments (`applySavageryDurationCompression`, "duration compression primitive", "same tick count, faster ticks"). The only string "penalty" remaining in the six files is in the doc comment at Druid.lua:1133-1135, where it appears exclusively in the negating clause "This is a BUFF, not a penalty" — correct framing, not a mislabel; verified against the user's memory note that Savagery's 0.9 factor is a gain.

## Info

### IN-01: `clickContext.POUNCE_DURATION` is now dead after the single-point refactor

**File:** `classes/druid/combo.lua:70`
**Issue:** The refactor moved Pounce duration to the file-scope `macroTorch.POUNCE_DURATION = 18` (Druid.lua:867), which `computePounce_Duration` reads. `pounceLeft` was the last reader of the per-click field and now goes through `computePounce_Duration()` (Druid.lua:1255). A repo-wide grep confirms `clickContext.POUNCE_DURATION = 18` at combo.lua:70 has no remaining reader anywhere. Two sources of truth for the same constant (per-click field vs file-scope global) invites drift if one is ever changed alone.
**Fix:** Remove line 70 from `macroTorch.catAtk()` (the clickContext field), leaving `macroTorch.POUNCE_DURATION` as the single source. Keep it only if a future per-click override is planned — in which case a comment stating that intent should be added.

### IN-02: `showEnergyUsageSet` now duplicates the file-scope constant (harmless, never called)

**File:** `classes/druid/Druid.lua:265`
**Issue:** The never-called `showEnergyUsageSet` assigns `macroTorch.POUNCE_DURATION = 18`, which now duplicates the new file-scope assignment at Druid.lua:867 with the same value. Both are 18 today; the duplication is dead code only (the function has no callers in-tree), so no behavioral risk, but it is a second write site for a constant the refactor intended to centralize.
**Fix:** Optionally drop `macroTorch.POUNCE_DURATION = 18` from `showEnergyUsageSet` (or convert that legacy function to read the file-scope constant) so exactly one write site exists, mirroring how `RIP_BASE_DURATION = 10` / `RAKE_DURATION = 9` were consolidated.

## Prior-Pass Findings Re-Verified (not re-broken by this delta)

- **CR-01 (pass 1)**: FB renewal listener signature — still `function(spell, landTime)` with `spell` first and the numeric `landTime` second (Druid.lua:718), matching framework dispatch `listener(spell, landTime)` (spell_trace_core.lua:219). Q-10 still asserts the numeric renewal time.
- **Self-test restore discipline (Phase 26 CR-01)**: re-checked above under focus item 5; the delta's added stubs comply.
- **Nil-guard chains in the land framework**: `recordCastTable`, `recordFailTable`, `recordLandEvent`, `pairLandIntent`, `finalizeFail`, `consumeLandEvent/FailEvent`, and the three `peek*` functions all retain their pre-existing `loginContext`/`target.isCanAttack` guards; the delta's new show() calls are each placed inside those established guard staircases.
- **V-01 (pass 2 area)**: `macroTorch.context` being nil in a fresh out-of-combat session remains stubbed in Q-10; the new `computeRip_Duration` default arm additionally made that failure mode silently degrade (base 10s) rather than error.
- **WR-02 multi-feral residual risk note (accepted)**: unchanged semantics; the green print fires only on a successful own-target pairing, so it cannot claim a foreign apply as landed.

---

_Reviewed: 2026-08-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Scope: git diff 30d5c1f..HEAD (third incremental pass on phase 27)_