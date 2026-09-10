# Deferred Items — Phase 30 (out-of-scope discoveries, not fixed)

Recorded by the 30-01 executor per the deviation-rule scope boundary (do not
auto-fix pre-existing issues unrelated to the current task).

## 1. Duplicate phase-05 directory normalization warning

- **Where seen:** every `gsd-tools` state/roadmap verb during 30-01 execution.
- **Issue:** `.planning/phases/` contains both `05` and `05-druid-player-cast-druid`,
  which normalize to the same phase key '05' (#3355 warning; the tool keeps `05` by
  deterministic lexicographic order).
- **Why deferred:** pre-existing directory layout from earlier phases, outside this
  plan's file set (classes/druid/Druid.lua, core/events.lua). Self-healing the phase
  directory during plan execution risks invalidating prior-phase references.
- **Suggested owner:** a cleanup phase or `/gsd-health`.

## 2. Local grep is ugrep

- **Issue:** the local `grep` resolves to ugrep, which rejects POSIX BRE
  backslash-plus escapes (`'^\+\+\+'`) that Task 1's plan-level verify uses verbatim.
- **Handling:** task-level gate re-run with an equivalent awk filter, same semantics
  and result (documented in 30-01-SUMMARY.md "Issues Encountered"); no plan change.
- **Why deferred:** environment-specific tooling; the plan's gate semantics were
  preserved. Future plans whose verify blocks use `grep -v '^\+...'` idioms may hit
  the same wall and should prefer awk.