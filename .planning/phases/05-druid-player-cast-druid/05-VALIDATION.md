---
phase: 05
slug: druid-player-cast-druid
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-13
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Lua syntax check (WoW 1.12.1 embedded Lua, no test framework) |
| **Config file** | none |
| **Quick run command** | `./build.sh` |
| **Full suite command** | `./build.sh && echo "Build OK"` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh`
- **After every plan wave:** Run `./build.sh` + grep assertions
- **Before `/gsd-verify-work`:** Build must pass + manual in-game testing
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| *TBD by planner* | - | - | R8 | — | N/A | build | `./build.sh` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- None — existing infrastructure (`./build.sh` + grep) covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Druid skill methods cast correctly on en_US client | R8 | WoW client API interaction | Login en_US client, press macro key, verify skills execute |
| Druid skill methods cast correctly on zh_CN client | R8 | WoW client API interaction | Login zh_CN client, press macro key, verify skills execute |
| _castSpell mode='safe' respects range check | R8 | Requires in-game distance | Stand at max range, verify 'safe' mode doesn't cast, 'raw' mode does |
| Cat form energy costs correct after talent changes | R8 | Dynamic talent-dependent | Respec talents, verify energy costs with `player.mana` |
| Bear form skills work with rage costs | R8 | Rage is combat-dependent | Enter combat in bear form, verify abilities use correct rage |

---

## Validation Sign-Off

- [ ] All tasks have `<acceptance_criteria>` with build or grep assertions
- [ ] Sampling continuity: `./build.sh` after every task
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending