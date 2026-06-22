---
phase: 16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra
reviewed: 2026-06-23T12:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/leveling.lua
  - core/selftest.lua
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-06-23T12:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed `classes/druid/leveling.lua` (catLeveling 练级版一键宏实现，211 行) and `core/selftest.lua` (全新 Category J 自测注册，~40 行).

**1 个阻断级问题** — `player.tigers_fury('ready')` 调用了不存在的方法名（正确名称为 `tiger_fury`），会在运行时抛出 Lua 错误 `attempt to call nil value`，导致猛虎之怒模块完全失效。

**2 个警告级问题** — 自测注册中关键验证项使用了 `isOptional=true`，以及 `isBehind` 字段的防御性不足。

**3 个信息级建议** — 间接 idol 检查、自测分类不一致、共享函数 `rough` 字段访问说明。

## Critical Issues

### CR-01: `tigers_fury` 方法名拼写错误，导致运行时 Lua 错误

**File:** `classes/druid/leveling.lua:110`
**Issue:** `player.tigers_fury('ready')` 调用了不存在的方法。Druid.lua 中定义的方法名为 `tiger_fury('ready')`（单数形式），对应 WoW 法术 "Tiger's Fury"。`tigers_fury` 在 metatable 链中不存在，Lua 会尝试调用 `nil` 值，抛出 `attempt to call nil value` 错误。

**证据:**
- Druid.lua line 153: `function obj.tiger_fury(mode, rank)` — 正确的单数方法名
- cat.lua line 378: `macroTorch.player.tiger_fury('ready')` — catAtk 中使用正确拼写
- leveling.lua line 110: `player.tigers_fury('ready')` — 错误的复数拼写

**Fix:**
```lua
-- line 110 — 将 tigers_fury 改为 tiger_fury
player.tiger_fury('ready')
```

## Warnings

### WR-01: 自测 J3 (catLeveling invocation) 标记为 optional，无法作为回归保护

**File:** `core/selftest.lua:593-597`
**Issue:** `"J: catLeveling invocation does not error"` 测试被标记为 `isOptional=true`。这意味着如果 catLeveling 因任何原因（如方法名拼写错误 CR-01）抛出运行时异常，自测只会输出黄色警告而非红色错误。考虑到 catLeveling 是用户直接调用的核心战斗函数，其无错误性应作为强制性约束。`isOptional` 的本意是用于外部模块依赖（如 SuperWoW、UnitXP），而非核心功能验证。

**Fix:**
```lua
-- line 597 — 将 isOptional 改为 false
end, false)  -- 原为 true，改为 false 以强制捕获回归
```

### WR-02: `isBehind` 字段直接使用 `player.isBehindTarget` 返回值，类型可能非布尔

**File:** `classes/druid/leveling.lua:57`
**Issue:** `clickContext.isBehind = target.isCanAttack and player.isBehindTarget` — 当 `target.isCanAttack` 为 nil 或非布尔值（实际为伪布尔 1/0，WoW 1.12.1 API 惯例），且 `player.isBehindTarget` 可能返回 nil 时，`isBehind` 可能为 nil 而非明确的 `false`。对比 catAtk 的实现（combo.lua line 77），两者的写法一致，但 `isBehind` 在后续条件判断中作为布尔使用（line 184, 200），nil 在 Lua 条件下表现为 falsy 是正确的，但在 `shouldUseShred` 等共享函数中如果被意外使用，nil 和 false 的语义差异可能引发问题。

**Fix:**
```lua
-- line 57 — 增加显式布尔转换
clickContext.isBehind = macroTorch.toBoolean(target.isCanAttack and player.isBehindTarget)
```

## Info

### IN-01: `computeRake_E` 和 `computeClaw_E` 内部检查 Idol of Ferocity，间接引入了 idol 逻辑

**File:** `classes/druid/leveling.lua:40-41`
**Issue:** `catLeveling` 调用 `macroTorch.computeRake_E()` 和 `macroTorch.computeClaw_E()` 来计算技能能量消耗。这两个函数内部检查 `player.isItemEquipped('Idol of Ferocity')` 以决定是否减少 3 能量。虽然这不符合设计原则 "不调用 idol/relic 函数"，但实际的 idol 检查是工具函数内的透明实现细节，且练兵期间（<55 级）不存在神像装备，对行为无实际影响。这更像是设计约束的边界情况而非真正的违规。

**Fix:** 无需改动。如果未来需要严格隔离，可让 `computeClaw_E/computeRake_E` 接受一个可选参数 skipIdolCheck 来跳过神像检查。当前设计已足够。

### IN-02: 自测 J1 (catLeveling function exists) 标记为 optional，与其他类别不一致

**File:** `core/selftest.lua:577-581`
**Issue:** `"J: catLeveling function exists and is callable"` 被标记为 `isOptional=true`。同类的 J2 "shared decision functions remain accessible" 和 J4 "catAtk remains unmodified" 都是 `isOptional=false`。函数存在性验证是核心测试，不是可选测试。此标记可能使非 Druid 类别的玩家跳过测试（已有 `UnitClass` guard）或在 Druid 玩家关键验证被降级为警告。

**Fix:**
```lua
-- line 581 — 将 isOptional 改为 false
end, false)
```

### IN-03: catLeveling 的 `clickContext.rough` 字段不存在，依赖 Lua nil 的 falsy 行为

**File:** `classes/druid/leveling.lua:36` (及 `classes/druid/Druid.lua:902,924`)
**Issue:** `catLeveling` 的 `clickContext` 未设置 `rough` 字段。当该字段被 `shouldCastRip(clickContext)` (Druid.lua:902) 和 `shouldUseBite(clickContext)` (Druid.lua:924) 访问时，其值为 `nil`。Lua 中 `nil or false` 等逻辑表达式正确处理了此情况（nil 为 falsy），因此行为正确。但这一隐式约定缺乏文档说明，可能导致未来维护者误以为 rough 字段应该被设置。建议在 leveling.lua 注释中显式标注 "rough 字段不设置，依靠 nil 的 falsy 语义"。

**Fix:** 添加代码注释说明：
```lua
-- leveling.lua line 36 后添加
-- 注意: clickContext.rough 未设置，应为 nil。
-- shouldCastRip/shouldUseBite 中通过 or 短路正确处理 nil (falsy)。
```

---

_Reviewed: 2026-06-23T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_