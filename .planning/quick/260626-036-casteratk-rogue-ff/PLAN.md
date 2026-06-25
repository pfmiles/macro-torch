---
created: 2026-06-26
quick_id: 260626-036
slug: casteratk-rogue-ff
---

# casterAtk 盗贼精灵之火优先级

## 问题

当前 `casterAtk()` 的 debuff 维护按照 Moonfire → FF → Insect Swarm 顺序，FF 优先级低于 Moonfire。对盗贼目标而言，FF 应最高优先级——防止盗贼潜行/消失。

## 方案

在 `casterAtk()` 中，`isCanAttack` guard 之后立即插入盗贼 FF 检查：
- 目标职业为 Rogue/盗贼 + 无 FF debuff → 立即 `faerie_fire()`
- 优先级高于未进战的 Wrath 起手（FF 瞬发，Wrath 读条）

## 改动点

- `classes/druid/combo.lua` — `casterAtk()` 函数，在 `isCanAttack` guard 之后插入盗贼 FF 优先逻辑