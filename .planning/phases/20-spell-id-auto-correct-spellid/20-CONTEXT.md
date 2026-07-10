# Phase 20 Context: SPELL_ID_AUTO_CORRECT 全局开关

## 目标

在 macro-torch 项目中添加一个全局开关 `macroTorch.SPELL_ID_AUTO_CORRECT`，用于控制是否启用基于 UNIT_CASTEVENT 事件的全局 spellId 自动修正机制。

## 背景

当前代码中存在一套完整的 spellId 动态修正机制。由于不同 Turtle WoW 客户端版本中，同一个技能的 Global Spell ID（来自 SuperWow 的 UNIT_CASTEVENT 事件第4参数）可能与 SPELL_NAME_TO_ID 中写死的静态基线不同，代码会在每次施法时通过事件上报的实际 spellId 与静态基线比对，发现差异后自动将修正值持久化到 SM_EXTEND.spellIdMap 中，同时同步到 loginContext.spellIdMap 并迁移 tracingSpells 的 key。此后 resolveSpellId() 优先返回修正值。

## 改造范围

涉及 5 个文件的改动：

### 1. macro_torch.lua — 定义开关变量
- 在 `macroTorch = {}` 之后定义 `macroTorch.SPELL_ID_AUTO_CORRECT = true`
- 附带注释说明其用途

### 2. core/spell_trace_core.lua — resolveSpellId() 守卫
- 当前逻辑：先查 loginContext.spellIdMap（修正值），找不到再 fallback 到 SPELL_NAME_TO_ID（静态值）
- 改造：外层加 `if macroTorch.SPELL_ID_AUTO_CORRECT then` 守卫，false 时跳过 loginContext.spellIdMap 查询，直接返回静态值

### 3. entity/Player.lua — _castSpell() 桥接变量守卫
- 将设置桥接变量 `macroTorch.current_casting_spell` 的代码块和上方的陈旧检测代码块整体用 `if macroTorch.SPELL_ID_AUTO_CORRECT then` 包裹
- 开关关闭时既不设置桥接变量，也不做陈旧检测

### 4. core/events.lua — UNIT_CASTEVENT 分支守卫
- 将整个 `if macroTorch.current_casting_spell then` 代码块用 `if macroTorch.SPELL_ID_AUTO_CORRECT then` 包裹
- 注意不要影响后面的 recordCastTable 调用，该调用仍需正常工作

### 5. core/spell_trace_immune.lua — loadSpellIdMap() 守卫
- 函数体开头加 `if not macroTorch.SPELL_ID_AUTO_CORRECT then return end`
- 开关关闭时完全跳过加载和迁移

## 设计要点

- **默认 true**：完全向后兼容，不影响现有行为
- **false 时 land tracing 失效**：spellId 与静态值不同的客户端上追踪会失效，这是预期行为
- **resolveSpellId 是唯一入口**：注册阶段 loginContext 不存在，本就 fallback 到静态值，无需额外改动
- **历史数据不动**：SM_EXTEND.spellIdMap 中已有的修正数据不会被清除，但开关关闭时不会被读取也不会被更新