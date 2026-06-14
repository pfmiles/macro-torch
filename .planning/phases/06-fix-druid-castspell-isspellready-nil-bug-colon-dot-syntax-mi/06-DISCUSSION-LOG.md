# Phase 6: Fix Druid _castSpell isSpellReady nil bug - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-14
**Phase:** 06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi
**Areas discussed:** 修复策略, 公开方法的处理, 回归风险范围, _hasResource 的 self 引用

---

## 修复策略

| Option | Description | Selected |
|--------|-------------|----------|
| 最小修复 (推荐) | 仅修改 Player.lua 中 _castSpell 内部4处调用从冒号改为点号 | ✓ |
| 一致性修复 | 同时修改 _castSpell + _isInRange + _hasResource 三个私有方法为冒号定义 | |
| 全量统一 (不推荐) | 修改全部5个方法定义+全部外部调用点 (~70处) | |

**User's choice:** 最小修复 — 保持所有定义点号，仅修复调用端。

**Notes:** 用户在讨论中点号设计偏好时明确：metatable __index 链 + 闭包上值模式即可实现继承链，点号是正确且一致的选择。不需要改为冒号"正统"模式。

---

## 公开方法的处理

| Option | Description | Selected |
|--------|-------------|----------|
| 保持点号定义 (推荐) | isSpellReady 和 cast 保持点号定义，仅在 _castSpell 内部修复调用 | ✓ |
| 改为冒号定义 | 改为冒号定义，同时迁移所有外部调用点 (~28处) | |

**User's choice:** 保持点号定义。外部 28+ 处调用无需修改。

**Notes:** `isSpellReady` 和 `cast` 都不使用 `self`，点号定义最准确表达意图。

---

## 回归风险范围

| Option | Description | Selected |
|--------|-------------|----------|
| 自检+手动清单 (推荐) | selftest.lua 添加 ~15 个测试 + HUMAN-UAT.md 手动清单 | ✓ |
| 仅自检测试 | 仅 selftest.lua 自动化测试 | |
| 仅手动清单 | 仅 HUMAN-UAT.md 文档 | |

**User's choice:** 自检+手动清单组合，覆盖自动化回归和游戏内验证。

**Notes:** 项目已有成熟的 SelfTest 框架 (74+ 测试)，添加 Category F 测试成本极低。

---

## _hasResource 的 self 引用 + Druid 调用端修改

**User's choice:** 用户要求在所有决策点使用点号保持设计一致性。`_hasResource` 保持点号定义（闭包 self 通过 ref="player" 正确），Druid 46 个技能方法改为 `obj._castSpell(...)` 点号调用。

**Notes:** 用户解释了设计偏好——整个代码库依赖点号 + metatable __index 链实现继承，这不是不正确的做法，而是与冒号同等的可行选择。冒号只是 Lua 语法糖，不定义也不调用方法时两者没有优劣之分。

---

## Claude's Discretion

- Selftest 测试用例的具体实现细节
- HUMAN-UAT.md 的具体测试步骤和格式
- Druid.lua 中 `obj._castSpell(...)` 替换 `self:_castSpell(...)` 的执行方式

## Deferred Ideas

- 冒号语法迁移：用户明确倾向点号，不迁移
- `_hasResource` 实例 self 修正：点号方案下不需要