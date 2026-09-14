---
phase: quick-260914-nth
plan: 260914-nth
subsystem: cat-druid-cp-builder
tags: [lua50, wow-1.12, selfTest, shouldUseShred, getNextAbilityCost, CR-01-stub-discipline, shred-vs-claw]

# Dependency graph
requires: []
provides:
  - "shouldUseShred 分支3：3+ 流血付费帧保持 Claw、免费帧(OoC/无限能量)背后改为 Shred"
  - "R6-05 重写（免费帧断言 + 同帧 getNextAbilityCost 析出 SHRED_E 轻量 pin）+ R6-05b 付费帧伴生 pin"
  - "原则文档 Rule 6 表格行 3 与伪代码行 3 免费帧例外修订（untracked 工作树-only）"
affects: [catAtk-cp-builder, getNextAbilityCost-consumers, catAtk-core-principles]

# Actuals (#2632) — chars/4 over the realized diff
actuals:
  tokens: 767
  tasks: 3
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CR-01 测试桩纪律（R6-01..03 先例）：rawget 快照/own-key 影子/rawset 还原 + isKillShotOrLastChance orig 引用 capture/restore，还原均在 pcall 之后、所有 assert 之前"
    - "R6-05b 付费帧测试证明短路免影子（与 R6-04 同构）：(false or false) 使 and-chain 在 accessor 之前短路"

key-files:
  created: []
  modified:
    - "classes/druid/Druid.lua — shouldUseShred 1016-1024 分支3 改写（提交 c1f4e67）"
    - "classes/druid/selftest.lua — R6-05 重写(484-529) + R6-05b 新增(530-553)（提交 c1f4e67）"
    - ".planning/catAtk-core-principles.md — Rule 6 表行3 + 伪代码行3（UNTRACKED，永不提交；.gitignore:34）"

key-decisions:
  - "免费帧裁决落地形态：分支3 return 行与分支2 字节一致（(ooc or infiniteEnergy) and isBehind and not isBehindAttackJustFailed），付费帧经短路天然落回 false，零新增运行时代价"
  - "SHRED_E pin 折入新 R6-05 而非独立测试：kill-shot 函数 stub + isFastBattleNotPvp 预置 false 构成确定 trace；fastBattle 的 player-controlled 前置读（1054）不影响 false 结论"
  - "getNextAbilityCost 能量影响判为差≈0：shouldDoReshift(cat.lua:258) 与 shouldCastFFDuringWaitWindow(Druid.lua:1167) 均显式排除 ooc，无限能量帧上成本不等式恒不成立，SHRED_E 更贵只会愈加固化"

patterns-established: []

requirements-completed: ["R6@quick-260914-nth"]

# Metrics
duration: 7min
completed: 2026-09-14
status: complete
---

# 快速任务 260914-nth: OoC 帧 cp-builder 裁决落地 Summary

**3+ 流血免费帧（OoC/无限能量·背后）由 Claw 改为 Shred：shouldUseShred 分支3 行为改写 + R6-05 免费帧断言（折入 getNextAbilityCost SHRED_E 析出 pin）+ R6-05b 付费帧伴生 pin + 原则文档 Rule 6 免费帧例外修订（untracked）**

## Performance

- **Duration:** 7 min
- **Started:** 2026-09-14T09:24:22Z
- **Completed:** 2026-09-14T09:30:39Z
- **Tasks:** 3
- **Files modified:** 3（2 个提交 + 1 个 untracked 文档）

## Accomplishments

- `Druid.lua` shouldUseShred 分支3：`else return false -- 3+ bleeding always uses Claw end` 三行改写为 6 行英文注释（引用 2026-09-14 样本裁决证据：撕碎非暴击单发 507.3 n=124 vs 3 流血爪击 483.5 n=13，等暴击期望差约 5%，爪击每多一流血仅 +57）+ `return (clickContext.ooc or infiniteEnergy) and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed`（与分支2 行 1015 字节一致，and-chain 计数 1→2 经 GATE 1 钉死）
- `selftest.lua` 旧 R6-05（「3+ 流血无视 OoC/infinite 永远 Claw」，与新行为矛盾必红）整块重写为新 R6-05：3 流血 ooc+infinite+behind 断言 Shred，并折入轻量 pin —— 同一 ctx 上 `getNextAbilityCost` 必须析出 `ctx.SHRED_E`(60) 而非 `CLAW_E`(45)，kill-shot 函数 stub + isFastBattleNotPvp 预置 false 保证确定性；新增 R6-05b 断言付费帧(ooc=false/infinite=false)仍 Claw
- 原则文档（untracked）两处锁定修订：Rule 6 表格行 3 与伪代码行 3 免费帧例外；页脚/围栏/作者行零改动，`wc -l` 494→495

## Task Commits

1. **Task 1: Druid.lua 分支3 改写 + selftest R6-05 重写/R6-05b + 全电池** - `c1f4e67` (fix)
2. **Task 2: 原则文档 2 处锁定修订** - 无 commit（untracked 工作树-only，按计划永不提交）
3. **Task 3: SUMMARY 输出** - 无 commit（.planning 收口留给 quick 流程 docs commit）

`git show --stat --format= HEAD` 确认 c1f4e67 仅含 `classes/druid/Druid.lua`（+8/-1 呈现）与 `classes/druid/selftest.lua`（+49/-2 呈现），57 insertions / 3 deletions，无文件删除。

## Files Created/Modified

- `classes/druid/Druid.lua` — shouldUseShred 分支3 免费帧 Shred 化（1016-1024）
- `classes/druid/selftest.lua` — R6-05 重写（484-529，含 SHRED_E pin）+ R6-05b 新增（530-553），R6-06 顺移至 554
- `.planning/catAtk-core-principles.md` — Rule 6 表行3 `| 3+ | 爪击（付费帧）；撕碎（OoC/无限能量·背后） | 付费帧爪击 DPE 仍最高；免费帧能量成本无关、GCD 稀缺，撕碎单发胜出 |`、伪代码改为 `useShred IF (ooc OR infiniteEnergy) AND isBehind / ELSE useClaw`（untracked，工作树-only）

## 验证电池结果（GATE 0-6）

| Gate | 内容 | 结果 |
|------|------|------|
| GATE 0 | 三解释器（Lua 5.0.3/5.1.5/5.4.7）loadfile 编译两文件 | LOADFILE-OK ×3 |
| GATE 1 | 16 项结构 grep（新注释×2、and-chain=2、旧文本清零×2、R6-05/R6-05b 命名、pin 断言、kill-shot capture/stub/restore=1×3、shadow=4、rawset=4、isPouncePresent=2） | 全绿 |
| GATE 2 | 删除面：内容断言逐字执行通过（被删行 = 旧 return / 旧 R6-05 块）；计数值修正后验证（见 Deviations） | 通过（内容）|
| GATE 3 | hunk 起行范围：Druid.lua=1017∈1010..1025；selftest.lua=484/491/501/503∈480..600（解析方式修正，见 Deviations） | 通过 |
| GATE 4 | bbcheck 两文件全文件 BALANCED（计划基线保持）+ 变更区段重建平衡（Druid 1013-1025 / selftest 483-553 均 BALANCED，替代 additions-only 检查，见 Deviations） | 通过 |
| GATE 5 | 新增行无 `#`/`goto `/`::`、无 CJK、无 CR 字节、`git diff --check` 干净 | 全绿 |
| GATE 6 | 变更面：tracked 修改恰为两个 Lua 文件；untracked 仅 quick 目录自身；原则文档不出现在 status（仍被 check-ignore）；SM_Extend.lua 零触碰；未运行任何 build | 通过 |
| Task 2 文本门 | 正向 3 grep + 旧文本清零 2 项 + 行差 494→495 + 恰 2 hunk + 围栏 30 不变 + 作者行末行无换行 + 12 常量漂移审计 + 零 git 复核 | 全绿（hunk 计数值见 Deviations） |

## Decisions Made

- 免费帧裁决落地形态（如上 key-decisions）
- **pin 决策（已读 shouldUseBite 裁定）：加。** 稳定 ctx 构造存在：isSpellExist 系真实 API 与既测同类；fastBattle 用 `ctx.isFastBattleNotPvp=false` 预置（Druid.lua:1054 player-controlled 前置读不影响 false 结论）；shouldUseBite 的 trivial 臂被 `ctx.isImmuneRip=true` 短路杀死、cp5 臂被 `ctx.comboPoints=1` 杀死，唯 isKillShotOrLastChance 是实机状态读——函数 stub(false) 钉死；isTigerPresent/isRipPresent/isRakePresent 全部 ctx 预置。执行前逐行 live 校验全部 helper（getNextAbilityCost 七步、shouldUseBite、isFastBattleNotPvp、isTigerPresent、isRipPresent、isRakePresent），trace 与计划锁定一致。

## 能量估算影响论证结论（live 校验后确认 差≈0）

`getNextAbilityCost` 在该 ctx 上由 CLAW_E 析出 SHRED_E，两个生产消费者均被前置门屏蔽：

