--[[
   Copyright 2024 pf_miles

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]] --   
--- 判断当前目标是否正在攻击我
---@param t string 指定的目标
function isTargetAttackingMe()
    local t = 'target'
    return isTargetValidCanAttack(t) and UnitAffectingCombat(t) and UnitName("player") == UnitName("targettarget")
end

--- 判断指定的目标是否存在且活着且可被玩家攻击
---@param t string 指定的目标
---@return boolean true/false
function isTargetValidCanAttack(t)
    return UnitExists(t) and not UnitIsDead(t) and UnitCanAttack('player', t)
end

--- 判断指定的目标是否友好
---@param t string 指定的目标
---@return boolean true/false
function isTargetValidFriendly(t)
    return UnitExists(t) and not UnitIsDead(t) and UnitCanAssist('player', t)
end

--- 判断指定的目标是否是玩家或被玩家控制的目标
---@param t string
function isPlayerOrPlayerControlled(t)
    return UnitIsPlayer(t) or UnitPlayerControlled(t)
end

--- 判断技能栏中指定texture的技能是否已经冷却结束
---@param actionTxtContains string 技能栏中代表技能的图标texture(可以是部分内容, 使用字符串contains判断)
function isActionCooledDown(actionTxtContains)
    for z = 1, 172 do
        local txt = GetActionTexture(z)
        if txt and string.find(txt, actionTxtContains) then
            return GetActionCooldown(z) == 0
        end
    end
end

--- 获得指定目标的剩余生命值百分比
---@param t string 指定的目标
function getUnitHealthPercent(t)
    return UnitHealth(t) / UnitHealthMax(t) * 100
end

--- 获得制定目标剩余魔法/怒气/能量值百分比
---@param t string 指定的目标
function getUnitManaPercent(t)
    return UnitMana(t) / UnitManaMax(t) * 100
end

--- 开启自动近战攻击, 这需要“攻击”技能被放在任意一个技能栏格子里
function startAutoAtk()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        -- and (string.find(a, 'Weapon') or string.find(a, 'Staff') or string.find(a, 'Spell_Reset'))
        if a and IsAttackAction(i) then
            if not IsCurrentAction(i) then
                UseAction(i)
            end
            return
        end
    end
end

--- 开启自动射击, 这需要“射击”技能被放在任意一个技能栏格子里
function startAutoShoot()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and (string.find(a, 'Weapon') or string.find(a, 'Staff')) and ActionHasRange(i) then
            if not IsAutoRepeatAction(i) then
                UseAction(i)
            end
            return
        end
    end
end

--- 判断指定的buff或debuff在指定的目标身上是否存在
---@param t string 指定的目标
---@param txt string 指定的buff/debuff texture文本, 可以是部分内容, 使用string.find匹配
function isBuffOrDebuffPresent(t, txt)
    for i = 1, 40 do
        if string.find(tostring(UnitDebuff(t, i)), txt) or string.find(tostring(UnitBuff(t, i)), txt) then
            return true
        end
    end
    return false
end

--- 获取指定buff或debuff在目标身上的层数
---@param t string 指定的目标
---@param txt string 指定的buff/debuff texture文本, 可以是部分内容, 使用string.find匹配
function getTargetBuffOrDebuffLayers(t, txt)
    for i = 1, 40 do
        if string.find(tostring(UnitDebuff(t, i)), txt) or string.find(tostring(UnitBuff(t, i)), txt) then
            local b, c = UnitDebuff(t, i)
            if c then
                return c
            else
                return 0
            end
        end
    end
    return 0
end

--- 如果指定的buff在指定的目标身上不存在，则释放指定的技能
---@param t string 指定的目标
---@param sp string 指定的技能
---@param dbfTexture string 指定的debuf, texture文本
function castIfBuffAbsent(t, sp, dbfTexture)
    if not isBuffOrDebuffPresent(t, dbfTexture) then
        CastSpellByName(sp)
    end
end

--- 如当前目标存在且是活着的友好目标，则释放指定的法术，否则对自己释放且不丢失当前目标
---@param sp string 指定的法术
function castBuffOrSelf(sp)
    if isTargetValidFriendly('target') then
        CastSpellByName(sp)
    else
        CastSpellByName(sp, true)
    end
end

