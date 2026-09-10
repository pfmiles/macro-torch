---
phase: 29-landing
plan: "04"
subsystem: spell-trace
tags: [lua, wow-1.12, landing, rendering, hue-mapping, uat-gap-closure, selftest]
requires:
  - phase: 29-landing
    provides: [29-02 (inferred) blue announce layer, 29-03 UAT protocol + HUMAN-UAT color contract]
provides:
  - [G-29-3 gap closure: D-14-correct hue arms in macroTorch.show, Cat T-02 real-show render-hue regression]
affects: [user-side /mt self-check, Windows+Cygwin rebuild, verify-work 29-UAT backfill]
actuals:
  tokens: 1291
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [hue-dominant arm literals, downstream-only fixture planting (real show under test)]
key-files:
  created: []
  modified: [interface_debug.lua, classes/druid/selftest.lua]
key-decisions:
  - "None - followed plan as specified (G-29-3 root cause fixed at the render layer per D-14; T-02 drives the real macroTorch.show with planted downstream fixtures only)"
requirements-completed: [D-14]
coverage:
  - id: D1
    description: "macroTorch.show blue/green hue arms corrected to the D-14 protocol (blue = inferred blue-dominant, green = landed green-dominant), OFFICER key reference cleared from interface_debug.lua"
    requirement: D-14
    verification:
      - kind: other
        ref: "grep gates: custom_blue x1 / pure-green literal x1 / Color-label contract x1 / OFFICER x0 / SAY-YELL-SYSTEM-AddMessage x1 each"
        status: pass
      - kind: other
        ref: "bbcheck interface_debug.lua BALANCED + git diff --check clean + Lua 5.0 token gate 0 + CRLF 0 + new-comment CJK 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cat T-02 regression driving the real macroTorch.show mapping with planted DEFAULT_CHAT_FRAME capture stub + vanilla-shaped ChatTypeInfo, asserting hue dominance of all five arms (default/red/yellow/blue/green) after CR-01 restore"
    requirement: D-14
    verification:
      - kind: other
        ref: "static battery: registration name x1 / Cat T- x2 / planted_say x2 / blue-green-red-dominant x1 each / Category T.*2 tests x2 / token-CRLF-CJK-word gates 0"
        status: pass
      - kind: other
        ref: "bbcheck selftest.lua BALANCED + SM_Extend.lua byte-identical to HEAD"
        status: pass
    human_judgment: true
    rationale: "the behavioral pass/fail of T-02 executes only in-game via /mt on the user's Windows+Cygwin client (no local Lua interpreter on this host); the static battery proves the assertion block is in place and syntax-clean, but only the live run proves the five arms render green/blue — tracked as unrun-verify (WINDOWS.md entry 7) and backfilled into 29-UAT.md by verify-work"
duration: 5min
completed: 2026-09-11
status: complete
---

# Phase 29 Plan 04: G-29-3 gap closure Summary

**G-29-3 gap closure: `macroTorch.show` 的 blue/green 两臂色相修正到 D-14 协议（blue = inferred 渲蓝、green = landed 渲绿，OFFICER 键引用清零），并以 Category T-02 回归自测驱动真实 show() 映射表——五臂色相主导断言使任何将来臂颠倒必红/黄，渲染层零覆盖的历史终态闭环。**

## Performance
- **Duration:** 5 min
- **Started:** 2026-09-10T18:57:26Z
- **Completed:** 2026-09-11 (UTC 2026-09-10T19:02Z)
- **Tasks:** 2
- **Files modified:** 2 (计划变更面恰 2 个预期文件)
- **Estimate actuals:** 1291 tokens (chars/4 over the realized diff 403116d~1..HEAD, +57/-4) vs estimate 22000; 2 tasks vs 2 estimated; 2 task commits + 1 plan metadata commit

## Accomplishments
- **G-29-3 root_cause 直接修复 (missing 第 1 条):** `macroTorch.show` 蓝臂 'blue'→OFFICER 频道键（1.12 客户端实渲绿色，倒置源）改复用已验证渲蓝的自定义 RGB `{ r = 0, g = 0.5, b = 0.9, id = 'custom_blue' }`；绿臂 'green'→原蓝通道主导的 `{ r = 0, g = 0.5, b = 0.9, id = 'custom_green' }` 改为纯绿 `{ r = 0, g = 1, b = 0, id = 'custom_green' }`。函数签名、SAY 缺省臂、red→YELL/yellow→SYSTEM 臂、AddMessage 出口行、log() 转发表全部字节不变——共享渲染通路（spell_trace_core.lua:451/499/598 通告、macroTorch.log、diag、Target）随修复整体归位。
- **契约注释（D-14）:** function 上一行新增三行英文注释块（Color-label contract: green = landed, blue = inferred；每臂为 hue-dominant 字面量，防未来静默颠倒），无 OFFICER 字样、零 CJK。
- **Category T-02 渲染映射回归 (missing 第 2 条):** 区别于 Q 系列整体 stub 掉 show 的写法，T-02 只种植 show 的两个下游依赖（DEFAULT_CHAT_FRAME 捕获桩 + 拟态 vanilla 逐键独一 id 的 ChatTypeInfo），映射表本体照真执行；pcall 内按序调用五臂（缺省/red/yellow/blue/green），CR-01 恢复先于六条断言——缺省臂 = planted_say、red 臂 red-dominant、yellow 臂 must stay warm、blue 臂 blue-dominant、green 臂 green-dominant。任务 1 修复后全绿；任臂将来改回颠倒 T-02 必红/黄。Category T 两处计数注释更新为 2 tests（终态 `SelfTest:register("Cat T-` 恰 2 处）。
- **静态电池全绿:** bbcheck 两文件 BALANCED；git diff --check 干净；Lua 5.0 令牌门两文件 0（代码行口径，全行注释豁免——interface_debug.lua:17 中文头部注释为既存字节）；CRLF 0；diff 新增注释零 CJK、不含 [a-z] 词元行 0；SM_Extend.lua 全程零 diff；Category Q 16 条注册零改动、core/ 零改动、spell_trace_core.lua 调用点零改动。

### 横向影响评估（计划 Task 1 第 5 条，抄录）
全仓唯一 ChatTypeInfo 与 custom_green 引用面即本函数（grep 已证）；绿臂消费者 = spell_trace_core.lua:499/:598 直接 landed、Target.lua:65、diag.lua 十余处、macroTorch.log 链路——全部走同一 arm，修复后统一变真绿，正是协议期望；无任何文件依赖旧 OFFICER 臂或旧蓝调字面量。red/yellow 臂不在本次缺陷范围且用户已确认正常，保持不动。OFFICER 字面量现仅存在于 T-02 的种植夹具（selftest.lua，拟态 vanilla 色相，供未来修复变体兼容预留）。

### 语言工具可行性结论（计划 Task 2 开头，抄录）
本机无 Lua 解释器（仅 node），色相行为断言无法在本机执行；已有工具链（bbcheck.balanced、Lua 5.0 令牌门、字面量 grep 门、CRLF/CJK/word 门）静态验证语法与断言在位，行为级验证落在游戏内 /mt（本任务交付的 T-02）与用户下一次实机重建。

## Task Commits
1. **Task 1: 修正 macroTorch.show 绿/蓝两臂色相** — `403116d` fix (interface_debug.lua +5/-2)
2. **Task 2: Category T-02 渲染映射回归自测** — `6bd0015` test (classes/druid/selftest.lua +52/-2)
**Plan metadata:** docs commit (SUMMARY + STATE + ROADMAP + REQUIREMENTS + WINDOWS ledger) follows this file.

## Files Created/Modified
- `interface_debug.lua` - blue 臂改 `{ r = 0, g = 0.5, b = 0.9, id = 'custom_blue' }`、green 臂改 `{ r = 0, g = 1, b = 0, id = 'custom_green' }`、function 上一行新增三行 Color-label contract 注释块；其余全部字节不变
- `classes/druid/selftest.lua` - Category T-02 注册（真实 show() 五臂色相断言 + CR-01 快照/恢复 + pcall 隔离、isOptional=true）+ 两处 Category T 计数注释更新为 2 tests

## Decisions Made
None - followed plan as specified（G-29-3 root_cause 渲染层修复 + T-02 映射层回归，D-14 颜色契约逐字落地，无方向性偏差）。

## Deviations from Plan
None - plan executed exactly as written. 两任务 verify 门全部按计划公式原样执行并命中备案值（Task 1：两臂上下文/字面量计数/OFFICER 清零/三臂与出口行原文/bbcheck/令牌/CRLF/CJK/SM_Extend 零 diff；Task 2：注册名与 Cat T 计数/planted_say 与三主导报文计数/Category T.*2 tests/双文件令牌与 CRLF/新增注释 CJK 与 wordless 门/SM_Extend 零 diff）。注释块按计划"function 上一行插入"落在 `---@param a any` 与函数签名之间，未触碰任何既存注释字节。无 Rule 1-4 触发。

**Total deviations:** 0. **Impact:** 无——两个提交与计划条款逐字一致。

## Issues Encountered
None。唯一环境性事实（已抄录上文）：本机无 Lua 解释器，T-02 的行为级绿/红只能由游戏内 /mt 判定（属于交付设计而非执行问题，已入 WINDOWS.md 条目 7 unrun-verify）。

## User Setup Required
None - 无外部服务配置。运行级复验按计划落在用户 Windows+Cygwin 机：rebuild 后单人木桩观察 rake/bite landed 行渲绿、pounce/rip (inferred) 行渲蓝、无红（HUMAN-UAT §3），/mt 自检 Category T-02 通过——由 verify-work 会话将结果回写 `29-UAT.md`（G-29-3 gap 关闭）。

## Next Phase Readiness
- G-29-3 缺口机器侧闭环：渲染表双臂与 D-14 协议一致（静态可判，本机已验证全部证据），映射层从此有行为断言钉死（颠倒即红）。
- Phase 29 至此 4/4 计划完成（29-01/02/03 + 29-04 gap closure），源码面干净：SM_Extend.lua 待用户侧重建携带修复；29-UAT.md 的 G-29-3 状态由后续实机验证回写翻绿。
- 遗留台账：WINDOWS.md 条目 7（T-02 in-game unrun-verify，open）与条目 5（Druid.lua 既有 '#' 注释字形，open）延续至 ship 门。

## Self-Check: PASSED

---
*Phase: 29-landing*
*Completed: 2026-09-11*