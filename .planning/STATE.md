---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Executing Phase 17
last_updated: "2026-06-29T10:54:20Z"
last_activity: 2026-06-29
progress:
  total_phases: 16
  completed_phases: 11
  total_plans: 33
  completed_plans: 32
  percent: 70
stopped_at: context exhaustion at 76% (2026-06-18)
---

# Project State

## Current Status

- **Milestone**: macro-torch 架构重构
- **Started**: 2026-06-07
- **Current Phase**: Phase 16 — catLeveling 练级版一键宏（执行中）
- **Active Branch**: main

## Phase Progress

| Phase | 状态 | 开始 | 完成 | 提交 |
|-------|------|------|------|------|
| Phase 1: 基础设施 + Entity 迁移 | ✅ complete | 2026-06-07 | 2026-06-08 | 6 plans |
| Phase 2: 事件系统拆分 | ✅ complete | 2026-06-08 | 2026-06-08 | 3 plans |
| Phase 3: 自检 + Spell Trace 配置化 | 🔵 context-ready | — | — | — |
| Phase 4: 职业重组 + 构建系统 | ✅ complete | 2026-06-08 | 2026-06-08 | 4 plans |
| Phase 5: Druid技能方法封装改造 | ✅ complete | 2026-06-14 | 2026-06-14 | 3 plans |
| Phase 6: Fix Druid _castSpell isSpellReady nil bug | ✅ complete | 2026-06-14 | 2026-06-14 | 1 plan |
| Phase 7: Druid 形态判断语义化方法 | ✅ complete | 2026-06-15 | 2026-06-15 | 1 plan |
| Phase 8: 非Druid职业代码结构重构（对齐Druid架构） | ✅ complete | 2026-06-15 | 2026-06-15 | 4 plans |
| Phase 9: pokemonLoad 移至 Player 层 | 🔵 in_progress | 2026-06-16 | — | — |
| Phase 10: Druid 综合一键宏方法（druidAtk/Aoe/Heal/Defend/Control） | ✅ complete | 2026-06-16 | 2026-06-17 | 2 plans |
| Phase 13: catAtk 小号练级适配（技能存在性检查、动态能量消耗、降级策略） | 🔵 in_progress | 2026-06-20 | — | 1/2 plans |
| Phase 14: 战斗时长预测与斩杀判断等级自适应（isTrivialBattle/isKillShotOrLastChance 静态估算动态化） | ⚪ planned | 2026-06-20 | — | — |
| Phase 15: catAtk 从 Druid 实例方法重构为 combo.lua 全局一键宏方法 | ✅ complete | 2026-06-20 | 2026-06-20 | 1 plan |
| Phase 16: catLeveling 练级版一键宏 — 起手技选择、中间循环(debuff/buff/精灵之火)、斩杀线判断 | 🔵 in_progress | 2026-06-22 | — | 1/2 plans |

## Accumulated Context

### Roadmap Evolution

- Phase 5 added: Druid技能方法封装改造 - 将player.cast()字符串调用重构为技能对象方法，支持多语言客户端，从Druid试点 (2026-06-13)
- Phase 6 added: Fix Druid _castSpell isSpellReady nil bug - Player.lua 中 _castSpell/_isInRange/_hasResource 点号定义与 Druid.lua 冒号调用不匹配，导致闭包 self 错误 (2026-06-14)
- Phase 7 added: Druid 形态判断语义化方法 — 新增 isInCatForm/isInBearForm 等 5 个语义方法替换 isFormActive 硬编码调用 (2026-06-15)
- Phase 10 added: Druid 综合一键宏方法 — 创建 druidAtk/druidAoe/druidHeal/druidDefend/druidControl 5 个方法，内部按形态 if-else 路由到对应子方法 (2026-06-16)
- Phase 13 added: catAtk 小号练级适配 — 技能存在性检查、动态能量消耗计算、低等级降级策略，保持60级满级DPS能力不变 (2026-06-19)
- Phase 14 added: 战斗时长预测与斩杀判断等级自适应 — 将 isTrivialBattle 和 isKillShotOrLastChance 中硬编码的60级静态DPS估算替换为等级自适应动态估算，使练级阶段也能准确判断快速战斗和斩杀线 (2026-06-20)
- Phase 15 added: 将catAtk从Druid实例方法重构为combo.lua全局一键宏方法 (2026-06-20)
- Phase 16 added: catLeveling 练级版一键宏 — 新建 catLeveling 函数（不修改 catAtk），实现技能存在性检查、起手技 ravage/pounce 选择（复用 isTrivialBattleOrPvp）、中间循环（猛虎之怒/双流血/精灵之火）、斩杀线判断（复用 kill shot 逻辑） (2026-06-22)
- Phase 17 added: catLeveling FF prowling guard + global spellId 动态更正机制 — FF不能在潜行状态下释放；spell tracing/immune 改为按名称注册，建立name→spellId双向映射(含中英文)，运行时通过UNIT_CASTEVENT捕获真实spellId并持久化矫正 (2026-06-29)

## Key Decisions

| 日期 | 决策 | 理由 |
|------|------|------|
| 2026-06-07 | 启动重构项目 | REFACTOR_PLAN.md 已对齐，架构方案确认 |
| 2026-06-07 | 4 Phase 拆分方案 | 比原始 7 Step 更聚焦，每 Phase 可独立验证 |
| 2026-06-07 | Phase 1 同时做 entity 迁移 | classMetatable + entity 迁移是不可分的原子操作 |
| 2026-06-07 | 保持所有 macroTorch.* 全局命名 | WoW 1.12.1 不支持 require，必须全局可见 |
| 2026-06-07 | build_order.txt + build.sh 提前到 Phase 1 | Phase 1 移动 entity/ 文件后旧 build.sh 硬编码路径失效，必须同步更新构建系统 |
| 2026-06-07 | build.sh Phase 1 使用容错模式 | 后续 Phase 逐步创建新文件，build.sh 跳过不存在文件避免报错；Phase 4 切换到严格模式 |
| 2026-06-07 | periodic.lua 和 events.lua 使用独立 Frame | 原 battle_event_queue.lua 中共享 frame，拆分后各自创建独立 frame，无共享状态 |
| 2026-06-07 | classMetatable 最简工厂方案 | 仅消除重复模板，不引入 parent 参数/builder 模式，保持类继承隐式 |
| 2026-06-07 | initPlayer 惰性注册表 | 各职业自注册 `registerPlayerClass()`，initPlayer 查表+fallback，消除多态 hack |
| 2026-06-07 | build_order.txt 一次性全量 | Phase 1 写出所有 Phase 2-4 文件路径，容错模式跳过未创建文件 |
| 2026-06-07 | LRUStack 改用 classMetatable(nil) | 验证工厂设计，统一 metatable 模式，无父类情况显式传 nil |
| 2026-06-07 | periodic.lua Phase 1 独立 Frame | OnUpdate 代码块与 OnEvent handler 零耦合，立即分离无过渡状态 |

## Open Questions

- Group/Raid 实体是否有实际使用场景，需要后续跟用户确认后再决定是否实现（当前保持空壳）
- 非 Druid 职业文件（Hunter/Mage 等）是否需要在此次重构中也进行逻辑完善？文档只要求作为参考样例保留

## References

- [PROJECT.md](PROJECT.md) — 项目背景和约束
- [REQUIREMENTS.md](REQUIREMENTS.md) — 8 项可验证需求
- [ROADMAP.md](ROADMAP.md) — 4 Phase 详细实施步骤
- [config.json](config.json) — 工作流配置
- [../docs/REFACTOR_PLAN.md](../docs/REFACTOR_PLAN.md) — 原始重构计划
- [codebase/](codebase/) — 现有代码库分析文档

## Commands

```bash

# 开始 Phase 1

/gsd:plan-phase 1

# 执行当前 Phase

/gsd:execute-phase

# 验证 Phase 完成

/gsd:validate-phase
```

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 05 P03 | 380 | 4 tasks | 2 files |
| Phase 07 P01 | 132 | 3 tasks | 3 files |
| Phase 08 P01 | 407 | 3 tasks | 6 files |
| Phase 08 P02 | N/A | 3 tasks | 4 files |
| Phase 08 P03 | N/A | 3 tasks | 5 files |
| Phase 13-catatk-60-dps P02 | 122 | 1 tasks | 1 files |
| Phase 14-istrivialbattle-iskillshotorlastchance-60-dps-b P01 | 462 | 3 tasks | 6 files |
| Phase 16-catatk-dps-catatk-catleveling P01 | 141 | 1 tasks | 1 files |
| Phase 16-catatk P02 | 87 | 1 tasks | 1 files |
| Phase 17 P01 | 192 | 3 tasks | 6 files |
| Phase 17 P02 | 209 | 2 tasks | 4 files |

## Decisions

- [Phase 05]: Deleted 5 wrapper functions: safeShred, readyShred, safeClaw, readyClaw, safePounce -- replaced with direct mode-based skill method calls (nil='ready', 'safe'='energy+distance checks', 'raw'='no checks')
- [Phase 07 P01]: Added 5 semantic form-check methods (isInCatForm/isInBearForm/isInTravelForm/isInAquaticForm/isInCasterForm) in DRUID_FIELD_FUNC_MAP delegating to isFormActive; isInBearForm uses OR logic for Bear Form + Dire Bear Form; isInTravelForm/isInAquaticForm/isInCasterForm reserved for future expansion; replaced 7 hardcoded isFormActive calls across Druid.lua/bear.lua/utility.lua
- [Phase 08 P01]: Refactored Hunter (3 files) and Warrior (3 files) to Druid-aligned architecture — classMetatable + FIELD_FUNC_MAP + skill methods with _castSpell and locale tables + registerPlayerClass + SpellTrace:register + SelfTest:register; Hunter: 10 skill methods, Warrior: 17 skill methods; replaced CastSpellByName with skill method calls for all spells, preserved CastShapeshiftForm/castIfBuffAbsent/CastSpellByName for stance changes
- [Phase 08 P02]: Refactored Rogue (2 files) and Mage (2 files) to Druid-aligned architecture; Rogue: 7 skill methods with English locale names verified by user, pickPocketBeforeCast state machine preserved, comboPoints in FIELD_FUNC_MAP, lockNearestEnemyThenCast deferred migration; Mage: 3 skill methods, castIfBuffAbsent preserved for Frost Armor/Arcane Intellect, Frostbolt CastSpellByName replaced
- [Phase 08 P03]: Refactored Priest (3 files) and Warlock (2 files) to Druid-aligned architecture; Priest: 7 skill methods (holy_fire/shadow_word_pain/inner_fire/power_word_fortitude/heal/lesser_heal/renew), CastSpellByName for Holy Fire/Heal/Lesser Heal replaced with skill methods, castIfBuffAbsent preserved for Power Word: Fortitude/Inner Fire/Shadow Word: Pain/Renew, healing threshold logic preserved; Warlock: 4 skill methods (immolate/corruption/curse_of_agony/demon_skin) for future migration, all castIfBuffAbsent calls preserved unchanged (no CastSpellByName in original code)
- [Phase 10 P01]: Created classes/druid/combo.lua with 5 global combo methods (druidAtk/druidAoe/druidHeal/druidDefend/druidControl) — form-based if-elseif routing, one-action-per-press design, 5 optional SelfTest registrations. druidHeal uses CancelShapeshiftForm for form cancellation. druidControl merges old druidStun logic with target type detection for Hibernate vs Entangling Roots.
- [Phase 10 P02]: Removed bear routing block from catAtk (lines 380-384) and isInBearForm cache (line 348) in Druid.lua — catAtk is now pure cat-form. Deleted 3 obsolete functions (druidStun/druidDefend/druidControl) from utility.lua — druidBuffs retained unchanged. Added combo.lua to build_order.txt after utility.lua.
- [Phase ?]: Category H tests placed before Category G2 for logical grouping: G1 (field integrity) -> H (guard verification) -> G2 (form semantics)
- [Phase ?]: HRPS primary
- [Phase 15]: Moved catAtk from Druid instance method (obj.catAtk) to combo.lua global function (macroTorch.catAtk) — function body uses only macroTorch.* globals, no self/obj dependency; druidAtk call updated from macroTorch.player.catAtk to macroTorch.catAtk; added selftest for new function location
- [Phase 16 P01]: Implemented catLeveling() — 210-line leveling one-button macro with 9 modules in priority order, no rough/ERPS/reshift/relic, all 8 skills guarded by isSpellExist, inline simplified FF and Shred-vs-Claw decisions. catAtk and catLeveling are fully independent.
- [Phase ?]: test
- [Phase ?]: Phase 16 P02: Added 5 Category J SelfTest registrations for catLeveling in core/selftest.lua — verifying function presence, shared decision function references (isKillShotOrLastChance/shouldCastRip/shouldUseBite), clickContext correctness, catAtk invariance, and ERPS/reshift independence. 2 core (isOptional=false) + 3 optional (isOptional=true) tests with UnitClass guard for non-Druid logins.
- [Phase 17 P01]: Established SPELL_NAME_TO_ID static mapping table (8 entries, EN+ZH), resolveSpellId() two-stage resolution (runtime correction > static baseline), loadSpellIdMap() persistence binding to loginContext, SpellTrace:register spellName field support, and FF prowling guard in catLeveling.
- [Phase 17 P02]: Bridged _castSpell spellName to UNIT_CASTEVENT spellId via current_casting_spell; implemented runtime spellId correction with SM_EXTEND persistence and tracingSpells key migration; migrated 4 Druid land-tracing spells (Pounce/Rake/Rip/Ferocious Bite) from hardcoded spellId to spellName-driven registration; added 5 Category K self-tests (K1-K5) for spellId mapping system verification.

## Session

## Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260619-1ry | 技能释放默认最高等级 + 可选rank参数 | 2026-06-18 | 33a9a92 | [260619-1ry-rank-1-based](./quick/260619-1ry-rank-1-based/) |
| 260619-qbj | casterAtk加入Faerie Fire/Insect Swarm debuff + Starfire交替循环 | 2026-06-19 | c7549ff | [260619-qbj-add-faerie-fire-insect-swarm-debuff-and-](./quick/260619-qbj-add-faerie-fire-insect-swarm-debuff-and-/) |
| 260620-gpw | burstMod/atkPowerBurst 存在性守卫 (Berserk技能+Trinket2饰品槽) | 2026-06-20 | 7f03c82 | [260620-gpw-catatk](./quick/260620-gpw-catatk/) |
| 260620-j2p | Opener血量阈值+法力药水阈值改为level-adaptive | 2026-06-20 | af283bd | [260620-j2p-opener-mana-level-adaptive](./quick/260620-j2p-opener-mana-level-adaptive/) |
| 260623-wrh | Druid技能诊断打印函数 printDruidDiag | 2026-06-23 | f1bba57 | [260623-wrh-druid](./quick/260623-wrh-druid/) |
| 260627-g4j | 修复 spell_trace_immune.lua 日志问题 | 2026-06-27 | fef6f2f | [260627-g4j-1-3](./quick/260627-g4j-1-3/) |

## Session

**Last session:** 2026-06-29T10:54:20.000Z
**Last activity:** 2026-06-29
**Resume file:** None
