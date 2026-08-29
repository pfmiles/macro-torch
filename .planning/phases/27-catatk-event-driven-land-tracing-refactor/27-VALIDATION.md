---
phase: 27
slug: catatk-event-driven-land-tracing-refactor
status: validated
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-29
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | repo-native static battery + in-game SelfTest framework (no Lua interpreter / CI locally) |
| **Config file** | none (bbcheck.js is a committed planning tool; SelfTest framework in core/selftest.lua) |
| **Quick run command** | `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js <files>; git diff --check` |
| **Full suite command** | `bash build.sh` + leftover sweep (`git grep -E 'maintainLandTables|computeLandTable|consumeDruidBattleEvents|RAWDIAG|_rawScout|_diag...' -- '*.lua'`) + Lua 5.0 audit; in-game `/mt` SelfTest run on the game machine |
| **Estimated runtime** | ~30 s static; ~2 min in-game |

---

## Sampling Rate

- **After every task commit:** bbcheck.js on the task's files + `git diff --check` (executed green by all three plan executors)
- **After every plan wave:** full static battery (bbcheck ×7, build.sh, sweep, scope, fidelity) — executed green after waves 1/2/3 and after the CR-01/V-01 fix commits
- **Before `/gsd-verify-work`:** static battery green (confirmed); in-game Category Q run pending (user-deferred UAT)
- **Max feedback latency:** seconds (static); one game session (in-game)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 27-01-02 | 01 | 1 | intent machine + landSource registry + fail revocation (truths #3/#4/#5/#6) | T-27-01 / T-27-02 | pairing + guid ownership; string-only parsing | static + selftest | `bbcheck.js core/spell_trace_core.lua core/periodic.lua`; Q-02..Q-06 at /mt | ✅ (static green; Q pending in-game) | ✅ green |
| 27-01-03 | 01 | 1 | three-tier RAW handler + self-hit dispatch (truths #5/#6/#8) | T-27-03 / T-27-04 | whitelist + no logging; own-cast prefix | static + selftest | `bbcheck.js core/events.lua`; grep gates; Q-01/Q-07 at /mt | ✅ (static green; Q pending in-game) | ✅ green |
| 27-02-01 | 02 | 2 | aura-apply registrations + FB listener (truths #1/#2/#3) | T-27-05 | presence-gated renewal; snapshot read-only | static + selftest | `bbcheck.js classes/druid/Druid.lua`; grep gates; Q-01/Q-08/Q-10 at /mt | ✅ (static green; Q pending in-game) | ✅ green |
| 27-02-02 | 02 | 2 | druid-side deletions + fidelity (truths #4/#5/#6) | — | isRipPresent byte-fidelity; no diag identifiers | static | diff vs HEAD; leftover sweep | ✅ | ✅ green |
| 27-02-03 | 02 | 2 | Hunter Sting migration (truth #1) | — | behavior-preserving landSource | static | `bbcheck.js classes/hunter/Hunter.lua`; build.sh | ✅ | ✅ green |
| 27-03-01 | 03 | 3 | Category Q registrations (truths #1/#2) | T-27-07 | CR-01 restore-before-assert; no registry writes | static + selftest | `bbcheck.js classes/druid/selftest.lua`; grep -c 'Cat Q-0' = 10 | ✅ | ✅ green |
| 27-03-02 | 03 | 3 | phase battery (truths #3/#4/#5) | T-27-08 | regenerated artifact before greps | static | full battery → BATTERY_FAIL=0 | ✅ | ✅ green |
| 27-01-01 | 01 | 1 | deletion authorization (checkpoint) | — | user decision option-a | decision gate | recorded in SUMMARY + STATE | ✅ | ✅ green |

*Status: ✅ green · ❌ red · ⚠️ flaky · ⬜ pending*
*The in-game `/mt` SelfTest execution for Q-01..Q-10 is the repo's only runtime-verifiable layer; user deferred it to end-of-implementation UAT (27-UAT.md). Static proofs for the same behaviors are all green — REVIEW.md verified line-by-line.*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements: bbcheck.js (committed in the phase dir) + build.sh + grep/diff gates + the in-game SelfTest framework from prior phases. No new test framework needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| In-game Category Q run (Q-01..Q-10 green, incl. Q-10 numeric-time renewal) | truths (behavioral verification of 27-01/27-02/27-03) | No Lua interpreter locally; SelfTest runs inside the WoW 1.12 client only | Game machine: pull → Cygwin build.sh → /reload → observe /mt results. Deferred by user to post-implementation UAT (27-UAT.md) |
| Dummy-fight smoke: event-driven Renewing lines + no arithmetic errors on catAtk hot path | FB renewal behavior (27-02 truth #2) | Requires live combat events on the game machine | Dummy fight with Rip/Rake/FB; observe Renewing lines on each landed FB hit. Deferred by user to post-implementation UAT (27-UAT.md) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify (static battery ran green per task and phase-wide)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none missing)
- [x] No watch-mode flags
- [x] Feedback latency within static bounds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-29 (in-game execution deferred by user to final UAT)