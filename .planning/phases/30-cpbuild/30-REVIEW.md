---
phase: 30-cpbuild
reviewed: 2026-09-10T16:16:06Z
depth: standard
iteration: 2
files_reviewed: 5
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/HUMAN-UAT.md
  - classes/druid/selftest.lua
  - core/events.lua
  - tools/cpbuild.lua
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 30: Code Review Report (Iteration 2 — Pre-UAT Re-Review)

**Reviewed:** 2026-09-10T16:16:06Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found（0 Critical / 3 Warning / 4 Info — 较第一遍 9f2950a：0 新增 Critical/Warning，IN-01 已随本轮 config 修正化解，新增 1 条 Info）

## Summary

本轮是用户实机测试前的重审（原话意图：验证本次重构的正确性与完整性、且不破坏 cpDamage 与 catAtk 一键宏）。第一遍审查 9f2950a 之后，5 个源码文件仅有 96dd755（.planning 工件）一次提交——**5 个被审文件自第一遍起零变化**，因此本轮工作重点是：逐条 re-verify 第一遍 7 项发现、对锁定的 D-01..D-15 契约做独立交叉核验、以及对用户最关心的非回归面（cpDamage/catAtk）做防线复核。静态门（bbcheck、diff --check、Lua 5.0 glyph、luaparser、Lua 5.0.3 实跑 26+8 条测试）已由 phase verifier 认证绿色，本轮不重跑。

**契约逐条核验结论（全部相符）：**

- **D-04 状态机（Druid.lua:408-472）**：三态 + 两旁路逐行对照封版协议成立。WAIT_ANCHOR→BUILDING 仅由 `prevCp > 1 and cp <= 1` 下跳触发（423 行）；cp=0 消歧只在落点恰为 0 时背查 `target.isCanAttack`（424 行 `cp == 1 or ...` 短路，cp=1 时不读目标，S-06 钉住）；BUILDING 中 `cp >= 5` 先于下跳分支检查（425-433 行，D-04 顺序锁定）；截断旁路记 fail + 存活目标重锚保持 BUILDING / 垂死目标 t0 置 nil 回 WAIT_ANCHOR（434-448 行，30-02 d78d6a2 已在场，两处 WAIT_ANCHOR 返回点均为纯净态——t0 nil、state WAIT_ANCHOR、prevCp 语义保持：局部回退后 prevCp 等于当轮 cp（0 或 1），下跳谓词要求 prevCp > 1，与 nil 等价，无二次伪锚，非死代码）；DONE 静默到下一锚（457-470 行）。kill-shot 变体"记一次 fail 不重锚"与 S-09/S-08 的 SUMMARY 决定一致。
- **D-01/D-05 门序（408-415 行）**：开关读 → `macroTorch.inCombat` 读 → `GetComboPoints()`。已独立确认 `macroTorch.inCombat` 是 combat_context.lua:22/33 写出的纯布尔字段（非方法），两处提前返回确为纯字段读、零客户端 API；S-12 三条臂与实现一致。轮询经 `registerPeriodicTask('cpBuildDkiPoll', { interval = 0.1, ... })`（474 行），periodic.lua 的 leastUpdateInterval=0.1 框架属实；注册成本为载入期一次表写入，战斗外 tick 空转返回。
- **D-06 行协议**：`[cpBuildT] ok t=` 恒 `%.3f`（432 行）、fail 无 t 字段、取消不写行——与 cpbuild.lua 解析器（`parseTOkBody` 恰 2 token、'fail' 精确匹配、坏行入 badLines）闭合；`[cpBuild]` 行语义 D-02 冻结（cpBuildLogSample/cpBuildLogEvent 344-371 行为零变化，diff 仅追加其后）。
- **D-07/D-08 分析器**：与 cpdamage.lua 的五个共享 harness 函数（readAll/extractMacroTorchLog/loadBlockSandboxed/getMessages/countList）**逐字节 diff 为空**，自包含拷贝属实（cpdamage.lua 本身 zero-diff）。k 统计 BREAK_THRESHOLD=30s 断链切分（k>30 或 k≤0 计入 breaks 且排除出一切 k 统计）、六档直方图 [<1.5)..[≥10) 与 D-08 逐字一致；双档达标率 rakeDur `d-1` / savagery `0.9d-1`、分母 = ok+fail（`calculatePassRates` 878-907 行）；窗口矩阵、badLines、26 检查 selftest 的 fixture 数学全部手算复核吻合（k 均值 4.6、断链 1、桶占用 1/0/1/1/1/1、T 双样本 [6,8)、d=9 时 savagery passed 1/2 等）。
- **D-10**：新代码无 `#` 长度运算符、无 goto（静态门已绿，不再重跑）。
- **D-13 CR-01**：S-05..S-12 共 8 条注册体逐条核对——每个测试 7 项快照（GetComboPoints/GetTime/log/inCombat/cpBuildLog/target/cpBuildDki），pcall 驱动，**恢复先于首个 assert**；pin 的内容与已实现机器完全一致（S-05 种子 tick 语义、S-06 双驱动、S-08 重锚 t0=110、S-09 t0=nil、S-10 DONE 双 tick、S-12 三臂，均无与实现矛盾的 pin，无越界钉实现细节）。
- **加载顺序（非回归关键）**：build_order.txt 中 core/periodic.lua（第 6 行）先于 classes/druid/Druid.lua（第 27 行），`registerPeriodicTask` 在 Druid.lua 载入期可用；`macroTorch.log`（interface_debug.lua 第 18 行）、`macroTorch.toBoolean`（impl_util.lua 第 2 行）、entity 层均先加载。DKI 块插入位置（373-474）位于 cpBuildLogEvent 之后、cpDamage 注释块（476）之前，cpDamageSample(482)/cpDamageCast(528) 及其上下文逐行未动。
- **events.lua 冻结面**：diff 仅 +8 行（两处注释 + 两处 `resetCpBuildDki()` side-effect join），无新增 RegisterEvent（全库仍 20 处，含注释行口径）；两调用均位于既有分支内、不改动任何既有语句的先后与条件；PLAYER_REGEN_ENABLED 分支的 reset 在 `onCombatExit()` 之后（先落 inCombat=false/context 交换，再清 DKI），与 D-04 旁路 2 语义吻合。
- **完整性盘点**：5 文件内无缺失钩子/遥测点。HUMAN-UAT Phase 30 覆盖 D-09 目标态循环前置（287 行）与 D-14 Windows+Cygwin rebuild + 游戏内电池（284/291-293 行），与 30-VALIDATION Manual-Only 表 1-3 行对应；第 4 行（WINDOWS.md 账本闭环）在 HUMAN-UAT 正文缺一条指引（新发现 IN-05）。
- **非回归（用户两项点名功能）**：cpDamage——cpdamage.lua 零 diff、Druid.lua 的 cpDamage 区段零 diff、spell_trace_core.lua 零 diff、events.lua 的 RAW_COMBATLOG [cpDamage] 通道分支未触碰；catAtk——combo.lua/cat.lua 零 diff，Druid.lua 仅追加 DKI 块（claw/shred/rake/bite 包装器与 _castSpell 路径未动），新周期任务对宏点击路径无任何共享状态写入。两者均可判定为本 phase 安全。

## Warnings

### WR-01（第一遍，still-open）: DKI 下跳谓词把一切连击点终结技当作咬击锚（Rip / 低星斩杀咬污染窗口）

**File:** `classes/druid/Druid.lua:423-424`
**证据（本轮复核）:** 谓词与 9f2950a 时逐字节相同；建议补丁未落地——HUMAN-UAT Phase 30 采集协议（296-300 行）仍无"采集全程禁止 Rip/非 5 星咬"的豁免行。本轮另核实前提成立的代码锚点：cat.lua `termMod → cp5Bite`（cat.lua:99-130）及其注释"若目标身上还不存在rip效果，一般5星时是优先rip而非bite的"，即常规循环在 5 星会真实打出 5→0 的 Rip 下跳（活体背查通过 → 假锚 → 一条伪 ok 窗口）；旁路 1 同样无法区分"窗口中途的 Rip/非目标态终结技"与真实的低星斩杀咬。此外同一机械假设还延伸一个此前未写明的变体：窗口中段目标被流血跳死（非咬击致死）时 3→0 下跳 + 死体背查也会落一条 fail——三类污染同根。D-09 前置（287 行）是唯一程序性保护，分析器无法事后分辨。
**Fix:** 维持两处程序性补强（原建议照旧）：
1. HUMAN-UAT Phase 30 第 3 节补一行：采集全程释放的终结技仅限 5 星 Ferocious Bite 与目标态下的斩杀咬，禁止打 Rip/非 5 星咬（违者弃档）；
2. 第 6 节追加排查条：fail 占比异常偏高 + ok 明显偏短 → 自查是否中途打过 Rip 或目标被流血跳死。
（用 UNIT_SPELLCAST_SUCCEEDED 侧做终结技种别判别属另立 phase，不并入本相。）

### WR-02（第一遍，still-open）: HUMAN-UAT 排障条目把 GCD 探针要求错误归因到 [cpBuildT] 通道

**File:** `classes/druid/HUMAN-UAT.md:317`
**证据（本轮复核）:** 行文未变："无 ok 无 fail — 查……GCD 探针黄色警告是否出现（Rake 法术必须在动作条上，否则无采集）"。GCD 探针（`isActionCooledDown('Ability_Druid_Rake')`）只门控 [cpBuild] 施法采样（cpBuildLogSample），DKI tick（408-472 行）只读 `GetComboPoints()`，Rake 不在动作条上时 [cpBuildT] 行照常产出。
**Fix:** 拆成双通道排查：[cpBuild] 缺失 → 查 GCD 探针警告；[cpBuildT] 缺失 → 查 `macroTorch.cpBuildLog` 热开、目标态循环是否真发生了下跳（无下跳则永无锚）、`macroTorch.LOG_MAX_SIZE` 是否已裁剪。

### WR-03（第一遍，still-open）: events.lua 对 `resetCpBuildDki` 的无守卫调用位于分支首句，Druid.lua 加载失败会级联打断既有逻辑

**File:** `core/events.lua:77`、`core/events.lua:99`
**证据（本轮复核）:** 两处调用仍无 nil 守卫，与 9f2950a 相同。本轮补充核实了正常路径下无此风险（build_order.txt 中 periodic/impl/entity/interface 均先于 Druid.lua 加载，函数在事件时刻必然存在）；风险面是未来 Druid.lua 编译失败被 WoW 跳载时，PLAYER_TARGET_CHANGED 分支首句抛错会中止后续 `ffTimer / targetHealthVector` 清理与 "Target change in combat!" 提示（PLAYER_REGEN_ENABLED 分支的报错虽在 `onCombatExit()` 之后，inCombat 不会被卡 true，仍每次脱战刷错误）。
**Fix:** 两处加免费守卫（正常路径恒真、零行为变化）：
```lua
if macroTorch.resetCpBuildDki then
    macroTorch.resetCpBuildDki()
end
```

## Info

### IN-01（第一遍，resolved 于本轮）: 审查配置的文件清单路径拼写错误

**File:** 审查配置（非源码）
**状态:** 本轮 iteration-2 config 的 `files:` 已写正确的 `tools/cpbuild.lua`（实测 `tools/` 下确为 cpbuild.lua/cpdamage.lua 两文件），原 `toolsls/` 误写不再出现于任何活体配置。**注:** 同一拼写类瑕疵在本轮评测提示的 required_reading 段复发（`tools/cpbuild.luaua`）——未落入仓库，仅提请下游消费者引用路径时以 `tools/cpbuild.lua` 为准。

### IN-02（第一遍，still-open）: tools/cpbuild.lua 携带约 240 行从未调用的 decodeJson（D-07 冻结拷贝的余重）

**File:** `tools/cpbuild.lua:315-558`
**证据（本轮复核）:** `grep decodeJson(` 全文件唯一命中处为 315 行定义本身，零调用点；本脚本只消费 terse 行协议（parseCastBody/parseTOkBody）。属刻意的 D-07 路线 A 冻结面（与 cpdamage 同款），非缺陷。
**Fix:** 保持不动（冻结纪律优先）；若瘦身需另立 phase。

### IN-03（第一遍，still-open）: `--rake-dur` 接受 0 与负数值，产出退化 cutoff

**File:** `tools/cpbuild.lua:1187-1201`
**证据（本轮复核）:** 当前树 `tonumber(args[i+1])` 通过后无下界校验（1200 行 `drake = dur`）；`--rake-dur 0`/负数得到 `cutoff = -1`（899 行）、两档达标率全 0% 且无任何提示，用户无法判断是输入错还是真全 fail。
**Fix:** tonumber 检查后加下界钳制（如 `dur == nil or dur < 2` → 报错 + printUsage + exit 1）。

### IN-04（第一遍，still-open）: selftest 电池把回读临时文件写到当前工作目录

**File:** `tools/cpbuild.lua:1125-1128`
**证据（本轮复核）:** `cpbuild_selftest_json_roundtrip.tmp` 仍写 CWD；只读目录下 `io.open(path,'w')` 失败在 writeJsonOut 内 exit 1（1007 行），与 1162-1163 行"self-test path touches no external files"注释矛盾，失败模式误导。
**Fix:** 改用 `os.tmpname()`（Lua 5.0 支持）或写入失败时跳过回读检查并打印说明而非 exit 1。

### IN-05（本轮新发现）: HUMAN-UAT Phase 30 未覆盖 VALIDATION Manual-Only 第 4 行（WINDOWS.md 账本闭环），且 VALIDATION 引用的账本路径不存在

**File:** `classes/druid/HUMAN-UAT.md:275-320`（对照 `30-VALIDATION.md:69`、`.planning/WINDOWS.md` entry 6）
**Issue:** 30-VALIDATION.md Manual-Only 表第 4 行的 Test Instructions 是"按 `climate/WINDOWS.md` 账本条目逐项核对"，但仓库中无 `climate/` 目录——真实账本是 `.planning/WINDOWS.md`（phase 28 SUMMARY 可证），其中 entry 6（phase 30、kind=unrun-verify、status=open）原文即"S-05..S-12 stubbed DKI pins … execute on Windows+Cygwin per HUMAN-UAT.md Phase 30 protocol"。HUMAN-UAT Phase 30 六节正文通篇未提到该账本闭环（也未提账本位置），用户按 UAT 执行完毕也不知道要把 entry 6 勾销——完整性上缺一环（该闭环目前只存在于 30-UAT.md/30-VERIFICATION.md 的汇总层，由 verifier 代步）。
**Why it matters:** `workflow.windows_enforce` 开启时 open_count > 0 会阻塞 `/gsd-ship`；用户实机跑完若未闭环账本，后续 ship 会被 entry 6 卡住且排查方向被 `climate/` 误引导。
**Fix:**
1. HUMAN-UAT Phase 30 完成信号处加一行："在 `.planning/WINDOWS.md` 找到 phase 30 的 unrun-verify entry 6，按 `gsd-tools windows fixed 6` 勾销（或交由 verifier 汇入 30-UAT.md 时勾销）"；
2. 顺手把 30-VALIDATION.md:69 的 `climate/WINDOWS.md` 更正为 `.planning/WINDOWS.md`。

## Pre-UAT Verdict（给用户）

**结论：GO（可上实机）。** 本轮以 0 Critical、3 条第一遍遗留 Warning 收尾——状态机六转移 + 两旁路 + 门序 + 行协议 + 分析器统计全部对封版契约成立，8 条 S-05..S-12 pin 与实现零矛盾，动态证据（Lua 5.0.3 实跑）已由 verifier 备书。实机测试请带上三个前提：(1) **必须按 D-09 走目标态循环**（双流血由咬击刷新维持、全程只用 5 星咬作终结技），否则数据有效性仅剩程序性保护（WR-01）；(2) 排障时按 WR-02 的双通道口径区分 [cpBuild] 与 [cpBuildT] 缺失原因；(3) 跑完记得闭环 `.planning/WINDOWS.md` entry 6（IN-05）。

**cpDamage 与 catAtk 一键宏：均判定安全。** cpDamage 的采集/配对/分析面（cpdamage.lua 全文件、Druid.lua 的 cpDamageSample/cpDamageCast 及其注释块、spell_trace_core.lua 挂钩点、events.lua 的 RAW 通道分发）零 diff；catAtk 决策面（combo.lua/cat.lua）零 diff；Druid.lua 对两者的唯一接触是各包装器内的既有 switch 链，未受新 DKI 块影响；新周期任务与 catAtk 点击路径无共享状态写入，开关关闭时轮询路径为两次纯字段读（D-01）。综合判定：本 phase 未破坏其它功能，可以 rebuild + HUMAN-UAT。

---

_Reviewed: 2026-09-10T16:16:06Z_
_Reviewer: Claude (gsd-code-reviewer, iteration 2)_
_Depth: standard_