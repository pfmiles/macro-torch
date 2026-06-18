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
        local ok, sName, spellRank = pcall(GetSpellName, i, bookType);
        if not ok or not sName then
            break;
        end;
        if macroTorch.equalsIgnoreCase(sName, spellName) then
            return i
        end
        i = i + 1;
    end
    return nil
end

-- get spell id by name and rank (1-based, rank 1 = first match/lowest level)
-- @param spellName string spell name
-- @param bookType string book type, 'spell' or 'pet' for example
-- @param rank number|nil the rank to select (1-based), nil or exceeding max → highest rank
-- @return number spell id, or nil if not found
function macroTorch.getSpellIdByNameRank(spellName, bookType, rank)
    local ids = {}
    local i = 1
    while true do
        local ok, sName, spellRank = pcall(GetSpellName, i, bookType)
        if not ok or not sName then
            break
        end
        if macroTorch.equalsIgnoreCase(sName, spellName) then
            table.insert(ids, i)
        end
        i = i + 1
    end
    if macroTorch.tableLen(ids) == 0 then
        return nil
    end
    if rank == nil or rank > macroTorch.tableLen(ids) then
        return ids[macroTorch.tableLen(ids)] -- highest rank
    end
    return ids[rank]
end

function macroTorch.getSpellUniqIdByName(spellName, bookType)
    local spellId = macroTorch.getSpellIdByName(spellName, bookType)
    if not spellId then
        return nil
    end
    local ok, _, c = pcall(GetSpellName, spellId, bookType)
    if not ok then
        return nil
    end
    return c
end

function macroTorch.isSpellExist(spellName, bookType)
    return macroTorch.toBoolean(macroTorch.getSpellIdByName(spellName, bookType))
end

-- a solid implementation of cast spell by name, defaulting to the highest rank
-- @param spellName string spell name
-- @param bookType string book type, 'spell' or 'pet' for example
-- @param rank number|nil optional rank (1-based), nil = highest rank
function macroTorch.castSpellByName(spellName, bookType, rank)
    local spellId = macroTorch.getSpellIdByNameRank(spellName, bookType, rank)
    if not spellId then
        return
    end
    CastSpell(spellId, bookType)
end

-- print all spells, for debug usages
function macroTorch.listAllSpells(bookType)
    local i = 1;
    while true do
        local ok, spellName, spellRank = pcall(GetSpellName, i, bookType);
        if not ok or not spellName then
            break;
        end;
        macroTorch.show(i .. ": " .. spellName .. '(' .. spellRank .. ')');
        i = i + 1;
    end
end

-- get the action slot index of which the melee attack action be placed in
function macroTorch.findAttackActionSlot()
    if not macroTorch.context then
        macroTorch.context = {}
    end
    if not macroTorch.context.attackSlot then
        for i = 1, 120 do
            if GetActionTexture(i) and IsAttackAction(i) and not ActionHasRange(i) then
                macroTorch.context.attackSlot = i
                break
            end
        end
    end
    if not macroTorch.context.attackSlot then
        macroTorch.show(
            "Couldn't find attack action in any of your action slot. Place it in any of the action slots plz.", 'red')
        return false
    end
    return macroTorch.context.attackSlot
end

function macroTorch.getRangedWeaponTexture()
    local slotId, _ = GetInventorySlotInfo("RangedSlot")
    return GetInventoryItemTexture("player", slotId)
end

-- find the action slot index of which the shoot action be placed in
function macroTorch.findAutoShootActionSlot()
    local texture = macroTorch.getRangedWeaponTexture()
    if texture then
        if macroTorch.context.autoShootSlot then
            return macroTorch.context.autoShootSlot
        end

        for i = 1, 120 do
            if (not GetActionText(i)) then        -- ignore any Player macros :-)
                if (not IsEquippedAction(i)) then -- ignore any equip macros :-)
                    if (ActionHasRange(i) and GetActionTexture(i) == texture) then
                        macroTorch.context.autoShootSlot = i
                        break
                    end
                end
            end
        end

        if (not macroTorch.context.autoShootSlot) then
            macroTorch.show('Could not find auto shoot action in any of your action slots, place it in one of them plz.',
                'red')
        end
    else
        macroTorch.context.autoShootSlot = nil
    end
    return macroTorch.context.autoShootSlot
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

-- 找到当前团队/raid中损血最多的成员（包含玩家自己的比较）
-- @return unitId string 损血最多的unitId，默认返回"player"
-- @return healthPercent number 该单位的血量百分比
function macroTorch.findMostDamagedGroupMember()
    local lowestHpUnit = "player"
    local mostMissingHp = UnitHealthMax("player") - UnitHealth("player")

    local maxMembers, prefix
    if macroTorch.player.isInRaid then
        maxMembers = 40
        prefix = "raid"
    else
        maxMembers = 4
        prefix = "party"
    end

    for i = 1, maxMembers do
        local unitId = prefix .. i
        if UnitExists(unitId) and not UnitIsDead(unitId) and UnitHealth(unitId) > 1 then
            if CheckInteractDistance(unitId, 4) then
                local missingHp = UnitHealthMax(unitId) - UnitHealth(unitId)
                if missingHp > mostMissingHp then
                    mostMissingHp = missingHp
                    lowestHpUnit = unitId
                end
            end
        end
    end

    return lowestHpUnit, macroTorch.getUnitHealthPercent(lowestHpUnit)
end

-- 获取天赋等级
-- @param talentName string 天赋名称
-- @return number 天赋等级
function macroTorch.getTalentRank(talentName)
    -- GetNumTalentTabs()
    for tabIndex = 1, GetNumTalentTabs() do
        -- GetTalentInfo(tabIndex,talentIndex)   - return name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq
        for talentIndex = 1, GetNumTalents(tabIndex) do
            local name, _, _, _, rank, _, _, _ = GetTalentInfo(tabIndex, talentIndex)
            if name == talentName then
                return rank
            end
        end
    end
    macroTorch.show("[macro-torch] getTalentRank: talent not found in any tab: " .. tostring(talentName), "yellow")
    return 0
end

-- 检查身上装备格子的装备名称
-- @param slot number 装备格子索引:
-- 1=头部
-- 2=项链
-- 3=肩部
-- 4=衬衫
-- 5=胸部
-- 6=腰带
-- 7=腿部
-- 8=脚部
-- 9=手腕
-- 10=手套
-- 11=戒指1
-- 12=戒指2
-- 13=饰品1
-- 14=饰品2
-- 15=背部
-- 16=主手武器
-- 17=副手武器
-- 18=远程武器
function macroTorch.getEquippedItemLink(slot)
    return GetInventoryItemLink("player", slot)
end

function macroTorch.getEquippedItemSlot(itemName)
    for slot = 1, 18 do
        local link = macroTorch.getEquippedItemLink(slot)
        if link and strfind(link, itemName) then
            return slot
        end
    end
    return nil
end

function macroTorch.isRangedWeaponEquipped(weaponName)
    local link = macroTorch.getEquippedItemLink(18)
    return macroTorch.toBoolean(link and strfind(link, weaponName))
end

macroTorch.isRelicEquipped = macroTorch.isRangedWeaponEquipped

-- 装备背包中物品到指定装备格子
-- @param itemName string 物品名称
-- @param slot number 装备格子索引
function macroTorch.equipItem(itemName, slot)
    local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(itemName)
    if not bagId or not slotIndex then
        return
    end
    PickupContainerItem(bagId, slotIndex)
    EquipCursorItem(slot)
end
