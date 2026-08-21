# Phase 26: 新增phase以支持猫德的fast战斗逻辑 - Context

**Gathered:** 2026-08-21
**Status:** Ready for planning

<domain>
## Phase Boundary

为猫德 `catAtk`（60 级 DPS 一键宏）新增"快速战斗"判断机制 `isFastBattleNotPvp`：当目标预计在 **8.5 秒** 内死亡且非 PvP 时，触发**纯直伤策略**——跳过所有流血效果（Pounce/Rake/Rip），仅用 Shred（背后）/Claw（正面）攒连击点至 5 星，然后 Bite 或 KillShot 斩杀。

**经济学原理：** 8.5s 阈值低于最短流血技能 Rake(9s) 的持续时间，确保流血在目标死亡前无法回本。能量用于直伤的边际收益更高。

**范围限定：** 仅修改 `catAtk` 路径（`classes/druid/combo.lua` + `classes/druid/cat.lua` + `classes/druid/Druid.lua`）。`catLeveling`（练级版）不纳入本 phase。

**阈值阶梯：**

| 函数 | 阈值 | 策略 |
|------|------|------|
| `isKillShotOrLastChance` | 2s | 任意 CP 直接斩杀 |
| **`isFastBattleNotPvp`** | **8.5s** | 纯直伤，不挂流血 |
| `isTrivialBattle` | 25s | 低星 Rip（quickKeepRip） |
| 默认 | > 25s | 5 星 Rip 完整循环 |

</domain>

<decisions>
## Implementation Decisions

### 核心判断函数

- **D-01: isFastBattleNotPvp 函数** — 新增于 `classes/druid/Druid.lua`，紧邻 `isTrivialBattle`（约 805 行后）。双条件判断：A. HRPS 动态预测 (`willDieInSeconds(8.5)`)；B. 血量估算 (`healthMax ≤ 人数 × DPS × 8.5`)。排除 PvP (`not target.isPlayerControlled`)。惰性缓存于 `clickContext`，每帧自动重算。— **Reversibility:** reversible

- **D-02: 阈值 8.5s** — 低于 Rake(9s) 和 Rip(12s) 持续时间，确保流血无足够 tick 回本。与 25s（isTrivialBattle）有 16.5s 间隔，足够区分 fast 和 quick。— **Reversibility:** reversible

### catAtk 修改点（7 处，3 文件）

- **D-03: Opener — 跳过 Pounce** — `classes/druid/combo.lua:137`，在 Pounce 释放条件追加 `and not isFastBattleNotPvp`。快速战斗时落到 `elseif hasRavage` 用 Ravage 直伤起手。

- **D-04: Rip 分支 — 完全跳过** — `classes/druid/combo.lua:160-167`，用 `if not isFastBattleNotPvp` 包裹原有 Rip 策略选择。快速战斗时 Rip 模块完全不执行。

- **D-05: keepRake — 守卫追加** — `classes/druid/cat.lua:332`，在已有守卫 `or` 链末尾追加 `or isFastBattleNotPvp`。快速战斗禁止挂 Rake。

- **D-06: energyDischargeBeforeBite — 不用 Rake 泄能** — `classes/druid/cat.lua:159`，在 Rake 泄能回退分支追加 `and not isFastBattleNotPvp`。Shred/Claw 泄能路径保留（有能量安全阀），仅禁止 Rake 泄能。

- **D-07: regularAttack 前置条件 — 脱离 Rake 依赖** — `classes/druid/combo.lua:173`，在守卫中追加 `isFastBattleNotPvp` 作为替代条件。快速战斗时即使无 Rake 也能攒星。

- **D-08: cp5Bite — 快速战斗也触发** — `classes/druid/cat.lua:115`，在 `comboPoints == 5` 的条件中追加 `isFastBattleNotPvp`。快速战斗时 5 星无条件触发 Bite（原逻辑要求 `isImmuneRip or isRipPresent`，快速战斗两者都不满足会导致 5 星永远不咬）。— **Reversibility:** reversible

- **D-09: 共享函数不变** — `shouldUseShred`（bleedCount=0 时 isTrivialBattleOrPvp 为 true，直接返回 isBehind，天然符合 fast 战斗）、`shouldUseBite`、`shouldCastRip` 等共享函数不做修改。catLeveling 路径不受影响。— **Reversibility:** reversible

### 不需要改动的模块

- **burstMod / keepTigerFury / keepFF / oocMod / termMod / otMod / reshiftMod** — 保持现有行为。burstMod 为 Shift 手动触发不应覆盖；keepTigerFury 直伤加成仍有益；keepFF 免费 GCD 可触发 OoC。

### 防抖

- **D-10: 不加防抖/迟滞** — `currentHRPS()` 的线性回归（100 点滑动窗口）已提供自然平滑；1.5s GCD 天然钝化高频切换；8.5s 阈值与 Rake(9s) 的 0.5s 间隔提供额外缓冲。

### 动态兼容性

- **D-11: 每帧独立判断** — `clickContext` 每帧新建，`isFastBattleNotPvp` 的缓存仅存活一帧。`willDieInSeconds` 基于 `maintainTHV()` 持续采集的 HRPS 数据（最小二乘回归），冷启动期间（< 2 样本）HRPS=0 → 返回 false → 保守行为。状态变化（fast ⇄ quick）在下一帧自动生效，无死锁风险。

### SelfTest 覆盖

- **D-12: 6 个 SelfTest 注册** — 全部 `isOptional=true`，新增于 `core/selftest.lua`：
  1. 函数存在性 — `isFastBattleNotPvp` 是 function
  2. PvP 排除 — `target.isPlayerControlled=true` → false
  3. HRPS 路径 — `willDieInSeconds(8.5)=true` → true
  4. 血量估算路径 — `healthMax ≤ 人数 × DPS × 8.5` → true
  5. 优先级关系 — fast=true ⇒ trivial=true（验证嵌套正确）
  6. cp5Bite 行为回归 — fast 战斗 + 5CP + 无 Rip 无免疫 → 触发 Bite

### 范围限定

- **D-13: catLeveling 不纳入** — 练级版一键宏保持现有行为不变，仅修改 catAtk（60 级 DPS）路径。catLeveling 的快速战斗策略留给后续 phase。

### Claude's Discretion

- SelfTest 具体实现细节（测试数据构造、桩函数设计）由 planner/executor 决定
- 代码注释风格和 commit message 格式遵循项目惯例

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 核心代码文件
- `classes/druid/Druid.lua:788-805` — `isTrivialBattleOrPvp` / `isTrivialBattle`（参考实现模式）
- `classes/druid/Druid.lua:837-851` — `isKillShotOrLastChance`（参考实现模式）
- `classes/druid/Druid.lua:736-785` — `shouldUseShred`（bleedCount 决策树，理解 fast 战斗为何不需修改）
- `classes/druid/combo.lua:49-181` — `catAtk` 完整流程（所有修改的锚点）
- `classes/druid/cat.lua:45-61` — `regularAttack`
- `classes/druid/cat.lua:104-112` — `termMod` / `cp5Bite`（113-143 行）
- `classes/druid/cat.lua:144-162` — `energyDischargeBeforeBite`
- `classes/druid/cat.lua:307-325` — `quickKeepRip`
- `classes/druid/cat.lua:326-345` — `keepRake`
- `entity/Target.lua:86-98` — `willDieInSeconds`（HRPS 预测机制）
- `entity/Target.lua:114-158` — `maintainTHV` / `currentHRPS`（数据采集和线性回归）

### 现有测试
- `core/selftest.lua` — SelfTest 注册机制，参考现有 `isTrivialBattle` 测试的注册模式
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`isTrivialBattle` 模式** — 完全复用其双条件判断 + 惰性缓存 + 每帧重算的架构。`isFastBattleNotPvp` 仅改阈值（25→8.5）和增加 PvP 排除。
- **`clickContext` 缓存机制** — 所有判断函数共用，无需新建数据结构。
- **`shouldUseShred` bleedCount 决策树** — 快速战斗 bleedCount=0，现有逻辑已返回正确结果（背后 Shred/正面 Claw），零修改复用。

### Established Patterns
- **模块化守卫追加** — 所有改动都是追加守卫条件，不修改已有分支逻辑。与 Phase 14、Phase 21 的模式一致。
- **Per-frame 惰性计算** — `if clickContext.xxx == nil then compute` 模式，与 `isTrivialBattle`、`isKillShotOrLastChance` 一致。
- **SelfTest isOptional 注册** — 非核心测试不阻塞构建，与现有 Category J/K 测试一致。

### Integration Points
- **`isTrivialBattleOrPvp`** — `isFastBattleNotPvp` 是其子集（8.5s ≤ 25s，且排除 PvP）。fast=true 时 trivial 也必然 true。
- **`isKillShotOrLastChance`** — 三个阈值形成阶梯（2s → 8.5s → 25s），互不冲突。
- **`cp5Bite` 守卫** — 快速战斗中 Rip 不存在 → 原有 5CP 触发条件不满足 → 必须追加 `isFastBattleNotPvp` 守卫。
</code_context>

<specifics>
## Specific Ideas

- 用户原文："对于特别弱小的普通 mob，它会在 10s 之内被打败，这种情况其实最适合的就是直接使用 shred(如果是正面则只能 claw) 直到 5 星就 bite 或 killshot 就 bite，然后一直再 shred/claw 到 5 星就 bite；换句话说，这种情况不挂任何流血"
- 阈值最终确定 8.5s（用户要求从原始 10s 下调）
- 函数命名 `isFastBattleNotPvp` 由用户指定，强调"非 PvP 的快速战斗"
</specifics>

<deferred>
## Deferred Ideas

- **catLeveling fast 战斗策略** — 练级版一键宏同样需要纯直伤策略（受益场景更频繁），留给后续 phase
- **防抖/迟滞机制** — 如实际使用中发现 HRPS 抖动导致频繁切换，可后续追加 hysteresis

</deferred>

---

*Phase: 26-phase-fast*
*Context gathered: 2026-08-21*