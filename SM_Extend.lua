spellMap = {}
spellMap['1'] = '2'

--- 判断指定的目标是否存在且活着且可被玩家攻击
---@param t string 指定的目标
---@return boolean true/false
function isTargetValidCanAttack(t)
    return UnitExists(t) and not UnitIsDead(t) and UnitCanAttack('player', t)
end

--- 判断指定的目标是否友好
---@param t string 指定的目标
---@return boolean true/false
function isTargetValidFriendly(t)
    return UnitExists(t) and not UnitIsDead(t) and UnitCanAssist('player', t)
end

--- 判断技能栏中指定名字的技能是否已经冷却结束
function isActionCooledDown(actionTxtContains)
    for z = 1, 172 do
        local txt = GetActionTexture(z)
        if txt and string.find(txt, actionTxtContains) then
            return GetActionCooldown(z) == 0
        end
    end
end

--- 获得指定目标的剩余生命值百分比
function getUnitHealthPercent(t)
    return UnitHealth(t) / UnitHealthMax(t) * 100
end

--- 获得制定目标剩余魔法/怒气/能量值百分比
function getUnitManaPercent(t)
    return UnitMana(t) / UnitManaMax(t) * 100
end

--- 开启自动近战攻击
function startAutoAtk()
    for z = 1, 172 do
        if IsAttackAction(z) then
            if not IsCurrentAction(z) then
                UseAction(z)
            end
            return
        end
    end
end

--- 开启自动射击
function startAutoShoot()
    for i = 1, 172 do
        local a = GetActionTexture(i)
        if a and string.find(a, 'Weapon') then
            if not IsAutoRepeatAction(i) then
                UseAction(i)
            end
            return
        end
    end
end

--- 判断指定的buff或debuff在指定的目标身上是否存在
---@param t string 指定的目标
---@param txt string 指定的buff/debuff texture文本
function isBuffOrDebuffPresent(t, txt)
    for i = 1, 40 do
        if string.find(tostring(UnitDebuff(t, i)), txt) or string.find(tostring(UnitBuff(t, i)), txt) then
            return true
        end
    end
    return false
end

--- 如果指定的buff在指定的目标身上不存在，则释放指定的技能
---@param t string 指定的目标
---@param sp string 指定的技能
---@param dbf string 指定的debuf
function castIfBuffAbsent(t, sp, dbf)
    if not isBuffOrDebuffPresent(t, dbf) then
        CastSpellByName(sp)
    end
end

--- 如当前目标存在且是活着的友好目标，则释放指定的法术，否则对自己释放且不丢失当前目标
function castBuffOrSelf(sp)
    if isTargetValidFriendly('target') then
        CastSpellByName(sp)
    else
        CastSpellByName(sp, true)
    end
end

--- 若指定的目标不存在指定的buff，则对其使用指定的包包物品
---@param t string 指定的目标
---@param itemName string 指定的包包物品名
---@param buff string buff texture文本
function useItemIfBuffAbsent(t, itemName, buff)
    if not isBuffOrDebuffPresent(t, buff) then
        useItemInBag(t, itemName)
    end
end

--- 若指定的目标生命值百分比小于指定的数值，则对其使用背包里的指定名称的物品
---@param t string 指定的目标
---@param hp number 生命百分比阈值, 0 - 100
---@param itemName string 背包里的物品名称，可以只包含部分名称，使用字符串包含逻辑匹配
function useItemIfHealthPercentLessThan(t, hp, itemName)
    if getUnitHealthPercent(t) < hp then
        useItemInBag(t, itemName)
    end
end

--- 若指定的目标法力/怒气/能量值百分比小于指定的数值，则对其使用背包里的指定名称的物品
---@param t string 指定的目标
---@param mp number 法力/怒气/能量百分比阈值, 0 - 100
---@param itemName string 背包里的物品名称，可以只包含部分名称，使用字符串包含逻辑匹配
function useItemIfManaPercentLessThan(t, mp, itemName)
    if getUnitManaPercent(t) < mp then
        useItemInBag(t, itemName)
    end
end

--- 对指定的目标使用包包里的物品
---@param t string 指定的目标
---@param itemName string 物品名，可仅仅指定一部分名字，使用字符串包含判断
function useItemInBag(t, itemName)
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b, s) do
            local n = GetContainerItemLink(b, s)
            if n and string.find(n, itemName) then
                UseContainerItem(b, s)
                SpellTargetUnit(t)
            end
        end
    end
end

--- 列出所有动作条可释放动作信息
function listActions()
    local i = 0

    for i = 1, 172 do
        local t = GetActionText(i);
        local x = GetActionTexture(i);
        if x then
            local m = "[" .. i .. "] (" .. x .. ")";
            if t then
                m = m .. " \"" .. t .. "\"";
            end
            DEFAULT_CHAT_FRAME:AddMessage(m);
        end
    end
end

--- 列出指定目标身上所有debuff
---@param t string 指定的目标
function listTargetDebuffs(t)
    for i = 1, 40 do
        local d = UnitDebuff(t, i)
        if d then
            DEFAULT_CHAT_FRAME:AddMessage('Found Debuff: ' .. tostring(d))
        end
    end
end

--- 列出指定目标身上的所有buff
---@param t string 指定的目标
function listTargetBuffs(t)
    for i = 1, 40 do
        local b = UnitBuff(t, i)
        if b then
            DEFAULT_CHAT_FRAME:AddMessage('Found Buff: ' .. tostring(b))
        end
    end
end

---显示目标的能量类型(魔法: 0, 怒气: 1, 集中值: 2, 能量: 3)
---@param t string 指定的目标
function showTargetPowerType(t)
    DEFAULT_CHAT_FRAME:AddMessage('Power Type: ' .. tostring(UnitPowerType(t)))
end

---显示目标的生物类型
---@param t string 指定的目标
function showTargetType(t)
    DEFAULT_CHAT_FRAME:AddMessage('Unit Type: ' .. tostring(UnitCreatureType(t)))
end

---猎人专用start---
function hunterStings()
    local t = 'target'
    local isPlayerTarget = UnitIsPlayer(t)
    local isManaTarget = UnitPowerType(t) == 0

    ---如果是法系玩家目标，上吸蓝钉刺 TODO

    ---如果是非法系的玩家目标，上减力减敏钉刺 TODO

    ---其它毒蛇钉刺有效目标，上毒蛇钉刺
    local targetType = UnitCreatureType(t)
    if not string.find(targetType, '元素') then
        castIfBuffAbsent(t, '毒蛇钉刺', 'Hunter_Quickshot')
    end
end
function MeleeSeq()
    if HasPetUI() and not UnitIsDead('pet') then
        PetAttack()
    end
    startAutoAtk()
    if not isBuffOrDebuffPresent('target', 'Rogue_Trip') then
        CastSpellByName('摔绊')
    end
    CastSpellByName('猛禽一击')
end
function RangedSeq()
    if HasPetUI() and not UnitIsDead('pet') then
        PetAttack()
    end
    local t = 'target'
    castIfBuffAbsent(t, '猎人印记', 'Hunter_SniperShot')
    startAutoShoot()
    hunterStings()
    CastSpellByName('奥术射击')
end
function hunterAtk()
    local t = 'target'
    if isTargetValidCanAttack(t) then
        if CheckInteractDistance(t, 3) then
            MeleeSeq()
        else
            RangedSeq()
        end
    else
        local pt = 'pettarget'
        if HasPetUI() and not UnitIsDead('pet') and isTargetValidCanAttack(pt) then
            TargetUnit(pt)
        else
            TargetNearestEnemy()
        end
        if isTargetValidCanAttack(t) then
            if CheckInteractDistance(t, 3) then
                MeleeSeq()
            else
                RangedSeq()
            end
        end
    end
end
---猎人专用end---

---盗贼专用start---
--- 释放技能前先偷东西，需潜行且目标存在
---@param sp string 偷东西后要释放的技能
function ppBeforeCast(sp)
    local t = 'target'
    if UnitIsPlayer(t) or not string.find(UnitCreatureType(t), '人型') then
        CastSpellByName(sp)
    else
        if n ~= 1 then
            CastSpellByName("偷窃")
            n = 1
        else
            CastSpellByName(sp)
            n = 0
        end
    end
