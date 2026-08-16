---
status: testing
phase: 24-unit-spellcast-succeeded-unit-castevent-cast-spellid
source: [24-VERIFICATION.md]
started: 2026-08-17
updated: 2026-08-17
---

## Current Test

number: 1
name: UNIT_SPELLCAST_SUCCEEDED event fires and records
expected: |
  recordCastTable receives the spellName string (not a spellId number). The castTable entry is populated.
awaiting: user response

## Tests

### 1. UNIT_SPELLCAST_SUCCEEDED event fires and records
expected: Cast any land-tracing spell (e.g. Rake) on a target mob and verify via debug that recordCastTable is called with the correct spellName string (not a spellId number).
result: [pending]

### 2. recordCastTable deduplication
expected: Cast a land-tracing spell rapidly (within 0.2s) on the same target and verify only one cast record is pushed, not two. Only one entry in castTable for that spell+mob combination despite two rapid casts.
result: [pending]

### 3. All 4 Druid land-tracing spells register and record
expected: Cast each of Pounce, Rake, Rip, Ferocious Bite on a target mob and verify each spell's cast is recorded in castTable with the correct spellName as key.
result: [pending]

### 4. Self-test Category K and N pass
expected: In-game, type /mt and verify that all Category K (5 tests) and Category N (4 tests) pass without assertion failures.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps