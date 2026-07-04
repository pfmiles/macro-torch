# Phase 18: spellId 自动更正机制改造方案（最终版） - Context

**Gathered:** 2026-07-04
**Status:** Ready for planning

<domain>
## Phase Boundary

将 Phase 17 的 `current_casting_spell` 无条件设值改造为 `_spellIdMonitored` 白名单机制。核心变更：

1. **SpellTrace:register 自动维护白名单** — `land=true` 且 `config.spellName` 存在时，自动将 spellName 加入 `macroTorch._spellIdMonitored` set
2. **_castSpell 白名单守卫** — 仅当 `_spellIdMonitored[localeNames.en]` 为 true 时才设置 `current_casting_spell`，替代当前无条件设值
3. **新增 `config.monitorSpellId` 可选字段** — 默认值等于 `config.land`，允许精确覆盖

**涉及文件：**
- `core/spell_trace_core.lua` — SpellTrace:register 白名单维护 + `_spellIdMonitored` 初始化
- `entity/Player.lua` — _castSpell 白名单守卫 + stale 检测 warning
- `core/events.lua` — UNIT_CASTEVENT spellId 更正逻辑（保持 Phase 17，无需改动）
- `core/selftest.lua` — 新增 Category L 白名单验证 selftest

**不涉及：** Druid.lua spell 注册（当前 4 个 land=true+spellName 已满足条件）、其他职业、SPELL_NAME_TO_ID 映射表（不变）
</domain>

<decisions>
## Implementation Decisions

### D-01: 白名单注册时机
- **land=true + config.spellName 存在** → SpellTrace:register 自动将 `config.spellName` 加入 `macroTorch._spellIdMonitored[spellName] = true`。零额外配置，4 个 Druid 注册无需改动。

### D-02: 白名单数据结构
- **独立 set table**：`macroTorch._spellIdMonitored = {}`，在 `core/spell_trace_core.lua` 顶部初始化。`_castSpell` 通过 `macroTorch._spellIdMonitored[localeNames.en]` 做 O(1) 查表。

### D-03: SpellTrace API — monitorSpellId 可选字段
- 新增 `config.monitorSpellId` 可选字段，**默认值 = `config.land`**（nil 视为 false）。
- 当前 4 个 Druid land-tracing 注册无需改动（land=true 自动推导 monitorSpellId=true）。
- 未来可通过 `monitorSpellId=false` 在 land=true 时排除，或 `monitorSpellId=true` 在 land=false 时纳入。

### D-04: current_casting_spell stale 检测
- **保持 Phase 17 清除机制**：UNIT_CASTEVENT 处理完 spellId 更正后 `current_casting_spell = nil`（events.lua:119）。
- **新增 stale 检测**：`_castSpell` 设置 `current_casting_spell` 前，若已非 nil（上次未清除），通过 `macroTorch.log()` 输出 warning，然后覆盖。

### D-05: 向后兼容
- `config.spellId` 遗留注册（无 spellName）：不进白名单，land tracing 仍正常工作，但不参与 spellId 更正监控。
- `setSpellTracing(spellId, name)` 直接调用：不进白名单，保持现有行为不变。

### Claude's Discretion
- `_spellIdMonitored` 在 spell_trace_core.lua 中的具体初始化位置（SpellTrace 命名空间之前/之后）
- stale 检测 warning 的具体日志格式（使用 macroTorch.log 还是 macroTorch.show）
- `config.monitorSpellId` 默认值解析逻辑的具体实现（`if config.monitorSpellId == nil then monitor = config.land end`）
- Selftest Category L 的具体用例数量和覆盖范围
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 18 目标
- `.planning/REQUIREMENTS.md` — R4 (Spell Trace 配置化) 约束

### 直接依赖 Phase
- `.planning/phases/17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr/17-CONTEXT.md` — SPELL_NAME_TO_ID 映射表、resolveSpellId、loadSpellIdMap、current_casting_spell 桥接、SpellTrace:register spellName 支持

### 关键源文件
- `core/spell_trace_core.lua:15-83` — tracingSpells、setSpellTracing、resolveSpellId、SpellTrace:register — 白名单维护点
- `core/spell_id_map.lua:17-32` — SPELL_NAME_TO_ID 静态映射表（8 entries, EN+ZH）
- `core/spell_trace_immune.lua:105-132` — loadSpellIdMap 持久化 + tracingSpells key 迁移
- `entity/Player.lua:42-94` — _castSpell 施法瓶颈，白名单守卫 + stale 检测点
- `core/events.lua:87-124` — UNIT_CASTEVENT 处理，spellId 更正 + current_casting_spell 清除
- `classes/druid/Druid.lua:614-633` — 当前 4 个 land-tracing spell 注册（不改动）
- `macro_torch.lua` — 全局命名空间初始化

### 构建系统
- `build_order.txt` — 确认 core/spell_id_map.lua 在 core/spell_trace_core.lua 之前
</canonical_refs>

<code_context>
## Existing Code Insights

### _castSpell 当前桥接代码 (entity/Player.lua:77-93)
```lua
-- 4. Execute the cast
if mode ~= 'ready' then
    macroTorch.current_casting_spell = localeNames.en  -- ← 无条件设值，需加白名单守卫
end
if onSelf then
    CastSpellByName(spellName, true)
else
    obj.cast(spellName, rank)
end
return true
```

### SpellTrace:register 当前实现 (spell_trace_core.lua:63-83)
```lua
function macroTorch.SpellTrace:register(name, config)
    if config.land then
        local spellId = nil
        if config.spellName then
            spellId = macroTorch.resolveSpellId(config.spellName)
        end
        if not spellId then spellId = config.spellId end
        -- ... setSpellTracing(spellId, name)
        -- ← 此处新增白名单写入: macroTorch._spellIdMonitored[config.spellName] = true
    end
    -- ...
end
```

### UNIT_CASTEVENT spellId 更正 (events.lua:87-124)
- 第 98-117 行：spellId 比较 + SM_EXTEND 持久化 + tracingSpells key 迁移
- 第 119 行：`macroTorch.current_casting_spell = nil`（保持，不改动）
- 第 121-123 行：`recordCastTable` 调用

### Reusable Assets
- `macroTorch.SPELL_NAME_TO_ID` — 静态映射表，resolveSpellId 依赖
- `macroTorch.resolveSpellId(spellName)` — 两级 spellId 解析
- `macroTorch.SpellTrace:register(name, config)` — 声明式注册 API，白名单维护插入点
- `macroTorch.log(level, message)` — SavedVariables-based 持久化日志

### Established Patterns
- **声明式注册**: `SpellTrace:register` / `SelfTest:register` — 配置优先，单一入口
- **全局 set table**: `macroTorch.tracingSpells = {}`、`macroTorch.traceSpellImmunes = {}` — 与 `_spellIdMonitored` 同一风格
- **默认参数模式**: `isOptional = isOptional or false` — 与 `config.monitorSpellId` 默认值逻辑一致
- **SM_EXTEND 持久化**: `spellIdMap[playerCls][spellName] = correctedId` — 运行时更正写入
</code_context>

<specifics>
## Specific Ideas

- `_spellIdMonitored` 白名单的初始化位置建议在 `spell_trace_core.lua` 顶部，紧随 `tracingSpells` 和 `traceSpellImmunes` 初始化之后（第 14 行附近）
- `_castSpell` 的白名单检查逻辑：`if mode ~= 'ready' and macroTorch._spellIdMonitored[localeNames.en] then` — 一行改动
- stale 检测 warning 建议使用 `macroTorch.log('warn', ...)` 写入持久化日志而非聊天框 `macroTorch.show`（避免干扰用户），格式：`"current_casting_spell was not cleared: " .. old_value .. " → " .. new_value`
- `config.monitorSpellId` 默认值逻辑：`local shouldMonitor = (config.monitorSpellId ~= nil) and config.monitorSpellId or (config.land or false)`
- Phase 18 不涉及 config.spellId 遗留路径的迁移 — 仅 spellId 的 register 不进白名单，功能不受影响
</specifics>

<deferred>
## Deferred Ideas

- **非 land-tracing 技能的 spellId 监控**：若未来某技能 land=false 但需要 spellId 更正，可通过 `monitorSpellId=true` 显式纳入
- **land=true 但排除监控**：若未来某环境 spellId 永远准确，可通过 `monitorSpellId=false` 排除
- **其他职业 land tracing 迁移**：Phase 8 已建立 SpellTrace:register 基础设施，未来职业添加 land tracing 时自动获得白名单监控
- **current_casting_spell 超时清除**：当前评估为过度设计，若 SuperWow 事件丢失问题在实战中被证实，届时再考虑

None — 讨论保持在 Phase 18 范围内。
</deferred>

---

*Phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin*
*Context gathered: 2026-07-04*