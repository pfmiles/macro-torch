---
phase: 17
slug: 1-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tracing-immune-name-spellid-unit-castevent-spellid
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-29
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | WoW Lua SelfTest (macroTorch.SelfTest framework in core/selftest.lua) |
| **Config file** | none — SelfTest:register() calls inline in source files |
| **Quick run command** | `./build.sh && echo "Build OK"` |
| **Full suite command** | In-game: `/mt` SLASH command triggers SelfTest:run() on PLAYER_ENTERING_WORLD |
| **Estimated runtime** | ~5 seconds (build), ~2 seconds (in-game self-test) |

---

## Sampling Rate

- **After every task commit:** Run `./build.sh`
- **After every plan wave:** Build + verify greps per task acceptance criteria
- **Before verification:** Full in-game self-test via `/mt` command
- **Max feedback latency:** 60 seconds (build + grep checks)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 1 | D-01 | — | N/A | grep | `grep "isProwling" classes/druid/leveling.lua` | ❌ W0 | ⬜ pending |
| 17-02-01 | 02 | 1 | D-02 | — | N/A | grep | `grep "SPELL_NAME_TO_ID" core/spell_id_map.lua` | ❌ W0 | ⬜ pending |
| 17-02-02 | 02 | 1 | D-03,D-04,D-05 | — | N/A | grep | `grep "loadSpellIdMap" core/spell_trace_immune.lua` | ❌ W0 | ⬜ pending |
| 17-02-03 | 02 | 1 | D-06,D-07 | — | N/A | grep | `grep "current_casting_spell" entity/Player.lua core/events.lua` | ❌ W0 | ⬜ pending |
| 17-02-04 | 02 | 1 | D-10 | — | N/A | grep | `grep "spellName" core/spell_trace_core.lua` | ❌ W0 | ⬜ pending |
| 17-02-05 | 02 | 2 | D-08,D-11 | — | N/A | grep | `grep "spellName" classes/druid/Druid.lua` | ❌ W0 | ⬜ pending |
| 17-02-06 | 02 | 2 | D-12 | — | N/A | grep | `grep "spellIdMap\|resolveSpellId" core/events.lua` | ❌ W0 | ⬜ pending |
| 17-03 | 03 | 3 | — | — | N/A | grep | `grep "SelfTest:register" classes/druid/Druid.lua core/selftest.lua` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `core/spell_id_map.lua` — SPELL_NAME_TO_ID static mapping table (new file)
- [ ] `core/spell_trace_core.lua` — resolveSpellId() function + SpellTrace:register() spellName support
- [ ] `core/spell_trace_immune.lua` — loadSpellIdMap() function
- [ ] `entity/Player.lua` — current_casting_spell set in _castSpell
- [ ] `core/events.lua` — current_casting_spell clear + spellId correction in UNIT_CASTEVENT
- [ ] `classes/druid/Druid.lua` — 4 SpellTrace:register calls migrated to spellName
- [ ] `classes/druid/leveling.lua` — FF prowling guard (1 line)
- [ ] `build_order.txt` — core/spell_id_map.lua insertion

*Wave 0 for this phase = the new files/functions created by the phase itself.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| spellId 运行时更正 | D-12 | 需要真实 WoW 客户端触发 UNIT_CASTEVENT | 登录 Druid，施放 Pounce/Rake/Rip/FB，检查 SM_EXTEND.spellIdMap 持久化 |
| FF 潜行守卫 | D-01 | 需要潜行状态下测试 FF | 猫形态潜行，按一键宏，确认 FF 不释放 |
| 低等级 spellId 自动发现 | (deferred) | 需要低等级 Druid 角色 | 低等级角色施放 rank-1 技能，验证映射表自动更新 |
| 中文客户端名称 | D-02 | 需要中文 WoW 客户端 | 中文客户端登录，施放技能，验证中文名称映射正常 |

---

## Validation Sign-Off

- [ ] All tasks have grep-verifiable acceptance criteria
- [ ] Sampling continuity: build.sh after every task commit
- [ ] Wave 0 covers all new file/functions
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending