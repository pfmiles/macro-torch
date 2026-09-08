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
-- Cower worldboss threat threshold (quick 260907-tuh): 75 percent by default,
-- set macroTorch.COWER_THREAT_THRESHOLD = 80 in game (SuperMacro body) to tune
-- the threat percent at which a worldboss catAtk answers with Cower. The
-- nil-guard re-arms the default on every login; a /run override lasts only
-- for the current session (no SavedVariables persistence), same as the two
-- boolean options above.
if macroTorch.COWER_THREAT_THRESHOLD == nil then
    macroTorch.COWER_THREAT_THRESHOLD = 75
end
-- macroTorch.log persistence buffer entry cap (quick 260907-vve): 500 by default,
-- set macroTorch.LOG_MAX_SIZE = 1000 in game (SuperMacro body) to keep more log
-- lines before the macroTorch.log trim loop drops entries. The nil-guard re-arms
-- the default on every login; a /run override lasts only for the current session
-- (no SavedVariables persistence), same as the three options above. The consumer
-- sanitizes the value (tonumber plus a clamp to at least 1) in macroTorch.log,
-- so the trim loop can never hang on an odd override.
if macroTorch.LOG_MAX_SIZE == nil then
    macroTorch.LOG_MAX_SIZE = 500
end
-- cat claw/shred/bite damage sample log switch (phase 28): false by default,
-- set macroTorch.cpDamageLog = true in game (SuperMacro body) to record every
-- Training-Dummy claw/shred/bite hit as a [cpDamage] JSON line through
-- macroTorch.log for the offline analyzer (tools/cpdamage.lua). The nil-guard
-- re-arms the default on every login; toggling mid-session needs no reload.
if macroTorch.cpDamageLog == nil then
    macroTorch.cpDamageLog = false
end
-- Per-login re-arm of the one-time GCD-probe diagnostic (WR-01 fix): reset here,
-- in the addon-load path, so a UI reload surfaces a fresh probe warning instead
-- of inheriting a stale worn flag from the previous session.
macroTorch._cpBuildLogProbeWarned = nil
-- Per-login re-arm of the one-time cpDamage GCD-probe diagnostic (phase 28):
-- same pattern as the cpBuildLog flag above, so a UI reload surfaces a fresh
-- probe warning instead of inheriting a stale worn flag.
macroTorch._cpDamageProbeWarned = nil

-- Global config options registry and login banner (quick 260907-sz4). A complete
-- survey of user-tunable globals yields exactly these five entries; a future option
-- is surfaced by appending one registry entry. The banner only reads values through
-- the explicit getters below — the nil-guards above stay the only assignments.
macroTorch.CONFIG_OPTIONS = {
    {
        name = 'macroTorch.cpBuildLog',
        default = false,
        desc = 'combo-point build cast log switch (Claw/Shred/Rake interval samples)',
        cmd = '/run macroTorch.cpBuildLog=true',
        get = function() return macroTorch.cpBuildLog end,
    },
    {
        name = 'macroTorch.rawdiag2Enabled',
        default = false,
        desc = 'RAWDIAG2 Rip landing forensics master switch',
        cmd = '/run macroTorch.rawdiag2Enabled=true',
        get = function() return macroTorch.rawdiag2Enabled end,
    },
    {
        name = 'macroTorch.COWER_THREAT_THRESHOLD',
        default = 75,
        desc = 'worldboss Cower threat percent trigger threshold (Cower fires when threat is at or above it)',
        cmd = '/run macroTorch.COWER_THREAT_THRESHOLD=80',
        get = function() return macroTorch.COWER_THREAT_THRESHOLD end,
    },
    {
        name = 'macroTorch.LOG_MAX_SIZE',
        default = 500,
        desc = 'macroTorch.log persistence buffer entry cap',
        cmd = '/run macroTorch.LOG_MAX_SIZE=1000',
        get = function() return macroTorch.LOG_MAX_SIZE end,
    },
    {
        name = 'macroTorch.cpDamageLog',
        default = false,
        desc = 'cat claw/shred/bite damage sample log switch ([cpDamage] entries for the offline analyzer)',
        cmd = '/run macroTorch.cpDamageLog=true',
        get = function() return macroTorch.cpDamageLog end,
    },
}
-- prints every registered config option with its current value, default and the
-- in-game setter command; read-only, never errors when a getter fails (pcall).
function macroTorch.printConfigBanner()
    macroTorch.show('[macro-torch] === Global Config Options ===', 'white')
    for _, opt in ipairs(macroTorch.CONFIG_OPTIONS) do
        local current = 'unavailable'
        local ok, v = pcall(opt.get)
        if ok then
            current = tostring(v)
        end
        macroTorch.show('[macro-torch] ' .. opt.name .. ' = ' .. current ..
            ' (default: ' .. tostring(opt.default) .. ') - ' .. opt.desc, 'yellow')
        macroTorch.show('[macro-torch]    set: ' .. opt.cmd, 'yellow')
    end
    macroTorch.show('[macro-torch] === End Config Options ===', 'white')
end
