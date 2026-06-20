---
status: testing
phase: 14-istrivialbattle-iskillshotorlastchance-60-dps-b
source: [14-VERIFICATION.md]
started: 2026-06-20T10:55:00+08:00
updated: 2026-06-20T10:55:00+08:00
---

## Current Test

number: 1
name: Run /mt — all 6 Category I selftests should pass green
expected: |
  Load the addon in WoW on a Druid character.
  Run `/mt` to execute all selftests.
  Category I tests (DPS/KS level-adaptive) should all pass with green output.
  Total selftest count should be 24 (was 18 before Phase 14).
awaiting: user response

## Tests

### 1. Category I Selftests pass in-game
expected: Run `/mt` on a Druid — all 6 Category I tests pass green
result: [pending]

### 2. Level-60 behavior regression check
expected: On a level 60 Druid, catAtk behavior is identical to pre-Phase-14. estimatePlayerDPS(60) = 500, getKSThreshold(60) = 1750, quick battle and kill shot detection trigger at same thresholds as before.
result: [pending]

### 3. Level-adaptive threshold testing (levels 30-40)
expected: On a level 30-40 Druid, quick battle detection triggers for appropriate low-health targets (not all green mobs). Kill shot threshold scales with level.
result: [pending]

### 4. KS_CP constants deletion in global namespace
expected: Run `/run print(macroTorch.KS_CP1_Health)` in-game — should print `nil`. No KS_CP* constants in the global namespace.
result: [pending]

### 5. isTrivialBattle condition B runtime (levels 10-59)
expected: isTrivialBattle condition B uses level-scaled DPS estimate. At level 30, trivial detection uses 120 DPS instead of 500.
result: [pending]

### 6. isKillShotOrLastChance condition B runtime (levels 10-59)
expected: isKillShotOrLastChance condition B uses single getKSThreshold() call. At level 30, threshold is 700 instead of level-60's 1750.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps