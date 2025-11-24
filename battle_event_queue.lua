-- sets what spells to trace
if not macroTorch.tracingSpells then
    macroTorch.tracingSpells = {}
end

function macroTorch.setSpellTracing(spellGuid, spellName)
    if not macroTorch.tracingSpells[spellGuid] then
        macroTorch.tracingSpells[spellGuid] = spellName
    end
end

-- global event listening
local frame = CreateFrame("Frame")

-- frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
-- frame:RegisterEvent("PLAYER_DEAD")
-- frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
-- frame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")

-- super wow specific
if SUPERWOW_STRING then
    frame:RegisterEvent("UNIT_CASTEVENT")
    -- frame:RegisterEvent("RAW_COMBATLOG")
end

function macroTorch.eventHandle()
    if event == 'PLAYER_LOGIN' then
        -- on player login
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- on player entering world
        macroTorch.loginContext = {}
    elseif event == 'PLAYER_TARGET_CHANGED' then
        -- target changed
        if macroTorch.player.isInCombat and macroTorch.target.isCanAttack then
            if macroTorch.context then
                macroTorch.context.ffTimer = nil
                macroTorch.context.targetHealthVector = nil
            end
            macroTorch.show('Target change in combat!')
        end
    elseif event == 'SPELLCAST_START' then
        -- on spell cast start
    elseif event == 'SPELLCAST_STOP' then
        -- on spell cast stop
    elseif event == 'SPELLCAST_FAILED' then
        -- on spell cast failed
    elseif event == 'SPELLCAST_INTERRUPTED' then
        -- on spell cast interrupted
    elseif event == 'PLAYER_REGEN_ENABLED' then
        -- combat exiting
        if macroTorch.context then
            macroTorch.inCombat = false
            macroTorch.context = {}
        end
        macroTorch.show('Exiting combat!')
    elseif event == 'PLAYER_REGEN_DISABLED' then
        -- combat entering
        if not macroTorch.context then
            macroTorch.context = {}
        end
        macroTorch.inCombat = true
        macroTorch.show('Entering combat!')
    elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" or event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        -- when player melee combat or spell is dodged, parried, blocked or resisted
        macroTorch.CheckDodgeParryBlockResist("target", event, arg1)
    elseif event == "PLAYER_DEAD" then
        -- on player dead
    elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
        -- when player get a buff
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        -- when player lose a buff
    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then

    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then

    elseif event == "UNIT_CASTEVENT" then
        -- when player myself cast a spell
        local unitGuid, castType, spellId = arg1, arg3, arg4
        if unitGuid == macroTorch.player.guid and castType == 'CAST' then
            if spellId and macroTorch.tracingSpells[spellId] then
                macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
            end
        end
    elseif event == "RAW_COMBATLOG" then
        -- when player cast a spell
    elseif event == "UI_ERROR_MESSAGE" then
        -- on ui error message
        if not macroTorch.context then
            macroTorch.context = {}
        end
        -- arg1 is a global var be set automatically, see https://wow.gamepedia.com/UI_ERROR_MESSAGE
        -- SPELL_FAILED_NOT_BEHIND is a global constant, see https://wow.gamepedia.com/Constants/SPELL_FAILED_NOT_BEHIND
        if (arg1 == SPELL_FAILED_NOT_BEHIND) then
            macroTorch.context.behindAttackFailedTime = GetTime()
        end
    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" then
        -- player dodged mob's attack
    end
end

frame:SetScript("OnEvent", macroTorch.eventHandle)

-- sets the fixed periodic logic
frame.lastUpdate = 0
frame.leastUpdateInterval = 0.1
if not macroTorch.periodicTasks then
    macroTorch.periodicTasks = {}
end
function macroTorch.onPeriodicUpdate()
    -- on periodic update
    for _, task in pairs(macroTorch.periodicTasks) do
        if GetTime() - frame.lastUpdate >= task.interval then
            task.task()
        end
    end
end

function macroTorch.registerPeriodicTask(name, task)
    macroTorch.periodicTasks[name] = task
end

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

