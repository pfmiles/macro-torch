# Phase A: catAtk 可维护性清理

> **来源：** `catAtk-core-principles.md` 逆向审视
> **目标：** 纯代码结构改进，不改行为，零 DPS 影响
> **预估改动量：** ~40 行，涉及 3 个文件

---

## 背景

从 `catAtk-core-principles.md` 的 14 条设计原则出发，逆向审视 `catAtk()` 及其子模块的当前实现，发现 4 个可维护性问题。这些问题不影响 DPS 输出，但增加了理解和修改代码的成本。

---

## 条目 1：修复 `catAtk` 注释编号

**文件：** `classes/druid/combo.lua`  
**位置：** 第 144–174 行（`catAtk` 函数体）

**现状：**

当前模块调用顺序的注释编号不连续且错位：

```
-- 7.oocMod          ← 标注为 "7"，实际在 termMod 之前
-- 6.termMod         ← 标注为 "6"，实际在 oocMod 之后
-- 8.OT mod
-- 9.tiger fury
-- 10.debuffMod
-- 11.regularAttack
-- 12.reshiftMod
```

步骤 1-5 正常，但从步骤 6 开始编号混乱（7 在 6 之前，且跳过了某些数字）。阅读代码时需要脑内重新排序。

**目标：**

将注释编号修正为与实际执行顺序一致的连续序列：

```
0. recoverNormalRelic
1. combatUrgentHPRestore / mana potion
2. targetEnemy
3. autoAttack
4. burstMod
5. opener mod (Pounce / Ravage)
6. oocMod          ← OoC 优先：内部含 KillShot → 攒星/撕咬
7. termMod         ← 终结技：KillShot → 5CP Bite
8. otMod
9. keepTigerFury
10. debuffMod (Rip → Rake → FF)
11. regularAttack
12. reshiftMod
```

**改动：** 仅修改注释文本，不改任何代码逻辑。

**验证：** 肉眼审查编号连续性，确认顺序与 `catAtk-core-principles.md` Rule 7 优先级表一致。

---

## 条目 2：为斩杀入口添加设计意图注释

**文件：**
- `classes/druid/combo.lua` 第 144–150 行
- `classes/druid/cat.lua` 第 156–174 行（`oocMod`）和第 97–105 行（`termMod`）

**现状：**

`tryBiteKillShot` 在两处被调用——`oocMod` 和 `termMod`。OoC 模块在 termMod 之前执行，因此 OoC 触发时优先走 OoC → KillShot 路径。没有注释解释为什么需要两个入口。

**目标：**

在 `oocMod` 和 `termMod` 的调用处各添加一行注释，说明设计意图：

- `combo.lua:144`（oocMod 调用前）：
  ```
  -- 6.oocMod: 清晰预兆优先——OoC 触发时用免费技能打 KillShot/Bite
  ```

- `combo.lua:149`（termMod 调用前）：
  ```
  -- 7.termMod: 普通 GCD 终结技——KillShot > 5CP Bite；若 OoC 已消费则此处跳过
  ```

- `cat.lua:156`（`oocMod` 函数头）：
  ```
  -- OoC (Omen of Clarity) 模块：节能施法状态下优先用免费技能
  -- KillShot 仍然是最优先的，其次才是常规攒星/撕咬
  ```

**改动：** 仅添加注释。

**验证：** 肉眼审查。

---

## 条目 3：集中化 `isInfiniteEnergy` 判断

**文件：**
- `classes/druid/combo.lua`（添加计算）
- `classes/druid/cat.lua`（替换引用）
- `classes/druid/Druid.lua`（替换引用）

**现状：**

"无限能量"判断 `macroTorch.computeErps(clickContext) >= clickContext.SHRED_E` 在以下 6+ 处独立出现：

| 位置 | 函数 | 行号 |
|------|------|------|
| `cat.lua` | `oocMod` | ~162 |
| `cat.lua` | `cp5Bite` | ~116 |
| `cat.lua` | `energyDischargeBeforeBite` | ~139 |
| `cat.lua` | `dischargeEnergyChangeRelicAndRip` | ~252 |
| `Druid.lua` | `shouldUseShred` | ~700 |
| `Druid.lua` | `shouldDoReshift` | 隐式（通过 projectedEnergy 间接实现） |
| `Druid.lua` | `shouldCastFFDuringWaitWindow` | 隐式（通过 projectedEnergy 间接实现） |
| `Druid.lua` | `recoverNormalRelic` | 隐式（通过能量溢出条件间接实现） |

任何对"无限能量"判断标准的修改都需要在多个文件中同步。

**目标：**

在 `catAtk` 中一次性计算，存入 `clickContext.isInfiniteEnergy`，所有子模块读取此标志。

```lua
-- 在 catAtk 中，computeErps 的值在 clickContext 初始化后添加：
clickContext.isInfiniteEnergy = macroTorch.computeErps(clickContext) >= clickContext.SHRED_E
```

然后将各模块中的 `macroTorch.computeErps(clickContext) >= clickContext.SHRED_E` 替换为 `clickContext.isInfiniteEnergy`。

**特殊处理：**

以下两处使用了独立的 `local erps = macroTorch.computeErps(clickContext)` 然后比较——改为直接读取 `clickContext.isInfiniteEnergy`：

