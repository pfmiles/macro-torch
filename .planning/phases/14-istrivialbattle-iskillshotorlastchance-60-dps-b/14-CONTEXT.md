# Phase 14: isTrivialBattle / isKillShotOrLastChance 等级自适应 - Context

**Gathered:** 2026-06-20
**Status:** Ready for planning

<domain>
## Phase Boundary

将 `isTrivialBattle` 和 `isKillShotOrLastChance` 中硬编码的 60 级静态估算替换为等级自适应的动态估算，使低等级角色也能准确判断"快速战斗"和"斩杀线"。

**核心改动两项：**
1. **`isTrivialBattle`** — 条件B 的 `500` DPS/人 替换为等级-DPS 查表
2. **`isKillShotOrLastChance`** — 删除全部 15 个 `KS_CP*_Health` 静态常量，条件B 简化为等级自适应的单一血量阈值；条件A（`willDieInSeconds(2)`，基于 HRPS 实时数据）保持为主路径

**关键约束：** 60 级满级行为完全不变。所有查表在 60 级输出值与当前硬编码等价。

**涉及文件：**
- `classes/druid/Druid.lua` — `isTrivialBattle`(769)、`isKillShotOrLastChance`(830)、KS_* 常量(807-823) 的修改
- `core/selftest.lua` — 新增等级自适应验证 selftest

**不涉及：** `willDieInSeconds` / `currentHRPS`（已是动态的，正确）、`isTrivialBattleOrPvp`（仅做 OR 组合，无需改动）、其他职业（仅 Druid scope）
</domain>

<decisions>
## Implementation Decisions

### DPS 估算策略
- **D-01:** 采用**等级-DPS 查表**。预设每个等级段的玩家期望 DPS（如 `[20-29]=60, [30-39]=120, [40-49]=200, [50-59]=350, [60]=500`），`isTrivialBattle` 条件B 直接查表取值。不使用 AP 公式（能量系统是猫德 DPS 的首要瓶颈，AP 单一变量无法准确建模）。

### 斩杀阈值策略
- **D-02:** `isKillShotOrLastChance` 条件B 从"15 个 KS_CP*_Health 常量 × CP 粒度 × 3 模式"简化为**单一血量阈值等级查表**（`KS_HEALTH_THRESHOLD`），不区分 CP 和 solo/group/raid。条件A（`willDieInSeconds(2)`）保持为主路径。
- **D-03:** 删除全部 15 个 `macroTorch.KS_CP*_Health*` 模块级常量（`Druid.lua:807-823`）。`isKillShotOrLastChance` 内部逻辑简化：条件A `willDieInSeconds(2)` → true 分支保留；条件B 简化为 `targetHealth < getKSThreshold(playerLevel)`。

### 代码组织
- **D-04:** 在 `classes/druid/Druid.lua` 中新增独立函数（`estimatePlayerDPS`、`getKSThreshold`），遵循 Phase 13 `computeReshiftEnergy` 模式。60 级加硬 guard：`if level == 60 then return 旧值 end`，确保满级行为零风险。
- **D-05:** 低等级数据不足时采用**保守 fallback**：`isTrivialBattle` → false（不触发快速战斗模式），`isKillShotOrLastChance` → 仅依赖 `willDieInSeconds`（无 HRPS 数据时不触发斩杀）。宁可保守不冒进。

### 测试策略
- **D-06:** 在 `core/selftest.lua` 中新增 ~6 个 Category I selftest：60 级 DPS 输出=500 验证、60 级 KS 阈值=1750 验证、低等级 DPS 查表区间边界验证、低等级 KS 阈值查表验证、条件A 功能不变验证（willDieInSeconds 路径未受影响）、保守 fallback 验证。

### Claude's Discretion
- 等级段的具体划分（几级一个段，是否每 10 级）
- 各等级段 DPS 和 KS 阈值的具体数值
- `getKSThreshold` 的 solo/group/raid 倍率是否需要保留（可在函数内用简单系数处理）
- 具体查表实现方式（if-elseif 链 vs table 查找）
- Selftest 的具体用例数量和边界覆盖
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 14 目标："将 isTrivialBattle 和 isKillShotOrLastChance 中硬编码的60级静态DPS估算（条件B）替换为等级自适应的动态估算"
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束

### 先前 Phase 决策
- `.planning/phases/13-catatk-60-dps/13-CONTEXT.md` — Phase 13 技能存在性 guard 模式 + `computeReshiftEnergy` 先例 + `isSpellExist` 基础设施
- `.planning/phases/10-5-druid-druidatk-druidaoe-druidheal-druiddefend-druidcontrol/10-CONTEXT.md` — if-elseif 形态路由模式

### 关键源文件
- `classes/druid/Druid.lua:769-778` — `isTrivialBattle()` 当前实现（硬编码 500 DPS）
- `classes/druid/Druid.lua:807-823` — 15 个 `KS_CP*_Health*` 常量定义（需删除）
- `classes/druid/Druid.lua:830-885` — `isKillShotOrLastChance()` 当前实现（需简化）
- `classes/druid/Druid.lua:763-766` — `isTrivialBattleOrPvp()`（仅 OR 组合，无需改动）
- `classes/druid/Druid.lua:556-564` — `computeClaw_E()` 动态能耗计算（查表+天赋查询的参考模式）
- `entity/Target.lua:86-98` — `willDieInSeconds(s)`（条件A，已是动态的，不改动）
- `entity/Target.lua:132-158` — `currentHRPS()`（线性回归 HRPS 计算，不改动）
- `biz_util.lua:75-77` — `isSpellExist(spellName, bookType)`（已有基础设施）