-- record traced spells' casts
function macroTorch.recordCastTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext.castTable then
        macroTorch.loginContext.castTable = {}
    end
    if not macroTorch.loginContext.castTable[spell] then
        macroTorch.loginContext.castTable[spell] = {}
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.castTable[spell][mob] then
        macroTorch.loginContext.castTable[spell][mob] = macroTorch.LRUStack:new(100)
    end
    macroTorch.loginContext.castTable[spell][mob].push(GetTime())

    -- macroTorch.show(spell ..
    --     ' cast on ' ..
    --     mob .. ' is recorded/renewed to castTable: ' ..
    --     macroTorch.loginContext.castTable[spell][mob].top)
end

-- record traced spells' failures, icluding all types of failures: miss, parry, resist, immune
-- it also computes the final 'landTable' immediately, cauz the cast event must arrived upon the fail event arrive
function macroTorch.recordFailTable(spell, failType)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    if not macroTorch.loginContext.failTable then
        macroTorch.loginContext.failTable = {}
    end
    if not macroTorch.loginContext.failTable[spell] then
        macroTorch.loginContext.failTable[spell] = {}
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.failTable[spell][mob] then
        macroTorch.loginContext.failTable[spell][mob] = macroTorch.LRUStack:new(100)
    end
    local item = { GetTime(), failType }
    macroTorch.loginContext.failTable[spell][mob].push(item)

    local lastCast = macroTorch.peekCastEvent(spell)
    macroTorch.show(spell ..
        ' failed on ' ..
        mob ..
        ' is recorded to failTable: ' ..
        item[1] .. '(' .. item[2] .. '), lag=' .. tostring(lastCast and (item[1] - lastCast) or 'noTracing'), 'red')
end

function macroTorch.computeLandTable(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    -- compute the final 'landTable'
    if not macroTorch.loginContext.landTable then
        macroTorch.loginContext.landTable = {}
    end
    if not macroTorch.loginContext.landTable[spell] then
        macroTorch.loginContext.landTable[spell] = {}
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext.landTable[spell][mob] then
        macroTorch.loginContext.landTable[spell][mob] = macroTorch.LRUStack:new(100)
    end
    local lastCast = macroTorch.peekCastEvent(spell) or 0
    if not lastCast or lastCast == 0 or GetTime() - lastCast > 0.9 then
        return
    end
    local lastLanded = macroTorch.peekLandEvent(spell) or 0
    -- already processed for this cast evnet
    if lastLanded == lastCast then
        return
    end
    local lastFail = macroTorch.peekFailEvent(spell)
    local lastFailedTime = lastFail and lastFail[1] or 0
    -- if no fail event near around the cast event, then it's a successful landed cast
    if math.abs(lastFailedTime - lastCast) > 0.2 then
        macroTorch.loginContext.landTable[spell][mob].push(lastCast)
        macroTorch.show(spell ..
            ' cast on ' ..
            mob .. ' landed: ' .. lastCast, 'blue')
    end
end

function macroTorch.consumeLandEvent(spell, logic)
    if not spell or not logic or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] or not macroTorch.loginContext.landTable[spell][mob].top then
        return
    end
    logic(macroTorch.loginContext.landTable[spell][mob].top)
end

function macroTorch.consumeFailEvent(spell, logic)
    if not spell or not logic or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.failTable or not macroTorch.loginContext.failTable[spell] or not macroTorch.loginContext.failTable[spell][mob] or not macroTorch.loginContext.failTable[spell][mob].top then
        return
    end
    logic(macroTorch.loginContext.failTable[spell][mob].top)
end

function macroTorch.peekCastEvent(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.castTable or not macroTorch.loginContext.castTable[spell] or not macroTorch.loginContext.castTable[spell][mob] then
        return nil
    end
    return macroTorch.loginContext.castTable[spell][mob].top
end

function macroTorch.peekFailEvent(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.failTable or not macroTorch.loginContext.failTable[spell] or not macroTorch.loginContext.failTable[spell][mob] then
        return nil
    end
    return macroTorch.loginContext.failTable[spell][mob].top
end

function macroTorch.peekLandEvent(spell)
    if not spell or not macroTorch.target.isCanAttack then
        return
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] then
        return nil
    end
    return macroTorch.loginContext.landTable[spell][mob].top
end

function macroTorch.landTableAnyMatch(spell, predicate)
    if not spell or not predicate or not macroTorch.target.isCanAttack then
        return false
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] then
        return false
    end
    return macroTorch.loginContext.landTable[spell][mob].anyMatch(predicate)