- `shouldUseShred` (`Druid.lua:699-700`)：`local infiniteEnergy = erps >= clickContext.SHRED_E` → `clickContext.isInfiniteEnergy`
- `dischargeEnergyChangeRelicAndRip` (`cat.lua:251-252`)：`local skipDischarge = erps >= clickContext.SHRED_E` → `clickContext.isInfiniteEnergy`

**不改动的位置：**

以下两处使用了"隐式"无限能量判断（通过能量计算自然得出而非显式比较），保持原样因为它们表达的是不同的语义（"能量是否会溢出"而非"是否无限能量"）：

- `shouldDoReshift`：`math.ceil(currentEnergy + erps * 1.5) < nextAbilityCost` — 表达"自然回能是否足够"
- `shouldCastFFDuringWaitWindow`：`currentEnergy + erps * 1.5 >= minAbilityCost and currentEnergy < minAbilityCost` — 表达"是否需要等待"
- `recoverNormalRelic`：`energy + erps * 2.5 <= 100` — 表达"是否有空闲 GCD"

**改动：** 在 `catAtk` 添加 1 行计算；在 4 处替换显式比较。

**验证：** 确保 `computeErps` 在 `isInfiniteEnergy` 计算之前已可用（当前 `computeErps` 依赖 `clickContext` 中的 `AUTO_TICK_ERPS`、`TIGER_ERPS` 等字段，这些字段在 `isInfiniteEnergy` 计算之前已设置——但 `computeErps` 内部调用 `isTigerPresent`、`isRakePresent` 等函数，这些函数又读取 `clickContext` 的缓存。由于此时尚未进入战斗，Tiger/Rake 等 buff 均不存在，`computeErps` 在这时调用返回的是基础 erps 值。**需确认**：`isInfiniteEnergy` 的值在战斗过程中是否可能发生变化（如 Tiger's Fury 被施放、Rake 被应用后 erps 增加）。如果可能变化，则 `isInfiniteEnergy` 应在每次点击时重新计算——当前 `clickContext` 本身就是每次点击新建的，满足此要求。✓）

---

## 条目 4：从 `keepRake` 中分离 ATK 爆发逻辑

**文件：** `classes/druid/cat.lua`  
**位置：** 第 300–314 行（`keepRake` 函数）

**现状：**

`keepRake` 函数在施放 Rake 之前，会检测是否为 worldboss/PvP 场景，如果是则调用 `atkPowerBurst` 消耗 ATK 爆发物品来增强 Rake 伤害：

```lua
function macroTorch.keepRake(clickContext)
    -- 守卫条件...
    -- ATK 爆发（副作用）：
    if ((target.classification == 'worldboss' and isRipPresent and not isTargetDummy)
            or target.isPlayerControlled) and isNearBy then
        macroTorch.atkPowerBurst(clickContext)
    end
    macroTorch.safeRake(clickContext)
end
```

函数名为 `keepRake`（保持 Rake debuff），调用者期望它是"debuff 维护"，但内部隐藏了爆发消耗的副作用。如果未来有人重构，可能漏掉这个逻辑。

**目标：**

方案有两种，推荐方案 A：

**方案 A（推荐，最小改动）：** 在副作用处添加明确的注释块，说明为什么 ATK 爆发在这里触发：

```lua
-- [SIDE EFFECT] ATK Power burst for Rake on priority targets
-- Rake benefits from AP snapshotting; consuming burst items here
-- maximizes bleed damage for the entire Rake duration.
-- This is placed in keepRake rather than burstMod because:
--   1. burstMod handles manual (Shift-key) burst coordination
--   2. This is an automated optimization for high-value targets
if ((macroTorch.target.classification == 'worldboss' and macroTorch.isRipPresent(clickContext)
        and not clickContext.isTargetDummy) or macroTorch.target.isPlayerControlled)
        and macroTorch.isNearBy(clickContext) then
    macroTorch.atkPowerBurst(clickContext)
end
```

**方案 B（更干净的分离，改动量大）：** 将 ATK 爆发提取为独立模块 `autoBurstMod`，在 `catAtk` 中 `keepRake` 之前调用。但此方案改变了模块拆分结构，需要更仔细的验证。

**推荐方案 A**，因为：
- 改动最小（~5 行注释）
- 不改变任何执行顺序
- 不引入新的模块耦合风险
- 副作用的存在被明确标注，后续维护者不会遗漏

**改动：** 添加注释块，微调格式。

**验证：** 肉眼审查注释准确性。

---

## 不改动的项目（已确认排除）

| 条目 | 排除原因 |
|------|----------|
| `burstMod` 中 Berserk 守卫导致跳过后续爆发物品 | **故意设计** — 爆发物品应与 Berserk 叠加使用 |
| 主动 FF 维护 | **暂缓** — 收益太小，引入复杂度过高 |
| `recoverNormalRelic` 无限能量永不触发 | **已知限制** — 已在原则文档 Appendix C.3 记录 |
| `oocMod` 中 `clickContext.ooc` 缓存导致的 1 帧延迟 | **可忽略** — OoC 消费后下一帧即更新 |

---

## 执行建议

1. 按条目 1→2→3→4 顺序执行，每个条目独立 commit
2. 条目 1、2 可合并为一个 commit（均为注释改动）
3. 条目 3 改动涉及 3 个文件，建议单独 commit
4. 条目 4 改动仅 1 个文件，单独 commit

---

*关联文档：[[catAtk-core-principles]] | [[catAtk-phaseB-quality]]*  
*创建日期：2026-07-28*