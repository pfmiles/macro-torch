---
status: testing
phase: 08-druid-druid
source: [08-VERIFICATION.md]
started: 2026-06-15T12:30:00Z
updated: 2026-06-15T12:30:00Z
---

## Current Test

number: 1
name: In-game SelfTest validation for all 6 classes
expected: |
  Log into game as each of the 6 classes (Hunter, Warrior, Rogue, Mage, Priest, Warlock) and verify SelfTest output in chat frame.
  For each class, all SelfTest registrations pass (FIELD_FUNC_MAP, singleton existence, registry entry, individual skill method existence).
  Only the summary line appears for passing tests. No red (error) or yellow (warning) output for registered class tests.
awaiting: user response

## Tests

### 1. Rogue English skill name verification
expected: All 7 English names (Pick Pocket, Ghostly Strike, Hemorrhage, Sinister Strike, Backstab, Vanish, Preparation) match actual Turtle WoW 1.12.1 English client spell names
result: approved (verified during 08-02 checkpoint execution, 2026-06-15)

### 2. In-game SelfTest validation
expected: Log in as each of the 6 classes (Hunter, Warrior, Rogue, Mage, Priest, Warlock) and verify SelfTest output shows all passing
result: [pending]

### 3. build_order.txt file path spot-check
expected: All 19 non-comment class file paths resolve to existing files. build.sh strict mode already enforces this.
result: passed (build.sh succeeds, exit 0)

## Summary

total: 3
passed: 2
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps