# Phase 13: catAtk 小号练级适配 - Context

**Gathered:** 2026-06-20
**Status:** Ready for planning

<domain>
## Phase Boundary

使 `catAtk` 一键宏适配低等级角色练级场景（10-50级），核心改动三项：
1. **技能存在性检查** — 通过 `isSpellExist()` 守卫未学习的技能模块
2. **动态能量消耗计算** — `RESHIFT_ENERGY` 从硬编码改为基于天赋+装备的动态计算
3. **低等级降级策略** — 模块级 guard 自动跳过不可用技能，rotation 自然降级到可用技能子集

**关键约束**：保持60级满级极限DPS能力完全不变。所有 guard 在60级满技能+满天赋下不触发，代码路径与改动前等价。

**涉及文件：**
- `classes/druid/Druid.lua` — 共享决策函数（`shouldUseShred`/`shouldCastRip`/`shouldUseBite` 等）加 guard + `RESHIFT_ENERGY` 动态计算
- `classes/druid/cat.lua` — 各模块（`keepRip`/`keepRake`/`keepFF`/`keepTigerFury`/`termMod`/`openerMod`/`otMod` 等）入口加 `isSpellExist` guard
- `core/selftest.lua` — 新增 catAtk 低等级路径 selftest

**不涉及：** 技能 rank 参数（Phase 5 已支持，默认最高 rank）、天赋依赖性计算（`computeClaw_E` 等已动态查 talentRank）、神像舞（`hasItem` guard 已存在）、CP 阈值调整（quick battle 由战斗时长预判驱动，与等级无关）。
</domain>

<decisions>
## Implementation Decisions

### 技能模块守卫策略
- **D-01:** 统一使用模块级 `isSpellExist` guard 模式。每个 catAtk 模块入口检查该模块依赖的核心技能是否存在，不存在则 `return`（静默跳过，继续执行后续模块）。与现有 `reshiftMod`（`cat.lua:177`）模式完全一致。
- **D-02:** 以下模块需加 `isSpellExist` guard（具体技能由 planner 读代码确认）：
  - `keepRip` → Rip
  - `keepRake` → Rake
  - `keepFF` → Faerie Fire (Feral)
  - `keepTigerFury` → Tiger's Fury
  - `termMod` → Ferocious Bite
  - `openerMod` → Pounce / Ravage
  - `otMod` → Cower
  - `regularAttack` → 通过 `shouldUseShred` 内部 guard 自然降级到 Claw

### 共享决策函数守卫
- **D-03:** `shouldUseShred`、`shouldCastRip`、`shouldUseBite` 等共享决策函数内部也加 `isSpellExist` guard。这些函数被 `getMinimumAffordableAbilityCost` 调用（用于 reshift 决策），一处 guard 全局生效。不存在技能的决策函数直接返回 false，调用链自然 fallback 到 Claw。

### Reshift 适配
- **D-04:** `RESHIFT_ENERGY` 从硬编码 `60`（`Druid.lua:338`）改为动态计算：`Furor天赋rank × 8 + (狼头头盔存在 ? 20 : 0)`。低等级无 Furor 且无狼头时 RESHIFT_ENERGY = 0，`shouldDoReshift` 自动判断"不划算"而不触发 reshift。
- **D-05:** `reshiftMod` 入口的 `isSpellExist('Reshift')` guard 保持不变（`cat.lua:177`），低等级干净跳过整个模块。

### 连击点阈值
- **D-06:** 不做等级感知的 CP 阈值调整。现有 `isTrivialBattleOrPvp` 由战斗时长预判驱动，与角色等级无关。低等级战斗天然更短，自动落入 quick battle 分支（低星 Rip）。

### 测试策略
- **D-07:** 在 `core/selftest.lua` 中添加 catAtk 低等级路径 selftest：
  - 技能存在时的正常执行路径验证
  - 技能不存在时各模块正确跳过验证
  - `shouldUseShred`/`shouldCastRip`/`shouldUseBite` 在技能不存在时返回 false 验证
  - `RESHIFT_ENERGY` 动态计算正确性验证

### 风险防控
- **D-08:** Planner 需逐点审查所有 guard 插入点，确保：
  - 无 nil 引用路径（模块 return 后后续模块仍能正常执行）
  - 无隐式假设断裂（如"keepRip 返回后 keepRake 一定能执行"之类）
  - `getMinimumAffordableAbilityCost` 在技能大量缺失时能正确 fallback 到 Claw

