---phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
plan: "04"
subsystem: instrumentation
tags: [lua-5.0, uat, verification-battery, r8-audit, user-machine-handoff]

# Dependency graph
requires:
  - plan: "28-02"
    provides: "three-skill cpDamage hooks + Category U x9 with the interop literals (cpDamageSample x4 / cpDamageCast x4 anchors)"
  - plan: "28-03"
    provides: "complete tools/cpdamage.lua analyzer with --selftest battery and --json-out archive (the UAT command surface)"
  - phase: 27-catatk-event-driven-land-tracing-refactor
    provides: "bbcheck.js bracket gate + the pairLandIntent symbol the coexistence assertion pins"
provides:
  - "classes/druid/HUMAN-UAT.md Phase 28 section: 6-section user-machine acceptance script (prerequisites / selftest pre-check / SV toc declaration check / dummy protocol / analyzer run / troubleshooting) covering both 28-VALIDATION.md Manual-Only rows"
  - "Phase-28 closing battery green: 8-file bbcheck, build.sh, 6 product-count assertions, Phase 27 pairLandIntent coexistence, R8 9-symbol presence, R7 zero-path audit (build manifest + analyzer + 8-commit window), diff --check"
  - "Stale R8 acceptance anchor corrected in REQUIREMENTS.md (canDoReshift -> shouldDoReshift) — the battery's verbatim copy tripped on the docs commit 10db348 mis-transcription"
affects: ["verifier phase gate (28-UAT.md human-check folding), future phases reusing the R8 acceptance grep"]

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 1377    # 5508 diff chars / 4 over the realized diff (HUMAN-UAT.md + REQUIREMENTS.md)
  tasks: 2
  commits: 2      # 2 task commits; 1 additional plan-metadata commit

# Tech tracking
tech-stack:
  added: []
  patterns: ["R8 nine-symbol presence asserted against the actual source symbol names (shouldDoReshift, not the stale canDoReshift)", "UAT section structure mirrors the file convention: metadata block + Prerequisites + Pre-Test + numbered protocol sections + - [ ] checkboxes"]

key-files:
  created: []
  modified: ["classes/druid/HUMAN-UAT.md", ".planning/REQUIREMENTS.md"]

key-decisions:
  - "R8 anchor corrected to the real symbol name (shouldDoReshift) rather than renaming the code symbol: canDoReshift exists in no tracked source since the phase-04 refactor, and the rename would touch decision files (cat.lua) that carry a zero-change prohibition plus break R2-01..R2-07 selftest call sites"
  - "Phase 28 UAT section written in Chinese per the plan's explicit directive; the file's legacy Phase 06 content is English-only (the plan's 'existing Chinese convention' premise was inaccurate) — structure convention mirrored, command lines and identifiers kept verbatim"
  - "human-check items (toc confirmation / two-interpreter --selftest / dummy session / analyzer run) are handed to the verifier as end-of-phase UAT, not mid-plan checkpoints (human_verify_mode=end-of-phase, per plan objective)"

patterns-established:
  - "closing battery = verbatim plan verify one-liner with BATTERY_FAIL echo; a failing anchor is diagnosed by splitting into numbered assertions (A1..A10) before any fix"

requirements-completed: [D-10, D-14, D-15, D-16, R7, R8]

# Coverage metadata (#1602) — one entry per shipped deliverable.
coverage:
  - id: D1
    description: "HUMAN-UAT.md Phase 28 section — 6-section user-machine acceptance script covering both 28-VALIDATION.md Manual-Only rows (dummy closed loop + SuperMacro toc variant confirmation) with T-28-05 same-switch warning and D-06/D-10/D-11 presets"
    requirement: "D-14"
    verification:
      - kind: other
        ref: "git diff --check + grep -c 'cpdamage.lua --selftest' == 1 + grep -c 'MACRO_TORCH_LOG' == 3 + grep -c 'cpDamageLog=true' == 1 (all non-zero per plan)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase-28 closing verification battery — 8-file bbcheck BALANCED, build.sh exit 0, product counts (cpDamage fn set == 5, Cat U == 9, sample/cast == 4 each), pairLandIntent == 1, R8 nine symbols >= 9, build manifest zero-path audit (tools entry == 0, analyzer symbol in product == 0, 8-commit window == 0), diff --check clean"
    requirement: "R7"
    verification:
      - kind: other
        ref: "plan 28-04 Task 2 verify one-liner (re-run with corrected R8 symbol anchor) -> BATTERY_FAIL=0"
        status: pass
    human_judgment: false
  - id: D3
    description: "User-machine UAT closed loop — toc declaration confirmation, --selftest under a 5.0 and a 5.1+ interpreter, /run macroTorch.cpDamageLog=true dummy session, analyzer two-layer report with >= 30 entries across all three skills"
    verification: []
    human_judgment: true
    rationale: "the game client and any Lua interpreter exist only on the user's machine (28-VALIDATION.md Manual-Only); at human_verify_mode=end-of-phase the verifier folds the result into 28-UAT.md"

# Metrics
duration: 3min
completed: 2026-09-08
status: complete
---

# Phase 28 Plan 04: catAtk claw/shred/bite damage instrumentation — user-machine UAT script + closing battery Summary

**classes/druid/HUMAN-UAT.md gains a 6-section Phase 28 acceptance script (prerequisites / two-interpreter --selftest pre-check / SavedVariables toc declaration check / dummy protocol / analyzer run / troubleshooting), and the phase-closing battery goes fully green — 8-file bbcheck, build.sh, 6 product-count assertions, Phase 27 pairLandIntent coexistence, R8 nine-symbol presence, R7 zero-path audit — after correcting the stale R8 acceptance anchor (canDoReshift -> shouldDoReshift) that docs commit 10db348 mis-transcribed**

## Performance

- **Duration:** 3 min
- **Started:** 2026-09-08T13:56:30Z
- **Completed:** 2026-09-08T13:59:50Z
- **Tasks:** 2
- **Files modified:** 2 (classes/druid/HUMAN-UAT.md, .planning/REQUIREMENTS.md)

## Accomplishments
- HUMAN-UAT.md 末尾追加完整 Phase 28 段（中文，6 小节）：① Prerequisites（SuperWoW/构建/双解释器/木桩/LOG_MAX_SIZE=3000 建议）② Pre-Test（`lua tools/cpdamage.lua --selftest` 双解释器 + /mt Category U 9 条 + 横幅第 5 项 `macroTorch.cpDamageLog = false`）③ SavedVariables 声明确认（RESEARCH A2：.toc 补 `MACRO_TORCH_LOG` 声明 + 完全退游重进）④ 打桩协议（`/run macroTorch.cpDamageLog=true` → catAtk 打骷髅桩 1 分钟 → 脱战 ≈5s 分批 → /reload → 拷回，含 T-28-05 勿与 rawdiag2 同开提醒）⑤ 分析运行（四档表/OOC 背位表/bite 回归/三类决策建议行/条目 ≥30 三技能齐）⑥ 期望结果与排查（e≈42/54/35、无打点三查 .toc→开关→GCD probe、crit 缺失记语言环境 A3）——完整覆盖 28-VALIDATION.md 两条 Manual-Only 行
- 全阶段验证电池 BATTERY_FAIL=0：8 文件 bbcheck 全 BALANCED、build.sh exit 0、产物断言六项全中（cpDamage 函数集 ERE=5、Cat U=9、cpDamageSample=4、cpDamageCast=4、pairLandIntent=1、R8 九符号=9）、R7 零路径三审计全零（build_order.txt 无 tools 条目、产物无 extractMacroTorchLog、最近 8 commit 无构建清单与决策文件）、git diff --check 干净
- Phase 27 land 配对语义与 R8 各符号并存无排挤：pairLandIntent 恰 1 处、catAtk/regularAttack/keepRip/keepRake/keepFF/shouldUseShred/shouldCastRip/shouldUseBite/shouldDoReshift 九符号全在产物中——并行观测通道零占道
- 实机验收协议（human-check 四项：.toc 确认 / 双解释器 --selftest / 打桩 1 分钟 / 分析器出真表）以 end-of-phase 形式交付 verifier 汇入 28-UAT.md

## Task Commits

Each task was committed atomically:

1. **Task 1: HUMAN-UAT.md 追加 Phase 28 实机验收段（含 human-check 验收协议）** - `363a189` (docs)
2. **Task 2: 全阶段验证电池 + 收尾（R7/R8 审计与 Phase 27 语义共存断言）** - `3240733` (docs, battery fix: R8 锚点拼写修正)

**Plan metadata:** see final docs commit below.

## Files Created/Modified
- `classes/druid/HUMAN-UAT.md` - 追加 Phase 28 段（6 小节 + 完成信号，58 行）: 前提（LOG_MAX_SIZE=3000 建议 D-10）/ Pre-Test（--selftest 双解释器 + Category U + D-06 横幅第 5 项）/ SV 声明确认（RESEARCH A2 补 .toc 修复法）/ 打桩协议（开关命令、三技能手动补样、脱战分批 D-11、勿同开提醒 T-28-05）/ 分析运行（四档表 + OOC 背位表 + bite 回归 + 三类决策行 + 条目 ≥30）/ 期望与排查（e 42/54/35、三查顺序、A3 语言环境记录）
- `.planning/REQUIREMENTS.md` - R8 验收 grep 锚点 `canDoReshift` → `shouldDoReshift`（1 行）

## Decisions Made
- **R8 锚点修正而非代码改名**：电池按计划原样运行时 R8 计数 8/9 失败——逐项拆解定位到 `canDoReshift` 在全部 tracked 源码与 build 产物中零命中；git 溯源证明该名随 phase-04 重构（fefecdf/86eca09）已成 `shouldDoReshift`（cat.lua:241），而文档提交 10db348（"update R8 module names to actual functions"）把 R8 验收 grep 误写回旧名。改代码名不可行（cat.lua 列本 phase 零改动禁域 + R2-01..R2-07 自测十余处调用点会全破），故修正锚点拼写——不弱化断言（从验证不存在的符号改为验证真实符号，语义更强），只改文档不改任何代码。
- **UAT 段语言取中文**：计划明示「中文文档」；既有文件仅 Phase 06 一段且全英文（计划的"既有中文惯例"前提与实际不符）——结构惯例（Prerequisites/Pre-Test/checklist `- [ ]` 风格）照抄，语言按计划指令走中文，命令行与标识符保持原样。
- **human-check 不设中途 checkpoint**：计划 objective 与 human_verify_mode=end-of-phase 一致——四项实机闭环写成文档交付 verifier 在阶段末汇入 28-UAT.md；四步动作全部落入 UAT 段第 3/2/4/5 节，含完成信号回复路径。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] R8 九符号断言锚点含不存在的旧符号名 canDoReshift（电池首跑 BATTERY_FAIL=1）**
- **Found during:** Task 2 验证电池首跑（R8 计数 8/9，其余九枚断言全绿）
- **Issue:** 计划的 R8 grep 照抄 REQUIREMENTS.md 既有验收标准原样，而该原样自文档提交 10db348 起就是错的：`canDoReshift` 在全部 tracked 源码与 SM_Extend.lua 产物中零命中（源码自 phase-04 重构起即名 `shouldDoReshift`，cat.lua:241；git log -S 证明 canDoReshift 只存在于重构前的旧时代提交）
- **Fix:** 修正 .planning/REQUIREMENTS.md R8 验收行锚点拼写（canDoReshift → shouldDoReshift），电池以同构断言重跑（修正后计数恰 9，其中 shouldDoReshift=1）；不改任何代码符号——cat.lua/combo.lua 为本 phase 决策文件零改动禁域，改名还会打碎 selftest.lua R2-01..R2-07 与 cat.lua 十余处调用点
- **Files modified:** .planning/REQUIREMENTS.md
- **Verification:** 电池重跑 BATTERY_FAIL=0；修正后 R8 grep=9、shouldDoReshift 在产物=1、canDoReshift 在 tracked 源码 0 文件；git diff --check 全净；其余 9 项断言与首跑一致
- **Committed in:** 3240733（Task 2 fix commit）

---

**Total deviations:** 1 auto-fixed (Rule 1 bug in the acceptance anchor)
**Impact on plan:** 只改 .planning 内一行验收文档拼写，代码、verify 锚点形状（仍为同型 alternation 计数 ≥9）、构建清单零改动。断言语义从弱（查不存在的名字）变强（查真实符号）；其余锚点原样。

## Issues Encountered
- 电池一句话断言链失败时不可读——按 A1..A10 拆解逐枚运行定位到 A6（R8 计数 8 8 < 9），再逐符号 grep 九个名字锁定唯一零命中项 canDoReshift；git log -S 双向溯源确认拼写历史（见 Decisions）。
- 本任务电池含 build.sh 重建（SM_Extend.lua 为 gitignored 产物，不进入 commit）与 8-commit 窗口审计——均已按计划原样执行，无一弱化。

## Known Stubs

None - the two shipped artifacts are complete. The user-machine UAT run itself (dummy session + two-interpreter --selftest + analyzer real-dump run) remains a designed end-of-phase human-check handoff carried by the plan's `<human-check>` and 28-VALIDATION.md Manual-Only table — at human_verify_mode=end-of-phase the verifier folds its result into 28-UAT.md. This is a verification-routing fact, not an unimplemented placeholder; no WINDOWS ledger entry applies (matching the 28-01/28-02/28-03 precedent).

## User Setup Required

None - no external service configuration required by this plan itself. The user-machine execution steps (what the user must do) are fully scripted in `classes/druid/HUMAN-UAT.md` Phase 28 section; the completion signal feeds the verifier's 28-UAT.md.

## Next Phase Readiness
- Phase gate material ready for the verifier: BATTERY_FAIL=0 battery report (this summary), the UAT script (HUMAN-UAT.md Phase 28 section), and the four human-check acceptance items.
- R8 acceptance grep is now truthful against the codebase — future phases reusing the REQUIREMENTS.md line will not trip on the stale spelling again.
- No blockers.

## Self-Check: PASSED
- Task commits exist: 363a189 / 3240733
- classes/druid/HUMAN-UAT.md exists with the Phase 28 section; three grep anchors non-zero (1 / 3 / 1)
- Battery re-run green: BATTERY_FAIL=0 with corrected R8 anchor (== 9)
- git diff --check clean at every task boundary; no CR bytes; working tree clean

---
*Phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac*
*Completed: 2026-09-08*