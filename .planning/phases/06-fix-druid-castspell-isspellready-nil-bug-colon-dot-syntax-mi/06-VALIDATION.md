---
phase: 06
slug: fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-14
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | macroTorch.SelfTest (custom, core/selftest.lua) |
| **Config file** | none — inline registrations in source files |
| **Quick run command** | `/mt` (SLASH command in-game) |
| **Full suite command** | `/mt` (same command, all tests run sequentially) |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Read-back verification of changed lines (grep-based)
- **After every plan wave:** `/mt` command in-game (requires WoW 1.12.1 client)
- **Before `/gsd-verify-work`:** All Category F tests pass + HUMAN-UAT.md checklist complete
- **Max feedback latency:** 60 seconds (grep verification); in-game testing requires WoW client

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | D-02 | — | _castSpell internal calls use dot syntax (obj.xxx not self:xxx) | grep | `grep 'self:' entity/Player.lua` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | D-03 | — | Druid skill methods use obj._castSpell not self:_castSpell | grep | `grep 'self:_castSpell' classes/druid/Druid.lua` | ✅ | ⬜ pending |
| 06-01-03 | 01 | 1 | D-06 | — | Category F selftest (~15 tests) registered in core/selftest.lua | unit | `grep 'SelfTest:register.*F:' core/selftest.lua` | ❌ W0 | ⬜ pending |
| 06-01-04 | 01 | 1 | D-07 | — | HUMAN-UAT.md exists with Type A/B/C × ready/safe/raw coverage | manual | `test -f classes/druid/HUMAN-UAT.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `core/selftest.lua` — add Category F section (~15 tests) for metatable chain and _castSpell parameter integrity
- [ ] `classes/druid/HUMAN-UAT.md` — create manual test checklist (Type A enemy skills: claw/shred/rake/rip; Type B self skills: cat_form/prowl/tiger_fury; Type C flexible skills: healing_touch/rejuvenation/mark_of_the_wild)
- [ ] No test framework install needed — SelfTest is already in place

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Druid skill casting in-game (Type A) | D-02, D-03 | CastSpellByName WoW API cannot be tested outside game client | Cast claw/shred/rake/rip on enemy target; verify spells cast and combo points generate |
| Druid self-target skills (Type B) | D-02, D-03 | Cannot simulate WoW buff application off-client | Cast cat_form/prowl/tiger_fury; verify forms shift and buffs apply |
| Druid flexible-target skills (Type C) | D-02, D-03 | Cannot verify spell targeting off-client | Cast healing_touch/rejuvenation/mark_of_the_wild with/without enemy target |
| Mode parameter behavior | D-02 | safe/raw/ready modes depend on WoW API state | Test each mode: raw casts always, safe checks resource/range, ready checks cooldown |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending