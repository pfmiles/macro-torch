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
---法师专用---
---远程逻辑
function mageRangedAtk(reapLine)
    startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end

    CastSpellByName('Frostbolt')
end
---近战逻辑
function mageMeleeAtk(reapLine)
    startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end

    CastSpellByName('Frostbolt')
end
---buff逻辑
function mageBuffs()
    local p = 'player'
    local t = 'target'
    if not isTargetValidFriendly(t) then
        t = p
    end
    castIfBuffAbsent(p, 'Frost Armor', 'Frost_FrostArmor02')
    castIfBuffAbsent(t, 'Arcane Intellect', 'Holy_MagicalSentry')
end

--- 法师一键输出
---@param pvp boolean whether or not attack player targets
function mageAtk(pvp, reapLine)
    mageBuffs()
    local t = 'target'
    if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
        if CheckInteractDistance(t, 3) then
            mageMeleeAtk(reapLine)
        else
            mageRangedAtk(reapLine)
        end
    else
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and isTargetValidCanAttack(pt) and
            (pvp or not isPlayerOrPlayerControlled(pt)) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
            if CheckInteractDistance(t, 3) then
                mageMeleeAtk(reapLine)
            else
                mageRangedAtk(reapLine)
            end
        end
    end
end

--- 法师控制
function mageCtrl()
end
