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
---术士专用---
---诅咒逻辑
function wlkCurses(reapLine)
    local t = 'target'
    if getUnitHealthPercent(t) > reapLine then
        castIfBuffAbsent(t, 'Immolate', 'Fire_Immolation')
    end

    if getUnitHealthPercent(t) > reapLine then
        castIfBuffAbsent(t, 'Corruption', 'Shadow_AbominationExplosion')
    end

    castIfBuffAbsent(t, 'Curse of Agony', 'Shadow_CurseOfSargeras')
end
---远程逻辑
function wlkRangedAtk(reapLine)
    --startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    wlkCurses(reapLine)

    startAutoShoot()
end
---近战逻辑
function wlkMeleeAtk(reapLine)
    --startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    wlkCurses(reapLine)

    startAutoShoot()
end
---buff逻辑
function wlkBuffs()
    local p = 'player'
    castIfBuffAbsent(p, 'Demon Skin', 'Shadow_RagingScream')
end

--- 术士一键输出
---@param pvp boolean whether or not attack player targets
function wlkAtk(pvp, reapLine)
    wlkBuffs()
    local t = 'target'
    if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
        if CheckInteractDistance(t, 3) then
            wlkMeleeAtk(reapLine)
        else
            wlkRangedAtk(reapLine)
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
                wlkMeleeAtk(reapLine)
            else
                wlkRangedAtk(reapLine)
            end
        end
    end
end

--- 术士控制
function wlkCtrl()
end