### 构建系统
- `build_order.txt` — 确认文件加载顺序
- `build.sh` — 严格模式

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — metatable __index 链、clickContext 缓存模式、模块优先级执行模型
- `.planning/codebase/CONVENTIONS.md` — 点号语法、全局函数命名、camelCase 约定
</canonical_refs>

<code_context>
## Existing Code Insights

### 当前 isTrivialBattle 条件B 硬编码
```lua
-- Druid.lua:769-778
function macroTorch.isTrivialBattle(clickContext)
    if clickContext.isTrivialBattle == nil then
        local trivialDieTime = 25
        clickContext.isTrivialBattle = macroTorch.target.willDieInSeconds(trivialDieTime) or
                macroTorch.target.healthMax <=
                        (macroTorch.player.mateNearMyTargetCount + 1) * 500 * trivialDieTime
    end
    return clickContext.isTrivialBattle
end
```
需将 `500` 替换为 `estimatePlayerDPS(level)` 查表调用。

### 当前 isKillShotOrLastChance 的 15 个常量
```lua
-- Druid.lua:807-823 — 全部需删除
macroTorch.KS_CP1_Health = 750
macroTorch.KS_CP2_Health = 1000
... (共 15 个)
```

### 当前 isKillShotOrLastChance 的复杂分支
```lua
-- Druid.lua:830-885
function macroTorch.isKillShotOrLastChance(clickContext)
    -- 条件A: willDieInSeconds(2) — 保留不变
    if macroTorch.target.willDieInSeconds(2) then
        return true
    end
    -- 条件B: 当前是 50+ 行 CP×mode 分支 → 简化为单阈值查表
    ...
end
```

### Reusable Assets
- **`UnitLevel('player')`** — WoW 1.12.1 原生 API，获取玩家等级
- **`macroTorch.isSpellExist(spellName, bookType)`** (`biz_util.lua:75`) — 已存在
- **`macroTorch.SelfTest:register(name, fn, isOptional)`** (`core/selftest.lua`) — 已有自检框架
- **`macroTorch.toBoolean(v)`** — 已有布尔归一化函数

### Established Patterns
- **clickContext 单次缓存模式**: `isTrivialBattle` 和 `isFightStarted` 已使用 `if clickContext.X == nil then compute; cache end` 模式
- **Phase 13 独立函数先例**: `computeReshiftEnergy` 被提取为独立函数放在 Druid.lua 中
- **60级硬 guard 先例**: Phase 13 所有 `isSpellExist` guard 在 60 级满技能时永不触发
- **保守 guard 模式**: `if not condition then return end` — 数据不足时静默跳过

### Integration Points
- `classes/druid/Druid.lua:769` — `isTrivialBattle` 条件B 插入 `estimatePlayerDPS(level)`
- `classes/druid/Druid.lua:807-823` — 删除 15 个 KS_CP* 常量
- `classes/druid/Druid.lua:830-885` — 简化 `isKillShotOrLastChance` 条件B
- `classes/druid/Druid.lua:763` — `isTrivialBattleOrPvp` 无需改动
- `core/selftest.lua` — 新增 Category I 测试注册
</code_context>

<specifics>
## Specific Ideas

- 条件A（`willDieInSeconds(2)`）是斩杀判断的**主路径**——基于 HRPS 线性回归的实时数据，精度最高且始终正确。条件B 仅作为 HRPS 数据不足时（如刚切目标）的 fallback，使用频率低。
- 60 级硬 guard（`if level == 60 then return 旧值 end`）确保满级行为绝对不变，这是该插件的最高价值路径。
- 15 个 KS_CP* 常量全部删除后，`isKillShotOrLastChance` 从 ~55 行缩减到 ~15 行，大幅简化。
- 等级段划分参考：每 10 级一个段（10-19/20-29/.../60），与 WoW 技能等级的自然分段对齐。
- 各等级段 DPS 值可从经典怀旧服练级数据或 `computeClaw_E` 的能量→伤害反推获得。
</specifics>

<deferred>
## Deferred Ideas

- **其他职业的 DPS 估算**: Warrior/Rogue 等职业也有类似问题（硬编码 DPS 假设），属于各自的未来 Phase。
- **AP 感知 DPS 估算**: 当前查表方案不感知装备差异。如果未来发现装备差异在特定等级段导致显著偏差，可升级为混合方案（baseline + AP 贡献项）。当前等级查表是合理的 MVP。
- **isKillShotOrLastChance 的 group/raid 倍率**: 当前简化为单阈值，如需区分 solo/group/raid 场景，可在 `getKSThreshold` 中加简单系数（×2 for group, ×3 for raid），无需恢复 15 个常量。

None — 讨论保持在 Phase 14 范围内。
</deferred>

---

*Phase: 14-istrivialbattle-iskillshotorlastchance-60-dps-b*
*Context gathered: 2026-06-20*