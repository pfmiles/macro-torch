---
phase: 10
slug: 5-druid-druidatk-druidaoe-druidheal-druiddefend-druidcontrol
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-16
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | WoW In-Game Manual Testing + selftest.lua |
| **Config file** | `core/selftest.lua` — existing self-test framework |
| **Quick run command** | `./build.sh && (in-game /macro-torch-selftest)` |
| **Full suite command** | Manual in-game verification of all 5 combo methods + regression check on catAtk/bearAtk |
| **Estimated runtime** | ~300 seconds (in-game) |

---

## Sampling Rate

- **After every task commit:** `./build.sh` (build verification only)
- **After every plan wave:** In-game manual test of affected combo method(s)
- **Before `/gsd-verify-work`:** Full in-game test of all 5 combo methods
- **Max feedback latency:** Build verification < 30s; in-game depends on developer availability

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | D-01/D-03/D-04 | N/A | N/A | manual-in-game | `./build.sh` | combo.lua | ⬜ pending |
| 10-01-02 | 01 | 1 | D-06/D-07/D-08 | N/A | N/A | manual-in-game | `./build.sh` | combo.lua | ⬜ pending |
| 10-01-03 | 01 | 1 | D-09/D-10/D-11/D-12 | N/A | N/A | manual-in-game | `./build.sh` | combo.lua | ⬜ pending |
| 10-01-04 | 01 | 1 | D-13/D-14/D-15 | N/A | N/A | manual-in-game | `./build.sh` | combo.lua | ⬜ pending |
| 10-01-05 | 01 | 1 | D-16/D-17/D-18 | N/A | N/A | manual-in-game | `./build.sh` | combo.lua | ⬜ pending |
| 10-02-01 | 02 | 1 | D-05 | N/A | N/A | manual-in-game | `./build.sh` | Druid.lua | ⬜ pending |
| 10-02-02 | 02 | 1 | D-17 | N/A | N/A | manual-in-game | `./build.sh` | utility.lua | ⬜ pending |
| 10-02-03 | 02 | 1 | D-20 | N/A | N/A | build | `./build.sh` | build_order.txt | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Existing `core/selftest.lua` framework already covers integration testing patterns
- [ ] `build.sh` is functional (build verification baseline)
- [ ] Existing `impl_util.lua` provides `tableLen()` and other utilities

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| druidAtk cat routing | D-03 | No WoW API simulation env | In cat form, press macro bound to druidAtk → verify catAtk executes |
| druidAtk bear routing | D-03 | No WoW API simulation env | In bear form, press macro bound to druidAtk → verify bearAtk executes |
| druidAoe bear routing | D-06 | No WoW API simulation env | In bear form with multiple targets → verify bearAoe executes |
| druidAoe caster Hurricane | D-06/D-07 | No WoW API simulation env | In caster form → verify Hurricane channels |
| druidHeal form cancel step | D-09 | No WoW API simulation env | In cat form, press druidHeal → verify form cancelled, second press → HOT applies |
| druidHeal HOT logic | D-09 | No WoW API simulation env | In caster form with < 50% HP → verify Rejuvenation casts on self |
| druidDefend Barkskin | D-14 | No WoW API simulation env | Press druidDefend → verify Barkskin casts (any form) |
| druidDefend Frenzied Regen | D-14 | No WoW API simulation env | Press druidDefend with Barkskin on CD → verify bear form switch + FR |
| druidControl Bash | D-16 | No WoW API simulation env | In bear form, melee range, press druidControl → verify Bash |
| druidControl Feral Charge | D-16 | No WoW API simulation env | In bear form, ranged, press druidControl → verify Feral Charge |
| druidControl Hibernate | D-16 | No WoW API simulation env | In caster form vs beast target → verify Hibernate |
| druidControl Entangling Roots | D-16 | No WoW API simulation env | In caster form vs non-beast → verify Entangling Roots |
| catAtk regression | D-05 | No WoW API simulation env | After removing bear routing, verify catAtk still works in cat form |
| bearAtk regression | D-05 | No WoW API simulation env | After removing bear routing, verify bearAtk still works independently |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending