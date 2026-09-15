---
quick_id: 260915-udx
slug: energy-tick-macrotorch-log-probetick-ene
subsystem: druid-cat
description: "energy tick 探针复用 macroTorch.log：删除 probeTick 独立存储桶与 energyProbeLog 包装函数，三文件门控写入点全部直调 macroTorch.log（屏幕显式输出 + 既有持久化/裁剪机制），守卫简化为 energyProbe 单开关（user feedback 260915-udx 锁定）"
date: 2026-09-15
phase: quick
plan: 260915-udx
type: execute
wave: 1
depends_on: [260915-tt3]
files_modified: [classes/druid/energy_probe.lua, core/events.lua, classes/druid/cat.lua]
autonomous: true
requirements: ["energy-probe-reroute@quick-260915-udx"]
estimate:
  tokens: 26000
  raw_tokens: 13000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "energyProbe 为 false/nil（默认，每次登录由 nil-guard 重挂）：core/events.lua 与 classes/druid/cat.lua 的三个 tap 点全部短路，既有语句改动前行为逐字节等价——零聊天输出、零持久化写入"
    - "energyProbe 为 true：六路 EPR 行按各自触发条件经 macroTorch.log 立即打印到聊天窗口（ON 状态显式提醒，by design）并落入 MACRO_TORCH_LOG.messages 共享缓冲（LOG_MAX_SIZE 裁剪）——全程无 probeTick 桶、无 energyProbeLog 包装"
    - "六模板字符串与 260915-tt3 逐字相同、各自原文件各恰 1 处；build.sh 成功，重建产物 SM_Extend.lua 含六前缀且零 probeTick / 零 energyProbeLog"
    - "/usr/bin/luac -p 过三个源文件 + SM_Extend.lua；Lua 5.0.3 loadfile 正门 LUA50-LOADFILE-OK"
    - "恰 1 个整单 commit（3 文件 1 原子 commit、message 逐字锁定）、build_order.txt 零改动、SM_Extend.lua 与 .planning 不进 commit"
  artifacts:
    - "classes/druid/energy_probe.lua：energyProbeLog 函数块（注释+函数体 11 行）整体删除；SES/EV/POLL 三个写入点直调 macroTorch.log，模板与实参逐字不动；nil-guard / local 状态表 / CreateFrame / 4 事件注册 / OnUpdate 累积 / PEW 重置全部保留"
    - "core/events.lua：RAW 守卫去掉 energyProbeLog 合取（147 行形态）、CAST 守卫同样化简；两条 body 改调 macroTorch.log，模板逐字不动；pendingName 捕获块一字不动"
    - "classes/druid/cat.lua：REL 守卫化简为 if macroTorch.energyProbe then，body 改调 macroTorch.log，模板逐字不动"
    - "./planning 侧：260915-udx-SUMMARY.md（Task 2，不进 commit）"
  key_links:
    - "macroTorch.log（interface_debug.lua:113-131，build order 18 = 展示到 DEFAULT_CHAT_FRAME + MACRO_TORCH_LOG.messages 共享裁剪）加载先于 core/events.lua(25) 与 classes/druid/energy_probe.lua(36)——直调零加载序风险"
    - "energyProbe nil-guard（energy_probe.lua:21-23）→ 三 tap 单开关守卫；去掉 energyProbeLog 合取零语义变化（该函数为探针模块常驻定义，模块加载后恒存在）"
    - "pendingName 捕获仍先于 bridge 消费/nil（events.lua:135），RAW tap 仍落穿不回 return、不消费 arg1/arg2"
---

# PLAN: energy tick 探针改走 macroTorch.log（260915-udx）

## 目标

**Goal（design brief 260915-udx 已锁定，只实现、不重新设计）**：把 260915-tt3 探针的专用存储（`MACRO_TORCH_LOG.probeTick` + `macroTorch.energyProbeLog` 包装函数）替换为共享日志通道 `macroTorch.log` —— 六路 EPR 行既显式打印到聊天（开启状态的持续提醒，用户点名要求）又落入既有 `MACRO_TORCH_LOG.messages`（`LOG_MAX_SIZE` 裁剪）。守卫从 `energyProbe and energyProbeLog` 双开关化简为 `energyProbe` 单开关。3 文件、1 原子 commit、build_order.txt 零改动。

**Purpose**: 用户反馈（260915-udx）：forensics 类功能应统一复用 `macroTorch.log`（聊天可见 + 共享持久化），不接受探针专用桶；聊天可见性从红线反转为目的。
**Output**: 3 文件 9 行改写 + 11 行删除，1 个 commit；重建后的 SM_Extend.lua 内置改后探针；SUMMARY.md（Task 2）。

## 锁定约束（违反即失败；逐字来自 design brief + 协调者勘误）

1. **字面量正源**：`macroTorch.log`（**无多余 r**，brief 中一处 `macroTororch.log` 系笔误，已由协调者勘误确认）。全计划所有锁点一律使用 `macroTorch.log`。
2. **3 文件、1 原子 commit、build_order.txt 零改动**。变更面恰为 `classes/druid/energy_probe.lua`、`core/events.lua`、`classes/druid/cat.lua`。
3. **WoW 1.12 client = Lua 5.0 语法：无 `#`、无 goto**；本 quick 只做逐行替换与整块删除，不新增任何语句。
4. **LF 行尾；代码注释与 commit message 英文**（项目惯例）。
5. **命名删除区外是 additive-only**：三个文件中除点名删除的 11 行与点名改写的 9 行（各守卫行/body 行）之外，一切既有语句零移动、零重排、零重缩进、零措辞改动。`classes/druid/energy_probe.lua` 第 17 行模块头注释（`-- energy tick forensics probe (quick 260915-tt3): flag-gated, additive-only, SavedVariables-only instrumentation`）**保持原样不改**——它在锁定改动清单之外；其「SavedVariables-only」措辞随 refactor 过期一事照实记入 SUMMARY 偏差一节。
6. **红线反转**：探针文件（energy_probe.lua 自身）**不得直接触碰 `DEFAULT_CHAT_FRAME` / `SendChatMessage` / `macroTorch.show`**——必须经 `macroTorch.log` 路由；聊天输出成为 REQUIRED 行为。
7. **加载序安全**（brief 事实）：`macroTorch.log` 定义于 interface_debug.lua（build order 18），先于 core/events.lua（25）与 druid 块末的 energy_probe.lua（36），直调零风险；函数的运行时解析与加载序无关，double-guard 不再需要。
8. **keep 清单**（energy_probe.lua）：energyProbe nil-guard、local 状态表（lastEnergy/lastTime/lastPollEnergy/pollAccum）、CreateFrame、4 个事件注册、OnUpdate 累积逻辑、PEW 重置逻辑——全部保留。
9. **executor 绝不 commit 文档**（PLAN/SUMMARY/STATE 由 quick 流程 orchestrator 收口）；`SM_Extend.lua` 绝不手改（build.sh 重建属预期，gitignore:26）。
10. **commit message 逐字**：`refactor(260915-udx): route energy probe lines through macroTorch.log (visible + shared persistence) instead of dedicated probeTick bucket`
11. **六模板逐字不变**：SES/EV/POLL（energy_probe.lua）、RAW/CAST（core/events.lua）、REL（classes/druid/cat.lua）六个 `string.format` 模板字符串与 260915-tt3 完全一致，原文件各恰 1 处。

## 背景事实（2026-09-15 规划时实地核对，编辑锚点以本节为准）

- 工作树 clean（`git status --porcelain` 为空）。规划目录 `?? .planning/quick/260915-udx-.../` 会在执行期出现（orchestrator 所有），电池以 `grep -v '^?? .planning/'` 豁免，同 260915-tt3 偏差 1。
- `classes/druid/energy_probe.lua`（129 行，LF、英文注释）：17 = 模块头注释；21-23 = nil-guard；**25-35 = 待删块**（25-29 函数文档注释 + 30-35 函数体）；69 = EV 调点；94 = SES 调点；125 = POLL 调点。删除 25-35 后其余行号整体 −11（69→58、94→83、125→114）——**执行一律用唯一字符串锚点的 Edit，不用行号**。
- `core/events.lua`（4 空格缩进）：147-148 = CAST 守卫+body（12/16 空格缩进）；152-153 = RAW 守卫+body（8/12 空格缩进）；135 = `local pendingName = macroTorch._pendingCastSpellName`（一字不动）。
- `classes/druid/cat.lua`：412-413 = REL 守卫+body（8/12 空格缩进）；415 = `macroTorch.player.reshift('ready')`（一字不动）。
- `interface_debug.lua:113-131` = `function macroTorch.log(a, color)`：`macroTorch.show(a, color)` + `MACRO_TORCH_LOG.messages` 共享缓冲 + `macroTorch.LOG_MAX_SIZE`（nil-guard 500）裁剪。energy_probe.lua 各调点未传 color → nil → 默认白色，符合预期。
- token 现状（实测）：`energyProbeLog`/`probeTick` 仅存在于上述 3 个源文件 + `SM_Extend.lua`（旧 build 产物，14 hit，重建后清零）；`.claude/.codegraph/.gsd/.git/.planning` 及全仓其余文件干净。改后全仓清零可达。
- 工具在位（实测）：`/usr/bin/luac`（5.3.4）；`/tmp/luabuild/lua-5.0.3/bin/lua` **PRESENT**（5.0.3 语法正门，无降级预期）。`./build.sh` 在本 Linux 主机不拷贝游戏目录（拷贝为 cygwin-only）。
- `SM_Extend.lua` 在 `.gitignore:26`（`git check-ignore SM_Extend.lua` 精确命中）。

## 前置条件

`/usr/bin/luac` 与 `/tmp/luabuild/lua-5.0.3/bin/lua` 均在位（已实测）。若执行时 5.0.3 解释器缺失：降级为仅 `/usr/bin/luac -p`（沿用 260915-tt3 前置条件口径），并在 SUMMARY 偏差一节记录「5.0.3 门跳过」，严禁再降级。工作树必须 clean。

## 任务

### Task 1（原子）: 三文件改写 + 单 commit

**文件（仅此三个）**: `classes/druid/energy_probe.lua` + `core/events.lua` + `classes/druid/cat.lua`

**(a) energy_probe.lua — 删除包装 + 三个调点直调**（两次 Edit，顺序固定）：

Edit 1 — 删除第 25-35 行整块（函数文档注释 + 函数体，共 11 行），锚点前后各保留一行不动：

```
--- delete (current lines 25-35, verbatim) ---
-- Probe-only persistence sink: lines land exclusively in the probeTick
-- buffer, capped at 2500 entries. The first-write nil-guards mirror the
-- macroTorch.log double-guard so a fresh MACRO_TORCH_LOG SavedVariables
-- table still rebuilds the nursery on first call. This function never
-- writes the chat frame and never reroutes through the shared display sink.
function macroTorch.energyProbeLog(line)
    if not MACRO_TORCH_LOG then MACRO_TORCH_LOG = { messages = {}, maxSize = 500 } end
    if not MACRO_TORCH_LOG.probeTick then MACRO_TORCH_LOG.probeTick = { messages = {}, maxSize = 2500 } end
    while macroTorch.tableLen(MACRO_TORCH_LOG.probeTick.messages) >= MACRO_TORCH_LOG.probeTick.maxSize do table.remove(MACRO_TORCH_LOG.probeTick.messages, 1) end
    table.insert(MACRO_TORCH_LOG.probeTick.messages, tostring(line))
end
```

Edit 2 — 改名调用点（replace_all，命中恰 3 处：EV 行 / SES 行 / POLL 行；函数定义已删，不误伤）：

```
old: macroTorch.energyProbeLog(string.format(
new: macroTorch.log(string.format(
```

三条 body 的**其余部分一字不动**（模板串与实参列表逐字保留）：

```
    macroTorch.log(string.format("EPR|EV|%s|t=%.3f|earg=%s|e=%s|m=%s|d=%d|dt=%d", evName, now, tostring(evArg), tostring(e), tostring(m), d, dt))
        macroTorch.log(string.format("EPR|SES|t=%.3f|form=%s|net=%s", GetTime(), form, net))
    macroTorch.log(string.format("EPR|POLL|t=%.3f|e=%s|m=%s|d=%d|c=%s", GetTime(), tostring(e), tostring(m), d, c))
```

保留且不动：17 行头注释、21-23 nil-guard、39-42 local 状态、50-54 CreateFrame+4 registrations、58-70 recordEvLine（69 行改调后仍属该函数）、73-108 probeOnEvent（94 行改调）、110-126 probeOnUpdate（125 行改调）、128-129 SetScript。

**(b) core/events.lua — C（CAST）与 B（RAW）各一处 Edit**：

Edit C（当前 147-148 行，逐字）：

```
--- before ---
            if macroTorch.energyProbe and macroTorch.energyProbeLog and pendingName == 'Reshift' then
                macroTorch.energyProbeLog(string.format("EPR|CAST|t=%.3f|spell=%s|e=%s", GetTime(), tostring(pendingName), tostring(UnitMana('player'))))
--- after ---
            if macroTorch.energyProbe and pendingName == 'Reshift' then
                macroTorch.log(string.format("EPR|CAST|t=%.3f|spell=%s|e=%s", GetTime(), tostring(pendingName), tostring(UnitMana('player'))))
```

Edit B（当前 152-153 行，逐字）：

```
--- before ---
        if macroTorch.energyProbe and macroTorch.energyProbeLog and arg2 and string.find(arg2, 'nergize') then
            macroTorch.energyProbeLog(string.format("EPR|RAW|t=%.3f|ch=%s|txt=%s", GetTime(), tostring(arg1), tostring(arg2)))
--- after ---
        if macroTorch.energyProbe and arg2 and string.find(arg2, 'nergize') then
            macroTorch.log(string.format("EPR|RAW|t=%.3f|ch=%s|txt=%s", GetTime(), tostring(arg1), tostring(arg2)))
```

语义不变：'nergize' 匹配原文照旧（含大小写）；pendingName 捕获（135 行）与 bridge 消费块一字不动；RAW tap 只读、落穿不回 return。

**(c) classes/druid/cat.lua — D 一处 Edit**（当前 412-413 行，逐字）：

```
--- before ---
        if macroTorch.energyProbe and macroTorch.energyProbeLog then
            macroTorch.energyProbeLog(string.format("EPR|REL|t=%.3f|e=%s|next=%s|cost=%s|earn=%s", GetTime(), tostring(macroTorch.player.mana), tostring(nextMove), tostring(nextAbilityCost), tostring(clickContext.RESHIFT_ENERGY - macroTorch.player.mana - clickContext.TIGER_E)))
--- after ---
        if macroTorch.energyProbe then
            macroTorch.log(string.format("EPR|REL|t=%.3f|e=%s|next=%s|cost=%s|earn=%s", GetTime(), tostring(macroTorch.player.mana), tostring(nextMove), tostring(nextAbilityCost), tostring(clickContext.RESHIFT_ENERGY - macroTorch.player.mana - clickContext.TIGER_E)))
```

show 调用（405-411）与 reshift('ready')（415）一字不动。

**验证电池（在仓库根顺序执行，任一失败即停并报告；与 design brief 的 verify gates 一一对应）**：

```bash
cd /home/admin/workspace/macro-torch

# GATE 1: 源码范围 token 归零（brief gate：probeTick 扫 classes/ core/ build_order.txt；energyProbeLog 扫源文件）+ 保留躯干不动
test "$(grep -rn 'probeTick' classes core build_order.txt | grep -c . || true)" = "0" || { echo "FAIL: G1 probeTick source residue"; exit 1; }
test "$(grep -rn 'energyProbeLog' classes core build_order.txt | grep -c . || true)" = "0" || { echo "FAIL: G1 energyProbeLog source residue"; exit 1; }
test "$(grep -cF 'function macroTorch.energyProbeLog' classes/druid/energy_probe.lua)" = "0" || { echo "FAIL: G1 function def residue"; exit 1; }
test "$(grep -cF 'macroTorch.energyProbe = false' classes/druid/energy_probe.lua)" = "1" || { echo "FAIL: G1 nil-guard kept"; exit 1; }
test "$(grep -cF 'probeFrame:RegisterEvent' classes/druid/energy_probe.lua)" = "4" || { echo "FAIL: G1 registrations kept"; exit 1; }
test "$(grep -cF 'probeFrame:SetScript' classes/druid/energy_probe.lua)" = "2" || { echo "FAIL: G1 SetScript kept"; exit 1; }

# GATE 2: 六模板逐字各恰 1 处、各自原文件（brief gate：grep -cF == 1）
test "$(grep -cF 'EPR|SES|t=%.3f|form=%s|net=%s' classes/druid/energy_probe.lua)" = "1" || { echo "FAIL: G2 SES"; exit 1; }
test "$(grep -cF 'EPR|EV|%s|t=%.3f|earg=%s|e=%s|m=%s|d=%d|dt=%d' classes/druid/energy_probe.lua)" = "1" || { echo "FAIL: G2 EV"; exit 1; }
test "$(grep -cF 'EPR|POLL|t=%.3f|e=%s|m=%s|d=%d|c=%s' classes/druid/energy_probe.lua)" = "1" || { echo "FAIL: G2 POLL"; exit 1; }
test "$(grep -cF 'EPR|RAW|t=%.3f|ch=%s|txt=%s' core/events.lua)" = "1" || { echo "FAIL: G2 RAW"; exit 1; }
test "$(grep -cF 'EPR|CAST|t=%.3f|spell=%s|e=%s' core/events.lua)" = "1" || { echo "FAIL: G2 CAST"; exit 1; }
test "$(grep -cF 'EPR|REL|t=%.3f|e=%s|next=%s|cost=%s|earn=%s' classes/druid/cat.lua)" = "1" || { echo "FAIL: G2 REL"; exit 1; }

# GATE 3: 守卫字面量（brief 三条 guard literal）+ 直调路由 + 旧合取清零 + 探针红线（禁直接触聊天）
test "$(grep -cF 'if macroTorch.energyProbe and arg2 and string.find' core/events.lua)" = "1" || { echo "FAIL: G3 RAW guard"; exit 1; }
test "$(grep -cF 'if macroTorch.energyProbe and pendingName' core/events.lua)" = "1" || { echo "FAIL: G3 CAST guard"; exit 1; }
test "$(grep -cF 'if macroTorch.energyProbe then' classes/druid/cat.lua)" = "1" || { echo "FAIL: G3 REL guard"; exit 1; }
test "$(grep -rcF 'macroTorch.energyProbe and macroTorch.energyProbeLog' classes/druid/energy_probe.lua core/events.lua classes/druid/cat.lua | grep -vc ':0')" = "0" || { echo "FAIL: G3 old conjunct residue"; exit 1; }
test "$(grep -cF 'macroTorch.log(string.format("EPR|' classes/druid/energy_probe.lua)" = "3" || { echo "FAIL: G3 probe routing"; exit 1; }
test "$(grep -cF 'macroTorch.log(string.format("EPR|' core/events.lua)" = "2" || { echo "FAIL: G3 events routing"; exit 1; }
test "$(grep -cF 'macroTorch.log(string.format("EPR|' classes/druid/cat.lua)" = "1" || { echo "FAIL: G3 cat routing"; exit 1; }
test "$(grep -nE 'DEFAULT_CHAT_FRAME|SendChatMessage' classes/druid/energy_probe.lua | grep -c . || true)" = "0" || { echo "FAIL: G3 direct-chat red line"; exit 1; }
test "$(grep -nE 'macroTorch\.show' classes/druid/energy_probe.lua | grep -c . || true)" = "0" || { echo "FAIL: G3 show red line"; exit 1; }

# GATE 4: build.sh 重建 + 产物六前缀 + 产物 token 归零（brief gate 的后半）
./build.sh || { echo "FAIL: G4 build.sh"; exit 1; }
for P in 'EPR|SES' 'EPR|EV' 'EPR|POLL' 'EPR|RAW' 'EPR|CAST' 'EPR|REL'; do
  test "$(grep -cF "$P" SM_Extend.lua)" -ge "1" || { echo "FAIL: G4 missing $P in product"; exit 1; }
done
test "$(grep -cF 'probeTick' SM_Extend.lua)" = "0" || { echo "FAIL: G4 probeTick in product"; exit 1; }
test "$(grep -cF 'energyProbeLog' SM_Extend.lua)" = "0" || { echo "FAIL: G4 energyProbeLog in product"; exit 1; }

# GATE 5: 语法门 — brief 的 luac -p 三源 + 产物 + Lua 5.0.3 正门（降级口径见 前置条件）
/usr/bin/luac -p classes/druid/energy_probe.lua || { echo "FAIL: G5 luac probe"; exit 1; }
/usr/bin/luac -p core/events.lua || { echo "FAIL: G5 luac events"; exit 1; }
/usr/bin/luac -p classes/druid/cat.lua || { echo "FAIL: G5 luac cat"; exit 1; }
/usr/bin/luac -p SM_Extend.lua || { echo "FAIL: G5 luac product"; exit 1; }
test -x /tmp/luabuild/lua-5.0.3/bin/lua && /tmp/luabuild/lua-5.0.3/bin/lua -e 'assert(loadfile("SM_Extend.lua"))' && echo "LUA50-LOADFILE-OK" || { echo "G5 5.0.3 degraded to luac-only"; /usr/bin/luac -p SM_Extend.lua || { echo "FAIL: G5 degraded luac"; exit 1; }; }

# GATE 6: 全仓 token 扫（brief gate：除 .planning 外整仓归零；.git 一并排除防对象库噪声）+ 既有语句零移动实证 + diff 卫生
test "$(grep -rIn 'energyProbeLog' . --exclude-dir=.git --exclude-dir=.planning | grep -c . || true)" = "0" || { echo "FAIL: G6 repo-wide energyProbeLog"; grep -rIn 'energyProbeLog' . --exclude-dir=.git --exclude-dir=.planning; exit 1; }
test "$(grep -rIn 'probeTick' . --exclude-dir=.git --exclude-dir=.planning | grep -c . || true)" = "0" || { echo "FAIL: G6 repo-wide probeTick"; exit 1; }
test "$(grep -cF 'local pendingName = macroTorch._pendingCastSpellName' core/events.lua)" = "1" || { echo "FAIL: G6 pendingName invariant"; exit 1; }
test "$(grep -cF "macroTorch.player.reshift('ready')" classes/druid/cat.lua)" = "1" || { echo "FAIL: G6 reshift call invariant"; exit 1; }
test "$(grep -cF \"', nextAbilityCost: ' .. tostring(nextAbilityCost) .. ', tigerLeft = ' .. macroTorch.tigerLeft(clickContext) ..\" classes/druid/cat.lua)" = "1" || { echo "FAIL: G6 show call invariant"; exit 1; }
git diff --check || { echo "FAIL: G6 diff --check"; exit 1; }
test "$(git diff -U0 -- classes/druid/energy_probe.lua core/events.lua classes/druid/cat.lua | grep '^+' | grep -v '^+++' | LC_ALL=C grep -cP '[^\x00-\x7F]' || true)" = "0" || { echo "FAIL: G6 non-ASCII in added lines"; exit 1; }
test "$(git diff -U0 -- classes/druid/energy_probe.lua core/events.lua classes/druid/cat.lua | grep '^+' | grep -v '^+++' | grep -c $'\r' || true)" = "0" || { echo "FAIL: G6 CR in added lines"; exit 1; }
grep -l $'\r' classes/druid/energy_probe.lua core/events.lua classes/druid/cat.lua build_order.txt 2>/dev/null | grep -c . >/dev/null && { echo "FAIL: G6 CR bytes in files"; exit 1; } || true

# GATE 7: 变更面恰 3 文件（豁免 orchestrator 的 ?? .planning/ 行）+ SM_Extend 稳居 gitignore
test "$(git status --porcelain | grep -v '^?? .planning/' | LC_ALL=C sort)" = "$(printf ' M classes/druid/cat.lua\n M classes/druid/energy_probe.lua\n M core/events.lua' | LC_ALL=C sort)" || { echo "FAIL: G7 change surface"; git status --porcelain; exit 1; }
test "$(git check-ignore SM_Extend.lua)" = "SM_Extend.lua" || { echo "FAIL: G7 SM_Extend leaked"; exit 1; }
test "$(git status --porcelain | grep -v '^?? .planning/' | grep -c 'build_order.txt' || true)" = "0" || { echo "FAIL: G7 build_order touched"; exit 1; }
echo "TASK1 GATES 1-7 OK"
```

**commit（1 原子、逐字 message、恰 3 文件）**：

```bash
cd /home/admin/workspace/macro-torch
git add classes/druid/energy_probe.lua core/events.lua classes/druid/cat.lua
git commit -m "refactor(260915-udx): route energy probe lines through macroTorch.log (visible + shared persistence) instead of dedicated probeTick bucket"
test "$(git log -1 --format=%s)" = "refactor(260915-udx): route energy probe lines through macroTorch.log (visible + shared persistence) instead of dedicated probeTick bucket" || { echo "FAIL: commit message"; exit 1; }
test "$(git diff HEAD~1 HEAD --name-only | LC_ALL=C sort)" = "$(printf 'classes/druid/cat.lua\nclasses/druid/energy_probe.lua\ncore/events.lua' | LC_ALL=C sort)" || { echo "FAIL: committed file set"; git diff HEAD~1 HEAD --name-only; exit 1; }
echo "TASK1 COMMIT OK"
```

**完成标准**：GATES 1-7 全绿 + TASK1 COMMIT OK（message 逐字、恰 3 文件、build_order.txt 不在其中）。

### Task 2（收口，无代码）: 提交后复核 + SUMMARY.md

- **复核电池（对 HEAD 复跑；不出代码、不产生新 commit）**：

```bash
cd /home/admin/workspace/macro-torch
test "$(git status --porcelain | grep -v '^?? .planning/' | grep -c . || true)" = "0" || { echo "FAIL: T2 post-commit residue"; exit 1; }
test "$(git log -1 --format=%s)" = "refactor(260915-udx): route energy probe lines through macroTorch.log (visible + shared persistence) instead of dedicated probeTick bucket" || { echo "FAIL: T2 message recheck"; exit 1; }
test "$(git diff HEAD~1 HEAD --name-only | LC_ALL=C sort)" = "$(printf 'classes/druid/cat.lua\nclasses/druid/energy_probe.lua\ncore/events.lua' | LC_ALL=C sort)" || { echo "FAIL: T2 file set recheck"; exit 1; }
./build.sh || { echo "FAIL: T2 build"; exit 1; }
/usr/bin/luac -p SM_Extend.lua || { echo "FAIL: T2 luac product"; exit 1; }
test -x /tmp/luabuild/lua-5.0.3/bin/lua && /tmp/luabuild/lua-5.0.3/bin/lua -e 'assert(loadfile("SM_Extend.lua"))' && echo "LUA50-LOADFILE-OK" || { /usr/bin/luac -p SM_Extend.lua || exit 1; }
test "$(grep -cF 'probeTick' SM_Extend.lua)" = "0" || { echo "FAIL: T2 product probeTick"; exit 1; }
for P in 'EPR|SES' 'EPR|EV' 'EPR|POLL' 'EPR|RAW' 'EPR|CAST' 'EPR|REL'; do
  test "$(grep -cF "$P" SM_Extend.lua)" -ge "1" || { echo "FAIL: T2 missing $P"; exit 1; }
done
git diff --check HEAD~1 HEAD || { echo "FAIL: T2 diff check"; exit 1; }
echo "TASK2 ALL GATES OK"
```

