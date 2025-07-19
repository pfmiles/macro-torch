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

macroTorch.SPELL_TEXTURE_MAP = {
    --- warrior start
    ['Defensive Stance'] = 'Ability_Warrior_DefensiveStance',
    ['Battle Stance'] = 'Ability_Warrior_OffensiveStance',
    ['Rend'] = 'Ability_Gouge',
    ['Sunder Armor'] = 'Ability_Warrior_Sunder',
    ['Demoralizing Shout'] = 'Ability_Warrior_WarCry',
    ['Thunder Clap'] = 'Spell_Nature_ThunderClap',
    ['Shield Wall'] = 'Ability_Warrior_ShieldWall',
    ['Disarm'] = 'Ability_Warrior_Disarm',
    --- warrior end
}

macroTorch.ITEM_TEXTURE_MAP = {}

--- get the buff or debuff texture of the specified spell or item
--- @param spellOrItemName the name of the spell or item
--- @return the texture of the buff or debuff of the specified spell or item
function macroTorch.getSpellOrItemBuffTexture(spellOrItemName)
    local ret = macroTorch.SPELL_TEXTURE_MAP[spellOrItemName] or macroTorch.ITEM_TEXTURE_MAP[spellOrItemName]
    if ret then
        return ret
    end
    return spellOrItemName
end
