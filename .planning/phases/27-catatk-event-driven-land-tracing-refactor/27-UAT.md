---
status: complete
phase: 27-catatk-event-driven-land-tracing-refactor
source: [27-VERIFICATION.md]
started: 2026-08-29T00:00:00Z
updated: 2026-08-30T03:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Category Q selftests green in-game (Q-01..Q-10)
expected: All 10 Category Q tests green on /mt (auto-run at world enter); Q-10 green proves the renewal listener receives the numeric event time; zero [RAWDIAG]/[DIAG] output.
result: pass

### 2. Dummy-fight smoke: event-driven land + renewal
expected: Rip/Pounce land via aura-apply pairing; landed FB hits emit Renewing lines driven by hit events (not polling); clocks restart from FB event time; no Lua arithmetic errors on the catAtk hot path. Renewing lines carry `expDuration: <N>s` from the cast-time snapshot (16.2s with original-cast Savagery at 5cp, else 18s). Cast logs (`Rip!!!`/`Rake!!!`/`Pounce!!!`) carry `expDuration: <N>s` from live cast-moment state. Additionally, each genuine traced-spell landing prints a green `cast on ... landed:` line, fail-revoked landings print a red `was cancelled by ...` line, and no green line appears for FB-driven renewals.
result: pass

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps