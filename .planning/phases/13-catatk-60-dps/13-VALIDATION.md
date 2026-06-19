---
phase: 13
slug: catatk-60-dps
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-20
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> WoW 1.12.1 Lua addon — validation via SelfTest framework, build verification, and in-game manual testing.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | macroTorch.SelfTest (core/selftest.lua) — in-game Lua self-test framework |
| **Config file** | none |
| **Quick run command** | `./build.sh && echo "Build OK"` |
| **Full suite command** | In-game: `/mt` SLASH command triggers `SelfTest:run()` on PLAYER_ENTERING_WORLD |
| **Estimated runtime** | ~10 seconds (build + in-game selftest) |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh` to verify concat success
- **After every plan wave:** Run `./build.sh` + grep-based symbol verification (see plan acceptance criteria)
- **Before `/gsd-verify-work`:** Full build + selftest grep audit must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | R8-PRESERVE | N/A | Guard no-op at lvl 60 | self-test | `./build.sh && grep "SelfTest:register" SM_Extend.lua` | — | ⬜ pending |
| TBD | TBD | TBD | LOW-LVL-SKIP | N/A | Module skip on missing spell | self-test | `./build.sh` | — | ⬜ pending |
| TBD | TBD | TBD | DYNAMIC-RESHIFT | N/A | computeReshiftEnergy() correct | self-test | `grep "computeReshiftEnergy" SM_Extend.lua` | — | ⬜ pending |
| TBD | TBD | TBD | DECISION-GUARD | N/A | Shared funcs return false on missing spell | self-test | `./build.sh` | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `core/selftest.lua` — existing SelfTest framework (no stubs needed; Phase 3 already established)
- [ ] `biz_util.lua` — `macroTorch.isSpellExist` already exists and tested
- [ ] `entity/Player.lua` — `talentRank`, `isItemEquipped` already exist and tested

Existing infrastructure covers all phase requirements. No new test framework installation required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Low-level catAtk rotation (lvl 10-49) | LOW-LVL-SKIP | Requires low-level Druid character on Turtle WoW | Create/use low-level Druid, bind catAtk macro, verify skill modules skip gracefully |
| Level 60 DPS unchanged | R8-PRESERVE | Requires level 60 Druid with full talents | Run catAtk on level 60 target dummy, compare DPS before/after change |
| RESHIFT_ENERGY dynamic with Furor + Wolfshead | DYNAMIC-RESHIFT | Requires specific talent/gear combos | Test reshift behavior with 0/5, 3/5, 5/5 Furor; with and without Wolfshead Helm |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending