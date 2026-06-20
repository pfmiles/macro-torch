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

-- 猫德练级路由：按等级分派到对应的练级函数
-- 随着升级逐步添加新等级段的函数，最终 60 级时由 druidAtk 路由到 catAtk
function macroTorch.catLeveling()
    local level = macroTorch.player.level

    if level < 24 then
        -- Rake 24级可学，在此之前只有 Claw + Rip
        macroTorch.cat_lv20()
    -- elseif level < 34 then
    --     macroTorch.cat_lv30()
    -- elseif level < 44 then
    --     macroTorch.cat_lv40()
    -- elseif level < 54 then
    --     macroTorch.cat_lv50()
    -- else
    --     54-59 级待添加
    end
end

-- 低等级练级宏（Claw + Rip，适用于未学 Rake 的阶段）
-- 逻辑：有星且目标无Rip → 挂Rip，否则 Claw
function macroTorch.cat_lv20()
    if not macroTorch.player.isInCatForm then
        return
    end

    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        return
    end

    macroTorch.player.startAutoAtk()

    if macroTorch.player.comboPoints > 0
            and macroTorch.isSpellExist('Rip', 'spell')
            and not macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_GhoulFrenzy')) then
        macroTorch.player.rip()
    else
        macroTorch.player.claw()
    end
end