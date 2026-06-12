# Phase 5: Druid 技能方法封装改造 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-13
**Phase:** 05-druid-player-cast-druid
**Areas discussed:** 迁移策略, 技能名映射表组织, 迁移顺序, 文件归属

---

## Safe/Ready 函数迁移策略

| Option | Description | Selected |
|--------|-------------|----------|
| 全量替换 | 所有 player.cast() + safe/ready 函数一次性替换为技能方法调用，删除旧函数 | ✓ |
| 渐进包装 | safe/ready 函数内部改为调用新技能方法，作为 thin wrapper 保留 | |
| 仅替换 cast | 只替换直接 player.cast() 调用，safe/ready 保持不变 | |

**User's choice:** 全量替换
**Notes:** 干净彻底，避免新旧模式共存。改动面约 35 处调用点 + ~20 个 safe/ready 函数。

---

## 技能名映射表组织

| Option | Description | Selected |
|--------|-------------|----------|
| 内联 (方案当前设计) | 每个技能方法内部直接写 { en = '...', zh = '...' } | ✓ |
| 集中常量表 | 在 Druid.lua 顶部定义集中映射表 DRUID_SPELL_NAMES | |
| 按形态文件拆分 | cat/bear/utility 各自维护映射 | |

**User's choice:** 内联 (方案当前设计)
**Notes:** 简洁直接，每个方法自包含，与 spell_refactor_plan_druid.txt 设计一致。

---

## 迁移顺序

| Option | Description | Selected |
|--------|-------------|----------|
| 核心优先 | Druid.lua（定义）→ cat.lua → bear.lua → utility.lua | ✓ |
| 简单优先 | utility.lua → bear.lua → cat.lua → Druid.lua | |
| 一次性迁移 | 所有文件在同一 commit 中迁移 | |

**User's choice:** 核心优先
**Notes:** 先建立基础设施（技能方法定义），再逐步迁移调用方。cat.lua 最复杂有 11 处调用。

---

## 技能方法文件归属

| Option | Description | Selected |
|--------|-------------|----------|
| 集中在 Druid.lua | 所有 ~40 个技能方法定义在 Druid:new() 中 | ✓ |
| 按形态分散 | 猫形态放 cat.lua，熊形态放 bear.lua | |
| Druid.lua + 按需补充 | 核心放 Druid.lua，形态专有可分散 | |

**User's choice:** 集中在 Druid.lua
**Notes:** 技能方法是形态无关的接口定义，集中便于维护。调用方通过 player.xxx() 调用。

---

## Claude's Discretion

- `_isInRange(range)` 具体实现（使用现有 `macroTorch.target.distance`）
- `_hasResource(cost)` 具体实现（基于 `self.mana`）
- 新增方法在 entity/Player.lua 中的代码风格和位置
- 熊形态动态消耗的具体数值（暂用固定值）
- `_castSpell` 边界情况处理（target 为 nil 等）

## Deferred Ideas

- 其他职业（Hunter/Mage/Priest/Rogue/Warlock/Warrior）技能方法封装 → 未来独立 Phase
- 熊形态怒气消耗计算函数 → 后续 Phase 补充
- 多语言扩展（ko/ru 等）→ 内联表方式当前足够
- 物品/饰品方法封装 → 未来考虑