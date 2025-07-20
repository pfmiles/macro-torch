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

macroTorch.Pet = macroTorch.Unit:new("pet")

function macroTorch.Pet:new()
    local obj = {}

    -- list all spells of the pet, for debug usages
    function obj.listAllSpells()
        return macroTorch.listAllSpells('pet')
    end

    -- get spell id by name
    -- @param spellName string spell name
    -- @return number spell id
    function obj.getSpellIdByName(spellName)
        return macroTorch.getSpellIdByName(spellName, 'pet')
    end

    function obj.isSpellCooledDown(spellName)
        return macroTorch.isSpellCooledDown(spellName, 'pet')
    end

    self.__index = self
    setmetatable(obj, self)
    return obj
end

macroTorch.pet = macroTorch.Pet:new()
