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