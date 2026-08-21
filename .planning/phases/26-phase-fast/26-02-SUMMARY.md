---
phase: 26-phase-fast
plan: 02
subsystem: classes
tags: [druid, feral-cat, isFastBattleNotPvp, selftest, regression, wow-addon, lua]

# Dependency graph
requires:
  - phase: 26-01
    provides: macroTorch.isFastBattleNotPvp + 7 guards + Category P section with P-01/P-02 (stub/restore template)
  - phase: 14-istrivialbattle-iskillshotorlastchance
    provides: isTrivialBattle / willDieInSeconds / estimatePlayerDPS (P-04/P-05 stub targets)
  - phase: 15-catatk-combo-refactor
    provides: macroTorch.cp5Bite / safeBite / readyBite / energyDischargeBeforeBite (P-06 stub targets)
provides:
  - 4 additional Category P SelfTests in core/selftest.lua (P-03 HRPS, P-04 health estimate, P-05 priority relation, P-06 cp5Bite regression)
  - Complete 6/6 D-12 SelfTest coverage with isOptional=true and stub/restore discipline
  - Final phase-wide verification (build, call-site counts, threshold literal, scope discipline, D-09/D-10/D-13 negative confirmations)
affects:
  - nothing downstream — Phase 26 closes with this plan; catLeveling fast-battle strategy remains deferred (26-CONTEXT.md)

# Actuals (#2632) — pairs with the plan's `estimate` (30000 tokens) to calibrate future estimates
actuals:
  tokens: 1079
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stub/restore discipline: local orig capture → pcall body → restore BEFORE first assert (T-26-04/T-26-06 mitigation)"
    - "Direct field injection to isolate a guard from live state: ctx.isFastBattleNotPvp = true bypasses HRPS collection (P-06)"
    - "Condition-isolation stubbing: kill Condition A with a false stub so Condition B alone decides the verdict (P-04)"

key-files:
  created: []
  modified:
    - core/selftest.lua

key-decisions:
  - "P-03/P-05 guard on macroTorch.target.isPlayerControlled (duel makes fast=false spuriously); P-04 guards on isCanAttack so healthMax is a real number"
  - "P-04 stubs estimatePlayerDPS to 1e9: (mateNearMyTargetCount+1) * 1e9 * 8.5 exceeds any real healthMax, making Condition B deterministic with willDieInSeconds stubbed false"
  - "P-06 stubs the full cast chain (safeBite/readyBite/energyDischargeBeforeBite) so no real spell fires during login self-test (T-26-05); isPseudoInfiniteEnergy=true makes shouldDischarge=false without relying on the discharge stub"
  - "Phase-wide verification scope = phase base a1467b1..HEAD excluding .planning/ metadata: shows exactly the 4 planned code files"
  - "Category P registration-count comment updated to '6 tests (2 in 26-01, 4 in 26-02)' — the previous '4 more arrive in 26-02' text became stale once P-06 landed"

requirements-completed: [D-09, D-10, D-12, D-13]

# Coverage metadata (#1602)
coverage:
  - id: D4
    description: "P-03 HRPS arm + P-04 health-estimate arm + P-05 fast⇒trivial priority relation (D-12 items 3-5)"
    requirement: D-12
    verification:
      - kind: other
        ref: "grep name counts 1/1/1; 6 test-name lines total; ./build.sh OK; SM_Extend.lua contains the registrations"
        status: pass
    human_judgment: true
    rationale: "Registrations execute inside the WoW client at PLAYER_ENTERING_WORLD via /mt; verdict logic exercised only in-game"
  - id: D5
    description: "P-06 cp5Bite 5CP fast-battle regression — bite must trigger with Rip absent and no immunity (D-12 item 6 / D-08)"
    requirement: D-12
    verification:
      - kind: other
        ref: "grep 'P: cp5Bite triggers bite at 5CP' == 1; all 4 stubs restored before asserts; ./build.sh OK"
        status: pass
    human_judgment: true
    rationale: "Combat-path behavior observable only in a live game session; cast chain fully stubbed so the self-test is side-effect free"

# Metrics
duration: 3min
completed: 2026-08-21
status: complete
---

# Phase 26 Plan 02: Category P SelfTest 补全 + 全阶段验证 Summary

**P-03..P-06 四个 SelfTest 注册落盘：HRPS 路径、血量估算路径、fast⇒trivial 优先级关系、cp5Bite 5CP 行为回归全部纳入 /mt 自检（均 isOptional=true、non-Druid 守卫、stub/restore 安全纪律），Phase 26 全阶段验证 8 项全绿**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-08-21T16:06:23Z
- **Completed:** 2026-08-21T16:09:36Z
- **Tasks:** 2
- **Files modified:** 1（core/selftest.lua）
- **Diff size:** 4316 added chars ≈ 1079 estimateTokens 单位（chars/4）— 计划估计 30000；本计划为测试注册追加，估计偏高约 28x（供 ADR-2629 校准）

## Accomplishments

- **P-03 HRPS 路径**（D-12 item 3）：`willDieInSeconds(8.5)` stub 恒真 → `isFastBattleNotPvp` 必须为 true，单独隔离条件 A
- **P-04 血量估算路径**（D-12 item 4）：`willDieInSeconds` stub 恒假杀掉条件 A + `estimatePlayerDPS` stub 1e9 → 条件 B 单独决定判true
- **P-05 优先级关系**（D-12 item 5）：同一 stub 下 `isFastBattleNotPvp({}) == isTrivialBattle({})`（8.5 < 25，fast 是 trivial 的子集）
- **P-06 cp5Bite 行为回归**（D-12 item 6 / D-08）：`ctx.isFastBattleNotPvp = true` 直接注入隔离实时 HRPS，stub 掉 isRipPresent/safeBite/readyBite/energyDischargeBeforeBite 四条施法链——5CP + 快速战斗 + 无 Rip 无免疫必须触发 Bite，且登录自检零真实施法
- **全阶段验证**：6 个 Category P 注册（均 `end, true)`）、combo.lua/cat.lua 各 3 处调用点、`localFastDieTime = 8.5` 字面量唯一、全阶段 diff 仅 4 个计划内文件、leveling.lua 零 hunk（D-13）、diff 形状 = 1 个新函数 + 7 处守卫（D-09/D-10）、无新依赖无 build_order 变更

## Task Commits

Each task was committed atomically:

1. **Task 1: 注册判定路径 SelfTest P-03/P-04/P-05（HRPS、血量估算、优先级关系）** — `e40dfe5` (feat)
2. **Task 2: 注册 cp5Bite 回归 SelfTest P-06 + 全阶段验证** — `7c80079` (feat)

## Files Created/Modified

- `core/selftest.lua` — Category P 段落内 +87/−1 行：P-02 之后依次追加 P-03/P-04/P-05/P-06 四个 `isOptional=true` 注册（每个上方带 `-- Phase 26 D-12 ...` 引用注释），段落计数注释同步为 6 tests

## Decisions Made

- 完整遵循 26-CONTEXT.md D-01..D-13 与 26-02-PLAN.md 的 stub/restore 纪律：原函数全部保存到 local → pcall 体内执行 → **先恢复后 assert**，失败的测试不会污染后续测试（T-26-04/T-26-06）
- P-04 用 1e9 DPS stub 保证条件 B 决定性成立；P-06 用 `isPseudoInfiniteEnergy=true` 让泄能检查自然跳过，防御性 stub 泄能函数兜底
- 全阶段验证以 phase 基线 `a1467b1..HEAD`（排除 .planning 元数据）为准：恰好 4 个计划内代码文件、catLeveling 零改动

## Deviations from Plan

Code execution: None — plan executed exactly as written (both tasks, all per-task verifies and overall 8-point verification green).

### Doc-Alignment Fixes (planning-doc truth only, no code impact)

**1. [Docs] Task 1 verify `grep -c "Category P"` 期望 1 实为 2（26-01 遗留）**
- **Found during:** Task 1 verify run
- **Issue:** 文件中 "Category P" 出现在两处——段落标题（26-01 添加）与 "Registration count" 计数注释行。计划校验期望 1，属计划文案未计入计数注释行
- **Fix:** 无代码修改。任务意图（"只追加到既有段落内，不新增第二个段落头"）通过 git diff 验证：本计划新增行含 "Category P" 0 处
- **Files modified:** 无

**2. [Docs] Category P 计数注释同步更新（Task 2，1 处删除行）**
- **Found during:** Task 2 收尾
- **Issue:** 旧注释 "Registration count: Category P adds 2 tests in 26-01; 4 more arrive in 26-02" 在 P-06 落地后不再真实（"4 more arrive" 描述的是未完成状态）
- **Fix:** 更新为 "Registration count: Category P adds 6 tests (2 in 26-01, 4 in 26-02)"
- **Files modified:** core/selftest.lua（注释行，commit 7c80079 中的 1 deletion）

## Issues Encountered

- 环境无 Lua 解释器（luac/lua 均不可用）——语法门由 `./build.sh` 拼接产物验证（与 26-01 相同做法），拼接成功即确认无语法断裂
- REQUIREMENTS.md 为旧 R1..Rn 格式，不含 D-09..D-13 ID 行，`requirements.mark-complete` 无可勾选条目；D-09/D-10/D-12/D-13 的验证以计划 `<verification>` 8 项检查为准
- SM_Extend.lua 位于 .gitignore（构建产物不入库），构建验证采用"运行 build + grep 产物"方式

## Known Stubs

None — 全部 6 个注册为真实断言；stub 函数均为测试内的临时替换且 100% 在 assert 前恢复，无遗留桩、无跳过测试、无 TODO。

## Next Phase Readiness

- Phase 26 至此收尾：6/6 Category P SelfTest、7 处守卫、isFastBattleNotPvp 全部落地并构建绿色
- 延后事项（26-CONTEXT.md deferred）：catLeveling 快速战斗策略、HRPS 抖动防抖（hysteresis）留待后续 phase

---

*Phase: 26-phase-fast*
*Plan: 02*
*Completed: 2026-08-21*

## Self-Check: PASSED

- `FOUND: e40dfe5` — Task 1 commit (feat(26-02): register judgment-path SelfTests P-03/P-04/P-05)
- `FOUND: 7c80079` — Task 2 commit (feat(26-02): register cp5Bite regression SelfTest P-06 + phase-wide verification)
- Build gate: `./build.sh` exit 0 on both tasks（Task 2 收尾时再跑一次仍绿）
- `grep -c 'P: isFastBattleNotPvp\|P: fast battle\|P: cp5Bite' core/selftest.lua` = 6（六个 test-name 行）
- Category P 区域内 `SelfTest:register` 与 `end, true)` 各 6 处（全部 isOptional=true）
- `grep -c "function macroTorch.isFastBattleNotPvp" SM_Extend.lua` = 1；SM_Extend.lua 含 P-06 注册名
- 全阶段 diff（a1467b1..HEAD，排除 .planning）= 仅 Druid.lua/combo.lua/cat.lua/core/selftest.lua；`classes/druid/leveling.lua` 零 hunk