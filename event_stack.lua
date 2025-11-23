macroTorch.LRUStack = {}

function macroTorch.LRUStack:new(maxSize)
    local obj = {
        maxSize = maxSize,
        elements = {},
    }

    setmetatable(obj, {
        -- k is the key of searching field, and t is the table itself
        __index = function(t, k)
            -- missing instance field search
            if macroTorch.ES_FIELD_FUNC_MAP[k] then
                return macroTorch.ES_FIELD_FUNC_MAP[k](t)
            end
            -- class field & method search
            local class_val = self[k]
            if class_val then
                return class_val
            end
        end
    })

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
