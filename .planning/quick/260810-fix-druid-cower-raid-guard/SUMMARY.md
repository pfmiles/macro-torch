---
slug: 260810-fix-druid-cower-raid-guard
description: fix(druid): extend otMod guard to accept raid membership
status: complete
date: 2026-08-10
---

# Summary: Fix otMod guard 支持 raid

## 问题

`otMod` L79 只检查 `isInGroup`（`GetNumPartyMembers() > 0`），在 raid 中子小队无人时返回 `false`，导致 cower 被跳过。`hasNearbyGroupMates` 和 `filterGroupMates` 已正确支持 raid，但被外层 guard 挡住。

## 修复

将 group/raid 检查从复合条件中拆出，新增独立 guard：

```lua
if not macroTorch.player.isInGroup and not macroTorch.player.isInRaid then
    return
end
```

与 `combo.lua:221` 模式一致。

## 改动

- `classes/druid/cat.lua` — otMod 函数：新增独立 guard + 删除 L79 旧条件
- Commit: `e917b88`