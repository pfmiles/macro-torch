# catAtk 核心设计原则

> **ADR-001: catAtk 核心设计原则**
>
> 本文档记录了猫德猫形态一键宏 `catAtk()` 的核心设计原则。这些规则来源于实测经验和数据分析，服务于单一目标：**最大化猫德 DPS**。
>
> 当前的 Lua 实现（`classes/druid/combo.lua`、`classes/druid/cat.lua`、`classes/druid/Druid.lua`）是**满足这些声明式规则的一种过程式解法**——其他等价的实现（不同的模块排序、不同的分支结构）也能满足同样的规则集。

---

## 统一目标函数

> **每一帧，在生存和仇恨约束的前提下，选择能使 `伤害输出 / (GCD + 等待时间)` 最大化的动作。**

所有子规则都是该目标函数在不同边界条件下的特化。

---

## 1. 能量经济学

猫德能量池固定上限 100，基础恢复速度为 20 能量 / 2 秒（10 erps）。所有决策本质上都受能量约束。

### 规则 1：溢出预防

**原则：** 当一个动作的执行会导致能量在 GCD 窗口期间超过 100 时，先将溢出能量释放为有效伤害。

```
IF  currentEnergy + erps * gcdDuration - skillCost > 100
AND erps < maxSkillCost                    -- 无限能量场景下溢出无法避免
THEN discharge() BEFORE mainAction()
```

| 相关函数 | 说明 |
|----------|------|
| `energyDischargeBeforeBite` (`cat.lua`) | 撕咬前泄能：撕碎/爪击 或 扫击 |
| `dischargeEnergyChangeRelicAndRip` (`cat.lua`) | 割裂前泄能 |
| `cp5Bite` (`cat.lua`) | 5 星撕咬前的泄能决策 |

**例外：** 当 `erps >= SHRED_E`（无限能量场景，如红龙精华 +50 erps）时，跳过泄能——溢出不可避免，泄能只会浪费 GCD。

**参考：** `computeErps` (`Druid.lua`)

---

### 规则 2：能量饥渴避免 — 变身回能

**原则：** 当能量不足以释放下一个最优技能时，比较"自然回能时间"与"变身 GCD（1.5s）"：
- 自然回能 ≤ 1.5s → 等待（避免浪费变身 GCD）
- 自然回能 > 1.5s → 变身（利用本来就需要等待的空闲 GCD）

```
IF  math.ceil(projectedEnergy(1.5s)) < nextAbilityCost    -- 1.5s 回能仍不够
AND isInCombat                                   -- 仅在战斗中
AND NOT prowling                                 -- 不打破潜行
AND NOT ooc                                      -- 不浪费清晰预兆
AND NOT isKillShot                               -- 不延迟斩杀
AND reshiftEnergy > 0                            -- 有野性之心天赋或狼心附魔
THEN reshift()
ELSE wait()                                      -- 自然回能更快
```

| 相关函数 | 说明 |
|----------|------|
| `shouldDoReshift` (`cat.lua`) | 核心变身决策逻辑 |
| `computeReshiftEnergy` (`Druid.lua`) | 野性之心天赋（每级 +8）+ 狼心附魔（+20） |

**核心洞察：** 变身回能的问题不在于"我能量是否低了？"，而在于**"哪条路径能更快地让我放出下一个技能？"**。如果自然回能 1.5s 已经能覆盖缺口，变身的 GCD 就是纯浪费。

**例外（以下情况不做变身）：**
- 不在战斗中
- 潜行中（潜行状态）
- 清晰预兆（OoC）激活
- 斩杀/最后机会阶段
- 变身回能为 0（无野性之心天赋且无狼心附魔）

---

### 规则 3：撕咬能量转化效率

**原则：** 凶猛撕咬将多余能量转化为额外伤害的转化比率**低于**将这些能量用于独立技能（撕碎/爪击/扫击）。撕咬前应始终先泄能。

| 相关函数 | 说明 |
|----------|------|
| `energyDischargeBeforeBite` (`cat.lua`) | 撕咬前泄能实现 |

**例外 — 割裂保护优先于泄能：**
撕咬会刷新目标身上的割裂持续时间。若割裂剩余 ≤ 2.3s，跳过泄能立即撕咬，防止割裂断档（见 `cp5Bite`，`cat.lua`）。

---

## 2. 流血协同

### 规则 4：流血优先于直接伤害

**原则：** 5 星割裂是持续战斗中价值最高的终结技。5 星连击点仅在割裂已存在（或目标免疫流血）时才用于撕咬。

```
IF  comboPoints == 5
AND NOT isImmuneRip
AND NOT isRipPresent
THEN rip()              -- 优先级高于 bite()
```

| 相关函数 | 说明 |
|----------|------|
| `cp5Bite` (`cat.lua`) | 门条件：仅在 `isImmuneRip OR isRipPresent` 时进入撕咬路径 |
| `shouldCastRip` (`Druid.lua`) | 正常战：仅在 `cp >= 5` 时割裂 |
| `keepRip` (`cat.lua`) | 割裂模块入口 |

---

### 规则 5：时长自适应割裂策略

**原则：**
- **正常（长）战斗：** 仅打 5 星割裂，最大化流血总伤害。循环：攒到 5 星 → 割裂 → 攒到 5 星 → 撕咬（刷新割裂） → 重复。
- **快战（短）战斗 / PvP：** 打 1-2 星低星割裂。目的不是流血伤害本身，而是激活远古兽性回能 + 爪击流血加成。3 星及以上直接撕咬效率更高。

```
IF  isTrivialBattle OR isPvP OR rough:
    IF  cp IN [1, 2] AND NOT isRipPresent → rip()
    IF  cp >= 3 AND NOT isRipPresent     → bite()    -- 低星撕咬 > 低星割裂
ELSE:
    IF  cp >= 5 AND NOT isRipPresent → rip()          -- 仅 5 星割裂
```

| 相关函数 | 说明 |
|----------|------|
| `shouldCastRip` (`Druid.lua`) | 连击点要求分叉（1-2 vs 5） |
| `quickKeepRip` (`cat.lua`) | 快战割裂逻辑 |
| `keepRip` (`cat.lua`) | 正常割裂逻辑 |
| `isTrivialBattle` (`Druid.lua`) | 战斗时长预测（25s 阈值 + DPS 估算） |

**核心洞察：** 在短战中，割裂的投资回报周期太长——目标在割裂跳完前就死了。割裂从"伤害技能"降级为"辅助技能"——存在的唯一意义是激活流血相关增益。

---

### 规则 6：流血数量决定攒星技能选择（撕碎 vs 爪击）

**原则：** 撕碎与爪击的选择基于目标身上的流血数量，由**实测 DPE（单能量伤害）数据**支撑：

| 流血数量 | 决策 | 理由 |
|----------|------|------|
| 0-1 | 撕碎（在背后时） | 撕碎 DPE > 爪击 DPE |
| 2 | 爪击（除非 OoC 或无限能量） | 爪击 DPE > 撕碎 DPE；撕碎仅在免费时胜出（OoC/无限能量） |
| 3+ | 始终爪击 | 爪击在原始伤害和 DPE 上均超过撕碎 |

```
IF  bleedCount <= 1:
    useShred IF (ooc OR infiniteEnergy OR energyRecoversFast) AND isBehind
IF  bleedCount == 2:
    useShred IF (ooc OR infiniteEnergy) AND isBehind
IF  bleedCount >= 3:
    useClaw
```

| 相关函数 | 说明 |
|----------|------|
| `shouldUseShred` (`Druid.lua`) | 撕碎 vs 爪击决策树 |
| `regularAttack` (`cat.lua`) | 调用 `shouldUseShred` 执行攒星技能 |

**无限能量阈值：** `erps >= SHRED_E`（在 `shouldUseShred` 中检查）

**能量恢复速度优化：**
当 `bleedCount <= 1` 且 1 秒内自然回能 ≥ 爪击消耗（`erps * 1 >= CLAW_E`）时，优先用撕碎。理由：能量恢复速度足够快，撕碎的高伤害可以防止能量溢出——与其等能量满了溢出，不如用撕碎消耗更多能量换取更高伤害。

```
IF  bleedCount <= 1
AND erps * 1 >= CLAW_E
AND isBehind
THEN useShred()             -- 能量回收快 → 撕碎防溢出 + 高伤害
```

**加速攒星优化（首次割裂前）：**
当割裂不存在、非快战、目标不免疫流血时，优先级从"最大化每 GCD 伤害"（撕碎）切换为"最大化连击点生成速度"（爪击）。爪击更便宜，CP 生成更快，能更快到达 5 星割裂。割裂施放后，`shouldUseShred` 恢复到标准的流血数量决策树。

```
IF  NOT isTrivialBattleOrPvp
AND NOT isImmuneRip
AND NOT isRipPresent
THEN useClaw()              -- 覆盖标准的 bleedCount 决策
```

---

## 3. GCD 经济学

### 规则 7：严格 GCD 优先级顺序

**原则：** 每个 GCD 仅允许一个动作。当多个动作同时可用时，按价值降序排列：

```
斩杀撕咬(任意星数)             -- 目标即将死亡，有星就咬
  > 撕咬(5星+割裂已存在)       -- 5 星且割裂已在目标身上
  > 割裂(5星)                  -- 5 星且割裂不存在（见规则 4）
  > 猛虎之怒(重新施放)          -- 维持猛虎 buff
  > 扫击(重新施放, <5星)        -- 维持扫击流血（但绝不在 5 星时——浪费连击点）
  > 撕碎/爪击(攒星)             -- 见规则 6
  > 精灵之火(填充等待窗口)       -- 仅在等待能量时（见规则 8）
  > 变身回能(等待>GCD时)        -- 见规则 2
```

| 相关函数 | 说明 |
|----------|------|
| `catAtk` (`combo.lua`) | 模块调用顺序 |
| `getNextAbilityCost` (`Druid.lua`) | 技能耗能查找顺序（供变身回能逻辑使用） |
| `shouldUseBite` (`Druid.lua`) | 撕咬触发条件 |

**关键约束 — 5 星时禁止释放任何攒星技能：**
扫击、撕碎和爪击均为攒星技能。在 5 星时释放任何攒星技能都会浪费本可用于终结技的连击点。因此：
- `keepRake` (`cat.lua`) 在 `comboPoints == 5` 时立即返回
- `regularAttack` (`cat.lua`) 在 `catAtk` 主流程中被 `comboPoints < 5` 门控

---

### 规则 8：等待窗口利用 — 精灵之火填充

**原则：** 当被迫等待能量回复，且等待时长 ≥ 1s 时，用精灵之火（野性）填充等待窗口。精灵之火不消耗能量——在本来无事可做的空闲时间里"免费"做了有用的事。

```
IF  projectedEnergy(1.5s) >= nextAbilityCost    -- 自然回能足够
AND currentEnergy < nextAbilityCost              -- 但能量还不够，必须等待
AND waitTime >= 1.0s                             -- 等待时间足够覆盖精灵之火的 1s GCD
AND NOT ooc                                      -- 不浪费清晰预兆
AND NOT isImmuneFF                               -- 目标不免疫
AND NOT shouldDoReshift                          -- 等待比变身回能更划算
THEN ff()
```

| 相关函数 | 说明 |
|----------|------|
| `shouldCastFFDuringWaitWindow` (`Druid.lua`) | 精灵之火填充决策 |
| `keepFF` (`cat.lua`) | 精灵之火模块入口 |

**为何不在能量充裕时主动补精灵之火：**
精灵之火消耗 1 个 GCD。如果有伤害技能（撕碎/爪击/撕咬）可用，精灵之火会挤占 1 个输出 GCD → 个人 DPS 损失。精灵之火仅在**无事可做**（等待能量）时才是"免费"的。

**已知限制：** 在无限能量场景（如红龙精华）下，等待窗口永不存在 → 精灵之火永不施放。团队需要依赖其他德鲁伊提供精灵之火覆盖。

**未来优化（待评估）：**
```
[FUTURE] 主动精灵之火维护：
  WHEN FF_debuff_absent
   AND energy + erps * 1s <= 100       -- 施放精灵之火不会导致能量溢出
   AND NOT wouldDelayPrioritySkill()    -- 不会延迟更高优先级的动作
  THEN castFF()
  -- 收益窗口窄；边际收益需要实测验证
```

---

## 4. 斩杀逻辑

### 规则 9：斩杀优先级反转

**原则：** 当目标即将死亡（≤ 2s 预测 或 血量低于斩杀阈值）时，所有 debuff 维护、泄能、变身回能逻辑全部暂停。唯一目标：在目标死亡前将现有连击点转化为撕咬伤害。

```
IF  isKillShotOrLastChance:
    IF  cp > 0 → bite('raw')     -- 有星就咬，忽略能量消耗
    ELSE → regularAttack()        -- 没星只能先攒一个
    -- 跳过：割裂、扫击、精灵之火、泄能、变身回能、仇恨管理
```

