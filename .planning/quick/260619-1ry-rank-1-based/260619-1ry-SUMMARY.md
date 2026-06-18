---
quick_id: 260619-1ry
slug: rank-1-based
description: 技能释放默认最高等级 + 可选rank参数
date: 2026-06-18
status: complete
---

# Quick Task 260619-1ry Summary

## Goal

修改法术释放系统：默认释放最高等级技能，支持可选的 rank 参数指定等级。

## Changes

### Root Cause
`getSpellIdByName` 从 index=1 遍历法术书返回第一个匹配（最低等级），导致所有目标型技能释放最低等级。

### Fix (4 commits)

1. **biz_util.lua**: 新增 `getSpellIdByNameRank(spellName, bookType, rank)` 函数
   - 收集所有同名法术 ID 到数组，rank=nil 或超范围返回最后一个（最高等级）
   - 修改 `castSpellByName` 增加 rank 参数，内部调用新函数

2. **entity/Player.lua**: `_castSpell` 和 `cast` 方法增加 rank 参数
   - 非 self-cast 路径：`obj.cast(spellName, rank)`
   - self-cast 路径：指定 rank 时使用 `CastSpellByName("Name(Rank N)", true)` 格式
   - rank=nil 自施法保持原有 `CastSpellByName(spellName, true)`（默认最高等级）

3. **7 个 class 文件** (Druid, Mage, Hunter, Priest, Rogue, Warlock, Warrior):
   - 所有技能方法签名增加可选 `rank` 参数
   - 88 个方法全部更新

### API

```lua
-- 默认最高等级（向后兼容）
player.wrath('ready')

-- 指定等级（1-based）
player.wrath('ready', 3)   -- Rank 3
player.heal(nil, true, 4)  -- self-cast Heal Rank 4

-- rank 超出范围 → 自动使用最高等级
player.wrath(nil, 99)
```

### Correctness Note

Executor's first attempt (reverted in 1f27aa2) inserted an extra `nil` argument, shifting resourceCost/onSelf/rank positions. Fixed in the re-do (33a9a92) — each `_castSpell` call appends `, rank` as the last argument without any position shift.