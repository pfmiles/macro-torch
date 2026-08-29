---
status: testing
phase: 27-catatk-event-driven-land-tracing-refactor
source: [27-VERIFICATION.md]
started: 2026-08-29T00:00:00Z
updated: 2026-08-29T01:40:00Z
---

## Current Test

number: 1
name: In-game selftest run (Category Q green, incl. Q-10) + dummy-fight smoke test of event-driven Renewing lines
expected: |
  On the game machine: pull the repo → Cygwin `bash build.sh` → `/reload`.
  Within ~0.5s of entering the world the SelfTest suite auto-runs; all 10
  Category Q tests (Q-01..Q-10) report green, including:
    - Q-10 (FB land event renews Rake and Rip with the numeric event time) —
      green, proving the CR-01 listener-signature fix works end to end.
  Zero `[RAWDIAG]` / `[DIAG]` output anywhere.
  Then a dummy-fight smoke run with Rip/Rake/Ferocious Bite: Rip/Pounce land via
  aura-apply (RAW `is afflicted by` pairing), and each landed FB hit immediately
  prints the event-driven `Renewing rake... left:` / `Renewing rip... left:`
  lines and restarts the self-reported clocks (no 0.1s-poll / CP-condition
  involvement). catAtk must not crash (no "attempt to perform arithmetic on a
  string value").
awaiting: user response (deferred by user: in-game testing postponed until all
development-side close-out work is complete; UAT runs as the final step)

## Tests

### 1. Category Q selftests green in-game (Q-01..Q-10)
expected: All 10 Category Q tests green on /mt (auto-run at world enter); Q-10 green proves the renewal listener receives the numeric event time; zero [RAWDIAG]/[DIAG] output.
result: [pending]

### 2. Dummy-fight smoke: event-driven land + renewal
expected: Rip/Pounce land via aura-apply pairing; landed FB hits emit Renewing lines driven by hit events (not polling); clocks restart from FB event time; no Lua arithmetic errors on the catAtk hot path.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps