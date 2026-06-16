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
