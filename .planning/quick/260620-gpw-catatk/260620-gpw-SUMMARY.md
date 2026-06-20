---
quick_task: "260620-gpw-catatk"
type: execute
status: complete
date: "2026-06-20"
tasks: 1
commits: ["7f03c82"]
files_modified: ["classes/druid/cat.lua"]
---

# Quick Task 260620-gpw: burstMod/atkPowerBurst Existence Guards

为 `burstMod` 和 `atkPowerBurst` 中的饰品/技能调用增加存在性守卫，使低等级角色在缺少对应物品或技能时跳过相关逻辑块，避免无效调用。

## Changes

### Modification 1 -- burstMod: Berserk skill guard (line 17)

在 `burstMod` 的 berserk 块中，`if not flags.berserk then` 内、`clickContext.berserk` 检查之前，添加了 `macroTorch.isSpellExist('Berserk', 'spell')` 守卫。当低等级角色（未学习 Berserk 天赋，需要 40 级才开放）按 Shift 键触发爆发时，跳过对该不存在技能的 `isSpellReady` 检查，并避免 `flags.berserk` 被设置为 `true`，确保爆发序列干净地跳过 berserk 步骤。

守卫模式参照了 otMod（Cower，line 64）和 termMod（Ferocious Bite，line 97）的现有 `isSpellExist` 守卫写法。

### Modification 2 -- atkPowerBurst: Trinket2 slot guard (line 378)

将 `atkPowerBurst` 中 trinket2 的条件从：
```lua
if player.isTrinket2CooledDown() then
```
改为：
```lua
if player.isTrinket2CooledDown() and GetInventoryItemLink("player", 14) then
```

原因：WoW 1.12.1 中 `GetInventoryItemCooldown("player", 14)` 在饰品槽位为空时返回 `(0, 0, 0)`，导致 `isTrinket2CooledDown()` 对空槽返回 `true`。`GetInventoryItemLink("player", 14)` 在槽位为空时返回 `nil`，可正确判断是否装备了饰品。

## Verification

- `grep -n 'isSpellExist.*Berserk' classes/druid/cat.lua` → Line 17: `if not macroTorch.isSpellExist('Berserk', 'spell') then return end`
- `grep -n 'GetInventoryItemLink.*14' classes/druid/cat.lua` → Line 378: `if player.isTrinket2CooledDown() and GetInventoryItemLink("player", 14) then`

## Not Modified

以下物品/技能不需要修改，因其已有守卫或内部安全检查：
- **Juju Flurry**（burstMod）：已有 `player.hasItem('Juju Flurry')` 守卫
- **Juju Power**（atkPowerBurst）：已有 `player.hasItem('Juju Power')` 守卫
- **Mighty Rage Potion**（atkPowerBurst）：已有 `player.hasItem('Mighty Rage Potion')` 守卫
- **Invulnerability Potion**（otMod）：`player.use()` 内部已通过 `getItemBagIdAndSlot` 做存在性检查

## Deviations from Plan

None -- plan executed exactly as written.