- **撰写 SUMMARY.md** 于 `/home/admin/workspace/macro-torch/.planning/quick/260915-udx-energy-tick-macrotorch-log-probetick-ene/260915-udx-SUMMARY.md`，结构照 260915-tt3-SUMMARY.md 先例（frontmatter：`quick_id: 260915-udx`、`status: complete`、date、one_liner、key_files modified（3 文件）、decisions、commits（本次 commit hash）、duration_seconds、estimate/actuals；正文：任务完成 / 偏差 / Unrun Verification / Threat Flags / Self-Check）。**必须记录以下三项（design brief 点名）**：
  - **(a)** 逐行聊天输出现在是 ON 状态的持续提醒，by design：EPR 行出现在 DEFAULT_CHAT_FRAME 即探针开启的可见证据；关闭仅需 `/run macroTorch.energyProbe = false`（无需 reload）。
  - **(b)** 实机使用指引：探针行量大（每 tick/事件一行），`macroTorch.log` 的共享缓冲裁剪上限默认 `LOG_MAX_SIZE = 500`，完整会话留档必须调高：`/run macroTorch.LOG_MAX_SIZE = 10000`（约 10 分钟会话量级示例；该缓冲与 cpBuildLog 等其他 macroTorch.log 流量共享）。
  - **(c)** Windows+Cygwin 客户端 unrun-verify 清单（本机无 WoW 客户端）：1) 默认关（energyProbe false）时宏行为与改动前一致、零 EPR 输出；2) `/run macroTorch.energyProbe = true` 后猫形态等待若干 tick——**聊天窗口应立即出现** `EPR|SES`/`EPR|EV`/`EPR|POLL` 等行（这是与 tt3 的行为差：聊天可见性）；3) `/run ReloadUI()` 退出后查 `WTF/Account/<账号>/SavedVariables/SuperMacro.lua` 的 `MACRO_TORCH_LOG.messages`：EPR|SES/EV/POLL/RAW/CAST/REL 行与其他 log 流量同存于共享 messages 列表，无 `MACRO_TORCH_LOG.probeTick` 段；4) 换形态/脱战开关一次验证 form 字段跟随、关闭立即静默；5) 确认内存/聊天无 probeTick 字样残留。
  - **偏差一节必记**：`classes/druid/energy_probe.lua:17` 模块头注释「SavedVariables-only」措辞随本次 refactor 语义过期但按锁定范围（命名删除区外 additive-only）原样保留。
- **SUMMARY.md 绝不 commit**（orchestrator 收口），也不创建/修改任何其他 .planning 文件、STATE.md。

**完成标准**：TASK2 ALL GATES OK；SUMMARY.md 存在于上述绝对路径且含 (a)(b)(c) 与偏差记录。

## 失败即回退

- 任一 gate 失败 → 不提交，修正至通过；`git status --porcelain` 出现预期外文件 → `git checkout -- <file>` 撤销并排查。
- Edit 锚点不匹配 → 文件已漂移，停止并报告实际内容，禁止自行发挥。
- `./build.sh` 失败 → 不得手工编辑 SM_Extend.lua 绕过，报告实际错误。
- Task 1 若已 commit 后复核发现漏网 → 追加修复后一律 `git commit --amend`（保持 1 原子 commit，message 不变）；amend 后重跑 Task 1 的 commit 校验三连。
- 偏差模板（违反任一即停）：变更文件超出 3 个；既有语句被移动/重排/重缩进/措辞改动；六模板或守卫行偏离锁定文案；probeTick/energyProbeLog 残留（源/产物/全仓）；探针文件出现 DEFAULT_CHAT_FRAME/SendChatMessage/macroTorch.show；build.sh 未跑或 luac -p 被跳过；5.0.3 门缺失未录偏；commit message 不符或 commit 夹带 build_order.txt/.planning/SM_Extend.lua。

## 威胁模型（STRIDE 简表）

| Trust Boundary | Description |
|----------|-------------|
| 客户端脚本 → 聊天窗口 + 本地 SavedVariables | 探针开启时数据同时进入玩家可见频道与本地 MACRO_TORCH_LOG；唯一写入边界，不触网、不经包管理器 |

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260915-udx-01 | DoS | energy_probe.lua 高频行刷屏 + 共享缓冲膨胀 | low | mitigate | energyProbe 默认 false、逐登录重挂（session-scoped opt-in）；MACRO_TORCH_LOG.messages 由 LOG_MAX_SIZE 裁剪有界；SUMMARY (b) 给出会话级上调指引（显式、可选） |
| T-260915-udx-02 | Information Disclosure | 能量/reshift 时序数据聊天可见 | low | accept | 单机本地客户端、自看自用；用户点名要求可见证据（by design），与既有 macroTorch.log 各调用同暴露面 |
| T-260915-udx-03 | Elevation | 格式串/异常中断事件链 | low | mitigate | 全部输入 tostring 纪律自 tt3 起不变；单开关守卫减少了 nil 路径；macroTorch.log 自带首次写 nil-guard 与 tonumber+clamp 裁剪净化（quick 260907-vve） |
| T-260915-udx-SC | Tampering | npm/pip/cargo installs | — | — | 本 quick 零包管理器安装，package legitimacy 门与 T-SC 行不适用 |

## 输出

执行完成后输出 `/home/admin/workspace/macro-torch/.planning/quick/260915-udx-energy-tick-macrotorch-log-probetick-ene/260915-udx-SUMMARY.md`（结构见 Task 2）；STATE.md Quick Tasks 表行由 quick 流程 docs commit 收口，代码 commit 中不得夹带任何 .planning 文件。