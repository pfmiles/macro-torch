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
  prints the event-driven `Renewing rake... left: ...` / `Renewing rip... left: ...`
  lines and restarts the self-reported clocks (no 0.1s-poll / CP-condition
  involvement). catAtk must not crash (no "attempt to perform arithmetic on a
  string value").

  Renewing-line payload (2026-08-30 user request): each Renewing line now also
  prints `expDuration: <N>s` — the expected full duration of the refreshed bleed
  computed from the cast-time snapshot only (write-once CP count and Savagery
  idol state, decision #4). At 5cp the value must be 16.2s when the ORIGINAL
  cast wore the Savagery idol, 18s when it did not — this is the snapshot
  inheritance the user verifies live.

  Cast-log payload (2026-08-30 user request): the `Rip!!!` / `Rake!!!` /
  `Pounce!!!` cast logs now also print `expDuration: <N>s` computed from LIVE
  cast-moment state (current CP + currently equipped idol) — what the server
  snapshots when the fresh cast lands, not the previous cast's snapshot.

  Land-feedback restore (2026-08-30, post-review user request): each genuine
  landing of a traced spell prints a green `<spell> cast on <mob> landed:
  <time>` line (Rake/FB via self-hit, Rip/Pounce via aura-apply pairing); a
  late fail that revokes such a landing prints a red `<spell> land on <mob>
  was cancelled by <failType>` line. No green line may appear for FB-driven
  Rake/Rip renewals (renewals are rewrites, not landings), and no `[DIAG]` /
  `[RAWDIAG]` / `init step` output anywhere.
awaiting: user response (deferred by user: in-game testing postponed until all
development-side close-out work is complete; UAT runs as the final step)

## Tests

### 1. Category Q selftests green in-game (Q-01..Q-10)
expected: All 10 Category Q tests green on /mt (auto-run at world enter); Q-10 green proves the renewal listener receives the numeric event time; zero [RAWDIAG]/[DIAG] output.
result: [pending]

### 2. Dummy-fight smoke: event-driven land + renewal
expected: Rip/Pounce land via aura-apply pairing; landed FB hits emit Renewing lines driven by hit events (not polling); clocks restart from FB event time; no Lua arithmetic errors on the catAtk hot path. Renewing lines carry `expDuration: <N>s` from the cast-time snapshot (16.2s with original-cast Savagery at 5cp, else 18s). Cast logs (`Rip!!!`/`Rake!!!`/`Pounce!!!`) carry `expDuration: <N>s` from live cast-moment state. Additionally, each genuine traced-spell landing prints a green `cast on ... landed:` line, fail-revoked landings print a red `was cancelled by ...` line, and no green line appears for FB-driven renewals.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps