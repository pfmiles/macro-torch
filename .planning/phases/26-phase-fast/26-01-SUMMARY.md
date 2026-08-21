---
phase: 26-phase-fast
plan: 01
subsystem: classes
tags: [druid, feral-cat, catAtk, fast-battle, isFastBattleNotPvp, selftest, wow-addon, lua]

# Dependency graph
requires:
  - phase: 14-istrivialbattle-iskillshotorlastchance
    provides: isTrivialBattle / isTrivialBattleOrPvp / isKillShotOrLastChance decision functions + willDieInSeconds HRPS prediction (implementation template + data source)
  - phase: 15-catatk-combo-refactor
    provides: macroTorch.catAtk global one-button macro in classes/druid/combo.lua (all modification anchors)
  - phase: 22-catatk-selftest
    provides: SelfTest:register registration pattern in core/selftest.lua (Category-letter grouping + isOptional flag)
provides:
  - macroTorch.isFastBattleNotPvp(clickContext) — 8.5s death-prediction judgment (HRPS OR health estimate), PvP-first exclusion, per-frame lazy cache
  - 7 additive fast-battle guards across catAtk: Pounce skip + Rip wrapper + regularAttack precondition (combo.lua), cp5Bite 5CP trigger + keepRake guard + energyDischarge Rake fallback (cat.lua)
  - 2 Category P SelfTests (P-01 existence, P-02 PvP exclusion + cache-ordering proof) with isOptional=true
affects:
  - 26-02-PLAN.md (remaining 4 Category P SelfTests + full-phase verification depend on this plan's function and test registrations)
  - future catLeveling fast-battle phase (deferred in 26-CONTEXT.md)

# Actuals (#2632) — pairs with the plan's `estimate` (42000 tokens) to calibrate future estimates
actuals:
  tokens: 1324
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive-guard modification: every change is an and/or-append or a wrapping if — no pre-existing branch removed or reordered (D-09)"
    - "Per-frame lazy judgment cache: if clickContext.X == nil then compute, identical to isTrivialBattle (D-11)"
    - "Category-letter SelfTest grouping with UnitClass guard + isOptional=true (Category P in core/selftest.lua)"

key-files:
  created: []
  modified:
    - classes/druid/Druid.lua
    - classes/druid/combo.lua
    - classes/druid/cat.lua
    - core/selftest.lua

key-decisions:
  - "D-01/D-02: 8.5s threshold dual condition (HRPS willDieInSeconds OR healthMax <= (mateNearMyTargetCount+1) * estimatePlayerDPS * 8.5) with PvP exclusion checked BEFORE the lazy cache so a player-controlled target can never cache true"
  - "D-09/D-13: zero changes to shared decision functions (shouldUseShred/shouldUseBite/shouldCastRip) and catLeveling — all 7 modifications verified as additive-only via per-task git diff"
  - "Category P section header deliberately omits test-name substrings ('P: fast battle' etc.) so the 26-02 grep counts exactly the 6 test-name lines"

requirements-completed: [D-01, D-02, D-03, D-04, D-05, D-06, D-07, D-08, D-09, D-10, D-11, D-12]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "macroTorch.isFastBattleNotPvp (8.5s dual condition, PvP-first guard before lazy cache) in Druid.lua + cp5Bite 5CP fast-battle trigger in cat.lua (D-08)"
    requirement: D-01
    verification:
      - kind: other
        ref: "grep: function==1, 'localFastDieTime = 8.5'==1, or-clause in cat.lua==1; ./build.sh OK (Task 1 verify, re-run green at tracer gate)"
        status: pass
    human_judgment: true
    rationale: "Per-frame HRPS prediction and PvP-field behavior are only exercisable inside the WoW client; the 2 registered Category P SelfTests execute at in-game login, not in this environment"
  - id: D2
    description: "catAtk 6 call-site guards: Pounce skip + Rip wrapper + regularAttack precondition (combo.lua); keepRake guard + energyDischarge Rake fallback (cat.lua, alongside cp5Bite from D1)"
    requirement: D-03
    verification:
      - kind: other
        ref: "grep call-site counts (combo 3, cat 3, refs 10 across 3 files) + ./build.sh OK (Task 2/3 verifies + overall 8-point verification all green)"
        status: pass
    human_judgment: true
    rationale: "Combat-path behavior (prowling opener fallthrough to Ravage, per-frame fast/quick state switches) is only verifiable in a live game session"
  - id: D3
    description: "2 Category P SelfTest registrations (P-01 function existence, P-02 PvP exclusion + cache-ordering proof) with isOptional=true appended before Module 4"
    requirement: D-12
    verification:
      - kind: other
        ref: "grep -c 'P: isFastBattleNotPvp' core/selftest.lua == 2; ./build.sh OK"
        status: pass
    human_judgment: false

# Metrics
duration: 3min
completed: 2026-08-21
status: complete
---

# Phase 26 Plan 01: 猫德 fast 战斗逻辑 Summary

**isFastBattleNotPvp（8.5s 死亡预测 + 非 PvP）纯直伤策略正式落地：catAtk 在快速战斗中跳过 Pounce/Rake/Rip 全部流血，Shred/Claw 攒星到 5CP 直接 Bite，7 处守卫全部为可逆的追加式修改**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-08-21T15:59:11Z
- **Completed:** 2026-08-21T16:02:55Z
- **Tasks:** 3
- **Files modified:** 4
- **Diff size:** 5296 added chars ≈ 1324 estimateTokens units (chars/4) — plan estimated 42000；本计划实际为追加式 Lua 修改，估计偏高约 32x（供 ADR-2629 校准）

## Accomplishments

- `macroTorch.isFastBattleNotPvp(clickContext)` 新增于 Druid.lua（紧邻 isTrivialBattle）：PvP 排除（`isPlayerControlled` 检查先于惰性缓存）、8.5s 双条件（HRPS `willDieInSeconds(8.5)` 或血量估算 `healthMax ≤ 人数×DPS×8.5`）、clickContext 惰性缓存每帧重算（D-01/D-02/D-11）
- cp5Bite 5 星无条件触发 Bite：快速战斗中 Rip 不存在、目标不免疫流血，原守卫永远不满足（D-08）
- catAtk 主流程三处守卫（combo.lua）：Pounce 起手改为落到 Ravage 直伤（D-03）、Rip 策略模块整体包裹跳过（D-04）、regularAttack 脱离 Rake 依赖照常攒星（D-07）
- 流血泄漏两个旁路封死（cat.lua）：keepRake 守卫链追加快速战斗短路（D-05）、energyDischargeBeforeBite 禁止 Rake 泄能且保留 Shred/Claw 首分支（D-06）
- 2 个 Category P SelfTest（P-01 函数存在性、P-02 PvP 排除 + 缓存顺序证明），均 isOptional=true，附 `-- [CITED: 26-CONTEXT.md D-12]`（D-12 items 1-2 of 6，其余 4 个由 26-02 完成）
- 正常战斗等价性（D-09）与 catLeveling 完整性（D-13）通过 git diff 验证：所有新增均为追加条件或包裹 if，共享决策函数与练级宏零改动

## Task Commits

Each task was committed atomically:

1. **Task 1 (tracer): End-to-end fast battle path — isFastBattleNotPvp + cp5Bite 5CP trigger** — `6995638` (feat)
2. **Task 2 (auto): catAtk main flow — opener Pounce skip, Rip bypass, regularAttack precondition** — `1627c16` (feat)
3. **Task 3 (auto): Close remaining bleed leaks — keepRake guard + energyDischargeBeforeBite** — `3b76447` (feat)

**Tracer feedback gate:** Task 1 `<verify>` 重跑在 commit 后仍然全绿（grep 计数 + build），SM_Extend.lua 含新符号（11 处），随后展开 Task 2/3。

## Files Created/Modified
- `classes/druid/Druid.lua` — +21 行：新增 isFastBattleNotPvp（PvP-first guard + 8.5s 双条件惰性缓存），插入于 isTrivialBattle 与 combatUrgentHPRestore 之间
- `classes/druid/combo.lua` — 3 处守卫：Pounce 起手条件追加 `and not`（D-03）、Rip 分支整体包裹 `if not ... then`（D-04）、regularAttack 前置条件括号组内追加 `or`（D-07）
- `classes/druid/cat.lua` — 3 处守卫：cp5Bite 条件追加 `or`（D-08）、keepRake 守卫链末尾追加 `or`（D-05）、energyDischargeBeforeBite Rake 回退追加 `and not`（D-06）
- `core/selftest.lua` — Category P 段落（含 P-01/P-02 两个 isOptional=true 注册），位于 Category M 之后、Module 4 之前

## Decisions Made

- 完全遵循 26-CONTEXT.md 的 D-01 至 D-13，无偏离：阈值 8.5s、PvP 排除先于缓存、无防抖（D-10）、每帧独立判断（D-11）、共享函数与 catLeveling 零改动（D-09/D-13）
- 全局验证 8 项全部通过（build、6 call sites、10 处引用计数、等价性 diff 审计、无 anti-jitter、阈值唯一、仅 4 文件触及）
- 无新增依赖、无威胁面变化（纯客户端 Lua 启发式，STRIDE 注册表已覆盖）

## Deviations from Plan

Code execution: None — plan executed exactly as written (all 3 tasks, all per-task and overall verifies green; tracer gate re-run green post-commit).

### Doc-Alignment Fixes (planning-doc truth only, no code impact)

**1. [Docs] ROADMAP.md Phase 26 wave rows still said "Category O SelfTest"**
- **Found during:** Post-execution ROADMAP review
- **Issue:** Plan-checker revision ba4aca3 renamed the category to P in the plan files, but both Phase 26 wave lines in ROADMAP.md still referenced "Category O" (that is Phase 23's Idol Dance category in classes/druid/selftest.lua)
- **Fix:** Corrected both 26-01 and 26-02 wave lines to "Category P SelfTest"; Phase 23's Category O references left intact
- **Files modified:** .planning/ROADMAP.md

## Issues Encountered

- `gsd-tools query state.advance-plan` 报错 "Cannot parse Current Plan or Total Plans in Phase from STATE.md" — STATE.md 属旧格式（无 Current Plan 字段），改为手动更新 Phase Progress 表与 frontmatter 计数（处理细节见 Self-Check 之后的状态更新）
- `roadmap.update-plan-progress` 在 SUMMARY.md 落盘前会报告 summary_count=0，是在写完 SUMMARY.md 后重跑才正确勾选

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 26-02 可直接展开：剩余 4 个 Category P SelfTest（HRPS 路径、血量估算路径、fast⇒trivial 优先级、cp5Bite 回归）依赖本计划的 isFastBattleNotPvp 与 P-01/P-02 注册模式
- 无未解决 blocker；构建绿色

---
*Phase: 26-phase-fast*
*Completed: 2026-08-21*

## Self-Check: PASSED

- `FOUND: .planning/phases/26-phase-fast/26-01-SUMMARY.md` (existence check)
- `FOUND: 6995638` — Task 1 commit (feat(26-01): add isFastBattleNotPvp fast-battle judgment + cp5Bite 5CP trigger)
- `FOUND: 1627c16` — Task 2 commit (feat(26-01): arm catAtk for fast battles — Pounce skip, Rip bypass, regularAttack precondition)
- `FOUND: 3b76447` — Task 3 commit (feat(26-01): close remaining bleed leaks — keepRake guard + energyDischarge Rake fallback)
- Build gate: `./build.sh` exit 0 on every task and at overall verification (8/8 checks green)
- ROADMAP.md 26-01 wave line ticked `[x]`; SM_Extend.lua contains `function macroTorch.isFastBattleNotPvp` exactly once