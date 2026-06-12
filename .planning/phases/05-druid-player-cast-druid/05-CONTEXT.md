# Phase 5: Druid 技能方法封装改造 - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning

<domain>
## Phase Boundary

将 `player.cast('技能名')` 字符串调用重构为技能对象方法（如 `player.claw()` / `player.wrath('safe')`），通过 `_castSpell` 共享辅助方法支持多语言客户端（中/英）。从 Druid 试点，覆盖 ~40 个技能，涉及 4 个文件约 35 处 `player.cast()` 调用点。

后续其他职业（Hunter、Mage 等）将参照 Druid 模式推进。
</domain>

<decisions>
## Implementation Decisions

### 迁移策略
- **D-01:** 全量替换。所有 `player.cast('技能名')` 调用、safe/ready 封装函数（如 safeShred、readyClaw 等约 20 个）一次性替换为技能方法调用，旧函数删除。不再保留 thin wrapper。

### 技能名映射表
- **D-02:** 内联表。每个技能方法内部直接写 `{ en = 'Claw', zh = '爪击' }`，不引入集中常量表或外部配置文件。简单直接，方法自包含。

### 迁移顺序
- **D-03:** 核心优先。`classes/druid/Druid.lua`（技能方法定义）→ `classes/druid/cat.lua`（11 处调用，最复杂）→ `classes/druid/bear.lua`（6 处）→ `classes/druid/utility.lua`（13 处）。先建立基础设施再逐步迁移调用方。

### 文件归属
- **D-04:** 所有 Druid 技能方法（~40 个）集中在 `classes/druid/Druid.lua` 的 `Druid:new()` 构造函数中。cat/bear/utility 中的调用方通过 `player.xxx()` 直接调用。技能方法本身是形态无关的接口定义，集中便于维护。

### 架构设计（来自 spell_refactor_plan_druid.txt）
- **D-05:** Player 基类新增 `_castSpell(localeNames, mode, range, resourceCost, onSelf)` 方法，负责：locale 选名 → ready 检查 → safe 检查（距离+资源）→ 调用 `self:cast(spellName, onSelf)`。
- **D-06:** mode 参数：`nil`（默认 ready 策略）、`'raw'`（直接释放）、`'safe'`（ready + 距离 + 资源检查）。
- **D-07:** 技能方法签名分三种类型：
  - **类型 A**（敌方目标）：`player.claw(mode)` — onSelf 固定 false
  - **类型 B**（自身目标）：`player.prowl(mode)` — onSelf 固定 true
  - **类型 C**（灵活目标）：`player.healing_touch(mode, onSelf)` — onSelf 透传
- **D-08:** resourceCost 同时接受数字（固定消耗）和函数引用（动态消耗，如 `macroTorch.computeClaw_E`），由 `_castSpell` 内部判断 type 后调用。

### Claude's Discretion
- `_isInRange(range)` 的具体实现（使用现有 `macroTorch.target.distance` 模式）
- `_hasResource(cost)` 的具体实现（基于 `self.mana`，WoW 1.12.1 按形态自动返回对应资源）
- 新增辅助方法在 `entity/Player.lua` 中的精确位置和代码风格
- 技能方法清单中熊形态动态消耗的具体数值（spec 标注"先标为固定值，后续完善"）
- `_castSpell` 内部的错误处理和边界情况（target 为 nil 等）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 权威技术方案
- `docs/spell_refactor_plan_druid.txt` — 完整技术方案：架构设计、`_castSpell` 流程、技能签名分类、Druid 技能清单（~40 个含英文名/中文名/距离/消耗）、实施步骤、注意事项

### 项目级文档
- `.planning/ROADMAP.md` — Phase 5 目标和依赖
- `.planning/REQUIREMENTS.md` — R8 (Druid 猫德逻辑保持) 约束

### 先前 Phase 决策
- `.planning/phases/04-class-files/04-CONTEXT.md` — Phase 4 产出 druid/ 目录结构，Druid.lua/cat.lua/bear.lua/utility.lua 文件边界
- `.planning/phases/03-spell-trace/03-CONTEXT.md` — D-06 (SpellTrace:register 声明式 API)，技能方法不影响 spell trace 注册

### 关键源文件
- `entity/Player.lua` — `player.cast(spellName, onSelf)` 当前实现，`_castSpell`/`_isInRange`/`_hasResource` 新增位置
- `classes/druid/Druid.lua` — Druid:new() 构造函数，所有技能方法新增位置
- `classes/druid/cat.lua` — 11 处 `player.cast()` + safe/ready 函数，主要迁移目标
- `classes/druid/bear.lua` — 6 处 `player.cast()` + bear safe/ready 函数
- `classes/druid/utility.lua` — 13 处 `player.cast()` + buff/控制相关

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — OOP metatable 继承链、safe/ready 双模式、clickContext 模式
- `.planning/codebase/CONVENTIONS.md` — 全局函数命名惯例、safe/ready 模式、能量常量命名
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`entity/Player.lua` `player.cast(spellName, onSelf)`**: 当前字符串驱动的释放方法，`_castSpell` 最终调用它。需要理解其参数语义以正确透传 onSelf。
- **`macroTorch.computeClaw_E()` / `computeShred_E()` 等**: 现有动态能量消耗计算函数，作为 `resourceCost` 函数引用传入。
- **`macroTorch.target.distance`**: 现有距离计算属性（Unit base），`_isInRange` 基于此实现。
- **`player.mana`**: WoW 1.12.1 中 UnitMana 在不同形态下自动返回能量/怒气/蓝量，`_hasResource` 直接使用。

### Established Patterns
- **safe/ready 双模式**: 当前 safeXxx 检查资源后调 readyXxx，readyXxx 检查 CD 后调 player.cast()。技能方法通过 mode 参数统一这三种调用方式。
- **clickContext 缓存**: 能量消耗在 catAtk 入口计算并缓存。技能方法的 resourceCost 函数引用依赖此机制 — 函数在 `_castSpell` 内部被调用时，期望 clickContext 中的值已就绪。
- **全局函数 vs 实例方法**: Player.lua 中的方法定义在 `Player:new()` 构造函数内（`function obj.cast(...)`），Druid 技能方法同理定义在 `Druid:new()` 内。

### Integration Points
- **`entity/Player.lua`**: 新增 `_castSpell`、`_isInRange`、`_hasResource` 三个方法
- **`classes/druid/Druid.lua`**: `Druid:new()` 构造函数中新增 ~40 个技能方法
- **`classes/druid/cat.lua`**: 替换 `player.cast()` 调用 + 删除 safe/ready 函数（safeShred、readyShred、safeClaw、readyClaw、safeRake、safeRip、safeBite、readyBite、safeCower、readyCower、safeTigerFury、safePounce 等）
- **`classes/druid/bear.lua`**: 替换调用 + 删除 bear safe/ready 函数（safeMaul、safeSwipe、safeSavageBite 等）
- **`classes/druid/utility.lua`**: 替换调用点
- **`build_order.txt`**: 不需要变更（文件路径不变）
</code_context>

<specifics>
## Specific Ideas

- `_castSpell` 是 Player 基类方法，使用 `self:_castSpell(...)` 调用，利用 metatable 继承链使 Druid 实例直接可用
- 技能方法内部极简：1-4 行，仅做参数转发，所有逻辑集中在 `_castSpell`
- `resourceCost` 为函数时无参数调用（如 `macroTorch.computeClaw_E()`），期望返回数字
- 距离参数直接使用码数（如 30 表示 30yd），与 WoW API 约定一致
- 熊形态技能消耗标注"动态（函数）"但当前无计算函数：Phase 5 使用固定值，后续完善
</specifics>

<deferred>
## Deferred Ideas

- **其他职业迁移**: Hunter、Mage、Priest、Rogue、Warlock、Warrior 的技能方法封装属于各自独立的未来 Phase。Druid Phase 5 建立模式和基类基础设施后，其他职业可参照推进。
- **熊形态怒气消耗计算函数**: 当前 spec 标注熊形态技能消耗为"动态（函数）"但无现成计算函数。Phase 5 先用固定值，后续 Phase 补充精确计算。
- **多语言扩展**: 当前仅支持 en/zh。内联表方式添加新语言需逐个方法修改，若未来支持更多语言（如 ko、ru），可考虑集中映射方案。当前足够。
- **物品/饰品方法封装**: 技能方法模式当前仅覆盖 spell，物品使用（`player.use()`）保持原样。

None — 讨论保持在 Phase 5 范围内。
</deferred>

---

*Phase: 05-Druid 技能方法封装改造*
*Context gathered: 2026-06-13*