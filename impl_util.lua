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

-- 检查字符串是否包含集合中的任意关键字
local function containsAnyKeyword(str, kwdList)
    if not str then return false end
    for _, keyword in ipairs(kwdList) do
        if string.find(str, keyword) then
            return true
        end
    end
    return false
end

