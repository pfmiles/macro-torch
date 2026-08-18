# Phase 25: Hunter 一键宏改造 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-18
**Phase:** 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol
**Areas discussed:** hunterAtk 设计, 技能覆盖, hunterAoe/hunterDefend/hunterControl, hunterMobTagging

---

## hunterAtk 设计

### 入口策略

| Option | Description | Selected |
|--------|-------------|----------|
| 单入口路由 | hunterAtk 统一入口，按距离自动路由近战/远程，类似 druidAtk → catAtk/bearAtk | ✓ |
| 分离式入口 | hunterAtk 专注远程，hunterMeleeAtk 独立宏 | |

**User's choice:** 单入口路由
**Notes:** 参照 Druid 的形态路由模式，用户只需一个按键

### 模块优先级

| Option | Description | Selected |
|--------|-------------|----------|
| 12 模块链 | 参照 Druid catAtk 的完整优先级链（生存急救→目标选择→自动攻击→爆发→起手→钉刺/标记→主要输出→仇恨管理→...） | ✓ |
| 精简模块链 | 聚焦核心循环 ~6 个模块 | |
| 扩展线性模式 | 保持当前线性风格，按距离展开 | |

**User's choice:** 12 模块链
**Notes:** 参照 catAtk 的 module-priority chain 模式 + clickContext 缓存

### 守护管理

| Option | Description | Selected |
|--------|-------------|----------|
| 自动切换 | 战斗中自动切雄鹰守护、非战斗切猎豹守护、近战切灵猴守护 | |
| 仅战斗守护 | 默认雄鹰，保命宏切灵猴 | |
| 不涉及守护 | 用户手动管理 Aspect 切换 | ✓ |

**User's choice:** 不涉及守护
**Notes:** 一键宏不调用任何守护切换

### 宠物集成

| Option | Description | Selected |
|--------|-------------|----------|
| 深度集成 | 每键 pet.attack + 死亡自动复活 + mend pet | |
| 基础集成 | 仅进战时发起 pet.attack | |
| 不集成宠物 | 用户手动管理宠物 | ✓ |

**User's choice:** 不集成宠物
**Notes:** 宠物管理完全由用户手动控制

---

### Auto Shot 管理

| Option | Description | Selected |
|--------|-------------|----------|
| 每键 startAutoShoot | 每次按键都确保自动射击活跃，类似 Druid 每键 startAutoAtk | ✓ |
| 仅切换目标时 | 只在首次按键或切换目标时启动 Auto Shot | |

**User's choice:** 每键 startAutoShoot
**Notes:** 确保自动射击保持活跃，即使因移动/近战被打断也能快速恢复

### Aimed Shot

| Option | Description | Selected |
|--------|-------------|----------|
| 条件使用 | 非移动 + 距离≥8yd + Auto Shot 活跃时使用 | |
| 不使用 Aimed Shot | 3 秒读条打断 Auto Shot 循环，练级效率低 | |
| Shift 手动触发 | Shift 修饰键手动触发，类似 Druid burstMod | ✓ |

**User's choice:** Shift 手动触发
**Notes:** 放在 burstMod 中，通过 IsShiftKeyDown() 检测

### 陷阱策略

| Option | Description | Selected |
|--------|-------------|----------|
| 不在 hunterAtk | 陷阱完全交给 hunterAoe/hunterControl | ✓ |
| 包含伤害陷阱 | 战斗中自动使用献祭陷阱 | |

**User's choice:** 不在 hunterAtk
**Notes:** 陷阱分属不同宏：伤害陷阱→hunterAoe，控制陷阱→hunterControl

### 距离阈值

| Option | Description | Selected |
|--------|-------------|----------|
| 固定 8yd | WoW 近战攻击最大距离 | ✓ |
| 11yd | 猎人的最适射击下限 | |

**User's choice:** 固定 8yd
**Notes:** 不考虑 5-8yd 死区

---

## 技能覆盖

### 文件结构

| Option | Description | Selected |
|--------|-------------|----------|
| Druid 对齐 | Hunter.lua（类+技能+SelfTest）+ combo.lua（5 个一键宏） | ✓ |
| 保持 3 文件 | Hunter.lua + combat.lua + utility.lua 但重写 | |
| 合并为 2 文件 | Hunter.lua + combo.lua（合并 combat+utility） | |

**User's choice:** Druid 对齐
**Notes:** 参照 Druid 的文件组织方式

### 技能清单

| Option | Description | Selected |
|--------|-------------|----------|
| 全面覆盖 | ~15 个新方法：核心战斗（Aimed Shot/Scorpid Sting/Viper Sting/Auto Shot）+ 陷阱（3）+ 生存（Deterrence/Feign Death）+ 宠物（Mend Pet/Revive Pet）| ✓ |
| 按需添加 | 只加 hunterAtk 直接使用的：Aimed Shot/Scorpid Sting/Auto Shot | |
| 最全列表 | 补充 Viper Sting/Eagle Eye/Track * 等 | |

**User's choice:** 全面覆盖
**Notes:** 用户补充：当前 Hunter 代码是过时的测试代码，需要推倒重来

### SpellTrace

