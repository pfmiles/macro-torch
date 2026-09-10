---
phase: 30-cpbuild
verified: 2026-09-10T15:56:58Z
status: passed
score: 14/14 must-haves verified
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 14
  total: 14
human_verification:

  - test: "游戏内 /mt 全绿（Windows+Cygwin rebuild 后，Category S-05..S-12 共 8 条全过、无红色 FAIL）"
    expected: "8 条 DKI stubbed 测试在 WoW 1.12 客户端内全部通过；登录横幅仍为 CONFIG_OPTIONS 4 项（本 phase 未增删配置项）"
    why_human: "selftest 电池的唯一注册/执行入口是客户端内 macroTorch.SelfTest；本机已用字节级抽取 + Lua 5.0.3 进程内复现 8/8 全过（见 Behavioral Spot-Checks），但客户端内执行仍是 HUMAN-UAT Phase 30 part 2 的权威确认（D-14）"
  - test: "目标态循环下实机采集（HUMAN-UAT Phase 30 part 3/4）：/run macroTorch.cpBuildLog=true 热开 → 打骷髅 → 观察聊天通道 [cpBuildT] ok t= 行与偶发 [cpBuildT] fail 行；随后 /run macroTorch.cpBuildLog=false 继续循环应无任何新 [cpBuild]/[cpBuildT] 行"
    expected: "ok 行 cadence 大致等于窗口周期（一窗一样本）；fail 与 ok 之比即未达标率；开关关闭后零新行且帧表现无变化（D-01 零 API 路径）"
    why_human: "真实 GetComboPoints 数值、真实下跳序列、聊天双写可见性只能由客户端提供；D-09 前置（目标态循环，禁硬打 Rake 补贴）是数据有效性的唯一程序性保障"
  - test: "战斗中途切换目标或脱战时不新增任何行（HUMAN-UAT part 3，D-04 bypass 2 实机路径）"
    expected: "BUILDING 中切换目标 → 状态静默回 WAIT_ANCHOR、不写行；脱战同样；历史已落盘样本不经重置清空"
    why_human: "PLAYER_TARGET_CHANGED / PLAYER_REGEN_ENABLED 的真实事件投递只能在客户端触发；本机仅验证了 reset 函数语义（S-11 进程内通过）与两处挂点的静态精确位（events.lua:77/99）"
  - test: "用户 Windows+Cygwin 上 lua tools/cpbuild.lua --selftest 原机重跑 + 真实 SuperMacro 存档日志解码（HUMAN-UAT part 5）"
    expected: "输出 selftest: ALL 26 PASSED、exit 0；真实日志报告含 k 均值 + 六档直方图 + 断链计数 + T̄ + T 分布直方图 + 双档达标率 + ok/fail 窗口矩阵"
    why_human: "权威目标运行时是用户机器的 Lua 5.0 解释器（D-14）；本机已用构建于本机的 Lua 5.0.3 实跑 ALL 26 PASSED 与合成报告链全对（见 Spot-Checks），用户机重跑确认环境差异为零并解码真实采集日志"
  - test: "WINDOWS.md unrun-verify 账本条目闭环（rebuild、游戏内 selftest 零红线）"
    expected: "账本中 Phase 30 相关 unrun 条目逐项勾销"
    why_human: "用户实机是唯一可执行环境（30-VALIDATION.md Manual-Only 表第 4 行，用户 2026-09-10 拍板 manual-only）"
---

# Phase 30: cpBuild 双保判定改造 — 验证报告

**Phase Goal:** 改造 cpBuild 测量系统为双保判定实证 instrumentation：保留 macroTorch.cpBuildLog 开关门控（关闭时零 API 调用），新增 0.1s 轮询的 bite→满5星耗时 live 状态机（[cpBuildT] ok/fail 行，D-04 三态+双旁路协议），新增自包含离线分析器 tools/cpbuild.lua（k 间隔分桶 + 30s 断链切分 + T̄ + 双档达标率 + ok/fail 窗口矩阵），Category S-05..S-12 CR-01 stubbed 单测。设计锁定于 30-CONTEXT.md D-01..D-14。
**Verified:** 2026-09-10T15:56:58Z
**Status:** human_needed（0 gap — 全部 14 条 truth 已核实；5 项实机人工验证待用户执行）
**Re-verification:** 否 — 初始验证（本目录无先前 VERIFICATION.md）

## 验证方法说明（重要）

本 host 事实上有 Lua 运行时：executor 在 30-03 执行期间于 /tmp/luabuild 编译了真实 **Lua 5.0.3**（正是 D-14 目标方言），并遗留 lupa(LuaJIT) venv。因此本验证器在自己的进程里执行了：

1. `lua tools/cpbuild.lua --selftest` → **selftest: ALL 26 PASSED, exit 0**（Lua 5.0.3 原生）
2. 合成 SavedVariables 完整报告链 + `--json-out` + `--rake-dur 10` → 全数手算吻合
3. **字节级抽取** Druid.lua:373-474（DKI 块逐字节原样）+ selftest.lua:1424-1814（S-05..S-12 注册体逐字节原样），配最小 stub 环境（macroTorch.toBoolean / tableLen 为 impl_util.lua 逐字节拷贝，log/registerPeriodicTask/SelfTest 桩），在 Lua 5.0.3 下执行 → **8 条测试 + 注册形状检查点 9/9 全过，exit 0**（含每条测试后的 CR-01 恢复泄漏围栏）

这与 SUMMARY 声称的"本机无法执行"不同——**锁定协议的可执行语义在本机获得了真实行为证据**。但这不取代实机 UAT：真实事件投递、真实 GetComboPoints 序列、聊天双写可见性、D-09 采集仍是用户侧 HUMAN-UAT 的权威层（用户已拍板 manual-only，见 30-VALIDATION.md Manual-Only 表）。

## Goal Achievement

### Observable Truths（14/14 全绿）

| # | Truth（来自 PLAN must_haves） | 状态 | Evidence |
| --- | --- | --- | --- |
| 1 | 30-01 T1：cpBuildLog 开 + 战斗中，bite 下跳锚定窗口、首达 5 星恰落一条 '[cpBuildT] ok t=<sec>' 行经 macroTorch.log（D-04/D-05/D-06） | ✓ VERIFIED | Druid.lua:425-433 转移表逐行对照 D-04 成立；S-05/S-07/S-10（锚定、ok 行、DONE 静默）在本机 Lua 5.0.3 进程内执行通过，S-07 断言捕获行恰为 '[cpBuildT] ok t=6.500'（3 位小数归档契约实证） |
| 2 | 30-01 T2：窗口中段下跳恰落一条 '[cpBuildT] fail' 并重锚下一窗口（D-04 旁路 1） | ✓ VERIFIED | Druid.lua:434-448（fail + biteAnchor 重锚保持 BUILDING；kill-shot 变体 t0=nil 回 WAIT_ANCHOR）；S-08/S-09 进程内通过（S-09 钉 t0=nil 的 d78d6a2 修复在场） |
| 3 | 30-01 T3：cpBuildLog 关时 0.1s 轮询在 GetComboPoints 前 return，轮询/采样路径零客户端 API 调用（D-01） | ✓ VERIFIED | 门序逐行核实：Druid.lua:409（cpBuildLog 首门）→ 412（inCombat 二门）→ 415（首个 API 调用）；S-12 以调用计数桩驱动真实 tick，进程内通过（关=0 / 战斗空闲=0 / 对照臂=1） |
| 4 | 30-01 T4：PLAYER_TARGET_CHANGED 或脱战丢弃在飞窗口且不落任何行（D-04 旁路 2） | ✓ VERIFIED | reset 语义 S-11 进程内通过（回 WAIT_ANCHOR、三字段清空、零捕获行）；挂点静态精确位：events.lua:77（PLAYER_TARGET_CHANGED 分支首句）+ events.lua:99（onCombatExit 之后），共恰 2 处；实机事件投递 → 人工项 #3 |
| 5 | 30-01 T5：轮询为加载期注册的 0.1s periodic task，体自门控，同 maintainTHV / maintainLandTables（D-05） | ✓ VERIFIED | Druid.lua:474 静态注册行；harness 注册捕获检查点验证参数相等（name='cpBuildDkiPoll', interval=0.1, task==macroTorch.cpBuildDkiTick） |
| 6 | 30-01 T6（D-03 禁令）：无 bite 行路径 — cpBuild 永不记 bite 行，锚点仅来自 cp 下跳检测，cpBuildLogSample/Event 零改动 | ✓ VERIFIED | 调用面普查：cpBuildLogEvent 仅 Claw/Shred/Rake 包装层 3 处（Druid.lua:30/43/55），bite/Rip/FB/Pounce 无路径；phase diff 对 Druid.lua 仅单 hunk（@@ -370,6 +370,109 @@ 纯插入），348-371 零改动 |
| 7 | 30-02 T1：八条 Cat S-05..S-12 stubbed 测试存在，均尾带 isOptional=true，逐条遵循 CR-01 快照/遮蔽/捕获/先恢复后断言纪律（D-13） | ✓ VERIFIED | 8 标题逐字在场（selftest.lua:1424-1814）、8 处 `end, true)` 全在 Druid 专属包装内；diff 增行中 7 个恢复字面量各恰 8 次；S-05 全裸核读确认先恢复后断言；harness 每条测试后恢复泄漏围栏 8/8 通过 |
| 8 | 30-02 T2：六转移 + 全局重置 + D-01 门控各由 stubbed 测试钉住（驱动 cpBuildDkiTick，捕获 GetComboPoints/GetTime/macroTorch.log） | ✓ VERIFIED | 8 条测试全部以 fresh 状态表 + 七全局遮蔽驱动真实 macroTorch.cpBuildDkiTick / resetCpBuildDki；本机 Lua 5.0.3 进程内执行 8/8 通过（S-12 门控臂 0/0/1 实证） |
| 9 | 30-02 T3：HUMAN-UAT.md 携带 Phase 30 章节，嵌入 D-09 目标态循环前置与 D-14 Windows+Cygwin 协议 | ✓ VERIFIED | 标题 '## Phase 30: cpBuild 双保判定 -- 实机 UAT 闭环'（275 行，文件末节）；D-09 前置全文（Part 1，含"现行循环会系统性低估真实 T̄ 并混淆能量轮廓"）；Windows+Cygwin 重建 + Cygwin lua 5.x 解码协议（Part 1/5） |
| 10 | 30-02 T4：全阶段静态电池绿 — bbcheck BALANCED、diff --check clean、只读文件零改动、SM_Extend.lua 无 tracked diff（D-11） | ✓ VERIFIED | 验证器自有进程重跑：4 文件 bbcheck 全 BALANCED + git diff --check clean + 只读围栏（cpdamage/cat/macro_torch/periodic/interface_debug）零 diff + SM_Extend.lua porcelain 0 + 工作树无越界文件 |
| 11 | 30-03 T1：tools/cpbuild.lua 为自包含 Lua 5.0 脚本，读取 SuperMacro SavedVariables、抽取 MACRO_TORCH_LOG、沙箱执行、报告 cpBuild 统计（D-07 route A：harness 复制、cpdamage 零改动） | ✓ VERIFIED | 1269 行；9 个 harness 函数与 cpdamage.lua **逐字节一致**（含 decodeJson 244 行、encodeValue、lineNumberOf，经精确 end 边界抽取 diff）；tools/cpdamage.lua 零 diff；在真 Lua 5.0.3 下零依赖运行 |
| 12 | 30-03 T2：k 统计遵守断链规则（相邻 [cpBuild] t 差 >30s 剔除）并落入六个锁定分桶 <1.5/1.5-2/2-3/3-5/5-10/>=10（D-08） | ✓ VERIFIED | BREAK_THRESHOLD = 30 文件头常量在场；实跑合成档：t 差 1.2/2.6/48.2/2.1 → breaks=1（48.2 剔除）、samples=3、mean=1.97、below15=1、桶 [<1.5)=1 [2,3)=2 —— 与手算逐项吻合 |
| 13 | 30-03 T3：T 统计产出均值 T̄、分布直方图、双档达标率 P(T≤D-1)（D 默认 9 与 0.9×D Savagery 档）（D-08） | ✓ VERIFIED | 实跑：T̄=6.66（6.542/7.950/5.500 手算 6.664）；T 桶 {4,6,8,10,12}；drake 9 → rakeDur cutoff 8.0 = 75%(3/4)、savagery cutoff 7.1 = 50%(2/4) 两档互异（跨档夹具）；--rake-dur 10 → cutoff 9.0/8.0 双 75% 手算吻合 |
| 14 | 30-03 T4：ok/fail 窗口矩阵与 dropped(badLines) 统计被报告；--selftest/--json-out/--rake-dur CLI 对齐 cpdamage 契约（D-07/D-08） | ✓ VERIFIED | 窗口矩阵 ok 3/fail 1 实跑正确；badLines 由 26 项电池覆盖（2 坏行夹具）；三旗标实跑：--selftest ALL 26 PASSED exit 0、--json-out 产出 9 键合法 JSON 归档（值全对）、--rake-dur 生效 |

**Score:** 14/14 must-haves verified（0 条 behavior-unverified — 行为依赖类 truth 均有本机进程内行为证据，见 Spot-Checks）

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| classes/druid/Druid.lua | DKI 状态机（cpBuildDki 表/状态/t0/prevCp、cpBuildDkiTick、resetCpBuildDki、加载期注册 'cpBuildDkiPoll'） | ✓ VERIFIED | 373-474 行完整块；门序/转移表/发射字符串逐行对照 D-01/D-04/D-05/D-06 成立；API 普查（GetComboPoints ×1、GetTime ×4、macroTorch.log ×2）符合 PLAN 判定 |
| core/events.lua | 两个 DKI 全局重置挂点，位于既有分支内 | ✓ VERIFIED | 恰 2 处（77/99 行），位置与 PLAN 逐字一致；RegisterEvent 面冻结 20 |
| classes/druid/selftest.lua | Category S-05..S-12 注册（8 条）+ 计数注释更新 | ✓ VERIFIED | 8 标题逐字 + `end, true)` ×8 + 7×8 恢复纪律 + 计数注释 "Category S adds 12 tests (quick 260907-0ya + WR-01 fix + phase 30 DKI 8 tests)" |
| classes/druid/HUMAN-UAT.md | '## Phase 30:' 实机验收清单（D-09 前置 + D-14 协议 + 分析运行 + 排查） | ✓ VERIFIED | 六节 checkbox + D-09 全文 + Windows+Cygwin 重建/解码 + 三旗标引用 + 完成信号行；章节为文件末节 |
| tools/cpbuild.lua | 自包含离线分析器（harness + terse 解析 + k/T/达标率统计 + 报告 + json + 电池） | ✓ VERIFIED | 1269 行；harness 字节一致；第 1/2/3 层全套锚点在场；Lua 5.0.3 实跑全对 |

### Key Link Verification（7/7 已接线 — 手工核实）

gsd-tools `verify.key-links` 查询无法解析本 phase PLAN 的 `from:` 字段（其含分支注释描述而非裸相对路径，工具返回 "Source file not found"，属工具解析限制——`from:` 格式为路径+括号注解），故以下全部以直接代码证据手工核实：

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| events.lua PLAYER_REGEN_ENABLED 分支 | macroTorch.resetCpBuildDki | 既有分支内 onCombatExit 之后的直接调用 | ✓ WIRED | events.lua:95 `macroTorch.onCombatExit()` → 99 `macroTorch.resetCpBuildDki()` |
| events.lua PLAYER_TARGET_CHANGED 分支 | macroTorch.resetCpBuildDki | 分支首句直接调用（先于 isInCombat nil 块） | ✓ WIRED | events.lua:73 elseif → 77 行即调用，先于 79 行既有 nil 块 |
| Druid.lua 加载期 registerPeriodicTask | macroTorch.cpBuildDkiTick | `task = macroTorch.cpBuildDkiTick` 于注册表内 | ✓ WIRED | Druid.lua:474；harness 参数相等检查点通过 |
| cpBuildDkiTick 发射 | interface_debug.lua macroTorch.log 双写通道 | 精确字符串 '[cpBuildT] ok t='/'[cpBuildT] fail' | ✓ WIRED | Druid.lua:432/437 两处调用；S-07 经捕获的 macroTorch.log 拿到逐字 'ok t=6.500'（进程内实证） |
| selftest.lua S-05..S-12 | cpBuildDkiTick / resetCpBuildDki | 七全局遮蔽 + fresh 表后直接驱动 | ✓ WIRED | 实体内直接调用（如 selftest.lua:1455）；harness 8/8 执行通过 |
| HUMAN-UAT.md Phase 30 章节 | tools/cpbuild.lua CLI | part 5 以三旗标形式的分析运行步骤 | ✓ WIRED | 'lua tools/cpbuild.lua --selftest' 双处锚点（293/308 行）+ --json-out/--rake-dur 引用；三旗标实跑验证存在 |
| tools/cpbuild.lua parseSamples | Druid.lua 发射器行契约 | 定序字段分词器消费逐字行文法 | ✓ WIRED | 实跑夹具（与发射格式逐字一致的 [cpBuild]/[cpBuildT] 行）解析全对、坏行 badLines 计数正确 |

### Data-Flow Trace（Level 4）

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| tools/cpbuild.lua parseSamples→report | casts/okTs 统计 | 文件 → extractMacroTorchLog → getMessages → parse | 是（合成档实跑全数手算吻合，无静态回退） | ✓ FLOWING |
| macroTorch.cpBuildDkiTick | cp/t0/prevCp | GetComboPoints()/GetTime() 轮询真值 | 是（S-07 用桩值 5+105.5 得 6.500 → 无硬编码；无桩时读客户端真值） | ✓ FLOWING |
| macroTorch.registerPeriodicTask | 'cpBuildDkiPoll' | 加载期静态注册 | 是（参数相等检查点） | ✓ FLOWING |
| HUMAN-UAT.md | 流程指令 | 人工文档 | 是（无 mock 数据） | ✓ FLOWING |

### Behavioral Spot-Checks（验证器自有进程执行）

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| 分析器电池（真实 Lua 5.0.3，非 LuaJIT） | `/tmp/luabuild/lua-5.0.3/bin/lua tools/cpbuild.lua --selftest` | selftest: ALL 26 PASSED, exit 0 | ✓ PASS |
| 完整报告链 | 同上命令 + /tmp/sv_sample.lua 合成档 | k mean 1.97/breaks 1/below15 1/T̄ 6.66/双档 75%/50%/矩阵 3/1 全手算吻合 | ✓ PASS |
| CLI 旗标 | `+ --json-out /tmp/cpbuild_out.json --rake-dur 10` | json 归档 9 键结构 + 值全对；rake-dur 重算双档 cutoff 9.0/8.0 正确 | ✓ PASS |
| DKI 状态机（字节级抽取代码 + 真实 Lua 5.0.3） | 自建 harness /tmp/dki_harness.lua（抽取 Druid.lua:373-474 + selftest.lua:1424-1814 逐字节，toBoolean/tableLen 用 impl_util.lua 逐字节拷贝，log/registerPeriodicTask/SelfTest 桩） | 8 测试 + 注册形状检查 9/9，exit 0；每测试后 CR-01 恢复泄漏围栏通过 | ✓ PASS |
| 静态门电池 | bbcheck ×4 + git diff --check | 4×BALANCED + clean | ✓ PASS |
| Lua 5.0 方言门 | goto/`::` 扫描（4 文件）+ 新增行 `#` 扫描（3 Lua 文件 phase diff）+ cpbuild.lua 全文件 `#` 计数 | 全 0 | ✓ PASS |

### Probe Execution

三份 PLAN frontmatter 均为 `specless probe: skipped`（phase_req_ids=null 的已记录可见跳过），本 phase 未声明任何 probe 文件；全仓亦无该 phase 的 `scripts/*/tests/probe-*.sh`。以上两条进程内行为执行（cpbuild --selftest + DKI harness）即本 phase 可取得的最强可执行证据，取代探针位。

### Requirements Coverage

**No-op（按规划声明会计）。** 三份 PLAN frontmatter 均声明 `requirements: []`（phase_req_ids=null），ROADMAP.md 记 "Requirements: —（无 req ID；reqs 覆盖门由编排器跳过）"。REQUIREMENTS.md 中 R1-R8 无任何一项映射到 Phase 30。无 ID 需要会计，亦不虚构 ID。

### Decision Coverage（非阻塞门，verifier-phase-gates #2492）

`check.decision-coverage-verify`：**14/14 honored，not_honored = []**。D-01..D-14 全部可在交付物中追到实现/记录（D-01 门序代码 / D-02 行语义零改动 diff / D-03 调用面普查 / D-04 转移表 + S-05..S-12 / D-05 474 行注册 / D-06 发射字面量 / D-07 harness 字节一致 + cpdamage 零 diff / D-08 live 实跑统计 / D-09 UAT Part 1 全文 / D-10 方言门 + Lua 5.0.3 实跑 / D-11 porcelain 0 / D-12 bbcheck+diff-check / D-13 7×8 + 泄漏围栏 / D-14 UAT 协议 + 本机证据记录）。

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| （5 个交付文件） | - | TBD/FIXME/XXX、placeholder 类串、空实现/空数据桩 | 无命中 | 无 |
| classes/druid/selftest.lua | 760 | "target.distance API not available on this client" | ℹ️ Info | 前 phase 遗留的合法测试断言消息，位于 phase diff 之外，非本 phase 引入 |

**Debt marker 门：** 0 阻断（无未引用债务标记）。

### Code Review Warning 状态（30-REVIEW.md，advisory、非阻塞）

| ID | 内容 | 现状（截至验证） | 是否破坏 must_have |
| --- | --- | --- | --- |
| WR-01 | 下跳谓词把 Rip 等连击点终结技机械视为咬击锚 → 非 D-09 采集下污染数据 | **仍开放**：HUMAN-UAT 采集协议节未见"采集全程禁 Rip/非5星咬"显性豁免行；数据有效性仍仅靠 D-09 前置程序性保障（part 1 全文在场） | 否 — 状态机按锁定协议实现，D-04/D-06 语义完整 |
| WR-02 | UAT 排查条目把 GCD 探针错误归因到 [cpBuildT] 通道 | **仍开放**：Part 6 仍为单通道归因（"无 ok 无 fail — 查…GCD 探针黄色警告…"未拆分双通道） | 否 — 文档质量项，UAT 锚点 truth 不受影响 |
| WR-03 | events.lua 两处 resetCpBuildDki 无守卫调用，Druid.lua 编译失败会级联打断分支逻辑 | **仍开放**：events.lua:77/99 仍为直接调用（首句位置风险最大） | 否 — 正常路径零行为变化；加固建议 |
| IN-01..IN-04 | 路径拼写（toolsls 误写）、decodeJson 死代码（D-07 冻结面）、--rake-dur 无下界、selftest 临时档写 CWD | 存续（IN-02 为刻意的冻结纪律，勿动） | 否 |

**结论：** 3 Warning + 4 Info 全部 advisory；无一触及 must_have truth 或 D-01..D-14 契约。可随 HUMAN-UAT 反馈或后续 phase 处置（WR-03 建议采纳——两行免费守卫与 handler 内其它宏调用同构）。

### Human Verification Required（需人类测试 — 见 frontmatter human_verification 全表）

1. **游戏内 /mt 全绿** — Windows+Cygwin rebuild 后客户端跑 Category S-05..S-12，零红色 FAIL。本机进程内复现已 8/8 通过，客户端执行是权威确认。
2. **目标态循环实机采集** — 热开开关 → 观察 [cpBuildT] ok/fail 行 → 关闭开关零新行（D-09 前置：目标态循环，非硬打 Rake 补贴循环）。
3. **实机重置路径** — 战斗中切换目标/脱战不新增行（bypass 2 真实事件投递）。
4. **用户机 Lua 5.0 原机重跑 + 真实日志解码** — `lua tools/cpbuild.lua --selftest` ALL PASSED + 真实 SuperMacro 存档报告核对（本机 5.0.3 已绿，用户机确认零环境差异）。
5. **WINDOWS.md unrun-verify 账本闭环** — 逐项勾销。

### Gaps Summary

**无 gap。** 14/14 truth 全部核实（静态证据 + 本机 Lua 5.0.3 进程内行为证据），5 个 artifact 三层验证（存在/实质/接线）+ 数据流 Level 4 全流经，7 条 key link 全接线，决策覆盖 14/14，无债务标记、无阻断反模式。剩余 5 项实机人工验证为 D-14 现实与用户 2026-09-10 拍板的 manual-only 处置（30-VALIDATION.md），已按 verifier 格式列为 human_verification 条目（非 FAIL 非 PRESPENT_BEHAVIOR_UNVERIFIED——锁定协议的可执行语义已由本机进程内执行获得行为证据）。3 条 review Warning 记录在案、advisory 开放。

---

_Verified: 2026-09-10T15:56:58Z_
_Verifier: Claude (gsd-verifier)_
