# Phase 10: 创建5个Druid综合一键宏方法 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-16
**Phase:** 10-创建5个Druid综合一键宏方法
**Areas discussed:** 形态路由策略, druidAoe 范围, druidHeal 策略, 现有方法整合与文件位置

---

## 形态路由策略

| Option | Description | Selected |
|--------|-------------|----------|
| A: if-elseif 链 | 每个 combo 方法内用简单 if-elseif 按形态分支，最快最直观。不自动切形态（输出），自动切人形（治疗） | ✓ |
| B: Dispatch Table | 用查表法统一路由，添加新形态只需改 table。但 WoW Lua 无 JIT，table lookup 有性能开销 | |
| A + D 混合 | if-elseif 链 + 按方法语义差异化形态覆盖面 | |

**User's choice:** A: if-elseif 链
**Notes:** 用户确认使用简单的 if-elseif 链进行形态路由。关键约束：druidAtk 绝不自动切形态（切形态清空能量/怒气触发 GCD），druidHeal 必须自动切人形（野兽形态无法施法）。

---

## druidAoe 范围

| Option | Description | Selected |
|--------|-------------|----------|
| C: 熊+人双形态 | 熊形态→bearAoe()，人形态→Hurricane。猫形态无 AOE 可直接 return | ✓ |
| B: 熊+猫 fallback | 熊形态 bearAoe()，猫形态 fallback 到 catAtk() | |
| A: 纯熊形态 | 只做形态路由到 bearAoe()，其他形态不做任何事 | |

**User's choice:** C: 熊+人双形态
**Notes:** 用户确认覆盖熊和人两个有 AOE 能力的形态。WoW 1.12.1 猫形态无 AOE 技能，不需要 fallback。Hurricane 是引导技能需特殊处理。

---

## druidHeal 策略

| Option | Description | Selected |
|--------|-------------|----------|
| B: 单步切人形+HOT优先 | 不在人形时先切人形（一次按键），下次按键治疗。HOT优先（回春术）+ 血量低时直接治疗之触。V1仅自疗 | ✓ |
| B+D: +NS优先 | 在B基础上加入自然迅捷优先级 | |
| B: 单步+治疗之触 | 最简逻辑，只用最高级治疗之触 | |

**User's choice:** B: 单步切人形+HOT优先
**Notes:** 用户确认 V1 仅自疗（onSelf=true），遵循一键宏"一次一个动作"哲学。HOT 优先（回春术），治疗之触作为血量危机时的兜底。

---

## 现有方法整合与文件位置

| Option | Description | Selected |
|--------|-------------|----------|
| 1: 新建 combo.lua+内联重构 | 创建 classes/druid/combo.lua，全新实现 5 个方法。删除 utility.lua 中旧的 druidDefend/druidControl | ✓ |
| 5: 全新实现替换 | 同方案1，更激进地重写所有逻辑 | |
| 1: 新建+包装旧方法 | 创建 combo.lua，包装 utility.lua 中现有方法 | |

**User's choice:** 1: 新建 combo.lua+内联重构，且 druidStun 并入 druidControl，druidBuffs 保留在 utility.lua
**Notes:** 用户明确指出 druidStun（晕/冲锋控制）本质上是 druidControl 的一部分，应合并。druidBuffs 是独立的方便方法，保留在 utility.lua 不动。

---

## Claude's Discretion

- druidHeal 中"是否在人形态"判断的具体实现方式
- druidControl 中 Bash vs Feral Charge 的距离判定逻辑细节
- druidAoe 中 Hurricane 的 mana 检查阈值
- combo.lua 文件内部的代码组织顺序和注释风格
- druidDefend 中 Barkskin 和 Frenzied Regeneration 的具体条件判断
- druidHeal 是否有必要检测"已经有人形态 HOT"避免重复施法

## Deferred Ideas

- druidHeal 团队治疗（扩展中 targets 选择）
- druidHeal NS 瞬发优化（自然迅捷+瞬发治疗之触）
- casterAtk 鹌鹑远程输出
- 猫形态 AOE（如果 Turtle WoW 后续添加）
- druidBuff 组合宏