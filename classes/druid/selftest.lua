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

--- catAtk 原则回归测试（Phase 22）---

if UnitClass('player') == 'Druid' then

-- Batch 1: Pure Functions (PF-01 ~ PF-07)

macroTorch.SelfTest:register("Principle PF-01: computeReshiftEnergy returns 0 when no Furor and no Wolfsheart", function()
  if macroTorch.player.talentRank('Furor') ~= 0 or macroTorch.isKeywordInEquippedItemTooltip(1, 'Wolfsheart') then return end
  assert(macroTorch.computeReshiftEnergy() == 0,
    "expected 0, got " .. tostring(macroTorch.computeReshiftEnergy()))
end, true)

macroTorch.SelfTest:register("Principle PF-02: computeReshiftEnergy returns 60 with Furor rank 5 + Wolfsheart", function()
  if macroTorch.player.talentRank('Furor') ~= 5 or not macroTorch.isKeywordInEquippedItemTooltip(1, 'Wolfsheart') then return end
  assert(macroTorch.computeReshiftEnergy() == 60,
    "expected 60, got " .. tostring(macroTorch.computeReshiftEnergy()))
end, true)

macroTorch.SelfTest:register("Principle PF-03: computeReshiftEnergy returns 24 with Furor rank 3 and no Wolfsheart", function()
  if macroTorch.player.talentRank('Furor') ~= 3 or macroTorch.isKeywordInEquippedItemTooltip(1, 'Wolfsheart') then return end
  assert(macroTorch.computeReshiftEnergy() == 24,
    "expected 24, got " .. tostring(macroTorch.computeReshiftEnergy()))
end, true)

macroTorch.SelfTest:register("Principle PF-04: estimatePlayerDPS(60) returns 500", function()
  assert(macroTorch.estimatePlayerDPS(60) == 500,
    "expected 500, got " .. tostring(macroTorch.estimatePlayerDPS(60)))
end, true)

macroTorch.SelfTest:register("Principle PF-05: estimatePlayerDPS(40) returns 200", function()
  assert(macroTorch.estimatePlayerDPS(40) == 200,
    "expected 200, got " .. tostring(macroTorch.estimatePlayerDPS(40)))
end, true)

macroTorch.SelfTest:register("Principle PF-06: computeErps returns baseline 10 erps with no active buffs", function()
  local ctx = {
    AUTO_TICK_ERPS = 10,
    TIGER_ERPS = 10 / 3,
    RAKE_ERPS = 0,
    RIP_ERPS = 0,
    POUNCE_ERPS = 0,
    BERSERK_ERPS = 10,
    berserk = false,
    hasEssenceOfTheRed = false,
    isTigerPresent = false,
    isRakePresent = false,
    isRipPresent = false,
    isPouncePresent = false
  }
  assert(macroTorch.computeErps(ctx) == 10,
    "expected 10, got " .. tostring(macroTorch.computeErps(ctx)))
end, true)

macroTorch.SelfTest:register("Principle PF-07: computeErps adds Tiger and Rake erps to baseline", function()
  local ctx = {
    AUTO_TICK_ERPS = 10,
    TIGER_ERPS = 10 / 3,
    RAKE_ERPS = 15,
    RIP_ERPS = 0,
    POUNCE_ERPS = 0,
    BERSERK_ERPS = 10,
    berserk = false,
    hasEssenceOfTheRed = false,
    isTigerPresent = true,
    isRakePresent = true,
    isRipPresent = false,
    isPouncePresent = false
  }
  local expected = 10 + (10 / 3) + 15
  local result = macroTorch.computeErps(ctx)
  assert(math.abs(result - expected) < 0.01,
    "expected ~" .. tostring(expected) .. ", got " .. tostring(result))
end, true)

-- Batch 1 Continued: Kill Shot Thresholds (R9-01 ~ R9-03)

macroTorch.SelfTest:register("Principle R9-01: getKSThreshold(60) returns 1750", function()
  assert(macroTorch.getKSThreshold(60) == 1750,
    "expected 1750, got " .. tostring(macroTorch.getKSThreshold(60)))
end, true)

macroTorch.SelfTest:register("Principle R9-02: getKSThreshold(50) returns 725", function()
  assert(macroTorch.getKSThreshold(50) == 725,
    "expected 725, got " .. tostring(macroTorch.getKSThreshold(50)))
end, true)

macroTorch.SelfTest:register("Principle R9-03: getKSThreshold(15) returns 100", function()
  assert(macroTorch.getKSThreshold(15) == 100,
    "expected 100, got " .. tostring(macroTorch.getKSThreshold(15)))
end, true)

-- End of Batch 1

	-- Batch 2: Conditional Decision Tests

	-- Rule 2: Energy Starvation — shouldDoReshift (R2-01 ~ R2-07)

	macroTorch.SelfTest:register("Principle R2-01: reshift energy 0 — no reshift triggered", function()
		assert(macroTorch.shouldDoReshift({ RESHIFT_ENERGY = 0 }) == false,
			"expected false when RESHIFT_ENERGY is 0")
	end, true)

	macroTorch.SelfTest:register("Principle R2-02: not in combat — no reshift triggered", function()
		if macroTorch.player.isInCombat then return end
		local ctx = { RESHIFT_ENERGY = 40 }
		assert(macroTorch.shouldDoReshift(ctx) == false,
			"expected false when not in combat")
	end, true)

	macroTorch.SelfTest:register("Principle R2-03: prowling — no reshift triggered", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = { RESHIFT_ENERGY = 40, prowling = true }
		assert(macroTorch.shouldDoReshift(ctx) == false,
			"expected false when prowling")
	end, true)

	macroTorch.SelfTest:register("Principle R2-04: Omen of Clarity active — no reshift triggered", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = { RESHIFT_ENERGY = 40, ooc = true }
		assert(macroTorch.shouldDoReshift(ctx) == false,
			"expected false when OoC active")
	end, true)

	macroTorch.SelfTest:register("Principle R2-05: kill shot phase — no reshift triggered", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = { RESHIFT_ENERGY = 40 }
		if not macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldDoReshift(ctx) == false,
			"expected false during kill shot phase")
	end, true)

	macroTorch.SelfTest:register("Principle R2-06: 1.5s natural recovery sufficient — no reshift triggered", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			RESHIFT_ENERGY = 40,
			comboPoints = 0,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isRipPresent = true,
			isImmuneRip = false,
			isRakePresent = true,
			isImmuneRake = false,
			isTigerPresent = true,
			CLAW_E = 45,
			SHRED_E = 60,
			BITE_E = 35,
			RAKE_E = 40,
			RIP_E = 30,
			TIGER_E = 30,
		}
		local erps = macroTorch.computeErps(ctx)
		local projectedEnergy = macroTorch.player.mana + erps * 1.5
		local nextAbilityCost = macroTorch.getNextAbilityCost(ctx)
		if math.ceil(projectedEnergy) < nextAbilityCost then return end
		assert(macroTorch.shouldDoReshift(ctx) == false,
			"expected false when 1.5s recovery is sufficient")
	end, true)

	macroTorch.SelfTest:register("Principle R2-07: 1.5s natural recovery insufficient — reshift triggered", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			RESHIFT_ENERGY = 40,
			comboPoints = 0,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isRipPresent = true,
			isImmuneRip = false,
			isRakePresent = true,
			isImmuneRake = false,
			isTigerPresent = true,
			CLAW_E = 45,
			SHRED_E = 60,
			BITE_E = 35,
			RAKE_E = 40,
			RIP_E = 30,
			TIGER_E = 30,
		}
		local erps = macroTorch.computeErps(ctx)
		local projectedEnergy = macroTorch.player.mana + erps * 1.5
		local nextAbilityCost = macroTorch.getNextAbilityCost(ctx)
		if math.ceil(projectedEnergy) >= nextAbilityCost then return end
		assert(macroTorch.shouldDoReshift(ctx),
			"expected true when 1.5s recovery is insufficient")
	end, true)

	-- Rule 4+5: Bleed Primacy + Duration-Adaptive Rip — shouldCastRip (R4-01 ~ R5-04)

	macroTorch.SelfTest:register("Principle R4-01: 5CP without Rip in normal battle — should cast Rip", function()
		local ctx = {
			comboPoints = 5,
			isRipPresent = false,
			isImmuneRip = false,
			rough = false,
			isTrivialBattle = false,
			isFightStarted = true,
			isNearBy = true,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == true,
			"expected true: 5CP without Rip should cast Rip")
	end, true)

	macroTorch.SelfTest:register("Principle R4-02: 5CP with Rip present — should not cast Rip", function()
		local ctx = {
			comboPoints = 5,
			isRipPresent = true,
			isImmuneRip = false,
			isFightStarted = true,
			isNearBy = true,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == false,
			"expected false: Rip already present")
	end, true)

	macroTorch.SelfTest:register("Principle R4-03: 5CP immune to Rip — should not cast Rip", function()
		local ctx = {
			comboPoints = 5,
			isRipPresent = false,
			isImmuneRip = true,
			isFightStarted = true,
			isNearBy = true,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == false,
			"expected false: target immune to Rip")
	end, true)

	macroTorch.SelfTest:register("Principle R4-04: kill shot phase — should not cast Rip", function()
		local ctx = {
			comboPoints = 5,
			isRipPresent = false,
			isImmuneRip = false,
			isFightStarted = true,
			isNearBy = true,
		}
		if not macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == false,
			"expected false: kill shot phase should not cast Rip")
	end, true)

	macroTorch.SelfTest:register("Principle R5-01: trivial battle 1CP without Rip — should cast Rip", function()
		local ctx = {
			comboPoints = 1,
			isRipPresent = false,
			isImmuneRip = false,
			isTrivialBattle = true,
			isFightStarted = true,
			isNearBy = true,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == true,
			"expected true: trivial battle 1CP should cast Rip")
	end, true)

	macroTorch.SelfTest:register("Principle R5-02: trivial battle 2CP without Rip — should cast Rip", function()
		local ctx = {
			comboPoints = 2,
			isRipPresent = false,
			isImmuneRip = false,
			isTrivialBattle = true,
			isFightStarted = true,
			isNearBy = true,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == true,
			"expected true: trivial battle 2CP should cast Rip")
	end, true)

	macroTorch.SelfTest:register("Principle R5-03: trivial battle 3CP — should not cast Rip, should Bite instead", function()
		local ctx = {
			comboPoints = 3,
			isRipPresent = false,
			isImmuneRip = false,
			isTrivialBattle = true,
			isFightStarted = true,
			isNearBy = true,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == false,
			"expected false: trivial battle 3CP should Bite, not Rip")
	end, true)

	macroTorch.SelfTest:register("Principle R5-04: normal battle 3CP — should not cast Rip (need 5CP)", function()
		local ctx = {
			comboPoints = 3,
			isRipPresent = false,
			isImmuneRip = false,
			isTrivialBattle = false,
			isFightStarted = true,
			isNearBy = true,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldCastRip(ctx) == false,
			"expected false: normal battle needs 5CP for Rip")
	end, true)

	-- Rule 6: Builder Choice — shouldUseShred (R6-01 ~ R6-06)

	macroTorch.SelfTest:register("Principle R6-01: 0 bleeds OoC behind — use Shred", function()
		local ctx = {
			ooc = true,
			isBehind = true,
			isRakePresent = false,
			isRipPresent = false,
			isPouncePresent = false,
			isPseudoInfiniteEnergy = false,
			CLAW_E = 45,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		macroTorch.player.isBehindAttackJustFailed = false
		assert(macroTorch.shouldUseShred(ctx) == true,
			"expected true: 0 bleeds OoC behind should use Shred")
	end, true)

	macroTorch.SelfTest:register("Principle R6-02: 0 bleeds infinite energy behind — use Shred", function()
		local ctx = {
			isPseudoInfiniteEnergy = true,
			isBehind = true,
			isRakePresent = false,
			isRipPresent = false,
			isPouncePresent = false,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		macroTorch.player.isBehindAttackJustFailed = false
		assert(macroTorch.shouldUseShred(ctx) == true,
			"expected true: 0 bleeds infinite energy behind should use Shred")
	end, true)

	macroTorch.SelfTest:register("Principle R6-03: 2 bleeds OoC behind — use Shred", function()
		local ctx = {
			ooc = true,
			isBehind = true,
			isPseudoInfiniteEnergy = false,
			isRakePresent = true,
			isRipPresent = true,
			isPouncePresent = false,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		macroTorch.player.isBehindAttackJustFailed = false
		assert(macroTorch.shouldUseShred(ctx) == true,
			"expected true: 2 bleeds OoC behind should use Shred")
	end, true)

	macroTorch.SelfTest:register("Principle R6-04: 2 bleeds no OoC no infinite — use Claw", function()
		local ctx = {
			ooc = false,
			isPseudoInfiniteEnergy = false,
			isRakePresent = true,
			isRipPresent = true,
			isPouncePresent = false,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		assert(macroTorch.shouldUseShred(ctx) == false,
			"expected false: 2 bleeds without OoC or infinite energy should use Claw")
	end, true)

	macroTorch.SelfTest:register("Principle R6-05: 3+ bleeds always Claw regardless of OoC/infinite", function()
		local ctx = {
			ooc = true,
			isBehind = true,
			isPseudoInfiniteEnergy = true,
			isRakePresent = true,
			isRipPresent = true,
			isPouncePresent = true,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		assert(macroTorch.shouldUseShred(ctx) == false,
			"expected false: 3+ bleeds should always use Claw")
	end, true)

	macroTorch.SelfTest:register("Principle R6-06: Rip absent normal battle — use Claw for faster CP generation", function()
		local ctx = {
			isBehind = true,
			isPseudoInfiniteEnergy = false,
			ooc = false,
			isRakePresent = true,
			isRipPresent = false,
			isPouncePresent = false,
			isImmuneRip = false,
			isTrivialBattle = false,
			CLAW_E = 45,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		assert(macroTorch.shouldUseShred(ctx) == false,
			"expected false: Rip absent in normal battle should use Claw for faster CP")
	end, true)

	-- Rule 7: GCD Priority / Bite Trigger — shouldUseBite (R7-01 ~ R7-06)

	macroTorch.SelfTest:register("Principle R7-01: kill shot with combo points — should Bite", function()
		local ctx = { comboPoints = 3 }
		if not macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldUseBite(ctx) == true,
			"expected true: kill shot with CP should Bite")
	end, true)

	macroTorch.SelfTest:register("Principle R7-02: kill shot zero combo points — should not Bite", function()
		local ctx = { comboPoints = 0 }
		if not macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldUseBite(ctx) == false,
			"expected false: kill shot with 0 CP should not Bite")
	end, true)

	macroTorch.SelfTest:register("Principle R7-03: 5CP Rip present normal battle — should Bite", function()
		local ctx = {
			comboPoints = 5,
			isRipPresent = true,
			isImmuneRip = false,
			isTrivialBattle = false,
			rough = false,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldUseBite(ctx) == true,
			"expected true: 5CP with Rip present should Bite")
	end, true)

	macroTorch.SelfTest:register("Principle R7-04: 5CP immune to Rip — should Bite (no Rip option)", function()
		local ctx = {
			comboPoints = 5,
			isImmuneRip = true,
			isTrivialBattle = false,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldUseBite(ctx) == true,
			"expected true: 5CP immune to Rip should Bite")
	end, true)

	macroTorch.SelfTest:register("Principle R7-05: trivial battle 3CP no Rip — should Bite", function()
		local ctx = {
			comboPoints = 3,
			isTrivialBattle = true,
			isRipPresent = false,
			isImmuneRip = false,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldUseBite(ctx) == true,
			"expected true: trivial battle 3CP no Rip should Bite")
	end, true)

	macroTorch.SelfTest:register("Principle R7-06: trivial battle 2CP no Rip — should not Bite (need 3+ CP)", function()
		local ctx = {
			comboPoints = 2,
			isTrivialBattle = true,
			isRipPresent = false,
			isImmuneRip = false,
		}
		if macroTorch.isKillShotOrLastChance(ctx) then return end
		assert(macroTorch.shouldUseBite(ctx) == false,
			"expected false: trivial battle 2CP should not Bite")
	end, true)

	-- Rule 8: FF Fill During Wait Window — shouldCastFFDuringWaitWindow (R8-01 ~ R8-06)

	macroTorch.SelfTest:register("Principle R8-01: Omen of Clarity active — no FF fill", function()
		local ctx = { ooc = true }
		assert(macroTorch.shouldCastFFDuringWaitWindow(ctx) == false,
			"expected false: OoC active should not cast FF")
	end, true)

	macroTorch.SelfTest:register("Principle R8-02: target immune to FF — no FF fill", function()
		if not macroTorch.target.isImmune('Faerie Fire (Feral)') then return end
		local ctx = { ooc = false }
		assert(macroTorch.shouldCastFFDuringWaitWindow(ctx) == false,
			"expected false: target immune to FF should not cast FF")
	end, true)

	macroTorch.SelfTest:register("Principle R8-03: reshift pending — no FF fill (reshift takes priority)", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = { ooc = false, RESHIFT_ENERGY = 40 }
		if not macroTorch.shouldDoReshift(ctx) then return end
		assert(macroTorch.shouldCastFFDuringWaitWindow(ctx) == false,
			"expected false: reshift pending should not cast FF")
	end, true)

	macroTorch.SelfTest:register("Principle R8-04: energy sufficient — no wait window, no FF fill", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = { ooc = false }
		-- This test expects player.mana >= minAbilityCost
		local minAbilityCost = macroTorch.getNextAbilityCost(ctx)
		if macroTorch.player.mana < minAbilityCost then return end
		assert(macroTorch.shouldCastFFDuringWaitWindow(ctx) == false,
			"expected false: energy sufficient, no wait needed")
	end, true)

	macroTorch.SelfTest:register("Principle R8-05: wait window too short to cast FF", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			ooc = false,
			isTigerPresent = true,
			isRakePresent = false,
			isRipPresent = false,
			isPouncePresent = false,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
		}
		if macroTorch.shouldDoReshift(ctx) then return end
		local erps = macroTorch.computeErps(ctx)
		if erps <= 0 then return end
		local minAbilityCost = macroTorch.getNextAbilityCost(ctx)
		local currentEnergy = macroTorch.player.mana
		if currentEnergy >= minAbilityCost then return end
		local energyDuringGcd = erps * 1.5
		if currentEnergy + energyDuringGcd < minAbilityCost then return end
		local energyNeeded = minAbilityCost - currentEnergy
		local waitSeconds = energyNeeded / erps
		if waitSeconds >= 1.0 then return end
		assert(macroTorch.shouldCastFFDuringWaitWindow(ctx) == false,
			"expected false: wait window too short (less than 1s)")
	end, true)

	macroTorch.SelfTest:register("Principle R8-06: wait window sufficient (>= 1s) — cast FF", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			ooc = false,
			isTigerPresent = true,
			isRakePresent = false,
			isRipPresent = false,
			isPouncePresent = false,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
		}
		if macroTorch.shouldDoReshift(ctx) then return end
		local erps = macroTorch.computeErps(ctx)
		if erps <= 0 then return end
		local minAbilityCost = macroTorch.getNextAbilityCost(ctx)
		local currentEnergy = macroTorch.player.mana
		if currentEnergy >= minAbilityCost then return end
		local energyDuringGcd = erps * 1.5
		if currentEnergy + energyDuringGcd < minAbilityCost then return end
		local energyNeeded = minAbilityCost - currentEnergy
		local waitSeconds = energyNeeded / erps
		if waitSeconds < 1.0 then return end
		assert(macroTorch.shouldCastFFDuringWaitWindow(ctx) == true,
			"expected true: wait window sufficient for FF (>= 1s)")
	end, true)

	-- End of Batch 2 — all catAtk principle regression tests complete

end