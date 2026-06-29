# Phase 17: catLeveling FF prowling guard + global spellId 动态更正机制 - Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

此 Phase 交付两个独立改动：

1. **catLeveling FF 潜行守卫** — 在 `catLeveling()` 函数中，Faerie Fire (Feral) 不能在潜行（prowling）状态下释放。添加 `not player.isProwling` guard。

2. **global spellId 动态映射系统** — 将 spell tracing/immune 的硬编码 spellId 注册改为按名称注册，建立 name→spellId 单向映射表（支持中英文技能名称）。以 60 级 spellId 为静态基准写死在代码中；运行时通过 UNIT_CASTEVENT 事件捕获真实 spellId，若与静态映射不一致则自动更新；映射数据持久化到文件（参考 immune table / definite table 机制）。

**关键约束：**
- 仅建立 name→spellId **单向**映射，不需要从 spellId 反查技能名
- 迁移范围仅限 **Druid land tracing**（Pounce/Rake/Rip/Ferocious Bite 共 4 个技能）
- Hunter 等只需 immune tracing 的职业不需要 spellId，本次不改动
- 持久化使用 SM_EXTEND SavedVariable（WoW 自动序列化，无需手动 flush）
</domain>

<decisions>
## Implementation Decisions

### Task 1: catLeveling FF 潜行守卫
- **D-01:** 在 catLeveling 的 FF 释放路径前添加 `not macroTorch.player.isProwling` 条件检查。潜行状态时跳过 FF，不阻止后续模块执行。

### Task 2-1: 映射数据结构
- **D-02:** 使用**扁平双 key table**：`spellNameToId = { ["Pounce"] = 9827, ["猛扑"] = 9827, ["Rake"] = 1822, ["斜掠"] = 1822, ... }`。每个中英文名称各一条 entry，指向同一 spellId。O(1) 直接哈希查找，与现有 `tracingSpells` 风格一致。

### Task 2-2: 持久化方案
- **D-03:** 使用 **SM_EXTEND 嵌套 table**，仿 `immuneTable` 模式：`SM_EXTEND.spellIdMap[playerCls][spellName] = realSpellId`。SM_EXTEND 是 WoW SavedVariable，登出时自动序列化到 `WTF/.../SuperMacro.lua`，无手动 flush。
- **D-04:** **加载时机**：`PLAYER_ENTERING_WORLD` 事件回调中（仿 `loadImmuneTable`），将 `SM_EXTEND.spellIdMap[playerCls]` 引用绑定到 `macroTorch.loginContext.spellIdMap`。
- **D-05:** **写入时机**：`UNIT_CASTEVENT` 检测到 spellId 与静态映射不一致时**立即写入**（幂等 table mutation）。立即写入优于登出批量写入，防止客户端崩溃丢失本次会话的发现。

### Task 2-3: current_casting_spell 生命周期
- **D-06:** **设置**：在 `_castSpell`（`entity/Player.lua`）返回 true 前设置 `macroTorch.current_casting_spell = spellName`。`_castSpell` 是所有 Druid 技能方法（40+ 个）的唯一施放瓶颈，一处改动全覆盖。注意：`mode='ready'` 路径（仅检查可用性不施法）不设置。
- **D-07:** **清除**：`UNIT_CASTEVENT`（`core/events.lua`）收到匹配的 `castType='CAST'` 事件后立即设置 `macroTorch.current_casting_spell = nil`。生命周期最短，无 stale state 残留。

### Task 2-4: 迁移范围
- **D-08:** **仅迁移 Druid land tracing**：Pounce (9827→name)、Rake (1822→name)、Rip (9492→name)、Ferocious Bite (22557→name)。Faerie Fire (Feral) 只用 immune tracing（land=false），无需 spellId，不改动。
- **D-09:** 其他职业（Hunter/Mage/Priest 等）只用 immune tracing，不需要 spellId，本次不改动。
- **D-10:** `SpellTrace:register()` 新增 `config.spellName` 字段作为 spellId 的替代。当 `land=true` 且 `config.spellName` 存在时，通过 name→spellId 映射表解析真实 spellId 再调用 `setSpellTracing`。保留 `config.spellId` 作为 fallback。

### Task 2-5: 静态映射基准
- **D-11:** 以 60 级 Druid 技能的 Global Spell ID 为静态基准，硬编码在代码中。当前已知映射（Turtle WoW 客户端）：Pounce=9827, Rake=1822, Rip=9492, Ferocious Bite=22557。另需补充对应的中文名称。

### Task 2-6: 运行时动态更正流程
- **D-12:** 在 `UNIT_CASTEVENT` 处理中（`events.lua:93-96`），当 `castType='CAST'` 时：若 `current_casting_spell` 非 nil，用映射表解析其静态 spellId，与事件中的 spellId 比较。若不一致，将事件中的真实 spellId 写入 `SM_EXTEND.spellIdMap[playerCls][spellName]` 并更新 `tracingSpells` 中的 key 映射。

### Claude's Discretion
- 扁平双 key table 的全局变量命名（如 `macroTorch.SPELL_NAME_TO_ID`）
- 静态映射表中英文名称的具体列表（需确认中文客户端的技能名称）
- `loadSpellIdMap()` 函数的具体实现和生命周期
- SpellTrace:register 中 `spellName` 字段解析与 fallback 逻辑的具体实现
- UNIT_CASTEVENT 中 spellId 比对和更正逻辑的实现细节
- catLeveling FF prowling guard 的具体位置（在 keepFF 内联逻辑中的哪一行）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 17 目标
- `.planning/REQUIREMENTS.md` — R4 (Spell Trace 配置化) 约束

### 先前 Phase 决策（直接依赖）
- `.planning/phases/16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra/16-CONTEXT.md` — catLeveling 架构决策、模块优先级、可复用函数列表
- `.planning/phases/03-self-test-spell-trace/03-CONTEXT.md` — SpellTrace:register() 声明式 API 原始设计

### 关键源文件
- `core/spell_trace_core.lua` — `tracingSpells`, `setSpellTracing`, `SpellTrace:register` — spell tracing 基础设施
- `core/spell_trace_immune.lua` — `loadImmuneTable`, `loadDefiniteBleedingTable` — 持久化参考实现
- `core/events.lua:87-97` — `UNIT_CASTEVENT` 事件处理，运行时 spellId 匹配逻辑
- `entity/Player.lua` — `_castSpell` 底层施法瓶颈，`current_casting_spell` 设置点
- `classes/druid/Druid.lua:611-633` — 现有硬编码 spellId register（含已知问题 TODO）
- `classes/druid/leveling.lua` — catLeveling 实现，FF prowling guard 目标文件
- `biz_util.lua:21-61` — `getSpellIdByName` / `getSpellIdByNameRank` — Spellbook Index 查询（注意：非 Global Spell ID）

### 构建系统
- `build_order.txt` — 确认新文件（如 spellId 映射数据文件）的位置
</canonical_refs>

<code_context>
## Existing Code Insights

### tracingSpells 当前结构 (spell_trace_core.lua)
```lua
macroTorch.tracingSpells = {}  -- { [spellId] = spellName }
function macroTorch.setSpellTracing(spellGuid, spellName)
    macroTorch.tracingSpells[spellGuid] = spellName
end
```

### SpellTrace:register 当前 API (spell_trace_core.lua:51)
```lua
function macroTorch.SpellTrace:register(name, config)
    -- config: { spellId, immune, land, debuffTexture }
    if config.land then
        macroTorch.setSpellTracing(config.spellId, name)
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
```

### UNIT_CASTEVENT 处理 (events.lua:87-96)
```lua
elseif event == "UNIT_CASTEVENT" then
    local unitId, targetId, castType, spellId, timeCost = arg1, arg2, arg3, arg4, arg5
    -- debug log: unitId, targetId, type, spellId, timeCost
    if unitId == macroTorch.player.guid and castType == 'CAST' then
        if spellId and macroTorch.tracingSpells[spellId] then
            macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
        end
    end
```

