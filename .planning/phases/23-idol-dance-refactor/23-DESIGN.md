# Idol Dance (神像舞) 逻辑重构设计文档

## 背景

猫德在 WoW Classic 中使用三种神像（Idol / Relic）来优化 DPS：

| 神像 | 效果 | 用途 |
|------|------|------|
| Idol of Savagery | 提高 Rip/Rake 的流血伤害（快照机制） | 打 Rip/Rake 时穿戴 |
| Idol of Ferocity | 减少 Claw 和 Rake 能量消耗 3 点 | 攒星阶段节省能量 |
| Idol of the Emerald Rot | 增加 Swipe/Claw/Rake 伤害（与 8/8 塞纳里奥 T1 冲突） | 攒星阶段增加伤害 |

切换神像有 1.5s GCD，频繁切换会严重损失 DPS。因此神像舞的设计目标是：最小化切换次数，在合适的时机穿合适的神像。

## 现有实现的问题

当前实现位于 `classes/druid/Druid.lua` 的 `computeNormalRelic()` 函数，存在三个问题：

### Gap 1：快速战斗/PvP 错误使用 Savagery

快速战斗中目标很快就会死亡，不一定能打出 Rip。预切 Savagery 浪费 1.5s GCD，应始终使用构建神像（Ferocity 或 Emerald Rot）。

### Gap 2：免疫 Rip 目标错误使用 Savagery

目标免疫 Rip 时 Savagery 的流血加成为零，等于白板神像。应始终使用构建神像。

### Gap 3：Rip 状态判断缺少记忆，导致来回切换

当前代码仅通过实时 `isRipPresent()` 判断 Rip 是否在目标身上。Rip 到期后 `isRipPresent` 变为 false，`computeNormalRelic` 返回 Savagery，触发切换。而 Rip 被 5 星 Bite 刷新后会再次变为 true，又切回构建神像——造成不必要的来回切换。

根因：缺少"此目标上是否曾经成功挂过 Rip"的状态记录。

## 理想决策逻辑

```
判断条件：猫形态 && 有攻击目标

1. 快速战斗/PvP？
   → 始终 Fero/Rot（构建神像）

2. 正常战斗：
   a. 目标免疫 Rip？
      → 始终 Fero/Rot（Savagery 完全无用）

   b. 目标不免疫 Rip：
      ├─ 此目标在本次战斗中是否曾成功挂过我的 Rip？
      │   （查询 ripAppliedTargets[targetGuid]）
      │
      ├─ 否（尚未挂过）：
      │   → Savagery
      │   （未进战斗时无能量检查直接预切；已进战斗时通过能量检查切换）
      │   （dischargeEnergyChangeRelicAndRip 在打 Rip 前也会兜底切换）
      │
      └─ 是（曾经挂过，无论现在 Rip 是否还在）：
          → Fero/Rot（锁定构建神像，不再切回 Savagery）
          （通过 recoverNormalRelic 的能量检查来找安全窗口切换）
```

## 实现方案

### 改动范围

仅修改两个文件，合计约 30 行变更：

**1. `classes/druid/Druid.lua` — 重写 `computeNormalRelic()`**

将当前 20+ 行的嵌套 if-else 替换为三个平级判断：

```lua
function macroTorch.computeNormalRelic(clickContext)
    -- 快速战斗/PvP：始终构建神像，不跳神像舞
    if macroTorch.isTrivialBattleOrPvp(clickContext) then
        return macroTorch.selectFerocityOrEmeraldRot()
    end

    -- 免疫 Rip：Savagery 完全无用，始终构建神像
    if clickContext.isImmuneRip then
        return macroTorch.selectFerocityOrEmeraldRot()
    end

    -- 不免疫 Rip：查此目标是否曾挂过 Rip
    local ripEverApplied = macroTorch.context
        and macroTorch.context.ripAppliedTargets
        and macroTorch.context.ripAppliedTargets[macroTorch.target.guid]

    if ripEverApplied then
        return macroTorch.selectFerocityOrEmeraldRot()   -- 锁定构建神像
    else
        return 'Idol of Savagery'                        -- 预切/等待首次 Rip
    end
end
```

**2. `classes/druid/cat.lua` — `safeRip()` 中增加状态记录**

