---
phase: 14-istrivialbattle-iskillshotorlastchance-60-dps-b
reviewed: 2026-06-20T03:10:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/Druid.lua
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-06-20T03:10:00Z
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed Phase 14 changes to `classes/druid/Druid.lua`: adding `estimatePlayerDPS()` and `getKSThreshold()` level-adaptive functions (lines 580-623), modifying `isTrivialBattle` condition B (line 822), simplifying `isKillShotOrLastChance` condition B from 15 per-CP constants + 55-line branching to a single flat threshold (lines 859-873), and adding 6 Category I selftests (lines 1378-1426).

The new functions correctly implement the PLAN.md specification: proper nil-level guards via `UnitLevel('player')`, 60-level hard guards preserving level-60 DPS (500) and KS-threshold (1750) behavior, and descending if-elseif level-bracket chains. All 15 `KS_CP*_Health*` constants are fully removed with zero lingering references. The selftests follow project conventions (isOptional=true, UnitClass guard, assert style).

Two warnings and two info items found. No critical issues.

## Warnings

### WR-01: isKillShotOrLastChance condition B loses CP-aware / group / PvP scaling, producing overly aggressive Bite at low CP

**File:** `classes/druid/Druid.lua:859-873`
**Issue:** The old `isKillShotOrLastChance` condition B had per-combo-point thresholds that differed by scenario:
- Solo/PvP (level 60): CP1=750, CP2=1000, CP3=1250, CP4=1500, CP5=1750
- 5-man group: scaled thresholds ~1500-3000 based on nearby mate count
- Raid: group thresholds + per-person scaling beyond 5 raiders
- PvP classification: `isInBattleField()` explicitly gated to solo thresholds

The new code replaces all of this with a single call: `targetHealth < macroTorch.getKSThreshold()` (1750 at level 60) regardless of combo points, group size, or PvP status (world bosses retain their special logic).

**Concrete regression at CP1:** When `isKillShotOrLastChance` returns true, `shouldUseBite` (line 1013) commits to Ferocious Bite. At CP1, Bite does minimal damage for 35 energy. The old code would only trigger Bite at CP1 when the target was truly about to die (health < 750 solo, or higher thresholds in groups where others could finish it). The new code triggers Bite at CP1 with targets up to 1750 health, wasting combo points and energy.

**PvP/battleground impact:** The `isInBattleField()` check was removed entirely. In battlegrounds, the old code used the conservative solo thresholds. The new code uses the aggressive flat threshold (1750 at level 60), triggering premature kill-shot attempts in PvP across all CP counts.

**Mitigation:** Condition A (`willDieInSeconds(2)` via HRPS) is the primary prediction path and remains unchanged. Condition B is the fallback path for when HRPS data is insufficient. The PLAN.md explicitly acknowledges this as an intentional simplification (test behavior 3: "equivalent to old KS_CP5_Health solo value").

**Fix (if CP-awareness should be preserved):**
```lua
-- Condition B with CP-aware scaling
local baseKS = macroTorch.getKSThreshold()
local cp = clickContext.comboPoints or 0
-- Scale threshold to be proportional to CP value (CP1=43%, CP5=100% of base)
local cpFraction = (cp - 1) * 0.14 + 0.43
return targetHealth < baseKS * math.max(cpFraction, 0.43)
```

**Fix (if intentional, document the tradeoff):**
```lua
-- [D-02] Level-adaptive single threshold (intentionally CP-agnostic; see Plan 01 for rationale)
-- Note: this is more aggressive than old per-CP thresholds for CP < 5.
-- When HRPS data is available, Condition A handles prediction correctly.
return targetHealth < macroTorch.getKSThreshold()
```

### WR-02: Selftest bracket boundary assertions are too permissive (>= instead of ==, v30 unchecked)

**File:** `classes/druid/Druid.lua:1391-1409`
**Issue:** The "bracket boundaries" selftests use `>=` assertions, which will pass even if the underlying lookup table values change unexpectedly:

- `v40 >= 200`, `v50 >= 350` in estimatePlayerDPS test -- would pass if the function returns 999 or any higher value
- `v40 >= 1050`, `v50 >= 1450` in getKSThreshold test -- same
- Level 30 is only validated for `type(v30) == "number"` with no value assertion at all -- should be exactly 120 (DPS) and 700 (KS threshold)

Contrast with the D-04 hard guard tests (lines 1379-1388) which correctly use exact `==` assertions.

**Fix:**
```lua
-- estimatePlayerDPS boundaries
assert(v30 == 120, "estimatePlayerDPS(30) should return 120, got: " .. tostring(v30))
assert(v40 == 200, "estimatePlayerDPS(40) should return 200, got: " .. tostring(v40))
assert(v50 == 350, "estimatePlayerDPS(50) should return 350, got: " .. tostring(v50))

-- getKSThreshold boundaries
assert(v30 == 700, "getKSThreshold(30) should return 700, got: " .. tostring(v30))
assert(v40 == 1050, "getKSThreshold(40) should return 1050, got: " .. tostring(v40))
assert(v50 == 1450, "getKSThreshold(50) should return 1450, got: " .. tostring(v50))
```

## Info

### IN-01: Stale TODO comments about wolfhead helm enchant (already implemented)

**File:** `classes/druid/Druid.lua:334, 425`
**Issue:** Two stale TODO comments reference work that was completed in this or a prior phase:

- Line 334: `-- TODO reshift energy restore should consider the head enchant: whether the wolfheart enchant exists`
- Line 425: `-- TODO reshift energy restore should consider wolfheart head enchant`

Both are now resolved by `computeReshiftEnergy()` (lines 568-578), which checks for Wolfshead Helm (+20 energy) and Furor talent ranks. The TODOs should be removed to avoid misleading future maintainers.

**Fix:** Remove both TODO comment lines (334 and 425).

### IN-02: [CHANGED] development artifact comment in isTrivialBattle

**File:** `classes/druid/Druid.lua:823`
**Issue:** The comment `-- [CHANGED] ^^^ 500 replaced with estimatePlayerDPS() call` is a transient development marker. It describes what changed during implementation rather than what the code does or why. This provides no ongoing value -- future maintainers will never see the old `500` literal and won't understand what "changed" means. The project conventions use `[D-01]` / `[D-02]` style annotations that describe intent, not change history.

**Fix:** Replace with a stable intent comment or remove:
```lua
-- [D-01] Per-player DPS estimate from level-adaptive lookup
```

---

_Reviewed: 2026-06-20T03:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_