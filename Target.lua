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

macroTorch.Target = macroTorch.Unit:new("target")

function macroTorch.Target:new()
    local obj = {}
    self.__index = self
    setmetatable(obj, self)
    return obj
end

macroTorch.target = macroTorch.Target:new()

--- 判断当前目标是否正在攻击我
---@param t string 指定的目标
function macroTorch.isTargetAttackingMe()
    local t = 'target'
    return macroTorch.isTargetValidCanAttack(t) and UnitAffectingCombat(t) and
        UnitName("player") == UnitName("targettarget")
end

--- 判断指定的目标是否存在且活着且可被玩家攻击
---@param t string 指定的目标
---@return boolean true/false
function macroTorch.isTargetValidCanAttack(t)
    return UnitExists(t) and not UnitIsDead(t) and UnitCanAttack('player', t)
end

--- 判断指定的目标是否友好
---@param t string 指定的目标
---@return boolean true/false
function macroTorch.isTargetValidFriendly(t)
    return UnitExists(t) and not UnitIsDead(t) and UnitCanAssist('player', t)
end

--- 判断指定的目标是否是玩家或被玩家控制的目标
---@param t string
function macroTorch.isPlayerOrPlayerControlled(t)
    return UnitIsPlayer(t) or UnitPlayerControlled(t)
end

--- 获得指定目标的剩余生命值百分比
---@param t string 指定的目标
function macroTorch.getUnitHealthPercent(t)
    return UnitHealth(t) / UnitHealthMax(t) * 100
end

--- 获得指定目标的损失了多少生命值
---@param t string 指定的目标
function macroTorch.getUnitHealthLost(t)
    return UnitHealthMax(t) - UnitHealth(t)
end

--- 获得制定目标剩余魔法/怒气/能量值百分比
---@param t string 指定的目标
function macroTorch.getUnitManaPercent(t)
    return UnitMana(t) / UnitManaMax(t) * 100
end

--- 判断指定的buff或debuff在指定的目标身上是否存在
---@param t string 指定的目标
---@param txt string 指定的buff/debuff texture文本, 可以是部分内容, 使用string.find匹配
function macroTorch.isBuffOrDebuffPresent(t, txt)
    for i = 1, 40 do
        if string.find(tostring(UnitDebuff(t, i)), txt) or string.find(tostring(UnitBuff(t, i)), txt) then
            return true
        end
    end
    return false
end

-- --- 判断指定的buff或debuff在指定的目标身上还剩多少持续时间
-- ---@param t string 指定的目标
-- ---@param txt string 指定的buff/debuff texture文本, 可以是部分内容, 使用string.find匹配
-- function macroTorch.getBuffOrDebuffDuration(t, txt)
--     for i = 1, 40 do
--         if string.find(tostring(UnitDebuff(t, i)), txt) or string.find(tostring(UnitBuff(t, i)), txt) then
--             return GetPlayerBuffTimeLeft(i)
--         end
--     end
--     return 0
-- end

--- 获取指定buff或debuff在目标身上的层数
---@param t string 指定的目标
---@param txt string 指定的buff/debuff texture文本, 可以是部分内容, 使用string.find匹配
function macroTorch.getTargetBuffOrDebuffLayers(t, txt)
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

--- 列出指定目标身上所有debuff
---@param t string 指定的目标
function macroTorch.listTargetDebuffs(t)
    for i = 1, 40 do
        local d = UnitDebuff(t, i)
        if d then
            macroTorch.show('Found Debuff: ' .. tostring(d))
        end
    end
end

--- 取得目标身上所有debuff的texture文本，返回一个总和字符串
---@param t string 指定的目标
function macroTorch.getTargetAllDebuffText(t)
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
function macroTorch.listTargetBuffs(t)
    for i = 1, 40 do
        local b = UnitBuff(t, i)
        if b then
            macroTorch.show('Found Buff: ' .. tostring(b))
        end
    end
end

