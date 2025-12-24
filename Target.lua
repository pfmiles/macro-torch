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
    -- the newly created target object
    local obj = {}
    -- specify props & method finder of the newly defined Target class
    self.__index = self
    -- set the metatable of the obj to the Target class, when method/field missing, try to find it firstly in TARGET_FIELD_FUNC_MAP, then in the Target class
    setmetatable(obj, {
        __index = function(t, k)
            if macroTorch.TARGET_FIELD_FUNC_MAP[k] ~= nil then
                return macroTorch.TARGET_FIELD_FUNC_MAP[k](t)
            end
            local class_val = self[k]
            if class_val ~= nil then
                return class_val
            end
        end
    })
    -- obj method def
    function obj.isImmune(spellName)
        if obj.isDefiniteBleeding(spellName) then
            return false
        end
        macroTorch.loadImmuneTable()
        return macroTorch.toBoolean(macroTorch.context.immuneTable and
            macroTorch.context.immuneTable[spellName] and macroTorch.context.immuneTable[spellName][obj.name])
    end

    -- record this target to the spell's persistent immune table
    function obj.recordImmune(spellName)
        if obj.isDefiniteBleeding(spellName) then
            return
        end
        macroTorch.loadImmuneTable()
        if not macroTorch.context.immuneTable[spellName] then
            macroTorch.context.immuneTable[spellName] = {}
        end
        if not macroTorch.target.isPlayerControlled and not macroTorch.context.immuneTable[spellName][obj.name] then
            macroTorch.context.immuneTable[spellName][obj.name] = GetTime()
            macroTorch.show("Spell: " .. spellName .. " is recorded IMMUNE to " .. obj.name, 'yellow')
        end
    end

    function obj.removeImmune(spellName)
        macroTorch.loadImmuneTable()
        if macroTorch.context.immuneTable[spellName] and macroTorch.context.immuneTable[spellName][obj.name] then
            macroTorch.context.immuneTable[spellName][obj.name] = nil
            macroTorch.show("Spell: " .. spellName .. " is removed from IMMUNE to " .. obj.name, 'yellow')
        end
    end

    function obj.recordDefiniteBleeding(spellName)
        obj.removeImmune(spellName)
        macroTorch.loadDefiniteBleedingTable()
        if not macroTorch.context.definiteBleedingTable[spellName] then
            macroTorch.context.definiteBleedingTable[spellName] = {}
        end
        if not macroTorch.target.isPlayerControlled and not macroTorch.context.definiteBleedingTable[spellName][obj.name] then
            macroTorch.context.definiteBleedingTable[spellName][obj.name] = true
            macroTorch.show("Spell: " .. spellName .. " is recorded DEFINITE_BLEEDING to " .. obj.name, 'green')
        end
    end

    function obj.isDefiniteBleeding(spellName)
        macroTorch.loadDefiniteBleedingTable()
        return macroTorch.toBoolean(macroTorch.context.definiteBleedingTable and
            macroTorch.context.definiteBleedingTable[spellName] and
            macroTorch.context.definiteBleedingTable[spellName][obj.name])
    end

    -- tell if the current target will die in s seconds, according to its health reducing speed computation
    function obj.willDieInSeconds(s)
        if not s or s < 1 then
            s = 1
        end
        if macroTorch.currentHRPS() <= 0 then
            return false
        end
        local ret = macroTorch.target.health <= macroTorch.currentHRPS() * s
        -- if ret then
        --     macroTorch.show('Last chance! 2*HRPS: ' .. tostring(macroTorch.currentHRPS() * 2))
        -- end
        return ret
    end

    return obj
end

macroTorch.target = macroTorch.Target:new()

-- target fields to function mapping
macroTorch.TARGET_FIELD_FUNC_MAP = {
}

-- maintain the target health vector
function macroTorch.maintainTHV()
    if macroTorch.context then
        local target = macroTorch.target
        if not macroTorch.context.targetHealthVector then
            macroTorch.context.targetHealthVector = {}
        end
        if target.isCanAttack and target.isInCombat then
            table.insert(macroTorch.context.targetHealthVector, { target.health, GetTime() })
            while macroTorch.tableLen(macroTorch.context.targetHealthVector) > 100 do
                table.remove(macroTorch.context.targetHealthVector, 1)
            end
        end
    end
end

macroTorch.registerPeriodicTask('maintainTHV', { interval = 0.1, task = macroTorch.maintainTHV })

-- compute current health-reducing-per-second
function macroTorch.currentHRPS()
    if macroTorch.tableLen(macroTorch.context.targetHealthVector) < 2 then
        return 0
    end

    -- 使用最小二乘法拟合线性回归，计算血量减少的速率
    local sumX = 0
    local sumY = 0
    local sumXY = 0
    local sumXX = 0
    local n = macroTorch.tableLen(macroTorch.context.targetHealthVector)

    -- 计算各项求和值
    for i = 1, n do
        local health, time = unpack(macroTorch.context.targetHealthVector[i])
        sumX = sumX + time
        sumY = sumY + health
        sumXY = sumXY + time * health
        sumXX = sumXX + time * time
    end

    -- 计算线性回归的斜率（即HRPS）
    local slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)

    -- 返回斜率的相反数，因为我们要的是血量减少速率
    return -slope
end

--- 判断当前目标是否正在攻击我
---@param t string 指定的目标
function macroTorch.isTargetAttackingMe()
    local t = 'target'
    return macroTorch.isTargetValidCanAttack(t) and UnitAffectingCombat(t) and
        UnitName("player") == UnitName("targettarget")
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

--- 判断指定的buff在指定的目标身上还剩多少持续时间
---@param t string 指定的目标
---@param txt string 指定的buff texture文本, 可以是部分内容, 使用string.find匹配
function macroTorch.getBuffDuration(t, txt)
    for i = 1, 40 do
        if string.find(tostring(UnitBuff(t, i)), txt) then
            return GetPlayerBuffTimeLeft(i)
        end
    end
    return 0
end

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
        local d, e, f, g = UnitDebuff(t, i)
        if d then
            macroTorch.show('Found Debuff: ' ..
                tostring(d) .. ' | ' .. tostring(e) .. ' | ' .. tostring(f) .. ' | ' .. tostring(g))
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
        local b, c, d = UnitBuff(t, i)
        if b then
            macroTorch.show('Found Buff: ' ..
                tostring(b) ..
                ' | ' .. tostring(c) .. ' | ' .. tostring(d) .. ' | Time Left: ' .. tostring(GetPlayerBuffTimeLeft(i)))
        end
    end
end
