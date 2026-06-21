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

-- 猫德练级宏：根据等级自动选择最优输出逻辑
-- 内部通过 if-else 区分不同等级段，随着升级逐步解锁更多技能
-- 最终 60 级时由 druidAtk 路由到 catAtk
function macroTorch.catLeveling()
    if not macroTorch.player.isInCatForm then
        return
    end

    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        return
    end

    local level = macroTorch.player.level
    local player = macroTorch.player
    local target = macroTorch.target

    -- 潜行起手：优先使用技能（Pounce/Ravage）作为起手技，避免普攻破潜行
    if player.isProwling then
        local hasPounce = macroTorch.isSpellExist('Pounce', 'spell')
        local hasRavage = macroTorch.isSpellExist('Ravage', 'spell')
        if hasPounce and not target.isImmune('Pounce') and target.health >= macroTorch.getOpenerHealthThreshold() then
            player.pounce()
            return
        elseif hasRavage then
            player.ravage('ready')
            return
        end
    end

    -- 仅在进入战斗后才开启自动攻击，避免普攻作为起手技抢在技能之前打出
    if player.isInCombat then
        player.startAutoAtk()
    end

    -- ooc (Omen of Clarity): 触发清晰预兆时优先用 Claw（免费施放）
    if player.isOoc then
        player.claw('ready')
        return
    end

    -- 按等级区分输出逻辑
    if level < 24 then
        -- Rake 24级可学，在此之前只有 Claw + Rip
        if player.comboPoints > 0
                and macroTorch.isSpellExist('Rip', 'spell')
                and not macroTorch.toBoolean(target.hasBuff('Ability_GhoulFrenzy')) then
            player.rip()
        else
            player.claw()
        end
    -- elseif level < 34 then
    --     -- 未来扩展：Rake + Rip + Claw
    -- elseif level < 44 then
    --     -- 未来扩展：加入 Shred 支持
    -- elseif level < 54 then
    --     -- 未来扩展：加入 Tiger's Fury 等
    -- else
    --     -- 54-59 级待添加
    end
end