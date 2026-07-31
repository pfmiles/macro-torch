# Quick Task 260801-akl: 修复 druidBuffs 自我施法和 casterAtk 自动攻击

**Date:** 2026-08-01
**Status:** planned

## Task 1: 修复 druidBuffs 无条件自我施法

**文件:** `classes/druid/utility.lua`
**改动:** 将 `mark_of_the_wild('ready', true)` 和 `thorns('ready', true)` 改为直接使用 `CastSpellByName(spellName, true)` 强制自我施法，因为 `_castSpell` 的 `onSelf` 参数对 Type C 技能实际不生效。

**验证:** `grep -n "CastSpellByName\|mark_of_the_wild\|thorns" classes/druid/utility.lua` 确认改动正确

## Task 2: 修复 casterAtk 缺少自动攻击

**文件:** `classes/druid/combo.lua`
**改动:** 在 `casterAtk()` 的战斗分支（`else` → `isInCombat == true`）开头添加 `macroTorch.startAutoAtk()` 调用，与 `catAtk` 保持一致的守护模式。

**验证:** `grep -n "startAutoAtk" classes/druid/combo.lua` 确认调用存在