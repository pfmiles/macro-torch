---
phase: 260914-nth
fixed_at: 2026-09-14T10:25:06Z
review_path: .planning/quick/260914-nth-per-2026-09-14-sample-verdict-ooc-frame-/260914-nth-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase quick-260914-nth: Code Review Fix Report

**Fixed at:** 2026-09-14T10:25:06Z
**Source review:** `.planning/quick/260914-nth-per-2026-09-14-sample-verdict-ooc-frame-/260914-nth-REVIEW.md`
**Iteration:** 1
**Scope:** critical_warning — WR-01 and WR-02 fixed; IN-01 and IN-02 explicitly NOT fixed (out of scope)
**Isolation:** `workflow.use_worktrees` is `false` (#2825) — all edits, verification, and commits ran in the MAIN checkout on `main`; no worktree, no temp branch, no recovery sentinel.

**Summary:**
- Findings in scope: 2 (WR-01, WR-02)
- Fixed: 2
- Skipped: 0
- Changed files (allowlist observed): `classes/druid/Druid.lua`, `classes/druid/selftest.lua` only

## Fixed Issues

### WR-01: Zero-delta energy argument inverted for `shouldCastFFDuringWaitWindow`; narrow FF-fill delta exists and unverified

**Files modified:** `classes/druid/selftest.lua`
**Commit:** 0db2f43
**Disposition:** fixed-via-pin. No retro-edit of the committed PLAN.md / SUMMARY.md (historical artifacts, per constraint). The behavior is now pinned so it stops being accidental: one new deterministic selftest `"WR-01 FF wait window: essence 0-energy edge accepted (SHRED_E=60)"` placed directly after R8-06 (the FF wait-window test block). It builds the razor-edge frame — 3 bleeds, `ooc=false`, `isPseudoInfiniteEnergy=true`, erps forced to 60, `SHRED_E=60`, `player.mana` shadowed to 0 — and asserts `shouldCastFFDuringWaitWindow(ctx) == true`, explicitly ACCEPTING the current verdict (FF fills an otherwise-idle GCD during the ~1s essence regen pause; cast path models energy cost 0; client verification remains unrun-verify). The English comment above the test carries the direction-correct rationale: a HIGHER `minAbilityCost` WIDENS the `currentEnergy < min` clause; the reachable delta zone is erps == 60 (naked Essence) AND SHRED_E == 60 (no Improved Shred) AND currentEnergy == 0; pre-change CLAW_E = 45 made the window unreachable.

**Stub discipline (verified against bodies before writing, not stubbed blindly):**
- `isKillShotOrLastChance`, `macroTorch.computeErps` (forced 60), `macroTorch.target.isImmune` (forced false), and `macroTorch.isSpellExist` (forced true) are function-stubbed and restored BEFORE the asserts — the CR-01/R6-05 discipline. The `isSpellExist` stub is load-bearing: without it a client character that has not learned Shred would make `shouldUseShred` return false at its D-03 guard and `getNextAbilityCost` would wrongly resolve CLAW_E.
- `player.mana` and `player.isBehindAttackJustFailed` are rawget-snapshotted, own-key shadowed, rawset-restored (`classMetatable` has no `__newindex`, so the own-key shadow works and rawset(nil) removes it).
- `shouldDoReshift` is deliberately NOT stubbed. Body verified against cat.lua:252-281: with projected = 0 + 60*1.5 = 90 >= SHRED_E 60 the condition-1 clause `math.ceil(projectedEnergy) < nextAbilityCost` resolves false naturally. Two ctx fields `RESHIFT_ENERGY = 40` and `TIGER_E = 30` were added (typical values used elsewhere in the suite) so the intermediate `effectiveEnergy = RESHIFT_ENERGY - TIGER_E` arithmetic stays defined when combat state reaches it — this is the one deliberate deviation from a minimal ctx, recorded here.
- `getNextAbilityCost` trace kills steps 1-4 deterministically via ctx presets: `isTrivialBattle=false`, `isFastBattleNotPvp=false` (cached), `isImmuneRip=true`, `comboPoints=1` (shouldUseBite false), `isTigerPresent=true` (step 2 fall-through), `isRipPresent=true` (shouldCastRip false), `isRakePresent=true` (step 4 fall-through) -> step 5 `shouldUseShred` true (infinite + behind + not just-failed) -> SHRED_E = 60.

### WR-02: Branch 3 returns `nil` instead of `false` when both `ooc` and `isPseudoInfiniteEnergy` are undefined

**Files modified:** `classes/druid/Druid.lua`, `classes/druid/selftest.lua`
**Commit:** f0dc226
**Disposition:** fixed-via-normalization+pin.
1. `Druid.lua:989` normalized to `local infiniteEnergy = clickContext.isPseudoInfiniteEnergy == true` — single line, existing comment above untouched, restores the strict boolean contract (branch 3's and-chain now evaluates `false or false` -> false on absent-flag paid frames instead of `false or nil` -> nil). Zero behavior change for all real inputs: production always sets the field to an explicit boolean (combo.lua:108) and every existing R6 ctx presets it. The bare and-chain at line 1023 is byte-identical, so no gate grep needles or pinned counts needed adjustment.
2. One new selftest `"Principle R6-05c: 3+ bleeds paid frames, absent infinite flag — strict false (WR-02 pin)"` placed directly after R6-05b, mirroring R6-05b's ctx but with the `isPseudoInfiniteEnergy` key ABSENT, asserting `shouldUseShred(ctx) == false` strictly. The and-chain short-circuits at `(false or false)` before the `isBehind` / `isBehindAttackJustFailed` accessors, so no rawget/rawset shadowing is needed (same no-shadow comment pattern as R6-05b). The R6 series has no count comments — no count updates.

## Out of Scope (NOT fixed, per fix_scope=critical_warning)

- **IN-01** (branches 2/3 mergeable): left as-is — simplification opportunity, not a defect; not in scope.
- **IN-02** (asymmetric free-frame combos untested): left as-is — optional coverage; not in scope.

## Verification Battery

All gates ran in the MAIN checkout (worktrees disabled; reproducible from the current tree). All results as of commit f0dc226.

| Gate | Druid.lua | selftest.lua |
|------|-----------|--------------|
| Lua 5.0.3 `loadfile` compile (`/tmp/luabuild/lua-5.0.3/bin/lua`) | OK | OK |
| Lua 5.1.5 `loadfile` compile (`/tmp/luabuild/lua-5.1.5/src/lua`) | OK | OK |
| Lua 5.4.7 `loadfile` compile (`/tmp/luabuild/lua-5.4.7/src/lua`) | OK | OK |
| bbcheck (`.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js`) | BALANCED | BALANCED |
| Token gate: `#` in added lines (range a8fc0da..HEAD) | 0 | 0 |
| Token gate: `goto `/`::` in added lines | 0 | 0 |
| CJK in added lines (range a8fc0da..HEAD) | 0 | 0 |
| CRLF in files | 0 | 0 |
| `git diff --check` (range a8fc0da..HEAD) | clean | clean |

**Change-surface audit** (range a8fc0da..HEAD): `Druid.lua` +1/-1 (exactly the line-989 normalization), `selftest.lua` +90/-0 (63 lines WR-01 pin + 27 lines R6-05c pin) — matches intended. Changed files match the allowlist exactly.

**Gate spelling deviations (honest record):** none in the final run — every listed gate passed as specified. One harness note for transparency: an intermediate battery invocation used a Redis-style `ARGV[1]` global by mistake and printed spurious traceback lines; it was identified as harness error (not file error), discarded, and the compile gates were re-run with literal paths, all OK. No build.sh run, no SM_Extend.lua touched, no committed PLAN.md / SUMMARY.md / REVIEW.md modified, no untracked files added. The first WR-01 commit (test-only) was verified to pass against the pre-normalization production code (the ctx presets `isPseudoInfiniteEnergy = true`, so the normalize is orthogonal); the WR-02 commit carries the normalization and its pin atomically.

**Commit list:**
1. `0db2f43` `fix(260914-nth): WR-01 pin essence 0-energy FF wait-window edge (accepted verdict, SHRED_E=60)` — selftest.lua
2. `f0dc226` `fix(260914-nth): WR-02 normalize infiniteEnergy to strict boolean + R6-05c absent-flag pin` — Druid.lua, selftest.lua

---

_Fixed: 2026-09-14T10:25:06Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_