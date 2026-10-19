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

    -- Load the next useable item from the table into its target equipment slot,
    -- with an automatic snapshot of whatever the load displaces:
    --   * target slot occupied -> the displaced item name is recorded (swap path)
    --     so the restore press can put it back to the same slot;
    --   * target slot empty (off-hand) -> the main hand (16) is snapshotted, then
    --     the item is equipped. A deferred (next-frame) refusal - the item back
    --     in the bag while a two-hander still occupies the main hand - moves the
    --     two-hander into an empty bag slot (recorded) and retries the equip.
    -- All equip/unequip actions run through the frame-split queue
    -- (macroTorch.pokemonEquipQueue, pumped by the periodic task
    -- 'pokemonPipelineTick'): ONE cursor op per tick, verification on the tick
    -- AFTER the action. Live forensics (2026-10-19) pinned three client facts:
    --   * an equip into an EMPTY slot lands but GetInventoryItemLink does not
    --     show it on the same frame - same-frame verification is unusable;
    --   * same-frame multi-op cursor chains keep only their first op: later
    --     PickupContainerItem / EquipCursorItem calls get dropped and the item
    --     strands on the cursor;
    --   * therefore every equip judgement below reads the slot link one tick
    --     after the equip action, and no tick issues more than one cursor op.
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

        -- Resume arm pre-scan: a previous press left a pending entry (equip
        -- enqueued but not yet verified). Finish it before any fresh load
        -- attempt so it can never be shadowed by another loadable item in the
        -- ordered table. Everything below enqueues the frame-split sequence;
        -- the pump completes it over the following ticks with no extra
        -- keypresses.
        if macroTorch.itemLoadingTable then
            for slot, pendingTable in pairs(macroTorch.itemLoadingTable) do
                if slot and pendingTable and pendingTable.pendingEquip and not pendingTable.useableItem then
                    macroTorch.pokemonEnqueue({ t = 'pickupBag', itemName = pendingTable.pendingEquip, targetSlot = slot })
                    macroTorch.pokemonEnqueue({ t = 'equipCursor', slot = slot })
                    macroTorch.pokemonEnqueue({ t = 'verifyEquipLoad', itemName = pendingTable.pendingEquip, targetSlot = slot, saying = pendingTable.pendingSaying })
                    return true
                end
            end
        end

        -- Global lock: at most one loaded item at a time. The state table only
        -- holds verified loads, so any entry carrying a useableItem - used or
        -- not - is a live load; it blocks new loads until the restore arm clears the entry.
        if macroTorch.itemLoadingTable then
            for _, loadingTable in pairs(macroTorch.itemLoadingTable) do
                if loadingTable.useableItem then
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
                    -- press can put it back to the same slot. The state entry
                    -- is written now (in-flight shape); the deferred verify
                    -- promotes it or keeps it pending for the next press.
                    if not macroTorch.itemLoadingTable then
                        macroTorch.itemLoadingTable = {}
                    end
                    macroTorch.itemLoadingTable[targetSlot] = {
                        swappingItem = macroTorch.getItemNameFromLink(currentSlotLink),
                        pendingEquip = useableItem,
                        pendingSaying = saying
                    }
                    macroTorch.pokemonEnqueue({ t = 'pickupBag', itemName = useableItem, targetSlot = targetSlot })
                    macroTorch.pokemonEnqueue({ t = 'equipCursor', slot = targetSlot })
                    macroTorch.pokemonEnqueue({ t = 'verifyEquipLoad', itemName = useableItem, targetSlot = targetSlot, saying = saying })
                    return true
                end

                -- Target slot empty: snapshot the main hand name. The deferred
                -- verify carries the snapshot; only a confirmed refusal (the
                -- item back in the bag) then moves the two-hander out of 16.
                local mainHandLink = macroTorch.getEquippedItemLink(16)
                local mainHandItem = nil
                if mainHandLink then
                    mainHandItem = macroTorch.getItemNameFromLink(mainHandLink)
                end
                if not macroTorch.itemLoadingTable then
                    macroTorch.itemLoadingTable = {}
                end
                macroTorch.itemLoadingTable[targetSlot] = {
                    pendingEquip = useableItem,
                    pendingSaying = saying
                }
                macroTorch.pokemonEnqueue({ t = 'pickupBag', itemName = useableItem, targetSlot = targetSlot })
                macroTorch.pokemonEnqueue({ t = 'equipCursor', slot = targetSlot })
                macroTorch.pokemonEnqueue({ t = 'verifyEquipLoad', itemName = useableItem, targetSlot = targetSlot, saying = saying, repair = mainHandItem })
                return true
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
                        -- Restore arm: press 2, or the same press after a CD skip,
                        -- restores the original equipment. Combat pause: protected
                        -- equip actions are client-refused in combat; press again
                        -- after combat, state is kept. All three restore arms ride
                        -- the frame-split queue: one cursor op per tick, verify on
                        -- the tick after.
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
                            macroTorch.pokemonEnqueue({ t = 'pickupBag', itemName = loadingTable.swappingItem, targetSlot = swappingSlot })
                            macroTorch.pokemonEnqueue({ t = 'equipCursor', slot = swappingSlot })
                            macroTorch.pokemonEnqueue({ t = 'verifyEquipRestore', slot = swappingSlot, backItem = loadingTable.swappingItem, goneSlot = swappingSlot, goneItem = loadingTable.useableItem, okMsg = 'Original item restored: ' .. loadingTable.swappingItem, failMsg = 'Original item restore failed: ' .. loadingTable.swappingItem })
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
                            macroTorch.pokemonEnqueue({ t = 'pickupBag', itemName = loadingTable.mainHandItem, targetSlot = 16 })
                            macroTorch.pokemonEnqueue({ t = 'equipCursor', slot = 16 })
                            macroTorch.pokemonEnqueue({ t = 'verifyEquipRestore', slot = 16, backItem = loadingTable.mainHandItem, goneSlot = swappingSlot, goneItem = loadingTable.useableItem, okMsg = 'Main hand weapon restored: ' .. loadingTable.mainHandItem, failMsg = 'Main hand weapon restore failed: ' .. loadingTable.mainHandItem })
                            return
                        else
                            -- Nothing was displaced during load: just unequip
                            -- the pokemon from its slot into the bag
                            if not obj.isItemNameInSlot(swappingSlot, loadingTable.useableItem) then
                                macroTorch.show("Useable item removed from slot " .. swappingSlot)
                                macroTorch.itemLoadingTable[swappingSlot] = nil
                                return
                            end
                            macroTorch.pokemonEnqueue({ t = 'pickupInventory', slot = swappingSlot, itemName = loadingTable.useableItem })
                            macroTorch.pokemonEnqueue({ t = 'verifySlotEmpty', slot = swappingSlot, itemName = loadingTable.useableItem, mode = 'plain' })
                            return
                        end
                    end
                    return
                else
                    -- sth got wrong, just reset - only for verified entries.
                    -- An in-flight (pending) load is owned by the queue: its
                    -- equip has been enqueued but not verified yet, so the
                    -- entry still carries the swap/repair context
                    -- (swappingItem, or the mainHandItem handed over by a
                    -- deposit commit). Clearing it here would wipe that
                    -- context before the deferred verify can promote the
                    -- entry - the deferred verify will rebuild it over the
                    -- next ticks.
                    if not loadingTable.pendingEquip then
                        macroTorch.itemLoadingTable[swappingSlot] = nil
                    end
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

-- Frame-split pokemon load/restore queue (live forensics 2026-10-19). The
-- queue lives on macroTorch so it survives player-object recreation; it is
-- pumped by the periodic task registered below ('pokemonPipelineTick', 0.1s),
-- executing exactly ONE cursor op per tick and verifying on the tick after.
-- When the player enters combat mid-sequence the pump pauses (steps are kept)
-- and resumes after combat; the load and restore keypresses enqueue only out
-- of combat. Step types:
--   pickupBag          PickupContainerItem (lift the named bag item)
--   pickupInventory    PickupInventoryItem  (lift from an equipment slot)
--   equipCursor / rollbackCursor
--                      EquipCursorItem      (place / return the cursor item)
--   verifySlotEmpty    read-only, the tick after the pickup
--   verifyEquipLoad    read-only, the tick after the equip; promotes the
--                      pending load, or fires the two-hander repair arm on a
--                      confirmed refusal
--   verifyDepositUnequip / verifyDepositPlain
--                      read-only, the tick after the bag deposit
--   verifyEquipRestore read-only, the tick after a restore equip
--   verifyRollback     read-only, the tick after a rollback
function macroTorch.pokemonQueueEnsure()
    if not macroTorch.pokemonEquipQueue then
        macroTorch.pokemonEquipQueue = {}
    end
    return macroTorch.pokemonEquipQueue
end

function macroTorch.pokemonEnqueue(step)
    table.insert(macroTorch.pokemonQueueEnsure(), step)
end

-- One tick of the queue: exactly one cursor op per tick. Cheap-first gate:
-- an idle queue returns before any client API call, mirroring cpBuildDkiTick.
function macroTorch.pokemonPipelineTick()
    local queue = macroTorch.pokemonEquipQueue
    if not queue then
        return
    end
    if macroTorch.tableLen(queue) == 0 then
        return
    end
    if UnitAffectingCombat("player") then
        return
    end
    local step = table.remove(queue, 1)
    macroTorch.pokemonPipelineStep(step)
end

macroTorch.registerPeriodicTask('pokemonPipelineTick', { interval = 0.1, task = macroTorch.pokemonPipelineTick })

function macroTorch.pokemonPipelineStep(step)
    if not step then
        return
    end
    local t = step.t
    if t == 'pickupBag' then
        macroTorch.pokemonStepPickupBag(step)
    elseif t == 'pickupInventory' then
        macroTorch.pokemonStepPickupInventory(step)
    elseif t == 'equipCursor' then
        EquipCursorItem(step.slot)
    elseif t == 'verifyEquipLoad' then
        macroTorch.pokemonStepVerifyEquipLoad(step)
    elseif t == 'verifySlotEmpty' then
        macroTorch.pokemonStepVerifySlotEmpty(step)
    elseif t == 'depositCursor' then
        macroTorch.pokemonStepDepositCursor(step)
    elseif t == 'verifyDepositUnequip' then
        macroTorch.pokemonStepVerifyDepositUnequip(step)
    elseif t == 'verifyDepositPlain' then
        macroTorch.pokemonStepVerifyDepositPlain(step)
    elseif t == 'verifyEquipRestore' then
        macroTorch.pokemonStepVerifyEquipRestore(step)
    elseif t == 'rollbackCursor' then
        EquipCursorItem(step.slot)
    elseif t == 'verifyRollback' then
        macroTorch.pokemonStepVerifyRollback(step)
    else
        macroTorch.show('Unknown pokemon pipeline step: ' .. tostring(t))
    end
end

-- Lift the named bag item onto the cursor (one PickupContainerItem). A busy
-- cursor aborts the WHOLE 3-step chain: the paired equipCursor and verify*
-- are drained from the queue, because the unattended equipCursor would
-- otherwise equip the foreign cursor item into the target slot on the next
-- tick. A vanished item keeps the pair enqueued on purpose - the cursor is
-- empty so the equipCursor is a no-op, and the paired verify still
-- adjudicates that failure (literally-gone versus keep-for-next-press).
function macroTorch.pokemonStepPickupBag(step)
    if CursorHasItem() then
        macroTorch.show('Useable item load unconfirmed: cursor busy, retry next press')
        -- Abort the WHOLE chain: the paired equipCursor must never run
        -- against a foreign cursor item. Every 3-step chain in this file is
        -- enqueued atomically as pickupBag -> equipCursor -> verify*, so the
        -- remaining two steps of this chain sit at the queue head: drain
        -- both before returning (table.remove on index 1 twice shifts the
        -- array left twice, Lua 5.0 1-based list semantics).
        local q = macroTorch.pokemonQueueEnsure()
        table.remove(q, 1)  -- equipCursor of this chain
        table.remove(q, 1)  -- verify* of this chain
        return
    end
    local bagId, slotIndex = macroTorch.getItemBagIdAndSlot(step.itemName)
    if not bagId or not slotIndex then
        macroTorch.show('Useable item load failed: ' .. step.itemName .. ' not in bags')
        return
    end
    PickupContainerItem(bagId, slotIndex)
end

-- Lift the item out of an equipment slot onto the cursor (one
-- PickupInventoryItem), only when the cursor is free and the slot still
-- holds the expected name. Every pickupInventory chain in this file is the
-- 2-step pair pickupInventory -> verifySlotEmpty; either abort here drains
-- that one remaining verify from the queue head so an aborted sequence ends
-- instead of letting the paired verify act on the wrong cursor contents.
function macroTorch.pokemonStepPickupInventory(step)
    if CursorHasItem() then
        macroTorch.show('Useable item load unconfirmed: cursor busy, retry next press')
        local q = macroTorch.pokemonQueueEnsure()
        table.remove(q, 1)  -- verifySlotEmpty of this chain
        return
    end
    if not macroTorch.player.isItemNameInSlot(step.slot, step.itemName) then
        macroTorch.show('Useable item load unconfirmed: slot ' .. step.slot .. ' no longer holds ' .. step.itemName)
        local q = macroTorch.pokemonQueueEnsure()
        table.remove(q, 1)  -- verifySlotEmpty of this chain
        return
    end
    PickupInventoryItem(step.slot)