在 `safeRip` 函数中，Rip Cast 成功后记录当前目标的 GUID：

```lua
-- 在 macroTorch.context.ripAppliedTargets 中记录此目标已挂过 Rip
if not macroTorch.context.ripAppliedTargets then
    macroTorch.context.ripAppliedTargets = {}
end
macroTorch.context.ripAppliedTargets[macroTorch.target.guid] = true
```

### 不改动的部分

| 函数 | 说明 |
|------|------|
| `selectFerocityOrEmeraldRot()` | 已有逻辑正确（含 8/8 T1 判断），不动 |
| `recoverNormalRelic()` | 能量检查、形态守卫、hasItem 守卫均正确，不动 |
| `dischargeEnergyChangeRelicAndRip()` | 打 Rip 前的 Savagery 切换逻辑正确，不动 |
| `keepRip()` / `quickKeepRip()` | 调用 dischargeEnergyChangeRelicAndRip，不动 |
| `onCombatExit()` | 已有 `macroTorch.context = {}` 清空逻辑，不动 |
| `onCombatEnter()` | 已有 `macroTorch.context = {}` 初始化，不动 |
| `catLeveling()` | 明确不涉及神像逻辑，不动 |

## 状态生命周期

### ripAppliedTargets 的存储

存储在 `macroTorch.context.ripAppliedTargets` 中，是一个 `{ [targetGuid]: true }` 的 map。

### 写入时机

- `safeRip()` 中 Rip Cast 时写入当前 `macroTorch.target.guid`
- 采用 Cast 时写入（而非落地时），因为 Rip Cast 时已通过 GCD/能量校验，落地失败属罕见情况，简化实现

### 重置时机

- **退战重置**：`onCombatExit()` 执行 `macroTorch.context = {}`，整个 map 自动清空
- **不随切目标重置**：同一场战斗中切换多个目标，各自保留各自的状态
- **不随 Rip 到期重置**：Rip 到期后标记保留，确保不切回 Savagery

## 变更对 DPS 的影响推演

| Gap | 场景 | 当前行为 | 修复后 | DPS 影响 |
|-----|------|---------|--------|---------|
| 1 | 快速战斗/PvP | Savagery (浪费 1.5s GCD) | Fero/Rot | 省 GCD，正向 |
| 2 | 免疫 Rip 目标 | Savagery (白板神像) | Fero/Rot | 白板变有用，正向 |
| 3 | Rip 被 Bite 刷新（常见） | 行为不变 | 行为不变 | 中性 |
| 3 | Rip 意外到期（罕见） | 攒星阶段无能量节省 | 攒星阶段有 Ferocity 节省 | 正向 |

三个场景正向，一个场景中性，无倒退。

## 设计决策记录

1. **Rip 到期后是否重新打 Rip 时仍切 Savagery？** → 是，`dischargeEnergyChangeRelicAndRip` 保持现有行为。如果 Rip 意外到期需要重新打，Savagery 快照价值 > 1.5s GCD 成本。

2. **ripAppliedTargets 重置时机？** → 仅退战重置。理由：同一场战斗中能同时追踪多个目标的状态，退出战斗即全部清除。退战通过已有的 `onCombatExit()` → `macroTorch.context = {}` 自动实现。

3. **状态标记记录位置？** → `safeRip` 中 Cast 时记录。Rip 的 Cast 前已经过 GCD/能量/距离校验，属于"确认要打"，与之配套。

## 验证要点

1. 非战斗猫形态，选非免疫目标 → 自动切 Savagery
2. 进入战斗后第一次打 Rip → Savagery 已在身上，快照正确
3. Rip 挂上后 → 找到安全能量窗口自动切回 Fero/Rot
4. Rip 存在期间 → 锁定在 Fero/Rot，不来回切
5. Rip 到期/被驱散 → 保持 Fero/Rot 不动
6. 战斗中切目标 → 新目标独立判断，走自己的 S0
7. 退出战斗再进 → 状态重置，重新开始
8. 快速战斗/PvP → 始终 Fero/Rot，不切 Savagery
9. 免疫 Rip 目标 → 始终 Fero/Rot
10. 高能量恢复（小红龙等）→ 能量检查阻止切换，全程 Savagery（0 次切换，符合设计意图）