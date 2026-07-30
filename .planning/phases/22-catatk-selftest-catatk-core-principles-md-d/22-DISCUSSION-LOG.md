# Phase 22: catAtk-selftest-catatk-core-principles-md-d - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-30
**Phase:** 22-catatk-selftest-catatk-core-principles-md-d
**Areas discussed:** 实施范围, 测试命名规范, 游戏依赖处理, 函数签名增强, 测试放置位置, principles.md 命名修正, Commit 策略, 文件组织

---

## 实施范围 — batch 策略

| Option | Description | Selected |
|--------|-------------|----------|
| Batch 1+2 | Batch 1 + 2（~38 tests）— 覆盖所有纯函数和条件决策测试，跳过需要函数签名的副作用验证 | ✓ |
| 全部 3 个 batch | 完整覆盖 ~50 tests，包括需要给 energyDischargeBeforeBite/cp5Bite 加返回值的 Batch 3 | |
| Batch 1 + 精选 | Batch 1 + 部分 Batch 2 — 最小可行范围 | |

**User's choice:** Batch 1+2

---

## 优先级（实施范围内）

| Option | Description | Selected |
|--------|-------------|----------|
| 按规则编号顺序 | 按规则编号顺序 1→9，pure functions 放在最前 | ✓ |
| 按难度递增 | 从最简单到最复杂 | |
| 精选核心规则 | 只做最重要的 5 个规则 | |

**User's choice:** 按规则编号顺序

---

## 测试命名规范

| Option | Description | Selected |
|--------|-------------|----------|
| Principle R<n>: xxx | 新格式与原则文档直接对应 | ✓ |
| Druid: xxx | 沿用现有 Druid 测试命名 | |
| Category Q: xxx | 遵循现有字母分类体系 | |

**User's choice:** Principle R<n>: xxx

---

## 命名细节

| Option | Description | Selected |
|--------|-------------|----------|
| 编号 + 简短描述 | "Principle R1-01: overflow prevention — skip energy discharge" | ✓ |
| 仅规则号 + 描述 | 无子编号 | |
| Category Q 前缀 | 加入 Category Q 前缀 | |

**User's choice:** 编号 + 简短描述

---

## 游戏依赖处理

| Option | Description | Selected |
|--------|-------------|----------|
| 条件 skip | 非 Druid/没天赋/没装备时静默 return，有条件时正常 assert | ✓ |
| 条件 assert 预期值 | assert 返回 0 表明不可测 | |
| 直接跳过 R2 | 不测 computeReshiftEnergy/shouldDoReshift | |

**User's choice:** 条件 skip

---

## Mana 依赖处理

| Option | Description | Selected |
|--------|-------------|----------|
| clickContext 预设值 | 测试中预设 clickContext 字段，绕过游戏状态 | ✓ |
| pcall + 不crash验证 | 降低断言精度 | |
| 函数签名微调 | 给 shouldDoReshift 加可选参数重载 | |

**User's choice:** clickContext 预设值

---

## 函数签名增强

| Option | Description | Selected |
|--------|-------------|----------|
| 不改函数签名 | Batch 1+2 被测函数已有返回值 | ✓ |
| 仅加返回值 | 给 energyDischargeBeforeBite 和 cp5Bite 加返回值 | |
| 全部加返回值 | 所有无返回值决策函数统一加 | |

**User's choice:** 不改函数签名

---

## 测试放置位置

| Option | Description | Selected |
|--------|-------------|----------|
| 新文件 | classes/druid/selftest.lua — 不膨胀现有文件 | ✓ |
| selftest.lua 集中 | core/selftest.lua 集中管理 | |
| Druid.lua 追加 | 与现有 Druid 测试一起 | |

**User's choice:** 新文件

---

## 文件组织

| Option | Description | Selected |
|--------|-------------|----------|
| 单文件全量 | 所有 38 tests 在同一个文件中，按规则编号排序 | ✓ |
| 按 Batch 分文件 | Batch 1/2 各自独立文件 | |
| 按规则分文件 | 每个规则一个文件 | |

**User's choice:** 单文件全量

---

## principles.md 命名修正

| Option | Description | Selected |
|--------|-------------|----------|
| 修正 | isInfiniteEnergy → isPseudoInfiniteEnergy | ✓ |
| 留给后续 | 留给专门的文档 Phase | |
| 记录为 Deferred | 记下来但不做 | |

**User's choice:** 修正

---

## Commit 策略

| Option | Description | Selected |
|--------|-------------|----------|
| 分 Batch 提交 | Batch 1 → Batch 2 两个独立 commit | ✓ |
| 单 commit 全量 | 所有改动一个 commit | |
| 源码 + 文档分离 | 新文件与 doc fix 分开 | |

**User's choice:** 分 Batch 提交

---

## Claude's Discretion

- 测试函数内部 assert 条件的具体措辞
- clickContext 预设字段的具体命名和值
- selftest.lua 内部注释结构（规则分区 header 格式）
- 条件 skip guard 的具体写法（`UnitClass` check + `talentRank` + `isKeywordInEquippedItemTooltip`）
- `isOptional` 参数：所有 Principle R 测试统一用 `true`（Druid 专属）

## Deferred Ideas

- **Batch 3 副作用验证测试**: R1-01~04, R12-01~03 — 需要函数签名增强，留给后续 phase
- **active FF maintenance test**: Rule 8 主动 FF 维护（未实现，先不测）
- **集成级 catAtk() 调用测试**: 完整 clickContext 构造 + catAtk() 调用 — 风险高，留待后续