### Claude's Discretion
- 各模块具体 `isSpellExist` 检查的技能名称（对应 locale 表）
- `RESHIFT_ENERGY` 动态计算函数的具体实现位置（内联 vs 独立函数）
- Selftest 的具体用例数量和覆盖范围
- `shouldCastFFDuringWaitWindow` 是否需要 guard（被 `shouldUseShred` 间接调用）
- Guard 插入的具体代码行位置和格式
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 13 目标："使catAtk一键宏适配小号练级场景：技能存在性检查、动态能量消耗计算、低等级降级策略，同时保持60级满级极限DPS能力不变"
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束

### 先前 Phase 决策
- `.planning/phases/05-druid-player-cast-druid/05-CONTEXT.md` — D-05/D-06/D-07: `_castSpell` 架构、技能方法签名分类、mode/rank 参数
- `.planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-CONTEXT.md` — D-01: 纯点号语法约定
- `.planning/phases/07-druid/07-CONTEXT.md` — D-01/D-02: 形态判断语义化方法（isInCatForm/isInBearForm 等）
- `.planning/phases/10-5-druid-druidatk-druidaoe-druidheal-druiddefend-druidcontrol/10-CONTEXT.md` — D-01: if-elseif 形态路由模式

### 关键源文件
- `classes/druid/Druid.lua:299-426` — `catAtk()` 主入口 + clickContext 构建 + 13 个模块调度
- `classes/druid/Druid.lua:338` — `RESHIFT_ENERGY = 60` 硬编码（需改为动态计算）
- `classes/druid/Druid.lua:556-564` — `computeClaw_E()` 动态能耗计算（参考模式）
- `classes/druid/Druid.lua:705-750` — `shouldUseShred()` 共享决策函数（需加 guard）
- `classes/druid/Druid.lua:953-982` — `getMinimumAffordableAbilityCost()` 最低技能消耗查询
- `classes/druid/Druid.lua:987-1023` — `shouldCastRip()` / `shouldUseBite()` 共享决策函数
- `classes/druid/cat.lua:128-146` — `energyDischargeBeforeBite()` 能量倾泻逻辑
- `classes/druid/cat.lua:176-185` — `reshiftMod()` 已存在的 `isSpellExist` guard（参考模式）
- `classes/druid/cat.lua:186-202` — `shouldDoReshift()` reshift 核心决策逻辑
- `classes/druid/cat.lua:210-220` — `keepRip()` 模块入口
- `classes/druid/cat.lua:260-292` — `quickKeepRip()` / `keepRake` 模块
- `biz_util.lua:75-77` — `isSpellExist(spellName, bookType)` 已有基础设施
- `entity/Player.lua:39-87` — `_castSpell(localeNames, mode, range, resourceCost, onSelf, rank)` 技能释放底层

### 构建系统
- `build_order.txt` — 确认文件加载顺序
- `build.sh` — 严格模式（Phase 4 收尾）

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — metatable __index 链、clickContext 缓存模式、模块优先级执行模型
- `.planning/codebase/CONVENTIONS.md` — 点号语法、全局函数命名、camelCase 约定
</canonical_refs>

<code_context>
## Existing Code Insights

### 已有的 isSpellExist 模式（参考实现）
```lua
-- cat.lua:177 — reshiftMod 入口（唯一已有的 guard）
function macroTorch.reshiftMod(clickContext)
    if not macroTorch.isSpellExist('Reshift', 'spell') then
        return
    end
    -- ... reshift 逻辑
end
```

### RESHIFT_ENERGY 当前硬编码
```lua
-- Druid.lua:338
clickContext.RESHIFT_ENERGY = 60
```
需改为动态计算。Furor 天赋每 rank +8 能量（最高 rank 5 = 40），狼头头盔 (Wolfshead Helm) +20。

### 共享决策函数当前未检查技能存在性
```lua
-- Druid.lua:705 — shouldUseShred 判断 Shred vs Claw
-- 内部检查：isBehind, comboPoints, erps vs cost, FF wait window 等
-- 缺少：isSpellExist('Shred') guard
function macroTorch.shouldUseShred(clickContext)
    -- ... 各种条件判断
end
```

