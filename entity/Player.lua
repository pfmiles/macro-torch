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

    -- cast spell by name (precise spell targeting via macroTorch.castSpellByName)
    -- for self-cast, use obj.cast (CastSpell via spellbook index), same as _castSpell
    -- @param spellName string spell name
    -- @param rank number|nil optional rank (1-based), nil = highest rank
    function obj.cast(spellName, rank)
        macroTorch.castSpellByName(spellName, 'spell', rank)
    end

    -- Internal: shared spell casting helper with locale support, readiness, and resource checks
    -- @param localeNames table { en = 'EnglishName', zh = '中文名' }
    -- @param mode string|nil nil='safe' (default), 'ready'=readiness only, 'raw'=no checks
    -- @param range number|nil distance in yards, nil = melee (no check)
    -- @param resourceCost number|function|nil cost or function returning cost, nil = skip check
    -- @param onSelf boolean true if cast on self
    -- @param rank number|nil optional rank (1-based), nil = highest rank
    -- @return boolean true if spell was cast
    function obj._castSpell(localeNames, mode, range, resourceCost, onSelf, rank)
        -- 1. Locale-based spell name selection
        local locale = GetLocale()
        local spellName
        if locale == 'zhCN' and localeNames.zh then
            spellName = localeNames.zh
        else
            spellName = localeNames.en
        end

        -- 2. Readiness check (skip if mode is 'raw')
        if mode ~= 'raw' then
            if not obj.isSpellReady(spellName) then
                return false
            end
        end

        -- 3. Distance + resource checks (skip for 'ready' and 'raw', default nil = safe)
        if mode ~= 'ready' and mode ~= 'raw' then
            if range and not onSelf and not obj._isInRange(range) then
                return false
            end
            if resourceCost then
                local cost
                if type(resourceCost) == 'function' then
                    cost = resourceCost()
                else
                    cost = resourceCost
                end
                if not obj._hasResource(cost) then
                    return false
                end
            end
        end

        -- Unified cast path: both self-cast and target-cast use obj.cast
        -- (CastSpell via spellbook index), because CastSpellByName parses
        -- parentheses as rank specifiers, silently failing for spells like
        -- "Barkskin (Feral)" or "Faerie Fire (Feral)".
        -- For self-only spells, CastSpell auto-targets the caster.
        -- Bridge for UNIT_CASTEVENT: record English spell name so the event handler
        -- can correlate the cast event with the spell without needing spellId.
        -- Clears any stale bridge from a previous failed cast first.
        macroTorch._pendingCastSpellName = nil
        obj.cast(spellName, rank)
        macroTorch._pendingCastSpellName = localeNames.en
        return true
    end

    -- Internal: check if current target is within casting range
    -- @param range number distance in yards, nil/0 = melee (always in range if target exists)
    -- @return boolean
    function obj._isInRange(range)
        if not macroTorch.target or not macroTorch.target.isExist then
            return false
        end
        if type(range) ~= 'number' or range <= 0 then
            return true  -- nil/0 range = melee, always considered in range if target exists
        end
        return macroTorch.target.distance <= range
    end

    -- Internal: check if player has sufficient resource for spell
    -- WoW 1.12.1: UnitMana('player') auto-returns energy in cat, rage in bear, mana in caster
    -- @param cost number resource cost (energy/rage/mana)
    -- @return boolean
    function obj._hasResource(cost)
        return self.mana and self.mana >= cost
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
        local ok, ready = pcall(SpellReady, spellName)
        if not ok then return false end
        return macroTorch.toBoolean(ready and macroTorch.isSpellCooledDown(spellName, 'spell'))
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
        return obj.isEquippedItemInSlotCooledDown(macroTorch.getEquippedItemSlot(itemName))
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
                        return true
                    end
                end
            end
        end
        return false
    end

    -- Load the next useable item from the table into its target equipment slot,
    -- with an automatic snapshot of whatever the load displaces:
    --   * target slot occupied -> the displaced item name is recorded (swap path)
    --     so the restore press can put it back to the same slot;
    --   * target slot empty (off-hand) -> the main hand (16) is snapshotted first,
    --     then the item is equipped and verified via GetInventoryItemLink:
    --       - verified: keep the load, main hand untouched (nothing to restore
    --         except the loaded item itself);
    --       - refused (a two-hand weapon in the main hand blocks the off-hand):
    --         the two-hander is unequipped into an empty bag slot (recorded),
    --         then the equip is retried and verified again.
    -- Only one item can be loaded at a time - must cast and unload before loading
    -- another.
    -- @param useableItemsTable table with keys, values (maps key->item name) and
    --        toSlots (maps key->target equipment slot, 13/14=trinket, 16=main
    --        hand, 17=off-hand)
    --
    -- Example of useableItemsTable structure:
    --     local combatItems = {
    --         keys = {"Use Trinket 1", "Use Trinket 2", "Use Weapon"},
    --         values = {
    --             ["Use Trinket 1"] = "Talisman of Ephemeral Power",
    --             ["Use Trinket 2"] = "Zandalarian Hero Charm",
    --             ["Use Weapon"] = "Crul'shorukh, Edge of Chaos"
    --         },
    --         toSlots = {
    --             ["Use Trinket 1"] = 13,  -- Trinket slot 1
    --             ["Use Trinket 2"] = 14,  -- Trinket slot 2
    --             ["Use Weapon"] = 16      -- Main hand
    --         }
    --     }
    --     macroTorch.player.loadUseableItemToSlot(combatItems)

    -- Empirically verified client fact: GetInventoryItemLink returns ZERO values
    -- on an empty slot in this Lua 5.0 client. Every read below is captured into
    -- a local first - never concatenate, index or tostring a raw multi-value API
    -- return.
    -- @param slot number equipment slot index
    -- @param itemName string item name (substring match)
    -- @return boolean true only when the slot link exists and contains itemName
    function obj.isItemNameInSlot(slot, itemName)
        local link = macroTorch.getEquippedItemLink(slot)
        return macroTorch.toBoolean(link and strfind(link, itemName))
    end

    -- Equip a bag item into targetSlot and verify the result through the slot
    -- link. This gate fixes the former unconditional-success bug: the client
    -- refuses the equip (e.g. off-hand while a two-hander occupies the main
    -- hand) with a clean cursor and the item auto-returned to the bag, so the
    -- only trustworthy success signal is the slot link itself.
    -- @param itemName string item name in bag
    -- @param targetSlot number equipment slot index
    -- @return boolean true only when the slot link confirms the item landed
    function obj.equipItemToSlotVerified(itemName, targetSlot)
        obj.equipItem(itemName, targetSlot)
        return obj.isItemNameInSlot(targetSlot, itemName)
    end

    -- Unequip the named item from equipment slot into the first empty bag slot,
    -- verifying every sub-step; on any failed sub-step the item is rolled back
    -- into the original slot so the inventory is never left half-moved.
    -- Sub-steps: PickupInventoryItem(slot) lifts the item onto the cursor and
    -- empties the slot; PickupContainerItem(bag, emptySlot) deposits the cursor
    -- item into that empty slot (same-frame protected-action pairing as the
    -- verified PickupContainerItem + EquipCursorItem sequence).
    -- @param itemName string expected item name in slot
    -- @param slot number equipment slot index
    -- @return boolean true only when the slot no longer holds itemName and
    --         itemName is found in a bag
    function obj.unequipToBagVerified(itemName, slot)
        if not obj.isItemNameInSlot(slot, itemName) then
            return false
        end
        PickupInventoryItem(slot)
        if obj.isItemNameInSlot(slot, itemName) then
            return false
        end
        local depositBag, depositSlot = nil, nil
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            for s = 1, numSlots do
                local slotLink = GetContainerItemLink(bag, s)
                if not slotLink then
                    depositBag, depositSlot = bag, s
                    break
                end
            end
            if depositBag then
                break
            end
        end
        if not depositBag then
            EquipCursorItem(slot)
            return false
        end
        PickupContainerItem(depositBag, depositSlot)
        if CursorHasItem() then
            EquipCursorItem(slot)
            return false
        end
        if obj.isItemNameInSlot(slot, itemName) or not macroTorch.isItemExist(itemName) then
            return false
        end
        return true
    end

    function obj.loadUseableItemToSlot(useableItemsTable)
        -- Ensure useableItemsTable has required fields
        if not useableItemsTable or not useableItemsTable.keys or not useableItemsTable.toSlots then
            macroTorch.show("Invalid useableItemsTable: missing required fields")
            return false
        end

        -- Combat pause: equipment actions are client-refused while in combat.
        -- The load key simply does nothing then; press it again after combat, no
        -- state is lost.
        if UnitAffectingCombat("player") then
            return false
        end

        -- Resume arm pre-scan: a previous press unequipped the two-hander but
        -- the final equip was not verified, so the state table only holds a
        -- pending entry. Finish it before any fresh load attempt so it can
        -- never be shadowed by another loadable item in the ordered table.
        if macroTorch.itemLoadingTable then
            for slot, pendingTable in pairs(macroTorch.itemLoadingTable) do
                if slot and pendingTable and pendingTable.pendingEquip and not pendingTable.useableItem then
                    obj.equipItem(pendingTable.pendingEquip, slot)
                    if obj.isItemNameInSlot(slot, pendingTable.pendingEquip) then
                        pendingTable.useableItem = pendingTable.pendingEquip
                        pendingTable.useableItemUsed = false
                        if pendingTable.pendingSaying and not macroTorch.isNumber(pendingTable.pendingSaying) then
                            pendingTable.saying = pendingTable.pendingSaying
                        end
                        pendingTable.pendingEquip = nil
                        pendingTable.pendingSaying = nil
                        macroTorch.show("Useable item loaded to slot " .. slot .. ": " .. pendingTable.useableItem)
                        return true
                    end
                    macroTorch.show("Useable item load failed to slot " .. slot .. ": " .. pendingTable.pendingEquip)
                    return false
                end
            end
        end

        -- Global lock: at most one loaded item at a time. State is only written
        -- after a verified success, so any entry with an unused useableItem is
        -- a real loaded item and must block new loads.
        if macroTorch.itemLoadingTable then
            for _, loadingTable in pairs(macroTorch.itemLoadingTable) do
                if loadingTable.useableItem and loadingTable.useableItemUsed == false then
                    macroTorch.show("A usable item is already loaded: " .. loadingTable.useableItem)
                    return false
                end
            end
        end

        for _, saying in ipairs(useableItemsTable.keys) do
            local useableItem = useableItemsTable.values[saying]
            local targetSlot = useableItemsTable.toSlots[saying]

            -- Validate targetSlot
            if not targetSlot or targetSlot < 1 or targetSlot > 18 then
                macroTorch.show("Invalid target slot for " .. saying .. ": " .. tostring(targetSlot))
                return false
            end

            if obj.hasItem(useableItem) and obj.getItemInBagCoolDown(useableItem) <= 30 then
                -- Snapshot first: what is occupying the target slot right now?
                local currentSlotLink = macroTorch.getEquippedItemLink(targetSlot)
                if currentSlotLink then
                    -- Swap path: remember the displaced item so the restore
                    -- press can put it back to the same slot
                    local displacedItem = macroTorch.getItemNameFromLink(currentSlotLink)
                    if not obj.equipItemToSlotVerified(useableItem, targetSlot) then
                        macroTorch.show("Useable item load failed to slot " .. targetSlot .. ": " .. useableItem)
                        return false
                    end
                    if not macroTorch.itemLoadingTable then
                        macroTorch.itemLoadingTable = {}
                    end
                    macroTorch.itemLoadingTable[targetSlot] = {
                        useableItem = useableItem,
                        useableItemUsed = false,
                        swappingItem = displacedItem
                    }
                    if saying and not macroTorch.isNumber(saying) then
                        macroTorch.itemLoadingTable[targetSlot].saying = saying
                    end
                    macroTorch.show("Useable item loaded to slot " .. targetSlot .. ": " .. useableItem)
                    return true
                end

                -- Target slot empty: snapshot the main hand (16) and try
                -- equipping. Success keeps the main hand untouched; refusal
                -- means a two-hander blocks the off-hand and it must move first.
                local mainHandLink = macroTorch.getEquippedItemLink(16)
                local mainHandItem = nil
                if mainHandLink then
                    mainHandItem = macroTorch.getItemNameFromLink(mainHandLink)
                end
                if obj.equipItemToSlotVerified(useableItem, targetSlot) then
                    if not macroTorch.itemLoadingTable then
                        macroTorch.itemLoadingTable = {}
                    end
                    macroTorch.itemLoadingTable[targetSlot] = {
                        useableItem = useableItem,
                        useableItemUsed = false
                    }
                    if saying and not macroTorch.isNumber(saying) then
                        macroTorch.itemLoadingTable[targetSlot].saying = saying
                    end
                    macroTorch.show("Useable item loaded to slot " .. targetSlot .. ": " .. useableItem)
                    return true
                end

                -- The off-hand equip was refused. Only the 17-slot case with a
                -- really occupied main hand can be repaired here; any other
                -- refusal (wrong item type, empty main hand) just fails.
                if not mainHandItem or targetSlot ~= 17 then
                    macroTorch.show("Useable item load failed to slot " .. targetSlot .. ": " .. useableItem)
                    return false
                end

                -- Unequip the two-hander into an empty bag slot (rollback-safe)
                -- and record it as the restore target for the main hand
                if not obj.unequipToBagVerified(mainHandItem, 16) then
                    macroTorch.show("Useable item load failed to slot " .. targetSlot .. ": " .. useableItem)
                    return false
                end
                if not macroTorch.itemLoadingTable then
                    macroTorch.itemLoadingTable = {}
                end
                macroTorch.itemLoadingTable[targetSlot] = {
                    mainHandItem = mainHandItem,
                    pendingEquip = useableItem,
                    pendingSaying = saying
                }

                -- Final equip + verify; on failure the pending entry stays so
                -- the next press resumes without re-unequipping anything
                obj.equipItem(useableItem, targetSlot)
                if obj.isItemNameInSlot(targetSlot, useableItem) then
                    macroTorch.itemLoadingTable[targetSlot].useableItem = useableItem
                    macroTorch.itemLoadingTable[targetSlot].useableItemUsed = false
                    if saying and not macroTorch.isNumber(saying) then
                        macroTorch.itemLoadingTable[targetSlot].saying = saying
                    end
                    macroTorch.itemLoadingTable[targetSlot].pendingEquip = nil
                    macroTorch.itemLoadingTable[targetSlot].pendingSaying = nil
                    macroTorch.show("Useable item loaded to slot " .. targetSlot .. ": " .. useableItem)
                    return true
                end
                macroTorch.show("Useable item load failed to slot " .. targetSlot .. ": " .. useableItem .. " (two-hand weapon unequipped, retry next press)")
                return false
            end
        end
        return false
    end

    -- load pet/useable item to action bar slot for later casting via castLoadedItem
    function obj.pokemonLoad()
        local battleChickenSaying = 'Go, Battle Chicken! I choose you!'
        local arcaniteDragonlingSaying = 'Come on out, Arcanite Dragonling!'
        local onyxianEggSaying = 'Go, Onyxian Broodling! I choose you!'
        local barovServantsSaying = 'Go, Barov Servants! I choose you!'
        local skeletonSaying = 'Come on out, Skeleton!'
        local mechanicalYetiSaying = 'Go, Mechanical Yeti! I choose you!'
        local decoyDragonlingSaying = 'Come on out, Decoy Dragonling!'

        local orderedTable = {
            keys = {
                battleChickenSaying,
                arcaniteDragonlingSaying,
                onyxianEggSaying,
                barovServantsSaying,
                skeletonSaying,
                mechanicalYetiSaying,
                decoyDragonlingSaying
            },
            values = {
                [battleChickenSaying] = 'Gnomish Battle Chicken',
                [arcaniteDragonlingSaying] = 'Arcanite Dragonling',
                [onyxianEggSaying] = 'Onyxian Brood Egg',
                [barovServantsSaying] = 'Barov Peasant Caller',
                [skeletonSaying] = 'Ancient Cornerstone Grimoire',
                [mechanicalYetiSaying] = 'Mechanical Yeti',
                [decoyDragonlingSaying] = 'Decoy Dragonling Remote'
            },
            toSlots = {
                [battleChickenSaying] = 13,
                [arcaniteDragonlingSaying] = 13,
                [onyxianEggSaying] = 13,
                [barovServantsSaying] = 13,
                [skeletonSaying] = 17,
                [mechanicalYetiSaying] = 13,
                [decoyDragonlingSaying] = 17
            }
        }
        obj.loadUseableItemToSlot(orderedTable)
    end

    -- use loaded useable item and swap it back to the original one
    function obj.castLoadedItem()
        if not macroTorch.itemLoadingTable then
            return
        end
        for swappingSlot, loadingTable in pairs(macroTorch.itemLoadingTable) do
            if swappingSlot and loadingTable and loadingTable.useableItem then
                if obj.isItemEquipped(loadingTable.useableItem) then
                    if loadingTable.useableItemUsed == false then
                        -- Release press 1: use the item + say the saying. Usable
                        -- items stay usable in combat, so this arm is not
                        -- paused; only the restore arm below is combat-paused.
                        if obj.isEquippedItemCooledDown(loadingTable.useableItem) then
                            obj.useEquippedItem(loadingTable.useableItem)
                            macroTorch.show("Useable item casted: " .. loadingTable.useableItem)
                            if loadingTable.saying then
                                obj.say(loadingTable.saying)
                            end
                            loadingTable.useableItemUsed = true
                            return
                        end
                        macroTorch.show("Useable item is in CD, restoring: " .. loadingTable.useableItem)
                        -- On cooldown the use is skipped; the same press restores the original equipment
                        loadingTable.useableItemUsed = true
                    end
                    if loadingTable.useableItemUsed then
                        -- Restore arm: press 2, or the same press after a CD skip, restores the original equipment.
                        -- Combat pause: protected equip actions are
                        -- client-refused in combat; press again after combat,
                        -- state is kept.
                        if UnitAffectingCombat("player") then
                            return
                        end
                        if loadingTable.swappingItem then
                            -- Swap path reversed: equip the displaced off-hand
                            -- back to its slot; the client swaps the pokemon
                            -- back into the bag. Idempotent: an already
                            -- restored state clears immediately.
                            if obj.isItemNameInSlot(swappingSlot, loadingTable.swappingItem)
                                    and not obj.isItemNameInSlot(swappingSlot, loadingTable.useableItem) then
                                macroTorch.show("Original item restored: " .. loadingTable.swappingItem)
                                macroTorch.itemLoadingTable[swappingSlot] = nil
                                return
                            end
                            obj.equipItem(loadingTable.swappingItem, swappingSlot)
                            if obj.isItemNameInSlot(swappingSlot, loadingTable.swappingItem)
                                    and not obj.isItemNameInSlot(swappingSlot, loadingTable.useableItem) then
                                macroTorch.show("Original item restored: " .. loadingTable.swappingItem)
                                macroTorch.itemLoadingTable[swappingSlot] = nil
                                return
                            end
                            macroTorch.show("Original item restore failed: " .. loadingTable.swappingItem)
                            return
                        elseif loadingTable.mainHandItem then
                            -- Unequipped two-hander path: equip it back to main
                            -- hand (16) in one step; the client auto-returns
                            -- the off-hand pokemon to the bag. Idempotent
                            -- clear on re-press.
                            if obj.isItemNameInSlot(16, loadingTable.mainHandItem)
                                    and not obj.isItemNameInSlot(swappingSlot, loadingTable.useableItem) then
                                macroTorch.show("Main hand weapon restored: " .. loadingTable.mainHandItem)
                                macroTorch.itemLoadingTable[swappingSlot] = nil
                                return
                            end
                            obj.equipItem(loadingTable.mainHandItem, 16)
                            if obj.isItemNameInSlot(16, loadingTable.mainHandItem)
                                    and not obj.isItemNameInSlot(swappingSlot, loadingTable.useableItem) then
                                macroTorch.show("Main hand weapon restored: " .. loadingTable.mainHandItem)
                                macroTorch.itemLoadingTable[swappingSlot] = nil
                                return
                            end
                            macroTorch.show("Main hand weapon restore failed: " .. loadingTable.mainHandItem)
                            return
                        else
                            -- Nothing was displaced during load: just unequip
                            -- the pokemon from its slot into the bag
                            if not obj.isItemNameInSlot(swappingSlot, loadingTable.useableItem) then
                                macroTorch.show("Useable item removed from slot " .. swappingSlot)
                                macroTorch.itemLoadingTable[swappingSlot] = nil
                                return
                            end
                            if obj.unequipToBagVerified(loadingTable.useableItem, swappingSlot) then
                                macroTorch.show("Useable item removed from slot " .. swappingSlot)
                                macroTorch.itemLoadingTable[swappingSlot] = nil
                                return
                            end
                            macroTorch.show("Useable item remove failed from slot " .. swappingSlot)
                            return
                        end
                    end
                    return
                else
                    -- sth got wrong, just reset (the item is no longer equipped)
                    macroTorch.itemLoadingTable[swappingSlot] = nil
                end
            end
        end
    end

    function obj.say(text)
        if text then
            SendChatMessage(text)
        end
    end

    setmetatable(obj, macroTorch.classMetatable(self, "PLAYER_FIELD_FUNC_MAP"))

    return obj
end

-- player fields to function mapping
macroTorch.PLAYER_FIELD_FUNC_MAP = {
    -- basic props
    ['threatPercent'] = function(self)
        local TWT = macroTorch.TWT
        local p = 0
        if TWT and TWT.threats and TWT.threats[TWT.name] then
            p = TWT.threats[TWT.name].perc or 0
        end
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
        local numSlots = GetContainerNumSlots(b)
        for s = 1, numSlots do
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

--- 开启自动近战攻击, 这需要"攻击"技能被放在任意一个技能栏格子里
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

--- 开启自动射击, 这需要"射击"技能被放在任意一个技能栏格子里
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