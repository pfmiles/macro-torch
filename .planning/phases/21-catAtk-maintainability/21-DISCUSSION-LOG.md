# Phase 21: catAtk-maintainability - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-29
**Phase:** 21-catAtk-maintainability
**Areas discussed:** keepRake ATK 爆发分离方案, isInfiniteEnergy 替换范围, Commit 粒度与执行顺序

---

## keepRake ATK 爆发分离方案

| Option | Description | Selected |
|--------|-------------|----------|
| 方案 A：注释标注 | 在 keepRake 中 ATK 爆发处添加详细注释块，说明为什么在这里触发（AP snapshot 最大化流血伤害）、为什么放在 keepRake 而非 burstMod。改动 ~5 行注释，不改变任何执行逻辑或模块顺序。 | ✓ |
| 方案 B：独立模块 | 将 ATK 爆发提取为独立 autoBurstMod 模块，在 catAtk 中 keepRake 之前调用。改变了模块拆分结构和 catAtk 内部调用顺序。 | |

**User's choice:** 方案 A：注释标注（来源文档推荐）
**Notes:** 来源文档已提供完整的注释块模板（英文），说明 AP snapshot 机制、why keepRake not burstMod（burstMod 处理手动 Shift 键协调，这里是高价值目标自动优化）。

---

## isInfiniteEnergy 替换范围

| Option | Description | Selected |
|--------|-------------|----------|
| 按来源文档边界 | 严格按来源文档：替换 5 处显式比较，保留 3 处隐式比较（表达不同语义）。命名为 `isPseudoInfiniteEnergy`。 | ✓ |
| 扩大范围：包含隐式比较 | 将 shouldDoReshift 和 shouldCastFFDuringWaitWindow 中的隐式比较也改为读 isPseudoInfiniteEnergy。 | |
| 缩小范围：仅 cat.lua 内 | 只替换 cat.lua 内 4 处比较，Druid.lua 的 shouldUseShred 不改。 | |

**User's choice:** 按来源文档边界，但字段名改为 `isPseudoInfiniteEnergy`（不是 `isInfiniteEnergy`）
**Notes:** 用户强调命名应体现"近似无穷能量"的语义（erps >= SHRED_E 判断的是"能量在可预见 GCD 内不会耗尽"，而非字面的 infinite）。计算位置确认为 catAtk 入口处一次计算（非 lazy field）。

---

## Commit 粒度与执行顺序

| Option | Description | Selected |
|--------|-------------|----------|
| 文档建议：3 commits | Items 1+2 合并（纯注释），Item 3 单独（isPseudoInfiniteEnergy 集中化），Item 4 单独（keepRake 注释标注）。 | ✓ |
| 全部合并：1 commit | 4 个条目全部 squash，改动量小（~40 行），同属 maintainability 主题。 | |
| 完全拆分：4 commits | 每个条目独立 commit，最细粒度。 | |

**User's choice:** 文档建议：3 commits
**Notes:** 执行顺序 1→2→3→4（来源文档建议），每个条目执行后独立验证。

---

## Claude's Discretion

- isPseudoInfiniteEnergy 在 combo.lua 中的具体计算行位置（clickContext 初始化之后、模块调用之前）
- 注释的具体措辞（遵循来源文档提供的模板，可微调）
- cp5Bite 和 energyDischargeBeforeBite 中替换的具体代码（统一改为读 clickContext.isPseudoInfiniteEnergy）
- 是否需要同步更新 catAtk-core-principles.md（反映 isPseudoInfiniteEnergy 命名决策）

## Deferred Ideas

- burstMod 改造 — 来源文档已确认不改（故意设计）
- 主动 FF 维护 — 暂缓
- recoverNormalRelic 无限能量永不触发 — 已知限制
- catAtk-phaseB-quality.md — 后续独立阶段