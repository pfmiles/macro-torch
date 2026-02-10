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

macroTorch.Player = macroTorch.Unit:new("player")

function macroTorch.Player:new()
    local obj = {}

    -- cast spell by name
    -- @param spellName string spell name
    -- @param onSelf boolean true if cast on self, current target otherwise
    function obj.cast(spellName, onSelf)
        macroTorch.castSpellByName(spellName, 'spell')
    end

    -- use item in bag by name
    -- @param itemName string item name
    -- @param onSelf boolean true if use on self, current target otherwise
    function obj.use(itemName, onSelf)
        local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(itemName)
        if bagId and slotIndex then
            UseContainerItem(bagId, slotIndex, onSelf)
            -- SpellTargetUnit(obj.ref)
        end
    end

    -- tell if the player has the specified item in bag
    -- @param itemName string item name
    -- @return boolean true if has, false otherwise
    function obj.hasItem(itemName)
        return macroTorch.isItemExist(itemName)
    end

    -- get spell id by name
    -- @param spellName string spell name
    -- @return number spell id
    function obj.getSpellIdByName(spellName)
        return macroTorch.getSpellIdByName(spellName, 'spell')
    end

    function obj.useTrinket1()
        if GetInventoryItemCooldown("player", 13) == 0 then
            UseInventoryItem(13)
        end
    end

    function obj.isTrinket1CooledDown()
        return GetInventoryItemCooldown("player", 13) == 0
    end

    function obj.useTrinket2()
        if GetInventoryItemCooldown("player", 14) == 0 then
            UseInventoryItem(14)
        end
    end

    function obj.isTrinket2CooledDown()
        return GetInventoryItemCooldown("player", 14) == 0
    end

    -- 随机选择一个坐骑并施放
    function obj.randomMount(mounts)
        CastSpellByName(mounts[math.random(1, table.getn(mounts))])
    end

    -- tell if the specified stance or form is active
    -- @param formName string stance or form name
    -- @return boolean true if active, false otherwise
    function obj.isFormActive(formName)
        local numOfStances = GetNumShapeshiftForms()
        for i = 1, numOfStances do
            local idx, spellName, active = GetShapeshiftFormInfo(i)
            if active then
                if macroTorch.equalsIgnoreCase(spellName, formName) then
                    return true
                end
            end
        end
        return false
    end

    -- tell if the specified spell is ready
    -- @param spellName string spell name
    -- @return boolean true if ready, false otherwise
    function obj.isSpellReady(spellName)
        return macroTorch.toBoolean(SpellReady(spellName) and macroTorch.isSpellCooledDown(spellName, 'spell'))
    end

    -- tell if the specified action is ready, such that GCD is ok
    -- @param indicatorActionTexture the action texture of a spell in action bar, which is used to determine if GCD is ready
    -- @return boolean true if ready, false otherwise
    function obj.isActionCooledDown(indicatorActionTexture)
        -- 'Ability_Druid_Rake' for example
        return macroTorch.isActionCooledDown(indicatorActionTexture)
    end

    function obj.isInBattleField()
        return GetBattlefieldInstanceRunTime() > 0
    end

    --- print all spells in book, for debug usages
    function obj.listAllSpells()
        return macroTorch.listAllSpells('spell')
    end

    -- target nearest enemy if curent target is not attackable
    function obj.targetEnemy()
        if not macroTorch.target.isCanAttack then
            if macroTorch.target.isFriendly and macroTorch.targettarget.isCanAttack then
                AssistUnit('target')
            else
                ClearTarget()
                TargetNearestEnemy()
            end
        end
    end

    -- start auto attack, this requires "Attack" action be placed in any action slot
    function obj.startAutoAtk()
        if not obj.isAutoAttacking then
            UseAction(macroTorch.findAttackActionSlot())
        end
    end

    -- stop auto attack, this requires "Attack" action be placed in any action slot
    function obj.stopAutoAtk()
        if obj.isAutoAttacking then
            UseAction(macroTorch.findAttackActionSlot())
        end
    end

    -- start auto shoot, this requires ranged weapon action be placed in any of the action slots
    function obj.startAutoShoot()
        if not obj.isAutoShooting then
            UseAction(macroTorch.findAutoShootActionSlot())
        end
    end

    -- stop auto shoot, this requires ranged weapon action be placed in any of the action slots
    function obj.stopAutoShoot()
        if obj.isAutoShooting then
            UseAction(macroTorch.findAutoShootActionSlot())
        end
    end

    function obj.isSpellCooledDown(spellName)
        return macroTorch.isSpellCooledDown(spellName, 'spell')
    end

    function obj.isItemCooledDown(itemName)
        if obj.isItemEquipped(itemName) then
            return obj.isEquippedItemCooledDown(itemName)
        else
            return obj.isItemInBagCooledDown(itemName)
        end
    end

    function obj.isEquippedItemCooledDown(itemName)
        return obj.isEquippedItemInSlotCooledDown(obj.macroTorch.getEquippedItemSlot(itemName))
    end

    function obj.isEquippedItemInSlotCooledDown(slot)
        if slot then
            return GetInventoryItemCooldown("player", slot) == 0
        else
            return false
        end
    end

    function obj.isItemInBagCooledDown(itemName)
        return macroTorch.isItemCooledDown(itemName)
    end

    -- get the coolDown, including items both in bag and equipped
    -- @param itemName string item name
    -- @return number coolDown time in seconds
    function obj.getItemCoolDown(itemName)
        if obj.isItemEquipped(itemName) then
            return obj.getEquippedItemCoolDown(itemName)
        else
            return obj.getItemInBagCoolDown(itemName)
        end
    end

    function obj.getItemInBagCoolDown(itemName)
        if macroTorch.isItemExist(itemName) then
            local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(itemName)
            local start, totalCd = GetContainerItemCooldown(bagId, slotIndex)
            if start > 0 and totalCd > 0 then
                return totalCd - (GetTime() - start)
            else
                return 0
            end
        else
            return nil
        end
    end

    function obj.getEquippedItemCoolDown(itemName)
        local slot = macroTorch.getEquippedItemSlot(itemName)
        if slot then
            local start, totalCd = GetInventoryItemCooldown("player", slot)
            if start > 0 and totalCd > 0 then
                return totalCd - (GetTime() - start)
            else
                return 0
            end
        else
            return nil
        end
    end

    function obj.isCasting(spellName)
        return macroTorch.isCasting(spellName, 'spell')
    end

    function obj.isItemEquipped(itemName)
        return macroTorch.getEquippedItemSlot(itemName) ~= nil
    end

    function obj.isRangedWeaponEquipped(weaponName)
        return macroTorch.isRangedWeaponEquipped(weaponName)
    end

    function obj.countEquippedItemNameContains(itemName)
        local count = 0
        for slot = 1, 18 do
            local link = macroTorch.getEquippedItemLink(slot)
            if link and strfind(link, itemName) then
                count = count + 1
            end
        end
        return count
    end

    function obj.equipItem(itemName, slot)
        macroTorch.equipItem(itemName, slot)
    end

    function obj.useEquippedItem(itemName)
        local slot = macroTorch.getEquippedItemSlot(itemName)
        if slot then
            UseInventoryItem(slot)
        end
    end

    function obj.talentRank(talentName)
        return macroTorch.getTalentRank(talentName)
    end

    -- load useable item to the slot in which the swappingItem is placed, give up if the useable item is in CD
    function obj.loadUseableItem(useableItemsTable, swappingItem)
        for _, saying in ipairs(useableItemsTable.keys) do
            local useableItem = useableItemsTable.values[saying]
            if obj.hasItem(useableItem) and obj.getItemInBagCoolDown(useableItem) <= 30 then
                local swappingSlot = macroTorch.getEquippedItemSlot(swappingItem)
                if swappingSlot then
                    if not macroTorch.itemLoadingTable then
                        macroTorch.itemLoadingTable = {}
                    end
                    if not macroTorch.itemLoadingTable[swappingSlot] then
                        macroTorch.itemLoadingTable[swappingSlot] = {}
                    end
                    if macroTorch.itemLoadingTable[swappingSlot].useableItem == nil then
                        macroTorch.itemLoadingTable[swappingSlot].swappingItem = swappingItem
                        macroTorch.itemLoadingTable[swappingSlot].useableItem = useableItem
                        macroTorch.itemLoadingTable[swappingSlot].useableItemUsed = false
                        if saying and not macroTorch.isNumber(saying) then
                            macroTorch.itemLoadingTable[swappingSlot].saying = saying
                        end
                        obj.equipItem(useableItem, swappingSlot)
                        macroTorch.show("Useable item loaded: " .. useableItem)
                        return
                    end
                end
            end
        end
    end

    -- use loaded useable item and swap it back to the original one
    function obj.castLoadedItem()
        if not macroTorch.itemLoadingTable then
            return
        end
        for swappingSlot, loadingTable in pairs(macroTorch.itemLoadingTable) do
            if swappingSlot and loadingTable.useableItem and loadingTable.swappingItem and obj.isItemEquipped(loadingTable.useableItem) then
                if loadingTable.useableItemUsed == false then
                    if obj.isEquippedItemCooledDown(loadingTable.useableItem) then
                        obj.useEquippedItem(loadingTable.useableItem)
                        macroTorch.show("Useable item casted: " .. loadingTable.useableItem)
                        if loadingTable.saying then
                            obj.say(loadingTable.saying)
                        end
                    else
                        macroTorch.show("Useable item is in CD: " .. loadingTable.useableItem)
                    end
                    loadingTable.useableItemUsed = true
                else
                    obj.equipItem(loadingTable.swappingItem, swappingSlot)
                    macroTorch.show("Useable item swapped back: " .. loadingTable.useableItem)
                    macroTorch.itemLoadingTable[swappingSlot] = nil
                end
                return
            else
                -- sth got wrong, just reset
                macroTorch.itemLoadingTable[swappingSlot] = nil
            end
        end
    end

    function obj.say(text)
        if text then
            SendChatMessage(text)
        end
    end

    -- impl hint: original '__index' & metatable setting:
    -- self.__index = self
    -- setmetatable(obj, self)

    setmetatable(obj, {
        -- k is the key of searching field, and t is the table itself
        __index = function(t, k)
            -- missing instance field search
            if macroTorch.PLAYER_FIELD_FUNC_MAP[k] ~= nil then
                return macroTorch.PLAYER_FIELD_FUNC_MAP[k](t)
            end
            -- class field & method search
            local class_val = self[k]
            if class_val ~= nil then
                return class_val
            end
        end
    })

    return obj
end

-- player fields to function mapping
macroTorch.PLAYER_FIELD_FUNC_MAP = {
    -- basic props
    ['threatPercent'] = function(self)
        local TWT = macroTorch.TWT
        local p = 0
        if TWT and TWT.threats and TWT.threats[TWT.name] then p = TWT.threats[TWT.name].perc or 0 end
        return p
    end,
    -- conditinal props
    ['isBehindAttackJustFailed'] = function(self)
        return macroTorch.context and macroTorch.context.behindAttackFailedTime and
            (GetTime() - macroTorch.context.behindAttackFailedTime) <= 0.5
    end,
    ['isBehindTarget'] = function(self)
        return macroTorch.target.isExist and macroTorch.isFunctionExist('UnitXP') and
            UnitXP('behind', 'player', 'target')
    end,
    ['isInGroup'] = function(self)
        return (GetNumPartyMembers() or 0) > 0
    end,
    ['isAutoAttacking'] = function(self)
        return (IsCurrentAction(macroTorch.findAttackActionSlot()) == 1)
    end,
    ['isAutoShooting'] = function(self)
        return (IsAutoRepeatAction(macroTorch.findAutoShootActionSlot()) == 1)
    end,
    ['groupMemberCount'] = function(self)
        return GetNumPartyMembers() or 0
    end,
    ['raidMemberCount'] = function(self)
        return GetNumRaidMembers() or 0
    end,
    ['mateNearMyTargetCount'] = function(self)
        local function mateNearMyTarget(unitId)
            local dis = macroTorch.unitTargetDistance(unitId)
            if not dis then
                return false
            end
            return dis <= 43
        end
        local nearMates = macroTorch.filterGroupMates(mateNearMyTarget)
        return macroTorch.tableLen(nearMates)
    end,
}

macroTorch.player = macroTorch.Player:new()

--- 如果指定的buff在指定的目标身上不存在，则释放指定的技能
---@param t string 指定的目标
---@param sp string 指定的技能
---@param dbfTexture string 指定的debuf, texture文本
function macroTorch.castIfBuffAbsent(t, sp, dbfTexture)
    if not macroTorch.isBuffOrDebuffPresent(t, dbfTexture) then
        CastSpellByName(sp)
    end
end

--- 如当前目标存在且是活着的友好目标，则释放指定的法术，否则对自己释放且不丢失当前目标
---@param sp string 指定的法术
function macroTorch.castBuffOrSelf(sp)
    if macroTorch.isTargetValidFriendly('target') then
        CastSpellByName(sp)
    else
        CastSpellByName(sp, true)
    end
end

--- 如果目标生命百分比小于指定值，则释放指定的法术
---@param t 目标
---@param health 生命百分比
---@param spell 法术
function macroTorch.castIfUnitHealthPercentLessThan(t, health, spell)
    if macroTorch.getUnitHealthPercent(t) < health then
        CastSpellByName(spell)
    end
end

--- 如果目标生命百分比大于指定值，则释放指定的法术
---@param t 目标
---@param health 生命百分比
---@param spell 法术
function macroTorch.castIfUnitHealthPercentMoreThan(t, health, spell)
    if macroTorch.getUnitHealthPercent(t) >= health then
        CastSpellByName(spell)
    end
end

--- 若指定的目标不存在指定的buff，则对其使用指定的包包物品
---@param t string 指定的目标
---@param itemName string 指定的包包物品名
---@param buff string buff texture文本
function macroTorch.useItemIfBuffAbsent(t, itemName, buff)
    if not macroTorch.isBuffOrDebuffPresent(t, buff) then
        macroTorch.useItemInBag(t, itemName)
    end
end

--- 若指定的目标生命值百分比小于指定的数值，则对其使用背包里的指定名称的物品
---@param t string 指定的目标
---@param hp number 生命百分比阈值, 0 - 100
---@param itemName string 背包里的物品名称，可以只包含部分名称，使用字符串包含逻辑匹配
function macroTorch.useItemIfHealthPercentLessThan(t, hp, itemName)
    if macroTorch.getUnitHealthPercent(t) < hp then
        macroTorch.useItemInBag(t, itemName)
    end
end

--- 若指定的目标法力/怒气/能量值百分比小于指定的数值，则对其使用背包里的指定名称的物品
---@param t string 指定的目标
---@param mp number 法力/怒气/能量百分比阈值, 0 - 100
---@param itemName string 背包里的物品名称，可以只包含部分名称，使用字符串包含逻辑匹配
function macroTorch.useItemIfManaPercentLessThan(t, mp, itemName)
    if macroTorch.getUnitManaPercent(t) < mp then
        macroTorch.useItemInBag(t, itemName)
    end
end

--- 对指定的目标使用包包里的物品
---@param t string 指定的目标
---@param itemName string 物品名，可仅仅指定一部分名字，使用字符串包含判断
function macroTorch.useItemInBag(t, itemName)
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b, s) do
            local n = GetContainerItemLink(b, s)
            if n and string.find(n, itemName) then
                UseContainerItem(b, s)
                SpellTargetUnit(t)
            end
        end
    end
end

--- tell if the specified index of stance active
---@param idx number
function macroTorch.isStanceActive(idx)
    local a, b, c = GetShapeshiftFormInfo(idx)
    return c
end

--- 判断指定名称的姿态是否激活
---@param stanceName string 姿态名称，如'Defensive Stance'
function macroTorch.isStanceActiveByName(stanceName)
    local numOfStances = GetNumShapeshiftForms()
    for i = 1, numOfStances do
        if macroTorch.isStanceActive(i) then
            local idx, spellName, enabled = GetShapeshiftFormInfo(i)
            if spellName == stanceName then
                return true
            end
        end
    end
    return false
end

--- 开启自动近战攻击, 这需要“攻击”技能被放在任意一个技能栏格子里
function macroTorch.startAutoAtk()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        -- and (string.find(a, 'Weapon') or string.find(a, 'Staff') or string.find(a, 'Spell_Reset'))
        if a and IsAttackAction(i) and not ActionHasRange(i) and not IsCurrentAction(i) then
            UseAction(i)
            return
        end
    end
end

--- 停止自动攻击
function macroTorch.stopAutoAtk()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and IsAttackAction(i) and not ActionHasRange(i) and IsCurrentAction(i) then
            UseAction(i)
            return
        end
    end
end

-- 定义可复用的查找字符串集合
local RANGED_WEAPON_KEYWORDS = { 'Weapon', 'Staff', 'Bow', 'Gun' }

--- 开启自动射击, 这需要“射击”技能被放在任意一个技能栏格子里
function macroTorch.startAutoShoot()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and macroTorch.containsAnyKeyword(a, RANGED_WEAPON_KEYWORDS) and ActionHasRange(i) and not IsAutoRepeatAction(i) and not IsCurrentAction(i) then
            macroTorch.show(a .. ':' .. tostring(i))
            UseAction(i)
            return
        end
    end
end

--- 停止自动射击
function macroTorch.stopAutoShoot()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and macroTorch.containsAnyKeyword(a, RANGED_WEAPON_KEYWORDS) and ActionHasRange(i) and IsAutoRepeatAction(i) and IsCurrentAction(i) then
            UseAction(i)
            return
        end
    end
end
