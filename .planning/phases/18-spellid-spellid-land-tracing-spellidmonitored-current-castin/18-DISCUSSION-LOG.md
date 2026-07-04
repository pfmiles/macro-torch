# Phase 18: spellId 自动更正机制改造方案（最终版） - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-04
**Phase:** 18-spellid-spellid-land-tracing-spellidmonitored-current-castin
**Areas discussed:** 白名单注册时机, 白名单数据结构, current_casting_spell 安全性, SpellTrace API 变更范围

---

## 白名单注册时机

| Option | Description | Selected |
|--------|-------------|----------|
| A: land=true 自动推导 | land=true 且 spellName 存在时自动加入白名单。零额外配置，4 个 Druid 注册无需改动 | ✓ |
| C: 显式 monitorSpellId 字段 | 新增 config.monitorSpellId 字段，独立于 land。最精确但调用侧需加字段 | |
| D: _castSpell 内联 resolveSpellId | 不维护白名单，直接在 _castSpell 中 resolveSpellId 判非 nil。1 行 diff，最简实现 | |

**User's choice:** A — land=true + spellName 自动推导
**Notes:** land=true 是 spellId 监控的充分必要条件。当前 4 个 Druid land-tracing spells 完全兼容。

---

## 白名单数据结构

| Option | Description | Selected |
|--------|-------------|----------|
| A: 独立 set table | macroTorch._spellIdMonitored = {['Pounce']=true, ...}，独立维护，语义清晰 | ✓ |
| B: 复用 SPELL_NAME_TO_ID | 直接查 SPELL_NAME_TO_ID[localeNames.en] ~= nil 判断是否被监控，零新结构 | |
| C: 挂 SpellTrace 命名空间 | macroTorch.SpellTrace._monitored = {...}，封装在命名空间内 | |

**User's choice:** A — 独立 set table
**Notes:** O(1) hash lookup，与现有 tracingSpells / traceSpellImmunes 风格一致。

---

## current_casting_spell 安全性

| Option | Description | Selected |
|--------|-------------|----------|
| A+B: 保持+stale检测 | 保持 Phase 17 的 UNIT_CASTEVENT 清除机制，在 _castSpell 设置前加 1 行 stale 检测+warning 日志 | ✓ |
| A: 保持 Phase 17 方案 | 不做任何改动，白名单后风险已可接受 | |
| B: 仅加 stale 检测 | 仅加 warning 日志，不改变清除机制 | |

**User's choice:** A+B — 保持 + stale 检测
**Notes:** 白名单将风险面缩减 ~50 倍。stale 检测提供防御性可观测性，使用 macroTorch.log() 持久化日志。

---

## SpellTrace API 变更范围

| Option | Description | Selected |
|--------|-------------|----------|
| D: monitorSpellId 默认=land 可覆盖 | 新增可选 config.monitorSpellId，默认值等于 land。当前 4 个 Druid 注册无需改动 | ✓ |
| A: 无新字段，land 自动推导 | 不扩展 API，land=true + spellName 自动进白名单，最简单 | |
| C: monitorSpellId 独立显式字段 | 必填新字段，最显式但 4 个 Druid 调用点需加一行 | |

**User's choice:** D — monitorSpellId 默认=land 可覆盖
**Notes:** 兼顾自动化和精确控制。当前 Druid 零改动，未来可通过显式覆盖控制边界情况。

---

## Claude's Discretion

- `_spellIdMonitored` 在 spell_trace_core.lua 中的初始化位置
- stale 检测 warning 的具体日志格式（推荐 macroTorch.log）
- `config.monitorSpellId` 默认值解析逻辑
- Selftest Category L 的具体用例数量

## Deferred Ideas

- 非 land-tracing 技能的 spellId 监控（通过 monitorSpellId=true 纳管）
- land=true 但排除监控（通过 monitorSpellId=false）
- 其他职业 land tracing 迁移（自动获得白名单监控）
- current_casting_spell 超时清除（SuperWow 事件丢失实战验证后再考虑）