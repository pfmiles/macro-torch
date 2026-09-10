---
phase: 29-landing
plan: "02"
subsystem: spell-trace
tags: [lua, wow-1.12, landing, inference, fallback, ttl]
requires:
  - phase: 29-landing
    provides: [29-01 unified OR evidence core: per-spell ttl + cast-dim dedup skeleton]
provides:
  - [inference fallback layer: maintainLandTables 0.1s cycle + computeLandTable windowed inference + (inferred) blue announce]
affects: [29-03 boundary cases, immune path-2 revival]
actuals:
  tokens: 2997
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [silent-window inference trigger, windowed fail veto reuse, (inferred) announce suffix]
key-files:
  created: []
  modified: [core/spell_trace_core.lua, classes/druid/selftest.lua]
key-decisions:
  - "None - followed plan as specified (DESIGN-CONTEXT 锁定决策 3/4 + D-03/D-04/D-13/D-14 逐条落地)"
requirements-completed: [D-03, D-04, D-13, D-14, D-16]
coverage:
  - deliverable: inference fallback layer (core/spell_trace_core.lua)
    verification:
      - bbcheck BALANCED; git diff --check clean
      - grep anchors: maintainLandTables/computeLandTable defs x1, registerPeriodicTask('maintainLandTables' x1, landIntentTtls read x2 (seed + inference), 'blip <= ttl' x1, 'lastLand >= lastCast' x2, 'lastFail[1] >= lastCast' x1, "'(inferred)', 'blue'" x1, 'landTable[spell][mob].push(lastCast)' x1
      - Lua 5.0 token gate 0; SM_Extend.lua byte-identical; events.lua + spell_trace_immune.lua zero diff
    status: pass
    human_judgment: false
  - deliverable: selftest pinning Q-09/Q-11/Q-13 (classes/druid/selftest.lua)
    verification:
      - bbcheck BALANCED; git diff --check clean
      - Q-09/Q-11/Q-13 test names x1 each; computeLandTable( x3; periodicTasks['maintainLandTables'] x1; '(inferred)' x2; plan summary 'Cat Q-1[13]:' x2
      - Lua 5.0 token gate 0; SM_Extend.lua byte-identical
    status: pass
    human_judgment: false
duration: 6min
completed: 2026-09-10
status: complete
---

# Phase 29 Plan 02: 反推兜底复活 Summary

反推兜底层完整复活：0.1s 周期任务 maintainLandTables 以 tracingSpells + inCombat 双门驱动 computeLandTable，全窗口静默（blip > ttl、未被覆盖、无窗内 fail）的 cast 在 ttl 到期后以 cast 时刻为锚推定 landed 并以蓝色 '(inferred)' 通告；窗口化 fail 否决（D-04）与 cast 维覆盖谓词（D-02 复用）构造性保证反推永不与游戏事件竞争，免疫路径 2 的 land 供给随之复活；Q-09/Q-11/Q-13 三注册将行为钉死（D-16 前两条 + 复活断言）。

## Performance
- **Duration:** 388s (~6 min)
- **Started:** 2026-09-10T02:43:17Z
- **Completed:** 2026-09-10T02:49:45Z
- **Tasks:** 2
- **Files modified:** 2
- **Estimate actuals:** 2997 tokens (chars/4 over the realized diff, +203/-7) vs estimate 32000; 2 tasks vs 2 estimated; 2 commits

## Accomplishments
- **maintainLandTables 复活 (D-03):** 守卫逐字照抄 archived 形态（tracingSpells 空集退出 + inCombat 双门），循环 per tracingSpells 条目驱动 computeLandTable；模块级注册 `registerPeriodicTask('maintainLandTables', { interval = 0.1, ... })`（键空闲已只读确认，无残留覆盖）。
- **computeLandTable 窗口化推断 (D-03/D-04):** 谓词序确定——no-cast 返回 → `blip <= ttl` 静默窗返回（触发边即 ttl，旧 0.02 下界/0.9 上界双常量被 ttl 取代，零新增魔法数字）→ `lastLand >= lastCast` 覆盖谓词（D-02 复用，真实证据/先前反推覆盖即退）→ 窗口化 fail 否决 `cast <= failTime <= cast + ttl`（D-04，替代旧 ±0.05s 邻接启发式）→ `push(lastCast)`（锚 = cast 时刻）→ 蓝色通告。
- **per-spell ttl 一参三用 (D-05):** `landIntentTtls[spell] or LAND_INTENT_TTL`——钉刺 2 / 猫德 0.9，与 pairLandIntent 配对窗、finalizeFail 否决窗同一语义。
- **通告观感 (D-13/D-14):** `{spell} cast on {mob} landed: {time} (inferred)`，蓝色——与 green 正推通道肉眼可辨；(inferred) 后缀供实机区分 apply 确认与反推兜底。
- **selftest 三注册:** Q-09 重写为复活断言（双函数 type + 周期任务键/interval 0.1/task 指向 + consumeDruidBattleEvents 仍为 nil）；Q-11 无证据反推（2.0s 旧 cast 静默窗 → top == 种植 cast 值、show 恰 1 次蓝色含 '(inferred)'）；Q-13 单注册两阶段（窗内 fail +0.5s 零通告零 land / 窗前 fail -0.1s 推断照发）。三段全部 CR-01 纪律、isOptional=true。
- **免疫路径 2 附带复活:** 无代码改动——spell_trace_immune.lua 的 0.1s 消费任务因 land 供给恢复而行为复位（VERIFICATION-ONLY 契约，git diff 零改动）。

## Task Commits
1. **Task 1: 反推兜底层复活** - `50544fd` feat (spell_trace_core.lua +64)
2. **Task 2: Q-09 复活断言 + Q-11/Q-13 双场景** - `90267cd` test (selftest.lua +139/-7)
**Plan metadata:** docs commit follows (SUMMARY + STATE + ROADMAP + REQUIREMENTS)

## Files Created/Modified
- `core/spell_trace_core.lua` - maintainLandTables 双门守卫 + 模块级 0.1s 周期注册 + computeLandTable 六步谓词链（守卫/懒初始化照抄 archived 形状，逻辑按 D-03/D-04 换新）
- `classes/druid/selftest.lua` - Q-09 原位重写 + Q-11/Q-13 追加于 Q-10 之后 + Category Q 头注释更新（序列 Q-01..Q-11 + Q-13，Q-12/Q-14..Q-16 待 29-03）

## Decisions Made
None - followed plan as specified（DESIGN-CONTEXT 锁定决策 3/4 + 29-CONTEXT D-03/D-04/D-13/D-14 逐条落地，无方向性偏差）。

## Deviations from Plan
None - plan executed exactly as written.（执行途中发生 3 处编辑笔误——跨行 return 错位、spspell 参数笔误、注释双破折号——均在提交前的 verify 执行前即时修正，未进入任何提交；不改行为、不触计划条款，不计入 deviation。SM_Extend.lua 全程字节等于 HEAD。）

**Total deviations:** 0 auto-fixed. **Impact:** 无——最终提交与计划条款逐字一致。

## Issues Encountered
None — 两任务 verify 全绿（bbcheck 2 文件 BALANCED；谓词锚 grep 全部命中备案值；拼接式 '(inferred)' 字面通过 ggrep 门；Lua 5.0 令牌门 0；git diff --check 干净；SM_Extend.lua 字节一致；events.lua/spell_trace_immune.lua 零 diff）。

## User Setup Required
None. 运行级验证按计划落在用户 Windows+Cygwin 机（/mt 自测 Q 全绿）与 29-03 HUMAN-UAT；本计划无本地 Lua 解释器、无 build 步骤、无 user_setup 段。

## Next Phase Readiness
- 反推层就绪且被三注册钉死：29-03 边界用例（Q-12/Q-14..Q-16：apply 后到同 cast 被拒、intentTtl 0.9/2 边界、续期豁免、远程迟到时序）与 HUMAN-UAT 可直接在此层上展开；Q-11/Q-13 的单注册双阶段夹具形态可作为 29-03 多阶段用例模板。
- 已知留意点（29-01 移交）：processRawAuraApply 内注释仍写 "<=2s land offset"（29-01 计划规定其函数体零改动），若 29-03 条款涵盖注释清理，届时处理——本计划未触碰该函数与 events/immune 两文件（VERIFICATION-ONLY 契约）。

## Self-Check: PASSED

---
*Phase: 29-landing*
*Completed: 2026-09-10*