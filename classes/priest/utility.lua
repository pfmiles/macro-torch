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
-- Priest utility functions

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

--- 牧师控制
function macroTorch.priestCtrl(pvp)
end

--- 牧师治疗
function macroTorch.priestHeal()
    local p = 'player'
    local t = 'target'
    local player = macroTorch.player
    local onSelf = false
    if not macroTorch.isTargetValidFriendly(t) then
        t = p
        onSelf = true
    end
    if macroTorch.getUnitHealthLost(t) > 440 then
        player.heal('ready', onSelf)
    elseif macroTorch.getUnitHealthLost(t) > 140 then
        player.lesser_heal('ready', onSelf)
    else
        macroTorch.castIfBuffAbsent(t, 'Renew', 'Spell_Holy_Renew')
    end
end