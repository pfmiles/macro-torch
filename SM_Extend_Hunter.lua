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
---猎人专用---
--- 钉刺逻辑
function hunterStings()
    local t = 'target'
    local isPlayerTarget = UnitIsPlayer(t)
    local isManaTarget = UnitPowerType(t) == 0

    if isPlayerTarget then
        if isManaTarget then
            ---如果是法系玩家目标，上吸蓝钉刺 TODO
            ---TODO 吸蓝sting
        else
            ---如果是非法系的玩家目标，上减力减敏钉刺 TODO
            CastSpellByName('毒蝎钉刺')
        end
    else
        ---其它毒蛇钉刺有效目标，上毒蛇钉刺
        local targetType = UnitCreatureType(t)
        if targetType and not string.find(targetType, '元素生物') and not string.find(targetType, '机械生物') and
            getUnitHealthPercent(t) > 50 then
            castIfBuffAbsent(t, '毒蛇钉刺', 'Hunter_Quickshot')
        end
    end
end
function MeleeSeq()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    startAutoAtk()
    if not isBuffOrDebuffPresent('target', 'Rogue_Trip') then
        CastSpellByName('摔绊')
    end
    CastSpellByName('猫鼬撕咬')
    CastSpellByName('猛禽一击')
end
function RangedSeq()
    if HasPetUI() and not UnitIsDead('pet') then
        PetDefensiveMode()
        PetAttack()
    end
    local t = 'target'
    castIfBuffAbsent(t, '猎人印记', 'Hunter_SniperShot')
    startAutoShoot()
    hunterStings()
    --CastSpellByName('Trueshot')
    Quiver.CastNoClip('Trueshot')
    --CastSpellByName('奥术射击')
    Quiver.CastNoClip('Arcane Shot')
end
--- hunter attack all in one
---@param pvp boolean whether or not attack player targets
function hunterAtk(pvp)
    local t = 'target'
    if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
        if CheckInteractDistance(t, 3) then
            MeleeSeq()
        else
            RangedSeq()
        end
    else
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and isTargetValidCanAttack(pt) and
            (pvp or not isPlayerOrPlayerControlled(pt)) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if isTargetValidCanAttack(t) and (pvp or not isPlayerOrPlayerControlled(t)) then
            if CheckInteractDistance(t, 3) then
                MeleeSeq()
            else
                RangedSeq()
            end
        end
    end
end

function changeStance()
    if isBuffOrDebuffPresent('player', 'Mount_JungleTiger') then
        local t = 'target'
        if isTargetValidCanAttack(t) then
            if CheckInteractDistance(t, 3) then
                CastSpellByName('灵猴守护')
            else
                CastSpellByName('雄鹰守护')
            end
        else
            CastSpellByName('灵猴守护')
        end
    else
        CastSpellByName('猎豹守护')
    end
end

--- 强制陷阱
---@param trap string
function forceTrap(trap)
    local p = 'player'
    if UnitAffectingCombat(p) then
        -- 宠物停止攻击
        if HasPetUI() and not UnitIsDead('pet') then
            PetPassiveMode()
            PetStopAttack()
            PetFollow()
        end
        -- 如果没有在假死状态，假死
        castIfBuffAbsent(p, '假死', 'Rogue_FeignDeath')
    end
    CastSpellByName(trap)
end

--- 控制序列
function hunterCtrl()
    castIfBuffAbsent('target', '震荡射击', 'Devour')
    CastSpellByName('Intimidation')
end
