---
quick_id: 260627-fix-catleveling-rip
description: 修复 catLeveling Rip 重复施放 — lastRipAtCp 未设置导致计时偏短
status: complete
---

## Summary

修复 `catLeveling` 中 Rip 模块缺少 `macroTorch.context.lastRipAtCp` 设置的问题。

### Root Cause

`catLeveling` 调用 `player.rip()` 后未设置 `context.lastRipAtCp`，导致 `ripLeft()` 始终用 `RIP_BASE_DURATION`（10s，1星）计算剩余时间。5 星 Rip（18s）在施放 10s 后，`ripLeft` 返回 0 → `isRipPresent` 返回 false → `shouldCastRip` 返回 true → Rip 被重复施放。

### Fix

`classes/druid/leveling.lua` — Rip 模块添加 `macroTorch.context.lastRipAtCp = clickContext.comboPoints`

与 `safeRip` (cat.lua:360) 保持一致。

### Commit

`daa632b` — fix(druid): set lastRipAtCp in catLeveling Rip module to prevent premature re-cast