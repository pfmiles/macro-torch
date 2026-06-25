---
created: 2026-06-25
quick_id: 260625-wzn
slug: catleveling-opener-fallback
---

# catLeveling 起手技 fallback 改进

## 问题

当前 `catLeveling()` 的起手模块（模块1）在潜行状态下只检查 Pounce 和 Ravage：
- Pounce 可用 → 用 Pounce
- Ravage 可用 → 用 Ravage
- **两者都不可用 → 什么都不做，宏卡住**

## 方案

在起手模块末尾增加 fallback：如果 Pounce 和 Ravage 都没学，检查是否在目标背后：
- 在背后 (`isBehind`) + Shred 已学 → 用 Shred 打破潜行
- 否则 Claw 已学 → 用 Claw 打破潜行

使用 `'ready'` 模式（跳过能量检查），因为潜行起手时能量通常是满的，且我们需要强制打破潜行状态。

## 改动点

- `classes/druid/leveling.lua:79` — 在 `elseif hasRavage` 分支的 `end` 之前插入 fallback 逻辑