end
function rogueSneak(startSp)
    ppBeforeCast(startSp)
end
--- 特定情况下回复能量(爆发)
function restoreEnergy()
    local t = 'target'
    if isTargetValidCanAttack(t) and UnitPlayerControlled(t) and UnitMana('player') < 20 then
        useItemInBag('player', '菊花茶')
    end
end
function rogueBattle()
    CastSpellByName('鬼魅攻击')
    CastSpellByName('出血')
    startAutoAtk()
end
--- 盗贼正面战斗
---@param startSp string 潜行状态起手技
function rogueAtk(startSp)
    local t = 'target'
    if isTargetValidCanAttack(t) then
        restoreEnergy()
        if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
            rogueSneak(startSp)
        else
            rogueBattle()
        end
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) then
            restoreEnergy()
            if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
                rogueSneak(startSp)
            else
                rogueBattle()
            end
        end
    end
end
function rogueSneakBack(startSp)
    ppBeforeCast(startSp)
end
function rogueBattleBack()
    CastSpellByName('背刺')
    startAutoAtk()
end
--- 盗贼背后战斗
---@param startSp string 潜行状态起手技
function rogueAtkBack(startSp)
    local t = 'target'
    if isTargetValidCanAttack(t) then
        restoreEnergy()
        if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
            rogueSneakBack(startSp)
        else
            rogueBattleBack()
        end
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) then
            restoreEnergy()
            if isBuffOrDebuffPresent('player', 'Ability_Stealth') then
                rogueSneakBack(startSp)
            else
                rogueBattleBack()
            end
        end
    end
end
--- 切换最近处的敌人并释放指定技能(不是抓贼宏)
---@param sp string 指定技能
function lockNearestEnemyThenCast(sp)
    local t = 'target'
    if isTargetValidCanAttack(t) and CheckInteractDistance(t, 3) then
        CastSpellByName(sp)
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) and CheckInteractDistance(t, 3) then
            CastSpellByName(sp)
        end
    end
end
--- 伺机消失
function readyVanish()
    if not isBuffOrDebuffPresent('player', 'Ability_Stealth') then
        local s = '消失'
        if isActionCooledDown('Ability_Vanish') then
            CastSpellByName(s)
        else
            CastSpellByName('伺机待发')
            CastSpellByName(s)
        end
    end
end
---盗贼专用end---

---小德专用start---
--- 近战动作策略
function xdMeleeSeq()
    local t = 'target'
    local p = 'player'
    startAutoAtk()
    if isBuffOrDebuffPresent(p, 'Racial_BearForm') then
        --- 熊形态
        CastSpellByName('低吼')
        castIfBuffAbsent(t, '挫志咆哮', 'Druid_DemoralizingRoar')
        CastSpellByName('槌击')
    else
        --- 人形态
    end
end
--- 远程动作策略
function xdRangedSeq()
    local t = 'target'
    local p = 'player'
    startAutoAtk()
    if isBuffOrDebuffPresent(p, 'Racial_BearForm') then
        --- 熊形态
    else
        --- 人形态
        CastSpellByName('愤怒')
    end
end
function xdAtk()
    local t = 'target'
    if isTargetValidCanAttack(t) then
        if CheckInteractDistance(t, 3) then
            xdMeleeSeq()
        else
            xdRangedSeq()
        end
    else
        TargetNearestEnemy()
        if isTargetValidCanAttack(t) then
            if CheckInteractDistance(t, 3) then
                xdMeleeSeq()
            else
                xdRangedSeq()
            end
        end
    end
end
--- 小德治疗序列
---@param onSelf boolean 是否对自己释放
function xdHealSeq(onSelf)
    local t
    if (onSelf) then
        t = 'player'
    else
        t = 'target'
    end
    if not isBuffOrDebuffPresent(t, 'Nature_ResistNature') then
        CastSpellByName('愈合', onSelf)
    end
    CastSpellByName('治疗之触', onSelf)
end
function xdHeal()
    if isTargetValidFriendly('target') then
        xdHealSeq(false)
    else
        xdHealSeq(true)
    end
end
---小德专用end---
