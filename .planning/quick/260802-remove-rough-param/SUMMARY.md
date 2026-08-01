---
quick_id: 260802-remove-rough-param
status: complete
date: 2026-08-02
---

# Quick Task 260802-remove-rough-param: 移除 rough 参数

## 目标

从 druid 一键宏链路中彻底移除 `rough` 参数及其所有消费逻辑。

## 执行摘要

`rough` 参数在所有消费点与 `isTrivialBattleOrPvp()` 自动检测完全冗余（OR 关系），用户从不传递 `rough=true`。移除后运行时行为完全不变。

## 改动文件

| 文件 | 改动 |
|------|------|
| `classes/druid/combo.lua` | 移除 catAtk/druidAtk/druidMobTagging 函数签名中的 rough 参数；删除 clickContext.rough 赋值；简化 OR 条件 |
| `classes/druid/bear.lua` | 移除 bearAtk 函数签名中的 rough 参数；删除 clickContext.rough 赋值；移除 bearOtMod 死代码 early-return；简化 bearRegularAttack 条件 |
| `classes/druid/cat.lua` | 简化 shouldEquipSavagery 条件；更新注释 |
| `classes/druid/Druid.lua` | 简化 3 处 isTrivialBattleOrPvp or rough → isTrivialBattleOrPvp；更新注释 |
| `classes/druid/selftest.lua` | 从测试 fixture 中删除 2 处 `rough = false` |

## 验证

- `grep -rn "clickContext.rough\|\brough\b" --include="*.lua" .` 无代码引用残留
- 所有 `rough` 使用点均为 OR 关系：`rough=false` → 移除后逻辑等价
- catAtk 核心 DPS 路径不受影响（`rough or isTrivialBattleOrPvp` → `isTrivialBattleOrPvp`，语义一致）