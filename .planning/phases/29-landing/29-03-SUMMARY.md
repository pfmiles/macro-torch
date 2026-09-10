---
phase: 29-landing
plan: "03"
subsystem: spell-trace
tags: [lua, wow-1.12, landing, boundary-cases, uat, static-battery]
requires:
  - phase: 29-landing
    provides: [29-01 unified OR core, 29-02 inference fallback]
provides:
  - [Q-12/Q-14/Q-15/Q-16 boundary behavior assertions, HUMAN-UAT.md live-test protocol, full-phase static battery]
affects: [user-side /mt self-check, Windows+Cygwin rebuild, verify-work]
actuals:
  tokens: 3620
  tasks: 3
  commits: 2
tech-stack:
  added: []
  patterns: [CR-01 fixture discipline, full-phase static battery]
key-files:
  created: []
  modified: [classes/druid/selftest.lua, classes/druid/HUMAN-UAT.md]
key-decisions:
  - "None - followed plan as specified (D-16/D-17/D-18 per DESIGN-CONTEXT locked decisions and 29-CONTEXT, no directional deviation)"
requirements-completed: [D-16, D-17, D-18]
coverage:
  - deliverable: D-16 boundary-case fixtures Q-12/Q-14/Q-15/Q-16 (classes/druid/selftest.lua)
    verification:
      - bbcheck BALANCED; git diff --check clean
      - four test names x1 each; recordLandEventRenewal( x1; push({ state = 'pending', castAt = 999.0 x3; SelfTest:register("Cat Q- x16
      - Lua 5.0 token gate 0 on selftest.lua; SM_Extend.lua byte-identical
    status: pass
    human_judgment: false
  - deliverable: Phase 29 live-machine UAT protocol (classes/druid/HUMAN-UAT.md)
    verification:
      - git diff --check clean; "## Phase 29: 统一 landing 判定重构" x1; anchorBias x1 (D-18 note)
      - forensics todo find = 0 (no-op); rawdiag scan core/+classes/ = 1 (semantic-load comment only); stale rawdiag2Enabled reminder line removed
      - SM_Extend.lua byte-identical
    status: pass
    human_judgment: true
    rationale: "the protocol document itself is machine-verified, but its acceptance value realizes only through the user's live-machine run on the Windows+Cygwin rebuild — by design this rides human_verify_mode=end-of-phase into the verifier's 29-UAT.md aggregation"
  - deliverable: full-phase static closing battery (Task 3, no file changes)
    verification:
      - bbcheck 4 files BALANCED; git diff --check clean; landSource residual scan empty (Q-01 exemption); events.lua + spell_trace_immune.lua zero diff
      - cpDamage zero diff; LAND_INTENT_TTL x10 (9 code + 1 comment, gate allows); Hunter intentTtl = 2 x2; renewal/maintain/compute function defs x3; Cat Q = 16
      - CRLF scan 5 files empty; comment CJK gate 0; comment wordless-lines gate 0 (both on empty plan-literal diff and on the cumulative phase range f39c667..HEAD)
      - SM_Extend.lua byte-identical to HEAD across all three plans
    status: pass
    human_judgment: true
    rationale: "one battery gate reports the known pre-existing condition: the Lua 5.0 token-gate grep prints 2 for classes/druid/Druid.lua — both are '#' glyphs inside HEAD-pre-existing comment text ('debug decision #3' / 'decision #4', verified identical at f39c667) that 29-01's verbatim-preserve clause forbids rewording; already recorded as WINDOWS.md ledger entry 5, no Lua 5.0 code token introduced by any phase-29 plan"
duration: 9min
completed: 2026-09-10
status: complete
---

# Phase 29 Plan 03: 边界用例+UAT+静态电池 Summary

D-16 六组边界用例全部落地（Category Q 序列 Q-01..Q-16 共 16 条注册）+ Phase 29 实机 UAT 协议六节入档（含 D-18 锚偏差锁定注记与 D-17 cpDamage 零改动声明）+ 全阶段 10 项静态收尾电池全绿（唯一门异常 = Druid.lua 两个既有注释 '#' 字形，已入账既有物）。

## Performance
- **Duration:** 573s (~9 min)
- **Started:** 2026-09-10T02:58:47Z
- **Completed:** 2026-09-10T03:08:20Z
- **Tasks:** 3 (Task 3 = verification-only battery, no diff)
- **Files modified:** 2
- **Estimate actuals:** 3620 tokens (chars/4 over the 29-03 diff span 51304cd..HEAD) vs estimate 30000; 3 tasks vs 3 estimated; 2 commits

## Accomplishments
- **Q-12 去重拒后到 (D-16 组 2):** 种植 seedCast = 5.0 + pending intent（ttl = 0.9）；`processRawAuraApply` 5.1 配对并落第一条 land 后，第二通道 `recordLandEvent('Rip', 5.4)` 被 cast 维谓词（lastLand 5.1 >= lastCast 5.0）丢弃——top 保持 5.1、size == 1。注册插入其编号语义位（Q-11 与 Q-13 之间），Category Q 文件顺序按数字排列。
- **Q-14 ttl 双边界 (D-16 组 4):** 不种 cast/land 表，纯驱动 `pairLandIntent`——同 1.5s 差分下 Serpent（ttl 2）配对成功落地 1000.5、Rake（ttl 0.9）被 purge 为 expired 且返回 nil。
- **Q-15 续期豁免 (D-16 组 5):** 普通入口 5.6 被拒（5.3 >= 5.0 覆盖该 cast），`recordLandEventRenewal` 豁免入口直推新锚——top == 5.6、size == 2（5.3 保留 + 5.6 新锚）。
- **Q-16 远程迟到 (D-16 组 6):** 不种 castTable（同时验证无 cast 记录时去重谓词不拦截）——1.0s 迟到 apply 超出 0.9 默认但落在 2s 钉刺弹道窗内：intent landed、landTop == 1000.0。
- **Category Q 头注释:** 更新为 Q-01..Q-16 全序列 16 项覆盖总述（统一注册/配对/拒外来/过期/fail 终局/迟配对拦截/pairing-free/监听器/复活断言/续期时间/无证据反推/去重拒后到/否决窗/ttl 边界/续期豁免/远程迟到）。
- **HUMAN-UAT.md Phase 29 节:** 六节可勾选协议（Prerequisites：Windows+Cygwin rebuild + SuperWoW；Pre-Test：/mt Category Q 16 全绿 + CONFIG_OPTIONS 4 项；单人木桩；多猫同目标选做；猎人钉刺 2s 窗；Troubleshooting a/b/c 三支路）；末尾 D-17 注记（cpDamage 零结构改动、窗随 LAND_INTENT_TTL = 0.9 自动生效）+ D-18 锁定注记（远程推断锚偏早一个飞行时间为最终形态、不做 anchorBias）。
- **关闭项收口:** 取证 todo `druid-rip-land-forensics-next-cd*` 搜索 = 0（规划期已随 7bd08c3 关闭，本计划确认 no-op）；陈旧插桩注释扫描——删除 HUMAN-UAT.md 旧第 206 行 `rawdiag2Enabled` 勿同开提醒（其前提开关已随 quick 260909-w3r 移除），扫描收口到恰 1 处（spell_trace_core.lua 的语义负载注释 "Plain show() — not a DIAG/RAWDIAG marker"）。
- **Task 3 全阶段静态电池:** bbcheck 4 文件 BALANCED；来源注册残留扫描空（豁免 Q-01 阴性断言后）；VERIFICATION-ONLY 两文件零 diff；cpDamage 段 zero-diff；LAND_INTENT_TTL 引用 10（9 代码 + 1 注释，门允许）；Hunter intentTtl = 2 两处 + 常量定义 1 处 + 三函数定义各 1；Cat Q = 16；CRLF 扫描 5 文件空；diff 新增注释 CJK 0 / 缺英文词元 0（计划字面门与累计 phase 范围 f39c667..HEAD 双跑）；SM_Extend.lua 全程字节等于 HEAD。

## Task Commits
1. **Task 1: D-16 边界用例后半程 Q-12/Q-14/Q-15/Q-16** — `9efc645` test (selftest.lua +155/-2)
2. **Task 2: Phase 29 UAT 协议 + 关闭项清点** — `575db45` docs (HUMAN-UAT.md +49/-2)
3. **Task 3: 全阶段静态电池** — 无 diff（纯验证任务，全部门绿，无提交）
**Plan metadata:** docs commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS) follows this file.

## Files Created/Modified
- `classes/druid/selftest.lua` - Q-12 插入 Q-11 后（编号语义位）+ Q-14/Q-15/Q-16 追加于 Q-13 后；Category Q 头注释 16 项覆盖总述；四条注册全部 CR-01 纪律、isOptional=true、英文注释
- `classes/druid/HUMAN-UAT.md` - 新增「Phase 29: 统一 landing 判定重构 -- 实机 UAT 闭环」六节协议；删除失效的 rawdiag2Enabled 勿同开提醒行

## Decisions Made
None - followed plan as specified（DESIGN-CONTEXT 8 条锁定决策 + 29-CONTEXT D-16/D-17/D-18 逐条落地，无方向性偏差）。

## Deviations from Plan

### Documented Gate Excursions (no fix applied)

**1. [电池令牌门既有命中 — 计划门假阳性] Druid.lua token gate 输出 2**
- **Found during:** Task 3 电池 B2（Lua 5.0 令牌门 4 文件）
- **Issue:** `grep -cn '#\|goto \|::' classes/druid/Druid.lua` = 2 —— 两处均为 HEAD 既有注释内 '#' 编号字形（`git show f39c667:classes/druid/Druid.lua` 证实 phase 29 开始前即存在，逐字保留条款），非代码长度运算符；其余三文件 0
- **Fix:** 不修（29-01 的 verbatim-preserve 条款 + scope boundary——本计划 files 不含 Druid.lua；修复即违约）。已入账 WINDOWS.md ledger entry 5（29-01 记录，open）
- **Files modified:** 无
- **Verification:** 四文件中 spell_trace_core/Hunter/selftest 均 0；Druid.lua 2 处与 f39c667 原文件逐字一致

**2. [电池变更面执行形态差异] Task 3 时 diff --stat HEAD 为空**
- **Found during:** Task 3 电池 B9（变更面清点）
- **Issue:** 计划按"5 个预期文件"写 `git diff --stat HEAD`；实际每任务原子提交后工作树已净，电池时 diff 为空
- **Fix:** 不修（执行形态使然）；以累计面复核替代——phase 29 生产面自 4ee2315..HEAD 恰为 5 个预期文件（spell_trace_core/Druid/Hunter/selftest + HUMAN-UAT.md）+ 1 个已关闭取证 todo 删除（48 行，29-CONTEXT Folded Todos 规定）；29-PATTERNS.md/29-CONTEXT.md/DESIGN-CONTEXT.md 均处于 git 跟踪态（无未跟踪残留）
- **Files modified:** 无

**Total deviations:** 2 documented (no auto-fix targets). **Impact:** 一个既有门假阳性（无代码令牌引入，real syntax constraint 满足）；一个执行形态说明（变更面与预期一致，核对方式替代）。

## Issues Encountered
None — 三任务 verify 全绿（Task 1：bbcheck + 4 名称 grep + renewal/999.0/Q-16 计数 + 令牌 0 + SM_Extend 干净；Task 2：标题/anchorBias 计数 + todo find 0 + rawdiag 收口 1 + diff --check；Task 3：10 项电池含 LF/注释语言门与字节一致），唯一门参数为上表已入账既有物。

## User Setup Required
None. 运行级验证按计划落在用户 Windows+Cygwin 机——HUMAN-UAT.md Phase 29 节六节清单即实机验收协议（rebuild SM_EXTEND.lua → /mt Category Q 16 全绿 → 单人木桩/多猫/猎人钉刺观察 → Troubleshooting 三支路），end-of-phase human-verify 由 verifier 汇入 29-UAT.md；本计划无本地 Lua 解释器、无 build 步骤。

## Next Phase Readiness
Phase complete, ready for next step — Phase 29 三个计划全部完成：统一 OR 核心（29-01）、反推兜底复活（29-02）、16 条 Category Q 行为钉 + UAT 协议 + 全阶段电池（29-03）。源码面全部落地并干净（来源注册残留零、VERIFICATION-ONLY 零 diff、cpDamage 零结构改动、SM_Extend.lua 字节一致待用户侧重建），等待 orchestrator 阶段验证（gsd-verifier 汇聚 HUMAN-UAT 实机结果）。

## Self-Check: PASSED

---
*Phase: 29-landing*
*Completed: 2026-09-10*