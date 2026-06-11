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

-- LRUStack — a bounded LRU-style stack with metatable-driven accessor fields
-- migrated from event_stack.lua per D-12/D-13
macroTorch.LRUStack = {}

function macroTorch.LRUStack:new(maxSize)
    local obj = {
        maxSize = maxSize,
        elements = {},
    }

    -- per D-12/D-13: use classMetatable(nil, ...) instead of hand-written metatable
    -- cls=nil because LRUStack has no parent class
    setmetatable(obj, macroTorch.classMetatable(nil, "ES_FIELD_FUNC_MAP"))

    function obj.push(event)
        while macroTorch.tableLen(obj.elements) >= obj.maxSize do
            table.remove(obj.elements, 1)
        end
        table.insert(obj.elements, event)
    end

    function obj.pop()
        if macroTorch.tableLen(obj.elements) == 0 then
            return nil
        end
        return table.remove(obj.elements, macroTorch.tableLen(obj.elements))
    end

    function obj.anyMatch(predicate)
        for _, event in ipairs(obj.elements) do
            if predicate(event) then
                return true
            end
        end
        return false
    end

    function obj.allMatch(predicate)
        for _, event in ipairs(obj.elements) do
            if not predicate(event) then
                return false
            end
        end
        return true
    end

    return obj
end

macroTorch.ES_FIELD_FUNC_MAP = {
    ['size'] = function(self)
        return macroTorch.tableLen(self.elements)
    end,
    ['top'] = function(self)
        local len = macroTorch.tableLen(self.elements)
        if len == 0 then
            return nil
        end
        return self.elements[len]
    end,

    ['isEmpty'] = function(self)
        return macroTorch.tableLen(self.elements) == 0
    end,
}

-- periodic task scheduling system
-- migrated from battle_event_queue.lua per D-14/D-15
-- uses independent OnUpdate Frame (not shared with battle_event_queue.lua)

-- DEBUG: init trace step 5a — before CreateFrame
DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step 5a: before CreateFrame", 0, 1, 0)
local frame = CreateFrame("Frame")
-- DEBUG: init trace step 5b — after CreateFrame
DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step 5b: after CreateFrame ok", 0, 1, 0)

-- sets the fixed periodic logic
frame.lastUpdate = 0
frame.leastUpdateInterval = 0.1
if not macroTorch.periodicTasks then
    macroTorch.periodicTasks = {}
end

function macroTorch.onPeriodicUpdate()
    -- on periodic update
    local expired = {}
    for name, task in pairs(macroTorch.periodicTasks) do
        if GetTime() - frame.lastUpdate >= task.interval then
            if not task.times or task.times > 0 then
                if task.times then
                    task.times = task.times - 1
                end
                task.task()
            else
                table.insert(expired, name)
            end
        end
    end
    for _, name in ipairs(expired) do
        macroTorch.removePeriodicTask(name)
    end
end

function macroTorch.registerPeriodicTask(name, task)
    macroTorch.periodicTasks[name] = task
end

function macroTorch.removePeriodicTask(name)
    macroTorch.periodicTasks[name] = nil
end

-- sets a function to run specified times with specified interval
function macroTorch.setRepeat(name, interval, times, func)
    macroTorch.registerPeriodicTask(name, { interval = interval, times = times, task = func })
end

-- DEBUG: init trace step 5c — before SetScript(OnUpdate)
DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step 5c: before SetScript(OnUpdate)", 0, 1, 0)
frame:SetScript("OnUpdate", function()
    if GetTime() - frame.lastUpdate >= frame.leastUpdateInterval then
        -- 使用pcall安全执行onPeriodicUpdate，确保后续代码一定执行
        local success, errorMsg = pcall(macroTorch.onPeriodicUpdate)
        if not success then
            -- 记录错误但不中断执行
            macroTorch.show("onPeriodicUpdate执行错误: " .. tostring(errorMsg), "red")
        end
        frame.lastUpdate = GetTime()
    end
end)
-- DEBUG: init trace step 5d — after SetScript(OnUpdate)
DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step 5d: after SetScript(OnUpdate) ok", 0, 1, 0)