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

Player = Unit:new("player")

function Player:new()
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    return obj
end

mt.player = Player:new()

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

--- tell if the specified index of stance active
---@param idx number
function isStanceActive(idx)
    local a, b, c = GetShapeshiftFormInfo(idx)
    return c
end

--- 判断指定名称的姿态是否激活
---@param stanceName string 姿态名称，如'Defensive Stance'
function isStanceActiveByName(stanceName)
    local numOfStances = GetNumShapeshiftForms()
    for i = 1, numOfStances do
        if isStanceActive(i) then
            local idx, spellName, enabled = GetShapeshiftFormInfo(i)
            if spellName == stanceName then
                return true
            end
        end
    end
    return false
end

--- 开启自动近战攻击, 这需要“攻击”技能被放在任意一个技能栏格子里
function startAutoAtk()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        -- and (string.find(a, 'Weapon') or string.find(a, 'Staff') or string.find(a, 'Spell_Reset'))
        if a and IsAttackAction(i) and not ActionHasRange(i) and not IsCurrentAction(i) then
            UseAction(i)
            return
        end
    end
end

--- 停止自动攻击
function stopAutoAtk()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and IsAttackAction(i) and not ActionHasRange(i) and IsCurrentAction(i) then
            UseAction(i)
            return
        end
    end
end

-- 定义可复用的查找字符串集合
local RANGED_WEAPON_KEYWORDS = { 'Weapon', 'Staff' }

--- 开启自动射击, 这需要“射击”技能被放在任意一个技能栏格子里
function startAutoShoot()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and containsAnyKeyword(a, RANGED_WEAPON_KEYWORDS) and ActionHasRange(i) and not IsAutoRepeatAction(i) then
            UseAction(i)
            return
        end
    end
end

--- 停止自动射击
function stopAutoShoot()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and containsAnyKeyword(a, RANGED_WEAPON_KEYWORDS) and ActionHasRange(i) and IsAutoRepeatAction(i) then
            UseAction(i)
            return
        end
    end
end
