---
status: clean
depth: standard
files_reviewed: 3
critical: 0
warning: 0
info: 0
total: 0
---

# Code Review: reshift effective energy guard

**Commit:** `eeb306a` — `fix(druid): add effective energy guard to shouldDoReshift`
**Date:** 2026-08-01

## Scope

| File | Type | Lines Changed |
|------|------|---------------|
| `classes/druid/cat.lua` | Core logic | +16 / -3 (`shouldDoReshift`) |
| `classes/druid/Druid.lua` | Comments | +7 (3 locations) |
| `classes/druid/selftest.lua` | Tests | +43 / -4 (R2-07 updated, R2-08 added) |

## Summary

The change adds an **effective energy guard** to `shouldDoReshift` that prevents reshifting when the net energy gain (after accounting for the mandatory Tiger's Fury recast) would be zero or negative. This is a correctness fix: the old logic only checked whether waiting 1.5s was sufficient, without verifying that reshifting actually improves the player's energy position.

## Findings

**No issues found.** All 3 files pass review at standard depth.

### Detailed analysis

#### 1. `shouldDoReshift` — effective energy computation (cat.lua:221–231)

```
effectiveEnergy = RESHIFT_ENERGY - TIGER_E (when Tiger present)
Guard: effectiveEnergy > currentEnergy  (= positive earning)
```

**Correctness verification:**

| Scenario | Tiger | RESHIFT_ENERGY | TIGER_E | effectiveEnergy | Earning | Verdict |
|----------|-------|----------------|---------|-----------------|---------|---------|
| BiS gear | present | 60 | 30 | 30 | > 0 (if mana < 30) | ✅ May reshift |
| Non-BiS | present | 40 | 30 | 10 | ≤ 0 (if mana ≥ 10) | ✅ Won't reshift |
| No Tiger | absent | 60 | — | 60 | > 0 (if mana < 60) | ✅ May reshift |

- **Tiger cost modeling:** When Tiger's Fury is active, reshifting removes the buff. The mandatory recast costs `TIGER_E`, correctly deducted from `RESHIFT_ENERGY`. When Tiger is not present, no deduction needed — the game won't force-cast it post-reshift.
- **Operator choice (`>` vs `>=`):** Using `>` (strict) means zero-net-gain reshifts are blocked. This is correct — incurring a 1.5s GCD for zero energy improvement is never worth it.
- **Short-circuit evaluation:** Lua's `and` stops at condition 1 if waiting is sufficient, avoiding unnecessary computation of condition 2.
- **Negative effectiveEnergy:** If `TIGER_E > RESHIFT_ENERGY` (hypothetical edge case), `effectiveEnergy` goes negative and `negative > mana` evaluates `false`, correctly blocking reshift.

#### 2. Comment additions (Druid.lua)

| Location | Comment | Assessment |
|----------|---------|------------|
| `computeReshiftEnergy` (L451–452) | Returns raw value; Tiger cost deducted by caller | ✅ Accurately documents contract — consistent with `shouldDoReshift` behavior |
| `getNextAbilityCost` (L883–886) | Return value reflects current state; callers must add TIGER_E for post-reshift scenarios | ✅ Accurate advisory — `shouldDoReshift` handles Tiger cost via `effectiveEnergy` deduction (gain-side) rather than cost-side addition, an equivalent approach |
| `tigerSelfGCD` (L1148–1149) | Internal 1s CD, not global GCD | ✅ Clarifies local scope of this timer |

#### 3. Test updates (selftest.lua)

**R2-07** (RESHIFT_ENERGY: 40 → 60):
- The bump from 40 to 60 ensures `effectiveEnergy = 60 - 30 = 30`, giving a reasonable test window (mana < 30) for the "should reshift" path. With the old value of 40, `effectiveEnergy = 10`, making the test skip at almost all realistic mana levels.
- Added earning guard skip: correctly mirrors the new `effectiveEnergy > mana` condition.

**R2-08** (new test: earning ≤ 0 → no reshift):
- `RESHIFT_ENERGY = 40`, `TIGER_E = 30` → `effectiveEnergy = 10`. Test asserts `shouldDoReshift == false` when `mana ≥ 10`.
- Complementary to R2-07: R2-08 covers the domain where the new guard blocks reshift.

**Test domain coverage:**

```
mana:  0 ─────────── 10 ─────────────────── 30 ────────────→∞
                     │◄── R2-08 (false) ──►│
                     │◄── R2-07 (true) ───►│ (if projected < nextAbilityCost)
R2-07 skips ────────┘                      └── R2-07 skips
                      R2-08 skips ─────────┘
```

R2-07 and R2-08 are complementary: for `10 ≤ mana < 30` (and `projectedEnergy < nextAbilityCost`), R2-07 verifies reshift happens with `RESHIFT_ENERGY=60` while R2-08 verifies it doesn't with `RESHIFT_ENERGY=40`. No coverage gap.

## Verification

- [x] Core logic: effectiveEnergy computation correctly models Tiger buff removal cost
- [x] Edge cases: nil TIGER_E, negative effectiveEnergy, effectiveEnergy == mana all handled safely
- [x] Condition ordering: short-circuit evaluation prevents wasted computation
- [x] Comments: consistent contract documentation across 3 locations
- [x] Tests: complementary coverage of positive and non-positive earning scenarios
- [x] Regression: change is strictly more conservative (AND gate) — no risk of false-positive reshifts

## Conclusion

The change is correct and well-tested. The effective energy guard is a strict improvement: it adds one additional condition (earning > 0) that can only block useless reshifts, never enable incorrect ones. The comment additions in Druid.lua consistently document the Tiger cost contract, and the test updates provide complementary coverage of the new guard's domain.