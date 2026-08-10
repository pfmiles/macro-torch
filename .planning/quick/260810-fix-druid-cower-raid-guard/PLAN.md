---
slug: 260810-fix-druid-cower-raid-guard
description: fix(druid): extend otMod group guard to also accept raid membership
date: 2026-08-10
---

# Fix: otMod L79 guard 支持 raid

## 问题

`classes/druid/cat.lua:79` 的 `otMod` 入口 guard 只检查 `isInGroup`：

```lua
or not macroTorch.player.isInGroup then
```

`isInGroup` = `GetNumPartyMembers() > 0`，在 raid 中子小队只有自己一人时返回 `false`，导致整个 cower 模块被跳过——即使 raid 中有其他成员在 60 码内。

`hasNearbyGroupMates(60)` 和 `filterGroupMates` 本身已正确支持 raid（遍历 raid1~raid40），但被 L79 的 guard 挡住，在 raid 中永远不会到达。

对比 `combo.lua:221` 的正确模式：
```lua
if macroTorch.player.isInGroup or macroTorch.player.isInRaid then
```

## 修复方案

采用方案 B（独立 guard，与 combo.lua 风格一致）：

1. 将 group/raid 检查从 L73-L81 的复合条件中拆出
2. 在 targetDummy guard 之后，新增独立 guard block
3. 同时删除 L79 的 `or not macroTorch.player.isInGroup then`

## 改动文件

- `classes/druid/cat.lua` — otMod 函数