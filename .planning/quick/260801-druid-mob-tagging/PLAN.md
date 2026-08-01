---
title: "druidMobTagging — 德鲁伊抢怪一键宏"
status: planned
created: 2026-08-01
---

## 背景

现有 druidAtk 关注 DPS 最大化，缺少抢怪（mob tagging）逻辑。需要在怪物刷新第一时间尽可能抢先造成伤害以夺取拾取权。

## 实现方案

在 `classes/druid/combo.lua` 新增 `macroTorch.druidMobTagging(rough)` 函数，放在 `druidCharge()` 之后、selftest 之前。

### 决策树

```
druidMobTagging(rough):
  if not cat and not bear:          -- 人形态
    Moonfire('ready') → druidAtk(rough)

  if not target.isCanAttack or target.distance > 30 or target.isPlayerControlled:
    targetEnemy()
    if target.isPlayerControlled → ClearTarget()   -- 排除 PvP 玩家
    return

  if target.distance <= 5:          -- 近战 tag
    if cat + prowling + behind → druidAtk(rough)
    elif cat → startAutoAtk() + claw('ready') → druidAtk(rough)
    else(bear) → startAutoAtk() + maul('ready') → druidAtk(rough)

  else:                              -- 5yd < dist <= 30yd 引怪
    if bear → druidCharge()
    faerie_fire_feral('ready')
    → druidAtk(rough)
```

## 影响范围

- 纯新增功能，不修改任何已有函数
- 不修改全局状态
- 不影响现有宏逻辑