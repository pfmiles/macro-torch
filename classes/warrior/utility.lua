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
-- Warrior utility functions

---buff逻辑
function macroTorch.wroBuffs()
    local p = 'player'
    if UnitMana(p) >= 10 then
        macroTorch.castIfBuffAbsent(p, 'Shield Block', 'Ability_Defend')
    end
    if UnitMana(p) >= 10 then
        macroTorch.castIfBuffAbsent(p, 'Battle Shout', 'Ability_Warrior_BattleShout')
    end
    if UnitAffectingCombat(p) and UnitMana(p) < 10 then
        macroTorch.player.bloodrage()
    end
end

---debuff逻辑
function macroTorch.wroDebuffs()
    local t = 'target'
end

--- 战士控制
function macroTorch.wroCtrl(pvp)
    local t = 'target'
    if not pvp and macroTorch.isPlayerOrPlayerControlled(t) then
        return
    end
    local p = 'player'
    if UnitAffectingCombat(p) then
        if not macroTorch.isBuffOrDebuffPresent(t, 'Ability_ShockWave') then
            if macroTorch.isStanceActive(2) and UnitMana(p) < 7 then
                CastSpellByName('Battle Stance')
            end
            macroTorch.player.hamstring()
        end
    else
        if not macroTorch.isStanceActive(1) and UnitMana(p) < 7 then
            CastSpellByName('Battle Stance')
        end
        macroTorch.player.charge()
    end
end

function macroTorch.wroInterrupt()
    local p = 'player'
    if macroTorch.isStanceActive(3) and UnitMana(p) < 7 then
        CastSpellByName('Defensive Stance')
    end
    macroTorch.player.shield_bash()
end

--- 大保命逻辑
function macroTorch.warriorDefence()
    if not macroTorch.isStanceActiveByName('Defensive Stance') then
        CastSpellByName('Defensive Stance')
    end
    if macroTorch.isActionCooledDown(macroTorch.SPELL_TEXTURE_MAP['Disarm']) and UnitMana('player') >= 20 then
        macroTorch.player.disarm()
    else
        if macroTorch.isActionCooledDown(macroTorch.SPELL_TEXTURE_MAP['Shield Wall']) then
            macroTorch.player.shield_wall()
        end
    end
    UseInventoryItem(13)
end