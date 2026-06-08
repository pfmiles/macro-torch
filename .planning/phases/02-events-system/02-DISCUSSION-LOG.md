# Phase 2: 事件系统模块化拆分 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-08
**Phase:** 02-事件系统模块化拆分
**Areas discussed:** 事件注册架构, spell_trace 拆分粒度, 模块间依赖方向, battle_event_queue 清理策略

---

## 事件注册架构

| Option | Description | Selected |
|--------|-------------|----------|
| 集中式 | events.lua 一个 Frame 注册全部 14 个事件，eventHandle 内部 dispatch 到 combat_context/spell_trace 函数 | ✓ |
| 分布式 | combat_context.lua 和 spell_trace.lua 各自 CreateFrame 注册自己关心的事件 | |
| 混合式 | events.lua 暴露 registerHandler API，各模块通过回调注册表订阅事件 | |

**User's choice:** 集中式（推荐）
**Notes:** 与现有架构差异最小，dispatch 逻辑仅 2-3 个消费模块。periodic.lua 独立 Frame 的原因是 OnUpdate 与事件系统职责隔离，不构成先例。

---

## spell_trace 拆分粒度

| Option | Description | Selected |
|--------|-------------|----------|
| 单文件 (~350行) | 所有 spell trace 功能放一个文件，违反 250 行验收标准 | |
| 双文件 | spell_trace_core.lua (表管理) + spell_trace_immune.lua (免疫判定) | ✓ |
| 三文件 | table/immune/combat 三文件，最细粒度但碎片化 | |

**User's choice:** 双文件（推荐）
**Notes:** 拆分边界对应功能正交：core 管数据面（表写入/查询/推算），immune 管控制面（免疫判定 + 持久化）。需确保引用顺序：spell_trace_core.lua 在 spell_trace_immune.lua 之前。

---

## 模块间依赖方向

| Option | Description | Selected |
|--------|-------------|----------|
| 直接调用 + 调整顺序 | combat_context/spell_trace 放 events 之前，events 直接调用 | ✓ |
| Stub 灌入模式 | events 定义空 stub，后面文件灌入实现 | |
| 回调注册 | events 暴露回调注册表，模块自注册 | |

**User's choice:** 直接调用 + 调整顺序（推荐）
**Notes:** 与现有 macroTorch 全局函数调用模式完全一致，零新机制。combat_context/spell_trace 是纯函数定义不含 Frame，不需要在 events Frame 之后定义。

---

## battle_event_queue 清理策略

| Option | Description | Selected |
|--------|-------------|----------|
| 完全删除 | 删除文件 + 从 build_order.txt 移除条目 | ✓ |
| 保留兼容 stub | 保留 ≤10 行注释 stub 作为安全网 | |

**User's choice:** 完全删除（推荐）
**Notes:** 所有函数在 macroTorch.* 全局命名空间，删文件不影响可用性。通过 grep 验证外部调用方引用完整后即可安全删除。与 Phase 4 严格模式自然兼容。

---

## Deferred Ideas

None — 讨论保持在 Phase 2 范围内。