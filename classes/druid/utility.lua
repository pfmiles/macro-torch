-- Druid utility functions (extracted from SM_Extend_Druid.lua)
function macroTorch.druidBuffs()
    if macroTorch.isSpellExist('Mark of the Wild', 'spell')
            and not macroTorch.player.buffed('Mark of the Wild')
            and macroTorch.player.isSpellReady('Mark of the Wild') then
        CastSpellByName('Mark of the Wild', true)
    end
    if macroTorch.isSpellExist('Thorns', 'spell')
            and not macroTorch.player.buffed('Thorns')
            and macroTorch.player.isSpellReady('Thorns') then
        CastSpellByName('Thorns', true)
    end
    if macroTorch.isSpellExist("Nature's Grasp", 'spell')
            and not macroTorch.player.buffed("Nature's Grasp") then
        macroTorch.player.natures_grasp('ready')
    end
end
