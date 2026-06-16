-- Druid utility functions (extracted from SM_Extend_Druid.lua)
function macroTorch.druidBuffs()
    if not macroTorch.player.buffed('Mark of the Wild') then
        macroTorch.player.mark_of_the_wild(nil, true)
    end
    if not macroTorch.player.buffed('Thorns') then
        macroTorch.player.thorns(nil, true)
    end
    if not macroTorch.player.buffed('Nature\'s Grasp') then
        macroTorch.player.natures_grasp()
    end
end
function macroTorch.druidStun()
    local clickContext = {}
    local inBearForm = macroTorch.player.isInBearForm
    -- if in melee range then use bear bash else bear charge
    -- if not in bear form, be bear first
    if not inBearForm then
        macroTorch.player.dire_bear_form()
    end
    -- reshift to restore when rage is 0
    if inBearForm and macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Reshift') then
        macroTorch.player.reshift()
    end
    if macroTorch.isNearBy(clickContext) then
        macroTorch.player.bash()
    else
        if macroTorch.isSpellExist('Feral Charge', 'spell') then
            macroTorch.player.feral_charge()
        end
    end
end
function macroTorch.druidDefend()
    -- [Barkskin (Feral)][Frenzied Regeneration]
    if macroTorch.player.isSpellReady('Barkskin (Feral)') then
        macroTorch.player.barkskin('raw')
    end
    if macroTorch.player.isSpellReady('Frenzied Regeneration') then
        local inBearForm = macroTorch.player.isInBearForm
        if not inBearForm then
            macroTorch.player.dire_bear_form()
        end
        if inBearForm and macroTorch.player.mana == 0 and macroTorch.player.isSpellReady('Enrage') then
            macroTorch.player.enrage()
        end
        macroTorch.player.frenzied_regeneration()
    end
end
function macroTorch.druidControl()
    -- if target is of type beast or dragonkin, use Hibernate, else use [Entangling Roots]
    if macroTorch.target.type == 'Beast' or macroTorch.target.type == 'Dragonkin' then
        macroTorch.player.hibernate('safe')
    else
        macroTorch.player.entangling_roots('safe')
    end
end
