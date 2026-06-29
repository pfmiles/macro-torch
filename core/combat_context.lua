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

-- combat entry/exit state management
-- extracted from battle_event_queue.lua PLAYER_REGEN_ENABLED/DISABLED event branches
-- provides independent macroTorch.* functions for events.lua eventHandle to call

function macroTorch.onCombatExit()
    if macroTorch.context then
        macroTorch.inCombat = false
        macroTorch.context = {}
    end
    macroTorch.show('Exiting combat!')
end

function macroTorch.onCombatEnter()
    if not macroTorch.context then
        macroTorch.context = {}
    end
    macroTorch.inCombat = true
    macroTorch.show('Entering combat!')
end

function macroTorch.onPlayerEnteringWorld()
    macroTorch.player = macroTorch.initPlayer()
    macroTorch.loginContext = {}
    macroTorch.loadSpellIdMap()
end