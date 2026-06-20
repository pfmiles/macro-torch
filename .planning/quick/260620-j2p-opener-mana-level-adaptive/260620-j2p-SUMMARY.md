---
phase: quick
plan: 260620-j2p
subsystem: Druid-level-adaptive
tags: [level-adaptive, opener, mana-potion, catAtk, low-level]
requires: [15-catatk-combo-refactor]
provides: [level-adaptive opener threshold, level-adaptive mana potion threshold]
affects: [catAtk opener module, catAtk health-mana-saver module]
tech-stack:
  added: []
  patterns: [level-adaptive lookup table, percentage-based threshold]
key-files:
  created: []
  modified:
    - classes/druid/Druid.lua
    - classes/druid/combo.lua
decisions:
  - "使用 lookup table 模式适配 opener 血量阈值，与现有 estimatePlayerDPS/getKSThreshold 风格一致"
  - "法力药水改用 UnitMaxMana * 0.3 百分比阈值，解决低等级法力池绝对数值不适用的问题"
  - "猫形态下 UnitMana 返回能量的问题通过药水 CD（2分钟）自然限制，无需额外法力追踪基础设施"
metrics:
  duration: 149s
  completed_date: 2026-06-20
  task_count: 2
  file_count: 2
status: complete
---

# Quick Task 260620-j2p: Opener & Mana Potion Level-Adaptive Fix Summary

**One-liner:** 将 catAtk 中 opener 血量阈值和法力药水阈值从60级硬编码改为 level-adaptive 逻辑，确保低等级练级阶段正确运作。

## Tasks Executed

### Task 1: Opener Health Threshold -> Level-Adaptive Lookup

- **Commit:** `4051a5a`
- **Files:** `classes/druid/Druid.lua`, `classes/druid/combo.lua`

在 `Druid.lua` 中新增 `macroTorch.getOpenerHealthThreshold(level)` 函数，参照 `estimatePlayerDPS` 和 `getKSThreshold` 的 lookup table 模式：
- 60级: 1500（向后兼容）
- 50-59: 1000
- 40-49: 600
- 30-39: 300
- <30: 150

在 `combo.lua:114` 将硬编码 `target.health >= 1500` 替换为 `target.health >= macroTorch.getOpenerHealthThreshold()`。

### Task 2: Mana Potion Threshold -> Percentage-Based

- **Commit:** `af283bd`
- **Files:** `classes/druid/Druid.lua`, `classes/druid/combo.lua`

在 `Druid.lua` 中新增两个函数：
- `macroTorch.getManaPotionThreshold()` — 返回 `UnitMaxMana('player') * 0.3`
- `macroTorch.shouldUseManaPotion()` — 封装当前法力与阈值比较逻辑

在 `combo.lua:95` 将硬编码 `player.humanFormMana < 350` 替换为 `macroTorch.shouldUseManaPotion()`。

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `classes/druid/Druid.lua` — FOUND (modified)
- `classes/druid/combo.lua` — FOUND (modified)
- Build output `SM_Extend.lua` — contains all 3 new functions (6 occurrences)
- Commit `4051a5a` — FOUND
- Commit `af283bd` — FOUND