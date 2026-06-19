---
status: testing
phase: 13-catatk-60-dps
source: [13-VERIFICATION.md]
started: 2026-06-20T01:35:00+08:00
updated: 2026-06-20T01:35:00+08:00
---

## Current Test

number: 1
name: Level 60 DPS Equivalence
expected: |
  RESHIFT_ENERGY = 60. All isSpellExist guards pass through (all skills available at 60). 
  DPS indistinguishable from pre-change baseline over 5+ minutes on target dummy.
awaiting: user response

## Tests

### 1. Level 60 DPS Equivalence
expected: Log into WoW with level 60 Druid (5/5 Furor, Wolfshead Helm, all cat skills learned). Test catAtk() DPS against target dummy for 5+ minutes and compare with pre-change baseline.
result: [pending]

### 2. Low-Level Druid (Level 10-15)
expected: Log in with a low-level Druid that only has Claw. Execute catAtk() in cat form against enemies. No Lua errors, only Claw used, reshift never fires.
result: [pending]

### 3. Mid-Level Druid (Level 20-30)
expected: Log in with a mid-level Druid that has some but not all cat skills (e.g., has Rip and Rake, but no Shred, no Ferocious Bite). Available skills used, unavailable ones skipped. shouldUseShred returns false → Claw used. No errors.
result: [pending]

### 4. Dynamic RESHIFT_ENERGY Selftest
expected: On any Druid, observe selftest output on login (Category H). computeReshiftEnergy debug log shows correct Furor rank and Wolfshead Helm status. Value between 0-100. No assertion failures.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps