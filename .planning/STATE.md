---
gsd_state_version: 1.0
milestone: v1.0
current_plan: Not started
status: in_progress
stopped_at: Phase 28 complete, ready to plan Phase 29
last_updated: "2026-09-12T18:30:57.725Z"
state_head: 32c900b941ae5e5fb0de40002cb4c8fd8393373d
progress:
  total_phases: 29
  completed_phases: 15
  total_plans: 68
  completed_plans: 68
milestone_name: milestone
last_activity: 2026-09-13
current_phase: 29
current_phase_name: 统一 landing 判定重构
last_activity_desc: "Completed quick task 260913-46s: tools/cpdamage.lua OOC-Bite Criteria 自动计算块（R*(A/B)/R*(D/B) + --erps，selftest 35→49 三解释器全绿）"
---

# Project State

## Current Status

- **Milestone**: macro-torch 架构重构
- **Started**: 2026-06-07
- **Current Phase**: Phase 29 — 统一 landing 判定重构（实机验证已闭环：29-UAT.md complete 5/5，G-29-3 resolved，29-VERIFICATION.md passed，2026-09-12）。Phase 28 cat 伤害打桩 UAT 5/5 全绿、verification passed、阶段完成（2026-09-13）。Phase 30 已全绿闭合（2026-09-11）
- **Current Plan:** Not started
- **Total Plans in Phase:** 4
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
| Phase 13: catAtk 小号练级适配（技能存在性检查、动态能量消耗、降级策略） | ✅ complete | 2026-06-20 | 2026-06-20 | 2 plans |
| Phase 14: 战斗时长预测与斩杀判断等级自适应 | ✅ complete | 2026-06-20 | 2026-06-20 | 1 plan |
| Phase 15: catAtk 从 Druid 实例方法重构为 combo.lua 全局一键宏方法 | ✅ complete | 2026-06-20 | 2026-06-20 | 1 plan |
| Phase 16: catLeveling 练级版一键宏 | ✅ complete | 2026-06-22 | 2026-06-23 | 2 plans |
| Phase 17: catLeveling FF prowling guard + global spellId 动态更正机制 | ✅ complete | 2026-06-29 | 2026-06-29 | 2 plans |
| Phase 18: spellId 自动更正机制改造 | ✅ complete | 2026-07-04 | 2026-07-04 | 2 plans |
| Phase 19: 改造druidControl逻辑 — druidCharge | ✅ complete | 2026-07-08 | 2026-07-08 | 2 plans |
| Phase 20: SPELL_ID_AUTO_CORRECT 全局开关 | ✅ complete | 2026-07-10 | 2026-07-10 | 3 plans |
| Phase 21: catAtk 可维护性清理 | ✅ complete | 2026-07-29 | 2026-07-29 | 3/3 plans |
| Phase 22: catAtk 质量保障 — SelfTest + 文档补充 | ✅ complete | 2026-07-30 | 2026-07-30 | 2/2 plans |
| Phase 23: idol dance refactor — computeNormalRelic + 距离优化 | 🟡 in_progress | 2026-08-02 | — | 1/1 plan |
| Phase 25: Hunter 一键宏改造 — Druid 对齐架构 | ✅ complete | 2026-08-18 | 2026-08-19 | 3/3 plans |
| Phase 26: 猫德 fast 战斗逻辑 | ✅ complete | 2026-08-21 | 2026-08-22 | 3/3 plans |
| Phase 27: catAtk event-driven land tracing refactor | ✅ complete | 2026-08-28 | 2026-08-29 | 3/3 plans |
| Phase 28: catAtk claw/shred/bite damage instrumentation | ✅ complete | 2026-09-08 | 2026-09-08 | 4/4 plans |
| Phase 29: 统一 landing 判定重构 | ✅ complete | 2026-09-10 | 2026-09-12 | 4/4 plans |
| Phase 30: cpBuild 双保判定改造 | ✅ complete | 2026-09-10 | 2026-09-11 | 3/3 plans |

## Accumulated Context

### Roadmap Evolution

- Phase 30 added: cpBuild 双保判定改造 — 保留 cpBuildLog 开关持久化门控，新增 bite→满星耗时 live 计时器（状态机协议已封版），可选离线分析脚本 (2026-09-10)
- Phase 29 added: 统一 landing 判定重构 — 去 landSource 参数、OR 三通道 + 反推兜底、cast 谓词去重、可配 intentTtl（默认 0.9s/猎人钉刺 ~2s）、FB 续期豁免 (2026-09-09)
- Phase 24 added: 用 UNIT_SPELLCAST_SUCCEEDED 标准事件替代 UNIT_CASTEVENT 的 cast 记录链路，消除对全局 spellId 的依赖 (2026-08-17)
- Phase 5 added: Druid技能方法封装改造 - 将player.cast()字符串调用重构为技能对象方法，支持多语言客户端，从Druid试点 (2026-06-13)
- Phase 6 added: Fix Druid _castSpell isSpellReady nil bug - Player.lua 中 _castSpell/_isInRange/_hasResource 点号定义与 Druid.lua 冒号调用不匹配，导致闭包 self 错误 (2026-06-14)
- Phase 7 added: Druid 形态判断语义化方法 — 新增 isInCatForm/isInBearForm 等 5 个语义方法替换 isFormActive 硬编码调用 (2026-06-15)
- Phase 10 added: Druid 综合一键宏方法 — 创建 druidAtk/druidAoe/druidHeal/druidDefend/druidControl 5 个方法，内部按形态 if-else 路由到对应子方法 (2026-06-16)
- Phase 13 added: catAtk 小号练级适配 — 技能存在性检查、动态能量消耗计算、低等级降级策略，保持60级满级DPS能力不变 (2026-06-19)
- Phase 14 added: 战斗时长预测与斩杀判断等级自适应 — 将 isTrivialBattle 和 isKillShotOrLastChance 中硬编码的60级静态DPS估算替换为等级自适应动态估算，使练级阶段也能准确判断快速战斗和斩杀线 (2026-06-20)
- Phase 15 added: 将catAtk从Druid实例方法重构为combo.lua全局一键宏方法 (2026-06-20)
- Phase 16 added: catLeveling 练级版一键宏 — 新建 catLeveling 函数（不修改 catAtk），实现技能存在性检查、起手技 ravage/pounce 选择（复用 isTrivialBattleOrPvp）、中间循环（猛虎之怒/双流血/精灵之火）、斩杀线判断（复用 kill shot 逻辑） (2026-06-22)
- Phase 17 added: catLeveling FF prowling guard + global spellId 动态更正机制 — FF不能在潜行状态下释放；spell tracing/immune 改为按名称注册，建立name→spellId双向映射(含中英文)，运行时通过UNIT_CASTEVENT捕获真实spellId并持久化矫正 (2026-06-29)
- Phase 18 added: spellId 自动更正机制改造 — 将 spellId 更正监听与 land tracing 注册合并，以 _spellIdMonitored 白名单替代无条件 current_casting_spell 设值，消除残留污染和错误更正风险 (2026-07-04)
- Phase 19 added: 改造druidControl逻辑 — 拆分bash到新方法druidCharge，加强形态验证和技能存在性判断，优化练级流程控制与冲锋体验 (2026-07-08)
- Phase 20 added: 添加 SPELL_ID_AUTO_CORRECT 全局开关控制 spellId 自动修正机制 — 涉及 macro_torch.lua / spell_trace_core.lua / Player.lua / events.lua / spell_trace_immune.lua 五个文件的守卫逻辑 (2026-07-10)
- Phase 21 added: catAtk 可维护性清理 — 基于 catAtk-core-principles.md 逆向审视，4 项纯代码改进：注释编号修复、斩杀入口注释、isInfiniteEnergy 集中化、keepRake ATK 爆发分离。来源：`.planning/catAtk-phaseA-maintainability.md` (2026-07-29)
- Phase 22 added: catAtk 质量保障 — 基于原则的 SelfTest 回归测试 + 原则文档补充（附录 D 可追溯性矩阵）。来源：`.planning/catAtk-phaseB-quality.md` (2026-07-30)
- Phase 23 added: Idol Dance (神像舞) Refactor — 修复 computeNormalRelic 2 个逻辑 gap + recoverNormalRelic 距离旁路优化 + Category O SelfTest 覆盖。来源：`.planning/phases/23-idol-dance-refactor/23-CONTEXT.md` (2026-08-02)
- Phase 25 added: 参考druid相关逻辑，仿照代码组织结构，改造hunter职业的代码，构造出hunterAtk宏用于练级过程中的一键输出，包含远程和近战输出；hunterAoe用于范围输出，同样包括远程和近战；hunterDefend用于保命减伤；hunterControl用于控制目标；hunterMobTagging用于抢怪，包含近战和远程抢怪 (2026-08-17)
- Phase 26 added: 新增猫德fast战斗逻辑 — isFastBattleNotPvp(8.5s阈值)纯直伤策略，跳过所有流血(Pounce/Rake/Rip)，仅Shred/Claw攒星→5CP Bite/KillShot (2026-08-21)
- Phase 27 added: catAtk event-driven land tracing refactor — 事件驱动 land 机制替代 0.1s 轮询 blip 窗口（卡顿机器上 ripLeft 证据链断裂的根治）：cast 桥不变 + 2s 过期 cast intent + landSource 枚举(self-hit/aura-apply) + fail 终局撤销 + 三层 RAW 过滤器。27-01 已删除核心轮询对与 RAWDIAG 侦察 (2026-08-28)
- Phase 28 added: cat druid claw/shred/bite 伤害统计打桩 — macroTorch bool 开关控制的 log 采集（claw/shred 的 energy efficiency 按流血效果数分档 + 单次伤害对比，bite 多余能量伤害转化），配套独立 lua 离线分析脚本解析持久化 json array log，支撑 catAtk 两个核心输出决策，支持装备/天赋变化后多次复用测试 (2026-09-08)

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
| 2026-09-13 | CC(清晰预兆)咬决策基准文档化 | 推演定案：CC 恒给 shred（免费单次+省能耗双赢）；CC 咬仅在 ERPS≥~25/s 窗口更优（如 Essence）。基准+校准流程落档 28-OOC-BITE-CRITERIA.md，常数不写死宏 |
| 2026-09-13 | cpdamage --json-out 严格 JSON 修复 | G-28-5：encodeKey 数字键加引号 + 自检 33→35，5.0/5.1/5.4 三解释器全绿，屏显输出字节级不变 |

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
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 21-catAtk-maintainability P03 | 4 | 2 tasks | 1 files |
| Phase 22 P01 | 367 | 2 tasks | 3 files |
| Phase 22 P02 | 480 | 2 tasks | 1 files |
| Phase 23 P01 | 55 | 2 tasks | 2 files |
| Phase 25 P01 | ~15 | 2 tasks | 1 files |
| Phase 25 P02 | ~8 | 2 tasks | 1 files |
| Phase 25 P03 | 2 | 2 tasks | 1 files |
| Phase 26 P01 | 175 | 3 tasks | 4 files |
| Phase 26 P02 | 193 | 2 tasks | 1 files |
| Phase 26 P03 | 3 | 3 tasks | 2 files |
| Phase 27 P01 | 17 min | 3 tasks | 3 files |
| Phase 27 P02 | 2 min | 3 tasks | 3 files |
| Phase 27 P03 | 13 min | 2 tasks | 1 files |
| Phase 28 P01 | 12 | 3 tasks | 7 files |
| Phase 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac P02 | 345 | 2 tasks | 2 files |
| Phase 28 P03 | 18 | 4 tasks | 1 files |
| Phase 28 P04 | 3 | 2 tasks | 2 files |
| Phase 29 P01 | 10 | 3 tasks | 4 files |
| Phase 29 P02 | 6 | 2 tasks | 2 files |
| Phase 29 P03 | 9 | 3 tasks | 2 files |
| Phase 30-cpbuild P01 | 2 | 2 tasks | 2 files |
| Phase 30-cpbuild P03 | 19 | 3 tasks | 1 files |
| Phase 30 P02 | 4 | 2 tasks | 3 files |
| Phase 29-landing P04 | 206 | 2 tasks | 2 files |

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
- [Phase ?]: Phase 21-03: D-08 Scheme A — comment block annotation only, zero code changes in keepRake. Documents why atkPowerBurst is called here: AP snapshot maximizes Rake bleed, burstMod handles manual Shift-key while this is automated optimization
- [Phase ?]: Phase 21-03: D-09 Third and final commit of Phase 21 — docs(catAtk): annotate ATK burst side effect in keepRake — completes 3-commit strategy
- [Phase ?]: PF-01 conditional skip guard auto-fixed: plan had negated logic (skip when condition MET), corrected to skip when NOT met (~= 0 instead of == 0)
- [Phase 23 P01]: D-01: Flat 5-branch if-else chain in computeNormalRelic — non-combat immune → Fero/Rot, non-combat non-immune → Savagery, trivialBattle/PvP → Fero/Rot, immune Rip → Fero/Rot, Rip present → Fero/Rot, fallback → Savagery
- [Phase 23 P01]: D-02: Non-combat pre-switch to Savagery preserved as first branch fallthrough
- [Phase 23 P01]: D-03/D-04: Distance bypass (20yd threshold) in recoverNormalRelic inserted before energy check
- [Phase 23 P01]: O-04 deviation: Plan instructed pendingCasts approach but actual isRipPresent checks clickContext.isRipPresent — fixed by injecting field directly in clickContext
- [Phase 25 P01]: Hunter.lua complete rewrite — 303 lines, 25 skill methods (10 corrected range params + 15 new), 2 SpellTrace registrations (Serpent Sting + Scorpid Sting with spellName/land/immune/debuffTexture), 28 SelfTest registrations (3 infra + 25 skill methods), aligned with Druid.lua architecture
- [Phase 25 P02]: Hunter combo.lua created — 316 lines, 5 public macro functions (hunterAtk/Aoe/Defend/Control/MobTagging) with distance routing, 2 internal helpers (hunterAtkRanged/Melee), 5 SelfTest registrations, no Aspect/Pet/Trap logic in hunterAtk modules per D-06/D-07/D-08
- [Phase ?]: [Phase 25 P03]: build_order.txt was already partially restructured (combo.lua in place, combat/utility absent) — adjusted Task 1 from 4-line block replacement to comment-only update, fully achieving plan objective
- [Phase ?]: Phase 26-01: isFastBattleNotPvp implemented — 8.5s dual condition (HRPS + health estimate), PvP-first exclusion before lazy per-frame cache; 7 additive guards wired across catAtk (combo.lua 3, cat.lua 3) + definition in Druid.lua (D-01..D-11)
- [Phase ?]: Phase 26-01: Category P SelfTests P-01/P-02 registered (isOptional=true) — function existence + PvP-exclusion cache ordering; remaining 4 land in 26-02 (D-12)
- [Phase ?]: Phase 26-02: remaining 4 Category P SelfTests registered (P-03 HRPS / P-04 health estimate / P-05 priority relation / P-06 cp5Bite regression) with stub/restore discipline; phase-wide verification green — 6/6 registrations, 3+3 call sites, 4-file diff scope, catLeveling untouched (D-12, D-09/D-10/D-13)
- [Phase ?]: [Phase 26-03]: CR-01 closed — P-02 snapshots with rawget and restores via raw assignment; the nil restore deletes the own-key so the __index accessor (FIELD_FUNC_MAP isPlayerControlled) stays live — running /mt can no longer freeze session-wide PvP detection
- [Phase ?]: [Phase 26-03]: WR-01 closed — getNextAbilityCost resolves the fast-battle verdict once per click and skips Bite/Rip/Rake in fast battles so reshift/FF consumers benchmark real Shred/Claw/Tiger costs; shouldCastRip/shouldUseBite untouched (D-09/D-13)
- [Phase ?]: [Phase 26-03]: IN-03/IN-04 closed — P-06 stubs the judgment function instead of pre-seeding the lazy-cache field; isFastBattleNotPvp caches false when macroTorch.target.isCanAttack is false (missing/dead target), with P-03/P-05 gaining the same skip guard as P-04
- [Phase ?]: Phase 27-01: event-driven land framework replaces polling — checkpoint option-a confirmed (permanent deletion of maintainLandTables/computeLandTable + RAWDIAG scout per debug decision #5); land ownership split: aura-apply lands pair with cast intent + guid match, self-hit lands pairing-free; fail is final via finalizeFail revocation
- [Phase ?]: Phase 28-01: channel gate dispatches by channel (SELF_DAMAGE consumed before tier-1 whitelist), Phase 27 land semantics untouched
- [Phase ?]: Phase 28-01: cpDamage intent queue is fully parallel to intentTable (no state/landAt, table.remove on purge and pair); tool script flags spelled via hyphen-pair concatenation to satisfy the bbcheck line-comment-first strip order
- [Phase ?]: Phase 28-02: U-02/U-03 contract literals hand-derived from the 28-01 encoder/emitter and byte-verified via node simulation (no local Lua)
- [Phase ?]: Phase 28-02: three-skill cpDamage hook triple ('claw', computeClaw_E()) / ('shred', computeShred_E()) / ('bite', 35); bite cpDamage-only, cpBuild range lock kept
- [Phase ?]: Phase 28-02: Category U U-01..U-09 (isOptional=true) pin D-03/D-05/D-06/D-07; U-09 stubs the full gate chain incl. context batch with CR-01 snapshot/restore
- [Phase ?]: Phase 28-03: analyzer double-quote bytes inside source strings spelled via string.char(34) — bbcheck's quote-first strip order mis-pairs bare quotes across the decoder (proven with a mirror replace-pipeline debugger; impl_util's encoder block is the proven-safe raw-quote exception)
- [Phase ?]: Phase 28-03: avgDmg/avgEff/avgRaw bucket semantics locked verbatim (avgEff = per-sample dmg/e mean, avgRaw = no energy division); bite regression x = energyPool−35 (regular) / energyPool−0 (OOC); json-out numbers integral-or-%.4f for cross-version stable archives
- [Phase ?]: Phase 28-04: R8 anchor corrected to the real symbol name shouldDoReshift (stale canDoReshift from docs commit 10db348) rather than renaming decision-file code
- [Phase ?]: Phase 28-04: HUMAN-UAT.md gains a 6-section Phase 28 user-machine acceptance script; the 4-item closed-loop human-check rides human_verify_mode=end-of-phase into the verifier's 28-UAT.md (no mid-plan checkpoints)
- [Phase ?]: Phase 28-04: closing battery BATTERY_FAIL=0 with the corrected R8 anchor — 8-file bbcheck + build.sh + 6 product counts + R7 zero-path audit + Phase 27 pairLandIntent coexistence
- [Phase ?]: D-01 confirmed by user at execution checkpoint: landSource field + landSources registry + both dispatch gates removed per locked scope (option-a)
- [Phase ?]: 29-03 followed plan as specified: D-16 six boundary cases all landed (Category Q = 16), UAT protocol filed, full-phase battery green — DESIGN-CONTEXT locked decisions + D-16/D-17/D-18 implemented without directional deviation; only documented excursions are the pre-existing Druid.lua '#' comment glyphs (ledger entry 5) and the battery-time clean-tree diff form
- [Phase 30-cpbuild]: DKI state lives in a dedicated macroTorch.cpBuildDki table, not macroTorch.context — onCombatExit swaps the whole context table and would destroy the in-flight window (D-04/D-15 sibling decision)
- [Phase 30-cpbuild]: all [cpBuildT] persistence flows through macroTorch.log and is gated by macroTorch.cpBuildLog; switch off = the 0.1s poll tick returns before GetComboPoints, zero client API calls (D-01)
- [Phase 30-cpbuild]: locked D-04 transition table implemented verbatim: BUILDING cp>=5 checked before the down-jump branch; mid-window down-jump counts the fail denominator and re-anchors; kill-shot-on-dying-target logs one fail line but does not re-anchor; DONE silent until next down-jump
- [Phase 30-cpbuild]: cp=0 back-look via macroTorch.toBoolean(macroTorch.target.isCanAttack), short-circuit-evaluated only when a down-jump lands on 0
- [Phase ?]: T histogram edges { 4, 6, 8, 10, 12 } live as header-local constants T_BUCKET_EDGES / T_BUCKET_LABELS (planner-chosen, user-tunable)
- [Phase ?]: Savagery pass-rate row carries d = drake * 0.9 with cutoff = d - 1 alongside the raw rakeDur row (cutoff d - 1); both rows always reported
- [Phase ?]: cpbuild.lua selftest battery carries 26 hand-derived checks; tokenNumber key-length bug (cp= dropped all cast lines) caught on first LuaJIT battery pass and fixed
- [Phase 30]: S-09 pin conflict resolved toward the plan's pinned contract: kill-shot returns now fully reset to a pristine WAIT_ANCHOR (t0 cleared) instead of weakening the pin to the shipped stale-t0 behavior (Rule 2, commit d78d6a2)
- [Phase 30]: runtime evidence stays user-side per D-14: the eight S-05..S-12 pins and the Phase 30 UAT protocol execute on Windows+Cygwin; static gates are the executor-certifiable subset, in-game battery tracked as unrun-verify in the windows ledger
- [Phase 30]: UAT 5/5 全绿 — 实机目标态循环 32 窗口 T̄=5.61s（≪ 8.0s 截点），rakeDur 达标率 87.5% / savagery 75.0%、0 截断窗口；双保判据在实机成立，样本存档 .planning/samples/cpBuild.txt（132 施法 257s 连续会话 0 断链，交叉核验 100% 吻合）
- [Phase 30]: 复审 fix 收口（e34c510/5f03a82/7f85576）— WR-01 下跳锚协议内 by-design（HUMAN-UAT 强化 D-09 终点技纪律），WR-02 双通道排障口径拆分，WR-03 events.lua resetCpBuildDki 存在性守卫
- [Phase ?]: 29-04 followed plan as specified: G-29-3 render-layer fix lands D-14 hue arms (blue={0,0.5,0.9} custom_blue, green={0,1,0} custom_green, OFFICER cleared) + Cat T-02 real-show five-arm hue-dominance regression; Category Q untouched, SM_Extend.lua byte-identical, T-02 in-game run tracked as WINDOWS unrun-verify

## Session

**Last session:** 2026-09-10T19:00:55.223Z
**Stopped at:** Phase 28 complete, ready to plan Phase 29
**Resume file:** None

## Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260619-1ry | 技能释放默认最高等级 + 可选rank参数 | 2026-06-18 | 33a9a92 | [260619-1ry-rank-1-based](./quick/260619-1ry-rank-1-based/) |
| 260619-qbj | casterAtk加入Faerie Fire/Insect Swarm debuff + Starfire交替循环 | 2026-06-19 | c7549ff | [260619-qbj-add-faerie-fire-insect-swarm-debuff-and-](./quick/260619-qbj-add-faerie-fire-insect-swarm-debuff-and-/) |
| 260620-gpw | burstMod/atkPowerBurst 存在性守卫 (Berserk技能+Trinket2饰品槽) | 2026-06-20 | 7f03c82 | [260620-gpw-catatk](./quick/260620-gpw-catatk/) |
| 260620-j2p | Opener血量阈值+法力药水阈值改为level-adaptive | 2026-06-20 | af283bd | [260620-j2p-opener-mana-level-adaptive](./quick/260620-j2p-opener-mana-level-adaptive/) |
| 260623-wrh | Druid技能诊断打印函数 printDruidDiag | 2026-06-23 | f1bba57 | [260623-wrh-druid](./quick/260623-wrh-druid/) |
| 260627-g4j | 修复 spell_trace_immune.lua 日志问题 | 2026-06-27 | fef6f2f | [260627-g4j-1-3](./quick/260627-g4j-1-3/) |
| 260707-x3d | 修复catLeveling OOC+CP=5时无技能释放的bug | 2026-07-07 | 5162d02 | [260707-x3d-catleveling-ooc-cp-5-bug](./quick/260707-x3d-catleveling-ooc-cp-5-bug/) |
| 260725-s1v | getMinimumAffordableAbilityCost重命名+earning日志字段 | 2026-07-25 | c371482 | [260725-s1v-reshift-minabilitycost-nextabilitycost-r](./quick/260725-s1v-reshift-minabilitycost-nextabilitycost-r/) |
| 260801-akl | 修复 druidBuffs 自我施法和 casterAtk 自动攻击 | 2026-08-01 | 605531b | [260801-akl-druid-buffs-caster-atk-fix](./quick/260801-akl-druid-buffs-caster-atk-fix/) |
| 260802-remove-rough-param | 从 druid 一键宏链路中移除已废弃的 rough 参数 | 2026-08-02 | b4bf3a3 | [260802-remove-rough-param](./quick/260802-remove-rough-param/) |
| 260804-0bz | Pounce duration/ERPS 适配 Idol of Savagery | 2026-08-04 | c6f83a7 | [260804-0bz-fix-pounce-savagery-duration](./quick/260804-0bz-fix-pounce-savagery-duration/) |
| 260806-0y9 | 修复 druid 猫/熊形态下法力药水误消耗 | 2026-08-06 | ac8d30d | [260806-0y9-fix-druid-mana-potion](./quick/260806-0y9-fix-druid-mana-potion/) |
| 260808-t3w | druid cower otMod guard — hasNearbyGroupMates 附近队友检查 | 2026-08-08 | 601160c | [260808-t3w-druid-cower-otmod-guard-hasnearbygroupma](./quick/260808-t3w-druid-cower-otmod-guard-hasnearbygroupma/) |
| 260810-fix-cower-raid | otMod guard 同时支持 raid（isInGroup → isInGroup or isInRaid） | 2026-08-10 | e917b88 | [260810-fix-druid-cower-raid-guard](./quick/260810-fix-druid-cower-raid-guard/) |
| 260817-sg1 | macroTorch.log 持久化格式简化：{msg, color} table → 纯文本 string | 2026-08-17 | 5ff2233 | [260817-sg1-simplify-macrotorch-log-persistence-stor](./quick/260817-sg1-simplify-macrotorch-log-persistence-stor/) |
| 260823-gg8 | 更新 catAtk-core-principles.md：补充 Phase 26 新增的「速战」(fast battle, 8.5s) 战斗分层，保持精华风格不写实现细节 | 2026-08-23 | 84af982 | [260823-gg8-planning-catatk-core-principles-md-phase](./quick/260823-gg8-planning-catatk-core-principles-md-phase/) |
| 260825-s3v | 修复 catAtk OoC 帧绕过泄能直接免费咬的路径：cp5Bite 泄能尝试后 OoC 守卫 return + energyDischargeBeforeBite 帧内 isDischarged 去重 | 2026-08-25 | ad093c9 | [260825-s3v-catatk-ooc-ferocious-bite-cp5bite-energy](./quick/260825-s3v-catatk-ooc-ferocious-bite-cp5bite-energy/) |
| 260825-t86 | 统一修复泄能绕过 bug（洞 A/B 收尾）：energyDischargeBeforeBite 返回是否发起泄能尝试，cp5Bite 在泄能帧一律延迟咬击判定，新增 P 自测固化 | 2026-08-25 | 96e55d1 | [260825-t86-catatk-bug-a-b-r-locked-energydischargeb](./quick/260825-t86-catatk-bug-a-b-r-locked-energydischargeb/) |
| 260825-vp9 | 修复 code review WR-01/IN-01：quickKeepRip 接入泄能布尔契约（泄能尝试帧延迟咬击）+ 新增泄能条件未命中落穿活性的 P 自测 | 2026-08-25 | 592284c | [260825-vp9-fix-code-review-findings-wr-01-in-01-qui](./quick/260825-vp9-fix-code-review-findings-wr-01-in-01-qui/) |
| 260830-45g | Phase 27 UAT 反馈小修复：绿色 landed 确认日志挪到 recordLandEvent 之前，打印顺序符合因果序（FB landed 先于 Renewing rake/rip） | 2026-08-30 | 194d907 | [260830-45g-phase-27-uat-aura-apply-landed-recordlan](./quick/260830-45g-phase-27-uat-aura-apply-landed-recordlan/) |
| 260831-24c | target 对象新增 clear() 方法：宏随时调用 macroTorch.target.clear() 清空当前目标持久化的 immune/definite 记录，无目标时静默跳过 | 2026-08-31 | 6f22a48 | [260831-24c-target-clear](./quick/260831-24c-target-clear-macrotorch-target-clear-imm/) |
| 260907-0ya | 新增 macroTorch.cpBuildLog 布尔开关(默认 false)：开启后 Claw/Shred/Rake 施放经 macroTorch.log 打点持久化，用于打桩测量攒星攻击间隔辅助双保判据 | 2026-09-07 | 90ef069 | [260907-0ya-macrotorch-false-true-macrotorch-log](./quick/260907-0ya-macrotorch-false-true-macrotorch-log/) |
| 260914-0ql | cp5Bite 新增 1.3s 保 rake 跳过泄能条件（与 2.3s 保 rip 平行）：rake 在场且剩余 <=1.3s 时放弃泄能/泄 ooc 直接 bite 以续 rake，单文件 6 行纯插入 | 2026-09-14 | e776e98 | [260914-0ql-cp5bite-1-3s-rake-2-3s-rip-rake-1-3s-ooc](./quick/260914-0ql-cp5bite-1-3s-rake-2-3s-rip-rake-1-3s-ooc/) |
| 260907-sz4 | 登录/reload 后 selftest 末尾打印全局配置项横幅（CONFIG_OPTIONS 注册表：cpBuildLog + rawdiag2Enabled，含默认值与设置命令） | 2026-09-07 | 219071a | [260907-sz4-reload-selftest-macro-torch-lua-config-o](./quick/260907-sz4-reload-selftest-macro-torch-lua-config-o/) |
| 260907-mhh | RAWDIAG2 Rip landing 取证插桩（多猫 landing 抑制就地验证）：RAW_COMBATLOG 白名单前 scout + pair ledger + safeRip 决策戳，纯增量 | 2026-09-07 | 953bd50 | [260907-mhh-rip-landing-rawdiag-forensics-build-1-co](./quick/260907-mhh-rip-landing-rawdiag-forensics-build-1-co/) |
| 260907-tuh | Cower 世界首领仇恨阈值可配置化：Druid.lua:909 硬编码赋值迁移为 macro_torch.lua nil-guard 默认 75 + CONFIG_OPTIONS 第三项进登录横幅，/run 会话级覆盖 | 2026-09-07 | 1a8bb19 | [260907-tuh-cower-threat-threshold-75](./quick/260907-tuh-cower-threat-threshold-75/) |
| 260907-vve | macroTorch.log 持久化上限可配置化：新增 macroTorch.LOG_MAX_SIZE nil-guard 默认 500 + CONFIG_OPTIONS 第四项进横幅，裁剪上限改读带 tonumber+clamp 净化的局部值（0/负数钳到 1，非法值回落 500）+ Cat T-01 自测，per-session 语义 | 2026-09-07 | cb0fcd3 | [260907-vve-add-macrotorch-log-max-size-global-confi](./quick/260907-vve-add-macrotorch-log-max-size-global-confi/) |
| 260909-2kd | 移除 RAWDIAG2 侦察器 150 行采集上限：只保留 60s 时间窗口 disarm（混战中 'fades' 噪声 ~24s 即触顶、浪费 CD 取证机会；LOG_MAX_SIZE 已上调 2000 兜底音量），_rawdiag2Lines 计数保留用于 dump 统计 | 2026-09-09 | 139250b | [260909-2kd-rawdiag2-forensics-scout-150-150-24-fade](./quick/260909-2kd-rawdiag2-forensics-scout-150-150-24-fade/) |
| 260909-4ep | 删除 RAWDIAG2 scout 的 60s 时间窗 disarm 门：窗口从玩家 Rip 施放（arm）持续到 combat exit（context 出战斗清空、每场战斗一个窗口）；rotation 每场只放一次 Rip（其余靠 FB 刷新），时间门会静默截断长战斗的后续取证 | 2026-09-09 | 69a0954 | [260909-4ep-rawdiag2-scout-60s-disarm-rip-arm-combat](./quick/260909-4ep-rawdiag2-scout-60s-disarm-rip-arm-combat/) |
| 260909-w3r | 移除 RAWDIAG2 取证插桩：主开关与横幅条目（5→4 项）、safeRip 决策戳、combat-log scout、arming hook、intent-depth 助手、pair 账本全部删除；多猫仲裁改由统一 landing 方案在两种假设下自洽，取证装置失去存在必要 | 2026-09-09 | c383f34 | [260909-w3r-rawdiag2-forensics-instrumentation-remov](./quick/260909-w3r-rawdiag2-forensics-instrumentation-remov/) |
| 260910-ilu | catAtk 原则文档 9 处裁决修订（B1 worldboss 圣物限定/B3 畏缩范围/A3 规则2 净收益/A4 erps>0/A5 规则4 门对齐/A6 自动攻强推广/B4 猛虎独立 GCD 注记/移除定义位置列与 SelfTest ID 表）+ 斩杀期 FF 等待窗排除门（shouldCastFFDuringWaitWindow 加 isKillShotOrLastChance，对齐规则 9） | 2026-09-10 | a810f6e | [260910-ilu-catatk-ff-code-1-shouldcastffduringwaitw](./quick/260910-ilu-catatk-ff-code-1-shouldcastffduringwaitw/) |
| 260912-0kg | Reshift/FF 两条通告行颜色微调：macroTorch.show 新增 coffee（浅咖啡）+ violet（浅紫红，FF 图标色）自定义色臂，纯渲染层零判定改动 | 2026-09-12 | e4de202 | [260912-0kg-reshift-cat-lua-readyreshift-rgb-0-82-0-](./quick/260912-0kg-reshift-cat-lua-readyreshift-rgb-0-82-0-/) |
| 260913-2wo | 修复 tools/cpdamage.lua 的 --json-out 输出为严格 JSON（G-28-5）：新增 encodeKey 数字键加引号 + 2 项自检断言（33→35），5.0/5.1/5.4 三解释器全绿，Node JSON.parse 端到端通过，屏显输出字节级不变 | 2026-09-13 | 1b62f12 | [260913-2wo-tools-cpdamage-lua-json-out-json-g-28-5-](./quick/260913-2wo-tools-cpdamage-lua-json-out-json-g-28-5-/) |
| 260913-46s | 为 tools/cpdamage.lua 添加 CC 咬决策常量自动计算块（OOC-Bite Criteria：R*(A/B)/R*(D/B) 翻转阈值 + 可选 --erps <N> 参数 + --json-out 同步块；E/S/C/β 读取点按 28-OOC-BITE-CRITERIA.md；selftest 35→55 三解释器全绿，Node 严格 JSON 与屏显 additive 零删除双口径门通过，宏本体 11 字段 schema 零改动；code review 0C/2W/3I，WR-01 --erps inf/nan 穿透、WR-02 rDB nil 守卫不对称经三解释器复现实证后修复 94f17b7/e042f9f） | 2026-09-13 | a8e7852 | [260913-46s-tools-cpdamage-lua-cc-decisions-additive](./quick/260913-46s-tools-cpdamage-lua-cc-decisions-additive/) |
| 260914-1t0 | 修复 260914-0ql code review WR-01：vp9 no-discharge liveness pin 补 rakeLeft stub（返回 9 > 1.3 使 rake 门不触发，恢复真实能量泄能路径）；新增 Category P「rake <=1.3s 跳过泄能直接咬」续期 pin，自测数 8→9 | 2026-09-14 | 418d664 | [260914-1t0-fix-quick-260914-0ql-code-review-wr-01-t](./quick/260914-1t0-fix-quick-260914-0ql-code-review-wr-01-t/) |
| 260914-3vh | 原则文档 4 处修订（untracked，仅工作树）：规则 3 例外扩为双流血保护（扫击 ≤1.3s 门入册 + 阈值非对称理由）；规则 8 补非斩杀排除；附录 B 补 1.3s 常量行；时间戳 09-14 | 2026-09-14 | — | [260914-3vh-revise-planning-catatk-core-principles-m](./quick/260914-3vh-revise-planning-catatk-core-principles-m/) |
| 260914-49l | 防御缺口 B1 修复：energyDischargeBeforeBite 显式斩杀豁免（规则 9 由 GCD 隐式兜底改为显式短路，5 行纯插入）+ Category P 第 10 项 kill-shot 泄能 pin，计数 9→10 | 2026-09-14 | d7a24ed | [260914-49l-fix-defense-gap-b1-killshot-frames-have-](./quick/260914-49l-fix-defense-gap-b1-killshot-frames-have-/) |
| 260914-nth | OoC 帧 cp builder 裁决落地：3+ 流血免费帧（OoC/伪无限能量）+背后改打撕碎（采样裁决：撕碎非暴击单发 507.3 > 3流血爪击 483.5）；R6-05 重写 + R6-05b 付费帧 pin + getNextAbilityCost 析出 pin；原则文档规则 6 同步修订（untracked）；code review 0C/2W/2I 经真伪筛查后 2W 全部修复：WR-02 无限能量字段 nil 契约以 989 行归一 + R6-05c pin 修复 f0dc226、WR-01 FF 等待窗 0 能量精华帧行为差以 selftest pin 显式接受 0db2f43（REVIEW-FIX 2/2 verified-and-fixed） | 2026-09-14 | c1f4e67 | [260914-nth-per-2026-09-14-sample-verdict-ooc-frame-](./quick/260914-nth-per-2026-09-14-sample-verdict-ooc-frame-/) |
| 260914-u4l | FF 见缝插针覆盖审查收敛：shouldCastFFDuringWaitWindow 排除表新增 prowling 臂（潜行帧禁 FF 填充防破潜毁 Pounce/Ravage 先手，补齐与 keepRake isFightStarted、oocMod prowling 守卫的不对称）+ selftest 潜行拒绝 pin（WR-01 razor edge 帧镜像，修复前必红方向型）；tiger 潜行提前放经复核为有意设计、rake 已有 isFightStarted 守卫，均不涉改 | 2026-09-14 | b0a610a | [260914-u4l-ff-shouldcastffduringwaitwindow-prowling](./quick/260914-u4l-ff-shouldcastffduringwaitwindow-prowling/) |
| 260915-tt3 | 创建 energy tick 相位取证探针（实机调研）：新增 classes/druid/energy_probe.lua 探针模块 + build_order.txt 加行 + core/events.lua RAW/UNIT_CASTEVENT 两处 flag 门控透传 + cat.lua readyReshift 释放点日志 | 2026-09-15 | d9319f2 | [260915-tt3-energy-tick-classes-druid-energy-probe-l](./quick/260915-tt3-energy-tick-classes-druid-energy-probe-l/) |
| 260915-udx | energy tick 探针改为重用 macroTorch.log：删除 probeTick 独立存储桶与 energyProbeLog 包装函数，探针文件内部与 events.lua/cat.lua 三处门控写入点全部直调 macroTorch.log（屏幕显式输出 + 既有持久化/裁剪机制），守卫简化为 energyProbe 单开关 | 2026-09-15 | a80fe39 | [260915-udx-energy-tick-macrotorch-log-probetick-ene](./quick/260915-udx-energy-tick-macrotorch-log-probetick-ene/) |
| 260915-uzs | energy tick 取证探针扩展 PDT 通道：RAW_COMBATLOG 两个 periodic 通道（creature/hostileplayer）全量 tick 行以 EPR|PDT(tx=RAW) 落 macroTorch.log，同名 chat 通道再落 EPR|PDT(tx=CHAT) 双传输比对到达时序；无法术白名单，所有可检测 periodic tick 事件全量落盘供离线分析 | 2026-09-15 | 344a81a | [260915-uzs-energy-tick-pdt-raw-combatlog-periodic-c](./quick/260915-uzs-energy-tick-pdt-raw-combatlog-periodic-c/) |
| 260916-0hh | 修复 260915-uzs 评审 WR-01/02/03：RAW tap 'nergize' 匹配改 string.lower 大小写不敏感（任意 casing 全捕获）；EV 行裸事件名移为 t= 后 ev= KV 恢复 8 线路型 EPR\|TYPE\|t= 固定列契约；两处 UnitMana e 补 nil 守卫 + POLL d 补 floor | 2026-09-16 | 69c2e4b | [260916-0hh-fix-260915-uzs-review-warnings-wr-01-02-](./quick/260916-0hh-fix-260915-uzs-review-warnings-wr-01-02-) |

- [Phase 21-02]: D-04: Field named isPseudoInfiniteEnergy — emphasizes approximate (erps >= SHRED_E) semantics
- [Phase 21-02]: D-05: Computation in catAtk() after clickContext init, before module calls — each keystroke rebuilds clickContext, guaranteeing freshness
- [Phase 21-02]: D-06: All 5 explicit comparisons replaced (oocMod, cp5Bite, energyDischargeBeforeBite, dischargeEnergyChangeRelicAndRip, shouldUseShred), local erps retained where needed for overflow calculations
- [Phase 21-02]: D-07: 3 implicit comparisons preserved unchanged — shouldDoReshift, shouldCastFFDuringWaitWindow, recoverNormalRelic express different semantics (energy overflow, not isPseudoInfiniteEnergy)
- [Phase 28]: cpDamage UAT 5/5 全绿闭环（实机 941 样本/52.1min/4 批次，11 字段 0 坏行；SavedVariables 段持久化实证；Category U 9/9）。OOC-bite 推演定案：CC→shred + 泄能再咬 = 现状最优；CC 咬仅 ERPS≥~25 场景更优，基准+校准流程落档 28-OOC-BITE-CRITERIA.md。G-28-5 --json-out 严格 JSON 修复经 quick 260913-2wo 落地（1b62f12）

## Session

**Last session:** 2026-09-12T18:33:15.000Z
**Stopped at:** Phase 28 complete (UAT 5/5 + verification passed + VALIDATION + SECURITY), ready to plan Phase 29
**Resume file:** None