### 现有硬编码 spellId (Druid.lua:611-633)
```lua
-- TODO 这里的spellId并不稳定，实践发现不同的客户端可能有不同的spellId
macroTorch.SpellTrace:register('Pounce', {
    spellId = 9827, land = true, immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
macroTorch.SpellTrace:register('Rake', {
    spellId = 1822, land = true, immune = true, debuffTexture = 'Ability_Druid_Disembowel'
})
macroTorch.SpellTrace:register('Rip', {
    spellId = 9492, land = true, immune = true, debuffTexture = 'Ability_GhoulFrenzy'
})
macroTorch.SpellTrace:register('Ferocious Bite', {
    spellId = 22557, land = true, immune = false
})
```

### _castSpell 施放瓶颈 (entity/Player.lua)
```lua
function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)
    -- resolves localeNames → spellName
    -- mode='ready': check only, return false (no cast)
    -- mode='raw': cast directly
    -- mode='safe': check energy + range then cast
    -- Returns boolean (true = attempted cast)
end
```

### immuneTable 持久化参考 (spell_trace_immune.lua)
- `SM_EXTEND.immuneTable[playerCls][spellName][mobName]` — 嵌套 table
- `loadImmuneTable()` 在 `onPlayerEnteringWorld()` 中调用
- 写入直接 mutate `macroTorch.context.immuneTable[...]`（与 SM_EXTEND 同一引用）
- 无手动 flush，依赖 WoW SavedVariable 自动序列化

### Reusable Assets
- `macroTorch.SpellTrace:register(name, config)` — 现有声明式 API，仅需扩展 `spellName` 字段
- `SM_EXTEND` SavedVariable — 已有持久化基础设施
- `getSpellIdByName(spellName, bookType)` — Spellbook Index 查询（注意：非 Global Spell ID，不可混用）
- `macroTorch.player.isProwling` — 已有潜行状态检测字段

### Established Patterns
- **声明式注册**: `SpellTrace:register()` / `SelfTest:register()` — 配置优先
- **SM_EXTEND 持久化**: immuneTable / definiteBleedingTable — 嵌套 table + 引用绑定 + 自动序列化
- **全局变量命名**: `macroTorch.*` 全空间，UPPER_SNAKE_CASE 用于模块级常量
- **事件驱动**: `UNIT_CASTEVENT` → 匹配 → 回调 — 现有 spell tracing 已用此模式
</code_context>

<specifics>
## Specific Ideas

- FF prowling guard 最简单直接：在 catLeveling 的 FF 释放路径前加一行 `if macroTorch.player.isProwling then return end`
- 映射表文件可仿 `texture_map.lua` 的模式：纯数据文件，放在 `core/spell_id_map.lua` 或根目录，通过 `build_order.txt` 按序拼接
- spellName 的值应与 `SpellTrace:register` 的第一个参数（name）完全一致，以保证映射查找一致性
- `_castSpell` 在 `mode='ready'` 时不设置 `current_casting_spell`（不施法），在 `mode='safe'`/`mode='raw'` 且返回 true 前设置
- 注意 `castSpellByName` 外部直接调用不走 `_castSpell`——检查代码是否有此类调用，如有则需同样处理
</specifics>

<deferred>
## Deferred Ideas

- **其他职业 land tracing 迁移**：Hunter/Mage/Priest/Rogue/Warlock/Warrior 当前只用 immune tracing，若未来需要 land tracing 可复用本次建立的映射基础设施
- **catLeveling 低等级技能 spellId**：练级时使用不同 rank 的技能（不同 Global Spell ID），当前 scope 仅建基础设施，低等级技能的实际 spellId 会在首次施放时自动发现
- **多语言扩展**：若未来需要支持第三种语言（如韩文/俄文客户端），在扁平双 key table 中添加新的语言别名即可
- **反向映射（spellId→name）**：本次明确不需要，但若未来 UNIT_CASTEVENT 处理需要反向查找，可在当前映射表基础上构建反向索引

None — 讨论保持在 Phase 17 范围内。
</deferred>

---

*Phase: 17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr*
*Context gathered: 2026-06-29*