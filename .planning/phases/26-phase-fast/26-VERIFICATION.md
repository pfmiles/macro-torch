---
phase: 26-phase-fast
verified: 2026-08-22T00:00:00Z
status: human_needed
score: 15/16 must-haves verified
behavior_unverified: 1
overrides_applied: 0
behavior_unverified_items:
  - truth: "fast battle: 5 combo points triggers Bite even with no Rip and no Rip immunity (D-08)"
    test: "In-game /mt self-test — P-06 cp5Bite regression; or engage a weak mob, reach 5CP with no Rake/Rip applied and no bleed immunity, confirm Bite fires"
    expected: "cp5Bite enters the 5CP branch via the added `or macroTorch.isFastBattleNotPvp(clickContext)` clause and calls safeBite (ooc=false) / readyBite (ooc=true)"
    why_human: "The guard and the full call chain are present and statically coherent, but the only test exercising this state transition is P-06, which requires the WoW client (UnitClass, PLAYER_ENTERING_WORLD); no Lua interpreter exists in this environment, so the transition cannot be executed here"
---

# Phase 26: 猫德 fast 战斗逻辑 (isFastBattleNotPvp) Verification Report

**Phase Goal:** 为猫德 catAtk 新增快速战斗判断 `isFastBattleNotPvp`（8.5s 死亡预测、非 PvP），触发纯直伤策略 — 跳过所有流血效果（Pounce/Rake/Rip），仅用 Shred（背后）/Claw（正面）攒连击点至 5 星后 Bite 或 KillShot 斩杀。
**Verified:** 2026-08-22
**Status:** human_needed — 1 项行为依赖 truth 需游戏内验证 + 1 项 SelfTest 副作用 Warning 需人工决策
**Re-verification:** No — initial verification

## Goal Achievement

核心目标**已达成**：`isFastBattleNotPvp` 判定函数落地、7 处追加式守卫全部就位、纯直伤策略逻辑完整，构建绿色。唯一未能在本环境验证的是 D-08 行为真值（5CP→Bite 的状态转移），其指定测试 P-06 存在但仅能在 WoW 客户端内执行（本环境无 Lua 解释器）。

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `macroTorch.isFastBattleNotPvp(clickContext)` 存在于 Druid.lua，位于 isTrivialBattle 之后、返回 boolean（D-01） | ✓ VERIFIED | Druid.lua:812-826；紧邻 isTrivialBattle 的 end（:805），位于 combatUrgentHPRestore（:828）之前；`or` 两个布尔比较结果 → boolean |
| 2 | PvP 排除是函数第一条语句（D-01） | ✓ VERIFIED | Druid.lua:814-816 `if macroTorch.target.isPlayerControlled then return false end` 先于惰性缓存块 |
| 3 | 阈值恰为 8.5，`localFastDieTime` 变量唯一（D-02） | ✓ VERIFIED | `grep -c "localFastDieTime = 8.5"` == 1；函数体内 8.5 字面量恰一次（注释块 807-811 提及 8.5s 属注释） |
| 4 | 判定语义：HRPS/血量估算两臂真→true；PvP 恒 false（D-01） | ✓ VERIFIED | 纯布尔组合、代码路径完整可见：`willDieInSeconds(8.5) or (healthMax <= (mate+1)*estimatePlayerDPS()*8.5)`；Lua `or` 短路语义由 P-03/P-04 分别隔臂覆盖；PvP 路径无条件早退。无状态转移/清理/排序不变量 |
| 5 | fast=true ⇒ trivial=true（优先级关系） | ✓ VERIFIED | 数学必然：willDieInSeconds 为 `health <= HRPS*s`，对 s 单调（Target.lua:86-98），8.5<25 ⇒ A 蕴含成立；B 臂线性缩放同理；PvP 仅使 fast 更窄。P-05 存在同一 stub 下等值断言 |
| 6 | 快速战斗起手永不 Pounce，潜行时落到 Ravage（D-03） | ✓ VERIFIED | combo.lua:139 Pounce 条件末位 `and not macroTorch.isFastBattleNotPvp(clickContext)`；`elseif hasRavage` 分支（:146-147）原样未动，快速战斗自然落入 |
| 7 | 快速战斗完全跳过 Rip（keepRip/quickKeepRip 均不执行）（D-04） | ✓ VERIFIED | combo.lua:164-172 整体包裹 `if not macroTorch.isFastBattleNotPvp(clickContext) then ... end`；内部 isTrivialBattleOrPvp → quickKeepRip / else keepRip 结构 git diff 证实逐字节未变（仅换缩进上下文） |
| 8 | 快速战斗绝不挂 Rake：keepRake 守卫 + energyDischarge Rake 回退双封（D-05/D-06） | ✓ VERIFIED | cat.lua:337 守卫链末尾 `or macroTorch.isFastBattleNotPvp(clickContext)`；cat.lua:163 Rake 回退插入 `and not macroTorch.isFastBattleNotPvp(clickContext)`；泄能首分支（:151-157）未动 |
| 9 | 快速战斗无 Rake 也照常攒星（regularAttack 前置条件）（D-07） | ✓ VERIFIED | combo.lua:180 括号组内追加 `or macroTorch.isFastBattleNotPvp(clickContext)` |
| 10 | 快速战斗 5CP 触发 Bite（无 Rip 且无免疫）（D-08） | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | cat.lua:117 条件含 `or macroTorch.isFastBattleNotPvp(clickContext)`；后续链（isPseudoInfiniteEnergy→skip discharge→ooc?readyBite:safeBite）静态一致。指定行为测试 P-06 存在但仅能在 WoW 客户端执行，本环境无 Lua 解释器 — 见 Human Verification #1 |
| 11 | 共享函数零改动，全部修改为追加式（D-09） | ✓ VERIFIED | git diff 审计：Druid.lua 仅 1 个 hunk（新函数纯插入 +21 行）；shouldUseShred（Druid.lua:736）、shouldCastRip（:987）、shouldUseBite（:1012）零 hunk；combo.lua/cat.lua 6 处修改均为条件追加或包裹 if，无任何既有分支条件被删除/重排 |
| 12 | 无防抖/迟滞机制（D-10） | ✓ VERIFIED | 全阶段 diff grep `C_Timer|debounce|jitter|hysteresis|throttle` 零命中；diff 形状 = 1 新函数 + 7 守卫 + 6 测试注册 |
| 13 | clickContext 惰性缓存 pattern 与 isTrivialBattle 一致，每帧重算（D-11） | ✓ VERIFIED | Druid.lua:817 `if clickContext.isFastBattleNotPvp == nil` 与 :795 isTrivialBattle 完全同构；combo.lua:55 `local clickContext = {}` 每次 catAtk 调用重建（单次点击作用域） |
| 14 | 恰 6 个 Category P 注册、全部 isOptional=true（D-12） | ✓ VERIFIED | core/selftest.lua:698-807 六处 `SelfTest:register(..., true)`；每个均以 `if UnitClass('player') ~= 'Druid' then return end` 开头；self-test 名 grep 计数 == 6。⚠️ 附带 Warning：P-02 的 isPlayerControlled stub 非精确恢复（见 Anti-Patterns） |
| 15 | catLeveling 完全未动（D-13） | ✓ VERIFIED | `git diff a1467b1..HEAD -- classes/druid/leveling.lua` 零 hunk（leveling.lua 不在 diff 文件列表中） |
| 16 | 构建成功 + SM_Extend.lua 含新符号 + 范围仅 4 文件 | ✓ VERIFIED | `./build.sh` exit 0（实测）；SM_Extend.lua 含 `function macroTorch.isFastBattleNotPvp` 恰 1 处、6 个测试名行；excludes .planning 后 diff 恰 4 个代码文件 |

**Score:** 15/16 truths verified (1 present-but-behavior-unverified)

### Decision Coverage (26-CONTEXT.md)

13/13 decisions honored — no deviation from user decisions:

| Decision | Verdict | Evidence |
|----------|---------|----------|
| D-01 | ✓ honored | Druid.lua:812-826（位置、PvP 首句、双条件、clickContext 缓存） |
| D-02 | ✓ honored | `localFastDieTime = 8.5` 恰一次 |
| D-03 | ✓ honored | combo.lua:139 Pounce 起手条件追加 `and not` |
| D-04 | ✓ honored | combo.lua:164-172 Rip 策略整体包裹 |
| D-05 | ✓ honored | cat.lua:337 keepRake 守卫链末尾追加 |
| D-06 | ✓ honored | cat.lua:163 Rake 泄能回退追加 `and not` |
| D-07 | ✓ honored | combo.lua:180 regularAttack 前置条件括号组内追加 |
| D-08 | ✓ honored | cat.lua:117 cp5Bite 5CP 触发追加 |
| D-09 | ✓ honored | 共享函数零 hunk，全部追加式 |
| D-10 | ✓ honored | diff 无任何 timer/debounce 构造 |
| D-11 | ✓ honored | nil-check 缓存 + 每帧 clickContext 重建 |
| D-12 | ✓ honored | 6 个 Category P 注册全部 isOptional=true（含 Warning，见下） |
| D-13 | ✓ honored | leveling.lua 零 hunk |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `classes/druid/Druid.lua` | isFastBattleNotPvp 函数（PvP-first + 8.5s 双条件 + 惰性缓存） | ✓ VERIFIED | :812-826，21 行纯插入 |
| `classes/druid/combo.lua` | Pounce 跳过 / Rip 包裹 / regularAttack 前置（3 处） | ✓ VERIFIED | :139 / :164-172 / :180，均按计划语义 |
| `classes/druid/cat.lua` | cp5Bite / energyDischarge / keepRake（3 处） | ✓ VERIFIED | :117 / :163 / :337 |
| `core/selftest.lua` | Category P 段落，P-01..P-06 | ✓ VERIFIED | :693-809（Warning: P-02 stub 恢复非精确） |

注：计划锚定行号（combo.lua:137/160/173、cat.lua:115/159/332）与实际（139/164/180、117/163/337）偏移 +2~+7，均为计划要求添加的 `[FAST] D-0x` 注释行所致，语义完全一致。

### Key Link Verification

| From | To | Via | Status |
|------|----|----|--------|
| combo.lua:139 opener | Druid.lua:812 isFastBattleNotPvp | `and not macroTorch.isFastBattleNotPvp(clickContext)` | ✓ WIRED |
| combo.lua:164 Rip wrapper | Druid.lua:812 | `if not macroTorch.isFastBattleNotPvp(clickContext) then` | ✓ WIRED |
| combo.lua:180 regularAttack | Druid.lua:812 | `or macroTorch.isFastBattleNotPvp(clickContext)`（括号组内） | ✓ WIRED |
| cat.lua:117 cp5Bite | Druid.lua:812 | `or macroTorch.isFastBattleNotPvp(clickContext)` | ✓ WIRED |
| cat.lua:163 energyDischarge | Druid.lua:812 | `and not macroTorch.isFastBattleNotPvp(clickContext)` | ✓ WIRED |
| cat.lua:337 keepRake | Druid.lua:812 | `or macroTorch.isFastBattleNotPvp(clickContext)`（链末） | ✓ WIRED |
| Druid.lua isFastBattleNotPvp | entity/Target.lua:86 willDieInSeconds + Druid.lua:513 estimatePlayerDPS | 同 isTrivialBattle 双条件结构 | ✓ WIRED |
| write `clickContext.isFastBattleNotPvp` | read at 6 处调用点 | 同字段懒缓存（D-11） | ✓ WIRED |
| SelfTest:register(name, fn, true) | core/selftest.lua:34 API（第三参 isOptional） | `end, true)` × 6 | ✓ WIRED |
| catAtk 每帧新建 clickContext（combo.lua:55） | 缓存失效 → 每帧重算 | `local clickContext = {}` | ✓ WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| isFastBattleNotPvp 判定 | `willDieInSeconds(8.5)` | currentHRPS() 线性回归（100 点滑动窗口，事件驱动采集） | ✓ 真实运行时数据 | ✓ FLOWING |
| isFastBattleNotPvp 判定 | `target.healthMax` | WoW UnitHealthMax 实时单位血量 | ✓ 真实运行时数据 | ✓ FLOWING |
| isFastBattleNotPvp 判定 | `estimatePlayerDPS()` | 等级自适应查表 | ✓ 真实运行时数据 | ✓ FLOWING |
| 6 处守卫 | `isFastBattleNotPvp(clickContext)` 返回值 | 上述判定 → 分支控制 | ✓ 无静态回退、无硬编码 true/false | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 构建成功 | `./build.sh` | exit 0 | ✓ PASS |
| SM_Extend.lua 含函数 | `grep -c "function macroTorch.isFastBattleNotPvp"` | 1 | ✓ PASS |
| SM_Extend.lua 含 6 测试名 | `grep -c "P: isFastBattleNotPvp\|P: fast battle\|P: cp5Bite"` | 6 | ✓ PASS |
| 阈值唯一 | `grep -c "localFastDieTime = 8.5" Druid.lua` | 1 | ✓ PASS |
| 调用点计数 | combo.lua / cat.lua 各 3 处 | 3 / 3 | ✓ PASS |
| leveling.lua 零改动 | `git diff -- classes/druid/leveling.lua` | 空 | ✓ PASS |
| P-06 行为测试执行 | 需 Lua 解释器/WoW 客户端 | 环境无 lua/luac/luajit | ? SKIP — 见 Human Verification |

### Probe Execution

无 probe 声明（本 phase 非迁移/工具类 phase）— SKIPPED。

### Requirements Coverage

D-01..D-13 全部有归属并核验（REQUIREMENTS.md 为旧 R1..Rn 格式、不含 D-ID 行；D-ID 来源为 26-CONTEXT.md，见 ROADMAP.md "Phase 26 — Requirements: D-01 through D-13 (from 26-CONTEXT.md)"）：

| Requirement | 声明于 | Description | Status | Evidence |
|-------------|--------|-------------|--------|----------|
| D-01 | 26-01 frontmatter + 26-CONTEXT | 函数存在/位置/PvP 首句 | ✓ SATISFIED | Druid.lua:812-816 |
| D-02 | 26-01 frontmatter | 阈值 8.5 唯一 | ✓ SATISFIED | grep == 1 |
| D-03..D-08 | 26-01 frontmatter | 6 处守卫 | ✓ SATISFIED | 见 Truths #6-#10 |
| D-09 | 26-01 + 26-02 frontmatter | 追加式/共享函数不变 | ✓ SATISFIED | git diff 单 hunk/零 hunk 审计 |
| D-10 | 26-01 + 26-02 frontmatter | 无防抖 | ✓ SATISFIED | diff 零 timer 构造 |
| D-11 | 26-01 frontmatter | 惰性缓存/每帧重算 | ✓ SATISFIED | Druid.lua:817 + combo.lua:55 |
| D-12 | 26-01 frontmatter（1-2/6）+ 26-02（3-6/6） | 6 个 isOptional SelfTest | ✓ SATISFIED | selftest.lua:698-807（含 Warning） |
| D-13 | 26-02 frontmatter | catLeveling 不动 | ✓ SATISFIED | leveling.lua 零 hunk |

无 orphaned 需求：两个 PLAN frontmatter `requirements` 字段并集 = D-01..D-13 全集。

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| core/selftest.lua | 708-718 (P-02) | stub/restore 非精确：`target.isPlayerControlled` 是经 `__index` 计算的字段（Unit.lua:186 `['isPlayerControlled'] = function(self) ...`，classMetatable `__index` 直接调用 FIELD_FUNC_MAP），并非计划声称的 "plain boolean field"。`macroTorch.target.isPlayerControlled = true` 是 rawset 影子字段，`= origPvp` 还原的是测试时刻的快照值 — 影子字段永久遮挡实时计算直至实例重建（仅 addon 重载时 Target:new 一次，Target.lua:105） | ⚠️ WARNING | /mt 运行后本会话内 PvP 实时检测被冻结：若登录时快照为 false（PvE 常态），则之后进入 PvP 时本 phase 新增的 PvP 排除失效（对玩家目标可能误入纯直伤策略），Phase 14 的 isTrivialBattleOrPvp PvP 臂同步失效；若在 PvP 状态下运行 /mt（快照 true），isFastBattleNotPvp 整会话恒 false — 本 phase 核心功能被自身测试禁用。建议修复：恢复时 `macroTorch.target.isPlayerControlled = nil` 删除影子字段（重新启用 __index） |
| core/selftest.lua | 768 (P-05) | 断言强度：恒真 stub 下的等值断言即便阈值写错也会通过（fast 与 trivial 都会恒真） | ℹ️ INFO | 蕴含关系仍可由源码数学证明（willDieInSeconds 对 s 单调）；isOptional=true 测试为附加证据，无功能影响 |

无 TBD/FIXME/XXX 债务标记（新增行扫描零命中）。

### Human Verification Required

#### 1. P-06 行为回归 + 快速战斗状态转移（对应 behavior_unverified #1）

**Test:** 游戏内运行 `/mt` 自检（或登录触发 PLAYER_ENTERING_WORLD 自检），观察 Category P 六条全部通过；随后攻击一只将在 8.5s 内死亡的弱怪，保持无 Rake/Rip（流血）与无流血免疫，攒满 5 星。
**Expected:** P-06 无红字失败；5CP 时触发 Bite（cp5Bite 经新增 `or macroTorch.isFastBattleNotPvp` 进入分支 → safeBite/readyBite）。
**Why human:** 该状态转移唯一测试 P-06 需要 WoW 客户端 API（UnitClass 等）与本环境没有的 Lua 解释器；grep/静态分析只能证明代码在场且路径自洽，不能证明运行时触发。

#### 2. P-02 SelfTest 影子字段副作用（Warning 项）

**Test:** 运行 `/mt` 之后，在同一会话内选中一个 PvP 玩家目标（决斗/野外），观察 isTrivialBattleOrPvp 与 isFastBattleNotPvp 的行为。
**Expected:** 期望行为（当前代码下可能不成立）：isFastBattleNotPvp 对玩家目标立即返回 false 且不过缓存；IsTrivialBattleOrPvp 对玩家目标走 quickKeepRip 臂。
**Why human:** 影子字段冻结导致会话内 PvP 检测停在 /mt 运行时刻的快照值，只有游戏内观察能确认实际影响；修复建议（`= nil` 删除影子字段）需开发者决策。

#### 3. fast ⇄ normal 逐帧切换

**Test:** 对中等血量 mob 开战，观察其血量降至 8.5s 死亡预测线以下/以上时，下一帧的行为切换。
**Expected:** 进入 fast 后流血停止、仅直伤；回到 normal 后 keepRip/keepRake 恢复。切换无粘滞、无死锁。
**Why human:** 每帧重算行为依赖 WoW 运行时事件采集，环境内无法模拟。

### Gaps Summary

无 FAIL 级 gap：全部 13 项决策落地，16 条合并 truth 中 15 条 VERIFIED、1 条 PRESENT_BEHAVIOR_UNVERIFIED（D-08 状态转移，测试存在但仅游戏内可执行）。唯一实质性缺陷为 P-02 的 isPlayerControlled stub 恢复非精确（WARNING —— 计划文案 "plain boolean field ... stubbing and restoring it is exact" 与事实不符），后果是 /mt 运行后会话内 PvP 实时检测冻结，建议以 `= nil` 删除影子字段的方式修复。该两项均走 human_needed 路由，不阻塞后续 phase 展开（catLeveling fast 策略为显式 deferred 项，非 gap）。

---

_Verified: 2026-08-22_
_Verifier: Claude (gsd-verifier)_