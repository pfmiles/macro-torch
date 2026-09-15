---
phase: quick
plan: 260915-udx
quick_id: 260915-udx
slug: energy-tick-macrotorch-log-probetick-ene
subsystem: druid-cat 能量 tick 探针改走 macroTorch.log（probeTick 桶与 energyProbeLog 包装删除，聊天显式输出）
tags: [druid-cat, energy-tick, probe, macroTorch-log, chat-visible, guard-simplify, lua50]
status: complete
date: 2026-09-15
one_liner: "energy tick 探针复用 macroTorch.log：删除 probeTick 独立存储桶（2500）与 energyProbeLog 包装函数，三文件六路 EPR 行（SES/EV/POLL/RAW/CAST/REL）全部直调 macroTorch.log——聊天窗口显式输出（ON 状态持续提醒，by design）+ 落共享 MACRO_TORCH_LOG.messages（LOG_MAX_SIZE 裁剪），守卫从 energyProbe+energyProbeLog 双开关化简为 energyProbe 单开关（9 插入 21 删除，1 原子 commit）"
key_files:
  modified: [classes/druid/energy_probe.lua, core/events.lua, classes/druid/cat.lua]
decisions:
  - "GATE 3 probe-routing 与 GATE 6 show-call-invariant 首轮 FAIL 均为执行器自转录缺陷（Bash 工具层给单引号内的双引号多加反斜杠），以计划逐字原文重跑全绿、文件零改动——与 260915-tt3 偏差 2/3 同型（电池脚本缺陷而非文件缺陷）"
  - "energy_probe.lua:17 模块头注释 'SavedVariables-only' 措辞随本次 refactor 语义过期，但按锁定范围（命名删除区外 additive-only）原样保留，偏差照实记录"
commits:
  code: a80fe39
duration_seconds: 480
estimate:
  tokens: 26000
  raw_tokens: 13000
  tasks: 2
  confidence: low
actuals:
  tokens: 693
  raw_tokens: 693
  tasks: 2
  commits: 1
---

# Quick 260915-udx Summary

energy tick 相位取证探针（260915-tt3 装置）按其用户反馈（design brief 260915-udx）从专用存储通道改走共享日志通道：删除 `MACRO_TORCH_LOG.probeTick`（2500 上限桶）与 `macroTorch.energyProbeLog` 包装函数，三个文件中的六路 EPR 行（SES/EV/POLL 于 energy_probe.lua、RAW/CAST 于 core/events.lua、REL 于 cat.lua）全部直调 `macroTorch.log` —— 同时获得聊天窗口显式输出（探针开启的持续提醒，by design）与既有 `MACRO_TORCH_LOG.messages` 共享缓冲持久化（`LOG_MAX_SIZE` 裁剪）；守卫从 `energyProbe and energyProbeLog` 双开关化简为 `energyProbe` 单开关。改面恰 3 文件（9 插入 21 删除）、恰 1 个原子 commit、message 逐字锁定、build_order.txt 零改动、`SM_Extend.lua` 由 build.sh 重建（gitignored，未手改、未进 git）。计划全部锁点逐字落地，GATES 1-7 + TASK1 COMMIT OK + TASK2 ALL GATES OK 全绿。

## 任务完成

| 变更 | 文件 | 内容 |
|------|------|------|
| (a) Edit 1 删除包装 | classes/druid/energy_probe.lua | 原 25-35 行整块删除（5 行函数文档注释 + `function macroTorch.energyProbeLog(line)` + 4 行体 + `end`，恰 11 行）；前后锚点行（`end` / 空行 / `-- Per-event-name baselines...` 注释）一字不动 |
| (a) Edit 2 三调点直调 | classes/druid/energy_probe.lua | `macroTorch.energyProbeLog(string.format(` → `macroTorch.log(string.format(` replace_all 恰命中 3 处（EV 行 / SES 行 / POLL 行，函数定义已删无剩余可误伤），模板与实参逐字不动；nil-guard、local 状态表、CreateFrame、4 事件注册、OnUpdate 累积、PEW 重置全部保留 |
| (b) Edit C CAST | core/events.lua | 守卫 `if macroTorch.energyProbe and macroTorch.energyProbeLog and pendingName == 'Reshift' then` → `if macroTorch.energyProbe and pendingName == 'Reshift' then`；body 改调 `macroTorch.log`，模板逐字不动；pendingName 捕获块（135 行）与 bridge 消费块一字不动 |
| (b) Edit B RAW | core/events.lua | 守卫去掉 `macroTorch.energyProbeLog and` 合取；body 改调 `macroTorch.log`，模板逐字不动；只读落穿不回 return |
| (c) Edit D REL | classes/druid/cat.lua | 守卫化简为 `if macroTorch.energyProbe then`；body 改调 `macroTorch.log`，模板逐字不动；show 调用（405-411）与 `reshift('ready')`（415）一字不动 |

提交：`a80fe39` — `refactor(260915-udx): route energy probe lines through macroTorch.log (visible + shared persistence) instead of dedicated probeTick bucket`（恰 3 文件、9 insertions、21 deletions）。`.planning/` 工件（PLAN.md / 本 SUMMARY / STATE.md 表行）由 quick 流程 docs commit 收口，代码 commit 零夹带。

## 验证电池结果

- **GATE 1**（源码范围 token 归零 + 保留躯干）全达标：probeTick / energyProbeLog 在 classes/ core/ build_order.txt 均 0；`function macroTorch.energyProbeLog` 残留 0；nil-guard 1、RegisterEvent 4、SetScript 2。
- **GATE 2**（六模板逐字各恰 1 处、各自原文件）SES/EV/POLL/RAW/CAST/REL 六项全 1。
- **GATE 3**（守卫字面量 + 直调路由 + 旧合取清零 + 探针红线）RAW/CAST/REL 三条新守卫各 1；旧双开关合取残留 0；`macroTorch.log(string.format("EPR|` 计数 3/2/1；`DEFAULT_CHAT_FRAME`/`SendChatMessage`/`macroTorch.show` 在探针文件 0（红线未破）。
- **GATE 4** `./build.sh` 成功；产物含六前缀；产物 probeTick / energyProbeLog 均 0。
- **GATE 5** 语法门：`luac -p` 三源 + 产物全过；`LUA50-LOADFILE-OK`（/tmp/luabuild/lua-5.0.3/bin/lua 正门，未降级）。
- **GATE 6** 全仓 token 扫（除 .git/.planning）energyProbeLog / probeTick 均 0；pendingName 捕获、reshift 调用、show 调用三不变式各 1；`git diff --check` 干净；新增行非 ASCII 0、CR 0；三源 + build_order.txt 无 CR 字节（全 LF）。
- **GATE 7** 变更面恰 3 文件（porcelain 豁免 orchestrator 的 `?? .planning/` 行）；SM_Extend.lua 稳居 gitignore（精确命中）；build_order.txt 零进入。
- **TASK1 COMMIT OK**：message 逐字复核一致；committed file set 恰 3 文件；跨提交 0 意外删除。
- **TASK2 ALL GATES OK**（对 HEAD 复跑）：提交后代码残留 0、message/文件集复核一致；`./build.sh` + `luac -p` 产物 + 5.0.3 `LUA50-LOADFILE-OK`；产物 probeTick 0、六前缀齐；`git diff --check HEAD~1 HEAD` 干净。

## Deviations from Plan

**代码零偏差**：五处 Edit（1 删除块 + 4 处守卫/body 改写）全部按计划锁定 before/after 逐字落地，六模板逐字不变，既有语句零移动零重排零重缩进（与 260915-tt3 偏差 1-4 同型的电池脚本缺陷另计，见下）。

1. **[GATE 3 probe-routing / GATE 6 show-call-invariant 首轮 FAIL — 执行器自转录缺陷]** 首轮电池转写时给单引号模式内的双引号（`'macroTorch.log(string.format("EPR|'`）多加了反斜杠，grep 固定串不匹配导致假失败；GATE 6 一行因转义层行错位产生 parse error、输出不可信，两门均以计划逐字原文重跑（文件零改动）全绿，并以逐项打印原始值（A-I/G7a 各值与期望逐一目视核对）收官。与 260915-tt3 偏差 2/3 同型：电池脚本缺陷，非文件缺陷。
2. **[锁定范围偏差 — 模块头注释措辞过期]** `classes/druid/energy_probe.lua:17` 模块头注释「... flag-gated, additive-only, **SavedVariables-only** instrumentation」的 SavedVariables-only 措辞随本次 refactor 语义过期（现经 macroTorch.log 同时聊天可见 + 持久化），但该行在锁定改动清单之外，按「命名删除区外是 additive-only」约束原样保留。计划 Task 2 点名要求照实记录。

## Unrun Verification（经 /mt 实机电池，本机无 WoW 客户端）

**行为差说明（design brief 点名）：**

- **(a)** 逐行聊天输出现在是 ON 状态的**持续提醒，by design**：`EPR|SES`/`EPR|EV`/`EPR|POLL`/`EPR|RAW`/`EPR|CAST`/`EPR|REL` 行出现在 DEFAULT_CHAT_FRAME 即探针开启的可见证据；关闭仅需 `/run macroTorch.energyProbe = false`（无需 reload）。
- **(b)** 实机使用指引：EPR 行量大（每能量事件/每 1 秒轮询一行），`macroTorch.log` 共享缓冲裁剪上限默认 `LOG_MAX_SIZE = 500`，完整会话留档必须先调高：`/run macroTorch.LOG_MAX_SIZE = 10000`（约 10 分钟会话量级示例；该缓冲与 cpBuildLog 等其他 macroTorch.log 流量共享，各自流量会互相挤占）。

**用户 Windows+Cygwin 重建 `/mt` 后的验证清单：**

1. 默认关（energyProbe false，每次登录由 nil-guard 重挂）：宏行为与改动前一致，零 EPR 输出。
2. `/run macroTorch.energyProbe = true` 后猫形态等待若干 tick——**聊天窗口应立即出现** `EPR|SES`（PEW 时）/`EPR|EV`（UNIT_ENERGY/UNIT_MANA 触发）/`EPR|POLL`（约每 1 秒）等行（这是与 tt3 的行为差：聊天可见性）；Reshift 释放出现 `EPR|CAST`/`EPR|REL`，'nergize' 行出现 `EPR|RAW`。
3. `/run ReloadUI()` 退出后查 `WTF/Account/<账号>/SavedVariables/SuperMacro.lua` 的 `MACRO_TORCH_LOG.messages`：EPR 各行与其他 log 流量同存于共享 messages 列表，**无** `MACRO_TORCH_LOG.probeTick` 段。
4. 换形态/脱战开关一次：`form` 字段跟随形态变化；`/run macroTorch.energyProbe = false` 后立即静默（无需 reload）。
5. 确认内存/聊天无 probeTick 字样残留（聊天空白行与 SavedVariables 两处入手）。

## Threat Flags

无超出计划威胁模型的新表面：聊天可见性即 design brief 的 T-260915-udx-02（accept，用户点名要的可见证据，与既有 macroTorch.log 各调用同暴露面）；T-260915-udx-01（刷屏 + 缓冲）由默认 false 会话级 opt-in + LOG_MAX_SIZE 裁剪缓解，SUMMARY (b) 已给会话级上调指引；T-260915-udx-03 由单开关守卫简化 nil 路径 + macroTorch.log 自带首次写 nil-guard 缓解。零包管理器安装（T-SC 不适用）。改面仅 3 行守卫 + 3 行 body 的既有通道改写，未引入任何新端点或写入边界。

## Self-Check: PASSED

- `git log --oneline -3 | head -1` → `a80fe39 refactor(260915-udx): route energy probe lines through macroTorch.log (visible + shared persistence) instead of dedicated probeTick bucket`，message 逐字一致。
- `git diff HEAD~1 HEAD --name-only | sort` → 恰 `classes/druid/cat.lua` / `classes/druid/energy_probe.lua` / `core/events.lua` 三文件。
- `git diff HEAD~1 HEAD --numstat` → `2 2` / `3 15` / `4 4` = 9 insertions、21 deletions，与锁定「9 行改写 + 11 行删除（纯删除区）+ 行内合并余量」口径吻合（三处守卫行各含 1 改写行 + 1 body 改写行；删除块 11 行纯删除，其余 10 删除行为守卫/body 旧行替换）。
- `git status --porcelain | grep -v '^?? .planning/'` → 空（零残留）。
- SUMMARY 存在绝对路径：/home/admin/workspace/macro-torch/.planning/quick/260915-udx-energy-tick-macrotorch-log-probetick-ene/260915-udx-SUMMARY.md