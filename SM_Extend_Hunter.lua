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

    ---如果是法系玩家目标，上吸蓝钉刺 TODO

    ---如果是非法系的玩家目标，上减力减敏钉刺 TODO

    ---其它毒蛇钉刺有效目标，上毒蛇钉刺
    local targetType = UnitCreatureType(t)
    if not string.find(targetType, '元素生物') then
        castIfBuffAbsent(t, '毒蛇钉刺', 'Hunter_Quickshot')
    end
end
function MeleeSeq()
    if HasPetUI() and not UnitIsDead('pet') then
        PetAttack()
    end
    startAutoAtk()
    if not isBuffOrDebuffPresent('target', 'Rogue_Trip') then
        CastSpellByName('摔绊')
    end
    CastSpellByName('猛禽一击')
end
function RangedSeq()
    if HasPetUI() and not UnitIsDead('pet') then
        PetAttack()
    end
    local t = 'target'
    castIfBuffAbsent(t, '猎人印记', 'Hunter_SniperShot')
    startAutoShoot()
    hunterStings()
    CastSpellByName('奥术射击')
end
function hunterAtk()
    local t = 'target'
    if isTargetValidCanAttack(t) then
        if CheckInteractDistance(t, 3) then
            MeleeSeq()
        else
            RangedSeq()
        end
    else
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and isTargetValidCanAttack(pt) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if isTargetValidCanAttack(t) then
            if CheckInteractDistance(t, 3) then
                MeleeSeq()
            else
                RangedSeq()
            end
        end
    end
end
