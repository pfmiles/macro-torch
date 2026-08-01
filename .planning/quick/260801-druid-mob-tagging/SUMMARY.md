---
title: "druidMobTagging — 德鲁伊抢怪一键宏"
status: complete
created: 2026-08-01
completed: 2026-08-01
---

## 摘要

在 `classes/druid/combo.lua` 中新增 `macroTorch.druidMobTagging(rough)` 函数（第 346-401 行），实现德鲁伊抢怪一键宏。

## 实现要点

- **人形态**：Moonfire 瞬发直伤 tag → druidAtk
- **猫形态 ≤5yd**：潜行+身后走起手模块；否则 claw 直伤 tag
- **熊形态 ≤5yd**：auto-atk + Maul tag
- **5-30yd 引怪区**：熊优先 druidCharge 冲锋贴脸；通用 FF(Feral) 兜底
- **目标过滤**：排除 PvP 玩家，避免误伤
- **零影响**：纯新增函数，不修改任何已有逻辑
- **自测注册**：新增 selftest 条目

## 提交

`feat(druid): add druidMobTagging mob-tagging macro` (832065c)