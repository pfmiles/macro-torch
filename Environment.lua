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

macroTorch.env = {}

macroTorch.context = {}

--- all events handle globally
function macroTorch.eventHandle(event)
    if event == 'PLAYER_REGEN_ENABLED' then
        -- combat exiting
        if macroTorch.context then
            macroTorch.inCombat = false

            macroTorch.context.rakeTimer = nil
            macroTorch.context.ripTimer = nil
            macroTorch.context.ffTimer = nil
            macroTorch.context.pounceTimer = nil
            macroTorch.context.targetHealthVector = nil
        end
        macroTorch.show('macroTorch.context.rake/rip/ff/pounceTimer/THV cleared due to combat exiting!')
    elseif event == 'PLAYER_TARGET_CHANGED' then
        -- target changed
        if macroTorch.player.isInCombat and macroTorch.target.isCanAttack then
            if macroTorch.context then
                macroTorch.context.rakeTimer = nil
                macroTorch.context.ripTimer = nil
                macroTorch.context.ffTimer = nil
                macroTorch.context.pounceTimer = nil
                macroTorch.context.targetHealthVector = nil
            end
            macroTorch.show('macroTorch.context.rake/rip/ff/pounceTimer/THV cleared due to target change in combat!')
        end
    elseif event == 'PLAYER_REGEN_DISABLED' then
        -- combat entering
        if not macroTorch.context then
            macroTorch.context = {}
        end
        macroTorch.inCombat = true
        macroTorch.show('Entering combat!')
    elseif event == "UI_ERROR_MESSAGE" then
        -- on ui error message
        if not macroTorch.context then
            macroTorch.context = {}
        end
        -- arg1 is a global var be set automatically, see https://wow.gamepedia.com/UI_ERROR_MESSAGE
        -- SPELL_FAILED_NOT_BEHIND is a global constant, see https://wow.gamepedia.com/Constants/SPELL_FAILED_NOT_BEHIND
        if (arg1 == SPELL_FAILED_NOT_BEHIND) then
            macroTorch.context.behindAttackFailedTime = GetTime()
        end
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        -- when player melee combat or spell is dodged, parried, blocked or resisted
        macroTorch.CheckDodgeParryBlockResist("target", event, arg1)
    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        -- player dodged mob's attack
    end
end
