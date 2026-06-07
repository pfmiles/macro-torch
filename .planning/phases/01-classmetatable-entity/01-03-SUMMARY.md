---
phase: 01-classmetatable-entity
plan: 03
subsystem: core/periodic
tags: [migration, cleanup, refactoring, periodic-task, onupdate-frame]
requires: [01-01]
provides: ["LRUStack + ES_FIELD_FUNC_MAP via classMetatable(nil)", "periodic task scheduling system with independent OnUpdate Frame"]
affects: [event_stack.lua (deleted), battle_event_queue.lua (slimmed)]
tech-stack:
  added: []
  patterns: [classMetatable(nil) for parentless classes, independent local Frame per module]
key-files:
  created: [core/periodic.lua]
  modified: [battle_event_queue.lua]
  deleted: [event_stack.lua]
decisions:
  - "LRUStack uses classMetatable(nil, \"ES_FIELD_FUNC_MAP\") with nil-guard for cls — per D-12/D-13"
  - "periodic.lua creates independent local Frame for OnUpdate — per D-14/D-15, no shared state with battle_event_queue.lua"
metrics:
  duration: "~2 minutes"
  completed_date: "2026-06-08T01:30:00+08:00"
  tasks: 3
  files_changed: 3
  lines_added: 135
  lines_deleted: 121
---

# Phase 01 Plan 03: 迁移 LRUStack + periodic task 调度系统到 core/periodic.lua Summary

创建独立的 periodic task 调度模块 `core/periodic.lua`，合并 event_stack.lua 的 LRUStack/ES_FIELD_FUNC_MAP 和 battle_event_queue.lua 的周期性任务系统，使用 classMetatable(nil) 统一 metatable 构造，并拥有独立 OnUpdate Frame。

## Tasks Executed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | 创建 core/periodic.lua，迁移 LRUStack + ES_FIELD_FUNC_MAP，使用 classMetatable | `2f8b1d3` | `core/periodic.lua` (created) |
| 2 | 迁移 registerPeriodicTask / removePeriodicTask / setRepeat / onPeriodicUpdate + 独立 OnUpdate Frame | `54c9ea2` | `core/periodic.lua` (modified) |
| 3 | 清理：删除 event_stack.lua，从 battle_event_queue.lua 删除已迁移代码 | `e714988` | `event_stack.lua` (deleted), `battle_event_queue.lua` (modified) |

## Commits

| Hash | Message |
|------|---------|
| `2f8b1d3` | feat(01-classmetatable-entity-03): create core/periodic.lua with LRUStack + ES_FIELD_FUNC_MAP using classMetatable(nil) |
| `54c9ea2` | feat(01-classmetatable-entity-03): migrate periodic task scheduling system + independent OnUpdate Frame to core/periodic.lua |
| `e714988` | feat(01-classmetatable-entity-03): cleanup — delete event_stack.lua, remove migrated periodic-task code from battle_event_queue.lua |

## Key Changes

### core/periodic.lua (135 lines, created)
- **LRUStack 类**: 从 event_stack.lua 完整迁入，含 push/pop/anyMatch/allMatch 四个实例方法
- **ES_FIELD_FUNC_MAP**: 从 event_stack.lua 迁入，含 size/top/isEmpty 三个动态计算字段
- **Metatable 统一**: LRUStack:new() 使用 `macroTorch.classMetatable(nil, "ES_FIELD_FUNC_MAP")` 替代原 13 行手写 setmetatable 模板。cls=nil 触发 nil-guard，跳过 class method fallback
- **Periodic task 系统**: onPeriodicUpdate/registerPeriodicTask/removePeriodicTask/setRepeat 从 battle_event_queue.lua 迁入
- **独立 OnUpdate Frame**: `local frame = CreateFrame("Frame")` 创建 periodic.lua 独享的 Frame，不与 battle_event_queue.lua 共享
- **错误处理**: pcall 包裹 onPeriodicUpdate 调用，单个 task 异常不中断调度框架

### battle_event_queue.lua (471 lines, 原 516 行)
- 删除 Lines 155-200（frame.lastUpdate/leastUpdateInterval 初始化、onPeriodicUpdate/registerPeriodicTask/removePeriodicTask/setRepeat 函数定义、OnUpdate handler）
- 保留: eventHandle() 函数（含 PLAYER_ENTERING_WORLD 的 initPlayer 调用）、OnEvent handler、maintainLandTables/spellsImmuneTracing 等后续 Phase 迁移内容
- 保留: registerPeriodicTask 调用点（maintainLandTables、spellsImmuneTracing 注册），因为被调用函数定义在 core/periodic.lua

### event_stack.lua (deleted)
- 全部内容已迁入 core/periodic.lua，源文件删除

## Deviations from Plan

None — plan executed exactly as written.

## Threat Model Compliance

| Threat ID | Status |
|-----------|--------|
| T-01-03a (DoS via OnUpdate) | MITIGATED — pcall 包裹保留在 core/periodic.lua lines 128-131，单个 task 异常不影响其他 task |
| T-01-03b (Information Disclosure) | ACCEPTED — 纯迁移操作，不引入新数据流 |

## Known Stubs

None. All migrated code is complete, functional, and was previously battle-tested in event_stack.lua and battle_event_queue.lua.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries.

## Verification

All acceptance criteria verified:

- event_stack.lua deleted
- core/periodic.lua contains all 7 required elements (LRUStack:new, registerPeriodicTask, removePeriodicTask, setRepeat, onPeriodicUpdate, CreateFrame, SetScript OnUpdate)
- LRUStack uses classMetatable(nil, "ES_FIELD_FUNC_MAP")
- battle_event_queue.lua has no stale function definitions for periodic task functions
- battle_event_queue.lua preserves eventHandle() and OnEvent SetScript
- pcall error handling preserved in core/periodic.lua
- Line count: 135 lines (>120 min_lines)