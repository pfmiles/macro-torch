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

-- unified metatable factory — replaces hand-written 9-line setmetatable + __index templates
-- per D-01: simplest factory, 1:1 mapping of current pattern to a single function call
-- per D-03: fieldMapName accepts a string, looked up via macroTorch[fieldMapName]
-- per D-12/D-13: cls can be nil (e.g. LRUStack has no parent class), nil-guard skips class fallback
function macroTorch.classMetatable(cls, fieldMapName)
    return {
        __index = function(t, k)
            -- step 1: instance-specific FIELD_FUNC_MAP lookup
            if fieldMapName and macroTorch[fieldMapName] and macroTorch[fieldMapName][k] ~= nil then
                return macroTorch[fieldMapName][k](t)
            end
            -- step 2: class method/field fallback (nil-guard per D-12/D-13)
            if cls then
                return cls[k]
            end
        end
    }
end

-- lazy registry for polymorphic player initialization
-- per D-04: empty table initialized in core/class.lua
macroTorch.PLAYER_CLASS_REGISTRY = {}

-- per D-04/D-05: registers a class entry in the polymorphic player registry
-- @param className  string — the UnitClass name (e.g. "DRUID", "HUNTER")
-- @param classTable table  — the class prototype table (e.g. macroTorch.Druid)
function macroTorch.registerPlayerClass(className, classTable)
    macroTorch.PLAYER_CLASS_REGISTRY[className] = classTable
end

-- per D-06/D-08: polymorphic player factory
-- looks up PLAYER_CLASS_REGISTRY by UnitClass('player'), calls :new() if found,
-- otherwise falls back to macroTorch.Player:new()
-- note: does NOT assign to macroTorch.player — assignment stays at each call site
--       (per D-08, Player.lua retains the default initialization)
function macroTorch.initPlayer()
    local className = UnitClass('player')
    local entry = macroTorch.PLAYER_CLASS_REGISTRY[className]
    if entry then
        return entry:new()
    end
    return macroTorch.Player:new()
end