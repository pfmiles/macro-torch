---
phase: 16
slug: catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-22
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | macroTorch.SelfTest (custom WoW addon test framework) |
| **Config file** | none — inline registrations in `core/selftest.lua` |
| **Quick run command** | In-game only: login as Druid, observe `[macro-torch] Self-test:` chat output |
| **Full suite command** | Same as quick run — all tests execute on PLAYER_ENTERING_WORLD |
| **Estimated runtime** | ~2 seconds (runs on login) |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh && echo "Build OK"` (Lua syntax check via build)
- **After every plan wave:** In-game login as Druid, verify SelfTest output
- **Before `/gsd-verify-work`:** Full suite must be green (all catLeveling tests pass in-game)
- **Max feedback latency:** ~60 seconds (game login + test execution)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-T01 | 01 | 1 | REQ-16-01 | N/A | N/A | unit | SelfTest:register in core/selftest.lua | ❌ W0 | ⬜ pending |
| 16-T02 | 01 | 1 | REQ-16-02 | N/A | N/A | manual | In-game Druid login, test across levels | N/A | ⬜ pending |
| 16-T03 | 01 | 1 | REQ-16-03 | N/A | N/A | unit | SelfTest:register in core/selftest.lua | ❌ W0 | ⬜ pending |
| 16-T04 | 01 | 1 | REQ-16-04 | N/A | N/A | unit | SelfTest:register in core/selftest.lua | ❌ W0 | ⬜ pending |
| 16-T05 | 01 | 1 | REQ-16-05 | N/A | N/A | unit | SelfTest:register in core/selftest.lua | ❌ W0 | ⬜ pending |
| 16-T06 | 01 | 1 | REQ-16-06 | N/A | N/A | unit | SelfTest:register in core/selftest.lua | ❌ W0 | ⬜ pending |
| 16-T07 | 01 | 1 | REQ-16-07 | N/A | N/A | unit | SelfTest:register in core/selftest.lua | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `core/selftest.lua` — new catLeveling test registrations (5+ tests)
- [ ] Selftest for `catLeveling` function existence with Druid class guard
- [ ] Selftest for isSpellExist guard behavior at module entry points
- [ ] Selftest verifying shared functions are not locally redefined in leveling.lua
- [ ] Selftest for catAtk unchanged (function body comparison)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mid-cycle module priority ordering | REQ-16-02 | Requires real combat with varying target HP/level | Login as leveling Druid, test 10+ combats across level ranges, verify TF→Rip→Rake→FF→Builder priority |
| Build system integrity | REQ-16-07 | Build.sh must produce valid output | Run `./build.sh && grep "function macroTorch.catLeveling" SM_Extend.lua` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending