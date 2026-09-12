---
created: 2026-09-12
status: pending
trigger: "实机木桩簇（用户 2026-09-12 报告并随后纠偏前提）：Bite 白字→绿 bite landing→仅一行 Renewing rip→咖啡 Reshift(nextMove: Rake)→两行白 Rake!!!（补耙 A）→蓝 Rake (Inferred)→又一行白 Rake!!!（补耙 B）→绿 Rake landing→恢复正常"
---

# 木桩簇判别：补耙 A 蓝字与补耙 B 的成因

## 前提纠偏（用户 2026-09-12 澄清，游戏机制）

咬只能**刷新目标身上已存在的** rake/rip debuff，不能凭空新增。因此"咬后只续 rip"= 当时 rake 已经自然到期（9s 上限），是**正常机制**，不是客户端数据滞后；咬后计划补耙也是**正常决策**。此前"咬后续期 rake 缺失=客户端滞后"的解释作废。

## 修正后的链条（正常部分）

1. rake 到期 → 目标只剩 rip；
2. 咬落地 → 只产生 Renewing rip（正是"只续现存"的应然输出）；
3. Reshift nextMove: Rake → 补耙 A（正常）。

## 剩余两个待答题（簇的真正异常部分）

### 问题一：补耙 A 为何蓝字 (Inferred)？

新耙落地有双证据通道（直伤自伤行 + 新挂流血必发的 apply 行），双双在 0.9s 窗内静默才触发兜底。候选=咬/换形/续期事件洪流的通道迟滞（与 M2 状态条冻结同族的环境延迟）。兜底照设计救了账（蓝色即"反推落地"），代价仅 rakeLeft 时钟锚定在施放时刻（误差 <1s，无害）。

### 问题二：A 之后为何又打补耙 B？（关键判别钥匙已内置于打印）

Rake 判定门是双钥匙：客户端图标（`hasBuff('Ability_Druid_Disembowel')`）+ 自维护时钟（`rakeLeft`，读 landTable 顶）。A 的蓝字兜底已把 landTable 顶刷新，`rakeLeft` 应为正值——故 B 成立多半因客户端图标数据滞后。**无需猜：每行白 Rake!!! 自带 `Rake present: true/false` 字段，即判定时刻双钥匙的求值结果。**

| B 行 `Rake present:` | 含义 | 下一步 |
|----------------------|------|--------|
| `false` | 判定时刻宏确实认为 rake 不在（结合 rakeLeft 已被兜底刷新 → 客户端 UnitDebuff 数据滞后坐实） | 环境链归档，评估是否做"蓝字兜底后宽限"优化（另立项） |
| `true` | 宏明知道 rake 在仍补打 → 判定树其它分支（keepRake 组合门）问题 | 回查 keepRake/cat.lua 判定树，立案侦查 |

## 取证要抄的最小集（仅当簇再现）

1. 蓝行全行（含 landed 时间戳数字）；
2. 绿行全行（含 landed 时间戳数字）——两行时间戳差 ≈3~4s 证明两发真耙；
3. 两处白 Rake!!! 全行（含 `Rake present:` 值——判别钥匙）；
4. 咬后的 Renewing 行（确认只有 Rip）。

## 连带影响

上次 12 分钟簇的"只续 rip"现在有更朴素解释（rake 9s 自然到期 + 咬只续现存），"客户端图标滞后"在两次观察里均失据，应降级为次要候选。