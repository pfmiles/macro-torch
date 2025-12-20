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

function macroTorch.isSpellExist(spellName, bookType)
    return macroTorch.toBoolean(macroTorch.getSpellIdByName(spellName, bookType))
end

-- a solid implementation of cast spell by name
-- @param spellName string spell name
-- @param bookType string book type, 'spell' or 'pet' for example
function macroTorch.castSpellByName(spellName, bookType)
    CastSpell(macroTorch.getSpellIdByName(spellName, bookType), bookType)
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
    local coolDown = GetSpellCooldown(spellId, bookType)
    -- macroTorch.show("Cooldown: " .. tostring(coolDown))
    return coolDown == 0
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

function macroTorch.isItemExist(itemName)
    local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(itemName)
    return macroTorch.toBoolean(bagId and slotIndex)
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

-- get the distance between specified unit and my target
function macroTorch.unitTargetDistance(unitId)
    if not UnitExists(unitId) or UnitIsDead(unitId) or not macroTorch.target.isExist then
        return nil
    end
    local distance = UnitXP("distanceBetween", unitId, "target")
    if not distance or distance < 0 then
        return nil
    end
    return distance
end

-- 过滤出符合条件的团队成员
-- @param predFunc function 过滤函数, 参数为unitId，返回值为boolean
-- @return table 符合条件的团队成员的unitId数组
function macroTorch.filterGroupMates(predFunc)
    local result = {}
    if macroTorch.player.isInRaid then
        for i = 1, 40 do
            local unitId = "raid" .. i
            if UnitExists(unitId) and not UnitIsDead(unitId) and not UnitIsUnit(unitId, "player") then
                if predFunc(unitId) then
                    table.insert(result, unitId)
                end
            end
        end
    elseif macroTorch.player.isInGroup and not macroTorch.player.isInRaid then
        for i = 1, 4 do
            local unitId = "party" .. i
            if UnitExists(unitId) and not UnitIsDead(unitId) and not UnitIsUnit(unitId, "player") then
                if predFunc(unitId) then
                    table.insert(result, unitId)
                end
            end
        end
    end

    -- macroTorch.show('filterGroupMates result: ' .. table.concat(result, ', '))
    return result
end
