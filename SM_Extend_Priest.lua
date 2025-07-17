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
---牧师专用---
---远程逻辑
function macroTorch.priestRangedAtk()
    local t = 'target'
    local p = 'player'
    macroTorch.startAutoShoot()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    if macroTorch.isActionCooledDown('Spell_Holy_SearingLight') and not macroTorch.isBuffOrDebuffPresent(t, 'Spell_Holy_SearingLight') and UnitMana(p) >= 80 and macroTorch.getUnitHealthPercent(t) > 10 and GetNumPartyMembers() == 0 then
        macroTorch.stopAutoShoot()
        CastSpellByName('Holy Fire')
        -- else
        --     if isActionCooledDown('Spell_Arcane_StarFire') then
        --         CastSpellByName('Starshards')
        --     end
    end
end

---buff逻辑
function macroTorch.priestBuffs()
    local p = 'player'
    local t = 'target'
    if not macroTorch.isTargetValidFriendly(t) then
        t = p
    end
    macroTorch.castIfBuffAbsent(t, 'Power Word: Fortitude', 'Spell_Holy_WordFortitude')
    macroTorch.castIfBuffAbsent(p, 'Inner Fire', 'Spell_Holy_InnerFire')
end

---debuff逻辑
function macroTorch.priestDebuffs()
    local t = 'target'
    local p = 'player'
    if macroTorch.getUnitHealthPercent(t) > 10 and GetNumPartyMembers() == 0 then
        macroTorch.castIfBuffAbsent(t, 'Shadow Word: Pain', 'Spell_Shadow_ShadowWordPain')
    end
    macroTorch.useItemIfManaPercentLessThan(p, 10, 'Mana Potion')
    macroTorch.useItemIfHealthPercentLessThan(p, 20, 'Health Potion')
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
        if CheckInteractDistance(t, 3) then
            macroTorch.priestRangedAtk()
        else
            macroTorch.priestRangedAtk()
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
            if UnitAffectingCombat(t) then
                macroTorch.priestDebuffs()
            end
            if CheckInteractDistance(t, 3) then
                macroTorch.priestRangedAtk()
            else
                macroTorch.priestRangedAtk()
            end
        end
    end
end

--- 牧师控制
function macroTorch.priestCtrl(pvp)
end

--- 牧师治疗
function macroTorch.priestHeal()
    local p = 'player'
    local t = 'target'
    if not macroTorch.isTargetValidFriendly(t) then
        t = p
    end
    if macroTorch.getUnitHealthLost(t) > 300 then
        CastSpellByName('Heal')
    elseif macroTorch.getUnitHealthLost(t) > 140 then
        CastSpellByName('Lesser Heal')
    else
        macroTorch.castIfBuffAbsent(t, 'Renew', 'Spell_Holy_Renew')
    end
end
