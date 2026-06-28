# Phase 17: catLeveling FF prowling guard + global spellId 动态更正机制 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 17-1-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr
**Areas discussed:** 映射数据结构, 持久化方案, current_casting_spell 生命周期, 迁移范围

---

## 映射数据结构 — name→spellId 单向映射

| Option | Description | Selected |
|--------|-------------|----------|
| A: 扁平双 key table | 每个中英文名各一条 entry 指向同一 spellId | ✓ |
| B: alias 辅助表 | 主表纯英文 + alias 表做中→英翻译 | |
| C: metatable 自动规范化 | __index 做 string.lower 查找 + 缓存 | |
| D: 静态+运行时双表 | 静态基准与运行时修正独立存储 | |

**User's choice:** A: 扁平双 key table
**Notes:** 用户明确只需单向映射（name→spellId），不需要从 spellId 反查。扁平双 key 最简单直接，与现有 `tracingSpells` 风格一致。

---

## 持久化方案 — 格式、文件、加载/保存时机

| Option | Description | Selected |
|--------|-------------|----------|
| A: SM_EXTEND 嵌套 table | SM_EXTEND.spellIdMap[playerCls][spellName]，仿 immuneTable 模式 | ✓ |
| B: SM_EXTEND 扁平 | SM_EXTEND.spellIdMap[spellName]，去掉 playerCls 层级 | |
| C: 纯文本序列化 | 自实现序列化，7000 字符限制 | |

**User's choice:** A: SM_EXTEND 嵌套 table
**Notes:** 完全沿袭 immuneTable/definiteBleedingTable 已验证模式，风险最低。SM_EXTEND 是 WoW SavedVariable，登出时自动序列化。加载在 PLAYER_ENTERING_WORLD，写入在 UNIT_CASTEVENT 检测到不一致时立即执行（防止崩溃丢数据）。

---

## current_casting_spell 生命周期

| Option | Description | Selected |
|--------|-------------|----------|
| A + 1: _castSpell + 立即清除 | _castSpell 返回 true 前设置，UNIT_CASTEVENT 匹配后 nil | ✓ |
| A + 3: _castSpell + 覆盖 | _castSpell 设置，每次新施法自然覆盖 | |
| A + 2: _castSpell + 超时 | _castSpell 设置，2秒 periodic task 自动清除 | |

**User's choice:** A + 1: _castSpell 设置 + UNIT_CASTEVENT 匹配后立即清除
**Notes:** _castSpell 是所有 Druid 技能方法的唯一施放瓶颈，一处改动全覆盖。mode='ready' 路径不设置（不施法）。立即清除保证生命周期最短，无 stale state 残留。

---

## 迁移范围

| Option | Description | Selected |
|--------|-------------|----------|
| 仅 Druid land tracing | Pounce/Rake/Rip/FB 4 个技能改为按名称注册 | ✓ |
| 全部统一迁移 | 所有 SpellTrace:register 调用改为按名称 | |
| spellName + spellId fallback | 新 API 同时接受两者，向后兼容 | |

**User's choice:** 仅 Druid land tracing
**Notes:** 只有 land=true 才需要 spellId（用于 tracingSpells 匹配 UNIT_CASTEVENT）。Hunter 等只用 immune tracing，不需要 spellId。这是最小改动，精准解决 Druid.lua:611 注释标注的已知痛点。

---

## Key Clarifications from User

- **只需单向映射**（name→spellId），不需要从 spellId 反查技能名
- 映射表同时包含中英文两种技能名称

## Deferred Ideas

- 其他职业 land tracing 迁移（可复用本次基础设施）
- catLeveling 低等级技能 spellId 自动发现（基础设施就绪后自然支持）