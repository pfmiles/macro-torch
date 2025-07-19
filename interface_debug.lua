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

--- 判断技能栏中指定texture的技能是否已经冷却结束
---@param actionTxtContains string 技能栏中代表技能的图标texture(可以是部分内容, 使用字符串contains判断)
function macroTorch.isActionCooledDown(actionTxtContains)
    for z = 1, 172 do
        local txt = GetActionTexture(z)
        if txt and macroTorch.containsAnyKeyword(txt, { actionTxtContains }) then
            return GetActionCooldown(z) == 0
        end
    end
end

--- 显示所有技能属性
function macroTorch.showAllActionProps()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a then
            macroTorch.show(a .. ':')
            macroTorch.show('IsAttackAction:' .. tostring(IsAttackAction(i)))
            macroTorch.show('ActionHasRange:' .. tostring(ActionHasRange(i)))
            macroTorch.show('IsCurrentAction:' .. tostring(IsCurrentAction(i)))
            macroTorch.show('IsAutoRepeatAction:' .. tostring(IsAutoRepeatAction(i)))
            macroTorch.show('IsEquippedAction:' .. tostring(IsEquippedAction(i)))
        end
    end
end

--- 列出所有动作条可释放动作信息
function macroTorch.showAllActions()
    local i = 0

    for i = 1, 172 do
        local t = GetActionText(i);
        local x = GetActionTexture(i);
        if x then
            local m = "[" .. i .. "] (" .. x .. ")";
            if t then
                m = m .. " \"" .. t .. "\"";
            end
            macroTorch.show(m);
        end
    end
end

---显示目标的能量类型(魔法: 0, 怒气: 1, 集中值: 2, 能量: 3)
---@param t string 指定的目标
function macroTorch.showTargetEnergyType(t)
    macroTorch.show('Power Type: ' .. tostring(UnitPowerType(t)))
end

---显示目标的生物类型
---@param t string 指定的目标
function macroTorch.showTargetType(t)
    macroTorch.show('Unit Type: ' .. tostring(UnitCreatureType(t)))
end

--- 显示目标职业
function macroTorch.showTargetClass(t)
    macroTorch.show('Unit Class: ' .. tostring(UnitClass(t)))
end

--- 在聊天框中显示传入的内容，传入内容会被tostring
---@param a any
function macroTorch.show(a)
    DEFAULT_CHAT_FRAME:AddMessage(tostring(a))
end
