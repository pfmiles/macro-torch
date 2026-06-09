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
---盗贼专用start---
--- 是否被盗贼技能眩晕
---@param t string 指定的目标
function macroTorch.isTargetRogueFaint(t)
    local rogueFaintDebuffs = { 'CheapShot', 'Rogue_KidneyShot' }
    local allDebuffText = macroTorch.getTargetAllDebuffText(t)
    for i, v in ipairs(rogueFaintDebuffs) do
        if string.find(allDebuffText, v) then
            return true
        end
    end
    return false
end

--- 释放技能前先偷东西，需潜行且目标存在
---@param sp string 偷东西后要释放的技能
function macroTorch.pickPocketBeforeCast(spell)
    local t = 'target'
    if UnitIsPlayer(t) or not string.find(UnitCreatureType(t), '人型生物') then
        CastSpellByName(spell)
    else
        if n ~= 1 then
            CastSpellByName("偷窃")
            n = 1
        else
            CastSpellByName(spell)
            n = 0
        end
    end
end

function macroTorch.rogueSneak(startSp)
    macroTorch.pickPocketBeforeCast(startSp)
end

--- 特定情况下回复
function macroTorch.restoreIfNeeded()
    local p = 'player'
    if macroTorch.isTargetAttackingMe() and UnitPlayerControlled('target') and UnitMana(p) < 20 then
        macroTorch.useItemInBag(p, '菊花茶')
    end
    macroTorch.useItemIfHealthPercentLessThan(p, 30, '治疗药水')
end

function macroTorch.rogueBattle()
    if not macroTorch.isTargetRogueFaint('target') and macroTorch.isTargetAttackingMe() then
        CastSpellByName('鬼魅攻击')
    end
    CastSpellByName('出血')
    CastSpellByName('邪恶攻击')
    macroTorch.startAutoAtk()
end

--- 盗贼正面战斗
---@param startSp string 潜行状态起手技
function macroTorch.rogueAtk(startSp)
    macroTorch.restoreIfNeeded()
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) then
        if macroTorch.isBuffOrDebuffPresent('player', 'Ability_Stealth') then
            macroTorch.rogueSneak(startSp)
        else
            macroTorch.rogueBattle()
        end
    else
        TargetNearestEnemy()
        if macroTorch.isTargetValidCanAttack(t) then
            if macroTorch.isBuffOrDebuffPresent('player', 'Ability_Stealth') then
                macroTorch.rogueSneak(startSp)
            else
                macroTorch.rogueBattle()
            end
        end
    end
end

function macroTorch.rogueSneakBack(startSp)
    macroTorch.pickPocketBeforeCast(startSp)
end

function macroTorch.rogueBattleBack()
    CastSpellByName('背刺')
    macroTorch.startAutoAtk()
end

--- 盗贼背后战斗
---@param startSp string 潜行状态起手技
function macroTorch.rogueAtkBack(startSp)
    macroTorch.restoreIfNeeded()
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) then
        if macroTorch.isBuffOrDebuffPresent('player', 'Ability_Stealth') then
            macroTorch.rogueSneakBack(startSp)
        else
            macroTorch.rogueBattleBack()
        end
    else
        TargetNearestEnemy()
        if macroTorch.isTargetValidCanAttack(t) then
            if macroTorch.isBuffOrDebuffPresent('player', 'Ability_Stealth') then
                macroTorch.rogueSneakBack(startSp)
            else
                macroTorch.rogueBattleBack()
            end
        end
    end
end

--- 切换最近处的敌人并释放指定技能(不是抓贼宏)
---@param sp string 指定技能
function macroTorch.lockNearestEnemyThenCast(sp)
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) and CheckInteractDistance(t, 3) then
        CastSpellByName(sp)
    else
        TargetNearestEnemy()
        if macroTorch.isTargetValidCanAttack(t) and CheckInteractDistance(t, 3) then
            CastSpellByName(sp)
        end
    end
end

--- 伺机消失
function macroTorch.readyVanish()
    if not macroTorch.isBuffOrDebuffPresent('player', 'Ability_Stealth') then
        local s = '消失'
        if macroTorch.isActionCooledDown('Ability_Vanish') then
            CastSpellByName(s)
        else
            CastSpellByName('伺机待发')
            CastSpellByName(s)
        end
    end
end
