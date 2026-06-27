# Quick Task 260627-fix-catleveling-rip: 修复 catLeveling Rip 重复施放

**Date:** 2026-06-27
**Status:** Ready

## Root Cause

`catLeveling` 的 Rip 模块调用了 `player.rip()` 后没有设置 `macroTorch.context.lastRipAtCp`，导致 `ripLeft()` 始终用 `RIP_BASE_DURATION`（10s，1星时长）计算剩余时间，而非实际 CP 对应的时长（5星 = 18s）。

当实际 5 星 Rip 打到目标 10 秒后，`ripLeft` 返回 0，`isRipPresent` 返回 false，`shouldCastRip` 返回 true → Rip 被重复施放。

## Fix

在 `classes/druid/leveling.lua` 的 Rip 模块中，`player.rip()` 调用之后添加：

```lua
macroTorch.context.lastRipAtCp = clickContext.comboPoints
```

与 `safeRip` (cat.lua:360) 保持一致。

## Files Changed

- `classes/druid/leveling.lua` — 添加一行 context 设置