| 相关函数 | 说明 |
|----------|------|
| `tryBiteKillShot` (`cat.lua`) | 斩杀入口 |
| `isKillShotOrLastChance` (`Druid.lua`) | 斩杀检测（HRPS 预测 + 等级自适应阈值） |

**双路径斩杀检测：**
1. **HRPS 预测（主路径）：** 目标将在 2 秒内死亡
2. **等级自适应阈值（回退路径）：** 世界boss团本：cp ≥ 3 AND HP% ≤ 2%；普通目标：HP < `getKSThreshold()`

---

## 5. 生存约束

### 规则 10：仇恨感知

**原则：** 死亡 = 0 DPS。在世界boss战斗中监控仇恨：

```
IF  isWorldboss AND isAttackingMe AND NOT cowerReady → 无敌药水
IF  isWorldboss AND threatPercent >= 75%             → 畏缩
IF  isKillShot → 跳过仇恨管理                          -- 战斗即将结束，不浪费 GCD
```

| 相关函数 | 说明 |
|----------|------|
| `otMod` (`cat.lua`) | 仇恨管理模块 |
| `COWER_THREAT_THRESHOLD` (`Druid.lua`) | 仇恨阈值 = 75% |

**注意：** 仇恨管理仅在组队 + 世界boss场景激活。单人游戏和训练木桩被排除在外。

---

### 规则 11：紧急生存

**原则：** 当 HP < 15% 时，优先使用救命消耗品（治疗石 > 治疗药水），自动在生存和 DPS 之间切换。

| 相关函数 | 说明 |
|----------|------|
| `combatUrgentHPRestore` (`Druid.lua`) | 紧急治疗 |
| `PLAYER_URGENT_HP_THRESHOLD` (`combo.lua`) | 阈值 = 15% |

---

## 6. 装备管理

### 规则 12：圣物交换 GCD 成本意识

**原则：** 圣物交换消耗 1.5s GCD。仅在本来会被浪费的空闲 GCD 期间进行交换。

**涉及的三种圣物：**

| 圣物 | 效果 | 使用场景 |
|------|------|----------|
| 凶猛圣物 | 强化流血（缩短 10% 跳间隔） | 施放割裂/扫击前换上 |
| 残忍圣物 | 爪击/扫击 能量消耗 -3 | 默认佩戴（割裂已存在时） |
| 翡翠腐朽圣物 | 残忍圣物的替代品（与 T1 8/8 不冲突） | 默认佩戴（无 T1 8/8 时替代残忍圣物） |

**交换策略：**
```
默认：残忍圣物或翡翠腐朽圣物（T1 8/8 → 残忍圣物，否则 → 翡翠腐朽圣物）
割裂前：换上凶猛圣物（仅正常战；快战/PvP 跳过）
割裂后：recoverNormalRelic() → 换回默认圣物（在空闲 GCD 期间）
```

| 相关函数 | 说明 |
|----------|------|
| `computeNormalRelic` (`Druid.lua`) | 默认圣物计算 |
| `selectFerocityOrEmeraldRot` (`Druid.lua`) | 残忍圣物 vs 翡翠腐朽圣物选择 |
| `dischargeEnergyChangeRelicAndRip` (`cat.lua`) | 割裂前换上凶猛圣物 |
| `recoverNormalRelic` (`Druid.lua`) | 空闲 GCD 期间换回默认圣物 |

**已知限制：** 在无限能量场景下，`recoverNormalRelic` 永不触发（因为 `energy + erps * 2.5 > 100` 永远成立），所以割裂后凶猛圣物一直戴着用于撕碎/爪击/撕咬——轻微的 DPS 损失。

---

## 7. 无限能量模式

### 规则 13：无限能量简化

**原则：** 当 `erps >= SHRED_E`（如红龙精华 +50 erps）时，所有基于"避免能量溢出"和"等待能量回复"的逻辑变得无关紧要。系统坍缩为最简单的循环。

**触发条件（满足任一）：**
- 红龙精华 buff：`+50 erps`（在 `computeErps` 中应用）
- 任何组合使 `computeErps() >= SHRED_E`

**行为变化：**

| 模块 | 正常行为 | 无限能量 |
|------|----------|----------|
| 撕咬前泄能 | 先泄能 | **跳过** |
| 割裂前泄能 | 先泄能 | **跳过** |
| 清晰预兆处理 | 特殊最大化 | **跳过**（走正常循环） |
| 等待窗口（精灵之火） | 探测并填充精灵之火 | **永不触发** |
| 变身回能 | 能量饥渴时触发 | **永不触发** |
| 圣物恢复 | 空闲 GCD 时换回 | **永不换回** |

