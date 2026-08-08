---
quick_id: 260808-t3w
slug: druid-cower-otmod-guard-hasnearbygroupma
description: druid cower otMod guard hasNearbyGroupMates
date: 2026-08-08
commit: 601160c
status: complete
---

## Summary

### Changes

1. **biz_util.lua** — 新增 `hasNearbyGroupMates(rangeYards)` 工具函数
   - 遍历队伍/团队成员，检查是否有人在玩家指定码数范围内
   - 使用 `isFunctionExist('UnitXP')` 守卫，模块不可用时退化为 `return true`
   - 复用现有 `filterGroupMates` 遍历逻辑
   - 距离 API：`UnitXP("distanceBetween", "player", unitId)`

2. **classes/druid/cat.lua `otMod`** — 两处修改
   - 在 `isInGroup` 守卫后添加附近队友检查：无队友在 60 码内则跳过整个 OT 模块
   - 无敌药水 `return` 修复：使用药水后立即 return，避免同 tick 继续尝试 cower

### Rationale

当队友都在另一张地图或超过 60 码时，怪物无论如何都会攻击玩家，cower 降仇恨没有意义，白白浪费 20 能量 + 1 GCD。

### Verified

- `hasNearbyGroupMates` 正确处理：solo、队友在不同地图、队友死亡、UnitXP 不可用
- `otMod` 守卫链完整：Cower 未学习 → 木桩 → 前置条件 → 附近队友 → 无敌药水 → Reshift → Cower