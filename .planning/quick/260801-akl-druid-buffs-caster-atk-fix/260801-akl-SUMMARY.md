---
quick_id: 260801-akl
slug: druid-buffs-caster-atk-fix
description: 修复 druidBuffs 自我施法和 casterAtk 自动攻击
date: 2026-08-01
commit: 605531b
status: complete
---

# Quick Task 260801-akl: 修复 druidBuffs 自我施法和 casterAtk 自动攻击

## 改动摘要

### Fix 1: druidBuffs 无条件自我施法 (`classes/druid/utility.lua`)

**问题：** `druidBuffs()` 中 `mark_of_the_wild('ready', true)` 和 `thorns('ready', true)` 的 `onSelf=true` 参数在 `_castSpell` → `CastSpell(spellId, 'spell')` 路径中失效——`CastSpell` 对 Type C 技能（可对任意友方释放）不会自动选择自身，而是对当前目标施法。若当前选中友方单位，buff 会错误地加到目标身上。

**修复：** 改为直接调用 `CastSpellByName('Mark of the Wild', true)` / `CastSpellByName('Thorns', true)`，利用 WoW 原生 API 的第二个参数 `true` 实现强制自我施法。同时添加 `isSpellReady` 前置检查以保留原有的就绪判断语义。`Nature's Grasp` 保持不变（Type B 纯自身技能，`CastSpell` 自动选自身）。

### Fix 2: casterAtk 添加自动攻击 (`classes/druid/combo.lua`)

**问题：** `casterAtk()` 只释放法术（Wrath/Moonfire/FF/IS/Starfire），完全没有调用 `startAutoAtk()`。法力耗尽、怪物近身时角色只能干等回蓝，无法自动近战平砍。

**修复：** 在进入战斗分支（`else` → `isInCombat == true`）开头添加 `macroTorch.startAutoAtk()` 调用，与 `catAtk`（第 127 行）保持一致的守护模式。拉怪起手阶段（`isInCombat == false`）不触发自动攻击，避免影响 Wrath 远程开怪。

## 验证

- `grep -n "CastSpellByName" classes/druid/utility.lua` — 确认 MotW 和 Thorns 使用 `CastSpellByName(name, true)` 自我施法
- `grep -n "startAutoAtk" classes/druid/combo.lua` — 确认 casterAtk 中存在 `startAutoAtk()` 调用