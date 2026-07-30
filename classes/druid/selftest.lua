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

-- End of Batch 1 -- Batch 2 tests go below (added in plan 22-02)

end