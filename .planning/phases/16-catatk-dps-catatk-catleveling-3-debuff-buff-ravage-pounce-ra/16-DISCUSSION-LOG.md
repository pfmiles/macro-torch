# Phase 16: catLeveling 练级版一键宏 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-22
**Phase:** 16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra
**Areas discussed:** Rotation 架构, 中间循环优先级, 终结技策略, 神像舞取舍

---

## Rotation 架构

| Option | Description | Selected |
|--------|-------------|----------|
| A: 完全独立实现 | 简化 clickContext + 内联简化版模块，仅复用纯判定函数 | ✓ |
| B: 薄封装层 | 构建完整 clickContext，调用现有模块但跳过不相关模块 | |
| C: 混合方案 | 复用判定函数，执行逻辑内联实现 | |

**User's choice:** A — 完全独立实现
**Notes:** 仅复用 shouldUseShred/shouldCastRip/shouldUseBite/isKillShotOrLastChance/isTrivialBattleOrPvp 等纯判定函数；延续 leveling.lua 已有独立骨架架构。

---

## 中间循环优先级

| Option | Description | Selected |
|--------|-------------|----------|
| A: 对齐 catAtk | TF → Rip → Rake → FF → Shred/Claw | ✓ |
| B: 攒星优先 | TF → Shred/Claw → Rip → Rake | |
| C: Rake 提前 | TF → Rake → Shred/Claw → Rip | |

**User's choice:** A — 对齐 catAtk 优先级
**Notes:** 保留 reshift 模块（低等级自动 no-op）；ooc 不需要独立模块（内联到 regularAttack）。

---

## 终结技策略

| Option | Description | Selected |
|--------|-------------|----------|
| A: 复用 + CP 上限检测 | shouldUseBite + isKillShotOrLastChance | ✓ (简化版) |
| B: 等级段 CP 阈值 | 4 个等级段分支 | |
| C: 统一 CP>=2 | 单一低阈值 | |
| D: 仅依赖斩杀 | 非斩杀不打 Bite | |

**User's choice:** A — 复用 catAtk 现有 Bite 逻辑（斩杀优先 → shouldUseBite）
**Notes:** 用户澄清两项关键认知：(1) CP 上限始终为 5，不随等级变化；(2) 斩杀是最终目的，高于 Rip 激活等一切优化 — 能斩杀时直接斩杀，不等 Rip。

---

## 神像舞取舍

| Option | Description | Selected |
|--------|-------------|----------|
| A: 完全移除 | 不调用任何 idol 相关函数 | ✓ |
| B: 保留常驻神像 | recoverNormalRelic 但不切 Savagery | |
| C: 完整保留 | 复制 catAtk 全部神像逻辑 | |

**User's choice:** A — 完全移除神像逻辑
**Notes:** 用户指出"练级都是快速战斗"说法不准确（练级中也有精英怪/副本 boss），但同意神像舞在练级中不需要。WoW Classic 猫德神像均为 55-60 级 endgame 掉落。druidAtk 已有 level >= 60 → catAtk 路由保留满级神像舞。

---

## Claude's Discretion

- 简化 clickContext 的具体字段列表
- 各模块内联实现的具体代码
- keepFF "等待窗口"是否保留
- Selftest 用例数量和覆盖范围
- leveling.lua 现有 `<24` 分支重构方式
- catLeveling 是否接受 rough 参数

## Deferred Ideas

- healthManaSaver 练级版 — 后续 Phase
- rushMod/burstMod 练级版 — 满级已有 catAtk
- 其他职业练级版 — 各自未来 Phase
- catLeveling rough 模式 — 未来如需支持可加参数