1. `shouldDoReshift`（cat.lua:252-281）：`clickContext.ooc` 显式排除（cat.lua:258）；无限能量帧上 `math.ceil(projectedEnergy) < nextAbilityCost` 因 `projectedEnergy >= nextAbilityCost` 恒真而永不触发；SHRED_E 更贵只使不等式更不可能触发。
2. `shouldCastFFDuringWaitWindow`（Druid.lua:1167 显式排除 ooc）：无限能量帧上 `currentEnergy < minAbilityCost` 永不成立，同样愈加固化。
3. 其余 getNextAbilityCost 测试调用点 ctx 无 `isPouncePresent=true`（GATE 1 绝对计数 2 钉死：仅新 R6-05 与 R6-05b），零影响。

执行前已 live 读取以上锚点行核实（cat.lua:255/258/278、Druid.lua:1166-1167/1184），与计划论证一致。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - 计划 diff 算术] GATE 2 删除行计数与 git 实际渲染不符（预测 -3/-21 与实测 -1/-2）**
- **Found during:** Task 1（GATE 2 执行）
- **Issue:** 计划预测 Druid.lua 3 删除行（else/return/end 整块）、selftest.lua 21 删除行（旧 R6-05 整块）。实测 git LCS 对齐把字节相同的 `else`/`end` 及新旧块共有的 19 行（ctx 结构行、`}`、assert 首行、`end, true)`）渲染为 context/matched，实际删除行为 Druid.lua 1 行（旧 return，逐字=锁定旧块）、selftest.lua 2 行（旧 register 行 + 旧断言串行）。执行前用 scratch repo 复刻验证了该渲染。
- **Fix:** 保留计划 GATE 2 全部内容断言（逐字执行，全过），计数断言的期望值改为实测地面真值（1 与 2），并追加更强的等价检查：删除行集合 = 旧锁定块签名行（三串 grep -vF 过滤后为空集）。计划的意图（删除面=旧块、无越界删除）被完全保留且强化。
- **Files modified:** 无（仅验证脚本参数）
- **Verification:** 删除行逐行 cat -A 目视 = 锁定旧块字节；GATE 3 hunk 范围全部落在计划带内。
- **Committed in:** c1f4e67（Task 1 commit）

**2. [Rule 3 - 计划 diff 算术] GATE 3 hunk 正则假设 `@@ -行,count` 格式，git 在 count=1 时省略 `,count`**
- **Found during:** Task 1（GATE 3 执行）
- **Issue:** 实测 hunk 头为 `@@ -1017 +1017,7 @@` 及 `@@ -484 +484 @@`（无 `,count`），计划正则 `^@@ -(10[1-9][0-9]|102[0-5]),` 因缺逗号不匹配直接判 FAIL。selftest 因新旧块大量共有行被拆为 5 个 hunk（484/491/501/503 起），与计划的单一 hunk 假设不同。
- **Fix:** hunk 起行改用通用 `^@@ -([0-9]+)` 提取后逐个范围断言；范围带保持不变（Druid 1010..1025；selftest 480..600）——计划的范围意图原样保留。
- **Files modified:** 无（验证脚本解析方式）
- **Verification:** 实测起行 1017 / 484 / 491 / 501 / 503 全部落在计划范围内。

**3. [Rule 3 - 计划 diff 算术] GATE 4 additions-only 平衡脚本对碎片化 diff 失效**
- **Found during:** Task 1（GATE 4 执行）
- **Issue:** 计划的脚本只对 `-U0` 的 `+` 行做括号平衡。因 git 把 `local ctx = {`、共享 ctx 字段、`}`、`end, true)` 等结构行对齐为 context，新增行流本身不平衡（首个 `\t\t}` 栈顶是 register 的 `(`），脚本无条件判 MISMATCH——不是代码不平衡（bbcheck 全文件双 BALANCED、三解释器 loadfile 已证语法成立）。
- **Fix:** 用等价强度更高的区段重建平衡替代：从**编辑后的文件**提取变更区段（Druid.lua 1013-1025、selftest.lua 483-553，含被对齐为 context 的结构行）做同样的注释/字符串剥离 + 括号平衡。保留计划全文件 bbcheck 双 BALANCED 断言（逐字执行，通过）。
- **Files modified:** 无（验证脚本替换）
- **Verification:** Druid.lua 1013-1025 BALANCED；selftest.lua 483-553 BALANCED；bbcheck 两文件 BALANCED；loadfile ×3。初次区段测验中 554 行截断引入的假阳性经边界修正后确认代码无恙。

**4. [Rule 3 - 计划 diff 算术] GATE 6 直跑必败：quick 目录自身是 untracked（`??`）**
- **Found during:** Task 1（GATE 6 执行）
- **Issue:** 计划命令以 `git status --porcelain` 仅剩两个 ` M` 行为前提，但本 quick 目录 `.planning/quick/260914-nth-.../` 必然是 untracked（docs commit 由 quick 流程收口），porcelain 恒多一行 `??`。且该行在我开始执行前即存在。
- **Fix:** 意图保真版本：tracked ` M` 恰为两个 Lua 文件（数量+名称双断言）、`??` 行中不含 catAtk-core-principles.md、`git check-ignore` 仍输出该路径、SM_Extend.lua diff stat 为 0。
- **Files modified:** 无（验证命令调整）
- **Verification:** 上述断言全绿；commit 后 `git status --porcelain` 仅剩 quick 目录 `??` 一行。

**5. [Rule 3 - 计划 diff 算术] Task 2 ZERO-DELTA 预测 -3/+4，实测 -2/+3**
- **Found during:** Task 2（快照 diff 审计）
- **Issue:** 伪代码旧块首行 `IF  bleedCount >= 3:` 新旧字节相同，diff 渲染为 context，故删除行 = 表行1 + useClaw 行1 = 2（计划计 3）、新增行 = 新表行1 + 伪代码 2 行 = 3（计划计 4）。行差 494→495、恰 2 hunk、围栏 30 不变等其余全部命中。
- **Fix:** 按地面真值 2/3 校验，内容断言（正向 3 项、旧文本清零 2 项、行差、hunk 数、结构不变量、12 常量漂移）逐字执行全部通过；文档内容与锁定文本完全一致，无需回退。
- **Files modified:** 无
- **Verification:** `/tmp/catAtk-nth.diff` 目视两 hunk 恰对应 Rule 6 表格行与伪代码块，无其它字节变化。

---

**Total deviations:** 5 auto-fixed（均为 [Rule 3 - 计划 diff 算术]，全部集中在计划验证电池的**预测计数/格式**，零代码/文档锁定文本偏差）
**Impact on plan:** 两处 Edit 的 old/new 块均逐字节照锁定文本执行；所有内容级断言按计划原文通过；唯一改变的是验证电池中与 git 实际 diff 渲染不符的预测数字，且每处都替换为强度不低于原意的地面真值断言。产物行为与计划目标完全一致。

## Issues Encountered

- git diff 的 LCS 对齐将新旧块共有行渲染为 context/matched，导致计划的"整块替换"diff 假设在三处（GATE 2/3/4）与 Task 2 快照 diff 上落空——scratch repo 复刻 + per-line 栈追踪定位根因（非代码问题），随后以区段重建平衡与逐行签名过滤替代。
- 调试过程中的两处工具性失误（`^--` 计数模式误写、区段右界误含 554 行 R6-06 的 register 开括号）均已识别并修正，最终证据链自洽。

## User Setup Required

None - 无外部服务配置。仅需实机验证（见下）。

## Unrun Verification 备案

本机无 WoW 客户端，R6-05/R6-05b 的实机执行未运行：

- **预期：** 用户 Windows+Cygwin 重建 `/mt` 后 R6-05（3 流血免费帧 Shred + SHRED_E pin）与 R6-05b（付费帧 Claw）应绿。**行为同步证据链：** 旧版 R6-05 断言（always Claw）在实机必红——新分支 3 在 ooc+infinite+behind 返回 true——先红后绿正是本次行为同步的证明。
- **实战观察点：** 3 流血在场时，清晰预兆（CC）/红龙精华帧背刺改为撕碎（战斗记录出现 Shred），非免费帧仍爪击。

## Next Phase Readiness

- 代码与文档均已落位；等 quick 流程 docs commit 收口 STATE.md 行（49l/0ql 先例）。
- 无遗留 blocker；无新增威胁面（T-260914-nth-01 CR-01 纪律已在新 R6-05 中实现，其余四项 accept 维持）。

## Self-Check

- [x] `classes/druid/Druid.lua` 存在且 1778 行（+6）
- [x] `classes/druid/selftest.lua` 存在且 2366 行（+48）
- [x] commit c1f4e67 存在：`git log --oneline -1` = `c1f4e67 fix(druid): 3+ bleeds free frames (OoC/infinite) behind use Shred; R6-05 rewrite + R6-05b paid-frame pin`
- [x] `git status --porcelain` 仅剩 quick 目录 `??` 一行（原则文档隐性、被 ignore）
- [x] 原则文档 `wc -l` = 495、`git check-ignore` 输出路径、末行无换行
- [x] GATE 0-6 全绿（0 全过、1 全过 16/16、4 双 BALANCED+区段平衡、5 全过、6 意图保真全过；2/3 按地面真值修正后全过）

## Self-Check: PASSED