### 动态能耗计算已有模式（可直接复用）
```lua
-- Druid.lua:556 — computeClaw_E 已动态查询天赋和装备
function macroTorch.computeClaw_E()
    local CLAW_E = 45
    if player.isItemEquipped('Idol of Ferocity') then CLAW_E = CLAW_E - 3 end
    CLAW_E = CLAW_E - player.talentRank('Ferocity')
    return CLAW_E
end
```

### 神像舞已是低等级安全
`recoverNormalRelic` (`Druid.lua:547`) 有 `player.hasItem(relicName)` guard，低等级无神像时自动 no-op。无需额外改动。

### getMinimumAffordableAbilityCost 的 fallback 链
该函数按 Bite → Tiger → Rip → Rake → Shred → Claw 优先级返回第一个"应该释放"的技能消耗。共享决策函数加 guard 后，不存在的技能自动被跳过，最终 fallback 到 Claw（level 1 即可学）。Claw 是兜底技能，始终可用。

### Reusable Assets
- **`macroTorch.isSpellExist(spellName, bookType)`** (`biz_util.lua:75`) — 已存在，`bearReshiftMod` 和 `reshiftMod` 已在使用
- **`player.talentRank(talentName)`** — 已存在，`computeClaw_E` 等已在使用，返回 0 表示未学习
- **`player.isItemEquipped(itemName)`** — 已存在，用于检测狼头头盔
- **`player.isSpellReady(spellName)`** — `_castSpell` 内部已用 pcall 包裹，不存在技能返回 false 不抛异常
- **`macroTorch.SelfTest:register(name, fn, isOptional)`** (`core/selftest.lua`) — 已有自检框架

### Established Patterns
- **模块级 guard 模式**: `if not condition then return end` — reshiftMod 已建立先例
- **clickContext 单次缓存**: 所有模块共享同一 clickContext，guard 插入不破坏此模式
- **模块顺序执行**: 模块按优先级排列，一个 return 后继续下一个，无依赖假设
- **共享决策函数**: Single Point of Truth 原则，guard 加在决策函数中受益所有调用方

### Integration Points
- `classes/druid/Druid.lua:299-426` — `catAtk()` 主函数，所有模块调度点
- `classes/druid/cat.lua` — 各模块实现文件，guard 插入目标
- `core/selftest.lua` — 新增测试注册
- `biz_util.lua:75` — `isSpellExist` 已就绪，无需改动
</code_context>

<specifics>
## Specific Ideas

- 所有 guard 改动是纯减法（加 `if not isSpellExist then return end`），不引入新代码路径。60级满技能时 guard 条件永不触发，代码路径等价于改动前。
- `shouldUseShred` 加 guard 后，`regularAttack` 自动 fallback 到 Claw（`shouldUseShred` 返回 false → 走 Claw 分支），无需额外修改 `regularAttack`。
- `getMinimumAffordableAbilityCost` 在各决策函数加 guard 后，不存在的技能自动被跳过，最终返回 CLAW_E。这使 `shouldDoReshift` 在低等级做出正确判断。
- Furor 天赋 rank 查询：`player.talentRank('Furor')` — planner 需确认 Turtle WoW 中该天赋的准确英文名。
- 狼头头盔检测：`player.isItemEquipped('Wolfshead Helm')` 或通过物品 ID/名称匹配 — planner 确认具体检测方式。
- Selftest 可覆盖：模拟60级满技能→所有 guard 不触发验证；模拟技能缺失→各模块正确跳过验证。
</specifics>

<deferred>
## Deferred Ideas

- **低等级专属 rotation 优化**: 当前仅做 guard 跳过，不引入低等级专属策略（如"缺 Rip 时多打 Rake"）。未来可按需添加等级感知的降级路径。
- **能量 tick 计算**: 当前 `AUTO_TICK_ERPS = 20/2` 在所有等级恒定，无需改动。Ancient Brutality 天赋 rank 已由现有逻辑动态查询。
- **非 Druid 职业练级适配**: 当前 Phase 仅针对 Druid catAtk。其他职业（Warrior/Rogue 等）的低等级适配属于各自未来 Phase。

None — 讨论保持在 Phase 13 范围内。
</deferred>

---

*Phase: 13-catatk-60-dps*
*Context gathered: 2026-06-20*