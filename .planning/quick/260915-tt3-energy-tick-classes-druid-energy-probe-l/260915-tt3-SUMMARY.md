---
phase: quick
plan: 260915-tt3
quick_id: 260915-tt3
slug: energy-tick-classes-druid-energy-probe
subsystem: druid-cat 能量 tick 相位取证探针（energy_probe.lua 新建 + build_order.txt + core/events.lua + classes/druid/cat.lua）
tags: [druid-cat, energy-tick, forensics, probe, flag-gated, savedvariables, events, reshift, lua50]
status: complete
date: 2026-09-15
one_liner: "on-client 取证探针（非产品逻辑）：energyProbe 开关默认 OFF、关闭时既有行为逐字节等价；开启后 SES/EV/POLL/RAW/CAST/REL 六路 EPR 行只进 MACRO_TORCH_LOG.probeTick（2500 上限，零聊天输出），五路能量/客户端信号原始时间线落盘供 tick-test-3 离线比对"
key_files:
  created: [classes/druid/energy_probe.lua]
  modified: [build_order.txt, core/events.lua, classes/druid/cat.lua]
decisions:
  - "GATE 5/GATE 11 porcelain 精确匹配豁免 orchestrator 未跟踪 planning 目录（与 260914-49l 偏差 3、260914-u4l 偏差 3 同型），并以行集相等（非 tr 拼接串）实证变更面恰为锁定文件"
  - "GATE 7 RAW 分支头行号按 C 插入 +6 行修正锚点 145→151（sed 字节级钉死），既有语句零移动零删除由跨提交 0 deletions 实证"
  - "GATE 8 energyProbe 字面量计数以 energyProbe|energy_probe 双拼写复核：build_order.txt 行是 snake_case 路径（classes/druid/energy_probe.lua），camelCase 字面量恒不匹配"
commits:
  code: bf47ecc, d9319f2
duration_seconds: 251
estimate:
  tokens: 32000
  tasks: 2
actuals:
  tokens: 1677
  raw_tokens: 1677
  tasks: 2
  commits: 2
---

# Quick 260915-tt3 Summary

energy tick 相位取证探针（tick-test-3 前序装置）：新建 `classes/druid/energy_probe.lua`（129 行，flag-gated、additive-only、只落 SavedVariables）+ `build_order.txt` druid 块末尾加行 + `core/events.lua` RAW/CAST 两处门控透传 + `classes/druid/cat.lua` readyReshift 释放点 REL 透传。计划三任务全绿，两个原子 commit 逐字锁定 message，`SM_Extend.lua` 由 build.sh 重建（gitignored，未手改、未进 git）。

## 任务完成

| 变更 | 文件 | 内容 |
|------|------|------|
| A — 探针模块（新建） | classes/druid/energy_probe.lua | 锁定的九个部分齐全：Apache-2.0 头注释 + 模块说明行、`macroTorch.energyProbe` nil-guard 默认 false（macro_torch.lua cpBuildLog 模式）、`macroTorch.energyProbeLog`（MACRO_TORCH_LOG 双保险 nil-guard + `probeTick={messages={},maxSize=2500}` + `macroTorch.tableLen`/`table.remove` trim）、local 状态（lastEnergy/lastTime 按 event 名分桶 + lastPollEnergy/pollAccum）、独立 CreateFrame 注册 UNIT_ENERGY/UNIT_MANA/CHAT_MSG_SPELL_PERIODIC_SELF_ENERGIZE/PLAYER_ENTERING_WORLD 四事件 + OnUpdate/OnEvent、PEW 会话行（SES：form 经 pcall+classMetatable getter 防御式读取、net 经 pcall(GetNetStats) '/' 相连或 'pcfail'）、EV 共享 emitter（每事件 UnitMana 恰 1 调 2 返回、d/dt 按事件名分桶 math.floor、零增量不滤除）、OnUpdate 累积轮询（≥1.0 记一条后累减不回零、关闭时 pollAccum 归零短路）、SES/EV/POLL 三模板逐字各恰 1 处 |
| A — build_order 加行 | build_order.txt | druid 块末尾（35 行 `classes/druid/leveling.lua` 之后、36 行 Hunter 注释之前）净增恰 1 行 `classes/druid/energy_probe.lua`，零删除零重排 |
| B — RAW 门控透传 | core/events.lua | RAW_COMBATLOG 分支顶部（head 之后、cpDamage gate 之前）纯插入 3 行：`macroTorch.energyProbe and macroTorch.energyProbeLog and arg2 and string.find(arg2, 'nergize')` 守卫 + `EPR|RAW|t=%.3f|ch=%s|txt=%s` 行；只读 arg1/arg2 落穿到底，无 return |
| C — CAST 捕获 + 尾插 | core/events.lua | UNIT_CASTEVENT CAST 块顶部（既有 bridge 消费/nil 之前）捕获 `local pendingName = macroTorch._pendingCastSpellName` + 2 行英注释；块逻辑之后尾插 `pendingName == 'Reshift'` 守卫 + `EPR|CAST|t=%.3f|spell=%s|e=%s` 行（UnitMana 恰 1 读）；既有语句零移动零重缩进 |
| D — REL 释放点前插 | classes/druid/cat.lua | readyReshift 内 `macroTorch.player.reshift('ready')`（原 412 行）之前纯插入 3 行：双守卫 + `EPR|REL|t=%.3f|e=%s|next=%s|cost=%s|earn=%s` 行（复用 nextMove/nextAbilityCost 形参与 show 调用同款 earning 表达式）；show 调用一字不动 |

提交：
- `bf47ecc` — `feat(260915-tt3): add druid energy tick forensics probe module and build_order entry`（恰含 build_order.txt 1 insertion + energy_probe.lua 129 insertions = 130，0 deletions）
- `d9319f2` — `feat(260915-tt3): gate raw/cast/reshift energy taps behind macroTorch.energyProbe`（恰含 events.lua 9 insertions + cat.lua 3 insertions = 12，0 deletions）

`.planning/` 工件（PLAN.md / 本 SUMMARY / STATE.md 表行）由 quick 流程 docs commit 收口，两个代码 commit 零夹带。

## 验证电池结果

- **GATE 1**（结构 grep 绝对计数）全部达标：nil-guard 1、SES/EV/POLL 模板各 1、probeTick 2500 init 1、chat energize 事件名 1、build_order 行 1、零重复行。
- **GATE 2**（探针红线）全部：`macroTorch.show`/`DEFAULT_CHAT_FRAME`/`SendChatMessage` 0、`goto`/`::` 0、`#` 运算符形态 0、非 ASCII（CJK）0、CR 字节 0（全 LF）。
- **GATE 3** `./build.sh` 成功，产物含 `EPR|SES`。
- **GATE 4**（语法三门）`luac -p` source/product 均过，`LUA50-LOADFILE-OK`（/tmp/luabuild/lua-5.0.3/bin/lua 正门）——5.0.3 语法验证按前置条件未降级。
- **GATE 5** 变更面恰 2 文件 + SM_Extend.lua 稳居 gitignore（`git check-ignore` = 精确命中）；见偏差 1/2。
- **GATE 6** 三处透传逐字各恰 1 处、events 守卫 2、cat 守卫 1，全达标。
- **GATE 7** 既有语句零移动：bridge block 计数 1、reshift 调用计数/位置（412→415）不变、show 调用行不变、跨两文件 diff 删除行 0；RAW 分支头字节级钉死于修正锚点 151（见偏差 3）。
- **GATE 8** 4 文件全有探针引用（见偏差 4 双拼写复核）。
- **GATE 9** 追加行无 `goto`/`::`/非 ASCII/CR；`git diff --check` 干净。
- **GATE 10** 全量构建 + 六前缀（SES/EV/POLL/RAW/CAST/REL）全齐 + luac -p ×3 + `LUA50-LOADFILE-OK`。
- **GATE 11** 变更面恰 2 文件（planning 目录豁免，见偏差 1）。
- **Task 3 提交后复核**（对 HEAD 复跑）：porcelain 除未跟踪 planning 目录外 0 行代码残留；`./build.sh` + `luac -p SM_Extend.lua` + 5.0.3 loadfile 三门全过；`git diff HEAD~2 --stat` 恰 4 文件 142 insertions 0 deletions；两条 commit message 逐字复核一致。

## Deviations from Plan

**代码/文本零偏差**：五处落笔（1 个新建文件 + 3 处 Edit + 1 行 build_order）全部按计划锁定 before/after 逐字落地，既有语句零移动零重排零重缩进（跨提交 0 deletions 实证）。以下 4 项均为验证电池脚本自身的缺陷/环境既有事实（与 260914-49l 偏差 3、260914-u4l 偏差 3 同型处理），在真实 diff 上逐项实证意图成立后如实记录：

1. **[GATE 5/GATE 11 变更面 porcelain 检查]** `git status --porcelain` 全程多出 `?? .planning/quick/260915-tt3-.../` 一行——planning 目录为本 quick 工作目录（保存 PLAN.md 与本 SUMMARY），orchestrator 所有、约束明令不得提交，执行起点即已存在。与 260914-49l/u4l 偏差 3 同型：显式豁免该行后，变更面恰为各 task 的锁定文件集；另加豁免行数审计（恒 1 行、无其他中间产物）。计划「背景事实」所记 porcelain 为空系规划期间早于本目录创建时采样。
2. **[GATE 5 对比串的管道产物缺陷]** 计划电池 `$(git status --porcelain | LC_ALL=C sort | tr '\n' '|')` 会把最后一条记录的换行也转成结尾 `|`，而锁定期望串 `" M build_order.txt|?? classes/druid/energy_probe.lua"` 无结尾 `|`——按原文恒不可能相等（即使计划自身预期的两文件场景也照fail）。**处理**：改为行集相等（`printf` 期望两行 vs 实际两行直接比较），语义更强且不依赖拼接符号。
3. **[GATE 7 RAW 分支头锚点算术缺陷]** 计划注释认定「RAW 分支头 145 行位置不受 B 影响——B 插入在其后」，但忽视了 C 插入在该分支**之前**（+3 行 capture 块 + +3 行 CAST tap = +6），头实际移至 **151** 行。`sed -n '151p'` 经字节级验证与锁定 before 头逐字一致；加上 0 deletions、bridge block 计数 1、reshift 位置 415 三项不变式全过，既有语句零移动意图实证成立。**处理**：以修正锚点 151 重跑，不改动文件。
4. **[GATE 8 camelCase 字面量在 build_order.txt 恒不匹配]** 计划电池对 4 文件 grep `energyProbe`（camelCase），但 build_order.txt 中的探针引用是路径 `classes/druid/energy_probe.lua`（snake_case 下划线），该字面量恒不匹配。**处理**：以 `energyProbe|energy_probe` 双拼写复核，4 文件全有探针引用，意图（4 个改动文件全含探针锚点）成立。

## Unrun Verification（经 /mt 实机电池，本机无 WoW 客户端）

用户 Windows+Cygwin 重建 `/mt` 后：

1. 默认关（energyProbe false）：宏行为与改前完全一致，无任何 EPR 输出。
2. 登录后 `/run macroTorch.energyProbe = true`：猫形态下等 20 个能量 tick 周期后 `/run ReloadUI()`；退出后查 `WTF/Account/<账号>/SavedVariables/SuperMacro.lua` 的 `MACRO_TORCH_LOG.probeTick.messages`：应含 EPR|SES（PEW 时）、EPR|EV（UNIT_ENERGY/UNIT_MANA 每次触发，含零增量行）、EPR|POLL（约每 1 秒）、EPR|RAW（'nergize' 行）、EPR|CAST（每次 Reshift 释放）、EPR|REL（readyReshift 判定释放时），总数 ≤2500，聊天窗口零输出。
3. 换狼/熊形态或脱战切换开关：`form` 字段跟随形态变化，关闭后输出立即停止（无需 reload）。
4. 采样数据交离线分析对比 UNIT_ENERGY 与 POLL 公差序列验证 tick 相位假设。

## Threat Flags

无超出计划威胁模型的新表面：探针唯一写入边界仍是 客户端脚本 → 本地 SavedVariables（T-*-01 由 maxSize=2500 + tableLen/table.remove trim 缓解并已 GATE 1 钉死；T-*-03 由全 tostring + energyProbe/energyProbeLog 双守卫缓解）；零包管理器安装（T-SC 不适用）。

## Self-Check: PASSED

- `test -f classes/druid/energy_probe.lua && echo FOUND` → FOUND
- `git log --oneline -2` → `d9319f2 feat(260915-tt3): gate raw/cast/reshift energy taps behind macroTorch.energyProbe` / `bf47ecc feat(260915-tt3): add druid energy tick forensics probe module and build_order entry` 逐字一致
- `git diff HEAD~2 --stat` → 恰 4 文件、142 insertions、0 deletions
- SUMMARY 存在绝对路径：/home/admin/workspace/macro-torch/.planning/quick/260915-tt3-energy-tick-classes-druid-energy-probe-l/260915-tt3-SUMMARY.md