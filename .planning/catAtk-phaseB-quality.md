# Phase B: catAtk 质量保障 — 原则驱动的 SelfTest + 文档同步

> **来源：** `catAtk-core-principles.md` 逆向审视
> **目标：** 建立基于原则的自动化回归测试 + 填补原则文档与代码之间的缺口
> **预估改动量：** ~200 行测试代码（`Druid.lua`）+ ~30 行文档补充（`catAtk-core-principles.md`）

---

## 背景

当前 `catAtk` 及其所有子模块 **没有覆盖测试**（CodeGraph 报告：⚠️ no covering tests found）。对于一个由 14 条设计原则约束的复杂 DPS 状态机，缺乏回归测试是最大的可维护性风险。

好消息是：`clickContext` 缓存机制天然支持依赖注入式的单元测试——可以通过预设 `clickContext` 字段绕过游戏 API 依赖，对决策函数进行纯逻辑验证。

---

## 条目 5：建立基于原则的 SelfTest

### 5.1 测试基础设施分析

**SelfTest 系统**（`core/selftest.lua`）：

```lua
-- 注册测试
macroTorch.SelfTest:register(name, fn, isOptional)
-- fn 内部使用 assert() 做断言
-- 在游戏客户端内执行，可通过 UnitClass('player') 做职业门控
```

**测试模式**（从现有测试中提取）：

```lua
-- 模式 1：纯函数测试（直接调用，传入参数）
macroTorch.SelfTest:register("Druid: estimatePlayerDPS(15) returns 25", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.estimatePlayerDPS(15)
    assert(val == 25, "expected 25, got " .. tostring(val))
end)

-- 模式 2：决策函数测试（构造 clickContext 预设缓存值）
macroTorch.SelfTest:register("Druid: shouldCastRip with 5CP normal battle", function()
    if UnitClass('player') ~= 'Druid' then return end
    local ctx = {
        isRipPresent = false,
        isImmuneRip = false,
        comboPoints = 5,
        rough = false,
        isTrivialBattle = false,  -- 预设缓存，绕过游戏状态
        isFightStarted = true,
        isNearBy = true,
    }
    assert(macroTorch.shouldCastRip(ctx), "5CP without Rip should cast Rip")
end)
```

**关键约束：**
- 测试在游戏客户端内运行（需登录 Druid 角色）
- 预设 `clickContext` 字段可绕过所有需要游戏状态的函数调用
- 测试按注册顺序执行，单个测试 crash 不影响后续
- `assert` 失败会打印红色错误消息

### 5.2 测试用例设计（按原则组织）

#### Rule 1: 能量溢出预防

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R1-01 | 无限能量时跳过泄能 | `energyDischargeBeforeBite` | `isInfiniteEnergy=true` | 函数直接 return（不调用 regularAttack） |
| R1-02 | 正常能量 + OoC 时泄能 | `energyDischargeBeforeBite` | `isInfiniteEnergy=false, ooc=true, mana=100, BITE_E=35, SHRED_E=60` | 调用 regularAttack（OoC 免费泄能） |
| R1-03 | 能量充足 + 在背后时用 Shred 泄能 | `energyDischargeBeforeBite` | `isInfiniteEnergy=false, ooc=false, mana=100, BITE_E=35, SHRED_E=60, isBehind=true` | 调用 regularAttack |
| R1-04 | 能量不足 + 无 Rake 时用 Rake 泄能 | `energyDischargeBeforeBite` | `isInfiniteEnergy=false, ooc=false, mana=70, BITE_E=35, SHRED_E=60, CLAW_E=45, isRakePresent=false` | 调用 safeRake |

> **注意：** R1-02~R1-04 的"调用 regularAttack/safeRake"验证需要该函数有返回值或在测试中 hook。如果当前函数无返回值，测试可以改为验证"不 crash"（pcall 包裹）或建议先给函数加返回值。

#### Rule 2: 能量饥渴 — Reshift

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R2-01 | Reshift 能量为 0 → 不触发 | `shouldDoReshift` | `RESHIFT_ENERGY=0` | `false` |
| R2-02 | 不在战斗中 → 不触发 | `shouldDoReshift` | `RESHIFT_ENERGY=40, player.isInCombat=false` | `false` |
| R2-03 | 潜行中 → 不触发 | `shouldDoReshift` | `RESHIFT_ENERGY=40, prowling=true` | `false` |
| R2-04 | OoC 时 → 不触发 | `shouldDoReshift` | `RESHIFT_ENERGY=40, ooc=true` | `false` |
| R2-05 | KillShot 阶段 → 不触发 | `shouldDoReshift` | `RESHIFT_ENERGY=40, isKillShotOrLastChance 预设为 true` | `false` |
| R2-06 | 1.5s 自然回能足够 → 不触发 | `shouldDoReshift` | `RESHIFT_ENERGY=40, mana=35, computeErps=10 (erps*1.5=15), nextAbilityCost=45` | `false`（35+15=50≥45） |
| R2-07 | 1.5s 自然回能不够 → 触发 | `shouldDoReshift` | `RESHIFT_ENERGY=40, mana=20, computeErps=10, nextAbilityCost=45` | `true`（ceil(20+15)=35<45） |

#### Rule 4+5: 流血优先 + 时长自适应 Rip

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R4-01 | 5CP + Rip 不存在 + 正常战 → 应 Rip | `shouldCastRip` | `cp=5, isRipPresent=false, isImmuneRip=false, rough=false, isTrivialBattle=false` | `true` |
| R4-02 | 5CP + Rip 已存在 → 不 Rip | `shouldCastRip` | `cp=5, isRipPresent=true, isImmuneRip=false` | `false` |
| R4-03 | 5CP + 免疫流血 → 不 Rip | `shouldCastRip` | `cp=5, isRipPresent=false, isImmuneRip=true` | `false` |
| R4-04 | KillShot 阶段 → 不 Rip | `shouldCastRip` | `cp=5, isKillShotOrLastChance 预设为 true` | `false` |
| R5-01 | 快战 + 1CP + Rip 不存在 → 应 Rip | `shouldCastRip` | `cp=1, isRipPresent=false, isTrivialBattle=true` | `true` |
| R5-02 | 快战 + 2CP + Rip 不存在 → 应 Rip | `shouldCastRip` | `cp=2, isRipPresent=false, isTrivialBattle=true` | `true` |
| R5-03 | 快战 + 3CP + Rip 不存在 → 不 Rip（应 Bite） | `shouldCastRip` | `cp=3, isRipPresent=false, isTrivialBattle=true` | `false` |
| R5-04 | 正常战 + 3CP + Rip 不存在 → 不 Rip（不到 5CP） | `shouldCastRip` | `cp=3, isRipPresent=false, isTrivialBattle=false` | `false` |

#### Rule 6: 流血数量决定攒星技能

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R6-01 | 0 流血 + OoC + 在背后 → Shred | `shouldUseShred` | `bleedCount=0, ooc=true, isBehind=true` | `true` |
| R6-02 | 0 流血 + 无限能量 + 在背后 → Shred | `shouldUseShred` | `bleedCount=0, isInfiniteEnergy=true, isBehind=true` | `true` |
| R6-03 | 2 流血 + OoC + 在背后 → Shred | `shouldUseShred` | `bleedCount=2, ooc=true, isBehind=true` | `true` |
| R6-04 | 2 流血 + 无 OoC + 无无限能量 → Claw | `shouldUseShred` | `bleedCount=2, ooc=false, isInfiniteEnergy=false` | `false` |
| R6-05 | 3+ 流血 → 始终 Claw | `shouldUseShred` | `bleedCount=3, ooc=true, isBehind=true` | `false` |
| R6-06 | Rip 不存在 + 正常战 → Claw（加速攒星） | `shouldUseShred` | `bleedCount≤1, isTrivialBattle=false, isImmuneRip=false, isRipPresent=false` | `false` |

#### Rule 7: Bite 触发条件

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R7-01 | KillShot + 有星 → Bite | `shouldUseBite` | `isKillShotOrLastChance=true, cp=3` | `true` |
| R7-02 | KillShot + 无星 → 不 Bite | `shouldUseBite` | `isKillShotOrLastChance=true, cp=0` | `false` |
| R7-03 | 5CP + Rip 存在 + 正常战 → Bite | `shouldUseBite` | `cp=5, isRipPresent=true, isTrivialBattle=false` | `true` |
| R7-04 | 5CP + 免疫 Rip + 正常战 → Bite | `shouldUseBite` | `cp=5, isImmuneRip=true, isTrivialBattle=false` | `true` |
| R7-05 | 快战 + 3CP + Rip 不存在 + 不免疫 → Bite | `shouldUseBite` | `cp=3, isTrivialBattle=true, isRipPresent=false, isImmuneRip=false` | `true` |
| R7-06 | 快战 + 2CP + Rip 不存在 → 不 Bite | `shouldUseBite` | `cp=2, isTrivialBattle=true, isRipPresent=false` | `false` |

