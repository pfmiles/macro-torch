# Quick Task: 移除 rough 参数

**Date:** 2026-08-02
**Status:** planned

## 目标

从 druid 一键宏链路中彻底移除 `rough` 参数。该参数在猫形态中与 `isTrivialBattleOrPvp()` 完全冗余（所有消费点都是 OR 关系），在熊形态中提供的是从不触发的死代码路径。用户确认从不传递 `rough=true`。

## 任务清单

### T1: 移除 rough 参数及相关逻辑

**涉及文件 (5):**
- `classes/druid/combo.lua` — 函数签名、参数传递、OR 条件简化
- `classes/druid/bear.lua` — 函数签名、死代码删除、条件简化
- `classes/druid/cat.lua` — `shouldEquipSavagery` 条件简化
- `classes/druid/Druid.lua` — 3 处 OR 条件简化 + 注释更新
- `classes/druid/selftest.lua` — 测试 fixture 中删除 `rough = false`

**改动汇总 (15 处):**

| 文件 | 行 | 改动类型 |
|------|-----|---------|
| combo.lua:49 | 注释 | 移除 rough 说明 |
| combo.lua:50 | 签名 | `catAtk(rough)` → `catAtk()` |
| combo.lua:58 | 删除 | `clickContext.rough = ...` |
| combo.lua:161 | 简化 | `rough or isTrivial...` → `isTrivial...` |
| combo.lua:183 | 签名 | `druidAtk(rough)` → `druidAtk()` |
| combo.lua:186 | 调用 | `catAtk(rough)` → `catAtk()` |
| combo.lua:191 | 调用 | `bearAtk(rough)` → `bearAtk()` |
| combo.lua:345-346 | 注释+签名 | `druidMobTagging(rough)` → `druidMobTagging()` |
| combo.lua:358/378/383/391/404 | 调用 | 5x `druidAtk(rough)` → `druidAtk()` |
| bear.lua:15-17 | 删除 | `if clickContext.rough then return end` |
| bear.lua:51-52 | 简化 | 移除 `not clickContext.rough and` |
| bear.lua:88 | 签名 | `bearAtk(rough)` → `bearAtk()` |
| bear.lua:92 | 删除 | `clickContext.rough = ...` |
| cat.lua:257 | 简化 | `not rough and not isTrivial...` → `not isTrivial...` |
| Druid.lua:310-311 | 注释 | 移除 rough 引用 |
| Druid.lua:372 | 简化 | `isTrivial... or rough` → `isTrivial...` |
| Druid.lua:928 | 简化 | 同上 |
| Druid.lua:950 | 简化 | 同上 |
| selftest.lua:262 | 删除 | `rough = false,` |
| selftest.lua:528 | 删除 | `rough = false,` |

**验证:** 确认所有 `rough` 引用已从代码库中移除（`grep -rn "rough" --include="*.lua" .` 无结果）