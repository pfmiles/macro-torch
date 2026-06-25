---
status: complete
quick_id: 260625-wzn
slug: catleveling-opener-fallback
completed_at: 2026-06-25T15:46:00Z
---

# catLeveling 起手技 fallback 改进

## 改动

在 `classes/druid/leveling.lua` 的起手模块（模块1）中增加了 fallback 逻辑：

```lua
else
    -- 既没学 Pounce 也没学 Ravage：用普通技能打破潜行起手
    if macroTorch.isSpellExist('Shred', 'spell') and clickContext.isBehind then
        player.shred('ready')
        return
    elseif macroTorch.isSpellExist('Claw', 'spell') then
        player.claw('ready')
        return
    end
end
```

## 效果

| 条件 | 行为 |
|------|------|
| Pounce 可用 + 满足条件 | Pounce 起手（不变） |
| Pounce 不可用/不满足 + Ravage 可用 | Ravage 起手（不变） |
| 两者都不可用 + 背后 + Shred 已学 | Shred('ready') 打破潜行 |
| 两者都不可用 + 正面/无 Shred + Claw 已学 | Claw('ready') 打破潜行 |

Commit: `0e19f75`