#### Rule 8: 等待窗口 FF 填充

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R8-01 | OoC 时 → 不 FF | `shouldCastFFDuringWaitWindow` | `ooc=true` | `false` |
| R8-02 | 免疫 FF → 不 FF | `shouldCastFFDuringWaitWindow` | `target.isImmune('Faerie Fire (Feral)')=true` | `false` |
| R8-03 | 应 Reshift → 不 FF | `shouldCastFFDuringWaitWindow` | `shouldDoReshift 预设为 true` | `false` |
| R8-04 | 能量够 + 不需等 → 不 FF | `shouldCastFFDuringWaitWindow` | `mana=60, erps=10, minAbilityCost=45` | `false`（60≥45 无需等待） |
| R8-05 | 等 0.5s → 不 FF（<1s） | `shouldCastFFDuringWaitWindow` | `mana=35, erps=20, minAbilityCost=45` | `false`（需等 0.5s < 1.0s） |
| R8-06 | 等 1.5s → FF | `shouldCastFFDuringWaitWindow` | `mana=30, erps=10, minAbilityCost=45` | `true`（需等 1.5s ≥ 1.0s） |

#### Rule 9: 斩杀阈值

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R9-01 | 60 级阈值 = 1750 | `getKSThreshold` | `level=60` | `1750` |
| R9-02 | 50 级阈值 = 725 | `getKSThreshold` | `level=50` | `725` |
| R9-03 | 15 级 fallback = 100 | `getKSThreshold` | `level=15` | `100` |

#### Rule 3+12: Bite 前泄能 + 圣物 swap（cp5Bite 逻辑）

| 测试ID | 场景 | 被测函数 | 预设 ctx | 预期 |
|--------|------|----------|----------|------|
| R12-01 | 5CP + Rip 存在 + 无限能量 → 跳过泄能，直接 Bite | `cp5Bite` | `cp=5, isRipPresent=true, isInfiniteEnergy=true` | 不调 energyDischarge，直接 readyBite/safeBite |
| R12-02 | 5CP + Rip 存在 + Rip ≤ 2.3s → 跳过泄能保 Rip | `cp5Bite` | `cp=5, isRipPresent=true, ripLeft≤2.3` | `shouldDischarge=false` |
| R12-03 | 5CP + Rip 存在 + 正常 → 先泄能再 Bite | `cp5Bite` | `cp=5, isRipPresent=true, isInfiniteEnergy=false, ripLeft>2.3` | `shouldDischarge=true`，调用 energyDischargeBeforeBite |

#### 纯函数测试

| 测试ID | 场景 | 被测函数 | 输入 | 预期 |
|--------|------|----------|------|------|
| PF-01 | Furor 0 + 无 Wolfsheart = 0 | `computeReshiftEnergy` | talent=0, no enchant | `0` |
| PF-02 | Furor 5 + Wolfsheart = 60 | `computeReshiftEnergy` | talent=5, enchant present | `60` |
| PF-03 | Furor 3 + 无 Wolfsheart = 24 | `computeReshiftEnergy` | talent=3, no enchant | `24` |
| PF-04 | 60 级 DPS 估算 = 500 | `estimatePlayerDPS` | `level=60` | `500` |
| PF-05 | 40 级 DPS 估算 = 200 | `estimatePlayerDPS` | `level=40` | `200` |
| PF-06 | 无 Tiger/Rake/Rip/Pounce/Berserk/Red → erps=10 | `computeErps` | ctx 中所有 buff=false | `10` |
| PF-07 | Tiger 存在 + Rake 存在 → erps=10+3.33+rakeErps | `computeErps` | `isTigerPresent=true, isRakePresent=true` | 由具体天赋决定 |

### 5.3 实现策略

**第一阶段（本次 Phase）：** 实现"纯条件"测试 —— 被测函数只依赖 `clickContext` 预设值，不调用任何需要游戏状态的子函数。

这些函数包括：
- `getKSThreshold` / `estimatePlayerDPS`（纯计算，已有部分测试）
- `shouldCastRip`（依赖 clickContext 预设 + `isTrivialBattleOrPvp` 预设）
- `shouldUseBite`（同上）
- `shouldUseShred`（依赖 clickContext 预设 + `isTrivialBattleOrPvp` 预设 + `computeErps` 预设）
- `computeReshiftEnergy`（依赖 talent rank + 装备扫描——但装备扫描需要游戏环境）
- `computeErps`（纯计算，但依赖 `isTigerPresent`/`isRakePresent` 等，可通过 clickContext 预设）

**第二阶段（后续）：** 实现需要 hook/返回值改造的测试（如验证 `energyDischargeBeforeBite` 是否调用了 `regularAttack`）。

**第三阶段（后续）：** 添加集成级测试，构造完整的 `clickContext` 并在安全环境下调用 `catAtk()`。

### 5.4 建议的函数签名增强（可选）

为便于测试，建议给以下关键决策函数添加返回值（当前部分无返回值或有返回值但不一致）：

| 函数 | 当前返回值 | 建议 |
|------|-----------|------|
| `energyDischargeBeforeBite` | 无 | 返回是否执行了泄能（boolean） |
| `cp5Bite` | 无 | 返回是否执行了 Bite（boolean） |
| `safeRake` | `true/false/nil` | 已有返回值 ✓ |
| `safeBite` | `true/false/nil` | 已有返回值 ✓ |
| `readyReshift` | `true/false` | 已有返回值 ✓ |

---

## 条目 6：原则文档补充

**文件：** `.planning/catAtk-core-principles.md`

### 6.1 补充"加速攒星到第一个 Rip"逻辑

**现状：** Rule 6 (Bleed Count Determines Builder Choice) 描述了基于流血数量的 Shred/Claw 选择树，但未收录 `shouldUseShred` 中的一个重要设计决策：

> 当 Rip 不存在、非快战、目标不免疫流血时，`shouldUseShred` 强制返回 `false`（用 Claw），目的是加速 CP 生成，尽快到达 5 CP 打出第一个 Rip。

**建议：** 在 Rule 6 的决策树下方添加以下内容：

```markdown
**CP-building optimization — Racing to first Rip:**

When Rip is absent in a normal-length battle, the priority shifts from "maximize per-GCD damage" (Shred) to "maximize CP generation speed" (Claw). Claw is cheaper, generating CP faster, which gets to 5-CP Rip sooner. Once Rip is applied, `shouldUseShred` reverts to the standard bleed-count decision tree.

```
IF  NOT isTrivialBattleOrPvp
AND NOT isImmuneRip
AND NOT isRipPresent
THEN useClaw()              -- overriding standard bleedCount decision
```
```

### 6.2 补充 `keepRake` 中的 ATK 爆发副作用说明

**现状：** Rule 14 (Manual Burst Coordination) 描述了 Shift 键手动爆发，但未提及 `keepRake` 中的自动 ATK 爆发（对 worldboss/PvP 的 Rake 增强）。

**建议：** 在 Rule 14 末尾添加：

```markdown
**Automated ATK burst for priority Rake:**

In addition to manual burst coordination, `keepRake` automatically consumes ATK power items 
when applying Rake to worldboss or PvP targets (where Rip is already present). 
Rationale: Rake snapshots attack power for its entire bleed duration; maximizing AP at cast time 
yields the highest total bleed damage. This automated consumption is separate from the Shift-key 
burst sequence and does not interfere with it.
```

### 6.3 补充"规则→代码"可追溯性索引

**建议：** 在文档末尾添加附录 D，建立原则与代码的双向索引：

