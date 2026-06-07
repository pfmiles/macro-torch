---
phase: 01-classmetatable-entity
plan: 04
subsystem: entity
tags: [classMetatable, migration, metatable, entity]
depends_on: [01-01]
requires: [macroTorch.classMetatable, core/class.lua]
provides: [entity/Unit.lua, entity/Player.lua, entity/Target.lua]
affects: [entity/, Unit.lua, Player.lua, Target.lua]
tech-stack:
  added: []
  patterns: [classMetatable factory]
key-files:
  created: [entity/Unit.lua, entity/Player.lua, entity/Target.lua]
  modified: []
  deleted: [Unit.lua, Player.lua, Target.lua]
decisions:
  - "classMetatable 一行替换消除了 3 个文件中的 9 行重复 setmetatable 模板"
  - "Target.lua 中 self.__index = self 已删除，classMetatable 自动处理类方法回退"
  - "Player.lua 中 impl hint 注释已删除，classMetatable 已实现其目的"
metrics:
  duration: 673s
  completed_date: 2026-06-07T18:04:24Z
  tasks: 3
  files: 6
---

# Phase 1 Plan 4: entity 核心类迁移 + classMetatable 替换 Summary

**One-liner:** Unit/Player/Target 三个核心类移至 entity/ 目录，手写 setmetatable 模板统一替换为 classMetatable 一行调用。

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | 迁移 Unit.lua -> entity/Unit.lua，替换 metatable | `7b80ca1` | `entity/Unit.lua` (created), `Unit.lua` (deleted) |
| 2 | 迁移 Player.lua -> entity/Player.lua，替换 metatable | `a99c6bf` | `entity/Player.lua` (created), `Player.lua` (deleted) |
| 3 | 迁移 Target.lua -> entity/Target.lua，替换 metatable | `9bb7a15` | `entity/Target.lua` (created), `Target.lua` (deleted) |

## Verification Results

- 三个 entity/ 文件均存在: PASS
- 根目录原文件均已删除: PASS
- 所有文件使用 `macroTorch.classMetatable`: PASS (each file has exactly 1 call)
- 手写 `setmetatable(obj, {` 模板已消除: PASS (zero matches across all files)
- `self.__index = self` 已从 Target.lua 删除: PASS
- `macroTorch.player = macroTorch.Player:new()` 默认初始化保留: PASS

## Deviations from Plan

None -- plan executed exactly as written. All three tasks followed the prescribed migration pattern:
1. Copy full file content to entity/
2. Replace hand-written setmetatable block with single `macroTorch.classMetatable(self, "FIELD_MAP_NAME")` call
3. Remove any now-redundant lines (impl hints in Player.lua, `self.__index = self` in Target.lua)
4. Delete root original file

## File Size Comparison

| File | Original (root) | New (entity/) | Delta | Reason |
|------|----------------|---------------|-------|--------|
| Unit.lua | 252 lines | 237 lines | -15 | 14-line metatable template -> 1 line |
| Player.lua | 692 lines | 673 lines | -19 | 14-line template -> 1 line + 3 impl hints removed |
| Target.lua | 276 lines | 262 lines | -14 | 11-line template -> 1 line + `self.__index = self` removed |

## Key Decisions

1. **classMetatable factory approach** (per D-01): All metatable construction uses `macroTorch.classMetatable(self, "FIELD_MAP_NAME")` -- the factory handles `__index` lookup logic (field map search followed by class method fallback), eliminating the need for per-file hand-written templates.

2. **`self.__index = self` removal** (Target.lua): The legacy pattern was rendered obsolete by classMetatable's built-in `cls[k]` fallback. `self.__index = self` was a Luau idiom that set up prototype chain lookup -- classMetatable handles this transparently.

3. **Impl hint removal** (Player.lua lines 465-467): The comments describing `self.__index = self` and `setmetatable(obj, self)` were implementation notes for a planned metatable pattern that classMetatable now fulfills.

## Known Stubs

None introduced. The single pre-existing TODO in Unit.lua line 235 (`TODO Update the texture path if different in your game client`) predates this plan and is unrelated to the metatable migration.

## Threat Flags

None. This plan performed pure file organization + semantically equivalent metatable pattern replacement. No new endpoints, auth paths, file access patterns, or schema changes at trust boundaries were introduced.

## Self-Check: PASSED

- entity/Unit.lua exists: YES
- entity/Player.lua exists: YES
- entity/Target.lua exists: YES
- Commit 7b80ca1 exists: YES
- Commit a99c6bf exists: YES
- Commit 9bb7a15 exists: YES