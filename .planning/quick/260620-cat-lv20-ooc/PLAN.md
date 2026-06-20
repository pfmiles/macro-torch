---
quick_id: 260620-uun
slug: cat-lv20-ooc
date: 2026-06-20
description: cat_lv20 方法加入 Omen of Clarity (ooc) 处理：触发 ooc 时用 Claw，其余逻辑不变
---

## 任务

修改 `classes/druid/leveling.lua` 中的 `cat_lv20()` 函数，加入 ooc（清晰预兆）判定。

## 修改逻辑

当前 `cat_lv20` 决策逻辑：
1. 有 combo point 且 Rip 可用且目标无 Rip → 用 Rip
2. 否则 → 用 Claw

修改后：
1. **如果 ooc 触发 → 直接用 Claw**（ooc 使下次技能免费，Claw 是最优选择）
2. 否则保持现有逻辑不变

## 实现

在现有决策逻辑前增加 ooc 检查：

```lua
if macroTorch.player.isOoc then
    macroTorch.player.claw()
    return
end
```

## 影响范围

- 仅修改 `classes/druid/leveling.lua` 一个文件
- `cat_lv20` 被 `catLeveling()` 调用，仅影响 24 级以下猫德练级行为