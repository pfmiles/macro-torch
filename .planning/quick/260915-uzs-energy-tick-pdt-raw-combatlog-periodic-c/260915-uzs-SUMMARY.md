---
phase: quick
plan: 260915-uzs
quick_id: 260915-uzs
slug: energy-tick-pdt-raw-combatlog-periodic-c
subsystem: druid-cat energy tick 探针 PDT 双传输扩展（RAW_COMBATLOG + chat 通道）
tags: [druid-cat, energy-tick, probe, pdt, periodic-damage-tick, dual-transport, raw-combatlog, chat-channel, lua50]
status: complete
date: 2026-09-15
one_liner: "energy tick 探针 PDT 双传输扩展：core/events.lua 三处纯插入（恰 9 插入 0 删除、1 文件、1 原子 commit）——RAW_COMBATLOG tier-1 白名单后新增 EPR|PDT tx=RAW tap，两个原先为空的 CHAT_MSG_SPELL_PERIODIC_*_DAMAGE 分支体各新增 EPR|PDT tx=CHAT tap；同一 tick 事件经 RAW 与 chat 双传输两行落 macroTorch.log（tx 字段区分，离线比对到达时序），无法术白名单全量落盘；复用 energyProbe 单开关，默认关闭三 tap 全部短路零输出"
key_files:
  modified: [core/events.lua]
decisions:
  - "零偏差执行：G1-G3 预检全绿（HEAD 37c2234，三条锚文本与规划背景事实逐字一致）、三处 Edit 一次命中逐字落地、GATES 4-8 与 T2a-e 首轮全绿零修复；Lua 5.0.3 正门 /tmp/luabuild/lua-5.0.3/bin/lua 在位（G8e 全强度通过），规划预留的 5.0.3 降级口径未触发"
  - "unrun-verify 项按执行器规范追加 .planning/WINDOWS.md 台账（kind unrun-verify）：EPR|PDT 实机电池（tx=RAW 与 tx=CHAT 双行出现）需用户在 Windows+Cygwin 重建 /mt 后验证——未 commit，随 .planning 工件由 orchestrator docs commit 收口"
commits:
  code: 344a81a
duration_seconds: 450
estimate:
  tokens: 32000
  raw_tokens: 16000
  tasks: 2
  confidence: low
actuals:
  tokens: 157
  raw_tokens: 157
  tasks: 2
  commits: 1
---

# Quick 260915-uzs Summary

energy tick 取证探针（tt3/udx 装置）按其 design brief 260915-uzs 扩展 periodic-damage-tick（PDT）通道：RAW_COMBATLOG 分支里 tier-1 白名单放行的两个 periodic 通道（creature/hostileplayer）每一条 tick 行以 `EPR|PDT|t=%.3f|tx=RAW|ch=<arg1>|txt=<arg2>` 落 `macroTorch.log`；两个原先为空的同名 chat 消息分支体各插入一个 `tx=CHAT` tap——同一 tick 事件经 chat 过滤通道与 RAW_COMBATLOG 双传输两行落盘，tx 字段区分传输，离线比对到达时序。**无法术白名单、无规律性假设**：全量样本落盘，通道/使用决策由离线分析器定。改面恰 1 文件 `core/events.lua`（9 插入 0 删除）、恰 1 个原子 commit（message 逐字锁定），`SM_Extend.lua` 由 build.sh 重建（gitignored，未手改、未进 git），`energy_probe.lua`/`cat.lua`/`build_order.txt` 零触碰。G1-G3 预检、GATES 4-8、TASK1 COMMIT OK、T2a-e 全部首轮绿灯。

## 任务完成

| 变更 | 文件 | 内容 |
|------|------|------|
| Edit 1 PDT-RAW tap | core/events.lua | tier-1 白名单 `return`/`end` 之后、`-- Tier 2 + Tier 3 (substring precheck + registered spell match):` 注释之前插入恰 3 行（8/12/8 空格缩进）：守卫 `if macroTorch.energyProbe and macroTorch.log and arg2 then` + `macroTorch.log(string.format("EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s", GetTime(), "RAW", tostring(arg1), tostring(arg2)))` + `end`。落地行 179-181；白名单 return 先行，arg1 被保证为两 periodic 通道之一、tap 只读落穿不消费 |
| Edit 2 PDT-CHAT tap creature | core/events.lua | 原为空的 `elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then` 分支体插入恰 3 行（守卫 `if macroTorch.energyProbe and macroTorch.log and arg1 then` + `EPR|PDT|...` 行 `tx="CHAT"`、`ch=tostring(event)`、`txt=tostring(arg1)` + `end`）；原空行原样保留在插入行之后。落地行 125-127 |
| Edit 3 PDT-CHAT tap hostileplayer | core/events.lua | 同形状，原为空的 `elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then` 分支体插入恰 3 行；原空行原样保留。落地行 130-132 |

