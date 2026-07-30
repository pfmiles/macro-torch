---
status: testing
phase: 22-catatk-selftest-catatk-core-principles-md-d
source: [22-VERIFICATION.md]
started: 2026-07-31T00:00:00Z
updated: 2026-07-31T00:00:00Z
---

## Current Test

number: 1
name: In-Game /mt execution — all 43 tests load without errors
expected: |
  All 43 Principle PF-xx / Rxx-xx tests appear in chat output. Tests with unmet preconditions silently skip (Pattern C). No Lua errors.
awaiting: user response

## Tests

### 1. In-Game /mt execution — all 43 tests load without errors
expected: All 43 Principle PF-xx / Rxx-xx tests appear in chat output. Tests with unmet preconditions silently skip (Pattern C). No Lua errors.
result: [pending]

### 2. PF-01~03 Conditional Skip — different Furor/Wolfsheart combos
expected: PF-01 asserts ==0 when Furor=0+no Wolfsheart. PF-02 asserts ==60 when Furor=5+Wolfsheart. PF-03 asserts ==24 when Furor=3+no Wolfsheart. All skip when preconditions not met.
result: [pending]

### 3. R2-06/R2-07 Complementarity — energy-level-dependent reshift
expected: Exactly ONE of R2-06 or R2-07 asserts per run based on player.mana. Both eventually assert across multiple runs.
result: [pending]

### 4. R8-05/R8-06 Complementarity — energy-level-dependent FF fill
expected: Exactly ONE of R8-05 or R8-06 asserts per run based on player.mana. Both eventually assert across multiple runs.
result: [pending]

### 5. Build Order Integrity — no "attempt to call nil" errors in game
expected: No nil-reference errors for macroTorch.shouldDoReshift, computeErps, etc. All 43 tests reference defined functions.
result: [pending]

### 6. Documentation D-09 fix — isPseudoInfiniteEnergy naming
expected: catAtk-core-principles.md Appendix D Rule 13 reads isPseudoInfiniteEnergy. No isInfiniteEnergy occurrences remain.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps