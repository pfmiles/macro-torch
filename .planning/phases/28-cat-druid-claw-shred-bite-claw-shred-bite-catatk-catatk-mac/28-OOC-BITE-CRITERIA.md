# OOC(清晰预兆)咬决策基准

> Phase 28 UAT 衍生结论文档（2026-09-13）。用途：装备/关键 buff 换档后，用新 cpDamage 采样按本文推算方式重算"是否该 CC 咬"，作为宏决策的校准依据。**本文不含实现代码——常数不入宏，若将来加分支，以运行时参数表方式接入。**

## 决策问题与方案定义

前提：5cp 满、ClearCasting(CC，宏内 isOoc)在手，池位 P。下一个施法必定消耗 CC。killShot（`isKillShotOrLastChance`）优先级**恒定高于**本决策，无需改动。

| 方案 | 序列 | 即得伤害（P 满池口径）|
|------|------|---------------------|
| A | CC 直接咬 | base + β·P（全池转化）|
| B | CC→免费 shred → 付费咬 | S + base + β·(P−35) |
| D | CC→免费 shred → 付费 claw 泄一刀 → 付费咬 | S + C + base + β·(P−72) |

其中 base = bite 回归截距、β = 转化斜率、S = shred 单次均值、C = claw 目标流血层单次均值。

**伤害差与池位无关**（P 与 base 全部抵消）：

- B − A = S − 35β
- D − B = C − 37β

## 时间修正与翻转判据

时间价值上限 = ERPS × E × GCD差（E = builder 效率 ≈ 最优 claw 档的 dmg/能耗；回能 10/s 起，`computeErps` 动态值含 Tiger/Rake/Rip/Pounce/狂暴/Essence+50/s）。

```
净差(A vs B) = (S − 35β) − ERPS·E·1
净差(D vs B) = (C − 37β) − ERPS·E·1
```

翻盘阈值：**R*(A/B) = (S−35β)/E，R*(D/B) = (C−37β)/E**。

- ERPS ≥ R*(A/B) → A（CC 直接咬）
- R*(D/B) ≤ ERPS < R*(A/B) → B（免费 builder 后立即咬，跳过泄能）
- ERPS < R*(D/B) → D（现状：泄能再咬）

**阈值是实时 ERPS 的分段判据**，ERPS 由 `computeErps(clickContext)` 现算，无需存储。

## 两侧对装备的尺度行为

- crit 提升：S、C、β、E 同乘 (1+crit)，阈值内分子分母抵消 → **不改变阈值**；
- 均匀增伤/AP 光环 buff：近似等比，阈值几乎不动，**不必重校**；
- AP 线性提升：`(S−35β) = (s₀−35β₀) + (cs−35·cβ)·AP`，阈值漂移方向由 shred 与 bite 转化的 AP 系数差决定，**必须用新采样重算**；
- 非均匀技能型 buff（只加 shred/只加 builder 等）：必须重算。

## 本批基准值（2026-09-12 木桩，941 条）

| 参数 | 值 | 读取位置（cpDmgOut.txt）|
|------|-----|----------------------|
| S（shred 单次）| 684.95 | aggregate tier 表 shred 行均值（bleed2 主口径）|
| C（claw 3流 / 2流）| 647.11 / 563.86 | aggregate tier 表 claw 对应行 |
| β（bite 转化斜率）| 6.8545 | bite regression 行斜率 `b` |
| base（截距校验值）| 1039.16 | bite regression 行 `a` |
| E（claw3 / claw2 口径）| 17.49 / 15.24 | claw 行 avg dmg/e |

派生断点（本档）：

| 对比 | 差值 | 阈值 R* |
|------|------|---------|
| A/B（背位 free shred）| 445 | **25.4/秒** |
| A/B（非背位 free claw·3流 / 2流）| 407 / 324 | 23.3 / 21.3 |
| D/B（3流 / 2流）| 394 / 310 | 22.5 / 20.4 |

实战速记（本档）：kill 窗口优先；否则 ERPS ≥ ~25 → CC 咬；其余维持 CC→shred + 泄能现状。B 与 D 差异较小（差一刀泄能），核心争议只在"该不该用 A"。

## 校准流程（换档后重推）

1. 新装备/关键 buff 下按 Phase 28 §4 协议采一组木桩（目标：bite ≥30、claw 各流血层 ≥20，记录背位占比）；
2. `lua tools/cpdamage.lua <导出文件>` 生成报告；
3. 从 aggregate 层读 S、C（按目标流血层）、β、base、E 五数；
4. 代入阈值公式，更新本文档参数区并注明日期与档位；
5. 每档重测三数即够（S、C、β；E=claw 行自带）。

## 未决事项与注意事项

- **CC 咬引擎行为零实测**：全池转化（x=pool−0）与"池是否清空"均为模型假设，唯一可靠来源是日志里一条真实 CC 咬样本（5cp 等 CC→直接咬→读 pool/dmg）。已有此类样本后，本文 A 方案公式反查修正。
- shred 样本几乎全 CC/全场背位：分组缺失时 S 沿用 bleed2 外推，注意 CC 不影响伤害即无偏。
- bite 转化斜率批次间噪声大（小批次可现负斜率），以 aggregate 层为准。

## 变更纪律

- killShot 分支不动；本决策只作为未来可选分支的输入依据；
- 常数不进一键宏；接入时用运行时参数表，由本文档校准后更新。