```markdown
## Appendix D: Principle → Code Traceability Matrix

| Rule | Principle | Primary Function(s) | File:Line |
|------|-----------|---------------------|-----------|
| 1 | Overflow Prevention | `energyDischargeBeforeBite`, `dischargeEnergyChangeRelicAndRip` | `cat.lua:137`, `cat.lua:242` |
| 2 | Starvation Avoidance | `shouldDoReshift`, `readyReshift` | `cat.lua:195`, `cat.lua:325` |
| 3 | Bite Conversion Efficiency | `energyDischargeBeforeBite` | `cat.lua:137` |
| 4 | Bleed Primacy | `shouldCastRip`, `cp5Bite` | `Druid.lua:909`, `cat.lua:106` |
| 5 | Duration-Adaptive Rip | `shouldCastRip`, `quickKeepRip`, `keepRip` | `Druid.lua:909`, `cat.lua:281`, `cat.lua:227` |
| 6 | Builder Choice | `shouldUseShred`, `regularAttack` | `Druid.lua:681`, `cat.lua:47` |
| 7 | GCD Priority | `catAtk` (module order), `getNextAbilityCost` | `combo.lua:47`, `Druid.lua:875` |
| 8 | FF Fill | `shouldCastFFDuringWaitWindow`, `keepFF` | `Druid.lua:842`, `cat.lua:315` |
| 9 | Kill Shot | `isKillShotOrLastChance`, `tryBiteKillShot`, `getKSThreshold` | `Druid.lua:783`, `cat.lua:175`, `Druid.lua:489` |
| 10 | Threat Awareness | `otMod`, `safeCower` | `cat.lua:64`, `cat.lua:393` |
| 11 | Emergency Survival | `combatUrgentHPRestore` | `Druid.lua:752` |
| 12 | Relic Swap | `computeNormalRelic`, `recoverNormalRelic`, `dischargeEnergyChangeRelicAndRip` | `Druid.lua:362`, `Druid.lua:424`, `cat.lua:242` |
| 13 | Infinite Energy | `computeErps`, `isInfiniteEnergy` (Phase A 新增) | `Druid.lua:802`, `combo.lua` |
| 14 | Burst Coordination | `burstMod`, `atkPowerBurst` | `cat.lua:2`, `cat.lua:399` |

### SelfTest Coverage

| Rule(s) | Test IDs |
|---------|----------|
| 1 | R1-01 ~ R1-04 |
| 2 | R2-01 ~ R2-07 |
| 4, 5 | R4-01 ~ R4-04, R5-01 ~ R5-04 |
| 6 | R6-01 ~ R6-06 |
| 7 | R7-01 ~ R7-06 |
| 8 | R8-01 ~ R8-06 |
| 9 | R9-01 ~ R9-03 |
| 3, 12 | R12-01 ~ R12-03 |
| — | PF-01 ~ PF-07 (pure functions) |
```

---

## 执行建议

1. **先执行 Phase A**（条目 1-4），确保代码结构清晰后再加测试
2. **条目 5 分批实现：**
   - Batch 1：纯函数测试（PF-01~07）+ 阈值测试（R9-01~03）——最简单，无游戏状态依赖
   - Batch 2：条件决策测试（Rule 2/4/5/6/7/8 的 clickContext 预设测试）
   - Batch 3：副作用验证测试（Rule 1/3/12 的泄能/Bite 测试，可能需要函数签名增强）
3. **条目 6** 可在条目 5 之前或同时进行，依赖关系弱
4. 每个 batch 独立 commit

---

## 开放问题（与 AI coding agent 讨论细化）

1. **`computeReshiftEnergy` 的可测试性：** 该函数依赖 `player.talentRank('Furor')` 和 `isKeywordInEquippedItemTooltip(1, 'Wolfsheart')`——这两个调用需要游戏环境。是否接受"在非 Druid 或无装备时 skip"的测试策略？还是需要为测试引入 talent/装备的 mock 机制？

2. **`shouldDoReshift` 中 `player.mana` 的可测试性：** `player.mana` 是通过 metatable 懒加载的（读取游戏能量值）。在测试中直接设置 `clickContext` 预设值可以绕过，但函数内部实际上访问的是 `macroTorch.player.mana` 而非 `clickContext.mana`。需要检查是否所有路径都先读 clickContext 缓存。

3. **副作用验证策略：** 对于"调用了 X 函数"的验证（如 R1-02 验证 `energyDischargeBeforeBite` 是否调用了 `regularAttack`），最简单的方案是给目标函数加布尔返回值，测试中检查返回值。但返回值语义需与现有调用方兼容。是否有其他偏好的验证方案？

4. **测试命名规范：** 现有 SelfTest 名称格式为 `"Druid: xxx"` 或 `"F: xxx"` 或 `"L: xxx"`。原则驱动测试建议使用 `"Principle R<n>: xxx"` 格式。是否与现有规范兼容？

---

*关联文档：[[catAtk-core-principles]] | [[catAtk-phaseA-maintainability]]*  
*创建日期：2026-07-28*