--- 如果目标生命百分比小于指定值，则释放指定的法术
---@param t 目标
---@param health 生命百分比
---@param spell 法术
function castIfUnitHealthPercentLessThan(t, health, spell)
    if getUnitHealthPercent(t) < health then
        CastSpellByName(spell)
    end
end

--- 如果目标生命百分比大于指定值，则释放指定的法术
---@param t 目标
---@param health 生命百分比
---@param spell 法术
function castIfUnitHealthPercentMoreThan(t, health, spell)
    if getUnitHealthPercent(t) >= health then
        CastSpellByName(spell)
    end
end

--- 若指定的目标不存在指定的buff，则对其使用指定的包包物品
---@param t string 指定的目标
---@param itemName string 指定的包包物品名
---@param buff string buff texture文本
function useItemIfBuffAbsent(t, itemName, buff)
    if not isBuffOrDebuffPresent(t, buff) then
        useItemInBag(t, itemName)
    end
end

--- 若指定的目标生命值百分比小于指定的数值，则对其使用背包里的指定名称的物品
---@param t string 指定的目标
---@param hp number 生命百分比阈值, 0 - 100
---@param itemName string 背包里的物品名称，可以只包含部分名称，使用字符串包含逻辑匹配
function useItemIfHealthPercentLessThan(t, hp, itemName)
    if getUnitHealthPercent(t) < hp then
        useItemInBag(t, itemName)
    end
end

--- 若指定的目标法力/怒气/能量值百分比小于指定的数值，则对其使用背包里的指定名称的物品
---@param t string 指定的目标
---@param mp number 法力/怒气/能量百分比阈值, 0 - 100
---@param itemName string 背包里的物品名称，可以只包含部分名称，使用字符串包含逻辑匹配
function useItemIfManaPercentLessThan(t, mp, itemName)
    if getUnitManaPercent(t) < mp then
        useItemInBag(t, itemName)
    end
end

--- 对指定的目标使用包包里的物品
---@param t string 指定的目标
---@param itemName string 物品名，可仅仅指定一部分名字，使用字符串包含判断
function useItemInBag(t, itemName)
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b, s) do
            local n = GetContainerItemLink(b, s)
            if n and string.find(n, itemName) then
                UseContainerItem(b, s)
                SpellTargetUnit(t)
            end
        end
    end
end

--- 列出所有动作条可释放动作信息
function listActions()
    local i = 0

    for i = 1, 172 do
        local t = GetActionText(i);
        local x = GetActionTexture(i);
        if x then
            local m = "[" .. i .. "] (" .. x .. ")";
            if t then
                m = m .. " \"" .. t .. "\"";
            end
            show(m);
        end
    end
end

--- 列出指定目标身上所有debuff
---@param t string 指定的目标
function listTargetDebuffs(t)
    for i = 1, 40 do
        local d = UnitDebuff(t, i)
        if d then
            show('Found Debuff: ' .. tostring(d))
        end
    end
end

--- 取得目标身上所有debuff的texture文本，返回一个总和字符串
---@param t string 指定的目标
function getTargetAllDebuffText(t)
    local allDebuffTxt = ""
    for i = 1, 40 do
        local d = UnitDebuff(t, i)
        if d then
            allDebuffTxt = allDebuffTxt .. tostring(d)
        end
    end
    return allDebuffTxt
end

--- 列出指定目标身上的所有buff
---@param t string 指定的目标
function listTargetBuffs(t)
    for i = 1, 40 do
        local b = UnitBuff(t, i)
        if b then
            show('Found Buff: ' .. tostring(b))
        end
    end
end

---显示目标的能量类型(魔法: 0, 怒气: 1, 集中值: 2, 能量: 3)
---@param t string 指定的目标
function showTargetPowerType(t)
    show('Power Type: ' .. tostring(UnitPowerType(t)))
end

---显示目标的生物类型
---@param t string 指定的目标
function showTargetType(t)
    show('Unit Type: ' .. tostring(UnitCreatureType(t)))
end

--- 显示目标职业
function showTargetClass(t)
    show('Unit Class: ' .. tostring(UnitClass(t)))
end

--- 在聊天框中显示传入的内容，传入内容会被tostring
---@param a any
function show(a)
    if a then
        DEFAULT_CHAT_FRAME:AddMessage(tostring(a))
    end
end

--- tell if the specified index of stance active
---@param idx number
function isStanceActive(idx)
    local a, b, c = GetShapeshiftFormInfo(idx)
    return c
end
