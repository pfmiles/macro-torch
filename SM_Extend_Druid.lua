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
---小德专用start---
--- 近战动作策略
function xdMeleeSeq()
    local t = 'target'
    local p = 'player'
    startAutoAtk()
    if isBuffOrDebuffPresent(p, 'Racial_BearForm') then
        --- 熊形态
        CastSpellByName(i18n('低吼'))
        castIfBuffAbsent(t, i18n('挫志咆哮'), 'Druid_DemoralizingRoar')
        CastSpellByName(i18n('槌击'))
    else
        --- 人形态
    end
end
--- 远程动作策略
function xdRangedSeq()
    local t = 'target'
    local p = 'player'
    startAutoAtk()
    if isBuffOrDebuffPresent(p, 'Racial_BearForm') then
        --- 熊形态
    else
        --- 人形态
        CastSpellByName(i18n('愤怒'))
    end
end
function xdAtk()
    local t = 'target'
    if isTargetValidCanAttack(t) then
        if CheckInteractDistance(t, 3) then
            xdMeleeSeq()
        else
            xdRangedSeq()
        end
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) then
            if CheckInteractDistance(t, 3) then
                xdMeleeSeq()
            else
                xdRangedSeq()
            end
        end
    end
end
--- 小德治疗序列
---@param onSelf boolean 是否对自己释放
function xdHealSeq(onSelf)
    local t
    if (onSelf) then
        t = 'player'
    else
        t = 'target'
    end
    if not isBuffOrDebuffPresent(t, 'Nature_ResistNature') then
        CastSpellByName(i18n('愈合'), onSelf)
    end
    CastSpellByName(i18n('治疗之触'), onSelf)
end
function xdHeal()
    if isTargetValidFriendly('target') then
        xdHealSeq(false)
    else
        xdHealSeq(true)
    end
end
