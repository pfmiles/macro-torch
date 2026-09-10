---
phase: 30-cpbuild
reviewed: 2026-09-10T15:49:19Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - classes/druid/Druid.lua
  - core/events.lua
  - classes/druid/selftest.lua
  - classes/druid/HUMAN-UAT.md
  - tools/cpbuild.lua
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 30: Code Review Report

**Reviewed:** 2026-09-10T15:49:19Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found（0 Critical / 3 Warning / 4 Info）

## Summary

审查了 Phase 30 全部五个交付文件。总体结论：**DKI 状态机与执行层面正确兑现了锁定的协议（30-CONTEXT.md D-01/D-04/D-05/D-06/D-08）**，与既有基础设施（`macroTorch.inCombat`、`macroTorch.target.isCanAttack`（含 `UnitIsDead` 背查语义）、`macroTorch.log` 双写通道、`macroTorch.cpBuildLog` 开关）的接线全部属实，未发现语义级 Defect：

- **门序（orchestrator 重点 1）**：`cpBuildDkiTick` 的两个 cheap-first 门（开关读、`inCombat` 读）都在 `GetComboPoints()` 之前，开关关闭时 0.1s tick 只做两次纯字段读返回，无任何客户端 API 调用（S-12 钉住）。
- **状态机记账（重点 2）**：三态 + 两旁路逐条对照锁表核验——BUILDING 的 `cp >= 5` 先于下跳分支检查；窗口中段下跳记 fail 且存活目标重锚（窗口互斥）；kill-shot 变体记 fail 后 t0 置 nil 回干净 WAIT_ANCHOR；DONE 完全静默直到下一个下跳；`t1 − t0` 恒定 `%.3f` 格式；分母 = ok + fail 在分析器中正确实现。
- **解析器静默丢行（重点 3）**：`tokenNumber` 的 `cp=` 三字符缺陷已在投递代码中修复（`string.len(key)`）；`parseSamples` 对坏行的丢弃全部计入 `badLines`（不静默）；前缀 `[cpBuild] ` / `[cpBuildT] ` 互斥性经字符位核对成立。
- **冻结面（重点 4）**：`cpBuildLogSample` / `cpBuildLogEvent` / `claw/shred/rake/ferocious_bite` 包装函数 diff 上零改动（仅上下文行）；`tools/cpdamage.lua` 零 diff；`core/events.lua` 仅新增 2 个 reset 调用点；RegisterEvent 面仍为 20。
- CR-01 stub 纪律在 S-05..S-12 的 8 条测试中逐条成立（7 项全局快照、pcall 驱动、**首个 assert 之前**恢复）。

残余问题均为 Warning 级：状态机的"下跳=咬击"机械假设在偏离 D-09 目标态循环时会被非 bite 终结技污染；HUMAN-UAT 排查条目对 GCD 探针的归因张冠李戴；events.lua 的无守卫 reset 调用存在级联失效面。另注：本相 config 的文件清单写的是 `toolsls/cpbuild.lua`（拼写错误，目录不存在），实际审查路径为 `tools/cpbuild.lua`，见 IN-01。

## Warnings

### WR-01: DKI 下跳谓词把一切连击点终结技都当作咬击锚（Rip / 低星斩杀咬污染窗口）

**File:** `classes/druid/Druid.lua:423-424`
**Issue:** `downJump = prevCp > 1 and cp <= 1` 与 `biteAnchor = downJump and (cp == 1 or toBoolean(target.isCanAttack))` 只依赖 CP 数量变化，无法区分消费全部连击点的技能——**Rip 同样是一次 5→0 的存活目标下跳**，会被机械地当作咬击锚：Rip 后到 5 星产生一条假 `ok` 窗口；窗口中段的一次 Rip（或 3-4 星快速咬等非目标态行为）会写成 `fail` 并重锚。catAtk 现行常规循环在 5 星时会正常释放 Rip，因此**在不满足 D-09 目标的采集下静默产出污染数据**（假 ok、假 fail 虚增分母），分析器无法事后区分。数据有效性目前只靠 HUMAN-UAT 的 D-09 前置条件程序性保护，机器本体没有任何判别器。
**Fix:** 线协议已冻结（D-06），不建议改行格式。两处程序性补强：
1. HUMAN-UAT.md 采集协议节追加明确豁免：采集全程禁止 Rip/非 5 星咬击（"窗口周期一次"一行写明）；
2. 排障节（Part 6）新增一条：数据中数量异常的 `fail` + 明显偏短的 ok——优先自查是否中途释放过 Rip。未来扩展可考虑用 `UNIT_SPELLCAST_SUCCEEDED` 侧短暂抑制非 Ferocious Bite 终结技的下跳，但需另立 phase，不并入本相。

### WR-02: HUMAN-UAT 排障条目把 [cpBuild] 的 GCD 探针要求错误归因到 [cpBuildT] 通道

**File:** `classes/druid/HUMAN-UAT.md:317`
**Issue:** "无 ok 无 fail — 查开关是否开启、目标是否为可攻击骷髅、**GCD 探针黄色警告是否出现（Rake 法术必须在动作条上，否则无采集）**"。GCD 探针（`isActionCooledDown('Ability_Druid_Rake')`）只门控 `[cpBuild]` 施法采样（`cpBuildLogSample`），而 DKI tick 只读 `GetComboPoints()`，**Rake 不在动作条上时 `[cpBuildT]` ok/fail 行照常产出**。按此行排查会误导用户去摆 Rake 技能条而漏掉真正原因（开关、inCombat、真实下跳发生与否、LOG_MAX_SIZE 裁剪）。
**Fix:** 拆成双通道排查：
- `[cpBuild]` 缺失 → 查 GCD 探针警告（Rake 必须在动作条上）；
- `[cpBuildT]` 缺失 → 查 `macroTorch.cpBuildLog` 是否热开、循环是否为咬击维持双流血的目标态（无下跳则永无锚）、`macroTorch.LOG_MAX_SIZE` 是否停顿前已裁剪。

### WR-03: events.lua 对 `resetCpBuildDki` 的无守卫调用位于分支首句，Druid.lua 若加载失败会级联打断既有逻辑

**File:** `core/events.lua:74-77`、`core/events.lua:96-99`
**Issue:** build_order.txt 中 `core/events.lua` 先于 `classes/druid/Druid.lua` 加载，`resetCpBuildDki` 在事件时刻才被引用。若未来某次改动让 Druid.lua 编译失败（WoW 会跳过该文件继续加载其余文件），`macroTorch.resetCpBuildDki` 为 nil：PLAYER_TARGET_CHANGED 分支**首句**抛错会中止同分支后续既有的 `ffTimer / targetHealthVector` 清理与 "Target change in combat!" 提示；PLAYER_REGEN_ENABLED 分支的报错虽在 `onCombatExit()` 之后（inCombat 不会被卡 true），仍每次脱战刷错误。同一 handler 的其它调用点（`onSelfDamageLine` 等）有同样的模式级风险，但本调用是白子落在分支头部，伤害最大。
**Fix:** 加免费守卫（两处相同）：
```lua
if macroTorch.resetCpBuildDki then
    macroTorch.resetCpBuildDki()
end
```
与 handler 内其它宏函数调用同构，零行为变化（正常路径恒为真）。

## Info

### IN-01: 审查配置的文件清单存在路径拼写错误（`toolsls/cpbuild.lua`）

**File:** 审查配置（非源码）
**Issue:** 本相 config 的 `files:` 写为 `toolsls/cpbuild.lua`，该目录不存在；实际审查与投递路径为 `tools/cpbuild.lua`（`tools/` 下仅 `cpbuild.lua`、`cpdamage.lua` 两文件）。下游消费者若按清单字面取文件会落空。
**Fix:** 后续 phase 摘要/修复器引用统一使用 `tools/cpbuild.lua`。

### IN-02: tools/cpbuild.lua 携带约 245 行从未调用的 decodeJson（D-07 冻结拷贝的余重）

**File:** `tools/cpbuild.lua:315-559`
**Issue:** `decodeJson` 是路线 A 从 cpdamage.lua 逐字节复制的 harness 成员，本脚本只消费 terse 行协议（`parseCastBody` / `parseTOkBody`），`decodeJson` 零调用（全文仅 669 行注释提及）。这是刻意的 D-07 冻结面，非缺陷，但占文件 20% 行数的死代码会成为后续维护者误改对象。
**Fix:** 保持不动（冻结纪律优先）。若要瘦身需另立 phase 决策，不要在本相内改动。

### IN-03: `--rake-dur` 接受 0 与负数值，产出退化 cutoff

**File:** `tools/cpbuild.lua:1187-1201`
**Issue:** `tonumber(args[i + 1])` 通过后未做下界校验；`--rake-dur 0` 或 `--rake-dur -5` 会得到 `rakeDur cutoff = -1`、`savagery d = 0/负、cutoff = -1`，达标率两行全 0% 且无语义，用户不会得到任何提示。数值非负但极小（如 1）同样边缘化。
**Fix:** 在 tonumber 检查后加下界钳制：
```lua
if dur == nil or dur < 2 then
    io.write('error: ' .. FLAG_RAKE_DUR .. ' expects a value >= 2 seconds\n')
    printUsage()
    os.exit(1)
end
```

### IN-04: selftest 电池把回读临时文件写到当前工作目录

**File:** `tools/cpbuild.lua:1125-1128`
**Issue:** `cpbuild_selftest_json_roundtrip.tmp` 写进 CWD；在只读目录（或无写的 Cygwin 挂载点）下运行 `--selftest` 会因 `io.open(path, 'w')` 失败误报 exit 1，与"selftest 零外部依赖"的注释（1162-1163 行）不符。文件在 readAll 后即 `os.remove`，泄露面很小但失败模式误导。
**Fix:** 改用 `os.tmpname()`（Lua 5.0 支持）取系统临时路径，或在无法写入 CWD 时跳过回读检查并打印说明而非 exit 1。