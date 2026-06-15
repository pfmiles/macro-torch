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
-- Priest combat rotation functions

---远程逻辑
function macroTorch.priestRangedAtk()
    local t = 'target'
    local p = 'player'
    local player = macroTorch.player
    macroTorch.startAutoShoot()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    if macroTorch.isActionCooledDown('Spell_Holy_SearingLight') and not macroTorch.isBuffOrDebuffPresent(t, 'Spell_Holy_SearingLight') and UnitMana(p) >= 95 and macroTorch.getUnitHealthPercent(t) > 10 and GetNumPartyMembers() == 0 then
        macroTorch.stopAutoShoot()
        player.holy_fire()
        -- else
        --     if isActionCooledDown('Spell_Arcane_StarFire') then
        --         CastSpellByName('Starshards')
        --     end
    end
end

--- 牧师一键输出
---@param pvp boolean whether or not attack player targets
function macroTorch.priestAtk(pvp)
    macroTorch.priestBuffs()
    local t = 'target'
    if macroTorch.isTargetValidCanAttack(t) and (pvp or not macroTorch.isPlayerOrPlayerControlled(t)) then
        if UnitAffectingCombat(t) then
            macroTorch.priestDebuffs()
        end
        macroTorch.priestRangedAtk()
    else
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and macroTorch.isTargetValidCanAttack(pt) and
            (pvp or not macroTorch.isPlayerOrPlayerControlled(pt)) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if macroTorch.isTargetValidCanAttack(t) and (pvp or not macroTorch.isPlayerOrPlayerControlled(t)) then
            if UnitAffectingCombat(t) then
                macroTorch.priestDebuffs()
            end
            macroTorch.priestRangedAtk()
        end
    end
end