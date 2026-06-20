# Phase 14: isTrivialBattle / isKillShotOrLastChance 等级自适应 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-20
**Phase:** 14-istrivialbattle-iskillshotorlastchance-60-dps-b
**Areas discussed:** DPS 估算方案, 斩杀阈值方案, 集成与回退策略

---

## DPS 估算方案

`isTrivialBattle` 条件B 中 `500` DPS/人的替代方案。

| Option | Description | Selected |
|--------|-------------|----------|
| 等级-AP 公式估算 | `DPS = f(level, AP)` 纯公式，对装备敏感 | |
| 技能伤害反推 | 基于 Claw/Shred 实际伤害+能量周期计算理论 DPS | |
| 等级-DPS 查表 | 预设等级→DPS对照表，简单直接 | ✓ |
| 混合方案 | 等级段 baseline + AP 贡献项 | |
| 纯AP比例 | `500 × AP/AP_at_60` | |

**User's choice:** 等级-DPS 查表
**Notes:** 用户指出猫形态 DPS 的真正瓶颈是能量系统而非 AP，因此纯 AP 公式无法准确建模。等级决定了能量恢复速率（天赋 rank）、可用技能 rank 和基础属性范围，是猫德练级 DPS 的第一决定因素。查表方案简单、零计算开销、不会引入伪精确问题。

---

## 斩杀阈值方案

`isKillShotOrLastChance` 中 15 个 `KS_CP*_Health` 静态常量的动态化。

| Option | Description | Selected |
|--------|-------------|----------|
| AP 伤害反推 | `computeBiteDamage(cp)` — 基于 AP + FB rank 计算期望伤害 | |
| 等级缩放因子 | `KS_CP5_Health × f(level)` — 保留原有多级CP结构 | |
| AP + 等级下限 | AP 公式 + 按等级的最低/最高限制 | |
| 精简为1个动态值 | 只保留 CP5 动态阈值 | |

**User's choice:** 单阈值 × 等级查表（推荐方案的变体）
**Notes:** 用户洞察：斩杀判断发生在战斗尾声，此时 HRPS 追踪（`willDieInSeconds(2)`）已有充足数据，条件A 已经准确。条件B 本质上是 fallback。因此不需要保留 15 个常量的 CP 粒度——简化为单一 `KS_HEALTH_THRESHOLD` 按等级缩放即可。删除全部 `KS_CP*_Health*` 常量。

---

## 集成与回退策略

### 代码组织

| Option | Description | Selected |
|--------|-------------|----------|
| 独立函数 + 60级硬guard | 提取 `estimatePlayerDPS`/`getKSThreshold`，60级直接返回旧值 | ✓ |
| 独立函数 + 自然推导 | 查表中60级值=旧值，无需特殊分支 | |
| 内联修改 | 不提取函数 | |

### 低等级 fallback

| Option | Description | Selected |
|--------|-------------|----------|
| 保守估计 | 数据不足时返回 false（不触发快速战斗/斩杀） | ✓ |
| 等级缩放旧常量 | `500 × level/60` 作为最后兜底 | |
| 仅依赖 HRPS | 完全依赖 willDieInSeconds | |

**User's choice:** 独立函数 + 60级硬guard + 保守fallback
**Notes:** 60 级硬 guard 确保满级行为零风险；保守 fallback 遵循"宁可不作为也不要误判"原则。遵循 Phase 13 `computeReshiftEnergy` 的先例模式。

---

## Claude's Discretion

- 等级段的具体划分粒度
- 各等级段 DPS 和 KS 阈值的具体数值
- 查表的具体实现方式（if-elseif 链 vs table lookup）
- Selftest 的具体用例数量和边界覆盖范围

## Deferred Ideas

- 其他职业的 DPS 估算（各自的未来 Phase）
- AP 感知升级（如装备差异导致显著偏差时可升级为混合方案）
- isKillShotOrLastChance 的 group/raid 倍率（如需区分可在 `getKSThreshold` 中加简单系数）