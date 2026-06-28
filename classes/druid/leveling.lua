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

-- 猫德练级宏：独立于 catAtk 的一键宏实现，为练级中的猫德角色提供简化的战斗循环
-- 设计原则：
--   1. 不接受 rough 参数 — 所有战斗按正常模式处理，isTrivialBattleOrPvp 自动判断快速战斗
--   2. 不计算 ERPS — 练级期间无 reshift，ERPS 仅服务于 reshift 决策和能量泄放逻辑
--   3. 不调用 idol/relic 函数 — WoW Classic 猫德神像均为 55-60 级 endgame 掉落
--   4. 内联简化版 Shred vs Claw 和 FF 穿插逻辑（不调用 shouldUseShred/shouldCastFFDuringWaitWindow）
function macroTorch.catLeveling()
    -- 形态守卫：非猫形态不执行
    if not macroTorch.player.isInCatForm then
        return
    end

    -- 目标守卫：目标不可攻击时切换目标
    if not macroTorch.target.isCanAttack then
        macroTorch.player.targetEnemy()
        return
    end

    -- 简化 clickContext：仅包含必要字段，无 rough/ERPS/reshift/relic
    local clickContext = {}

    -- 能量消耗
    clickContext.POUNCE_E = 50
    clickContext.CLAW_E = macroTorch.computeClaw_E()
    clickContext.SHRED_E = macroTorch.computeShred_E()
    clickContext.RAKE_E = macroTorch.computeRake_E()
    clickContext.BITE_E = 35
    clickContext.RIP_E = 30
    clickContext.TIGER_E = macroTorch.computeTiger_E()

    -- 持续时间
    clickContext.TIGER_DURATION = macroTorch.computeTiger_Duration()

    local player = macroTorch.player
    local target = macroTorch.target

    -- 状态快照
    clickContext.prowling = player.isProwling
    clickContext.comboPoints = player.comboPoints
    clickContext.ooc = player.isOoc
    clickContext.isBehind = target.isCanAttack and player.isBehindTarget

    -- 免疫标记
    clickContext.isImmuneRake = target.isImmune('Rake')
    clickContext.isImmuneRip = target.isImmune('Rip')

    -- ============================================================
    -- 模块1: 起手技模块 (Opener)
    -- 潜行 + 近战距离（≤3码）下选择 Pounce 或 Ravage
    -- Fallback：Pounce 和 Ravage 都没学时，用 Shred（背后）或 Claw（正面）打破潜行
    -- 非近战距离时跳过起手技，允许 Module 4 TF 在接近目标途中提前释放
    -- ============================================================
    if clickContext.prowling and macroTorch.isNearBy(clickContext) then
        local hasPounce = macroTorch.isSpellExist('Pounce', 'spell')
        local hasRavage = macroTorch.isSpellExist('Ravage', 'spell')
        if hasPounce
                and not target.isImmune('Pounce')
                and target.health >= macroTorch.getOpenerHealthThreshold()
                and not macroTorch.isTrivialBattleOrPvp(clickContext) then
            player.pounce()
            return
        elseif hasRavage then
            player.ravage('ready')
            return
        else
            -- 既没学 Pounce 也没学 Ravage：用普通技能打破潜行起手
            -- 'ready' 模式跳过能量检查，确保能成功起手
            if macroTorch.isSpellExist('Shred', 'spell') and clickContext.isBehind then
                player.shred('ready')
                return
            elseif macroTorch.isSpellExist('Claw', 'spell') then
                player.claw('ready')
                return
            end
        end
    end

    -- ============================================================
    -- 模块2: 自动攻击
    -- 战斗中（非潜行）保持自动攻击
    -- ============================================================
    if player.isInCombat then
        player.startAutoAtk()
    end

    -- ============================================================
    -- 模块3: 斩杀优先模块 (Kill Shot)
    -- 最高优先级：isKillShotOrLastChance 为 true 时，任意连击点直接斩杀
    -- ============================================================
    if macroTorch.isSpellExist('Ferocious Bite', 'spell')
            and clickContext.comboPoints > 0
            and macroTorch.isKillShotOrLastChance(clickContext) then
        player.ferocious_bite('raw')
        return
    end

    -- ============================================================
    -- 模块4: 猛虎之怒模块 (Tiger's Fury)
    -- TF 必须最先挂上，其回能效果影响后续所有决策
    -- ============================================================
    if macroTorch.isSpellExist("Tiger's Fury", 'spell')
            and not macroTorch.isTigerPresent(clickContext)
            and target.distance <= 20
            and macroTorch.tigerSelfGCD(clickContext) == 0
            and player.mana >= clickContext.TIGER_E then
        player.tiger_fury('ready')
        if not macroTorch.loginContext then
            macroTorch.loginContext = {}
        end
        macroTorch.loginContext.tigerTimer = GetTime()
        return
    end

    -- ============================================================
    -- 模块5: Rip 模块
    -- 5星 Rip 维持（正常战斗），快速战斗低星 Rip
    -- OOC 时使用 'ready' 模式跳过能量检查，避免 safe 模式的资源检查导致卡技能
    -- ============================================================
    if macroTorch.isSpellExist('Rip', 'spell')
            and macroTorch.shouldCastRip(clickContext)
            and macroTorch.isGcdOk(clickContext)
            and macroTorch.isNearBy(clickContext) then
        if clickContext.ooc then
            player.rip('ready')
        else
            player.rip()
        end
        -- 记录本次 Rip 的连击点数，ripLeft 依赖此值计算正确时长
        -- 5星 Rip = 18s (10 + 4*2)，未设置时默认按 1 星 10s 计算
        macroTorch.context.lastRipAtCp = clickContext.comboPoints
        return
    end

    -- ============================================================
    -- 模块6: Rake 模块
    -- 维持 Rake 流血 debuff，仅在连击点 < 5 时施放（5星时优先消耗连击点）
    -- OOC 时使用 'ready' 模式跳过能量检查，避免 safe 模式的资源检查导致卡技能
    -- ============================================================
    if macroTorch.isSpellExist('Rake', 'spell')
            and not macroTorch.isRakePresent(clickContext)
            and not clickContext.isImmuneRake
            and macroTorch.isGcdOk(clickContext)
            and macroTorch.isNearBy(clickContext)
            and clickContext.comboPoints < 5 then
        if clickContext.ooc then
            player.rake('ready')
        else
            player.rake()
        end
        return
    end

    -- ============================================================
    -- 模块7: Bite 终结技模块 (Ferocious Bite)
    -- OOC 触发时任意 CP 直接 Bite；非 OOC 时按 shouldUseBite 判定
    -- ============================================================
    if macroTorch.isSpellExist('Ferocious Bite', 'spell') then
        if clickContext.ooc and clickContext.comboPoints > 0 then
            player.ferocious_bite('ready')
            return
        end
        if macroTorch.shouldUseBite(clickContext) and player.mana >= clickContext.BITE_E then
            player.ferocious_bite()
            return
        end
    end

    -- ============================================================
    -- 模块8: 攒星技模块 (Builder - 简化内联版)
    -- 战斗中 CP < 5 时，选择合适的攒星技能：Shred（背后）或 Claw（正面）
    -- 非 OOC 时仅在有足够能量时施放；OOC 时可无视能量消耗施放
    -- ============================================================
    if macroTorch.isFightStarted(clickContext) and clickContext.comboPoints < 5 then
        local hasShred = macroTorch.isSpellExist('Shred', 'spell')
        local hasClaw = macroTorch.isSpellExist('Claw', 'spell')

        if not clickContext.ooc then
            -- 普通情况：需要足够能量才能释放技能
            -- 优先 Shred（如果有 + 在背后 + 背后攻击未刚失败）
            if hasShred and clickContext.isBehind and not player.isBehindAttackJustFailed
                    and player.mana >= clickContext.SHRED_E then
                player.shred()
                return
            end

            -- 否则 Claw
            if hasClaw and player.mana >= clickContext.CLAW_E then
                player.claw()
                return
            end
        else
            -- OOC 触发：无视能量消耗，任意可用技能即可释放
            if hasShred and clickContext.isBehind and not player.isBehindAttackJustFailed then
                player.shred('ready')
                return
            end

            if hasClaw then
                player.claw('ready')
                return
            end
        end
    end

    -- ============================================================
    -- 模块9: 精灵之火(野性) — 见缝插针填充技 (Faerie Fire Feral)
    -- 非 OOC + 非免疫 → 作为兜底填充，不论目标是否已有 debuff
    -- FF 无能量消耗且可能触发 OOC，在所有高优先级模块无动作时插入
    -- ============================================================
    if macroTorch.isSpellExist('Faerie Fire (Feral)', 'spell')
            and not clickContext.ooc
            and not target.isImmune('Faerie Fire (Feral)')
            and player.isSpellReady('Faerie Fire (Feral)')
            and macroTorch.isGcdOk(clickContext) then
        player.faerie_fire_feral('raw')
        return
    end
end