end

function macroTorch.landTableAllMatch(spell, predicate)
    if not spell or not predicate or not macroTorch.target.isCanAttack then
        return false
    end
    local mob = macroTorch.target.name
    if not macroTorch.loginContext or not macroTorch.loginContext.landTable or not macroTorch.loginContext.landTable[spell] or not macroTorch.loginContext.landTable[spell][mob] then
        return false
    end
    return macroTorch.loginContext.landTable[spell][mob].allMatch(predicate)
end

-- records battle status
function macroTorch.CheckDodgeParryBlockResist(unitId, eventType, eventMsg)
    -- macroTorch.show('CheckDodgeParryBlockResist: ' .. event .. ', msg: ' .. arg1)

    if not eventMsg then
        return
    end

    -- landTable的写入已由UNIT_CASTEVENT事件负责，只记录自己的动作，更加准确
    -- Your Rake crits Apprentice Training Dummy for 597.
    -- Your Rake hits Heroic Training Dummy for 173.
    -- local _, _, spell, mob = string.find(arg1, "Your (.-) hits (.-) for %d+%.")
    -- if not spell or not mob then
    --     _, _, spell, mob = string.find(arg1, "Your (.-) crits (.-) for %d+%.")
    -- end
    -- if spell and mob then
    --     -- macroTorch.show("HIT DETECTED: Spell[" .. spell .. "] by [" .. mob .. "]")
    --     if not macroTorch.context.landTable then
    --         macroTorch.context.landTable = {}
    --     end
    --     if not macroTorch.context.landTable[spell] then
    --         macroTorch.context.landTable[spell] = {}
    --     end
    --     macroTorch.context.landTable[spell][mob] = GetTime()
    -- end

    -- macroTorch.show(arg1)
    -- 尝试从 arg1 中匹配完整句式：Your <技能名> was dodged by <怪物名>.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) missed (.-)%.")
    if spell and mob then
        -- macroTorch.show("MISS DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] missed")
        macroTorch.recordFailTable(spell, 'miss')
    end
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) was dodged by (.-)%.")
    if spell and mob then
        -- macroTorch.show("DODGE DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] dodged")
        macroTorch.recordFailTable(spell, 'dodge')
    end
    -- Your Claw is parried by Vilemust Shadowstalker.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) is parried by (.-)%.")
    if spell and mob then
        -- macroTorch.show("PARRY DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] parried")
        macroTorch.recordFailTable(spell, 'parry')
    end
    --- Your Rake was resisted by Vilemust Shadowstalker.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) was resisted by (.-)%.")
    if spell and mob then
        -- macroTorch.show("RESIST DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] resisted")
        macroTorch.recordFailTable(spell, 'resist')
    end
    --- Your Rake failed. Vilemust Shadowstalker is immune.
    local _, _, spell, mob = string.find(eventMsg, "Your (.-) failed. (.-) is immune%.")
    if spell and mob then
        -- macroTorch.show("IMMUNE DETECTED: Spell[" .. spell .. "] by [" .. mob .. "] immune")
        macroTorch.recordFailTable(spell, 'immune')
    end
end

-- load the immuneTable from SM_EXTEND.immuneTable persistent var
function macroTorch.loadImmuneTable()
    -- init immuneTable and bind it to the SM_EXTEND.immuneTable persistent var
    if not SM_EXTEND then
        SM_EXTEND = {}
    end
    if not SM_EXTEND.immuneTable then
        SM_EXTEND.immuneTable = {}
    end
    if not macroTorch.context.immuneTable then
        macroTorch.context.immuneTable = SM_EXTEND.immuneTable
    end
end

-- load the definiteBleedingTable from SM_EXTEND.definiteBleedingTable persistent var
function macroTorch.loadDefiniteBleedingTable()
    -- init definiteBleedingTable and bind it to the SM_EXTEND.definiteBleedingTable persistent var
    if not SM_EXTEND then
        SM_EXTEND = {}
    end
    if not SM_EXTEND.definiteBleedingTable then
        SM_EXTEND.definiteBleedingTable = {}
    end
    if not macroTorch.context.definiteBleedingTable then
        macroTorch.context.definiteBleedingTable = SM_EXTEND.definiteBleedingTable
    end
end
