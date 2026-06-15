---
phase: 08
slug: druid-druid
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-15
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> WoW 1.12.1 addon — uses in-game SelfTest + grep verification (no external Lua test framework).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | In-game `macroTorch.SelfTest` + shell grep verification |
| **Config file** | none — SelfTest is programmatic |
| **Quick run command** | `./build.sh` |
| **Full suite command** | In-game login + check SelfTest chat frame output |
| **Estimated runtime** | ~5 seconds (build) |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh`
- **After every plan wave:** `./build.sh` + full grep verification
- **Before `/gsd-verify-work`:** `./build.sh` succeeds + all grep checks pass
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | REQ-08-CLASS-DEF | — | N/A | build+grep | `grep -c "macroTorch.classMetatable" classes/hunter/ classes/warrior/ classes/rogue/ classes/mage/ classes/priest/ classes/warlock/` >= 6 | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | REQ-08-SKILL-METHODS | — | N/A | build+grep | `grep -c "CastSpellByName" classes/hunter/ classes/warrior/ classes/rogue/ classes/mage/ classes/priest/ classes/warlock/` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | REQ-08-SPELLTRACE | — | N/A | build+grep | `grep -c "SpellTrace:register" classes/*/<Class>.lua` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | REQ-08-SELFTEST | — | N/A | self-test | In-game: log in as each class, check SelfTest chat frame | ❌ W0 | ⬜ pending |
| TBD | 01 | 2 | REQ-08-BUILD | — | N/A | build | `./build.sh && echo "Build OK"` | ❌ W0 | ⬜ pending |
| TBD | 01 | 2 | REQ-08-NO-FLAT | — | N/A | file check | `test ! -f classes/Hunter.lua && test ! -f classes/Warrior.lua && ...`  | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | REQ-08-INITPLAYER | — | N/A | grep | `grep -c "registerPlayerClass" classes/hunter/Hunter.lua classes/warrior/Warrior.lua classes/rogue/Rogue.lua classes/mage/Mage.lua classes/priest/Priest.lua classes/warlock/Warlock.lua` >= 6 | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `./build.sh` succeeds with current build_order.txt (baseline)
- [ ] All existing `grep` verification commands work as expected
- [ ] `castIfBuffAbsent` helper function confirmed available in entity/Player.lua

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| In-game SelfTest output for each class | REQ-08-SELFTEST | Requires WoW 1.12.1 client login | Log in as each class (Warrior/Mage/Priest/Rogue/Warlock/Hunter), check chat frame for `[macro-torch] Self-test: X passed, Y failed, Z warnings` |
| Skill methods actually cast spells | REQ-08-SKILL-METHODS | Requires WoW client with target | Log in, target a training dummy, press macro bound to each skill method |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending