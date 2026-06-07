---
phase: 01-classmetatable-entity
plan: 01
title: "classMetatable factory + initPlayer polymorphic factory"
one-liner: "Unified metatable factory eliminates 5-class metatable duplication; polymorphic initPlayer with lazy registry replaces runtime class-swap hack"
golden-standard: "smoke test: classMetatable 工厂返回的 metatable 语义精确等价于手写9行模板"
subsystem: infrastructure
tags: [classMetatable, initPlayer, factory, metatable, registry, infrastructure]
requires: []
provides: [macroTorch.classMetatable, macroTorch.initPlayer, macroTorch.registerPlayerClass, macroTorch.PLAYER_CLASS_REGISTRY]
affects: [core/class.lua]
tech-stack:
  added: []
  patterns: [factory, registry, nil-guard, lazy-init]
key-files:
  created:
    - path: core/class.lua
      role: "Unified metatable factory + polymorphic player initialization"
      exports: [macroTorch.classMetatable, macroTorch.initPlayer, macroTorch.registerPlayerClass, macroTorch.PLAYER_CLASS_REGISTRY]
      min_lines: 40
      actual_lines: 58
  modified: []
decisions:
  - "D-01: 最简工厂方案，1:1 映射手写9行模板为1行 classMetatable 调用"
  - "D-03: fieldMapName 接受字符串，通过 macroTorch[fieldMapName] 动态查找"
  - "D-04: 惰性注册表模式，PLAYER_CLASS_REGISTRY 空表 + registerPlayerClass 注册函数"
  - "D-06: initPlayer 查 UnitClass('player') → 注册表 → Player:new() fallback"
  - "D-08: initPlayer 不赋值 macroTorch.player，赋值保持在调用点"
  - "D-12/D-13: classMetatable 支持 cls=nil，nil-guard 跳过 class method fallback"
duration:
  plan: "01-01"
  start: "2026-06-07T17:17:15Z"
  end: "2026-06-07T17:18:07Z"
  duration_seconds: 52
  tasks: 2
  files_changed: 1
  lines_added: 58
---

# Phase 1 Plan 1: classMetatable Factory + initPlayer Factory Summary

## Summary

Created `core/class.lua` with two core infrastructure components:

1. **`macroTorch.classMetatable(cls, fieldMapName)`** -- a unified metatable factory that replaces the 9-line hand-written `setmetatable` + `__index` template repeated across 5 classes (Unit, Player, Target, Pet, TargetTarget). The factory preserves exact semantic equivalence: FIELD_FUNC_MAP lookup first, then class method/field fallback through the recursive `__index` chain. Supports `cls=nil` for parentless classes like LRUStack.

2. **`macroTorch.initPlayer()` + `macroTorch.registerPlayerClass()` + `PLAYER_CLASS_REGISTRY`** -- a polymorphic initialization system using lazy registration. `registerPlayerClass(className, classTable)` stores class prototypes in the registry, and `initPlayer()` looks up the current class via `UnitClass('player')`, instantiating the correct type or falling back to `macroTorch.Player:new()`. Per D-08, `initPlayer()` does NOT assign to `macroTorch.player` -- assignment stays at each call site.

The implementation follows all 15 locked design decisions from CONTEXT.md (D-01 through D-15).

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create core/class.lua with classMetatable factory | `f358f0a` | `core/class.lua` |
| 2 | Implement initPlayer + registerPlayerClass + PLAYER_CLASS_REGISTRY | `fb3e78e` | `core/class.lua` |

## Verification Results

All acceptance criteria met:

```
function macroTorch.classMetatable  -- exists (line 21)
function macroTorch.initPlayer      -- exists
function macroTorch.registerPlayerClass -- exists
PLAYER_CLASS_REGISTRY              -- initialized as empty table
initPlayer uses UnitClass('player') -- confirmed
initPlayer falls back to Player:new() -- confirmed
classMetatable has nil-guard (if cls then) -- confirmed (line 29)
Apache 2.0 license header          -- present (lines 1-15)
file line count: 58               -- exceeds min_lines: 40
```

## Deviations from Plan

None -- plan executed exactly as written. Both tasks implemented precisely according to CONTEXT.md design decisions and REFACTOR_PLAN.md reference code.

## Key Design Decisions Applied

- **D-01**: Simplest factory, 1:1 mapping -- no builder pattern, no `parent` parameter
- **D-03**: `fieldMapName` is a string, dynamically looked up via `macroTorch[fieldMapName]`
- **D-04/D-05**: Lazy registry pattern -- `PLAYER_CLASS_REGISTRY = {}` + `registerPlayerClass()` for self-registration
- **D-06/D-08**: `initPlayer()` factory returns instance but does NOT assign to `macroTorch.player`
- **D-12/D-13**: `classMetatable(nil, ...)` supported, nil-guard skips class method fallback

## Threat Flags

None -- this plan introduces only pure Lua factory functions and a registry data structure. No I/O, no user input, no external dependencies, no new trust boundaries.

## Known Stubs

None -- all functions are fully implemented with no placeholder code.