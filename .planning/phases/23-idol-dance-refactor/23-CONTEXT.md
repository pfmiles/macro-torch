# Phase 23: Idol Dance Refactor - Context

**Gathered:** 2026-08-02
**Status:** Ready for planning

<domain>
## Phase Boundary

重构猫德神像舞（Idol Dance）逻辑，修复 `computeNormalRelic()` 中两个已确认的 gap，并通过 `recoverNormalRelic()` 的距离优化消除远距离跑路时的不必要等待。

**改动量**: ~25 行，2 个文件（`Druid.lua` + `selftest.lua`）。**`cat.lua` 不改。**

**来源文档:** `.planning/phases/23-idol-dance-refactor/23-DESIGN.md` — 包含完整背景、Gap 分析、DPS 影响推演和 10 个验证场景。

### 修复的 Gap

| Gap | 场景 | 当前行为 | 修复后 |
|-----|------|---------|--------|
| **Gap 1** | 快速战斗/PvP | 切 Savagery（浪费 1.5s GCD） | 始终 Builder idol（Fero/Rot） |
| **Gap 2** | 免疫 Rip 目标 | 切 Savagery（白板神像） | 始终 Builder idol |
| **Gap 4** | 远距离目标 (≥20yd) | 能量检查阻止切换 | 距离旁路，直接切 |

### 明确不在此范围内

- **Gap 3**（Rip 到期后来回切换）— 接受现有行为。Rip 到期切回 Savagery 是合理的（重新打 Rip 需要 Savagery 快照）。`ripAppliedTargets` 永久记忆方案被否决。
</domain>

<decisions>
## Implementation Decisions

### 核心逻辑：computeNormalRelic 重写

- **D-01: 方案 A — 实时状态判断，只修 Gap 1+2** — 保留 `isInCombat` 外层守卫，战斗中 3 平级判断。不引入 `ripAppliedTargets` 永久记忆。不修 Gap 3（Rip 到期切回 Savagery 是正确行为）。**Reversibility:** reversible — 仅改一个函数，回退即恢复旧逻辑。

**新函数结构:**

```lua
function macroTorch.computeNormalRelic(clickContext)
    if not macroTorch.player.isInCombat then
        -- 非战斗：预切 Savagery（免疫 Rip 除外）
        if clickContext.isImmuneRip then
            return macroTorch.selectFerocityOrEmeraldRot()
        else
            return 'Idol of Savagery'
        end
    end

    -- 快速战斗/PvP：始终构建神像（Gap 1 修复）
    if macroTorch.isTrivialBattleOrPvp(clickContext) then
        return macroTorch.selectFerocityOrEmeraldRot()
    end
    -- 免疫 Rip：Savagery 完全无用（Gap 2 修复）
    if clickContext.isImmuneRip then
        return macroTorch.selectFerocityOrEmeraldRot()
    end
    -- Rip 当前存在：使用构建神像
    if macroTorch.isRipPresent(clickContext) then
        return macroTorch.selectFerocityOrEmeraldRot()
    end
    -- Rip 不存在：准备 Savagery 快照
    return 'Idol of Savagery'
end
```

- **D-02: 等价比对已验证** — 非战斗分支：`ripEverApplied` 方案被拒绝后，非战斗 + isRipPresent=true（罕见，Rip 到期前脱战）→ Savagery（当前一致）+ isImmuneRip→Fero/Rot（当前一致）。战斗中分支：Gap 1/2 修复 + isRipPresent 保持现有行为。逐场景比对表见 DISCUSSION-LOG.md。

### 距离优化：recoverNormalRelic

- **D-03: 距离旁路能量检查** — 在 `recoverNormalRelic` 的能量检查前插入距离判断：`macroTorch.target.distance >= 20` → 直接执行 `ensureRelicEquipped`，不再等待安全能量窗口。保守估算（基础跑速 7 yd/s）：(20-5)/7≈2.1s 跑路时间≥1.5s GCD。**Reversibility:** reversible — 单行条件，删除即恢复。

**修改位置:** `recoverNormalRelic` 第 435 行 `isFightStarted` 条件之前：

```lua
-- 距离够远：跑路时间足以覆盖神像 GCD，旁路能量检查直接切
if macroTorch.target.distance >= 20 then
    macroTorch.player.ensureRelicEquipped(relicName)
    return
end
```

- **D-04: 固定阈值 20yd** — 硬编码，不引入可配常量。理由：猫德跑速受天赋/形态影响但 ≥7 yd/s 始终成立，20yd 是安全下限。不判断是否"正在移动"——站远处说明不在做近战动作，切了就切了。

### 验证策略

- **D-05: SelfTest Category O** — 在 `classes/druid/selftest.lua` 末尾追加 Category O: Idol Dance，~6 个核心路径测试：
  - O-01: 快速战斗 → Fero/Rot
  - O-02: PvP 目标 → Fero/Rot
  - O-03: 免疫 Rip → Fero/Rot
  - O-04: Rip 存在 → Fero/Rot
  - O-05: Rip 不存在 → Savagery
  - O-06: 非战斗 + 非免疫 → Savagery（预切）
  距离测试（可选）：
  - O-07: 距离 ≥ 20yd → recoverNormalRelic 直接切换
- **D-06: 测试命名格式** — `"Cat O-NN: description"`，延续 Phase 22 的 Category 传统。`isOptional = true`（Druid 专属）。通过 `clickContext` 预设值 + `UnitClass('player')` guard 实现。
- **D-07: build_order.txt** — `classes/druid/selftest.lua` 已在 build_order.txt 中（Phase 22 添加），无需再改。

### 不改动的函数

| 函数 | 原因 |
|------|------|
| `selectFerocityOrEmeraldRot()` | 8/8 T1 判断逻辑正确 |
| `dischargeEnergyChangeRelicAndRip()` | 打 Rip 前 Savagery 切换逻辑正确 |
| `safeRip()` | 方案 A 不需要 ripAppliedTargets 标记 |
| `keepRip()` / `quickKeepRip()` | 调用链不变 |
| `onCombatExit()` / `onCombatEnter()` | `macroTorch.context = {}` 逻辑不变 |

### Commit 策略

- **D-08: 单 commit** — 改动量 ~25 行，合为一个 commit：`fix(druid): fix idol dance gaps + distance optimization`。包含 `Druid.lua`（computeNormalRelic 重写 + recoverNormalRelic 距离优化）+ `selftest.lua`（Category O 测试）。

### Claude's Discretion

- 距离阈值使用的具体比较符号（`>=` vs `>`，20 vs 20.0）
- SelfTest 函数内部 assert 条件的具体措辞
- `recoverNormalRelic` 距离旁路的 return 策略（早期 return vs 重新组织条件）
- 注释风格和措辞（英文，遵循现有约定）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 设计文档
- `.planning/phases/23-idol-dance-refactor/23-DESIGN.md` — 完整设计文档：背景、Gap 分析、理想逻辑、改动方案、DPS 影响推演、状态生命周期、10 个验证要点

### 修改目标文件
- `classes/druid/Druid.lua`（1383 行） — `computeNormalRelic()`（line 362）+ `recoverNormalRelic()`（line 424）+ `selectFerocityOrEmeraldRot()`（line 395）+ `isTrivialBattleOrPvp()`（line 735）
- `classes/druid/selftest.lua` — Category O 测试追加位置（Phase 22 创建）

### 非修改但需了解的关联文件
- `classes/druid/cat.lua`（417 行） — `dischargeEnergyChangeRelicAndRip()`（line 260）+ `safeRip()`（line 374）+ catAtk 子模块（不修改，但需了解调用链）
- `classes/druid/combo.lua`（375 行） — catAtk Module 0 调用链：`computeNormalRelic` → `recoverNormalRelic`
- `core/combat_context.lua` — `onCombatExit()` / `onCombatEnter()` `macroTorch.context` 生命周期

### 测试框架
- `core/selftest.lua` — `SelfTest:register(name, fn, isOptional)` API

### 直接依赖 Phase
- `.planning/phases/22-catatk-selftest-catatk-core-principles-md-d/22-CONTEXT.md` — Category 命名传统 + selftest.lua 结构参考

### 构建系统
- `build_order.txt` — 确认 `classes/druid/selftest.lua` 位置（Phase 22 已添加）
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `macroTorch.computeNormalRelic(clickContext)` — 当前实现（Druid.lua:362-388），将被完全重写
- `macroTorch.recoverNormalRelic(clickContext, relicName)` — 当前实现（Druid.lua:424-439），将在能量检查前插入距离旁路
- `macroTorch.selectFerocityOrEmeraldRot()` — 现有逻辑正确（Druid.lua:395-422），不动
- `macroTorch.isTrivialBattleOrPvp(clickContext)` — 现有逻辑（Druid.lua:735），在 computeNormalRelic 中使用
- `macroTorch.isRipPresent(clickContext)` — 现有逻辑，在 computeNormalRelic 中使用
- `macroTorch.target.distance` — 距离 API（Unit.lua:135），在 recoverNormalRelic 中使用
- `macroTorch.SelfTest:register(name, fn, isOptional)` — 测试注册 API（core/selftest.lua）

### Established Patterns
- **Category 测试命名**: Phase 22 建立了 `"Cat O-NN: description"` 格式 + `isOptional = true` + `UnitClass('player')` guard
- **clickContext 预设值测试**: 通过构造 `clickContext` 表绕过 WoW API 依赖，所有 boolean 决策函数可直接测试
- **computeNormalRelic 调用链**: catAtk Module 0（combo.lua:103,112）每次按键执行 → 返回值存入 `clickContext.normalRelic` → `recoverNormalRelic` 尝试切换

### Integration Points
- `classes/druid/combo.lua:103` — `clickContext.normalRelic = macroTorch.computeNormalRelic(clickContext)` — 调用入口
- `classes/druid/combo.lua:112` — `macroTorch.recoverNormalRelic(clickContext, clickContext.normalRelic)` — 切换执行
- `classes/druid/cat.lua:260` — `dischargeEnergyChangeRelicAndRip` — 打 Rip 前的 Savagery 兜底切换，不动
- `core/combat_context.lua:21-31` — 退战清空 context，退战进战初始化 `macroTorch.context = {}`

### New/Modified Code
- **`computeNormalRelic()` 重写** — 将当前 27 行嵌套 if-else 替换为 ~22 行平级判断：`isInCombat` guard（非战斗预切）→ `isTrivialBattleOrPvp` → `isImmuneRip` → `isRipPresent` → else
- **`recoverNormalRelic()` 插入** — 在能量检查前插入 4 行距离旁路：`if target.distance >= 20 then ensureRelicEquipped; return end`
- **`selftest.lua` 追加** — Category O 测试块（~40 行），包含 6 核心 + 可选距离测试
</code_context>

<specifics>
## Specific Ideas

- 23-DESIGN.md 包含完整的 10 个验证场景，下游 agent 应在实现后逐项对照
- 距离阈值 20yd 的推导：(D-5)/7 ≥ 1.5 → D ≥ 15.5，取 20yd 为保守值（cat form 实际跑速 9+ yd/s）
- 不改动清单中的函数如有变更需求 → 先讨论，默认不动
- Gap 3（Rip 到期后来回切换）在未来可能成为独立 phase，但目前接受现有行为
</specifics>

<deferred>
## Deferred Ideas

- **Gap 3: Rip 到期后来回切换** — Rip 被 Bite 刷新后 isRipPresent 重新变为 true → 切回构建神像 → next Rip cycle 又切 Savagery。当前接受此行为，因为 Rip 到期后切回 Savagery 是合理的（重新打 Rip 需要 Savagery 快照）。永久记忆方案（`ripAppliedTargets`）被否决——若 Rip 意外到期需重打，Savagery 快照价值 > 1.5s GCD 成本。
- **距离检测增强** — 当前用固定 20yd 阈值。未来可考虑：动态猫德跑速计算（Feline Swiftness 天赋）、Dash buff 检测、区分"站桩放 FF"和"跑向目标"两种远距离状态。

None — 讨论在 Phase 23 范围内。
</deferred>

---

*Phase: 23-idol-dance-refactor*
*Context gathered: 2026-08-02*