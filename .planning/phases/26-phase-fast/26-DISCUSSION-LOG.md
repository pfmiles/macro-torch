# Phase 26: 新增phase以支持猫德的fast战斗逻辑 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-21
**Phase:** 26-phase-fast
**Areas discussed:** catLeveling 覆盖范围, 防抖/迟滞机制, SelfTest 测试覆盖, Bite 泄能行为, burst/增益模块策略, SelfTest 用例设计

---

## catLeveling 覆盖范围

| Option | Description | Selected |
|--------|-------------|----------|
| 纳入本 phase | 一次性覆盖 catAtk + catLeveling，统一 fast 战斗策略 | |
| 只做 catAtk | catLeveling 留给后续 phase | ✓ |

**User's choice:** 只关心 catAtk 逻辑，catLeveling 不重要，那只是练级工具，核心目标是尽可能提升 catAtk 的 dps

---

## 防抖/迟滞机制

| Option | Description | Selected |
|--------|-------------|----------|
| 不加防抖 | HRPS 线性回归 + GCD 天然阻尼，8.5s 阈值本身低于 Rake(9s) | ✓ |
| 加简单防抖 | 连续 N 帧一致后才切换状态 | |

**User's choice:** 不加防抖

---

## SelfTest 测试覆盖

| Option | Description | Selected |
|--------|-------------|----------|
| 完整覆盖 | 3-5 个测试注册，参考 isTrivialBattle 已有模式 | ✓ |
| 最小覆盖 | 仅 1-2 个核心测试 | |
| 不加测试 | 留给后续质量保障 phase | |

**User's choice:** 完整覆盖

---

## Bite 泄能行为

| Option | Description | Selected |
|--------|-------------|----------|
| Shred/Claw 泄能保留 | 有能量安全阀，直伤比能量溢出转化更好 | ✓ |
| 跳过所有泄能 | 直接咬，节省 GCD | |

**User's choice:** 保留 Shred/Claw 泄能，仅禁止 Rake 泄能（已在改动 ④ 中覆盖）

---

## burst/增益模块策略

| Option | Description | Selected |
|--------|-------------|----------|
| 不改 | burstMod 是 Shift 手动触发不应覆盖；keepTigerFury 直伤加成有益 | ✓ |
| 跳过部分爆发 | 浪费饰品在 10s mob 上不划算 | |

**User's choice:** 不改

---

## SelfTest 用例设计

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A：6 个测试 | 函数存在性、PvP 排除、HRPS 路径、血量估算路径、优先级关系、cp5Bite 回归 | ✓ |
| 方案 B：4 个精简测试 | 函数存在 + PvP + HRPS/血量合并 + cp5Bite 回归 | |

**User's choice:** 方案 A — 6 个测试，全部 isOptional=true

---

## Deferred Ideas

- catLeveling fast 战斗策略 — 留给后续 phase
- 防抖/迟滞机制 — 如实际使用中发现 HRPS 抖动问题，可后续追加