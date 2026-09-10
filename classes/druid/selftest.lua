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
		-- R6-01 follows the CR-01 stub discipline (Cat U batch precedent):
		-- isBehindAttackJustFailed is a PLAYER_FIELD_FUNC_MAP accessor and the
		-- class metatable has no __newindex, so a bare assignment would shadow
		-- the accessor on the live player for the entire session. Snapshot via
		-- rawget, install the own-key shadow, restore via rawset BEFORE any
		-- assert.
		local player = macroTorch.player
		local saved = rawget(player, 'isBehindAttackJustFailed')
		player.isBehindAttackJustFailed = false
		local ok, res = pcall(function()
			return macroTorch.shouldUseShred(ctx) == true
		end)
		rawset(player, 'isBehindAttackJustFailed', saved)
		assert(ok, "R6-01 errored: " .. tostring(res))
		assert(res, "expected true: 0 bleeds OoC behind should use Shred")
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
		-- R6-02: same snapshot/shadow/restore discipline as R6-01.
		local player = macroTorch.player
		local saved = rawget(player, 'isBehindAttackJustFailed')
		player.isBehindAttackJustFailed = false
		local ok, res = pcall(function()
			return macroTorch.shouldUseShred(ctx) == true
		end)
		rawset(player, 'isBehindAttackJustFailed', saved)
		assert(ok, "R6-02 errored: " .. tostring(res))
		assert(res, "expected true: 0 bleeds infinite energy behind should use Shred")
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
		-- R6-03: same snapshot/shadow/restore discipline as R6-01.
		local player = macroTorch.player
		local saved = rawget(player, 'isBehindAttackJustFailed')
		player.isBehindAttackJustFailed = false
		local ok, res = pcall(function()
			return macroTorch.shouldUseShred(ctx) == true
		end)
		rawset(player, 'isBehindAttackJustFailed', saved)
		assert(ok, "R6-03 errored: " .. tostring(res))
		assert(res, "expected true: 2 bleeds OoC behind should use Shred")
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

	-- Category Q: event-driven land-framework regression tests (Phase 27 Q-01..Q-09,
	-- Phase 29 unified OR rewrite; 29-02 revives Q-09 as the inference-core
	-- assertion and adds Q-11/Q-13; 29-03 closes D-16 with Q-12/Q-14/Q-15/Q-16.
	-- The full sequence Q-01..Q-16 covers: unified registration / apply pairing /
	-- foreign-guid rejection / expiry / fail finality / late-pairing block /
	-- pairing-free self-hit / listener presence / inference revival / renewal
	-- numeric time / silent-window inference / dedup late evidence / windowed
	-- fail veto / ttl boundary / renewal exemption / remote late arrival.
	-- Every stubbed test (Q-02..Q-16) follows the Phase-26 CR-01 discipline: the fake
	-- loginContext / target are local tables built before install, framework calls run
	-- inside a pcall, results are captured into locals, the real globals are restored by
	-- raw assignment, and only then does any assert run — a failing assert can never
	-- leave a polluted session. No test writes macroTorch.tracingSpells,
	-- macroTorch.landListeners, or any real loginContext sub-table.

	macroTorch.SelfTest:register("Cat Q-01: unified three-channel OR registration (no per-spell source registry)", function()
		assert(macroTorch.landSources == nil,
			"expected the per-spell land source registry to be gone (D-01)")
		assert(macroTorch.tracingSpells['Pounce'] == true,
			"expected Pounce land tracing")
		assert(macroTorch.tracingSpells['Rake'] == true,
			"expected Rake land tracing")
		assert(macroTorch.tracingSpells['Rip'] == true,
			"expected Rip land tracing")
		assert(macroTorch.tracingSpells['Ferocious Bite'] == true,
			"expected Ferocious Bite land tracing")
		assert(macroTorch.tracingSpells['Serpent Sting'] == true,
			"expected Serpent Sting land tracing")
		assert(macroTorch.tracingSpells['Scorpid Sting'] == true,
			"expected Scorpid Sting land tracing")
		assert(macroTorch.LAND_INTENT_TTL == 0.9,
			"expected the default evidence window 0.9, got " .. tostring(macroTorch.LAND_INTENT_TTL))
		assert(macroTorch.landIntentTtls['Serpent Sting'] == 2,
			"expected Serpent Sting intentTtl 2, got " .. tostring(macroTorch.landIntentTtls['Serpent Sting']))
		assert(macroTorch.landIntentTtls['Scorpid Sting'] == 2,
			"expected Scorpid Sting intentTtl 2, got " .. tostring(macroTorch.landIntentTtls['Scorpid Sting']))
		assert(macroTorch.landIntentTtls['Pounce'] == 0.9,
			"expected Pounce intentTtl default 0.9, got " .. tostring(macroTorch.landIntentTtls['Pounce']))
		assert(macroTorch.landIntentTtls['Rake'] == 0.9,
			"expected Rake intentTtl default 0.9, got " .. tostring(macroTorch.landIntentTtls['Rake']))
		assert(macroTorch.landIntentTtls['Rip'] == 0.9,
			"expected Rip intentTtl default 0.9, got " .. tostring(macroTorch.landIntentTtls['Rip']))
		assert(macroTorch.landIntentTtls['Ferocious Bite'] == 0.9,
			"expected Ferocious Bite intentTtl default 0.9, got " .. tostring(macroTorch.landIntentTtls['Ferocious Bite']))
		local rakePattern = macroTorch.auraApplySpellPatterns['Rake']
		local pouncePattern = macroTorch.auraApplySpellPatterns['Pounce']
		local ripPattern = macroTorch.auraApplySpellPatterns['Rip']
		assert(type(rakePattern) == 'string' and string.find(rakePattern, ' is afflicted by ') ~= nil,
			"expected a Rake aura-apply pattern, got " .. tostring(rakePattern))
		assert(type(pouncePattern) == 'string' and string.find(pouncePattern, ' is afflicted by ') ~= nil,
			"expected a Pounce aura-apply pattern, got " .. tostring(pouncePattern))
		assert(type(ripPattern) == 'string' and string.find(ripPattern, ' is afflicted by ') ~= nil,
			"expected a Rip aura-apply pattern, got " .. tostring(ripPattern))
		assert(macroTorch.auraApplySpellPatterns['Faerie Fire (Feral)'] == nil,
			"expected no Faerie Fire (Feral) aura-apply pattern (land=false)")
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
			-- seeded castAt 0.5s before the applied 1000.5 — inside the 0.9 default window
			-- (write to the fake context's own intent only)
			fakeLoginContext.intentTable['Rip']['QTestMob'].top.castAt = 1000.0
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

	macroTorch.SelfTest:register("Cat Q-09: inference core revived with 0.1s periodic registration", function()
		assert(type(macroTorch.maintainLandTables) == 'function',
			"maintainLandTables should be a function, got " .. tostring(macroTorch.maintainLandTables))
		assert(type(macroTorch.computeLandTable) == 'function',
			"computeLandTable should be a function, got " .. tostring(macroTorch.computeLandTable))
		local task = macroTorch.periodicTasks['maintainLandTables']
		assert(task ~= nil,
			"expected the maintainLandTables periodic task registration")
		assert(task.interval == 0.1,
			"expected maintainLandTables interval 0.1, got " .. tostring(task.interval))
		assert(task.task == macroTorch.maintainLandTables,
			"expected the periodic task to point at the revived maintainLandTables")
		assert(macroTorch.consumeDruidBattleEvents == nil,
			"consumeDruidBattleEvents should still be gone, got " .. tostring(macroTorch.consumeDruidBattleEvents))
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

	macroTorch.SelfTest:register("Cat Q-11: silent-window inference fires after ttl with blue (inferred) announcement", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		local captured = {}
		macroTorch.show = function(msg, color)
			table.insert(captured, { msg = msg, color = color })
		end
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		local pcallRes = true
		local seedCast, rakeTop, capCount, capMsg, capColor
		pcallRes = pcall(function()
			local now0 = GetTime()
			-- 2.0s before now: past the 0.9 default window, the window is silent
			seedCast = now0 - 2.0
			fakeLoginContext.castTable = {}
			fakeLoginContext.landTable = {}
			fakeLoginContext.failTable = {}
			fakeLoginContext.castTable['Rake'] = {}
			fakeLoginContext.landTable['Rake'] = {}
			fakeLoginContext.failTable['Rake'] = {}
			fakeLoginContext.castTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
			fakeLoginContext.landTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
			fakeLoginContext.failTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
			fakeLoginContext.castTable['Rake']['QTestMob'].push(seedCast)
			macroTorch.computeLandTable('Rake')
			rakeTop = fakeLoginContext.landTable['Rake']['QTestMob'].top
			capCount = macroTorch.tableLen(captured)
			local cap1 = captured[1]
			if cap1 then
				capMsg = cap1.msg
				capColor = cap1.color
			end
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-11 pcall failed")
		assert(rakeTop == seedCast,
			"expected the inference anchor to be the cast time, got " .. tostring(rakeTop))
		assert(capCount == 1,
			"expected exactly one announcement, got " .. tostring(capCount))
		assert(string.find(capMsg or '', 'Rake cast on QTestMob landed:', 1, true) == 1,
			"expected the Rake cast-on announcement prefix, got " .. tostring(capMsg))
		assert(string.find(capMsg or '', '(inferred)', 1, true) ~= nil,
			"expected the (inferred) suffix, got " .. tostring(capMsg))
		assert(capColor == 'blue',
			"expected a blue announcement, got " .. tostring(capColor))
	end, true)

	macroTorch.SelfTest:register("Cat Q-12: late evidence for an already-landed cast is rejected (cast-dimension dedup)", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		macroTorch.show = function() end
		local pcallRes = true
		local intentResult, ripLandTop, ripLandSize
		pcallRes = pcall(function()
			-- seed the cast and its pending intent with a fixed clock (no real
			-- GetTime dependency); the intent enters the 0.9 default window
			local seedCast = 5.0
			fakeLoginContext.castTable = {}
			fakeLoginContext.castTable['Rip'] = {}
			fakeLoginContext.castTable['Rip']['QTestMob'] = macroTorch.LRUStack:new(100)
			fakeLoginContext.castTable['Rip']['QTestMob'].push(seedCast)
			fakeLoginContext.intentTable = {}
			fakeLoginContext.intentTable['Rip'] = {}
			fakeLoginContext.intentTable['Rip']['QTestMob'] = macroTorch.LRUStack:new(32)
			fakeLoginContext.intentTable['Rip']['QTestMob'].push({ state = 'pending', castAt = seedCast, landAt = nil, ttl = macroTorch.LAND_INTENT_TTL })
			-- the apply pairs the intent and lands at 5.1; the second evidence
			-- channel then reports 5.4 for the same cast, which the cast-dimension
			-- dedup must drop (one land per cast, earliest arrival wins)
			intentResult = macroTorch.processRawAuraApply('Rip',
				'0xF1300000000000AB is afflicted by Rip.', '0xf1300000000000ab', 5.1)
			macroTorch.recordLandEvent('Rip', 5.4)
			ripLandTop = fakeLoginContext.landTable['Rip']['QTestMob'].top
			ripLandSize = macroTorch.tableLen(fakeLoginContext.landTable['Rip']['QTestMob'].elements)
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-12 pcall failed")
		assert(intentResult ~= nil and intentResult.state == 'landed',
			"expected the 5.1 apply to pair and land the seeded intent, got " .. tostring(intentResult and intentResult.state))
		assert(ripLandTop == 5.1,
			"expected landTable top 5.1 (5.4 late evidence dropped), got " .. tostring(ripLandTop))
		assert(ripLandSize == 1,
			"expected one land per cast, got " .. tostring(ripLandSize))
	end, true)

	macroTorch.SelfTest:register("Cat Q-13: windowed fail veto — inside vetoes inference, outside does not", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		local captured = {}
		macroTorch.show = function(msg, color)
			table.insert(captured, { msg = msg, color = color })
		end
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		local pcallRes = true
		local landTopA, landTopB, countA, countB, castB, capMsg, capColor
		pcallRes = pcall(function()
			local function freshStacks()
				fakeLoginContext.castTable = {}
				fakeLoginContext.landTable = {}
				fakeLoginContext.failTable = {}
				fakeLoginContext.castTable['Rake'] = {}
				fakeLoginContext.landTable['Rake'] = {}
				fakeLoginContext.failTable['Rake'] = {}
				fakeLoginContext.castTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
				fakeLoginContext.landTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
				fakeLoginContext.failTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
			end
			-- phase A: fail 0.5s after the cast, inside the 0.9 window --
			-- vetoes the inference: zero land, zero announcement
			freshStacks()
			local nowA = GetTime()
			local castA = nowA - 1.5
			fakeLoginContext.castTable['Rake']['QTestMob'].push(castA)
			fakeLoginContext.failTable['Rake']['QTestMob'].push({ nowA - 1.0, 'resist' })
			macroTorch.computeLandTable('Rake')
			landTopA = fakeLoginContext.landTable['Rake']['QTestMob'].top
			countA = macroTorch.tableLen(captured)
			-- phase B: fail 0.1s BEFORE the cast, below the window lower bound
			-- inference fires with one blue (inferred) announcement
			freshStacks()
			local nowB = GetTime()
			castB = nowB - 1.5
			fakeLoginContext.castTable['Rake']['QTestMob'].push(castB)
			fakeLoginContext.failTable['Rake']['QTestMob'].push({ nowB - 1.6, 'resist' })
			macroTorch.computeLandTable('Rake')
			landTopB = fakeLoginContext.landTable['Rake']['QTestMob'].top
			countB = macroTorch.tableLen(captured) - countA
			local capB = captured[1]
			if capB then
				capMsg = capB.msg
				capColor = capB.color
			end
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-13 pcall failed")
		assert(landTopA == nil,
			"expected the in-window fail to veto the inference, got " .. tostring(landTopA))
		assert(countA == 0,
			"expected no announcement in the veto phase, got " .. tostring(countA))
		assert(landTopB == castB,
			"expected the out-of-window fail to leave the inference intact, got " .. tostring(landTopB))
		assert(countB == 1,
			"expected exactly one announcement in the plain-inference phase, got " .. tostring(countB))
		assert(string.find(capMsg or '', '(inferred)', 1, true) ~= nil,
			"expected the (inferred) suffix in phase B, got " .. tostring(capMsg))
		assert(capColor == 'blue',
			"expected a blue phase B announcement, got " .. tostring(capColor))
	end, true)

	macroTorch.SelfTest:register("Cat Q-14: per-intent ttl boundary — 2s window pairs, 0.9 expires at a 1.5s delta", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		local pcallRes = true
		local serpentRes, rakeRes, rakeSeededState
		pcallRes = pcall(function()
			fakeLoginContext.intentTable = {}
			fakeLoginContext.intentTable['Serpent Sting'] = {}
			fakeLoginContext.intentTable['Serpent Sting']['QTestMob'] = macroTorch.LRUStack:new(32)
			fakeLoginContext.intentTable['Serpent Sting']['QTestMob'].push({ state = 'pending', castAt = 999.0, landAt = nil, ttl = 2 })
			fakeLoginContext.intentTable['Rake'] = {}
			fakeLoginContext.intentTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(32)
			fakeLoginContext.intentTable['Rake']['QTestMob'].push({ state = 'pending', castAt = 999.0, landAt = nil, ttl = 0.9 })
			-- the same 1.5s delta reads differently against each intent's own
			-- ttl: 1.5 <= 2 pairs the sting, 1.5 > 0.9 purges the rake intent
			serpentRes = macroTorch.pairLandIntent('Serpent Sting', 1000.5)
			rakeRes = macroTorch.pairLandIntent('Rake', 1000.5)
			rakeSeededState = fakeLoginContext.intentTable['Rake']['QTestMob'].top.state
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		assert(pcallRes, "Q-14 pcall failed")
		assert(serpentRes ~= nil and serpentRes.state == 'landed' and serpentRes.landAt == 1000.5,
			"expected the 2s serpent window to pair at 1000.5, got " .. tostring(serpentRes and (serpentRes.state .. '/' .. tostring(serpentRes.landAt))))
		assert(rakeRes == nil,
			"expected the 0.9 rake window to refuse the 1.5s delta, got " .. tostring(rakeRes))
		assert(rakeSeededState == 'expired',
			"expected the stale rake intent purged to expired, got " .. tostring(rakeSeededState))
	end, true)

	macroTorch.SelfTest:register("Cat Q-15: renewal entry bypasses the cast-dimension dedup", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		macroTorch.show = function() end
		local pcallRes = true
		local rakeLandTop, rakeLandSize
		pcallRes = pcall(function()
			local seedCast = 5.0
			fakeLoginContext.castTable = {}
			fakeLoginContext.castTable['Rake'] = {}
			fakeLoginContext.castTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
			fakeLoginContext.castTable['Rake']['QTestMob'].push(seedCast)
			fakeLoginContext.landTable = {}
			fakeLoginContext.landTable['Rake'] = {}
			fakeLoginContext.landTable['Rake']['QTestMob'] = macroTorch.LRUStack:new(100)
			fakeLoginContext.landTable['Rake']['QTestMob'].push(5.3)
			-- the ordinary entry drops the 5.6 rewrite (the cast is already
			-- covered by the 5.3 land); the exempt renewal entry must push it
			macroTorch.recordLandEvent('Rake', 5.6)
			macroTorch.recordLandEventRenewal('Rake', 5.6)
			rakeLandTop = fakeLoginContext.landTable['Rake']['QTestMob'].top
			rakeLandSize = macroTorch.tableLen(fakeLoginContext.landTable['Rake']['QTestMob'].elements)
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-15 pcall failed")
		assert(rakeLandTop == 5.6,
			"expected the renewal entry to land the 5.6 rewrite, got " .. tostring(rakeLandTop))
		assert(rakeLandSize == 2,
			"expected the 5.3 evidence kept plus the 5.6 rewrite, got " .. tostring(rakeLandSize))
	end, true)

	macroTorch.SelfTest:register("Cat Q-16: remote late arrival — apply 1s after cast pairs under the 2s sting window", function()
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local savedShow = macroTorch.show
		local fakeLoginContext = {}
		local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
		macroTorch.loginContext = fakeLoginContext
		macroTorch.target = fakeTarget
		macroTorch.show = function() end
		local pcallRes = true
		local intentResult, stingLandTop
		pcallRes = pcall(function()
			-- no castTable seeded on purpose: the 1.0s delta exceeds the 0.9
			-- default but fits the 2s ballistic sting window, and the absent
			-- cast record proves the dedup predicate never blocks this land
			fakeLoginContext.intentTable = {}
			fakeLoginContext.intentTable['Serpent Sting'] = {}
			fakeLoginContext.intentTable['Serpent Sting']['QTestMob'] = macroTorch.LRUStack:new(32)
			fakeLoginContext.intentTable['Serpent Sting']['QTestMob'].push({ state = 'pending', castAt = 999.0, landAt = nil, ttl = 2 })
			intentResult = macroTorch.processRawAuraApply('Serpent Sting',
				'0xF1300000000000AB is afflicted by Serpent Sting.', '0xf1300000000000ab', 1000.0)
			stingLandTop = fakeLoginContext.landTable['Serpent Sting']['QTestMob'].top
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.target = savedTarget
		macroTorch.show = savedShow
		assert(pcallRes, "Q-16 pcall failed")
		assert(intentResult ~= nil and intentResult.state == 'landed' and intentResult.landAt == 1000.0,
			"expected the 2s sting window to pair the 1s-late apply at 1000.0, got " .. tostring(intentResult and (intentResult.state .. '/' .. tostring(intentResult.landAt))))
		assert(stingLandTop == 1000.0,
			"expected the sting land top 1000.0, got " .. tostring(stingLandTop))
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

	-- Category S-05+ (phase 30): stubbed pins of the cpBuild DKI state machine (D-04 transitions, D-01 switch gate, both bypasses) under CR-01 discipline
	macroTorch.SelfTest:register("Cat S-05: DKI WAIT_ANCHOR anchors on a 3-to-1 down-jump", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local gcpCalls = 0
		local stateAfter
		local t0After
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = true
		macroTorch.inCombat = true
		macroTorch.cpBuildDki = { state = 'WAIT_ANCHOR', t0 = nil, prevCp = nil }
		macroTorch.target = { isCanAttack = false }
		GetTime = function()
			return 42.5
		end
		-- the seeding tick records prevCp = 3, the second tick lands the anchor on 1
		GetComboPoints = function()
			gcpCalls = gcpCalls + 1
			if gcpCalls == 1 then
				return 3
			end
			return 1
		end
		local pcallRes = pcall(function()
			macroTorch.cpBuildDkiTick()
			macroTorch.cpBuildDkiTick()
			stateAfter = macroTorch.cpBuildDki.state
			t0After = macroTorch.cpBuildDki.t0
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-05 pcall failed")
		assert(stateAfter == 'BUILDING', "S-05 expected the 3-to-1 down-jump to anchor into BUILDING, got " .. tostring(stateAfter))
		assert(t0After == 42.5, "S-05 expected the anchor time to be the stubbed 42.5, got " .. tostring(t0After))
		assert(macroTorch.tableLen(captured) == 0, "S-05 anchoring must not log anything, got " .. tostring(macroTorch.tableLen(captured)))
	end, true)

	macroTorch.SelfTest:register("Cat S-06: DKI cp=0 back-look anchors alive target, cancels dead target", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local gcpCalls = 0
		local anchorState
		local anchorT0
		local cancelState
		local cancelT0
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = true
		macroTorch.inCombat = true
		macroTorch.target = { isCanAttack = true }
		GetTime = function()
			return 42.5
		end
		GetComboPoints = function()
			gcpCalls = gcpCalls + 1
			if gcpCalls == 1 then
				return 2
			end
			return 0
		end
		local pcallRes = pcall(function()
			-- drive (a): the 2-to-0 down-jump on an attackable target anchors
			macroTorch.cpBuildDki = { state = 'WAIT_ANCHOR', t0 = nil, prevCp = nil }
			macroTorch.cpBuildDkiTick()
			macroTorch.cpBuildDkiTick()
			anchorState = macroTorch.cpBuildDki.state
			anchorT0 = macroTorch.cpBuildDki.t0
			-- drive (b): the same down-jump on a dead target cancels instead
			macroTorch.cpBuildDki = { state = 'WAIT_ANCHOR', t0 = nil, prevCp = nil }
			macroTorch.target = { isCanAttack = false }
			gcpCalls = 0
			macroTorch.cpBuildDkiTick()
			macroTorch.cpBuildDkiTick()
			cancelState = macroTorch.cpBuildDki.state
			cancelT0 = macroTorch.cpBuildDki.t0
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-06 pcall failed")
		assert(anchorState == 'BUILDING', "S-06 expected the alive-target back-look to anchor into BUILDING, got " .. tostring(anchorState))
		assert(anchorT0 == 42.5, "S-06 expected the anchor time to be the stubbed 42.5, got " .. tostring(anchorT0))
		assert(cancelState == 'WAIT_ANCHOR', "S-06 expected the dead-target back-look to cancel, got " .. tostring(cancelState))
		assert(cancelT0 == nil, "S-06 expected no anchor time on a cancelled candidate, got " .. tostring(cancelT0))
		assert(macroTorch.tableLen(captured) == 0, "S-06 the back-look must not log anything, got " .. tostring(macroTorch.tableLen(captured)))
	end, true)

	macroTorch.SelfTest:register("Cat S-07: DKI BUILDING re-reach of 5 persists one ok line and goes DONE", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local lineCount
		local doneState
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = true
		macroTorch.inCombat = true
		macroTorch.cpBuildDki = { state = 'BUILDING', t0 = 99.0, prevCp = 4 }
		macroTorch.target = { isCanAttack = false }
		GetTime = function()
			return 105.5
		end
		GetComboPoints = function()
			return 5
		end
		local pcallRes = pcall(function()
			macroTorch.cpBuildDkiTick()
			lineCount = macroTorch.tableLen(captured)
			doneState = macroTorch.cpBuildDki.state
			macroTorch.cpBuildDkiTick()
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-07 pcall failed")
		assert(lineCount == 1, "S-07 expected exactly one ok line, got " .. tostring(lineCount))
		assert(captured[1] == '[cpBuildT] ok t=6.500', "S-07 expected the ok line [cpBuildT] ok t=6.500, got " .. tostring(captured[1]))
		assert(doneState == 'DONE', "S-07 expected the re-reach of 5 to move the machine to DONE, got " .. tostring(doneState))
		assert(macroTorch.tableLen(captured) == 1, "S-07 DONE must stay silent on a second tick, got " .. tostring(macroTorch.tableLen(captured)))
	end, true)

	macroTorch.SelfTest:register("Cat S-08: DKI BUILDING mid-window down-jump emits fail and re-anchors", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local stateAfter
		local t0After
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = true
		macroTorch.inCombat = true
		macroTorch.cpBuildDki = { state = 'BUILDING', t0 = 99.0, prevCp = 4 }
		macroTorch.target = { isCanAttack = false }
		GetTime = function()
			return 110.0
		end
		GetComboPoints = function()
			return 1
		end
		local pcallRes = pcall(function()
			macroTorch.cpBuildDkiTick()
			stateAfter = macroTorch.cpBuildDki.state
			t0After = macroTorch.cpBuildDki.t0
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-08 pcall failed")
		assert(macroTorch.tableLen(captured) == 1, "S-08 expected exactly one fail line, got " .. tostring(macroTorch.tableLen(captured)))
		assert(captured[1] == '[cpBuildT] fail', "S-08 expected the fail line [cpBuildT] fail, got " .. tostring(captured[1]))
		assert(stateAfter == 'BUILDING', "S-08 expected the mid-window down-jump to stay in BUILDING, got " .. tostring(stateAfter))
		assert(t0After == 110.0, "S-08 expected the re-anchor time to be the stubbed 110.0, got " .. tostring(t0After))
	end, true)

	macroTorch.SelfTest:register("Cat S-09: DKI kill-shot truncation emits fail and returns to WAIT_ANCHOR", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local stateAfter
		local t0After
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = true
		macroTorch.inCombat = true
		macroTorch.cpBuildDki = { state = 'BUILDING', t0 = 99.0, prevCp = 3 }
		macroTorch.target = { isCanAttack = false }
		GetTime = function()
			return 110.0
		end
		GetComboPoints = function()
			return 0
		end
		local pcallRes = pcall(function()
			macroTorch.cpBuildDkiTick()
			stateAfter = macroTorch.cpBuildDki.state
			t0After = macroTorch.cpBuildDki.t0
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-09 pcall failed")
		assert(macroTorch.tableLen(captured) == 1, "S-09 expected exactly one fail line, got " .. tostring(macroTorch.tableLen(captured)))
		assert(captured[1] == '[cpBuildT] fail', "S-09 expected the fail line [cpBuildT] fail, got " .. tostring(captured[1]))
		assert(stateAfter == 'WAIT_ANCHOR', "S-09 expected the kill-shot truncation to return to WAIT_ANCHOR, got " .. tostring(stateAfter))
		assert(t0After == nil, "S-09 expected a pristine WAIT_ANCHOR with no anchor time, got " .. tostring(t0After))
	end, true)

	macroTorch.SelfTest:register("Cat S-10: DKI DONE stays silent until the next down-jump re-anchors", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local gcpCalls = 0
		local stateMid
		local stateAfter
		local t0After
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = true
		macroTorch.inCombat = true
		macroTorch.cpBuildDki = { state = 'DONE', t0 = nil, prevCp = 5 }
		macroTorch.target = { isCanAttack = false }
		GetTime = function()
			return 66.0
		end
		GetComboPoints = function()
			gcpCalls = gcpCalls + 1
			if gcpCalls == 1 then
				return 5
			end
			return 1
		end
		local pcallRes = pcall(function()
			macroTorch.cpBuildDkiTick()
			stateMid = macroTorch.cpBuildDki.state
			macroTorch.cpBuildDkiTick()
			stateAfter = macroTorch.cpBuildDki.state
			t0After = macroTorch.cpBuildDki.t0
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-10 pcall failed")
		assert(stateMid == 'DONE', "S-10 expected a steady 5 count in DONE to stay silent, got " .. tostring(stateMid))
		assert(stateAfter == 'BUILDING', "S-10 expected the next down-jump in DONE to re-anchor into BUILDING, got " .. tostring(stateAfter))
		assert(t0After == 66.0, "S-10 expected the re-anchor time to be the stubbed 66.0, got " .. tostring(t0After))
		assert(macroTorch.tableLen(captured) == 0, "S-10 DONE must not log anything across both ticks, got " .. tostring(macroTorch.tableLen(captured)))
	end, true)

	macroTorch.SelfTest:register("Cat S-11: DKI global reset discards the active window to WAIT_ANCHOR", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local stateAfter
		local t0After
		local prevCpAfter
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = true
		macroTorch.inCombat = true
		macroTorch.cpBuildDki = { state = 'BUILDING', t0 = 123.0, prevCp = 3 }
		macroTorch.target = { isCanAttack = false }
		GetTime = function()
			return 123.0
		end
		GetComboPoints = function()
			return 1
		end
		local pcallRes = pcall(function()
			-- the reset is driven directly, the poll stubs stay idle on purpose
			macroTorch.resetCpBuildDki()
			stateAfter = macroTorch.cpBuildDki.state
			t0After = macroTorch.cpBuildDki.t0
			prevCpAfter = macroTorch.cpBuildDki.prevCp
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-11 pcall failed")
		assert(stateAfter == 'WAIT_ANCHOR', "S-11 expected the global reset to return to WAIT_ANCHOR, got " .. tostring(stateAfter))
		assert(t0After == nil, "S-11 expected the global reset to discard the anchor time, got " .. tostring(t0After))
		assert(prevCpAfter == nil, "S-11 expected the global reset to discard prevCp, got " .. tostring(prevCpAfter))
		assert(macroTorch.tableLen(captured) == 0, "S-11 the global reset must not log anything, got " .. tostring(macroTorch.tableLen(captured)))
	end, true)

	macroTorch.SelfTest:register("Cat S-12: DKI tick is zero-API when the switch is off or combat is idle", function()
		local savedGCP = GetComboPoints
		local savedGTime = GetTime
		local savedLog = macroTorch.log
		local savedInCombat = macroTorch.inCombat
		local savedCpBuildLog = macroTorch.cpBuildLog
		local savedTarget = macroTorch.target
		local savedDki = macroTorch.cpBuildDki
		local captured = {}
		local gcpCalls = 0
		local callsOff
		local callsIdle
		local callsControl
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpBuildLog = false
		macroTorch.inCombat = true
		macroTorch.cpBuildDki = { state = 'WAIT_ANCHOR', t0 = nil, prevCp = nil }
		macroTorch.target = { isCanAttack = false }
		GetTime = function()
			return 42.5
		end
		GetComboPoints = function()
			gcpCalls = gcpCalls + 1
			return 3
		end
		local pcallRes = pcall(function()
			-- the three arms differ only in the two cheap-first gates (D-01)
			macroTorch.cpBuildDkiTick()
			callsOff = gcpCalls
			macroTorch.cpBuildLog = true
			macroTorch.inCombat = false
			gcpCalls = 0
			macroTorch.cpBuildDkiTick()
			callsIdle = gcpCalls
			macroTorch.inCombat = true
			gcpCalls = 0
			macroTorch.cpBuildDkiTick()
			callsControl = gcpCalls
		end)
		GetComboPoints = savedGCP
		GetTime = savedGTime
		macroTorch.log = savedLog
		macroTorch.inCombat = savedInCombat
		macroTorch.cpBuildLog = savedCpBuildLog
		macroTorch.target = savedTarget
		macroTorch.cpBuildDki = savedDki
		assert(pcallRes, "S-12 pcall failed")
		assert(callsOff == 0, "S-12 expected zero GetComboPoints calls with the switch off, got " .. tostring(callsOff))
		assert(callsIdle == 0, "S-12 expected zero GetComboPoints calls while combat is idle, got " .. tostring(callsIdle))
		assert(callsControl == 1, "S-12 expected exactly one GetComboPoints call in the control arm, got " .. tostring(callsControl))
		assert(macroTorch.tableLen(captured) == 0, "S-12 expected no log lines across all three arms, got " .. tostring(macroTorch.tableLen(captured)))
	end, true)

	-- Registration count: Category S adds 12 tests (quick 260907-0ya + WR-01 fix + phase 30 DKI 8 tests)
	-- Category T: macroTorch.log persistence buffer cap (quick 260907-vve) + show() render-hue mapping (29-04 gap closure G-29-3, 2 tests)
	-- T-01 mirrors Cat S-01: pure default-value assert, read-only, no stubs,
	-- isOptional=true. It passes on a fresh login (the macro_torch.lua nil-guard
	-- has just re-armed 500); if the session overrode the value the failure is
	-- expected and informative - the same trade-off Cat S-01 accepted.
	macroTorch.SelfTest:register("Cat T-01: LOG_MAX_SIZE defaults to 500", function()
		assert(macroTorch.LOG_MAX_SIZE == 500,
			"LOG_MAX_SIZE should default to 500, got " .. tostring(macroTorch.LOG_MAX_SIZE))
	end, true)

	-- T-02 drives the REAL macroTorch.show: the Q-series tests replace show
	-- with a label-capturing stub, so the color-name -> render-hue mapping
	-- table inside show had zero coverage. Only show's two downstream
	-- consumers are planted (CR-01: snapshot, plant, pcall, restore before
	-- any assert); the mapping arms run for real, so a hue inverted in any
	-- arm turns this test red/yellow (G-29-3 gap closure).
	macroTorch.SelfTest:register("Cat T-02: show() color names resolve to matching hue-dominant channels", function()
		local savedDF = DEFAULT_CHAT_FRAME
		local savedCTI = ChatTypeInfo
		local captured = {}
		DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg, r, g, b, id)
			table.insert(captured, { r = r, g = g, b = b, id = id })
		end }
		-- vanilla-shaped stand-ins with one unique id per key: SAY carries the
		-- default arm, YELL/SYSTEM feed the red/yellow arms, OFFICER/GUILD stay
		-- planted for future variant compatibility.
		ChatTypeInfo = {
			SAY = { r = 0.5, g = 0.5, b = 0.5, id = 'planted_say' },
			YELL = { r = 1, g = 0.5, b = 0, id = 'planted_yell' },
			SYSTEM = { r = 1, g = 1, b = 0, id = 'planted_system' },
			OFFICER = { r = 0.25, g = 1, b = 0.25, id = 'planted_officer' },
			GUILD = { r = 0.25, g = 1, b = 0.25, id = 'planted_guild' },
		}
		local pcallRes = pcall(function()
			macroTorch.show('probe', nil)
			macroTorch.show('probe', 'red')
			macroTorch.show('probe', 'yellow')
			macroTorch.show('probe', 'blue')
			macroTorch.show('probe', 'green')
		end)
		DEFAULT_CHAT_FRAME = savedDF
		ChatTypeInfo = savedCTI
		local cap1 = captured[1]
		local cap2 = captured[2]
		local cap3 = captured[3]
		local cap4 = captured[4]
		local cap5 = captured[5]
		assert(pcallRes, "T-02 pcall failed")
		assert(cap1 and cap1.id == 'planted_say',
			"T-02 default arm should resolve to the planted SAY channel, got " .. tostring(cap1 and cap1.id))
		assert(cap2 and cap2.r >= cap2.g and cap2.r >= cap2.b,
			"T-02 red arm must stay red-dominant, got r=" .. tostring(cap2 and cap2.r) .. " g=" .. tostring(cap2 and cap2.g) .. " b=" .. tostring(cap2 and cap2.b))
		assert(cap3 and cap3.r >= cap3.b and cap3.g >= cap3.b,
			"T-02 yellow arm must stay warm, got r=" .. tostring(cap3 and cap3.r) .. " g=" .. tostring(cap3 and cap3.g) .. " b=" .. tostring(cap3 and cap3.b))
		assert(cap4 and cap4.b >= cap4.r and cap4.b >= cap4.g,
			"T-02 blue arm must stay blue-dominant, got r=" .. tostring(cap4 and cap4.r) .. " g=" .. tostring(cap4 and cap4.g) .. " b=" .. tostring(cap4 and cap4.b))
		assert(cap5 and cap5.g >= cap5.r and cap5.g >= cap5.b,
			"T-02 green arm must stay green-dominant, got r=" .. tostring(cap5 and cap5.r) .. " g=" .. tostring(cap5 and cap5.g) .. " b=" .. tostring(cap5 and cap5.b))
	end, true)

	-- Registration count: Category T adds 2 tests (quick 260907-vve + 29-04 gap closure G-29-3)
	-- Category U: cpDamage cast/damage log instrumentation (phase 28, 9 tests)
	-- U-04/U-05/U-06/U-07/U-08/U-09 follow the CR-01 stub discipline: snapshot via
	-- rawget, install own-key shadows, capture into locals, restore via raw
	-- assignment BEFORE any assert (Cat S-03 precedent).
	macroTorch.SelfTest:register("Cat U-01: cpDamageLog defaults to false", function()
		-- U-01 mirrors Cat T-01's trade-off: pure default-value assert, read-only,
		-- no stubs. It passes on a fresh login (the macro_torch.lua nil-guard has
		-- just re-armed false); a mid-session /run override makes it fail, which is
		-- expected and informative - the same trade-off Cat T-01 accepted.
		assert(macroTorch.cpDamageLog == false,
			"cpDamageLog should default to false, got " .. tostring(macroTorch.cpDamageLog))
	end, true)

	macroTorch.SelfTest:register("Cat U-02: jsonEncodeScalar emits strict JSON literals", function()
		local enc = macroTorch.jsonEncodeScalar
		assert(enc(nil) == 'null', "U-02 expected null, got " .. tostring(enc(nil)))
		assert(enc(true) == 'true', "U-02 expected true, got " .. tostring(enc(true)))
		assert(enc(42) == '42', "U-02 expected 42, got " .. tostring(enc(42)))
		-- the tricky string carries both a double quote and a backslash; the
		-- expected literal below is hand-written from the 28-01 encoder contract
		-- (quotes become \" and backslashes become \\)
		assert(enc('he said "hi"\\path') == '"he said \\"hi\\"\\\\path"',
			"U-02 string escaping mismatch: " .. tostring(enc('he said "hi"\\path')))
	end, true)

	macroTorch.SelfTest:register("Cat U-03: cpDamageEvent emits the fixed 11-field [cpDamage] JSON line", function()
		local savedLog = macroTorch.log
		local captured = {}
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		local pcallRes = pcall(function()
			local fixedSample = { spell = 'claw', t = 1234.5, cp = 2, energyPool = 60,
				bleedCount = 1, isOoc = false, isBehind = true, e = 42, batch = 1000 }
			macroTorch.cpDamageEvent(fixedSample, 210, false)
		end)
		macroTorch.log = savedLog
		assert(pcallRes, "U-03 pcall failed")
		assert(macroTorch.tableLen(captured) == 1,
			"U-03 expected exactly one emitted line, got " .. tostring(macroTorch.tableLen(captured)))
		-- the expected literal pins the fixed 11-field order spell dmg crit e
		-- energyPool bleedCount isOoc isBehind cp t batch - the verbatim encode/
		-- decode interop contract that the 28-03 decoder is checked against
		assert(captured[1] == '[cpDamage] {"spell":"claw","dmg":210,"crit":false,"e":42,"energyPool":60,' ..
			'"bleedCount":1,"isOoc":false,"isBehind":true,"cp":2,"t":1234.5,"batch":1000}',
			"U-03 JSON literal mismatch: " .. tostring(captured[1]))
	end, true)

	macroTorch.SelfTest:register("Cat U-04: pairCpDamageIntent pairs the newest in-window guid intent", function()
		local savedLoginContext = macroTorch.loginContext
		local fakeLoginContext = {}
		fakeLoginContext.cpDamageIntents = macroTorch.LRUStack:new(8)
		local seedSample = { spell = 'claw' }
		fakeLoginContext.cpDamageIntents.push({ spell = 'claw', guid = '0xF1300000CAFE0001',
			castAt = 1.0, sample = seedSample })
		macroTorch.loginContext = fakeLoginContext
		local paired, remaining = nil, -1
		local pcallRes = pcall(function()
			-- the lowercase guid on the damage line exercises the case-insensitive pair
			paired = macroTorch.pairCpDamageIntent('0xf1300000cafe0001', 1.5)
			remaining = 0
			for _ in ipairs(fakeLoginContext.cpDamageIntents.elements) do
				remaining = remaining + 1
			end
		end)
		macroTorch.loginContext = savedLoginContext
		assert(pcallRes, "U-04 pcall failed")
		assert(paired == seedSample, "U-04 expected the seeded sample back (reference equality)")
		assert(remaining == 0, "U-04 expected the stack drained after the pair, got " .. tostring(remaining))
	end, true)

	macroTorch.SelfTest:register("Cat U-05: stale cpDamage intent expires past the TTL (lazy purge)", function()
		local savedLoginContext = macroTorch.loginContext
		local fakeLoginContext = {}
		fakeLoginContext.cpDamageIntents = macroTorch.LRUStack:new(8)
		fakeLoginContext.cpDamageIntents.push({ spell = 'claw', guid = '0xF1300000CAFE0001',
			castAt = 1.0, sample = {} })
		macroTorch.loginContext = fakeLoginContext
		local paired, remaining = nil, -1
		local pcallRes = pcall(function()
			paired = macroTorch.pairCpDamageIntent('0xf1300000cafe0001', 5.0)
			remaining = 0
			for _ in ipairs(fakeLoginContext.cpDamageIntents.elements) do
				remaining = remaining + 1
			end
		end)
		macroTorch.loginContext = savedLoginContext
		assert(pcallRes, "U-05 pcall failed")
		assert(paired == nil, "U-05 expected nil beyond the LAND_INTENT_TTL window")
		assert(remaining == 0, "U-05 expected the purge to drain the stack, got " .. tostring(remaining))
	end, true)

	macroTorch.SelfTest:register("Cat U-06: hits damage line pairs and emits one [cpDamage] entry (crit false)", function()
		local savedLoginContext = macroTorch.loginContext
		local savedSwitch = macroTorch.cpDamageLog
		local savedLog = macroTorch.log
		local fakeLoginContext = {}
		fakeLoginContext.cpDamageIntents = macroTorch.LRUStack:new(8)
		local captured = {}
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpDamageLog = true
		local seedTime = GetTime()
		fakeLoginContext.cpDamageIntents.push({ spell = 'claw', guid = '0xF1300000CAFE0001', castAt = seedTime,
			sample = { spell = 'claw', t = seedTime, cp = 2, energyPool = 60, bleedCount = 0,
				isOoc = false, isBehind = false, e = 42, batch = 1000 } })
		macroTorch.loginContext = fakeLoginContext
		local pcallRes = pcall(function()
			macroTorch.onCpDamageLine('Your Claw hits 0xf1300000cafe0001 for 200.', GetTime())
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.log = savedLog
		macroTorch.cpDamageLog = savedSwitch
		assert(pcallRes, "U-06 pcall failed")
		assert(macroTorch.tableLen(captured) == 1,
			"U-06 expected exactly one emitted line, got " .. tostring(macroTorch.tableLen(captured)))
		assert(string.find(captured[1], '"crit":false', 1, true) ~= nil,
			"U-06 expected crit false in: " .. tostring(captured[1]))
	end, true)

	macroTorch.SelfTest:register("Cat U-07: miss line emits nothing and never consumes the intent (D-03)", function()
		local savedLoginContext = macroTorch.loginContext
		local savedSwitch = macroTorch.cpDamageLog
		local savedLog = macroTorch.log
		local fakeLoginContext = {}
		fakeLoginContext.cpDamageIntents = macroTorch.LRUStack:new(8)
		local captured = {}
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpDamageLog = true
		local seedTime = GetTime()
		fakeLoginContext.cpDamageIntents.push({ spell = 'claw', guid = '0xF1300000CAFE0001', castAt = seedTime,
			sample = { spell = 'claw', t = seedTime, cp = 2, energyPool = 60, bleedCount = 0,
				isOoc = false, isBehind = false, e = 42, batch = 1000 } })
		macroTorch.loginContext = fakeLoginContext
		local remaining = -1
		local remainingAfterRake = -1
		local pcallRes = pcall(function()
			macroTorch.onCpDamageLine('Your Claw was dodged by 0xf1300000cafe0001.', GetTime())
			remaining = 0
			for _ in ipairs(fakeLoginContext.cpDamageIntents.elements) do
				remaining = remaining + 1
			end
			-- WR-02: a Rake damage line (Rake is not cpDamage-sampled) is
			-- dropped by the spell whitelist and must NOT consume the pending
			-- claw intent the dodge line left behind.
			macroTorch.onCpDamageLine('Your Rake hits 0xf1300000cafe0001 for 150.', GetTime())
			remainingAfterRake = 0
			for _ in ipairs(fakeLoginContext.cpDamageIntents.elements) do
				remainingAfterRake = remainingAfterRake + 1
			end
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.log = savedLog
		macroTorch.cpDamageLog = savedSwitch
		assert(pcallRes, "U-07 pcall failed")
		assert(macroTorch.tableLen(captured) == 0,
			"U-07 expected zero emitted lines for a dodge, got " .. tostring(macroTorch.tableLen(captured)))
		assert(remaining == 1, "U-07 expected the dodge NOT to consume the intent, got " .. tostring(remaining))
		assert(remainingAfterRake == 1,
			"U-07 expected the Rake line NOT to consume the claw intent (WR-02), got " .. tostring(remainingAfterRake))
	end, true)

	macroTorch.SelfTest:register("Cat U-08: crits damage line marks crit true in the [cpDamage] JSON", function()
		local savedLoginContext = macroTorch.loginContext
		local savedSwitch = macroTorch.cpDamageLog
		local savedLog = macroTorch.log
		local fakeLoginContext = {}
		fakeLoginContext.cpDamageIntents = macroTorch.LRUStack:new(8)
		local captured = {}
		macroTorch.log = function(a)
			table.insert(captured, tostring(a))
		end
		macroTorch.cpDamageLog = true
		local seedTime = GetTime()
		fakeLoginContext.cpDamageIntents.push({ spell = 'claw', guid = '0xF1300000CAFE0001', castAt = seedTime,
			sample = { spell = 'claw', t = seedTime, cp = 2, energyPool = 60, bleedCount = 0,
				isOoc = false, isBehind = false, e = 42, batch = 1000 } })
		macroTorch.loginContext = fakeLoginContext
		local pcallRes = pcall(function()
			macroTorch.onCpDamageLine('Your Claw crits 0xf1300000cafe0001 for 300.', GetTime())
		end)
		macroTorch.loginContext = savedLoginContext
		macroTorch.log = savedLog
		macroTorch.cpDamageLog = savedSwitch
		assert(pcallRes, "U-08 pcall failed")
		assert(macroTorch.tableLen(captured) == 1,
			"U-08 expected exactly one emitted line, got " .. tostring(macroTorch.tableLen(captured)))
		assert(string.find(captured[1], '"crit":true', 1, true) ~= nil,
			"U-08 expected crit true in: " .. tostring(captured[1]))
	end, true)

	macroTorch.SelfTest:register("Cat U-09: claw() plants a cpDamage intent on the Training Dummy only (D-05)", function()
		local player = macroTorch.player
		local savedSwitch = macroTorch.cpDamageLog
		local savedBuildLog = macroTorch.cpBuildLog
		local savedContext = macroTorch.context
		local savedLoginContext = macroTorch.loginContext
		local savedTarget = macroTorch.target
		local savedLog = macroTorch.log
		local savedCast = rawget(player, '_castSpell')
		local savedActionCd = rawget(player, 'isActionCooledDown')
		macroTorch.log = function() end
		macroTorch.cpDamageLog = true
		macroTorch.cpBuildLog = false
		macroTorch.context = { _cpDamageBatch = GetTime() }
		local fakeLoginContext = {}
		macroTorch.loginContext = fakeLoginContext
		player._castSpell = function()
			return true
		end
		player.isActionCooledDown = function()
			return true
		end
		local dummyTarget = { name = 'Training Dummy', isCanAttack = true, guid = '0xTEST',
			hasBuff = function(self) return false end }
		local mobTarget = { name = 'QTestMob', isCanAttack = true, guid = '0xTEST',
			hasBuff = function(self) return false end }
		local nDummy, nMob = -1, -1
		local pcallRes = pcall(function()
			macroTorch.target = dummyTarget
			player.claw('ready')
			nDummy = 0
			if fakeLoginContext.cpDamageIntents then
				for _ in ipairs(fakeLoginContext.cpDamageIntents.elements) do
					nDummy = nDummy + 1
				end
			end
			macroTorch.target = mobTarget
			player.claw('ready')
			nMob = 0
			if fakeLoginContext.cpDamageIntents then
				for _ in ipairs(fakeLoginContext.cpDamageIntents.elements) do
					nMob = nMob + 1
				end
			end
		end)
		rawset(player, '_castSpell', savedCast)
		rawset(player, 'isActionCooledDown', savedActionCd)
		macroTorch.log = savedLog
		macroTorch.target = savedTarget
		macroTorch.loginContext = savedLoginContext
		macroTorch.context = savedContext
		macroTorch.cpDamageLog = savedSwitch
		macroTorch.cpBuildLog = savedBuildLog
		assert(pcallRes, "U-09 pcall failed")
		assert(nDummy == 1, "U-09 expected one planted intent on the dummy, got " .. tostring(nDummy))
		assert(nMob == 1, "U-09 expected no growth on a non-dummy target, got " .. tostring(nMob))
	end, true)

	-- Registration count: Category U adds 9 tests (phase 28-02)
end
