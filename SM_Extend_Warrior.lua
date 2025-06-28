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
---战士专用---
---远程逻辑
function wroRangedAtk(reapLine)
    startAutoShoot()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    CastSpellByName('Throw')
end
---近战逻辑
function wroMeleeAtk(reapLine)
    local t = 'target'
    local p = 'player'

    -- 开始攻击
    startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end

    -- 上自身buff
    wroBuffs()
    -- 给敌方叠debuff
    wroDebuffs()
    
    if isStanceActive(1) then
        -- 战斗姿态
        CastSpellByName('Overpower')
    end
    if isStanceActive(2) then
        -- 防御姿态
        if not isTargetAttackingMe() then
            CastSpellByName('Taunt')
        end
        CastSpellByName('Revenge')
        -- 在团队中时叠破甲
        if GetNumPartyMembers() > 0 and getTargetBuffOrDebuffLayers(t, 'Ability_Warrior_Sunder') < 5 then
            CastSpellByName('Sunder Armor')
        end
    end
    
    CastSpellByName('Heroic Strike')
    ---CastSpellByName('Slam')
end
---buff逻辑
function wroBuffs()
    local p = 'player'
    if UnitMana(p) >= 10 then
        castIfBuffAbsent(p, 'Shield Block', 'Ability_Defend')
    end
    if UnitMana(p) >= 10 then
        castIfBuffAbsent(p, 'Battle Shout', 'Ability_Warrior_BattleShout')
    end
    if UnitAffectingCombat(p) and UnitMana(p) < 10 then
        CastSpellByName('Bloodrage')
    end
end
---debuff逻辑
function wroDebuffs()
    local t = 'target'
    castIfBuffAbsent(t, 'Rend', 'Ability_Gouge')
end

--- aoe逻辑
function wroAoe()
    local t = 'target'
    local p = 'player'
    if not isBuffOrDebuffPresent(t, 'Spell_Nature_ThunderClap') then
        if isStanceActive(3) and UnitMana(p) < 7 then
            CastSpellByName('Defensive Stance')
        end
        CastSpellByName('Thunder Clap')
    end
    castIfBuffAbsent(t, 'Demoralizing Shout', 'Ability_Warrior_WarCry')
end

function wroInterrupt()
    local p = 'player'
    if isStanceActive(3) and UnitMana(p) < 7 then
        CastSpellByName('Defensive Stance')
    end
    CastSpellByName('Shield Bash')
end

--- 战士一键输出
---@param pvp boolean whether or not attack player targets
function wroAtk(pvp, reapLine, mainStanceIdx)
    local p = 'player'
    -- 切回主姿态
    if not isStanceActive(mainStanceIdx) and UnitMana(p) < 5 then
        CastShapeshiftForm(mainStanceIdx)
    end
    local t = 'target'
    if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
        -- 如果当前地方目标在近距离
        if CheckInteractDistance(t, 3) then
            wroMeleeAtk(reapLine)
        else
            wroRangedAtk(reapLine)
        end
    else
        -- 如果没有目标，有限支援宠物目标，否则搜寻最近敌人目标
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and isTargetValidCanAttack(pt) and
            (pvp or not isPlayerOrPlayerControlled(pt)) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
            if CheckInteractDistance(t, 3) then
                wroMeleeAtk(reapLine)
            else
                wroRangedAtk(reapLine)
            end
        end
    end
end

--- 战士控制
function wroCtrl(pvp)
    local t = 'target'
    if not pvp and isPlayerOrPlayerControlled(t) then
        return
    end
    local p = 'player'
    if UnitAffectingCombat(p) then
        if not isBuffOrDebuffPresent(t, 'Ability_ShockWave') then
            if isStanceActive(2) and UnitMana(p) < 7 then
                CastSpellByName('Battle Stance')
            end
            CastSpellByName('Hamstring')
        end
    else
        if not isStanceActive(1) and UnitMana(p) < 7 then
            CastSpellByName('Battle Stance')
        end
        CastSpellByName('Charge')
    end
end
