# Phase 7: Druid 形态判断语义化方法 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-15
**Phase:** 07-druid
**Areas discussed:** 方法定义位置, isInBearForm 覆盖范围, 未使用方法的取舍

---

## 方法定义位置

| Option | Description | Selected |
|--------|-------------|----------|
| Option E: DRUID_FIELD_FUNC_MAP (推荐) | 5 个方法定义为 DRUID_FIELD_FUNC_MAP 计算属性，与 isOoc/isProwling/isBerserk 风格一致。isFormActive 保留在 Player 基类作为通用 fallback | ✓ |
| Option A: Player 基类 | 定义在 entity/Player.lua 的 PLAYER_FIELD_FUNC_MAP，所有职业可用 | |
| Option C: 纯 DRUID_FIELD_FUNC_MAP | 仅 DRUID_FIELD_FUNC_MAP，不保留 isFormActive | |
| Option B: Druid:new() 构造函数 | 在 Druid:new() 内定义为闭包实例方法 | |

**User's choice:** Option E: DRUID_FIELD_FUNC_MAP 计算属性 + 保留 isFormActive
**Notes:** 与现有 isOoc/isProwling/isBerserk 模式完全一致。调研 agent 发现现有 self-test (Druid.lua:1267) 已预期 `macroTorch.player.isInCatForm` 可用，Option E 直接满足。

---

## isInBearForm 覆盖范围

| Option | Description | Selected |
|--------|-------------|----------|
| Option B: 两者都检查 (推荐) | `self:isFormActive('Bear Form') or self:isFormActive('Dire Bear Form')` — 覆盖 level 10-39 德鲁伊 | ✓ |
| Option A: 仅 Dire Bear Form | `self:isFormActive('Dire Bear Form')` — 与现有 5 处调用行为完全一致 | |

**User's choice:** Option B: 同时检查 'Bear Form' + 'Dire Bear Form'
**Notes:** 两种形态在 WoW 1.12.1 形态条上互斥，OR 逻辑零歧义。现有代码 5 处硬编码 'Dire Bear Form' 很可能仅因从未被低级德鲁伊测试过。

---

## 未使用方法的取舍

| Option | Description | Selected |
|--------|-------------|----------|
| Option C: 全实现+注释 (推荐) | 5 个全部实现，未调用的 3 个标注 `-- reserved for future expansion` | ✓ |
| Option A: 全部实现 | 5 个全部实现，不做特殊标注 | |
| Option B: 仅 Cat + Bear | 严格 YAGNI，仅实现有实际调用的 isInCatForm + isInBearForm | |

**User's choice:** Option C: 全 5 个实现 + 注释标注
**Notes:** 每个方法仅 ~5 行，极低成本。与 Phase 5 已有的形态技能方法形成对称 API。注释降低未来维护者困惑。

---

## Claude's Discretion

- DRUID_FIELD_FUNC_MAP 中 5 个新属性的精确顺序和位置
- 注释措辞（`-- reserved for future expansion`）
- self-test 注册的具体实现（复用现有 Category D Druid 测试模式）

## Deferred Ideas

- **Travel/Aquatic/Caster 形态战斗逻辑**: 目前代码库中无相关实现，属于未来 Phase
- **Warrior Stance 语义化方法**: 参照 Druid 模式为 Warrior 类添加语义化 Stance 方法
- **DRUID_FIELD_FUNC_MAP 性能优化**: 当前 metatable 查找开销对 WoW 宏系统可忽略