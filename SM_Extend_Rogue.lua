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
--- 释放技能前先偷东西，需潜行且目标存在
---@param sp string 偷东西后要释放的技能
function ppBeforeCast(sp)
    local t = 'target'
    if UnitIsPlayer(t) or not string.find(UnitCreatureType(t), '人型') then
        CastSpellByName(sp)
    else
        if n ~= 1 then
            CastSpellByName("偷窃")
            n = 1
        else
            CastSpellByName(sp)
            n = 0
        end
    end
end
function rogueSneak(startSp)
    ppBeforeCast(startSp)
end
--- 特定情况下回复能量(爆发)
function restoreEnergy()
    local t = 'target'
    if isTargetValidCanAttack(t) and UnitPlayerControlled(t) and UnitMana('player') < 20 then
        useItemInBag('player', '菊花茶')
    end
end
function rogueBattle()
    CastSpellByName('鬼魅攻击')
    CastSpellByName('出血')
    startAutoAtk()
end
--- 盗贼正面战斗
---@param startSp string 潜行状态起手技
function rogueAtk(startSp)
    local t = 'target'
    if isTargetValidCanAttack(t) then
        restoreEnergy()
        if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
            rogueSneak(startSp)
        else
            rogueBattle()
        end
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) then
            restoreEnergy()
            if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
                rogueSneak(startSp)
            else
                rogueBattle()
            end
        end
    end
end
function rogueSneakBack(startSp)
    ppBeforeCast(startSp)
end
function rogueBattleBack()
    CastSpellByName('背刺')
    startAutoAtk()
end
--- 盗贼背后战斗
---@param startSp string 潜行状态起手技
function rogueAtkBack(startSp)
    local t = 'target'
    if isTargetValidCanAttack(t) then
        restoreEnergy()
        if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
            rogueSneakBack(startSp)
        else
            rogueBattleBack()
        end
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) then
            restoreEnergy()
            if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
                rogueSneakBack(startSp)
            else
                rogueBattleBack()
            end
        end
    end
end
--- 切换最近处的敌人并释放指定技能(不是抓贼宏)
---@param sp string 指定技能
function lockNearestEnemyThenCast(sp)
    local t = 'target'
    if isTargetValidCanAttack(t) and CheckInteractDistance(t, 3) then
        CastSpellByName(sp)
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) and CheckInteractDistance(t, 3) then
            CastSpellByName(sp)
        end
    end
end
--- 伺机消失
function readyVanish()
    if not isBuffOrDebuffPresent('player', 'Ability_Stealth') then
        local s = '消失'
        if isActionCooledDown('Ability_Vanish') then
            CastSpellByName(s)
        else
            CastSpellByName('伺机待发')
            CastSpellByName(s)
        end
    end
end
