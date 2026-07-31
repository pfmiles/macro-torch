---
status: complete
---

# Summary

## Changes applied

1. **`classes/druid/cat.lua`** — `shouldDoReshift`:
   - Added `effectiveEnergy` computation (RESHIFT_ENERGY - TIGER_E when Tiger present)
   - Added `effectiveEnergy > currentEnergy` condition to return
   - Added reshift economics comment block

2. **`classes/druid/Druid.lua`** — 3 comment additions:
   - `getNextAbilityCost`: Tiger cost not included, callers must deduct for shapeshift decisions
   - `computeReshiftEnergy`: returns raw value, Tiger cost deducted by caller
   - `tigerSelfGCD`: clarifies internal CD, not global GCD

3. **`classes/druid/selftest.lua`** — test updates:
   - R2-07: RESHIFT_ENERGY 40→60, added earning guard skip
   - R2-08: new test for earning <= 0 → no reshift

## Verification

- All 3 modified files pass `luac -p` syntax check
- R2-07 still validates the "should reshift" path (with BiS-appropriate values)
- R2-08 validates the new guard (non-BiS: RESHIFT_ENERGY=40, earning <= 0)