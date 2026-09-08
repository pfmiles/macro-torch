---
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
fixed_at: 2026-09-08T22:30:00+08:00
review_path: .planning/phases/28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac/28-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report

**Fixed at:** 2026-09-08T22:30:00+08:00
**Source review:** .planning/phases/28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac/28-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 2 (fix_scope = critical_warning; IN-01/IN-02 out of scope)
- Fixed: 2
- Skipped: 0

## Fixed Issues

### WR-01: Selftests permanently shadow `isBehindAttackJustFailed` on the live player

**Files modified:** `classes/druid/selftest.lua`
**Commit:** 58735b4
**Applied fix:** R6-01/R6-02/R6-03 no longer write `macroTorch.player.isBehindAttackJustFailed = false`
unconditionally. Each test now follows the CR-01 stub discipline (Cat U batch precedent): snapshot via
`rawget(player, 'isBehindAttackJustFailed')`, install the own-key shadow, run `shouldUseShred(ctx)` inside a
`pcall`, restore via `rawset(player, 'isBehindAttackJustFailed', saved)` BEFORE any assert, then assert on the
captured result (`ok` + `res` separately so the specific expectation message survives). R6-02/R6-03 carry a
one-line pointer comment; the full rationale (PLAYER_FIELD_FUNC_MAP accessor + no `__newindex` on the class
metatable -> bare assignment permanently shadows) is documented above R6-01. Test registration count unchanged.

### WR-02: `onCpDamageLine` discards the parsed spell name — stale intent mislabeling leak

**Files modified:** `core/spell_trace_core.lua`, `classes/druid/selftest.lua`
**Commit:** c94af69
**Applied fix:**
- `onCpDamageLine` now captures the spell name as a third subpattern (`(.-)` in both hits/crits patterns) and
  maps it through a whitelist (Claw -> claw, Shred -> shred, Ferocious Bite -> bite). Non-whitelisted lines
  (Rake in particular) return BEFORE pairing, so they can never touch the intent stack.
- `pairCpDamageIntent(guid, now, want)` gained an optional third parameter; when given, the pair-pass match
  condition additionally requires `intent.sample.spell == want`. The gate lives inside the match condition, so a
  guid match with a spell mismatch consumes nothing — the intent stays pending for its own line. Callers without
  `want` (U-04/U-05) keep the previous behavior.
- Cat U-07 selftest extended with a Rake-mismatch scenario (dodged Claw intent must survive a following
  `Your Rake hits ...` line: zero emission, intent count still 1). No new registration — the 28-04 battery
  anchor `SelfTest:register("Cat U-0` == 9 is preserved.
- Cosmetic comment cleanup in the same file: `debug decisions #2/#6` -> `debug decisions 2 and 6`, so the static
  Lua 5.0 ban grep (`#`/`goto `/`unpack`, which per 28-01 PLAN counts comment lines too) reports 0 on the touched
  source files.
- **Status note:** pairing-condition logic fix — widget behavior is pinned by the U-06/U-07/U-08 in-game
  selftests, but the on-client run is part of HUMAN-UAT; flagged `fixed: requires human verification`.

## Verification Evidence

All gates ran inside the isolated review-fix worktree (`.claude/worktrees/rf-28-118322-1788877293`, branch
`gsd-reviewfix/28-118322`), which was fast-forwarded onto `main` after the fixes — the worktree itself is removed.
`SM_Extend.lua` was regenerated inside the worktree during verification and discarded with it; the numbers below
are reproducible from the main checkout by re-running `bash build.sh`.

- bbcheck (Phase 27 tool, per-plan): `classes/druid/selftest.lua` BALANCED, `core/spell_trace_core.lua` BALANCED
  (after both fixes).
- `bash build.sh` exit 0 (after both fixes).
- 28-04 battery anchors (both fixes): cpDamage function set == 5, `SelfTest:register("Cat U-0` == 9,
  `macroTorch.cpDamageSample` == 4, `macroTorch.cpDamageCast` == 4, `function macroTorch.pairLandIntent` == 1,
  R8 nine-symbol grep == 9 (with the corrected `shouldDoReshift` anchor per 28-04-SUMMARY).
- Static Lua 5.0 ban grep `#|goto |unpack`: `classes/druid/selftest.lua` = 0, `core/spell_trace_core.lua` = 0
  (was 1 pre-fix, cleaned). `SM_Extend.lua` = 8 lines are pre-existing build-artifact comment text outside the
  touched-source scope.
- `git diff --check` clean after each fix.

## Skipped Issues

None — both in-scope warning findings were fixed.

---

_Fixed: 2026-09-08T22:30:00+08:00_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_