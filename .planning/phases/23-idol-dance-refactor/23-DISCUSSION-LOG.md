# Phase 23: Idol Dance Refactor - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-02
**Phase:** 23-idol-dance-refactor
**Areas discussed:** 验证策略, computeNormalRelic 简化边界, ripAppliedTargets 标记时机, 与现有神像切换链的集成验证, 距离因素

---

## 验证策略

| Option | Description | Selected |
|--------|-------------|----------|
| 加 SelfTest（推荐） | 在 selftest.lua 追加 Category O，利用 clickContext 预设值测试决策逻辑。不能测实际装备效果 | ✓ |
| 纯手动验证 | 游戏内 10 个场景手动测试，无回归保护 | |
| SelfTest + 手动 | SelfTest 覆盖纯逻辑 + 手动验证 3-4 关键场景 | |

**User's choice:** 加 SelfTest（推荐）
**Notes:** Phase 22 已建立成熟的 Category 测试模式，延续该模式

---

## 验证策略 — 测试范围

| Option | Description | Selected |
|--------|-------------|----------|
| 核心路径 ~6 个 | 覆盖 3 个 Gap + 核心场景 | ✓ |
| 全组合 ~12 个 | 核心 + 边界（guid nil, context nil, 双神像缺失等） | |
| 10 点全覆盖 | 对应 DESIGN.md 所有验证要点 | |

**User's choice:** 核心路径 ~6 个（推荐）
**Notes:** 简洁、易维护，部分边界无法用 SelfTest 表达

---

## 验证策略 — 命名与放置

| Option | Description | Selected |
|--------|-------------|----------|
| Category O | "Cat O-NN: description"，放在 selftest.lua 末尾 | ✓ |
| 不分组 | 直接描述性命名 | |
| 单独文件 | 新建 idol_selftest.lua | |

**User's choice:** Category O（推荐）
**Notes:** 延续 Phase 22 Batch 1+2 的命名传统

---

## computeNormalRelic 简化边界 — 核心逻辑

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A：实时状态 | 只修 Gap 1+2，不修 Gap 3。用 isRipPresent 而非 ripAppliedTargets | ✓ |
| 方案 B：永久记忆 | DESIGN.md 原方案，一次 Rip 后永久锁定 Fero/Rot | |
| 方案 C：lastRipAtCp | 利用已有 lastRipAtCp 做精细判断 | |

**User's choice:** 方案 A：实时状态
**Notes:** 用户明确：之前设计时已决策过，战斗中 Rip 没了就该切 Savagery，不再关注是否曾对 target Rip 过

---

## computeNormalRelic 简化边界 — isInCombat 守卫

| Option | Description | Selected |
|--------|-------------|----------|
| 保留 isInCombat | 非战斗预切 Savagery（消除场景 3 差异） | ✓ |
| 去掉 isInCombat | 接受场景 3 差异（非战斗+仍有 Rip → Fero/Rot） | |

**User's choice:** 保留 isInCombat（推荐）
**Notes:** 非战斗预切 Savagery 确保进战后第一个 Rip 有快照。场景比对表已验证等价性

---

## computeNormalRelic 简化边界 — 非战斗 isImmuneRip

| Option | Description | Selected |
|--------|-------------|----------|
| 保留 isImmuneRip | 非战斗+免疫→Fero/Rot，Savagery 永远无用 | ✓ |
| 非战斗一律 Savagery | 进战后由 isImmuneRip 分支纠正 | |
| 非战斗也走 3 条件 | 统一逻辑，但引入场景 3 差异 | |

**User's choice:** 保留 isImmuneRip 检查（推荐）
**Notes:** 免疫目标 Savagery 完全无意义

---

## 集成验证

**User's choice:** 没问题，下一个
**Notes:** 新 computeNormalRelic → recoverNormalRelic → dischargeEnergyChangeRelicAndRip 链无冲突。用户纠正了关于 recoverNormalRelic `isFightStarted` guard 的误读——`not isFightStarted` 时直接切入，这正是"利用非战时间预切"的设计意图

---

## 距离因素

| Option | Description | Selected |
|--------|-------------|----------|
| 纳入本 Phase | 修改 recoverNormalRelic 能量检查：距离 ≥ 19yd 旁路 | ✓ |
| Defer | 留给后续 phase | |
| 只改 computeNormalRelic | 在 computeNormalRelic 中考虑距离影响 WHAT | |

**User's choice:** 纳入本 Phase（推荐）
**Notes:** 距离与神像舞高度相关。跑路时间 ≥ 1.5s GCD 时切换等价于免费

---

## 距离因素 — 作用点

| Option | Description | Selected |
|--------|-------------|----------|
| recoverNormalRelic + 固定阈值 | distance ≥ 20yd 旁路能量检查 | ✓ |
| computeNormalRelic | 影响 WHAT 决策 | |
| 两处都加 | WHAT + WHEN | |

**User's choice:** recoverNormalRelic + 固定阈值（推荐）
**Notes:** 距离影响的是 WHEN（时机）而非 WHAT（选择）

---

## 距离因素 — 实现细节

| Option | Description | Selected |
|--------|-------------|----------|
| distance ≥ 20yd 旁路 | 简单直接，保守估算 (20-5)/7≈2.1s ≥ 1.5s GCD | ✓ |
| 距离 + GCD 状态 | 额外检查非 GCD 状态避免与 FF 冲突 | |
| 可配常量 | macroTorch.IDOL_SWITCH_DISTANCE = 20 | |

**User's choice:** 距离 ≥ 20yd 就旁路（推荐）
**Notes:** 不判断是否在移动——站远处说明不在做近战动作

---

## Claude's Discretion

- 距离阈值比较符号（`>=` vs `>`）
- SelfTest assert 条件的具体措辞
- recoverNormalRelic 距离旁路的 return 策略
- 注释风格和措辞（英文）

## Deferred Ideas

- **Gap 3 永久记忆方案**: `ripAppliedTargets` 被否决——若 Rip 意外到期需重打，Savagery 快照价值 > 1.5s GCD 成本
- **动态猫德跑速计算**: 考虑 Feline Swiftness 天赋、Dash buff 的实时跑速，当前使用固定 20yd 保守阈值
- **"站桩放 FF" vs "跑向目标" 区分**: 当前不区分两种远距离状态，FF 延迟 1 GCD 影响可忽略