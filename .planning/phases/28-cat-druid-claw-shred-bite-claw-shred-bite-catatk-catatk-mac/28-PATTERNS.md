# Phase 28: catatk claw/shred/bite 伤害打桩 + 离线分析器 — Pattern Map

**Mapped:** 2026-09-08
**Files analyzed:** 9（7 修改 + 1 新建 + 1 只读引用）
**Analogs found:** 8 / 9（`tools/cpdamage.lua` 无直接 analog，见 "No Analog Found"）

> **给 planner 的两个决定性锚点**（依据 28-RESEARCH.md，已核验到 file:line，勿沿用 D-01 原文措辞）：
> 1. 伤害源 = `RAW_COMBATLOG` 事件的 `arg1=='CHAT_MSG_SPELL_SELF_DAMAGE'` 通道（`arg2` 为 `Your <Spell> hits|crits <GUID> for <N>.` 纯文本），**不存在名为 SPELL_DAMAGE 的事件名**。
> 2. **不得复用 Phase 27 `intentTable`/`pairLandIntent` 表**（Ferocious Bite 已被 land 配对占用，fail-wins 语义会互相污染）——必须并行独立队列 `loginContext.cpDamageIntents`，但复用 `LRUStack` + `LAND_INTENT_TTL` + purge/逆序配对骨架。
>
> **Tracked-source gate：** 本文件列出的全部 analog 路径均经 `git ls-files` 验证为 git-tracked 源码。`SM_Extend.lua`（build 产物）与 `.planning/samples/`（gitignored，客户端样本拷贝）**不可作为 analog 引用**——SV 文件行形态以 tracked 的 `28-RESEARCH.md` §2 逐字引用为准；分析器 `--selftest` fixture 必须由实现者**新写入脚本内部**，不从 untracked 样本复制。

## File Classification

| New/Modified File | 变更 | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|------|-----------|----------------|---------------|
| `classes/druid/Druid.lua` | modify | hook（技能方法内 cast 采样） | event-driven（cast 释放）+ transform（状态快照） | `classes/druid/Druid.lua:25-58` cpBuild 三件套 + `332-355` cpBuildLogSample/Event | exact（同文件先例） |
| `core/events.lua` | modify | middleware（事件路由/通道门） | event-driven（RAW_COMBATLOG 分派） | `core/events.lua:135-205` rawdiag2 scout + tier-1 白名单 | exact |
| `core/spell_trace_core.lua` | modify | service（伤害行解析 + intent 配对 + 条目发射） | event-driven（cast→damage 配对） | `core/spell_trace_core.lua:179-210` pairLandIntent；`365-395` onSelfDamageLine；`86-142` recordCastTable | exact |
| `core/combat_context.lua` | modify | store（context 生命周期，batch 戳） | event-driven（进/脱战） | `core/combat_context.lua:21-35` onCombatEnter/Exit | exact |
| `impl_util.lua` | modify | utility（纯函数 JSON 微编码器） | transform（Lua 值 → JSON 字符串） | `impl_util.lua:29-31,92-101` toBoolean/tableLen 全局纯函数样式 | role-match |
| `macro_torch.lua` | modify | config（per-session 开关 + 横幅注册） | init/bootstrap（login/reload 复位） | `macro_torch.lua:22-28` cpBuildLog nil-guard + `65-94` CONFIG_OPTIONS | exact |
| `classes/druid/selftest.lua` | modify | test（Category U 注册） | batch（assert 集合） | `classes/druid/selftest.lua:991-1096` Cat S/T + `745-884` Cat Q 桩纪律 | exact |
| `tools/cpdamage.lua` | create | CLI 分析脚本（离线层） | file-I/O + batch-transform（提取/解析/统计/报表） | 无（全仓无离线 Lua 脚本先例） | no-analog |
| `interface_debug.lua` | 不改（只读引用） | —（既有 `macroTorch.log` 写入口直接复用） | — | `interface_debug.lua:106-124` | 参考用 |

## Pattern Assignments

### 1. `classes/druid/Druid.lua`（hook，event-driven cast 采样 + 快照）

新增三件（仿 cpBuild 体系，落点与 cpBuildLogSample/Event 并排）：
- `macroTorch.cpDamageSample()` — cast 前快照（`t`/`cp`/`energyPool`/`bleedCount`/`isOoc`/`isBehind`/`e`/`gcdOk`）
- `macroTorch.cpDamageCast(sample)` — 种独立 intent（写 `loginContext.cpDamageIntents`）
- bleedCount 扫描 — 三次 `target.hasBuff(纹理)` 计数 0-3
- `obj.claw`/`obj.shred` 内嵌守卫；`obj.ferocious_bite` 补同构结构（当前无采样）

**技能方法三件套骨架（Druid.lua:25-58）** — claw/shred 已有、bite 缺失：
```lua
function obj.claw(mode, rank)
    local cpLog = macroTorch.cpBuildLog and macroTorch.cpBuildLogSample() or nil
    local cast = obj._castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false, rank)
    if cast and cpLog and cpLog.gcdOk then
        macroTorch.cpBuildLogEvent('Claw', cpLog)
    end
    return cast
end
function obj.ferocious_bite(mode, rank)   -- 56-58：当前无采样，Phase 28 补 cpDamage 结构
    return obj._castSpell({ en = 'Ferocious Bite', zh = '凶猛撕咬' }, mode, nil, 35, false, rank)
end
```

**采样函数样板（Druid.lua:328-355）** — WR-01 关键约束：GCD probe 必须先于 cast；只有 `cast` 返回真才种 intent/发条目：
```lua
-- The GCD probe must run BEFORE the cast because casting starts the GCD and
-- would falsify the reading; the probe reuses the same action-slot
-- 'Ability_Druid_Rake' texture scan as macroTorch.isGcdOk.
function macroTorch.cpBuildLogSample()
    local gcdOk = macroTorch.player.isActionCooledDown('Ability_Druid_Rake')
    if gcdOk == nil and not macroTorch._cpBuildLogProbeWarned then
        macroTorch._cpBuildLogProbeWarned = true
        macroTorch.show('[cpBuild] GCD probe failed: put the Rake spell on an action bar, otherwise no casts will be logged', 'yellow')
    end
    return { t = GetTime(), cp = macroTorch.player.comboPoints, e = macroTorch.player.mana, gcdOk = gcdOk }
end
function macroTorch.cpBuildLogEvent(skillName, s)
    macroTorch.log('[cpBuild] ' .. skillName .. ' t=' .. s.t .. ' cp=' .. s.cp .. ' e=' .. s.e)
end
```

**能耗动态值在 hook 内直接重调（幂等，RESEARCH §4/§7 钦定）**：
```lua
function macroTorch.computeClaw_E()     -- Druid.lua:501-509
    local CLAW_E = 45
    local player = macroTorch.player
    if player.isItemEquipped('Idol of Ferocity') then CLAW_E = CLAW_E - 3 end
    CLAW_E = CLAW_E - player.talentRank('Ferocity')
    return CLAW_E
end
function macroTorch.computeShred_E()    -- Druid.lua:642-645：60 − Improved Shred×6
-- BITE_E = 35 硬编码：combo.lua:62
```

**流血档快照链路：hasBuff 纹理法（任意来源口径，D-04）**：
```lua
-- entity/Unit.lua:26-34 —— 扫描 UnitDebuff+UnitBuff 全部来源；1..40 nil 安全，勿改（R8 禁令域）
function obj.hasBuff(spellOrItemName)
    local texture = macroTorch.getSpellOrItemBuffTexture(spellOrItemName)
    for i = 1, 40 do
        if string.find(tostring(UnitDebuff(obj.ref, i)), texture) or string.find(tostring(UnitBuff(obj.ref, i)), texture) then
            return true
        end
    end
    return false
end
-- texture_map.lua:40-46 —— 未映射字符串直接透传（SpellTrace 注册中的 immuneTexture 现成值即纹理本身）
-- 三流血纹理（Druid.lua:723-742 SpellTrace 注册）：Rake=Ability_Druid_Disembowel / Rip=Ability_GhoulFrenzy / Pounce=Ability_Druid_SupriseAttack
-- hasBuff 现场用法样板（Druid.lua:1137-1143）：
function macroTorch.isRipPresent(clickContext)
    if clickContext.isRipPresent == nil then
        clickContext.isRipPresent = macroTorch.toBoolean(macroTorch.target.hasBuff('Ability_GhoulFrenzy') and
                macroTorch.ripLeft(clickContext) > 0)
    end
    return clickContext.isRipPresent
end
```

**11 字段快照来源全集（RESEARCH §7 已逐字核验）**：`e` = computeClaw_E/computeShred_E/35；`energyPool` = `macroTorch.player.mana`（= UnitMana，猫形态即能量，entity/Unit.lua:114-116）；`cp` = `macroTorch.player.comboPoints`；`isOoc` = `macroTorch.player.isOoc`（Druid.lua:364-366 = Clearcasting buff）；`isBehind` = `macroTorch.player.isBehindTarget`（entity/Player.lua:602-605，UnitXP('behind')）；`isTargetDummy` 硬门 = combo.lua:104-106 同表达式 `macroTorch.toBoolean(macroTorch.target.isCanAttack and string.find(macroTorch.target.name, 'Training Dummy'))`；`batch` = `macroTorch.context._cpDamageBatch`。

### 2. `core/events.lua`（middleware，RAW_COMBATLOG 通道门）

**插入位置**：rawdiag2 scout 块结束（181 行注释）与 tier-1 白名单 early-return（187 行）**之间**——cpDamage 通道门先消费 SELF_DAMAGE 行，随后 tier-1 return 挡住 land 消费者（SELF_DAMAGE 非 periodic 通道，天然 return）。**不改 tier-1 白名单集合**（扰动 Phase 27 语义为禁区），按通道分派。

**现结构上下文（events.lua:135-205 节选）**：
```lua
elseif event == "RAW_COMBATLOG" then
    -- [RAWDIAG2 quick 260907-mhh] forensics scout, placed BEFORE the tier-1 channel
    -- whitelist so it sees every RAW_COMBATLOG line while armed. ...
    local scoutActive = macroTorch.context and macroTorch.context._rawdiag2Active
    if scoutActive then ... end
    -- end of RAWDIAG2 scout block (arming hook: spell_trace_core.lua recordCastTable)
    -- production event-driven land handler (three-tier filter, debug decision #6).
    -- Tier 1 (channel whitelist): only the two periodic-damage channels ...
    if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then
        return
    end
```
**新通道门（插入 181 与 187 之间）**：`if arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE' then macroTorch.onCpDamageLine(arg2, GetTime()) end` —— 仅 `macroTorch.cpDamageLog == true` 时才有意义（开关门放在被调函数内或此处，实现自选）。

**注意既有 `CHAT_MSG_SPELL_SELF_DAMAGE` 聊天过滤分支（events.lua:99-107）** — miss/dodge/resist 判定走该 chat 分支（CheckDodgeParryBlockResist + onSelfDamageLine land 通道），与 RAW 分支互不冲突；RAW 门只做伤害行解析，不得触 marshal 该分支。

**RAW 注册门（events.lua:47-51）** — cpDamageLog 依赖 SuperWoW，`SUPERWOW_STRING ~= nil` 门已存在：
```lua
if SUPERWOW_STRING ~= nil then
    frame:RegisterEvent("UNIT_CASTEVENT")
    frame:RegisterEvent("RAW_COMBATLOG")
end
```

**Lua 5.0 arg 序列化样板（events.lua:159-164）** — 无 `#`，用计数器循环：
```lua
local parts = {}
local ai = 1
while ai <= 12 and _G['arg' .. ai] ~= nil do
    table.insert(parts, 'arg' .. ai .. '=' .. tostring(_G['arg' .. ai]))
    ai = ai + 1
end
```

### 3. `core/spell_trace_core.lua`（service，解析 + 配对 + 发射，与 land 函数并排）

新增族：`macroTorch.onCpDamageLine(eventMsg, now)`（解析 `^Your (.+) (hits|crits) (0x[0-9A-Fa-f]+) for (%d+)%.`，不锚定行尾）+ `macroTorch.pairCpDamageIntent(guid, now)`（purge + 逆序配对）+ `macroTorch.cpDamageEvent(sample, dmg, crit)`（11 字段 JSON 组装 + `macroTorch.log('[cpDamage] ' .. json)`）。

**TTL 常量直接复用（spell_trace_core.lua:15）**：`macroTorch.LAND_INTENT_TTL = 2`（D-02 钦定对齐 2s）。

**intent 队列懒初始化样板 — recordCastTable（spell_trace_core.lua:90-101, 122-125）**：
```lua
if not macroTorch.loginContext then return end
if not macroTorch.loginContext.intentTable then macroTorch.loginContext.intentTable = {} end
...
macroTorch.loginContext.intentTable[spell][mob].push({ state = 'pending', castAt = GetTime(), landAt = nil })
```
→ 新队列写法照此（loginContext 每次 onPlayerEnteringWorld 整体重置，combat_context.lua:39）：`if not macroTorch.loginContext.cpDamageIntents then macroTorch.loginContext.cpDamageIntents = macroTorch.LRUStack:new(8) end`，元素 `{ spell, guid, castAt, sample }`（不带 state/landAt，伤害无 fail-wins 语义）。

**配对样板 — pairLandIntent（spell_trace_core.lua:179-210），purge 趟 + 逆序 pair 趟结构逐行照抄**：
```lua
function macroTorch.pairLandIntent(spell, landTime)
    ...
    -- purge pass: expire pending intents older than the TTL window
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if intent.state == 'pending' and (landTime - intent.castAt) > macroTorch.LAND_INTENT_TTL then
            intent.state = 'expired'
        end
    end
    -- pair pass: newest pending intent whose cast precedes this land
    for i = macroTorch.tableLen(stack.elements), 1, -1 do
        local intent = stack.elements[i]
        if intent.state == 'pending' and intent.castAt <= landTime and
                (landTime - intent.castAt) <= macroTorch.LAND_INTENT_TTL then
            intent.state = 'landed'
            intent.landAt = landTime
            return intent
        end
    end
    return nil
end
```
（一 cast 帧恰好一条 intent、队列深度恒 1，**保留 purge+逆序骨架**不简化——RESEARCH §4。）

**行正则样板 — onSelfDamageLine（spell_trace_core.lua:365-395，369-372 节选）**：
```lua
local _, _, spell = string.find(eventMsg, 'Your (.-) hits ([^%.]+)%.')
if not spell then
    _, _, spell = string.find(eventMsg, 'Your (.-) crits ([^%.]+)%.')
end
```
→ 新正则（RESEARCH §1 钦定）：`^Your (.+) (hits|crits) (0x[0-9A-Fa-f]+) for (%d+)%.`；miss/dodge/parry/resist 行天然不匹配 → D-03 零额外代码（句式全集见 CheckDodgeParryBlockResist，spell_trace_core.lua:468-507）。crit：动词在 `{hits, crits}` 白名单 → true/false；否则写 null。

**队列容器 — LRUStack（core/periodic.lua:21-75）**：
```lua
function macroTorch.LRUStack:new(maxSize)
    local obj = { maxSize = maxSize, elements = {} }
    setmetatable(obj, macroTorch.classMetatable(nil, "ES_FIELD_FUNC_MAP"))
    function obj.push(event)
        while macroTorch.tableLen(obj.elements) >= obj.maxSize do table.remove(obj.elements, 1) end
        table.insert(obj.elements, event)
    end
    function obj.pop() ... end
    function obj.removeMatch(predicate)   -- 逆序删除最新匹配元素
        for i = macroTorch.tableLen(obj.elements), 1, -1 do
            if predicate(obj.elements[i]) then return table.remove(obj.elements, i) end
        end
        return nil
    end
    return obj
end
```

### 4. `core/combat_context.lua`（store，batch 一行）

**onCombatEnter 尾部追加 `macroTorch.context._cpDamageBatch = GetTime()`（combat_context.lua:29-35）**；脱战 context 整体重建（21-27 行 `macroTorch.context = {}`）→ 下批自动取新值，零额外清空逻辑：
```lua
function macroTorch.onCombatExit()
    macroTorch.inCombat = false
    if macroTorch.context then macroTorch.context = {} end
    macroTorch.show('Exiting combat!')
end
function macroTorch.onCombatEnter()
    if not macroTorch.context then macroTorch.context = {} end
    macroTorch.inCombat = true
    macroTorch.show('Entering combat!')
end
```

### 5. `impl_util.lua`（utility，JSON 微编码器 ~30 行）

**纯函数样式样板（impl_util.lua:29-31, 92-101）** — `function macroTorch.xxx` 全局声明，Apache 头居首：
```lua
function macroTorch.toBoolean(v) return v and true or false end
function macroTorch.tableLen(tbl)
    if not tbl then return 0 end
    local len = 0
    for _ in pairs(tbl) do len = len + 1 end
    return len
end
```
**编码器约束（RESEARCH §3 钦定，Lua 5.0 逐条核验）**：`gsub` 替换项仅 string/**function**（5.0 无 table 形式）；**禁止 `%q` 产 JSON**（产 Lua 引号 `\ddd` 形式，JSON 非法）；`spell` 是唯一字符串字段且恒为 ASCII token，转义需求极小。字段序固定 11 字段——解码端同序互认契约。

### 6. `macro_torch.lua`（config，cpDamageLog nil-guard + 第 5 项）

**per-session bool 三惯例样板 — cpBuildLog（macro_torch.lua:22-28）**：
```lua
-- combo-point building cast log switch (quick 260907-0ya): false by default, set
-- macroTorch.cpBuildLog = true in game (SuperMacro body) to record ...
-- The nil-guard re-arms the default on every login; toggling mid-session needs no reload.
if macroTorch.cpBuildLog == nil then
    macroTorch.cpBuildLog = false
end
```

**CONFIG_OPTIONS 条目样板（macro_torch.lua:65-94 节选，第 5 项照此追加）**：
```lua
macroTorch.CONFIG_OPTIONS = {
    {
        name = 'macroTorch.LOG_MAX_SIZE',
        default = 500,
        desc = 'macroTorch.log persistence buffer entry cap',
        cmd = '/run macroTorch.LOG_MAX_SIZE=1000',
        get = function() return macroTorch.LOG_MAX_SIZE end,
    },
}
-- printConfigBanner（97-110）只读遍历 + pcall(get)，无需改动
```

### 7. `classes/druid/selftest.lua`（test，Category U — O/Q/R/S/T 已占用）

**注册 API（core/selftest.lua:34-40）**：`macroTorch.SelfTest:register(name, fn, isOptional)` — `isOptional=true` 失败走黄色 warning（49-89 pcall 隔离）。

**文件级 guard + Category 样式（selftest.lua:19, 1084-1093）**：
```lua
if UnitClass('player') == 'Druid' then
...
-- Category T: macroTorch.log persistence buffer cap (quick 260907-vve, 1 test)
macroTorch.SelfTest:register("Cat T-01: LOG_MAX_SIZE defaults to 500", function()
    assert(macroTorch.LOG_MAX_SIZE == 500,
        "LOG_MAX_SIZE should default to 500, got " .. tostring(macroTorch.LOG_MAX_SIZE))
end, true)
```
→ 新注册：`"Cat U-01: cpDamageLog defaults to false"` 起，格式 `"Cat U-NN: <desc>"` + `isOptional=true`。编码器断言（固定条目表 → 期望 JSON 字面量逐字断言）放同 Category 纯函数测试。

**桩纪律样板 — Cat S-03（selftest.lua:987-1048 节选，CR-01 纪律：rawget 快照 → 装影子 → 捕获 → assert 前 rawset 还原）**：
```lua
local savedSwitch = macroTorch.cpBuildLog
local savedLog = macroTorch.log
local savedCast = rawget(player, '_castSpell')
local savedActionCd = rawget(player, 'isActionCooledDown')
local captured = {}
macroTorch.log = function(a) table.insert(captured, tostring(a)) end
player._castSpell = function() return true end
player.isActionCooledDown = function() return true end
local pcallRes = pcall(function()
    macroTorch.cpBuildLog = true
    player.claw('ready')
    ...
end)
rawset(player, '_castSpell', savedCast)
rawset(player, 'isActionCooledDown', savedActionCd)
macroTorch.log = savedLog
macroTorch.cpBuildLog = savedSwitch
assert(pcallRes, "S-03 pcall failed")
```

**配对测试样板 — Cat Q-02/Q-04（selftest.lua:760-799, 824-847）** — 新 pairCpDamageIntent 测试直接复用 fakeLoginContext/fakeTarget + castAt 种值模板：
```lua
local savedLoginContext = macroTorch.loginContext
local savedTarget = macroTorch.target
local fakeLoginContext = {}
local fakeTarget = { isCanAttack = true, name = 'QTestMob', hasBuff = function(self) return false end }
fakeLoginContext.intentTable = {}
fakeLoginContext.intentTable['Rip'] = {}
fakeLoginContext.intentTable['Rip']['QTestMob'] = macroTorch.LRUStack:new(32)
local seededIntent = { state = 'pending', castAt = 1.0, landAt = nil }
fakeLoginContext.intentTable['Rip']['QTestMob'].push(seededIntent)
macroTorch.loginContext = fakeLoginContext
macroTorch.target = fakeTarget
local ok, pcallRes = true, true
pcallRes = pcall(function()
    ok = (macroTorch.pairLandIntent('Rip', 5.0) == nil)
    ...  -- Q-04：5.0 − 1.0 超 TTL → expired；Q-02：窗内配对 → landed + landAt=1000.5
end)
macroTorch.loginContext = savedLoginContext
macroTorch.target = savedTarget
assert(pcallRes, "... pcall failed")
```

### 8. `tools/cpdamage.lua`（create，无直接 analog — 见 "No Analog Found"）

**间接 pattern 源（全部 tracked）**：
- **括号配平 strip 逻辑**：`/home/admin/workspace/macro-torch/.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js`（全文 21 行，strip 顺序：块注释 → 长字符串 → 行注释 → 短字符串 → 栈配平）。Lua 版提取器须同构移植（JSON body 内 `{}`/引号必然裸计数错配）：`string.find` 定位 `MACRO_TORCH_LOG` → 向后扫到首个 `{` → 字符串/注释感知配平到闭合 `}` → `loadstring(block)` 沙箱执行（5.0/5.1 `setfenv`；5.2+ `load(block, nil, 't', env)` + `local load_chunk = loadstring or load` shim）。
- **Lua 5.0 方言**：Apache 2.0 头（每 .lua 文件，`]] --` 收尾，见 Druid.lua:1-15）；禁 `#`/goto/gsub table 替换（用 function 分支）；数组长用 ipairs 计数；避免 `unpack`（`arg[1]..arg[n]` 直取）；`%` 而非 math.mod；字符串转义只用 `\ddd`（RESEARCH §6 全表）。
- **SV 序列化形态**（`[1] = "..."` 显式键形式）：以 tracked `28-RESEARCH.md` §2 逐字引用为准（`[1] = "[RAWDIAG] #48 t=13415.600 arg1=...`）；**不引用** `.planning/samples/`（gitignored，untracked）。
- **防御**：`MACRO_TORCH_LOG = nil`/`{ }` 友好空结果；文件上限（如 32MB）+ 条数上限（如 50k）；解码器 pcall 包裹坏行跳过计数。
- **`--selftest` 子命令**：内嵌自写 fixture（小样 SV 形态 + 往返 JSON）+ 5.0 敏感断言，供用户机 `lua tools/cpdamage.lua --selftest`。

## Shared Patterns

### Apache 2.0 文件头
**Source:** 任意仓内 .lua（如 `core/events.lua:1-15`）。**Apply to:** 所有改动文件头部保持原样；`tools/cpdamage.lua` 新文件同款头（`]] --` 收尾）。

### 前缀打点落盘（D-12）
**Source:** `interface_debug.lua:106-124`（`macroTorch.log`：防御重init → show → LOG_MAX_SIZE trim → `table.insert(messages, tostring(a))`）+ cpBuild 前缀先例 `Druid.lua:353-355`。**Apply to:** cpDamage 发射函数 = `macroTorch.log('[cpDamage] ' .. jsonString)`，零新增存储结构；LOG_MAX_SIZE 用户 /run 自调（D-10）。

### per-session 配置 bool 三惯例（D-06）
**Source:** `macro_torch.lua:22-55`（cpBuildLog/rawdiag2Enabled/COWER_THREAT_THRESHOLD/LOG_MAX_SIZE 四先例）。**Apply to:** `cpDamageLog` — nil-guard 默认 false / login-reload 复位 / mid-session toggle 无需 reload / CONFIG_OPTIONS 第 5 项横幅。

### SelfTest 注册传统
**Source:** `classes/druid/selftest.lua:19`（UnitClass 门）+ Category U 新建（O/Q/R/S/T 已占用，28-RESEARCH.md §9 普查）+ `isOptional=true`。**Apply to:** Category U 全部新测试；编码器断言用纯函数（无游戏 API，/mt 可跑）。

### Lua 5.0 方言（游戏内与分析器同约束）
**Source:** RESEARCH §6（官方 5.0 手册核验表）+ `impl_util.lua:92-101` tableLen 先例。**Apply to:** 两端所有新写代码：无 `#`、无 goto、gsub 仅 string/function、无 `%q` 产 JSON。

### 验证电池（每 plan verify 段抄此）
**Source:** `.planning/phases/27-.../tools/bbcheck.js` + RESEARCH §9：
`node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js <触及全部 .lua 含 tools/cpdamage.lua>`（全 BALANCED）→ `./build.sh`（exit 0，SM_Extend.lua 出现 `cpDamage` 新符号）→ `git diff --check` → grep 断言组（`grep -c "cpDamageLog" macro_torch.lua` ≥ 2；`grep -c "build_order" git diff` = 0）。本机无 lua 解释器 → 分析器运行级靠用户机 `--selftest` + UAT。

### UAT 模板（checkpoint:human-verify）
**Source:** `classes/druid/HUMAN-UAT.md`（tracked 模板：Prerequisites / Pre-Test Self-Test Verification / 分型 checklist）。**Apply to:** 用户实机 `lua tools/cpdamage.lua --selftest`（5.0/5.1/5.4）+ 打骷髅桩 1 分钟 → ReloadUI → 拷回 SuperMacro.lua → analyzer 出表端到端闭环；另确认游戏机 SuperMacro .toc 含 `MACRO_TORCH_LOG`（RESEARCH A2 checkpoint）。

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `tools/cpdamage.lua` | CLI 分析脚本 | file-I/O + batch-transform | 全仓无任何离线 Lua 脚本先例（find 全仓 .planning/*.lua 零命中）；`tools/` 目录尚不存在。planner 按 RESEARCH §2/§3/§6 规格 + 上方间接 pattern 源（bbcheck.js strip 逻辑、Lua 5.0 游戏内方言、tracked 28-RESEARCH.md §2 的 SV 形态逐字引用）自建。**严禁引用 `.planning/samples/`（gitignored untracked）为 fixture 复制源**；`--selftest` fixture 全新内嵌 |
| `interface_debug.lua` | — | — | 无修改：既有 `macroTorch.log` 写路径直接复用（D-10），仅作为 Shared Pattern 来源引用 |

## Metadata

**Analog search scope:** `classes/druid/`、`core/`、`entity/`、`texture_map.lua`、repo 根（`macro_torch.lua`/`interface_debug.lua`/`impl_util.lua`/`biz_util.lua`/`build_order.txt`/`build.sh`/`.gitignore`）、`.planning/phases/27-.../tools/`、`.planning/samples/`（探明 untracked 后弃用）
**Files scanned:** 16（Druid.lua 4 段非重叠区间、events.lua、spell_trace_core.lua、periodic.lua、combat_context.lua、selftest.lua(core+druid 3 段)、macro_torch.lua、interface_debug.lua、impl_util.lua、texture_map.lua、Unit.lua、Player.lua、combo.lua、cat.lua、bbcheck.js、HUMAN-UAT.md、sample_back_again.txt(仅探明格式后弃用为 analog)）
**Pattern extraction date:** 2026-09-08
**All analog paths git-tracked-verified:** yes（`git ls-files --` 逐一通过；`SM_Extend.lua` 与 `.planning/samples/` 被排除）