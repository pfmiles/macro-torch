---
phase: quick-260825-vp9 (cumulative review of quick tasks 260825-s3v + 260825-t86 + 260825-vp9, base dc6bc00)
reviewed: 2026-08-25T15:46:06Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/cat.lua
  - core/selftest.lua
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: issues
---

# Code Review: quick tasks 260825-s3v + 260825-t86 + 260825-vp9 (catAtk discharge chain)

**Reviewed:** 2026-08-25
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the cumulative end state of `classes/druid/cat.lua` and `core/selftest.lua` at HEAD
(diff `dc6bc00..HEAD`, source commits ad093c9, 96e55d1, 592284c). The change chain gives
`macroTorch.energyDischargeBeforeBite` a total boolean return contract (`true` = a discharge
attempt was initiated on this frame, `false` only when no condition matched), makes `cp5Bite`
defer its bite verdict for one frame on `true`, extends the same contract to `quickKeepRip`
(vp9, closing WR-01), and adds a liveness selftest for the `shouldDischarge == true` +
real-helper-returns-false fall-through (vp9, closing IN-01).

**Prior-review cross-check — verdict per item:**

1. **WR-01 (quickKeepRip boolean discard) — VERIFIED FIXED, correct and complete.**
   `classes/druid/cat.lua:336-345` now guards the bite exactly as `cp5Bite` does:
   `if macroTorch.energyDischargeBeforeBite(clickContext) then return end` precedes
   `macroTorch.safeBite(clickContext)`. Guard placement is right (before the bite, after the
   cp>=3 / no-Rip / not-immune gate). No regression on discharge-false: `false` is returned
   only when no discharge condition matched (or under `isPseudoInfiniteEnergy`, where the
   pre-fix code also skipped the discharge and bit immediately), so the safeBite fall-through
   at line 343 is reached in every case the pre-fix code reached it. Cross-module exclusivity
   confirms the dedup flag cannot spuriously defer here: the only prior `isDischarged` setter
   in a frame is `cp5Bite`, whose gate (5CP + immuneRip/ripPresent/fast) is mutually exclusive
   with quickKeepRip's gate (cp>=3 + no Rip + not immune) on the fast-battle dimension, and
   fast battles skip quickKeepRip entirely (combo.lua:164). The OoC corner that motivated
   WR-01 — oocMod doing nothing at 5CP when the cp5Bite gate is closed, leaving OoC up for
   quickKeepRip's same-frame free bite — now defers instead of biting.
2. **IN-01 (no coverage of shouldDischarge=true + real helper returning false) — VERIFIED
   COVERED, and the test cannot pass spuriously.** The new test
   (`core/selftest.lua:862-902`, P-category) runs the REAL `energyDischargeBeforeBite` with a
   context where every discharge arm is provably false:
   - Entry gate opens on the second disjunct only — `isRipPresent` stubbed `true`
     short-circuits `isImmuneRip or isRipPresent or isFastBattleNotPvp` at cat.lua:117, so the
     real (unstubbed) `isFastBattleNotPvp` is never invoked and real target state is never read.
   - `shouldDischarge` stays true: `isPseudoInfiniteEnergy = false` on the ctx; `isRipPresent`
     stubbed true forces the `ripLeft` arm, stubbed to `4` (> 2.3), so the fence holds.
   - In the helper: `ooc = false`; mana (50) < BITE_E + SHRED_E (95) and < BITE_E + CLAW_E
     (80), both short-circuiting before `isBehindAttackJustFailed`; the Rake arm
     short-circuits on `not isRakePresent` = false (Rake stubbed present), so the real
     `isFastBattleNotPvp` on line 179 is also never evaluated.
   - The helper hits the `return false` tail (cat.lua:186) and `cp5Bite` falls through to the
     stubbed `safeBite`, setting `biteCalled = true`. A spurious pass is impossible: if the
     false tail ever became a deferral, `biteCalled` stays false and the assert fires; if
     `cp5Bite` errors, the pcall assert fires. Restores run unconditionally before both asserts
     (matching the D-01 ordering pattern of the sibling P tests), so a stumbled run cannot
     poison later tests.
   - Mana shadowing verified against the entity implementation: `macroTorch.player`'s metatable
     (`macroTorch.classMetatable`, core/class.lua:21-32) defines `__index` only — no
     `__newindex` — so `macroTorch.player.mana = 50` creates an own-key shadow; `mana` is a
     live accessor (Unit.lua:114 `UNIT_FIELD_FUNC_MAP['mana']` → `UnitMana(self.ref)`, never an
     own key), so the `rawget` snapshot yields nil and `rawset(..., nil)` at line 899 deletes
     the shadow, restoring the live accessor exactly as the test comment claims.
3. **IN-02 (duplicate isPseudoInfiniteEnergy filter) — still OPEN, relevance unchanged by vp9.**
   Not re-reported as a finding: `cp5Bite` still fences via `shouldDischarge`
   (cat.lua:125-127), and `quickKeepRip` still has no caller-side fence, so the inner check at
   cat.lua:163-165 remains the only guard for that call site. vp9 changed the bite side of
   quickKeepRip, not the discharge side; the divergence note from the prior review stands
   as-is.

No critical or warning findings. One documentation-drift info item follows.

## Info

### IN-01: Stale P-category header count comment (says 6, category now has 8)

**File:** `core/selftest.lua:694` (vs. updated count comment at line 904)
**Issue:** The section header still reads "Category P — Phase 26 fast-battle judgment
(6 tests, 2 from 26-01 + 4 from 26-02)". The cumulative diff added the quick 260825-t86 test
(lines 820-852) and the quick 260825-vp9 test (lines 862-902), and the trailing registration
count at line 904 was correctly updated to 8 — but the header was not. Reader-visible drift:
the header and the tail disagree on the category size.
**Fix:** Update the header to "(8 tests, 2 in 26-01 + 4 in 26-02 + 1 in quick 260825-t86 + 1 in
quick 260825-vp9)" to mirror line 904.

---

_Reviewed: 2026-08-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_