**简化循环：**
```
维持割裂(5星) → 维持扫击(<5星) → 撕碎/爪击攒星 → 5星撕咬 → 重复
```

**代码分布（`erps >= SHRED_E` 检查门控行为的函数）：**
- `cp5Bite` (`cat.lua`) — 跳过撕咬前泄能
- `energyDischargeBeforeBite` (`cat.lua`) — 立即返回，不做泄能
- `oocMod` (`cat.lua`) — 立即返回，走正常循环
- `dischargeEnergyChangeRelicAndRip` (`cat.lua`) — `skipDischarge` 标记绕过泄能
- `shouldDoReshift` (`cat.lua`) — 1.5s 后预期能量永远超过任何技能消耗，所以变身回能永不触发
- `shouldCastFFDuringWaitWindow` (`Druid.lua`) — `currentEnergy < minAbilityCost` 永远不成立，所以精灵之火填充永不触发
- `recoverNormalRelic` (`Druid.lua`) — `energy + erps * 2.5 > 100` 永远成立，所以圣物永不换回

---

## 8. 爆发协调

### 规则 14：手动爆发协调

**原则：** 爆发技能（狂暴、饰品、药水）由玩家手动触发（按住 Shift），而非自动触发。这给予玩家对爆发时机的完全控制。

**消费顺序（每次点击一个）：**
```
按住 Shift → burstFlags 设置
点击 1：狂暴
点击 2：Juju Flurry
点击 3：攻强物品（饰品 → Juju Power → 强效怒气药水）
全部消费完毕 → burstFlags 清除
```

| 相关函数 | 说明 |
|----------|------|
| `burstMod` (`cat.lua`) | 爆发模块（Shift 键门控 + 顺序消费链） |
| `atkPowerBurst` (`cat.lua`) | 攻强消耗品（饰品、Juju Power、强效怒气药水） |

**设计理由：** 爆发时机取决于战斗环境（boss 阶段、易伤窗口等）。自动化有风险在非最优时刻浪费爆发资源。

**高价值目标的自动攻强爆发（扫击时）：**
除了手动爆发协调外，`keepRake` 在向世界boss或 PvP 目标施放扫击时（且割裂已存在），会自动消费攻强物品。理由：扫击在施放时快照攻击强度，持续整个流血期间；在施放瞬间最大化攻强能产生最高的总流血伤害。此自动消费与 Shift 键爆发序列相互独立，互不干扰。

---

## 附录 A：能量来源参考

猫德所有能量恢复来源及其 erps 贡献：

| 来源 | erps 贡献 | 条件 |
|------|-----------|------|
| 自动 Tick（基础） | 10.0 | 始终 |
| 猛虎之怒 | 3.33 | 猛虎之怒 buff 激活 |
| 扫击流血 | `computeRake_Erps()` | 目标身上有扫击（需远古兽性天赋） |
| 割裂流血 | `computeRip_Erps()` | 目标身上有割裂（需远古兽性天赋） |
| 突袭流血 | `computePounce_Erps()` | 目标身上有突袭（需远古兽性天赋） |
| 狂暴 | 10.0 | 狂暴激活 |
| 红龙精华 | 50.0 | 红龙精华 buff 激活 |

**远古兽性天赋：**
- 等级 1：每次流血 Tick 回 3 能量
- 等级 2：每次流血 Tick 回 5 能量
- 割裂 Tick 间隔：2s（凶猛圣物：1.8s），扫击/突袭 Tick 间隔：3s（凶猛圣物：2.7s）

> 代码：`computeRake_Erps`、`computeRip_Erps`、`computePounce_Erps`，均在 `Druid.lua` 中

---

## 附录 B：关键常量

