# Phase 13: catAtk 小号练级适配 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-20
**Phase:** 13-catatk-60-dps
**Areas discussed:** Reshift 适配, 技能降级策略, CP 阈值, 共享决策函数守卫, 测试策略, FF/TF 模块守卫, Lua 异常风险防控

---

## Reshift 适配

| Option | Description | Selected |
|--------|-------------|----------|
| 动态计算 RESHIFT_ENERGY | Furor rank × 8 + 狼头 20，shouldDoReshift 自动判断 | ✓ |
| isSpellExist + 硬编码 | 仅在入口 guard，保持 RESHIFT_ENERGY = 60 | |
| 不做特殊处理 | 依赖现有 shouldDoReshift 自然得出 false | |

**User's choice:** 动态计算 RESHIFT_ENERGY (Recommended)
**Notes:** 用户确认 reshiftMod 入口的 `isSpellExist('Reshift')` guard 已存在且足够。希望补充动态回能计算使 shouldDoReshift 在低等级更准确。用户表示 reshift 判断逻辑是 catAtk 的核心设计，希望在不破坏该逻辑的前提下干净 guard。

---

## 技能降级策略

| Option | Description | Selected |
|--------|-------------|----------|
| 模块级 isSpellExist guard | 每个模块入口检查关键技能，不存在则 return | ✓ |
| 集中预计算技能表 | catAtk 开头构建可用技能表 | |
| 依赖现有静默失败 | 让 _castSpell 内部 isSpellReady 自然失败 | |

**User's choice:** 模块级 isSpellExist guard (Recommended)
**Notes:** 与现有 reshiftMod 模式一致。用户希望干净跳过不可用模块，而非依赖静默失败。

---

## CP 阈值

| Option | Description | Selected |
|--------|-------------|----------|
| 不做调整 | 用户指出：quick battle 由战斗时长预判决定，与等级无关 | ✓ |
| 复用现有 quick battle | isTrivialBattleOrPvp 已处理短战斗 | |
| 等级感知动态阈值 | 按等级段设不同 CP 上限 | |

**User's choice:** 不做调整
**Notes:** 用户澄清：quick battle 的判断依据是战斗时长预判，不是角色等级。低等级战斗天然短，自动落入 quick battle 分支。CP 阈值不需要等级感知。

---

## 共享决策函数守卫

| Option | Description | Selected |
|--------|-------------|----------|
| 在共享决策函数中 guard | shouldUseShred/shouldCastRip/shouldUseBite 内部加 isSpellExist | ✓ |
| 仅在模块入口 guard | 决策函数不改 | |
| 集中在 getMinimum... 中过滤 | 单一过滤点 | |

**User's choice:** 在共享决策函数中 guard (Recommended)
**Notes:** 这些函数被 `getMinimumAffordableAbilityCost` 调用（影响 reshift 判断），一处 guard 全局受益。不存在技能的决策函数返回 false，调用链自然 fallback 到 Claw。

---

## 测试策略

| Option | Description | Selected |
|--------|-------------|----------|
| 添加 selftest 覆盖 | 验证技能存在/不存在两条路径 | ✓ |
| 仅人工 UAT checklist | 登录对应等级角色验证 | |
| 不需要专门测试 | 代码改动足够简单 | |

**User's choice:** 添加 selftest 覆盖 (Recommended)
**Notes:** selftest 应覆盖：技能存在时正常执行、技能不存在时正确跳过、决策函数 guard 正确性、RESHIFT_ENERGY 动态计算。

---

## FF/TF 模块守卫

| Option | Description | Selected |
|--------|-------------|----------|
| 统一模块级 guard | keepFF 和 keepTigerFury 入口加 isSpellExist | ✓ |
| 依赖现有静默失败 | safeFF/safeTigerFury 内部失败即可 | |
| 不做处理 | FF 和 TF 非核心，低等级不影响 | |

**User's choice:** 统一模块级 guard (Recommended)
**Notes:** 保持与 reshiftMod 一致的守卫模式。

---

## Lua 异常风险防控

| Option | Description | Selected |
|--------|-------------|----------|
| Planner 逐点审查 | PLAN.md 列出所有 guard 插入点 + 风险分析 | ✓ |
| Selftest pcall 包装 | pcall 包裹 catAtk 模拟执行 | |
| 改动本身安全 | 纯减法，不加新代码路径 | |

**User's choice:** Planner 逐点审查 (Recommended)
**Notes:** 虽然加 guard 是纯减法，但需确保模块 return 后后续模块仍能正常执行，避免隐式假设断裂。

---

## Claude's Discretion

- 各模块具体 `isSpellExist` 检查的技能名称（对应 locale 表）
- `RESHIFT_ENERGY` 动态计算函数的具体实现位置（内联 vs 独立函数）
- Selftest 的具体用例数量和覆盖范围
- `shouldCastFFDuringWaitWindow` 是否需要 guard
- Guard 插入的具体代码行位置和格式

## Deferred Ideas

- 低等级专属 rotation 优化（如"缺 Rip 时多打 Rake"）
- 非 Druid 职业练级适配
- 能量 tick 计算调整（当前全等级恒定，无需改动）