---
phase: 02-events-system
plan: 02
subsystem: events
tags: [events, spell-trace, immune, refactor]
tech-stack:
  added: []
  patterns: [license-header, global-function-extract, centralized-event-dispatch]
key-files:
  created:
    - core/spell_trace_immune.lua
    - core/events.lua
  modified: []
decisions:
  - "loadImmuneTable/loadDefiniteBleedingTable 放入 spell_trace_immune.lua（per D-02 双文件拆分决策）"
  - "eventHandle 战斗进出/进入世界分支改用 combat_context.lua 直接函数调用（per D-03 直接函数调用决策）"
  - "事件帧使用 local frame 独立变量，与 periodic.lua 的 frame 不冲突（per D-14 独立 Frame）"
metrics:
  duration: ""
  completed_date: "2026-06-08"
  task_count: 2
  file_count: 2
---

# Phase 02 Plan 02: Events and Immune Tracing Extraction Summary

将 battle_event_queue.lua 中的免疫追踪和事件处理层提取为独立模块：`core/spell_trace_immune.lua` 和 `core/events.lua`。

## Tasks

| # | Name | Commit | Status |
|---|------|--------|--------|
| 1 | Create core/spell_trace_immune.lua | c363764 | done |
| 2 | Create core/events.lua | 3386e47 | done |

## Task 1: core/spell_trace_immune.lua

创建了 `core/spell_trace_immune.lua`（93 行），从 battle_event_queue.lua 精确迁移以下内容：

- `macroTorch.spellsImmuneTracing()` - 免疫追踪函数，包含 consumeFailEvent/consumeLandEvent 遍历逻辑
- `macroTorch.loadImmuneTable()` - 从 SM_EXTEND.immuneTable 加载免疫表
- `macroTorch.loadDefiniteBleedingTable()` - 从 SM_EXTEND.definiteBleedingTable 加载确定性流血表
- `macroTorch.registerPeriodicTask('spellsImmuneTracing', { interval = 0.1, task = ... })` - 周期性注册

所有函数代码保持逐字复制，未做任何逻辑修改。`entity/Target.lua` 的 5 处 `loadImmuneTable`/`loadDefiniteBleedingTable` 调用不受影响。

## Task 2: core/events.lua

创建了 `core/events.lua`（115 行），从 battle_event_queue.lua 迁移事件帧基础设施：

- 独立 `local frame = CreateFrame("Frame")`（与 periodic.lua 的 frame 无冲突）
- 14 个事件注册（含 SUPERWOW_STRING 条件注册的 UNIT_CASTEVENT）
- `macroTorch.eventHandle()` 集中式 if-elseif dispatch
- 3 个战斗状态分支改用 combat_context 函数调用：
  - `PLAYER_REGEN_ENABLED` → `macroTorch.onCombatExit()`
  - `PLAYER_REGEN_DISABLED` → `macroTorch.onCombatEnter()`
  - `PLAYER_ENTERING_WORLD` → `macroTorch.onPlayerEnteringWorld()` + Phase 3 SelfTest 预留注释
- `frame:SetScript("OnEvent", macroTorch.eventHandle)` 正确绑定

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- `core/spell_trace_immune.lua` exists (93 lines) — PASSED
- `core/events.lua` exists (115 lines) — PASSED
- Commits c363764 and 3386e47 verified — PASSED