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
-- Hunter utility functions

function macroTorch.hunterSting()
    local player = macroTorch.player
    local target = macroTorch.target
    if not target.buffed('Serpent Sting') and not target.isImmune('Serpent Sting') then
        player.serpent_sting('ready')
    end
end

function macroTorch.hunterCtrl()
    if macroTorch.target.distance < 8 then
        macroTorch.player.wing_clip('ready')
    else
        macroTorch.player.concussive_shot('ready')
    end
end