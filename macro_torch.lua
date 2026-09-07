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

-- some machanisms impl
if not macroTorch then
    macroTorch = {}
end

-- combo-point building cast log switch (quick 260907-0ya): false by default, set
-- macroTorch.cpBuildLog = true in game (SuperMacro body) to record every accepted
-- Claw/Shred/Rake cast through macroTorch.log for offline interval analysis.
-- The nil-guard re-arms the default on every login; toggling mid-session needs no reload.
if macroTorch.cpBuildLog == nil then
    macroTorch.cpBuildLog = false
end
-- RAWDIAG2 forensics master switch (quick 260907-mhh WR-02 fix): false by default,
-- set macroTorch.rawdiag2Enabled = true in game (SuperMacro body) to arm the Rip
-- landing forensics scout on every recorded in-combat Rip cast (and the safeRip ctx
-- stamp). The nil-guard re-arms the default on every login; toggling mid-session
-- needs no reload so incidental fights between the test and the log export stay silent.
if macroTorch.rawdiag2Enabled == nil then
    macroTorch.rawdiag2Enabled = false
end
-- Per-login re-arm of the one-time GCD-probe diagnostic (WR-01 fix): reset here,
-- in the addon-load path, so a UI reload surfaces a fresh probe warning instead
-- of inheriting a stale worn flag from the previous session.
macroTorch._cpBuildLogProbeWarned = nil