end

-- Tick after the pickup: read-only. Cursor ops mutate the local model
-- immediately, while the slot link can lag (E1-class latency; the removal
-- direction was never forensically pinned). With the pickupInventory cursor
-- guard above, a busy cursor here IS the lifted item - proceed to the
-- deposit. Stop the chain only when the cursor is empty AND the slot link
-- still shows the item.
function macroTorch.pokemonStepVerifySlotEmpty(step)
    if not CursorHasItem() and macroTorch.player.isItemNameInSlot(step.slot, step.itemName) then
        macroTorch.show('Useable item load unconfirmed: failed to lift ' .. step.itemName .. ' from slot ' .. step.slot)
        return
    end
    macroTorch.pokemonEnqueue({ t = 'depositCursor', fromSlot = step.slot, itemName = step.itemName, mode = step.mode,
        targetSlot = step.targetSlot, useableItem = step.useableItem, saying = step.saying })
end

-- Deposit the cursor item into the first empty bag slot (one
-- PickupContainerItem). No free slot (or nothing on the cursor) rolls back
-- into the original slot on the following ticks.
function macroTorch.pokemonStepDepositCursor(step)
    if not CursorHasItem() then
        macroTorch.show('Useable item load unconfirmed: nothing on cursor')
        return
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
        macroTorch.pokemonEnqueue({ t = 'rollbackCursor', slot = step.fromSlot, itemName = step.itemName })
        macroTorch.pokemonEnqueue({ t = 'verifyRollback', slot = step.fromSlot, itemName = step.itemName, okMsg = 'Useable item load failed: no empty bag slot, rolled back into slot ' .. step.fromSlot, failMsg = 'Useable item load unconfirmed: rollback did not return the item to slot ' .. step.fromSlot })
        return
    end
    PickupContainerItem(depositBag, depositSlot)
    if step.mode == 'twohand' then
        macroTorch.pokemonEnqueue({ t = 'verifyDepositUnequip', fromSlot = step.fromSlot, itemName = step.itemName,
            targetSlot = step.targetSlot, useableItem = step.useableItem, saying = step.saying })
    else
        macroTorch.pokemonEnqueue({ t = 'verifyDepositPlain', slot = step.fromSlot, itemName = step.itemName })
    end
end

-- Tick after the two-hander deposit: read-only. Confirmed (cursor clean, slot
-- empty, item in a bag) commits the repair context and re-runs the pokemon
-- equip with a fresh deferred verify; any doubt keeps the pending entry and
-- rolls back the cursor item into its slot.
function macroTorch.pokemonStepVerifyDepositUnequip(step)
    if CursorHasItem() then
        macroTorch.pokemonEnqueue({ t = 'rollbackCursor', slot = step.fromSlot, itemName = step.itemName })
        macroTorch.pokemonEnqueue({ t = 'verifyRollback', slot = step.fromSlot, itemName = step.itemName, okMsg = 'Useable item load failed: two-handed weapon deposit dropped, rolled back into slot ' .. step.fromSlot, failMsg = 'Useable item load unconfirmed: rollback did not return the item to slot ' .. step.fromSlot })
        return
    end
    if macroTorch.player.isItemNameInSlot(step.fromSlot, step.itemName) or not macroTorch.isItemExist(step.itemName) then
        macroTorch.show('Useable item load unconfirmed: ' .. step.itemName .. ' is not in a bag')
        return
    end
    if macroTorch.itemLoadingTable and macroTorch.itemLoadingTable[step.targetSlot] then
        macroTorch.itemLoadingTable[step.targetSlot].mainHandItem = step.itemName
        macroTorch.itemLoadingTable[step.targetSlot].pendingEquip = step.useableItem
        macroTorch.itemLoadingTable[step.targetSlot].pendingSaying = step.saying
    end
    macroTorch.pokemonEnqueue({ t = 'pickupBag', itemName = step.useableItem, targetSlot = step.targetSlot })
    macroTorch.pokemonEnqueue({ t = 'equipCursor', slot = step.targetSlot })
    macroTorch.pokemonEnqueue({ t = 'verifyEquipLoad', itemName = step.useableItem, targetSlot = step.targetSlot, saying = step.saying })
end

