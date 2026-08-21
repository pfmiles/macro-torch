---
phase: 26-phase-fast
reviewed: 2026-08-22T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - classes/druid/cat.lua
  - classes/druid/combo.lua
  - classes/druid/Druid.lua
  - core/selftest.lua
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 26: Code Review Report (Re-review after gap-closure fixes)

**Reviewed:** 2026-08-22
**Depth:** standard
**Files Reviewed:** 4
**Status:** clean

## Summary

This is a re-review of the Phase 26 source files after gap-closure fixes were applied (commits 306cd1e, a3559d5, 5d46a78, 0115a80). An earlier deep-depth review (26-REVIEW.md v1) identified 1 critical, 1 warning, and 4 info findings. All six have been verified against the current code state.

**Result: All previously-reported findings are FIXED. No new issues introduced by the fixes.**

---

## Fix Verification

The following table tracks each finding from the original review (v1) against the current code.

### CR-01: P-02 self-test permanently shadow-taints `macroTorch.target.isPlayerControlled`

**Status:** FIXED

**Original issue:** The PvP-exclusion test wrote a plain boolean into `macroTorch.target.isPlayerControlled` and restored with a stale boolean value, leaving a permanent own-key shadow over the FIELD_FUNC_MAP `__index` accessor. This froze PvP detection for the entire session.

**Fix applied (selftest.lua:704-722):**
- Line 706: Uses `rawget(macroTorch.target, 'isPlayerControlled')` to snapshot ONLY the own-key state (normally nil), not the `__index`-resolved value.
- Line 719: Restores with `macroTorch.target.isPlayerControlled = rawOrigPvp` which is nil, removing the own-key and re-exposing the `__index` accessor.
- Lines 707-720: Comments document the shadow-trap (CR-01 reference) and D-01 ordering rationale.

**Verification:** The rawget/nil-restore pattern is correct. Since `isPlayerControlled` is resolved via `classMetatable.__index` -> `UNIT_FIELD_FUNC_MAP['isPlayerControlled'](target)`, restoring nil causes the own-key to be deleted, making Lua fall through to `__index` again. This matches the recommended fix exactly.

---

### WR-01: `getNextAbilityCost`/`shouldCastRip`/`shouldUseBite` still report phantom abilities in fast battles

**Status:** FIXED

**Original issue:** In fast battles, `getNextAbilityCost` reported Rip (30 energy), Rake (40 energy), and Bite (35 energy) as the next ability, even though D-04/D-05/D-08 make them uncastable. This caused `shouldDoReshift` and `shouldCastFFDuringWaitWindow` to benchmark against phantom costs, misjudging reshift timing.

**Fix applied (Druid.lua:956-991):**
- Line 958: Declares `local fastBattle = macroTorch.isFastBattleNotPvp(clickContext)` once at function entry.
- Line 962: Bite branch gated with `and not fastBattle`.
- Line 975: Rip branch gated with `not fastBattle`.
- Line 980: Rake branch gated with `not fastBattle`.
- Lines 985-990: Fallthrough to Shred/Claw (the real castable builders in fast battles) is un-gated, ensuring a valid cost value is always returned.

**Verification:** The `not fastBattle` guards correctly exclude all three phantom abilities. The Tiger branch (line 970-972) is intentionally un-gated — Tiger can still be cast in fast battles. The fallthrough to Shred (60 energy) / Claw (45 energy) matches the actual builder costs in the fast-battle rotation. This matches the recommended fix exactly.

---

### IN-01: Design comment misstates Rip duration

**Status:** FIXED

**Original issue:** Comment at Druid.lua:809-810 claimed "Rake lasts 9s and Rip 12s", but `RIP_BASE_DURATION` is 10 and a standard 5-CP Rip lasts 18s. The ladder argument was still valid but the number was wrong.

**Fix applied (Druid.lua:808-809):**
- The comment now reads: "Rake lasts 9s and Rip at least 10s (18s at 5 CP), both exceeding the threshold"

