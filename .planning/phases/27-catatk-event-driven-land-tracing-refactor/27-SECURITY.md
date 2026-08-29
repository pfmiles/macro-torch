---
phase: 27
slug: catatk-event-driven-land-tracing-refactor
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-29
---

# Phase 27 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| WoW combat log → addon | RAW_COMBATLOG carries every nearby unit's combat lines (untrusted text, huge volume); CHAT_MSG_SPELL_SELF_DAMAGE carries the client-filtered own-cast lines (semi-trusted, self-owned) | raw text lines, no structured payload |
| addon state | loginContext / intentTable / landTable — only addon code writes; consumers are druid self-reported clocks (ripLeft/rakeLeft) and immune tracing | timestamps, spell names, guid strings |
| Client chat/Raw events → druid integration | FB hit/crit lines (self-owned) and RAW apply lines (target-owned, paired with cast intents) drive the renewal listener | spell names + event timestamps |
| selftest execution environment | Tests run inside the user's live client session at /mt; a leaked stub or mutated global outlives the test run (Phase 26 P-02/CR-01 precedent: session-wide freeze) | plain-table stubs, restored by raw assignment |
| verification commands | Repo-local node script (bbcheck.js, committed planning artifact) and build.sh — simple, reviewable, no network | none (local disk only) |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-27-01 | Spoofing | processRawAuraApply intent pairing | medium | mitigate | Land requires pairing with our own unconsumed cast intent (created only by recordCastTable from the cast bridge) AND a case-insensitive current-target guid match | closed |
| T-27-02 | Tampering | RAW_COMBATLOG untrusted text parsing | low | mitigate | String-only pattern matching (string.find/string.sub/string.lower); no loadstring/eval; malformed lines return nil harmlessly | closed |
| T-27-03 | DoS | RAW_COMBATLOG event flood | medium | mitigate | Three-tier filter: channel whitelist (2 channels) → O(N) precompiled-pattern string.find (N = registered aura-apply spells, ≤4) → zero allocation/logging on the hot path | closed |
| T-27-04 | Information Disclosure | diagnostic persistence to SavedVariables | low | accept | Recon scout (which bulk-logged raw combat lines) deleted in 27-01; production handler logs nothing | closed |
| T-27-05 | Spoofing | FB renewal rewriting Rip/Rake land | medium | mitigate | Renewal fires only on the client's own 'Your Ferocious Bite hits/crits' line (self-owned channel) and is gated by isRipPresent/isRakePresent (same hasBuff + clock authority as before); the hit event is stronger proof than CP>0 | closed |
| T-27-06 | Tampering | renewal listener mutates loginContext landTable | low | accept | Listener runs only on own-cast events; writes are timestamp pushes to per-spell stacks consumed by the same clock code | closed |
| T-27-07 | Tampering | selftest stubs polluting live session state | high | mitigate | Compute-into-locals + restore-globals-before-assert (CR-01) in every stubbed Category Q test; framework pcall-wraps each test; no test writes real registries; verified line-by-line by phase verification and code review | closed |
| T-27-08 | Spoofing | verification gates gamed by stale artifacts | low | mitigate | bbcheck regenerates SM_Extend.lua before greps; leftover sweep targets code identifiers; independent greps for 4-arg string.find/goto | closed |
| T-27-SC | Tampering | npm/pip/cargo installs | n/a | accept | No package installs in this phase; bbcheck.js uses the repo's existing node runtime only (appears identically in all three plans) | closed |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-01 | T-27-04 | Diagnostic persistence removed; accept covers the residual window in which the scout existed in history | planner threat model | 2026-08-29 |
| R-02 | T-27-06 | Listener operates on own-cast events only; access follows the existing landTable trust relationship | planner threat model | 2026-08-29 |
| R-03 | T-27-SC | Zero package installs; node runtime already present | planner threat model | 2026-08-29 |
| R-04 | WR-02 (code review) | Same-window allied-Rip apply may pair with our pending intent (≤2s land offset) in multi-feral scenarios; accepted design trade-off from the debug session — fail-wins covers the failure path, silent-apply-suppression residual risk accepted | developer design decision #2/#6 | 2026-08-29 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-29 | 9 | 9 | 0 | gsd-secure-phase (orchestrator; L1 short-circuit per ASVS-1 rule) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-29