-- Tick after a plain restore-unequip deposit: read-only. Success clears the
-- loading entry (pokemon back in a bag); doubt rolls back and keeps it.
function macroTorch.pokemonStepVerifyDepositPlain(step)
    if CursorHasItem() then
        macroTorch.pokemonEnqueue({ t = 'rollbackCursor', slot = step.slot, itemName = step.itemName })
        macroTorch.pokemonEnqueue({ t = 'verifyRollback', slot = step.slot, itemName = step.itemName, okMsg = 'Useable item remove failed: deposit dropped, rolled back into slot ' .. step.slot, failMsg = 'Useable item remove unconfirmed: rollback did not return the item to slot ' .. step.slot })
        return
    end
    if macroTorch.player.isItemNameInSlot(step.slot, step.itemName) or not macroTorch.isItemExist(step.itemName) then
        macroTorch.show('Useable item remove unconfirmed from slot ' .. step.slot)
        return
    end
    if macroTorch.itemLoadingTable then
        macroTorch.itemLoadingTable[step.slot] = nil
    end
    macroTorch.show('Useable item removed from slot ' .. step.slot)
end

-- Tick after an equip action: read-only verify through the slot link. Success
-- promotes the pending load; the two-hander repair arm fires only on a
-- confirmed refusal (item back in the bag, slot 17, a non-empty main-hand
-- snapshot) and is the only path that ever touches slot 16. Any other
-- failure reports the unconfirmed state and keeps it for the next press.
function macroTorch.pokemonStepVerifyEquipLoad(step)
    local slot = step.targetSlot
    if macroTorch.player.isItemNameInSlot(slot, step.itemName) then
        local entry = macroTorch.itemLoadingTable and macroTorch.itemLoadingTable[slot]
        if not entry then
            if not macroTorch.itemLoadingTable then
                macroTorch.itemLoadingTable = {}
            end
            entry = {}
            macroTorch.itemLoadingTable[slot] = entry
        end
        entry.useableItem = step.itemName
        entry.useableItemUsed = false
        if step.saying and not macroTorch.isNumber(step.saying) then
            entry.saying = step.saying
        end
        entry.pendingEquip = nil
        entry.pendingSaying = nil
        macroTorch.show('Useable item loaded to slot ' .. slot .. ': ' .. step.itemName)
        return
    end
    if step.repair and slot == 17 and macroTorch.isItemExist(step.itemName) then
        -- First doubt is not a confirmed refusal: the equip link of an empty
        -- slot can lag for 1-2 seconds (E1). Re-run this same verify every
        -- tick for up to that window; a refreshed link promotes the load
        -- early (first check above), and only a link that still misses after
        -- ~2 s while the item sits back in the bags is a real refusal.
        -- 20 ticks at the registered 0.1 s interval cover the full E1 lag.
        step.wait = step.wait or 20
        step.wait = step.wait - 1
        if step.wait > 0 then
            macroTorch.pokemonEnqueue(step)
            return
        end
        macroTorch.pokemonEnqueue({ t = 'pickupInventory', slot = 16, itemName = step.repair })
        macroTorch.pokemonEnqueue({ t = 'verifySlotEmpty', slot = 16, itemName = step.repair, mode = 'twohand',
            targetSlot = slot, useableItem = step.itemName, saying = step.saying })
        macroTorch.show('Useable item load refused: moving the two-handed weapon out of the main hand, retrying')
        return
    end
    macroTorch.show('Useable item load failed to slot ' .. slot .. ': ' .. step.itemName .. ' (unconfirmed, retry next press)')
end

-- Tick after a restore equip: read-only. Both target conditions met clears
-- the loading entry; otherwise the entry is kept for the next press.
function macroTorch.pokemonStepVerifyEquipRestore(step)
    if macroTorch.player.isItemNameInSlot(step.slot, step.backItem)
            and not macroTorch.player.isItemNameInSlot(step.goneSlot, step.goneItem) then
        if macroTorch.itemLoadingTable then
            macroTorch.itemLoadingTable[step.goneSlot] = nil
        end
        macroTorch.show(step.okMsg)
        return
    end
    macroTorch.show(step.failMsg)
end

-- Tick after a rollback equip: read-only; both outcomes keep the state for
-- idempotent re-press convergence, only the message differs.
function macroTorch.pokemonStepVerifyRollback(step)
    if macroTorch.player.isItemNameInSlot(step.slot, step.itemName) then
        macroTorch.show(step.okMsg)
    else
        macroTorch.show(step.failMsg)
    end
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