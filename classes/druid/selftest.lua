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

	macroTorch.SelfTest:register("Principle R2-07: 1.5s natural recovery insufficient + earning>0 — reshift triggered", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			RESHIFT_ENERGY = 60,
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
		-- Skip test if waiting 1.5s is already sufficient
		if math.ceil(projectedEnergy) >= nextAbilityCost then return end
		-- Skip test if earning <= 0 (would not reshift with effective guard)
		local effectiveEnergy = ctx.RESHIFT_ENERGY - ctx.TIGER_E  -- Tiger present, will be removed
		if effectiveEnergy <= macroTorch.player.mana then return end
		assert(macroTorch.shouldDoReshift(ctx),
			"expected true when 1.5s recovery is insufficient AND reshift improves position")
	end, true)

	macroTorch.SelfTest:register("Principle R2-08: earning <= 0 — no reshift even when 1.5s recovery insufficient", function()
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
		-- Only test when waiting 1.5s is insufficient (otherwise the first condition already blocks reshift)
		if math.ceil(projectedEnergy) >= nextAbilityCost then return end
		-- Only test when earning <= 0 (the new guard's domain)
		local effectiveEnergy = ctx.RESHIFT_ENERGY - ctx.TIGER_E
		if effectiveEnergy > macroTorch.player.mana then return end
		assert(macroTorch.shouldDoReshift(ctx) == false,
			"expected false when earning <= 0 (reshift does not improve energy position)")
	end, true)

	-- Rule 4+5: Bleed Primacy + Duration-Adaptive Rip — shouldCastRip (R4-01 ~ R5-04)

	macroTorch.SelfTest:register("Principle R4-01: 5CP without Rip in normal battle — should cast Rip", function()
		local ctx = {
			comboPoints = 5,
			isRipPresent = false,
			isImmuneRip = false,
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

	-- Category O: Idol Dance (Phase 23)

	macroTorch.SelfTest:register("Cat O-01: fast combat returns Fero/Rot (Gap 1 fix) — per D-01", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			isTrivialBattle = true,
			isImmuneRip = false,
		}
		assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
			"expected non-Savagery for fast combat, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
	end, true)

	macroTorch.SelfTest:register("Cat O-02: PvP target returns Fero/Rot (Gap 1 fix) — per D-01", function()
		if not macroTorch.player.isInCombat then return end
		if not macroTorch.target.isPlayerControlled then return end
		local ctx = {
			isTrivialBattle = false,
			isImmuneRip = false,
		}
		assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
			"expected non-Savagery for PvP target, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
	end, true)

	macroTorch.SelfTest:register("Cat O-05: Rip absent in normal combat returns Savagery — per D-01", function()
		local ctx = {
			isTrivialBattle = false,
			isImmuneRip = false,
		}
		assert(macroTorch.computeNormalRelic(ctx) == 'Idol of Savagery',
			"expected Savagery when Rip absent in normal combat, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
	end, true)

	macroTorch.SelfTest:register("Cat O-03: Immune Rip in combat returns Fero/Rot (Gap 2 fix) — per D-01", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			isImmuneRip = true,
			isTrivialBattle = false,
		}
		assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
			"expected non-Savagery for immune Rip in combat, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
	end, true)

	macroTorch.SelfTest:register("Cat O-04: Rip present returns Fero/Rot — per D-01", function()
		if not macroTorch.player.isInCombat then return end
		local ctx = {
			isImmuneRip = false,
			isTrivialBattle = false,
			isRipPresent = true,
		}
		assert(macroTorch.computeNormalRelic(ctx) ~= 'Idol of Savagery',
			"expected non-Savagery when Rip present, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
	end, true)

	macroTorch.SelfTest:register("Cat O-06: Non-combat non-immune returns Savagery (D-02 preserved) — per D-01", function()
		if macroTorch.player.isInCombat then return end
		local ctx = {
			isImmuneRip = false,
			isTrivialBattle = false,   -- pin to normal-battle path; otherwise trivial-target runtime state could short-circuit the top-level guard and fail the assertion
		}
		assert(macroTorch.computeNormalRelic(ctx) == 'Idol of Savagery',
			"expected Savagery for non-combat non-immune, got " .. tostring(macroTorch.computeNormalRelic(ctx)))
	end, true)

	macroTorch.SelfTest:register("Cat O-07: Distance >= 20 bypass present (Gap 4 fix) — per D-03", function()
		assert(type(macroTorch.recoverNormalRelic) == 'function',
			"recoverNormalRelic should be a function")
		assert(macroTorch.target.distance ~= nil,
			"target.distance API not available on this client")
	end, true)

	-- Category Q: event-driven land-framework regression tests (Phase 27 Q-01..Q-09)
	-- Every stubbed test (Q-02..Q-07) follows the Phase-26 CR-01 discipline: the fake
	-- loginContext / target are local tables built before install, framework calls run
	-- inside a pcall, results are captured into locals, the real globals are restored by
	-- raw assignment, and only then does any assert run — a failing assert can never
	-- leave a polluted session. No test writes macroTorch.tracingSpells,
	-- macroTorch.landSources, macroTorch.landListeners, or any real loginContext sub-table.

	macroTorch.SelfTest:register("Cat Q-01: land-source registry values (aura-apply vs self-hit)", function()
		assert(macroTorch.landSources['Rip'] == 'aura-apply',
			"expected Rip landSource 'aura-apply', got " .. tostring(macroTorch.landSources['Rip']))
		assert(macroTorch.landSources['Pounce'] == 'aura-apply',
			"expected Pounce landSource 'aura-apply', got " .. tostring(macroTorch.landSources['Pounce']))
		assert(macroTorch.landSources['Rake'] == 'self-hit',
			"expected Rake landSource 'self-hit', got " .. tostring(macroTorch.landSources['Rake']))
		assert(macroTorch.landSources['Ferocious Bite'] == 'self-hit',
			"expected Ferocious Bite landSource 'self-hit', got " .. tostring(macroTorch.landSources['Ferocious Bite']))
		assert(macroTorch.landSources['Serpent Sting'] == 'aura-apply',
			"expected Serpent Sting landSource 'aura-apply', got " .. tostring(macroTorch.landSources['Serpent Sting']))
		assert(macroTorch.landSources['Scorpid Sting'] == 'aura-apply',
			"expected Scorpid Sting landSource 'aura-apply', got " .. tostring(macroTorch.landSources['Scorpid Sting']))
	end, true)

	macroTorch.SelfTest:register("Cat Q-02: aura-apply line pairs the cast intent and lands at apply time", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		-- the paired apply now prints a green land line (2026-08-30 feedback
		-- restore); stub show so the test run leaves no chat noise
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		macroTorch.show = function() end
		local pcallRes = true
		local intentResult, intentState, intentLandAt, ripLandTop
		pcallRes = pcall(function()
			macroTorch.recordCastTable('Rip')
			-- recordCastTable stamps the intent with the real client clock; align the
			-- seeded castAt into the fake pair window around the 1000.5 apply time
			-- (write to the fake context's own intent only)
			fakeLoginContext.intentTable['Rip']['QTestMob'].top.castAt = 999.0
			intentResult = macroTorch.processRawAuraApply('Rip',
				'0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 1000.5)
			if intentResult then
				intentState = intentResult.state
				intentLandAt = intentResult.landAt
			end
			ripLandTop = fakeLoginContext.landTable['Rip']['QTestMob'].top
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-02 pcall failed")
		assert(intentResult ~= nil,
			"expected the aura-apply line to pair the cast intent, got nil")
		assert(intentState == 'landed',
			"expected intent state 'landed', got " .. tostring(intentState))
		assert(intentLandAt == 1000.5,
			"expected landAt 1000.5, got " .. tostring(intentLandAt))
		assert(ripLandTop == 1000.5,
			"expected landTable top 1000.5, got " .. tostring(ripLandTop))
	end, true)

	macroTorch.SelfTest:register("Cat Q-03: foreign-guid apply line is rejected and the intent stays pending", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		local ok, pcallRes = true, true
		local intentState, ripLanded
		pcallRes = pcall(function()
			macroTorch.recordCastTable('Rip')
			intentState = fakeLoginContext.intentTable['Rip']['QTestMob'].top.state
			ripLanded = fakeLoginContext.landTable ~= nil and fakeLoginContext.landTable['Rip'] ~= nil
			ok = (macroTorch.processRawAuraApply('Rip',
					'0xF1300000000000AB is afflicted by Rip.', '0xDEADBEEF00000000', 7.0) == nil
				and intentState == 'pending' and ripLanded == false)
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		assert(pcallRes, "Q-03 pcall failed")
		assert(ok, "expected the foreign-guid apply to be rejected (nil, pending intent, no land)")
	end, true)

	macroTorch.SelfTest:register("Cat Q-04: stale pending intent expires past the TTL (lazy purge)", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		fakeLoginContext.intentTable = {}
		fakeLoginContext.intentTable['Rip'] = {}
		fakeLoginContext.intentTable['Rip']['QTestMob'] = macroTorch.LRUStack:new(32)
		local seededIntent = { state = 'pending', castAt = 1.0, landAt = nil }
		fakeLoginContext.intentTable['Rip']['QTestMob'].push(seededIntent)
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		local ok, pcallRes = true, true
		local seededState
		pcallRes = pcall(function()
			ok = (macroTorch.pairLandIntent('Rip', 5.0) == nil)
			seededState = seededIntent.state
			ok = ok and (seededState == 'expired')
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		assert(pcallRes, "Q-04 pcall failed")
		assert(ok, "expected TTL expiry: 5.0 - 1.0 exceeds LAND_INTENT_TTL")
	end, true)

	macroTorch.SelfTest:register("Cat Q-05: fail after land revokes the land entry (fail is final)", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		-- the paired apply and the fail-revocation both print user-visible
		-- lines now (2026-08-30); stub show so the test run stays silent
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		fakeLoginContext.intentTable = {}
		fakeLoginContext.intentTable['Rip'] = {}
		fakeLoginContext.intentTable['Rip']['QTestMob'] = macroTorch.LRUStack:new(32)
		local seededIntent = { state = 'pending', castAt = 9.0, landAt = nil }
		fakeLoginContext.intentTable['Rip']['QTestMob'].push(seededIntent)
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		macroTorch.show = function() end
		local ok, pcallRes = true, true
		local seededState, landTopAfterFail
		pcallRes = pcall(function()
			macroTorch.processRawAuraApply('Rip',
				'0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 9.1)
			local landTopAfterPair = fakeLoginContext.landTable['Rip']['QTestMob'].top
			macroTorch.finalizeFail('Rip', 9.3)
			seededState = seededIntent.state
			landTopAfterFail = fakeLoginContext.landTable['Rip']['QTestMob'].top
			ok = (landTopAfterPair == 9.1 and landTopAfterFail ~= 9.1 and seededState == 'failed')
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-05 pcall failed")
		assert(ok, "expected the fail to revoke the 9.1 land entry and finalize the intent")
	end, true)

	macroTorch.SelfTest:register("Cat Q-06: fail before apply wins — no late pairing after finalization", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		fakeLoginContext.intentTable = {}
		fakeLoginContext.intentTable['Rip'] = {}
		fakeLoginContext.intentTable['Rip']['QTestMob'] = macroTorch.LRUStack:new(32)
		local seededIntent = { state = 'pending', castAt = 10.0, landAt = nil }
		fakeLoginContext.intentTable['Rip']['QTestMob'].push(seededIntent)
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		local ok, pcallRes = true, true
		local seededState, applyResult
		pcallRes = pcall(function()
			macroTorch.finalizeFail('Rip', 10.4)
			seededState = seededIntent.state
			applyResult = macroTorch.processRawAuraApply('Rip',
				'0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 10.5)
			ok = (applyResult == nil and seededState == 'failed')
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		assert(pcallRes, "Q-06 pcall failed")
		assert(ok, "expected no pairing after the intent was finalized as failed")
	end, true)

	macroTorch.SelfTest:register("Cat Q-07: self-hit lands pairing-free and unregistered spells are ignored", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		-- the self-hit land now prints a green line (2026-08-30); stub show
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		-- hasBuff is stubbed to false so the real Ferocious Bite renewal listener
		-- (dispatched by recordLandEvent) finds no present bleeds and stays a no-op
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		macroTorch.show = function() end
		local ok, pcallRes = true, true
		local fbLandTop, autumnLand
		pcallRes = pcall(function()
			macroTorch.onSelfDamageLine('Your Ferocious Bite hits QTestMob for 548.', 5.0)
			fbLandTop = fakeLoginContext.landTable['Ferocious Bite']['QTestMob'].top
			macroTorch.onSelfDamageLine('Your Autumn Harvest hits QTestMob for 1.', 5.0)
			autumnLand = fakeLoginContext.landTable['Autumn Harvest']
			ok = (fbLandTop == 5.0 and autumnLand == nil)
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-07 pcall failed")
		assert(ok, "expected a pairing-free Ferocious Bite land at 5.0 and no Autumn Harvest entry")
	end, true)

	macroTorch.SelfTest:register("Cat Q-08: Ferocious Bite renewal listener present", function()
		assert(type(macroTorch.landListeners) == 'table',
			"landListeners is not a table, got " .. type(macroTorch.landListeners))
		assert(macroTorch.tableLen(macroTorch.landListeners['Ferocious Bite'] or {}) >= 1,
			"expected at least one Ferocious Bite renewal listener")
	end, true)

	macroTorch.SelfTest:register("Cat Q-09: deleted polling machinery absent at runtime", function()
		assert(macroTorch.maintainLandTables == nil,
			"maintainLandTables should be deleted, got " .. tostring(macroTorch.maintainLandTables))
		assert(macroTorch.computeLandTable == nil,
			"computeLandTable should be deleted, got " .. tostring(macroTorch.computeLandTable))
		assert(macroTorch.consumeDruidBattleEvents == nil,
			"consumeDruidBattleEvents should be deleted, got " .. tostring(macroTorch.consumeDruidBattleEvents))
	end, true)

	macroTorch.SelfTest:register("Cat Q-10: FB land event renews Rake and Rip with the numeric event time", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local savedShow = macroTorch.show
		local savedContext = macroTorch.context
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return true end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		macroTorch.show = function() end
		-- ripLeft reads macroTorch.context.lastRipAtCp; context is nil in a fresh
		-- out-of-combat session (created onCombatEnter only), so stub it (V-01)
		macroTorch.context = {}
		local ok, pcallRes = true, true
		local rakeTop, ripTop
		pcallRes = pcall(function()
			local seedNow = GetTime()
			macroTorch.recordLandEvent('Rake', seedNow)
			macroTorch.recordLandEvent('Rip', seedNow)
			local fbNow = seedNow + 100
			macroTorch.recordLandEvent('Ferocious Bite', fbNow)
			rakeTop = fakeLoginContext.landTable['Rake']['QTestMob'].top
			ripTop = fakeLoginContext.landTable['Rip']['QTestMob'].top
			ok = (type(rakeTop) == 'number' and rakeTop == fbNow and type(ripTop) == 'number' and ripTop == fbNow)
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		macroTorch.context = savedContext
		assert(pcallRes, "Q-10 pcall failed")
		assert(ok, "expected the FB event time (number) to renew Rake and Rip land entries")
	end, true)

	-- Category S: cpBuildLog combo-point cast logging (quick 260907-0ya, 4 tests)
	-- S-03/S-04 follow the CR-01 stub discipline: snapshot via rawget, install
	-- own-key shadows, capture into locals, restore via raw assignment BEFORE
	-- any assert.
	macroTorch.SelfTest:register("Cat S-01: cpBuildLog switch defaults to false", function()
		assert(macroTorch.cpBuildLog == false,
			"cpBuildLog should default to false, got " .. tostring(macroTorch.cpBuildLog))
	end, true)

	macroTorch.SelfTest:register("Cat S-02: cpBuildLogEvent emits the fixed [cpBuild] line format", function()
		local savedLog = macroTorch.log
		local captured = nil
		macroTorch.log = function(a)
			captured = tostring(a)
		end
		local pcallRes = pcall(function()
			macroTorch.cpBuildLogEvent('Claw', { t = 12.34, cp = 3, e = 62 })
		end)
		macroTorch.log = savedLog
		assert(pcallRes, "S-02 pcall failed")
		assert(captured == '[cpBuild] Claw t=12.34 cp=3 e=62', "S-02 unexpected log line: " .. tostring(captured))
	end, true)

	macroTorch.SelfTest:register("Cat S-03: claw() logs only when switch on and GCD ready", function()
		local player = macroTorch.player
		local savedSwitch = macroTorch.cpBuildLog
		local savedLog = macroTorch.log
		local savedCast = rawget(player, '_castSpell')
		local savedActionCd = rawget(player, 'isActionCooledDown')
		local captured = {}
		local nOn, nGcd, nOff = 0, 0, 0
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		player._castSpell = function()
			return true
		end
		player.isActionCooledDown = function()
			return true
		end
		local pcallRes = pcall(function()
			macroTorch.cpBuildLog = true
			player.claw('ready')
			nOn = macroTorch.tableLen(captured)
			player.isActionCooledDown = function()
				return false
			end
			player.claw('ready')
			nGcd = macroTorch.tableLen(captured) - nOn
			macroTorch.cpBuildLog = false
			player.claw('ready')
			nOff = macroTorch.tableLen(captured) - nOn - nGcd
		end)
		rawset(player, '_castSpell', savedCast)
		rawset(player, 'isActionCooledDown', savedActionCd)
		macroTorch.log = savedLog
		macroTorch.cpBuildLog = savedSwitch
		assert(pcallRes, "S-03 pcall failed")
		assert(nOn == 1, "expected exactly one cpBuild log when the switch is on and GCD is ready, got " .. tostring(nOn))
		assert(nGcd == 0, "expected no cpBuild log when GCD is not ready, got " .. tostring(nGcd))
		assert(nOff == 0, "expected no cpBuild log when the switch is off, got " .. tostring(nOff))
	end, true)

	macroTorch.SelfTest:register("Cat S-04: cpBuildLogSample warns once when the GCD probe yields nil", function()
		local savedShow = macroTorch.show
		local savedWarned = macroTorch._cpBuildLogProbeWarned
		local player = macroTorch.player
		local savedActionCd = rawget(player, 'isActionCooledDown')
		local warnings = {}
		macroTorch.show = function(a)
			table.insert(warnings, tostring(a))
		end
		-- WR-01: nil (not false) from the action-slot scan is exactly what a session
		-- with Rake off every bar produces; the sample must warn exactly once and
		-- keep gcdOk nil so the measurement does not fabricate GCD-ready rows.
		player.isActionCooledDown = function()
			return nil
		end
		macroTorch._cpBuildLogProbeWarned = nil
		local sample1, sample2, ok
		local pcallRes = pcall(function()
			sample1 = macroTorch.cpBuildLogSample()
			sample2 = macroTorch.cpBuildLogSample()
			ok = (sample1.gcdOk == nil and sample2.gcdOk == nil)
		end)
		local warnCount = macroTorch.tableLen(warnings)
		rawset(player, 'isActionCooledDown', savedActionCd)
		macroTorch.show = savedShow
		macroTorch._cpBuildLogProbeWarned = savedWarned
		assert(pcallRes, "S-04 pcall failed")
		assert(sample1 ~= nil and sample2 ~= nil, "S-04 cpBuildLogSample should return a table")
		assert(ok, "S-04 gcdOk should stay nil when the probe fails")
		assert(warnCount == 1, "expected exactly one GCD probe warning, got " .. tostring(warnCount))
		assert(string.find(warnings[1], '[cpBuild]', 1, true) == 1,
			"S-04 warning should carry the [cpBuild] tag: " .. tostring(warnings[1]))
	end, true)

	-- Registration count: Category S adds 4 tests (quick 260907-0ya + WR-01 fix)
end
