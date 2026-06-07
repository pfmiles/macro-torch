---
phase: 01-classmetatable-entity
plan: 02
subsystem: entity-init
tags: [polymorphic-init, druid-registry, event-handling]
requires: [01-01]
provides: [initPlayer-integration]
affects: [battle_event_queue.lua, SM_Extend_Druid.lua]
tech-stack:
  added: []
  patterns: [polymorphic-factory, class-registry]
key-files:
  created: []
  modified:
    - battle_event_queue.lua
    - SM_Extend_Druid.lua
decisions:
  - "Druid 多态 hack 已删除，替换为 initPlayer() 工厂调用"
  - "Druid 类名注册为 'DRUID'，匹配 UnitClass('player') 返回值"
metrics:
  duration: "~2 min"
  completed-date: "2026-06-08"
  task-count: 2
  file-count: 2
---

# Phase 01 Plan 02: 删除 Druid 多态 hack + 接入 initPlayer 注册表

删除 battle_event_queue.lua 中 Druid 运行时实例替换 hack，改用 macroTorch.initPlayer() 多态工厂；同时在 SM_Extend_Druid.lua 中注册 Druid 到 PLAYER_CLASS_REGISTRY。

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | 删除 battle_event_queue.lua 中的 Druid 多态 hack，接入 initPlayer | 77dab07 | battle_event_queue.lua |
| 2 | SM_Extend_Druid.lua 中注册 Druid 到 initPlayer 注册表 | 22497a9 | SM_Extend_Druid.lua |

## Deviations from Plan

None - plan executed exactly as written.

## Key Changes

1. **battle_event_queue.lua:74-76** — PLAYER_ENTERING_WORLD 处理器中删除了 3 行 Druid 运行时替换代码，替换为单行 `macroTorch.player = macroTorch.initPlayer()` 调用。`macroTorch.loginContext = {}` 保留其后。

2. **SM_Extend_Druid.lua:272** — 在 `macroTorch.druid = macroTorch.Druid:new()` 之后新增 `macroTorch.registerPlayerClass("DRUID", macroTorch.Druid)`。类名 "DRUID" 匹配 WoW API `UnitClass('player')` 的返回值。

## Self-Check: PASSED

All 6 checks passed:
- Druid hack (`macroTorch.player = macroTorch.druid`) no longer exists in battle_event_queue.lua
- `macroTorch.initPlayer()` call present in PLAYER_ENTERING_WORLD branch
- `initPlayer()` call precedes `loginContext` initialization
- `macroTorch.registerPlayerClass("DRUID", macroTorch.Druid)` present in SM_Extend_Druid.lua
- Registration call follows Druid singleton initialization
- Both commits (77dab07, 22497a9) confirmed in git history