---
phase: 29-landing
plan: "01"
subsystem: spell-trace
tags: [lua, wow-1.12, landing, dedup, intent-ttl]
requires: []
provides:
  - [unified OR evidence chain: register without landSource, intent.ttl threading, cast-dim dedup, renewal exemption]
affects: [29-02 inference fallback, 29-03 boundary cases]
actuals:
  tokens: 6430
  tasks: 3
  commits: 4
tech-stack:
  added: []
  patterns: [unified OR evidence channel, cast-dimension dedup predicate, recordLandEventRenewal exemption]
key-files:
  created: []
  modified: [core/spell_trace_core.lua, classes/druid/Druid.lua, classes/hunter/Hunter.lua, classes/druid/selftest.lua]
key-decisions:
  - "D-01 confirmed by user at execution checkpoint: landSource field + landSources registry + both dispatch gates removed per locked scope (option-a)"
requirements-completed: [D-01, D-02, D-04, D-05, D-06, D-07, D-08, D-09, D-10, D-11, D-12, D-15]
coverage:
  - deliverable: unified OR evidence core (spell_trace_core.lua)
    verification:
      - bbcheck BALANCED
      - structural greps (renewal def / TTL 0.9 / registry init / per-intent ttl falls x3 / dedup x1 / fail lower bound / pattern fill) all pass
      - landSources + landSource residuals 0; Lua 5.0 token gate 0; SM_Extend.lua byte-identical
    status: pass
    human_judgment: false
  - deliverable: class registration migration (Druid.lua + Hunter.lua)
    verification:
      - bbcheck both files BALANCED
      - recordLandEventRenewal x2 in Druid / plain recordLandEvent 0 / intentTtl = 2 x2 in Hunter / landSource residuals 0 / SM_Extend.lua byte-identical
      - token-gate grep prints 2 for Druid.lua: both are '#' glyphs inside HEAD-pre-existing comment text ('debug decision #3' / 'decision #4') that the plan instructs to preserve verbatim; no Lua 5.0 code token introduced
    status: pass
    human_judgment: true
    rationale: "Druid.lua token-gate grep counts 2 pre-existing comment glyphs (verified identical at HEAD before this plan); the plan's own 'Savagery 快照只读不写的注释原样保留' clause forbids rewording them, so the formal gate line count stays 2 while the actual constraint (no '#' length operator / no goto / no '::' in code) holds — no token added or removed by this plan"
  - deliverable: selftest Category Q baseline realignment (classes/druid/selftest.lua)
    verification:
      - bbcheck BALANCED
      - Q-01 new name x1 / castAt = 1000.0 x1 / landIntentTtls reads x12 (>= 6) / landSources lines x1 pinned to the negative assert / token gate 0 / SM_Extend.lua byte-identical
    status: pass
    human_judgment: false
duration: 10min
completed: 2026-09-10
status: complete
---

# Phase 29 Plan 01: 统一 OR 证据链核心 Summary

统一 OR 正推证据链落地：register 去 landSource/landSources 并新增 landIntentTtls 注册表与自然属性 pattern 驱动，intent.ttl 贯通配对/否决双窗（fail 否决加上界下界），recordLandEvent 内置 cast 维去重谓词，FB 续期经独立豁免入口直推新锚，selftest Q-01/Q-02 基线重对齐到 0.9 默认窗。

## Performance
- **Duration:** 572s (~10 min)
- **Started:** 2026-09-10T02:27:38Z
- **Completed:** 2026-09-10T02:37:10Z
- **Tasks:** 3 (+tracer gate; Task 1 checkpoint:decision was resolved by the user as option-a, no code)
- **Files modified:** 4
- **Estimate actuals:** 6430 tokens (chars/4 over the realized diff) vs estimate 48000; 3 tasks vs 3 estimated; 4 commits

## Accomplishments
- **register 新形态 (D-01/D-09):** landSource 字段写入、模块级 landSources 注册表、onSelfDamageLine 来源早退三门三处全删；新增模块级 per-spell ttl 注册表 `macroTorch.landIntentTtls`（nil-guard init 照抄相邻 tracingSpells 形状）；auraApplySpellPatterns 填充改由自然属性驱动（`config.immune and config.debuffTexture`），落点集 Pounce/Rip/Rake + 双钉刺，FF 不入；pattern 拼接前有 find-pattern 元字符守卫（命中红字告警并跳过本名 pattern，tracing/ttl 注册照常）。
- **intent.ttl 贯通三窗 (D-05/D-07/D-10):** `LAND_INTENT_TTL = 0.9`（注释改为默认证据接收窗 + cpDamage 继续引用 D-17）；recordCastTable 播种 `ttl = landIntentTtls[spell] or LAND_INTENT_TTL`；pairLandIntent purge/pair 两趟改读 `intent.ttl or LAND_INTENT_TTL`；cpDamage 五函数零改动（pairCpDamageIntent 仍引用全局常量）。
- **fail 否决窗口化 (D-04/D-06):** finalizeFail 消费条件 = `intent.state pending/landed` + `0 <= failTime - castAt <= intent.ttl`；负差容差注释块整段替换为窗口化措辞；revoke 机器（removeMatch + 红字取消行）逐字保留，fail-wins 不变。
- **cast 维去重 + 续期豁免 (D-02/D-11):** recordLandEvent 在 lazy-init 之后 push 之前插入 `lastCast and lastLand and lastLand >= lastCast then return`；谓词仅在 lastCast 存在时生效（Q-07/Q-10 无 cast 夹具不受伤）；新增 `recordLandEventRenewal(spell, landTime)` 守卫/shape/push/派发与 recordLandEvent 逐字同构、唯无去重谓词。
- **职业注册点迁移 (D-08/D-12):** Druid Pounce/Rip 删 landSource，Rake 注释说明 apply 行新入统一通道（有意多一条）；Hunter 双钉刺删 landSource 并显式 `intentTtl = 2`（弹道飞行窗）；FB 续期监听器 847/854 两处改走豁免入口，isRakePresent/isRipPresent 前置条件原样；FF register 块零改动。
- **selftest 基线重对齐 (D-15):** Q-01 重写为统一 OR 断言（旧注册表 nil / 六 tracingSpells 项 / LAND_INTENT_TTL == 0.9 / 六项 per-spell ttl 取值 / 三 apply pattern 存在且 FF 缺席）；Q-02 种植 castAt 999.0 → 1000.0（0.5s <= 0.9 窗）；Q-03..Q-08/Q-10 逐差复核全部保持绿色；Category Q 头注释去除已删表名、预告 Q-11..Q-16 由 29-02/29-03 挂入。

## Task Commits
1. **Task 1 (tracer): 统一 OR 证据链核心** — `9f5952f` feat (spell_trace_core.lua 全链改动；tracer gate: verify 重跑全绿后展开)
2. **Task 2: 职业注册点迁移** — `62792a9` feat (Druid.lua + Hunter.lua)
3. **Task 3: selftest 基线重对齐** — `d010419` test (selftest.lua)
**Plan metadata:** docs commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS) follows this file.

## Files Created/Modified
- `core/spell_trace_core.lua` — 常量 0.9、landIntentTtls 注册表、register 新形态与 pattern 守卫、intent.ttl 播种、pair/否决三窗读 ttl、recordLandEvent 去重谓词、recordLandEventRenewal 豁免入口、self-hit 门拆除（+97/-47）
- `classes/druid/Druid.lua` — Pounce/Rip 删 landSource + 四技能注释统一 OR 语义 + FB 续期改豁免入口 + 监听器头注释补豁免说明（+27/-15）
- `classes/hunter/Hunter.lua` — 双钉刺删 landSource + intentTtl = 2 + 弹道窗注释（+13/-5）
- `classes/druid/selftest.lua` — Q-01 重写 + Q-02 种植值 + Category Q 头注释 + U-05 stale 2s 消息（+48/-20）

## Decisions Made
- D-01 confirmed by user at execution checkpoint: landSource field + macroTorch.landSources registry + both dispatch gates removed per locked scope (option-a 按锁定范围删除).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] U-05 断言消息携带因 D-10 失效的 2s 字样**
- **Found during:** Task 3（窗口值复核：Q-03..Q-08/Q-10 之外扫描到 U-05）
- **Issue:** `"U-05 expected nil beyond the 2s LAND_INTENT_TTL window"` 中的 "2s" 因 LAND_INTENT_TTL 2→0.9 直接失效（断言语义 4.0 > 0.9 仍成立，仅消息字面过时）
- **Fix:** 消息改为 "beyond the LAND_INTENT_TTL window"，断言不改
- **Files modified:** classes/druid/selftest.lua
- **Commit:** d010419

**2. [Task-2 token gate 假阳性 — 计划门假设偏差] see 覆盖块 rationale；无需修复（修复将违反计划第 5 条"注释原样保留"）**
- **Found during:** Task 2 verify
- **Issue:** `grep -cn '#\|goto \|::'` 对 Druid.lua 输出 2 —— 两行均为 HEAD 既有注释内的 '#' 编号字形（'debug decision #3' / 'decision #4'），非代码长度运算符；HEAD 原始文件即命中 2（本计划 0 新增令牌）
- **Fix:** 不修（计划 Task 2 第 5 条要求 Savagery 快照注释原样保留；scope boundary —— 不触碰非本任务引入的既有内容），按门协议记 deviation
- **Files modified:** 无
- **Verification:** `git show HEAD:classes/druid/Druid.lua | grep -n '#\|goto \|::'` = 2（与现文件逐行一致，仅行号随插入平移）

**Total deviations:** 2 auto-documented. **Impact:** 一个消息字面修正（行为零变化）；一个计划门假阳性（无代码令牌引入，real syntax constraint 满足）。

## Issues Encountered
None — all three task verifies green (bbcheck 4 files BALANCED; structural greps; residual scans; token gates; SM_Extend.lua byte-identical to HEAD), tracer gate passed before expansion.

## User Setup Required
None. Runtime verification per plan stays on the user Windows+Cygwin machine (/mt self-test Q-01..Q-10) and the 29-03 HUMAN-UAT protocol; this plan carries no local Lua interpreter and no build step (SM_Extend.lua untouched for every commit).

## Next Phase Readiness
- ttl/去重/豁免骨架就绪：29-02 反推兜底（maintainLandTables/computeLandTable 复活）直接外扩到 `landIntentTtls` + `intent.ttl` + cast 谓词上；D-04 与 29-02 共享（REQUIREMENTS 侧待 29-02 完成后才勾）。
- 已知留意点：processRawAuraApply 内注释仍写 "<=2s land offset"（计划规定其函数体零改动，留给 29-02 的注释清理条款处理）。
- Hunter/Druid 注册点已与 register 新形态对齐，29-03 六组边界用例（Q-11..Q-16）夹具可直接复用 Q-02 种子形态与豁免入口。

## Self-Check: PASSED

---
*Phase: 29-landing*
*Completed: 2026-09-10*