| 常量 | 值 | 说明 | 定义位置 |
|------|-----|------|----------|
| 能量池上限 | 100 | 猫形态能量最大值 | — |
| 基础回复 | 20/2s = 10 erps | 默认能量恢复速率 | `catAtk` (`combo.lua`) |
| 变身 GCD | 1.5s | 形态切换 GCD 时长 | `shouldDoReshift` (`cat.lua`) |
| 畏缩仇恨阈值 | 75% | 触发畏缩的仇恨百分比 | `COWER_THREAT_THRESHOLD` (`Druid.lua`) |
| 紧急血量阈值 | 15% | 触发治疗消耗品的血量百分比 | `catAtk` (`combo.lua`) |
| 快战阈值 | 25s | 预计存活 < 25s → 快战 | `isTrivialBattle` (`Druid.lua`) |
| 斩杀预测 | 2s | 目标 2s 内死亡 → 斩杀 | `isKillShotOrLastChance` (`Druid.lua`) |
| 割裂基础时长 | 10s | 每星 +2s（凶猛圣物 × 0.9） | `RIP_BASE_DURATION` (`Druid.lua`) |
| 扫击时长 | 9s | | `RAKE_DURATION` (`Druid.lua`) |
| 撕咬割裂刷新保护 | 2.3s | 割裂 ≤ 2.3s 剩余时跳过泄能以保护割裂 | `cp5Bite` (`cat.lua`) |
| 精灵之火 GCD | 1s | 施放精灵之火所需的最小等待窗口 | `shouldCastFFDuringWaitWindow` (`Druid.lua`) |

---

## 附录 C：未来优化方向

1. **[主动精灵之火维护]** — 当精灵之火 debuff 缺失且能量不会溢出时主动施放精灵之火，而非仅在等待窗口。边际收益需要实测验证。
2. **[快战扫击优化]** — 在快战中 3 星时，评估在撕咬前插入扫击（更强的撕咬 + 额外的流血）是否为净收益。需测试验证。
3. **[无限能量圣物恢复]** — 在红龙精华期间割裂后，评估是否有机会换回残忍/翡翠腐朽圣物。当前跳过；损失微小。

---

## 附录 D：原则→代码可追溯矩阵

| 规则 | 原则 | 主要函数 | 文件 |
|------|------|----------|------|
| 1 | 溢出预防 | `energyDischargeBeforeBite`、`dischargeEnergyChangeRelicAndRip` | `cat.lua`、`cat.lua` |
| 2 | 能量饥渴避免 | `shouldDoReshift`、`readyReshift` | `cat.lua`、`cat.lua` |
| 3 | 撕咬转化效率 | `energyDischargeBeforeBite` | `cat.lua` |
| 4 | 流血优先 | `shouldCastRip`、`cp5Bite` | `Druid.lua`、`cat.lua` |
| 5 | 时长自适应割裂 | `shouldCastRip`、`quickKeepRip`、`keepRip` | `Druid.lua`、`cat.lua`、`cat.lua` |
| 6 | 攒星技能选择 | `shouldUseShred`、`regularAttack` | `Druid.lua`、`cat.lua` |
| 7 | GCD 优先级 | `catAtk`（模块顺序）、`getNextAbilityCost` | `combo.lua`、`Druid.lua` |
| 8 | 精灵之火填充 | `shouldCastFFDuringWaitWindow`、`keepFF` | `Druid.lua`、`cat.lua` |
| 9 | 斩杀 | `isKillShotOrLastChance`、`tryBiteKillShot`、`getKSThreshold` | `Druid.lua`、`cat.lua`、`Druid.lua` |
| 10 | 仇恨感知 | `otMod`、`safeCower` | `cat.lua`、`cat.lua` |
| 11 | 紧急生存 | `combatUrgentHPRestore` | `Druid.lua` |
| 12 | 圣物交换 | `computeNormalRelic`、`recoverNormalRelic`、`dischargeEnergyChangeRelicAndRip` | `Druid.lua`、`Druid.lua`、`cat.lua` |
| 13 | 无限能量 | `computeErps`、`isPseudoInfiniteEnergy` | `Druid.lua`、`combo.lua` |
| 14 | 爆发协调 | `burstMod`、`atkPowerBurst` | `cat.lua`、`cat.lua` |

### SelfTest 覆盖

| 规则 | 测试 ID |
|------|---------|
| 1 | R1-01 ~ R1-04 |
| 2 | R2-01 ~ R2-07 |
| 4, 5 | R4-01 ~ R4-04, R5-01 ~ R5-04 |
| 6 | R6-01 ~ R6-06 |
| 7 | R7-01 ~ R7-06 |
| 8 | R8-01 ~ R8-06 |
| 9 | R9-01 ~ R9-03 |
| 3, 12 | R12-01 ~ R12-03 |
| — | PF-01 ~ PF-07（纯函数测试） |

---

*最后更新：2026-07-29*  
*作者：pf_miles*