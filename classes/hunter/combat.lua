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
-- Hunter combat rotation functions

function macroTorch.hunterAtk()
    local player = macroTorch.player
    local target = macroTorch.target
    local pet = macroTorch.pet
    local clickContext = {}
    clickContext.RAPTOR_E = 32
    clickContext.MONGOOSE_E = 28
    clickContext.DISENGAGE_E = 50

    clickContext.ARCANE_E = 50
    clickContext.MULTI_E = 100

    clickContext.prowling = player.buffed('Shadowmeld')

    player.targetEnemy()
    if target.isCanAttack and macroTorch.isFightStarted(clickContext) then
        pet.attack()
        macroTorch.htOtMod(clickContext)
        if target.distance < 8 then
            -- melee logic
            player.startAutoAtk()
            player.mongoose_bite('safe')
            player.raptor_strike('safe')
        else
            -- ranged logic
            if not target.buffed(nil, 'Ability_Hunter_SniperShot') then
                player.hunters_mark()
            end
            player.startAutoShoot()
            player.arcane_shot('safe')
            player.multi_shot('safe')
        end
    end
end

function macroTorch.htOtMod(clickContext)
    if string.find(macroTorch.target.name, 'Training Dummy') then
        return
    end
    local player = macroTorch.player
    local target = macroTorch.target
    if not player.isInCombat
        or not target.isInCombat
        or clickContext.prowling
        or target.willDieInSeconds(2)
        or not target.isCanAttack
        or target.isPlayerControlled
        or not macroTorch.player.isInGroup then
        return
    end
    if target.isAttackingMe and not player.isSpellReady('Disengage') and target.classification == 'worldboss' then
        player.use('Invulnerability Potion', true)
    end
    if target.isAttackingMe or (target.classification == 'worldboss' and player.threatPercent >= macroTorch.COWER_THREAT_THRESHOLD) then
        player.disengage()
    end
end