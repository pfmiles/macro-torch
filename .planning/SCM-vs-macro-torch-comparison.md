# SuperCleveRoidMacros vs macro-torch 功能对比分析报告

> 分析日期: 2026-08-13
> SCM 版本: master 分支 (MIT License)
> macro-torch 版本: main 分支 (Apache 2.0)

---

## 一、项目架构概览

| 维度 | macro-torch | SuperCleveRoidMacros (SCM) |
|------|-------------|---------------------------|
| 架构风格 | 面向对象，Entity 继承体系 (Unit → Target/Player) | 函数式+Event-driven，全局 CleveRoids 表 |
| 文件规模 | ~46 个 .lua 文件，核心精炼 | ~37 个 .lua 文件，核心巨大 (Conditionals.lua 410KB, Core.lua 293KB) |
| 职业抽象 | 按 class 拆分 (druid/hunter/mage/...) | 通用宏引擎，职业逻辑由用户通过条件语法编写 |
| 底层依赖 | SuperWow (UNIT_CASTEVENT) | Nampower v3.0+ (DLL注入), UnitXP_SP3 |
| 自我测试 | 内置 SelfTest 框架 | 无 |
| 宏语法引擎 | 无（Lua 直接调用 API） | 完整的 slash command 解析器 (条件+动作) |

---

## 二、SCM 拥有但 macro-torch 缺失的功能清单

### 2.1 🔴 高价值 — 强烈建议借鉴

#### Swing Timer 集成（平砍计时器）

SCM 通过 SP_SwingTimer 和 pfUI 实现了完整的平砍计时器系统：

| 条件 | 说明 |
|------|------|
| `[swingtimer:>80]` | 平砍进度 > 80%，可在下次平砍前插入技能 |
| `[rangedtimer:<20]` | 远程射击进度 < 20% |
| `[norangedclip]` | 当前技能的施法时间不会卡掉下次远程平砍 |
| `[slamwindow]` | 计算在当前平砍周期内可安全施放 Slam 的时间窗口 |
| `[noslamclip]` | 施放当前技能不会导致下次 Slam 卡平砍 |
| `[instantwindow]` | 施放瞬发技能后仍有足够时间在下次平砍前施放 Slam |

**macro-torch 现状**: 无任何 swing timer 支持。对于战士的 Slam 循环、猎人的瞄准射击等需要精确控制平砍的技能，这意味着完全无法实现不卡平砍的优化。

**建议**: 这是 **最值得优先实现** 的功能。SP_SwingTimer 是轻量级独立 addon，集成成本低，收益极高。

#### 反应式技能 Proc 追踪

SCM 实现了完整的反应式技能系统：

| 功能 | 实现方式 |
|------|---------|
| `[reactive:Overpower]` | 战斗日志解析敌人闪避事件，4秒窗口 |
| `[reactive:Revenge]` | 战斗日志解析自己闪避/招架/格挡事件 |
| `[reactive:Riposte]` | 战斗日志解析敌人招架事件 |
| `ProcessAutoAttackEvent()` | Nampower v2.24+ 原生事件 (dodge/parry/block) |

核心机制（`Utility.lua:9224`）:
```lua
function CleveRoids.SetReactiveProc(spellName, duration, targetGUID)
    CleveRoids.reactiveProcs[spellName] = {
        expiry = GetTime() + duration,
        targetGUID = targetGUID
    }
end
```

**macro-torch 现状**: 无任何 proc 追踪。战士的压制、复仇，盗贼的还击等反应式技能只能通过动作条高亮被动判断。

**建议**: 从战斗日志解析入手，实现 `macroTorch.reactiveProcs` 表 + `ParseReactiveCombatLog()`。

#### 多目标扫描 (MultiScan)

SCM 支持在不切换目标的情况下扫描多个敌人：

| 优先级 | 说明 |
|--------|------|
| `nearest` | 最近的目标 |
| `farthest` | 最远的目标 |
| `highesthp` / `lowesthp` | 血量百分比最高/最低 |
| `highestrawhp` / `lowestrawhp` | 血量绝对值最高/最低 |
| `markorder:876` | 按自定义团队标记顺序 |
| `skull/cross/square/...` | 指定具体团队标记 |

核心机制（`Conditionals.lua:3113`）:
- 不切换玩家目标，通过 UnitXP + nameplate GUID + 已知 GUID 缓存枚举
- 支持 `@unit` 语义
- 带 combat check（仅计入在战斗中的敌人）

**macro-torch 现状**: 只有 `targetEnemy()` 简单切换到最近敌人，无多目标扫描能力。

**建议**: 这是提升 AOE 和智能目标选择的关键功能。实现 `CountEnemiesMatching(checkFunc)` 和 `ResolveMultiscanTarget()`。

### 2.2 🟡 中等价值 — 值得考虑

#### Crowd Control 检测

SCM 通过 BuffLib 实现了完整的 CC 检测：

| 条件 | 说明 |
|------|------|
| `[cc:stun]` / `[cc:fear]` / `[cc:root]` | 指定 CC 类型 |
| `[cc:disorient]` / `[cc:silence]` / `[cc:charm]` | 其他 CC 类型 |
| `[cc]` / `[cc:any]` | 任意失控效果 |
| `[player:cc:stun]` / `[focus:cc:root]` | 任意单位的 CC 状态 |

核心机制（`Conditionals.lua:5563`）:
- BuffLib 优先路径（支持 overflow debuff）
- 内置 spell→mechanic 映射表作为 fallback
- 包含中文、俄语、韩语等多语言 CC 检测

**macro-torch 现状**: 无任何 CC 检测能力。

**建议**: 对于 PvP 宏尤其重要。可以先实现基础的 `ValidateUnitCC(unit, ccType)`，暂不需要 BuffLib 集成。

#### 免疫检测数据库

SCM 维护了一个完整的 NPC→法术/伤害类型免疫数据库：

```lua
CleveRoids_ImmunityData = {
    fire = { ["Ragnaros"] = true, ["Baron Geddon"] = true, ... },
    nature = { ["Princess Huhuran"] = { buff = "Nature Protection" }, ... },
    ...
}
```

支持:
- `/addimmunity <NPC名> <school/CC类型> [buff名]` — 用户可扩展
- `/listimmunity <school>` — 查看已知免疫
- Split damage 法术（如 Rake: 物理+流血）的分段免疫检测

**macro-torch 现状**: 有基础的 `target.isImmune(spellName)` + `target.recordImmune()`，但基于运行时发现（spell fail event），无预置数据库。

**建议**: SCM 的数据集可以直接复用，在 macro-torch 中增加预置免疫数据层作为 `target.isImmune()` 的第一道检查。

#### 平砍结果分析

SCM 通过 Nampower 的 AUTO_ATTACK 事件追踪每次平砍的结果：

| 条件 | 说明 |
|------|------|
| `[lastswing:crit]` | 上次平砍暴击 |
| `[lastswing:glancing]` | 上次平砍偏斜 |
| `[lastswing:miss]` / `[lastswing:dodge]` | 上次平砍未命中/被闪避 |
| `[lastswing:parry]` / `[lastswing:blocked]` | 上次平砍被招架/格挡 |
| `[incominghit:crit]` / `[incominghit:crushing]` | 受到的平砍暴击/碾压 |

**macro-torch 现状**: 无。

**建议**: 如果 Nampower 不可用（macro-torch 当前依赖 SuperWow），可以通过战斗日志解析实现类似功能。

#### 法术施法时间查询

```lua
function CleveRoids.GetSpellCastTime(spellName)
    -- 从 spellbook tooltip 解析施法时间
    -- 带缓存（2秒刷新），自动考虑天赋/急速
end
```

**macro-torch 现状**: 无此能力。这对 `[norangedclip]` 等 clip 检测是必需的。

#### 敌人计数（Count Mode）

```lua
[meleerange:>1]    -- 近战范围内超过 1 个敌人
[behind:>=2]       -- 背后至少 2 个敌人
[inrange:Blizzard:>3] -- Blizzard 范围内超过 3 个敌人
```

**macro-torch 现状**: 无。只能通过 `mateNearMyTargetCount` 判断队友附近目标数。

#### 法术施法队列感知

SCM 通过 Nampower 的原生 spell queue 提供队列感知：

| 条件 | 说明 |
|------|------|
| `[queuedspell:X]` | 指定法术在 Nampower 队列中 |
| `[queuedspell]` | 任意法术在队列中 |
| `[onswingpending]` | 下次平砍时触发的技能待处理（Slam 等） |

**macro-torch 现状**: 无队列感知。

#### 玩家属性比较

SCM 支持玩家属性值比较: `[stat:str>200]`, `[stat:agi<100]`, `[stat:ap>800]`, `[stat:spell_power>300]`, `[stat:fire_power>100]`, `[stat:armor>5000]` 等 20+ 种属性。

**macro-torch 现状**: 无。

#### Tap 状态追踪

`[tag]` / `[mytag]` / `[othertag]` — 追踪目标是否已被自己/他人标记（抢怪保护）。

**macro-torch 现状**: 无。

#### 目标职业检测

`[class:Mage]` / `[class:Warrior]` — 检测目标职业类型。PvP 场景下针对性施法。

**macro-torch 现状**: 通过 `UnitClass` 手动判断，无统一条件。

#### Combo Point Tracker 模块

SCM 有一个独立的 `ComboPointTracker.lua` (42KB)，实现：
- 连击点数追踪（比 GetComboPoints 更可靠）
- 基于连击点的终结技伤害/持续时间计算（Eviscerate, Kidney Shot, Rip, FB 等）
- Dark Harvest / Carnage 等特殊机制

**macro-torch 现状**: 有 `GetComboPoints()` 直接调用，但无 scaling 计算。

#### 扩展系统 (Extension System)

`ExtensionsManager.lua` 提供完整的扩展框架：
- 事件注册/注销
- 全局函数 Hook（带防死循环保护）
- 方法 Hook
- 已实现扩展: MacroLengthWarn, MacroErrorUI, CursiveCustomSpells, OverflowBuffFrame

**macro-torch 现状**: 无扩展系统。

### 2.3 🟢 较低优先级 — 锦上添花

| 功能 | SCM 实现 | macro-torch 现状 |
|------|---------|-----------------|
| **Aura Cap 检测** | `[buffcapped]` / `[debuffcapped]` — 32 buff / 16 debuff slots | 无 |
| **移动速度** | `[moving:>100]` — MonkeySpeed 集成 | 无 |
| **TTK/TTE** | TimeToKill addon 集成 | 无 (但有 `target.willDieInSeconds()` 基于 HRPS) |
| **武器附魔检测** | `[mhimbue:Flametongue]` / `[ohimbue:Frostbrand]` | 无 |
| **生物类型** | `[creaturetype:Humanoid/Beast/Dragonkin/...]` | 部分通过 `UnitCreatureType` 手动判断 |
| **目标等级** | `[level:>60]` / `[level:<30]` | 部分通过 `UnitLevel` 手动判断 |
| **法术消耗** | `GetSpellCost()` — 返回 mana/rage/energy | `_hasResource()` 手动传入 |
| **抵抗状态** | `SetResistState()` — 追踪法术被抵抗 | 通过 recordFailTable 追踪 |
| **Talent Modifiers** | `ApplyTalentModifier()` — 天赋影响技能持续时间 | 无 |
| **Set Bonus Modifiers** | `ApplySetBonusModifier()` — 套装影响技能 | 无 |
| **饰品管理** | `GetTrinkets()` — Nampower API 快速枚举饰品 | 有基础 `useTrinket1/2` |
| **所有施法者 Aura** | `GetAllCasterAuraTimeRemaining()` — 包括其他玩家施放的 debuff | 仅通过 UnitDebuff 查询自己施放的 |
| **施法序列** | `/castsequence reset=target/combat Spell1, Spell2, nil` | 无（通过 Lua 状态机手动实现） |

---

## 三、SCM 实现质量值得借鉴之处

### 3.1 性能优化基础设施

```lua
-- 1. Module-level upvalues（避免每次调用全局查找）
local GetTime = GetTime
local UnitExists = UnitExists
local pairs = pairs

-- 2. Per-frame single GetTime()
local time = GetTime()  -- OnUpdate 开头一次，全帧复用

-- 3. 多层缓存
CleveRoids.spellIdCache = {}        -- spell name → spell ID
CleveRoids.spellNameCache = {}      -- 构造的完整 spell name
_normalizedNames = {}               -- 下划线→空格
_lowercaseCache = {}                -- string.lower 缓存
_baseNameCache = {}                 -- 去 rank 后的基础名

-- 4. Event throttling
CleveRoids.lastUnitAuraUpdate = 0
CleveRoids.EVENT_THROTTLE = 0.1    -- 100ms throttle

-- 5. Cleanup timer (not per-frame)
CleveRoids.CLEANUP_INTERVAL = 5     -- 5秒清理一次
```

**macro-torch 现状**: 无此类性能优化。`GetTime()` 在每次调用时单独获取，无事件 throttling。

**建议**: 至少引入:
- `biz_util.lua` 或 `impl_util.lua` 中的关键全局函数 upvalue
- 高频事件的 throttling
- spell name cache

### 3.2 Personal vs Shared Debuff 区分

SCM 通过 libdebuff 区分个人 debuff 和共享 debuff，这对显示正确的剩余时间至关重要：

```lua
-- Personal debuff: 只看自己施放的
-- Shared debuff: 看任意施法者的
function IsSharedDebuffByIdOrName(lib, spellID, debuffName)
```

**macro-torch 现状**: 所有 debuff 检测都是通过 texture 匹配，不区分来源。这可能导致判断"debuff 是否是自己上的"不准确。

### 3.3 Overflow Buff/Debuff 追踪

SCM 知道 NPC 的 debuff 可以溢出到 buff 栏位（第17-48位），因此会在 buff 栏中也搜索 debuff：

```lua
-- 非玩家单位: debuff 可能溢出到 buff 栏位 (33-48)
for i = 1, 32 do
    local texture, stacks, spellID = UnitBuff(unitId, i)
    -- 检查是否是溢出 debuff
end
```

**macro-torch 现状**: 仅在 1-40 范围内搜索 UnitBuff/Debuff，但不知道溢出机制。对于团队副本中大量 debuff 的 NPC 可能漏检。

---

## 四、macro-torch 的独特优势（SCM 缺少的）

| 功能 | 说明 |
|------|------|
| **Land Table 系统** | 通过 UNIT_CASTEVENT 追踪法术是否成功命中、抵抗、闪避、免疫，按怪物名维护 LRU 栈。这在 SCM 中无等价物。 |
| **HRPS 预测** | 最小二乘法线性回归预测目标血量下降速率 → `willDieInSeconds()`。SCM 依赖外部 TimeToKill addon。 |
| **Item Loading 系统** | 完整的"装备→使用→换回"循环，支持 backup item 配置。SCM 有更基础的装备交换。 |
| **Periodic Task 框架** | `registerPeriodicTask()` / `removePeriodicTask()` 统一管理周期性任务 |
| **SelfTest 框架** | 内置自我测试，可注册强制/可选测试项 |
| **Entity 继承体系** | Unit → Target/Player/Pet/Group 的面向对象模型，属性懒加载 |
| **Class-based 架构** | 每个职业独立文件，关注点分离清晰 |
| **SpellTrace 声明式 API** | `SpellTrace:register(name, {land=true, immune=true, ...})` 声明式注册 |

---

## 五、优先级建议的实现路线图

### Phase 1: 基础补全（建议立即开始）

1. **Swing Timer 集成** — 接入 SP_SwingTimer
   - 实现 `player.swingPercentElapsed` (属性)
   - 实现 `swingtimer` 条件语义
   - 战士 Slam 循环可以直接受益

2. **反应式 Proc 追踪** — 战斗日志解析
   - 实现 `macroTorch.reactiveProcs` 表
   - 解析 dodge/parry/block 事件
   - 支持 Overpower, Revenge, Riposte

3. **性能基础设施**
   - 关键全局函数 upvalue
   - Per-frame GetTime() 复用
   - 高频事件 throttling

### Phase 2: 高级功能

4. **多目标扫描** — `CountEnemiesMatching()` + `ResolveMultiscanTarget()`
5. **CC 检测** — `ValidateUnitCC()` 基础实现
6. **免疫预置数据库** — 复用 SCM 的 `CleveRoids_ImmunityData`
7. **施法时间查询** — `getSpellCastTime()` 从 tooltip 解析

### Phase 3: 锦上添花

8. **Aura Cap 检测** — `buffcapped` / `debuffcapped`
9. **平砍结果分析** — `lastswing` / `incominghit`
10. **敌人计数** — count mode conditionals
11. **Overflow debuff 检测** — NPC debuff 溢出扫描

---

## 六、关键技术实现细节

### Swing Timer 集成（推荐方案）

```lua
-- SP_SwingTimer 提供的全局变量:
-- st_timer: 当前平砍剩余时间 (秒)
-- st_timerMax: 当前平砍总时间 (秒)
-- st_timerRange: 远程射击剩余时间
-- st_timerRangeMax: 远程射击总时间

-- 实现建议 (放入 entity/Player.lua)
function macroTorch.getSwingPercentElapsed()
    if st_timer ~= nil and st_timerMax ~= nil and st_timerMax > 0 then
        return ((st_timerMax - st_timer) / st_timerMax) * 100
    end
    return nil
end

function macroTorch.getSwingRemaining()
    if st_timer ~= nil then
        return st_timer
    end
    return nil
end
```

### 反应式 Proc 追踪（推荐方案）

```lua
-- 在 core/events.lua 中添加:
macroTorch.reactiveProcs = {}

local REACTIVE_PATTERNS = {
    Overpower = {
        patterns = {"你躲闪了", "You dodge", "dodge"},
        type = "enemy_dodge",
        duration = 5.0,
        requiresTargetGUID = true,
    },
    Revenge = {
        patterns = {"你闪避了", "你招架了", "你格挡了",
                    "You parry", "You block"},
        type = "player_avoid",
        duration = 5.0,
    },
}

function macroTorch.parseReactiveCombatLog(message)
    for spellName, config in pairs(REACTIVE_PATTERNS) do
        for _, pattern in ipairs(config.patterns) do
            if string.find(message, pattern) then
                macroTorch.reactiveProcs[spellName] = {
                    expiry = GetTime() + config.duration,
                    targetGUID = config.requiresTargetGUID
                        and macroTorch.target.guid or nil,
                }
                return
            end
        end
    end
end
```

### 多目标扫描（推荐方案）

```lua
-- 放在新文件 core/target_scan.lua
function macroTorch.countEnemiesMatching(checkFunc)
    local count = 0
    local checked = {}

    -- 1. 当前目标
    if macroTorch.target.isCanAttack then
        checked[macroTorch.target.guid] = true
        if checkFunc("target") then count = count + 1 end
    end

    -- 2. 队友目标
    for i = 1, 4 do
        local unit = "party" .. i .. "target"
        if UnitExists(unit) and UnitCanAttack("player", unit) then
            local guid = macroTorch.getUnitGuid(unit)
            if guid and not checked[guid] then
                checked[guid] = true
                if checkFunc(unit) then count = count + 1 end
            end
        end
    end

    -- 3. raid targets (if in raid)
    if GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            -- ...
        end
    end

    return count
end
```

---

## 七、总结

SuperCleveRoidMacros 作为一个成熟的通用宏框架，其最大的优势在于：

1. **底层事件系统的深度利用** — 通过 Nampower 的 DLL 注入获得原生 AUTO_ATTACK、SPELL_GO 等事件，macro-torch 的 SuperWow 路径也能做到部分
2. **战斗日志解析的威力** — 通过解析文本日志实现 proc 追踪、平砍结果分析，这完全不依赖特定注入框架
3. **庞大的预设数据集** — 免疫数据库、CC spell→mechanic 映射、split damage spell 列表，这些数据可以直接复用
4. **极致的性能优化** — upvalue、cache、event throttling、cleanup timer 分层

macro-torch 的独特优势在于其 **面向对象的架构设计** 和 **专注于职业特定逻辑的深度**（特别是猫德的 energy 计算、reshift 时机等复杂逻辑）。

**最值得优先借鉴的三个功能**: Swing Timer 集成 → 反应式 Proc 追踪 → 多目标扫描。这三项可以直接提升 macro-torch 在物理 DPS 职业（战士、盗贼、猫德）上的表现。