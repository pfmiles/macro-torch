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

-- get spell id by name
-- @param spellName string spell name
-- @param bookType string book type, 'spell' or 'pet' for example
-- @return number spell id
function macroTorch.getSpellIdByName(spellName, bookType)
    local i = 1;
    while true do
        local sName, spellRank = GetSpellName(i, bookType);
        if not sName then
            break;
        end;
        if macroTorch.equalsIgnoreCase(sName, spellName) then
            return i
        end
        i = i + 1;
    end
    return nil
end

-- print all spells, for debug usages
function macroTorch.listAllSpells(bookType)
    local i = 1;
    while true do
        local spellName, spellRank = GetSpellName(i, bookType);
        if not spellName then
            break;
        end;
        macroTorch.show(i .. ": " .. spellName .. '(' .. spellRank .. ')');
        i = i + 1;
    end
end

-- toggle auto attack status
function macroTorch.toggleAutoAtk(start)
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and IsAttackAction(i) and not ActionHasRange(i) then
            local isCur = IsCurrentAction(i)
            if (start and not isCur) or (not start and isCur) then
                UseAction(i)
            end
            return
        end
    end
    macroTorch.show(
        "ERROR: No attack action found in any of the action slots, please place \"Attack\" action in any action slot!")
end

local RANGED_WEAPON_KEYWORDS = { 'Weapon', 'Staff' }
-- start auto shoot, this requires ranged weapon action be placed in any of the action slots
function macroTorch.toggleAutoShoot(start)
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and macroTorch.containsAnyKeyword(a, RANGED_WEAPON_KEYWORDS) and ActionHasRange(i) then
            local isCur = IsCurrentAction(i)
            if (start and not isCur) or (not start and isCur) then
                UseAction(i)
            end
            return
        end
    end
    macroTorch.show(
        "ERROR: No ranged weapon action found in any of the action slots, please place \"Ranged Weapon(like bow or wand)\" action in any action slot!")
end

function macroTorch.isSpellCooledDown(spellName, bookType)
    local spellId = macroTorch.getSpellIdByName(spellName, bookType)
    if not spellId then
        return false
    end
    return GetSpellCooldown(spellId, bookType) <= 0
end

function macroTorch.getSpellTexture(spellName, bookType)
    local spellId = macroTorch.getSpellIdByName(spellName, bookType)
    if not spellId then
        return nil
    end
    return GetSpellTexture(spellId, bookType)
end

function macroTorch.getItemBagIdAndSlot(itemName)
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b, s) do
            local n = GetContainerItemLink(b, s)
            if n and string.find(n, itemName) then
                return b, s
            end
        end
    end
end

function macroTorch.isItemCooledDown(itemName)
    local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(itemName)
    if not bagId or not slotIndex then
        return false
    end
    return GetContainerItemCooldown(bagId, slotIndex) <= 0
end

function macroTorch.getItemInfo(itemName)
    local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(itemName)
    if not bagId or not slotIndex then
        return nil
    end
    return GetContainerItemInfo(bagId, slotIndex)
end

function macroTorch.isCasting(spellName, bookType)
    local spellId = macroTorch.getSpellIdByName(spellName, bookType)
    if not spellId then
        return false
    end
    return macroTorch.toBoolean(IsCurrentCast(spellId, bookType))
end

-- 定义计算table长度的函数
function macroTorch.tableLen(tbl)
    local len = 0
    for _ in pairs(tbl) do
        len = len + 1
    end
    return len
end