**Verification:** The correction matches both the base duration (10s, from `RIP_BASE_DURATION = 10` at line 859) and the 5-CP case (18s, from `ripLeft` at line 1108 adding `(cp-1)*2`). This matches the recommended fix.

---

### IN-02: Stale Category P section header comment

**Status:** FIXED

**Original issue:** The header at selftest.lua:694-696 said "2 tests in this task, 4 more in 26-02-PLAN.md" but all 6 tests were already registered in the file.

**Fix applied (selftest.lua:694):**
- The header now reads: "Category P — Phase 26 fast-battle judgment (6 tests, 2 from 26-01 + 4 from 26-02)"

**Verification:** The count is accurate — there are exactly 6 test registrations in Category P (P-01 through P-06 at lines 698, 704, 726, 743, 762, 783). This matches the recommended fix.

---

### IN-03: P-06 couples to the lazy-cache internals of the function under test

**Status:** FIXED

**Original issue:** The cp5Bite regression test pre-seeded `ctx.isFastBattleNotPvp = true` on the clickContext, relying on the real judgment function to short-circuit on the cached field. This made the test's meaning order-dependent and wobble-prone if the cache internals changed.

**Fix applied (selftest.lua:779-815):**
- Line 789: Stubs `macroTorch.isFastBattleNotPvp` as a function returning true, symmetric to other collaborator stubs (`isRipPresent`, `safeBite`, `readyBite`, `energyDischargeBeforeBite`).
- Line 812: Restores `macroTorch.isFastBattleNotPvp` to its original function.
- Line 780-781: Test description updated to clarify stub usage.

**Verification:** The stub pattern is now consistent with all other collaborators in the test. The test no longer depends on the lazy-cache field being pre-seeded. This matches the recommended fix.

---

### IN-04: healthMax arm of `isFastBattleNotPvp` is true for missing/dead targets

**Status:** FIXED

**Original issue:** `UnitHealthMax('target')` returns 0 for a nonexistent or dead target, so the estimate arm would yield `true` for targets that do not exist or are dead. This was latent (all current call sites sit inside `isCanAttack`-gated branches) but the public function was unprotected against future callers.

**Fix applied (Druid.lua:819-821):**
- Lines 820-821: `if not macroTorch.target.isCanAttack then clickContext.isFastBattleNotPvp = false` before the health computation.
- Lines 818-819: Comment documents the issue reference (IN-04) and explains the rationale.

**Verification:** The `isCanAttack` guard caches `false` before the health-estimate arm, preventing a `true` verdict when there is no valid attackable target. The guard correctly gates the health-computation only, leaving the `willDieInSeconds` arm un-gated (it independently handles nil/dead targets through its own HRPS data check). This matches the recommended fix.

---

## New Findings

None. After thorough review of all four source files in their current state, no new bugs, security vulnerabilities, or code quality defects were introduced by the gap-closure fixes.

Key areas verified:
- **`isFastBattleNotPvp` (Druid.lua:812-832):** D-01 ordering preserved (PvP exclusion before cache), IN-04 guard correct (isCanAttack before healthMax), lazy-cache pattern consistent.
- **`getNextAbilityCost` (Druid.lua:956-991):** Fast-battle guards on Bite/Rip/Rake branches are correct; Tiger un-gated intentionally; Shred/Claw fallthrough always reachable.
- **`cp5Bite` (cat.lua:113-145):** D-08 guard on line 117 uses function call (not cache field); `cp5Bite` test (selftest.lua:779-815) properly stubs the judgment function.
- **Guard D-03 through D-08:** All six fast-battle guards in combo.lua and cat.lua verified as correctly placed and correctly gating on `isFastBattleNotPvp(clickContext)`.
- **SelfTest P-01 through P-06:** All six tests properly stub and restore their collaborators; no field-shadow corruptions remain.
- **`shouldDoReshift` (cat.lua:215-244):** RESHIFT_ENERGY=0 guard at line 217-219 is correct; multi-value return at 241-243 is properly consumed by caller at combo.lua:203.

---

_Reviewed: 2026-08-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_