-- Druid utility functions (extracted from SM_Extend_Druid.lua)
function macroTorch.druidBuffs()
    local clickContext = {}
    if not macroTorch.player.buffed('Mark of the Wild') then
        macroTorch.player.cast('Mark of the Wild', true)
    end
    if not macroTorch.player.buffed('Thorns') then
        macroTorch.player.cast('Thorns', true)
    end
    if not macroTorch.player.buffed('Nature\'s Grasp') then
        macroTorch.player.cast('Nature\'s Grasp', true)
    end
end
function macroTorch.druidStun()
    local clickContext = {}
    local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
    -- if in melee range then use bear bash else bear charge
    -- if not in bear form, be bear first
    if not inBearForm then
        macroTorch.player.cast('Dire Bear Form')
    end
    -- reshift to restore when rage is 0
    if inBearForm and macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Reshift') then
        macroTorch.player.cast('Reshift')
    end
    if macroTorch.isNearBy(clickContext) then
        macroTorch.player.cast('Bash')
    else
        if macroTorch.isSpellExist('Feral Charge', 'spell') then
            macroTorch.player.cast('Feral Charge')
        end
    end
end
function macroTorch.druidDefend()
    local clickContext = {}
    -- [Barkskin (Feral)][Frenzied Regeneration]
    if macroTorch.player.isSpellReady('Barkskin (Feral)') then
        macroTorch.player.cast('Barkskin (Feral)')
    end
    if macroTorch.player.isSpellReady('Frenzied Regeneration') then
        local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
        if not inBearForm then
            macroTorch.player.cast('Dire Bear Form')
        end
        if inBearForm and macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Enrage') then
            macroTorch.player.cast('Enrage')
        end
        macroTorch.player.cast('Frenzied Regeneration')
    end
end
function macroTorch.druidControl()
    local clickContext = {}
    -- if target is of type beast or dragonkin, use Hibernate, else use [Entangling Roots]
    if macroTorch.target.type == 'Beast' or macroTorch.target.type == 'Dragonkin' then
        macroTorch.player.cast('Hibernate')
    else
        macroTorch.player.cast('Entangling Roots')
    end
end
function macroTorch.pokemonLoad()
    local battleChickenSaying = 'Go, Battle Chicken! I choose you!'
    local arcaniteDragonlingSaying = 'Come on out, Arcanite Dragonling!'
    local trackingHoundSaying = 'Go, Tracking Hound! I choose you!'
    local barovServantsSaying = 'Go, Barov Servants! I choose you!'
    local skeletonSaying = 'Come on out, Skeleton!'

    local orderedTable = {
        keys = {
            battleChickenSaying,
            arcaniteDragonlingSaying,
            trackingHoundSaying,
            barovServantsSaying,
            skeletonSaying
        },
        values = {
            [battleChickenSaying] = 'Gnomish Battle Chicken',
            [arcaniteDragonlingSaying] = 'Arcanite Dragonling',
            [trackingHoundSaying] = 'Dog Whistle',
            [barovServantsSaying] = 'Barov Peasant Caller',
            [skeletonSaying] = 'Ancient Cornerstone Grimoire'
        },
        toSlots = {
            [battleChickenSaying] = 13,
            [arcaniteDragonlingSaying] = 13,
            [trackingHoundSaying] = 13,
            [barovServantsSaying] = 13,
            [skeletonSaying] = 17
        },
        backupItem = { [skeletonSaying] = { item = "Jadestone Skewer", slot = 16 } }
    }
    macroTorch.player.loadUseableItemToSlot(orderedTable)
end
