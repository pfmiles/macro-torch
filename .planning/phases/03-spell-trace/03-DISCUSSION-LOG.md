# Phase 3: 自检系统 + Spell Trace 配置化 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-08
**Phase:** 03-自检系统 + Spell Trace 配置化
**Areas discussed:** SelfTest 触发时机, SpellTrace:register API 形态, 自检失败后的系统行为, Druid 自检覆盖边界

---

## SelfTest 触发时机

| Option | Description | Selected |
|--------|-------------|----------|
| A: 每次 PLAYER_ENTERING_WORLD | 最简单，每次跨区域都触发 | |
| B: 仅首次触发 | session flag，reload 后重新触发 | |
| C: 首次触发 + `/macro-torch selftest` | 日常安静 + 手动调试命令 | ✓ |

**User's choice:** 采纳 C，斜杠命令简写为 `/mt`
**Notes:** `/mt` 是中远期 mt-script 自定义 DSL 的执行入口，Phase 3 先实现无参数时运行自检

---

## SpellTrace:register API 形态

| Option | Description | Selected |
|--------|-------------|----------|
| A: 方法风格 SpellTrace:register() | 命名空间隔离，可生长 | |
| C: 便捷封装 + 保留底层 API | 迁移安全，双 API 并存 | |
| D: 完全替代旧 API | 最干净，无冗余 | ✓ |

**User's choice:** 采纳 D，完全替代 + 方法风格 `macroTorch.SpellTrace:register(name, config)`
**Notes:** 不考虑对其他模块（Hunter 等）的影响，追求长远最可维护方案。底层 setSpellTracing/setTraceSpellImmune 改为内部实现细节

---

## 自检失败后的系统行为

| Option | Description | Selected |
|--------|-------------|----------|
| A: 纯报告模式 | 仅聊天框输出，不改变运行时 | ✓ |
| B: 分级降级 | 核心失败设 degradedMode | |
| D: 自适应 + 分级降级 | 延迟输出 + 降级 | |

**User's choice:** A — 纯报告模式
**Notes:** 不引入降级机制，自检只做诊断报告不干预运行时行为

---

## Druid 自检覆盖边界

| Option | Description | Selected |
|--------|-------------|----------|
| A: 最小覆盖 10 项 | 仅技能存在性 | |
| B+: 技能 + Talent + 能量常量 | ~18 核心 + ~7 optional | ✓ |

**User's choice:** B+ — 基础设施优先，职业层在此基础上做深
**Notes:** 自检定位是基础设施健康检查（模块、API、实体基类），职业特定检测是第二层附加项。Player 是唯一可做只读调用验证的实体

---

## Claude's Discretion

- SelfTest:run() 内部 pcall 实现细节
- SpellTrace:register() 内部调用逻辑
- `/mt` 命令处理函数的实现
- selftest.lua 中测试代码组织
- build_order.txt 中 core/selftest.lua 的插入位置

## Deferred Ideas

- **mt-script DSL**: `/mt <script>` 执行自定义 DSL — 未来 Phase
- **降级模式**: 自检失败后的运行时保护 — 当前纯报告，未来可单独实现