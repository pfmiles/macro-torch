---
quick_task: "260620-gpw-catatk"
type: execute
files_modified:
  - classes/druid/cat.lua
requirements: []
---

<objective>
为 `burstMod` 和 `atkPowerBurst` 中的饰品（Berserk、Trinket2）增加物品/技能存在性守卫，使低等级角色在缺少对应物品或技能时跳过相关逻辑块，避免无效调用。
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
</execution_context>

<context>
@classes/druid/cat.lua
@entity/Player.lua
@biz_util.lua
</context>

<tasks>

<task type="auto">
  <name>Task 1: 为 burstMod 中的 Berserk 和 atkPowerBurst 中的 Trinket2 增加存在性守卫</name>
  <files>classes/druid/cat.lua</files>
  <action>
在 classes/druid/cat.lua 中修改两处，为饰品类消费品/技能使用增加物品存在性守卫：

**修改 1 — burstMod 的 berserk 块（第 15-22 行）：**

在调用 player.berserk('ready') 之前增加技能存在性检查。在 `if not flags.berserk then` 块内、`if not clickContext.berserk then` 之前，添加一行：

```
if not macroTorch.isSpellExist('Berserk', 'spell') then return end
```

参照现有的 isSpellExist 守卫模式（如 cat.lua 第 64 行 otMod 对 Cower、第 97 行 termMod 对 Ferocious Bite 的守卫写法）。

此守卫确保低等级角色（未学习 Berserk 天赋技能，需要 40 级才开放）在 shift 爆发时不会对不存在的技能做无效 isSpellReady 检查，同时避免 flags.berserk 被设置为 true 导致爆发序列跳过 berserk 后继续执行后续步骤。

**修改 2 — atkPowerBurst 的 trinket2 块（第 401-404 行）：**

在调用 player.useTrinket2() 之前增加饰品槽存在性检查。将现有的：

```
if player.isTrinket2CooledDown() then
    player.useTrinket2()
end
```

替换为：

```
if player.isTrinket2CooledDown() and GetInventoryItemLink("player", 14) then
    player.useTrinket2()
end
```

原因：WoW 1.12.1 中 GetInventoryItemCooldown("player", 14) 在槽位为空时返回 (0, 0, 0)，导致 isTrinket2CooledDown() 对空槽返回 true。GetInventoryItemLink("player", 14) 在槽位为空时返回 nil，可正确判断是否装备了饰品。

注意：atkPowerBurst 中的 Juju Power 和 Mighty Rage Potion 已有 `player.hasItem()` 守卫（对应 isItemExist），不需要额外修改。burstMod 中的 Juju Flurry 同样已有 `player.hasItem()` 守卫。otMod 中的 Invulnerability Potion 调用 `player.use()` 内部已通过 getItemBagIdAndSlot 做了存在性检查，也不需要额外修改。
</action>
<verify>
<automated>grep -n 'isSpellExist.*Berserk\|GetInventoryItemLink.*14' classes/druid/cat.lua</automated>
</verify>
<done>
1. burstMod 的 berserk 块：当 Berserk 技能未学习时，跳过调用直接 return，不设置 flags.berserk = true
2. atkPowerBurst 的 trinket2 块：当饰品槽 14 为空时，跳过 UseInventoryItem(14) 调用
3. 没有引入语法错误：cat.lua 保持有效的 Lua 语法
4. 其余物品（Juju Flurry、Juju Power、Mighty Rage Potion、Invulnerability Potion）不需要修改，因其已有守卫或内部安全检查
</done>
</task>

</tasks>

<verification>
整体验证：grep 改动后的 cat.lua，确认 exist 守卫和物品槽检查已正确加入。
</verification>

<success_criteria>
1. burstMod 中 Berserk 调用前有 isSpellExist 守卫
2. atkPowerBurst 中 Trinket2 调用前有 GetInventoryItemLink 检查
3. 所有语法正确，保持与现有代码风格一致
</success_criteria>

<output>
执行完毕后，无需创建 SUMMARY.md（quick task），直接确认修改验证结果即可。
</output>