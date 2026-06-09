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
function macroTorch.wlkCurses(reapLine)
    local t = 'target'
    if macroTorch.getUnitHealthPercent(t) > reapLine then
        macroTorch.castIfBuffAbsent(t, 'Immolate', 'Fire_Immolation')
    end

    if macroTorch.getUnitHealthPercent(t) > reapLine then
        macroTorch.castIfBuffAbsent(t, 'Corruption', 'Shadow_AbominationExplosion')
    end

    macroTorch.castIfBuffAbsent(t, 'Curse of Agony', 'Shadow_CurseOfSargeras')
end

---远程逻辑
function macroTorch.wlkRangedAtk(reapLine)
    --startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    macroTorch.wlkCurses(reapLine)

    macroTorch.startAutoShoot()
end

---近战逻辑
function macroTorch.wlkMeleeAtk(reapLine)
    --startAutoAtk()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    macroTorch.wlkCurses(reapLine)

    macroTorch.startAutoShoot()
end

---buff逻辑
function macroTorch.wlkBuffs()
    local p = 'player'
    macroTorch.castIfBuffAbsent(p, 'Demon Skin', 'Shadow_RagingScream')
end

--- 术士一键输出
---@param pvp boolean whether or not attack player targets
function macroTorch.wlkAtk(pvp, reapLine)
    macroTorch.wlkBuffs()
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) and (pvp or not macroTorch.isPlayerOrPlayerControlled(t)) then
        if CheckInteractDistance(t, 3) then
            macroTorch.wlkMeleeAtk(reapLine)
        else
            macroTorch.wlkRangedAtk(reapLine)
        end
    else
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and macroTorch.isTargetValidCanAttack(pt) and
            (pvp or not macroTorch.isPlayerOrPlayerControlled(pt)) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if macroTorch.isTargetValidCanAttack(t) and (pvp or not macroTorch.isPlayerOrPlayerControlled(t)) then
            if CheckInteractDistance(t, 3) then
                macroTorch.wlkMeleeAtk(reapLine)
            else
                macroTorch.wlkRangedAtk(reapLine)
            end
        end
    end
end

--- 术士控制
function macroTorch.wlkCtrl()
end