| Option | Description | Selected |
|--------|-------------|----------|
| 关键 debuff | Serpent Sting + Scorpid Sting 的 land tracing | ✓ |
| 保持现状 | 仅 Serpent Sting | |

**User's choice:** Serpent Sting + Scorpid Sting 的 land tracing
**Notes:** 目的是 trace landing 以区分自己的钉刺 vs 其他猎人的钉刺。Immune 检测已有自动机制。Hunter's Mark 不需要。

### SelfTest

| Option | Description | Selected |
|--------|-------------|----------|
| 参照 Druid | 技能方法存在性 + 一键宏存在性，~25-30 tests | ✓ |
| 最简测试 | 仅类定义/FIELD_FUNC_MAP/注册 | |

**User's choice:** 参照 Druid
**Notes:** isOptional=true + UnitClass('player') ~= 'Hunter' guard

---

## hunterAoe / hunterDefend / hunterControl

### hunterAoe

| Option | Description | Selected |
|--------|-------------|----------|
| 距离路由 | 远程≥8yd：Multi-Shot + Volley，近战<8yd：Explosive Trap + Immolation Trap | ✓ |
| 纯远程 AoE | 始终优先远程 AoE，不分近战距离 | |
| 最简方案 | 仅 Multi-Shot（远程）或 Explosive Trap（近战） | |

**User's choice:** 距离路由
**Notes:** 参照 Druid druidAoe 形态路由模式

### hunterDefend

| Option | Description | Selected |
|--------|-------------|----------|
| 降仇+减伤链 | Feign Death → Deterrence → Disengage | |
| 最简生存 | 仅 Feign Death → Disengage | |

**User's choice:** 仅 Deterrence
**Notes:** 用户明确：只有 Deterrence，Feign Death 不算减伤技能。极简实现 ~5 行。

### hunterControl

| Option | Description | Selected |
|--------|-------------|----------|
| 距离路由 | 近战<8yd：Wing Clip/Freezing Trap，远程≥8yd：Concussive Shot/Scatter Shot | ✓ |
| 统一优先级 | 统一 Concussive Shot → Wing Clip → Freezing Trap | |

**User's choice:** 距离路由
**Notes:** 参照 Druid druidControl 距离分支模式

### 陷阱分配

| Option | Description | Selected |
|--------|-------------|----------|
| 分属不同宏 | hunterAoe：伤害陷阱（Explosive/Immolation），hunterControl：控制陷阱（Freezing） | ✓ |
| 统一在 Control | 所有陷阱统一在 hunterControl 中 | |

**User's choice:** 分属不同宏
**Notes:** 每个陷阱专属它的宏

---

## hunterMobTagging

### 远程抢怪

| Option | Description | Selected |
|--------|-------------|----------|
| Arcane Shot R1 | 瞬发、最低法力消耗、30码 | ✓ |
| Serpent Sting R1 | 瞬发 DoT、tag 确认性更强 | |

**User's choice:** Arcane Shot rank 1
**Notes:** 参照 Druid 用 Moonfire rank 1 抢怪

### 近战抢怪

| Option | Description | Selected |
|--------|-------------|----------|
| 普攻 | startAutoAtk 触发自动攻击 | |
| 普攻 + Raptor Strike | 普攻附加伤害 | |
| 摔绊 (Wing Clip) | 瞬发近战直伤 + 减速 | ✓ |

**User's choice:** 摔绊 (Wing Clip)
**Notes:** 瞬发近战直伤。比普攻更可靠，附带减速效果。

### PvP 过滤

| Option | Description | Selected |
|--------|-------------|----------|
| 过滤玩家 | 选到玩家目标时 ClearTarget() | ✓ |
| 不过滤 | 不区分 PvE/PvP | |

**User's choice:** 过滤玩家
**Notes:** 参照 druidMobTagging 的二次确认模式

### 输出衔接

| Option | Description | Selected |
|--------|-------------|----------|
| 自动衔接 | tag 成功后自动调用 hunterAtk 进入正常输出 | ✓ |
| 只抢不输出 | 抢怪宏只负责 tag | |

**User's choice:** 自动衔接
**Notes:** 参照 druidMobTagging 的 tag → druidAtk 模式

---

## Claude's Discretion

- 12 个模块的具体命名、优先级顺序和实现细节
- clickContext 缓存字段的具体设计
- 技能方法的 mode 参数行为（'ready' vs 'safe' vs 'raw'）
- Aimed Shot Shift 触发在 burstMod 中的具体检查条件
- hunterAoe/hunterControl 中具体的优先级链和回退逻辑
- hunterMobTagging 中目标有效性检查的细粒度守卫条件
- SelfTest 测试用例的具体 assert 措辞
- combo.lua 中的注释风格和模块分隔

## Deferred Ideas

- Aspect 守护自动切换（战斗中雄鹰/非战斗猎豹/近战灵猴）— 未来 phase
- 宠物深度管理（自动 Mend Pet/Revive Pet/Call Pet）— 未来 phase
- Feign Death 集成到宏中 — 用户认为不属于减伤技能
- Intimidation（BM 天赋）— hunterControl 中未包含
- Viper Sting 自动使用 — 技能方法已定义但暂不自动
- 练级版 hunterAtk（参照 catLeveling + 技能存在性检查）— 后续 phase