提交：`344a81a` — `feat(260915-uzs): capture periodic damage ticks in probe via EPR|PDT dual transport (RAW + CHAT)`（message 逐字复核一致；1 file changed, 9 insertions(+)，跨提交 0 意外删除）。`.planning/` 工件（PLAN.md / 本 SUMMARY / STATE.md 表行 / WINDOWS.md 台账追加）由 quick 流程 orchestrator docs commit 收口，代码 commit 零夹带。

## 验证电池结果

- **G1** 预检全绿：G1a COLLISION-FREE（`git grep -cF 'EPR|PDT'` 全仓 tracked 0，名字冲突零）；G1b TREE-CLEAN（porcelain 除 orchestrator 的 `?? .planning/` 外零）。
- **G2** 新字面量基线全 0：PDT 模板 0、arg2 守卫 0、arg1 守卫 0（改前计数）。
- **G3** 锚文本（人工 cat -A 目视）：124/126 两空分支、152 nergize gate、170-173 tier-1 白名单 + Tier-2 注释、181-182 循环头——与规划背景事实逐字一致，LF 行尾无 CR。
- **G4** 新字面量锁定计数：模板 `EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s` == 3；RAW 守卫（arg2）== 1；CHAT 守卫（arg1）== 2。
- **G5** 既有六路 EPR 模板计数保持 udx 态：events.lua `EPR|RAW|` == 1、`EPR|CAST|` == 1；cat.lua `EPR|REL|` == 1；energy_probe.lua `EPR|SES|`/`EPR|EV|`/`EPR|POLL|` 各 == 1。
- **G6** 既有不变式字面量（生产代码零扰动）：tier-1 白名单 == 1、auraApplySpellPatterns 循环头 == 1、nergize gate == 1、cpDamage gate == 1。
- **G7** 纯插入 + diff 卫生：numstat 恰 `9 0 core/events.lua`；变更文件恰 1 个；`git diff --check` 干净；新增行 CR 0、非 ASCII 0。
- **G8** 构建 + 语法门：`./build.sh` 成功；产物 `SM_Extend.lua` 含 EPR|PDT（≥1）且六前缀全齐；`/usr/bin/luac -p` 过 core/events.lua 与产物；**Lua 5.0.3 正门 `LUA50-LOADFILE-OK`（未降级）**；`git check-ignore SM_Extend.lua` 精确命中（不手改、不进 commit）。
- **TASK1 COMMIT OK**：message 逐字一致；`git show --stat` 1 file changed, 9 insertions(+)；`git diff HEAD~1 HEAD` 文件集恰 core/events.lua、numstat 恰 `9 0`。
- **TASK2 ALL GATES OK**（对 HEAD 复跑）：T2a 提交后代码残留 0；T2b 模板 == 3；T2c 守卫 1+2；T2d `git diff --check HEAD~1 HEAD` 干净；T2e `./build.sh` + `luac -p` 双门 + 5.0.3 `loadfile` 全过。

## Deviations from Plan

**None - plan executed exactly as written.** 三处 Edit 一次命中（锚文本逐字、零覆盖既有语句）、全部 GATE 首轮通过、零修复、零回退，Lua 5.0.3 正门在位故降级口径未触发。除计划锁定三处插入外，既有一切语句零移动、零重排、零重缩进、零措辞改动。

## Unrun Verification（经实机电池，本机无 WoW 客户端）

**(a) scope note（design brief 点名）**：本 quick 仅捕获**我方对 creature / hostile player 的 period damage**（两个 periodic-damage 通道，modifier 不影响语义：rancid 我方视角即怪物身上的我方流血伤害）。SELF 侧 periodic（怪物流血打在我方玩家身上，经 `CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE` 通道）与 PARTY / FRIENDLYPLAYER periodic 通道**未覆盖**。如未来需要，按同形状每个通道加一个分支即可（one-branch-per-channel follow-up），本期不做。

**(b) volume guidance update**：PDT 双传输落地后，探针全通道合计输出约 **3–4 行/s（战斗中）**；实机取完整会话必须上调共享缓冲：`/run macroTorch.energyProbe = true macroTorch.LOG_MAX_SIZE = 20000`（替代 udx 指引的 10000）。该缓冲与其他 macroTorch.log 流量（cpBuildLog 等）共享，会被互相挤占。

**(c) unrun-verify checklist**（Windows+Cygwin 客户端，执行器本机无 WoW；沿用 tt3/udx 清单 + 新增 PDT 条）：

1. 默认关（energyProbe false/nil，每次登录 nil-guard 重挂）：三 tap 全部短路，宏行为与改动前一致，零 EPR|PDT 输出、零新增持久化。
2. `/run macroTorch.energyProbe = true` 后猫形态等待若干 tick——聊天窗口立即出现 `EPR|SES`/`EPR|EV`/`EPR|POLL` 行（tt3/udx 基线）；Reshift 释放出现 `EPR|CAST`/`EPR|REL`，'nergize' 行出现 `EPR|RAW`。
3. `/run ReloadUI()` 退出后查 SavedVariables 的 `MACRO_TORCH_LOG.messages`：EPR 各行与其他 log 流量同存于共享 messages 列表，无 `MACRO_TORCH_LOG.probeTick` 段。
4. 换形态/脱战开关一次：`form` 字段跟随形态变化；`/run macroTorch.energyProbe = false` 后立即静默（无需 reload）。
5. **【新增本条】PDT 双传输**：对训练木桩保持 Rake/Rip 流血期间，聊天窗口必须出现 `EPR|PDT|...|tx=RAW|...` 与 `EPR|PDT|...|tx=CHAT|...` **两种行都要有**——同一 tick 事件双传输两行落盘，tx 字段区分；每行 ch 字段为 CREATURE 或 HOSTILEPLAYER periodic 通道名、txt 为该 tick 行全文。关闭开关后两行同时消失。
6. **[可选] 缓冲留档**：完整会话按 (b) 先 `/run macroTorch.energyProbe = true macroTorch.LOG_MAX_SIZE = 20000` 再开始。

## Threat Flags

无超出计划威胁模型的新表面：三处 tap 全部位于既有 `macroTorch.log` 通道之上（聊天可见 + `MACRO_TORCH_LOG.messages` 网格持久化），与既有 EPR 六路同暴露面；T-260915-uzs-01（高频输出 + 缓冲膨胀）由默认 false 会话级 opt-in + LOG_MAX_SIZE 裁剪缓解，(b) 已给显式上调指引；T-260915-uzs-02（tick 时序聊天可见）accept 不变（单机自看自用，用户点名要的到达时序证据）；T-260915-uzs-03（格式串/nil 路径）由全 tostring 纪律 + 双守卫 + RAW 侧白名单前置保证 arg1 合法缓解。零包管理器安装（T-SC 不适用）；无 stub/占位行、无新增端点或写入边界。

## Self-Check: PASSED

- `git log --oneline -1` → `344a81a feat(260915-uzs): capture periodic damage ticks in probe via EPR|PDT dual transport (RAW + CHAT)`，message 逐字一致。
- `git diff HEAD~1 HEAD --name-only | sort` → 恰 `core/events.lua` 一行。
- `git diff HEAD~1 HEAD --numstat` → 恰 `9	0	core/events.lua`。
- `git status --porcelain | grep -v '^?? .planning/'` → 代码零残留；仅 ` M .planning/WINDOWS.md`（本 SUMMARY 追加的 unrun-verify 台账，.planning 域由 orchestrator docs commit 收口，executor 绝不 commit）。
- 三 tap 落地行核验：RAW 守卫 179 / 模板 180；CHAT-creature 守卫 125 / 模板 126；CHAT-hostileplayer 守卫 130 / 模板 131。
- SUMMARY 存在绝对路径：/home/admin/workspace/macro-torch/.planning/quick/260915-uzs-energy-tick-pdt-raw-combatlog-periodic-c/260915-uzs-SUMMARY.md