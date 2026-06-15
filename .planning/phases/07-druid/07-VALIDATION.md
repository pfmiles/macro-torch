---
phase: 07
slug: druid
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-15
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | SelfTest (built-in Lua), grep assertions, build.sh |
| **Config file** | core/selftest.lua |
| **Quick run command** | `./build.sh && grep -c "SelfTest:register" SM_Extend.lua` |
| **Full suite command** | `./build.sh && echo "Build OK"` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh`
- **After every plan wave:** Run full grep verification suite
- **Before `/gsd-verify-work`:** Full build + all grep assertions must pass
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | D-01,D-02,D-03 | N/A | N/A | grep | `grep "DRUID_FIELD_FUNC_MAP\[.isInCatForm.\]" classes/druid/Druid.lua` | ✅ | ⬜ pending |
| 07-01-02 | 01 | 1 | D-04 | N/A | N/A | grep | `grep -c "isFormActive.*Form" classes/druid/Druid.lua classes/druid/bear.lua classes/druid/utility.lua` | ✅ | ⬜ pending |
| 07-01-03 | 01 | 1 | D-03 | N/A | N/A | grep | `grep "SelfTest:register.*isInCatForm\|SelfTest:register.*isInBearForm" classes/druid/Druid.lua` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Existing infrastructure covers all phase requirements (SelfTest framework from Phase 3, build.sh from Phase 1)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| isInCatForm returns true in Cat Form | D-01 | WoW API requires in-game client | Login Druid, shift to Cat Form, verify `/mt` output shows isInCatForm=true |
| isInBearForm returns true in Dire Bear Form | D-02 | WoW API requires in-game client | Login Druid (level 40+), shift to Dire Bear Form, verify isInBearForm=true |
| isInBearForm returns true in Bear Form | D-02 | WoW API requires in-game client | Login Druid (level 10-39), shift to Bear Form, verify isInBearForm=true |
| catAtk rotation still works | D-04 | Combat logic requires in-game testing | Press cat macro keybind, verify rotation executes normally |
| bearAtk rotation still works | D-04 | Combat logic requires in-game testing | Press bear macro keybind, verify rotation executes normally |

---

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending