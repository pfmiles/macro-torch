# Seed: catAtk 双保（bite 节奏守护）

> **触发条件：** 有效暴击 c_eff = c·(1−miss) 越过 c\*(k) 判据（`notes/cat-double-keep-threshold.md`；按当前 k≈1.8~2.5s，β=70% 口径阈值 ≈ 26~29%），或处于爆发态/伪无限能量态（k ≤ 1.6s，恒成立区间）。天赋需 2/2 原始狂怒。
>
> 种植日期：2026-08-31 | 上下文：`/gsd-explore` 探索会话

---

## 目标

判据满足时，catAtk 以"bite 节奏守护"替代 keepRake 的常规补挂：rake 与 rip 都交由 bite 顺带刷新，主动 cast 退化为兜底，释放出的能量与 GCD 投入更多 Claw / Shred / Bite，并改善 Ancient Brutality 的流血覆盖回能。

## 设计要点

1. **守护判定（每次点击）：** 输入 rakeLeft、当前星数、实测 k；剩星 n 时槽数 s = ⌊(rakeLeft−1)/k⌋，按 N 分布算 P(n 星在 s 击内攒满)，≥ β 则抑制补 rake（赌下一发 bite），< β 走现行补挂。
2. **rip 兜底：** 仅当 bite 断流超过 rip 窗口时才 cast rip；现行 shouldCastRip 保留为兜底路径。
3. **节奏估计：** 滚动窗口内攻击间隔（cast 历史/land 事件），输出实测 k 供判定与日志。
4. **状态门：** 双保仅作用于战斗主循环；快战 / PvP / 流血免疫场景维持现行策略。
5. **攒星技能倾向：** 双保窗口内优先 Claw（37e）而非 Shred（48e），或按实测技能混合 k 重新评估阈值。
6. **校准先行：** 先做 selftest 级 Monte-Carlo（离散能量 tick + miss + 节奏波动）验证 c\*/β 表与期望覆盖率，再合入主循环——本 Seed 的判据表尚未校准，不得直接上线。

## 关联

- `.planning/notes/cat-double-keep-threshold.md` — 判据模型与 c\* 表
- `.planning/notes/ferocity-talent-analysis.md` — 能量模型（erps / k=1.83s 出处）
- 代码锚点：`combo.lua:catAtk(49)`、`cat.lua:keepRake(356)/safeBite(436)`、`Druid.lua:computeErps(887)`、`cat.lua:shouldDoReshift(236)`