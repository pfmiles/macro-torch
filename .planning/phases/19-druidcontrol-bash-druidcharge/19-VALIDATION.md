---
phase: 19
slug: druidcontrol-bash-druidcharge
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-08
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | SelfTest:register() + build.sh + in-game HUMAN-UAT |
| **Config file** | none — no test framework for WoW Lua addons |
| **Quick run command** | `./build.sh && echo "Build OK"` |
| **Full suite command** | `grep -c "SelfTest:register" SM_Extend.lua && ./build.sh` |
| **Estimated runtime** | ~2 seconds (build only; in-game tests require WoW client) |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh`
- **After every plan wave:** Run `./build.sh` + verify SelfTest registration count
- **Before `/gsd-verify-work`:** Build must pass + HUMAN-UAT checklist run in-game
- **Max feedback latency:** 5 seconds (build verification)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-{XX}-01 | 01 | 1 | D-01,D-02,D-03,D-04,D-05 | — | N/A | source | `grep "function macroTorch.druidCharge" classes/druid/combo.lua` | ⬜ pending | ⬜ pending |
| 19-{XX}-02 | 01 | 1 | D-06,D-07,D-08 | — | N/A | source | `grep "target.distance < 8" classes/druid/combo.lua` (expect 0 in druidControl) | ⬜ pending | ⬜ pending |
| 19-{XX}-03 | 01-02 | 1-2 | D-04, Claude's Discretion | — | N/A | source | `grep -c "SelfTest:register" core/selftest.lua` (Category M increase) | ⬜ pending | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Existing SelfTest infrastructure in `core/selftest.lua` covers all phase requirements
- [ ] `./build.sh` strict mode already active (Phase 4)

*Existing infrastructure covers all phase requirements. No new test framework installation needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| druidCharge in-game: bear form auto-switch | D-03 | WoW client required | Press druidCharge keybind while in caster/cat form — verify auto-switches to bear form and returns |
| druidCharge in-game: >=8 yards Feral Charge | D-02 | WoW client required | Target dummy at 8-25 yards, press druidCharge — verify Feral Charge cast |
| druidCharge in-game: <8 yards Bash | D-02 | WoW client required | Target dummy at melee range, press druidCharge — verify Bash cast |
| druidControl in-game: Bash branch removed | D-06 | WoW client required | Target dummy at melee range, press druidControl — verify Bash NOT cast (Hibernate/Entangling Roots instead) |
| druidCharge in-game: low level isSpellExist guard | D-04 | WoW client required | Low level druid without Bash/Feral Charge — verify no Lua errors, silent return |
| Build verification | All | CI/local | `./build.sh && echo "Build OK"` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending