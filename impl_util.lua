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
function macroTorch.containsAnyKeyword(str, kwdList)
    if not str then return false end
    for _, keyword in ipairs(kwdList) do
        if string.find(str, keyword) then
            return true
        end
    end
    return false
end

-- 转换可能的nil为布尔值
function macroTorch.toBoolean(v)
    return v and true or false
end

-- 实现不区分大小写的字符串比较方法
function macroTorch.equalsIgnoreCase(str1, str2)
    if type(str1) ~= "string" or type(str2) ~= "string" then
        return false
    end
    return string.lower(str1) == string.lower(str2)
end
