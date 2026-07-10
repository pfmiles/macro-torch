---
status: testing
phase: 20-spell-id-auto-correct-spellid
source: [20-VERIFICATION.md]
started: 2026-07-11T02:55:00Z
updated: 2026-07-11T02:55:00Z
---

## Current Test

number: 1
name: N1-N5 selftest verification via /mt in-game
expected: |
  All 5 Category N selftests produce no FAIL or WARN messages; summary shows them as passed.
awaiting: user response

## Tests

### 1. N1-N5 selftest verification via /mt in-game
expected: All 5 Category N selftests produce no FAIL or WARN messages; summary shows them as passed.
result: [pending]

### 2. SPELL_ID_AUTO_CORRECT = false full-path verification
expected: With switch off: casts produce no current_casting_spell bridge, no stale detection warnings, no spellId correction messages, resolveSpellId returns static SPELL_NAME_TO_ID values, loadSpellIdMap skips. recordCastTable still tracks land events.
result: [pending]

### 3. SPELL_ID_AUTO_CORRECT = true backward compatibility
expected: With switch on (default): all spellId auto-correction operates exactly as before Phase 20. No functional regression.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps