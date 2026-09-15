---
quick_id: 260915-uzs
slug: energy-tick-pdt-raw-combatlog-periodic-c
subsystem: druid-cat
description: "energy tick 取证探针扩展 PDT 通道：RAW_COMBATLOG 两个 periodic 通道（creature/hostileplayer）全量 tick 行以 EPR|PDT(tx=RAW) 落 macroTorch.log，同名 chat 通道再落 EPR|PDT(tx=CHAT) 双传输比对到达时序；无法术白名单，所有可检测 periodic tick 事件全量落盘供离线分析（design brief 260915-uzs 锁定）"
date: 2026-09-15
phase: quick
plan: 260915-uzs
type: execute
wave: 1
depends_on: [260915-udx]
files_modified: [core/events.lua]
autonomous: true
requirements: ["pdt-dual-transport@quick-260915-uzs"]
estimate:
  tokens: 32000
  raw_tokens: 16000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "energyProbe 为 false/nil（默认，每次登录由 nil-guard 重挂）：三处新 tap 全部短路——零新增输出、零新增持久化；六路既有 EPR 行（SES/EV/POLL/RAW/CAST/REL）与生产 landing 逻辑改动前行为逐字节等价"
    - "energyProbe 为 true：RAW_COMBATLOG 到达的 CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE / HOSTILEPLAYER_DAMAGE 每行全量落 EPR|PDT|tx=RAW；同名 chat 通道每行全量落 EPR|PDT|tx=CHAT——同一事件双传输两行落盘（tx 字段区分），离线可比对到达时序；无法术白名单，全量样本"
    - "EPR|PDT 模板逐字 `EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s` 在 core/events.lua 恰 3 处（1 RAW + 2 CHAT）；RAW 侧守卫字面量恰 1 处、CHAT 侧守卫字面量恰 2 处；tier-1 白名单 / processRawAuraApply 循环头 / nergize gate / cpDamage gate 四条既有字面量计数不变"
    - "既有六路 EPR 模板（events.lua RAW/CAST 各 1、cat.lua REL 1、energy_probe.lua SES/EV/POLL 各 1）计数与 udx 态一致；epr 前缀雾冲突——规划时 git grep 'EPR|PDT' 全仓 0（除本计划文档外）"
    - "./build.sh 成功；重建产物 SM_Extend.lua 含 EPR|PDT（≥1）且六前缀全齐；/usr/bin/luac -p 过 core/events.lua 与 SM_Extend.lua；Lua 5.0.3 loadfile 正门（缺则降级 luac 双门 + SUMMARY 记偏差）"
    - "恰 1 个整单 commit（1 文件、恰 9 插入 0 删除、message 逐字锁定）；SM_Extend.lua 稳居 gitignore 不手改不进 commit；.planning 由 orchestrator 收口"
  artifacts:
    - "core/events.lua：三处纯插入、每处恰 3 行（guard + macroTorch.log + end），总计 9 行净增 0 删除——PDT-RAW tap 落在 tier-1 白名单 return 之后、Tier-2 注释之前；两个 PDT-CHAT tap 落在两个原先为空的 CHAT_MSG_SPELL_PERIODIC_*_DAMAGE elseif 分支体内"
    - "SM_Extend.lua：由 build.sh 重建（gitignored，不手改、不 commit）"
    - ".planning 侧：260915-uzs-SUMMARY.md（Task 2，executor 不 commit）"
  key_links:
    - "PDT-RAW tap 位于 tier-1 白名单之后（events.lua:170-172 后）——arg1 被保证是两 periodic 通道之一、arg2 必为 periodic-damage 行全文；白名单 return 先行，tap 只读落穿不消费"
    - "PDT-CHAT 双 tap 位于 chat 消息 handler 的空分支（events.lua:124 / 126）——event 即通道名（ch 字段）、arg1 即行文本（txt 字段）；与 RAW 侧同一 tick 事件的双传输由 tx=RAW/CHAT 区分，到达时序离线比对"
    - "macroTorch.log（interface_debug.lua，build order 18）先于 core/events.lua（25）加载——直调零加载序风险；双守卫 energyProbe and macroTorch.log 仍防御性保留"
    - "单开关 macroTorch.energyProbe（nil-guard 在 classes/druid/energy_probe.lua）复用——全取证装置一个开关；关闭即三处 tap 短路"
---

# PLAN: energy tick 探针 PDT 双传输扩展（260915-uzs）

## 目标

**Goal（design brief 260915-uzs 已锁定，只实现、不重新设计）**：在既有 energy probe 上扩展 periodic-damage-tick（PDT）通道。RAW_COMBATLOG 分支里，tier-1 白名单放行的两个 periodic 通道（creature/hostileplayer）每一条 tick 行以 `EPR|PDT|t=%.3f|tx=RAW|ch=<arg1>|txt=<arg2>` 落 `macroTorch.log`；两个同名 chat 消息分支（原先为空）各落 `EPR|PDT|tx=CHAT` 行——同一 tick 事件经 chat 过滤通道与 RAW_COMBATLOG 双传输两行落盘，tx 字段区分传输，离线比对到达时序。**无法术白名单，不做规律性假设**：所有可检测 periodic tick 事件全量落盘，通道/使用决策全部推迟到离线分析。

**Purpose**: 用户锁定决策（取证阶段样本优先）：先全量后过滤，白名单与周期判据由离线分析器从全量样本中定，探针侧不做任何过滤假设。
**Output**: core/events.lua 三处纯插入（恰 9 行）、build.sh 重建的 SM_Extend.lua、1 个整单 commit；Task 2 产出 SUMMARY.md（不入 commit）。

## 锁定约束（违反即失败；逐字来自 design brief 260915-uzs）

1. **1 文件、1 原子 commit**：变更面恰为 `core/events.lua`。`SM_Extend.lua` 绝不手改（build.sh 重建属预期，gitignore:26）、绝不进 commit。
2. **三处插入逐字**（见「任务」节），**不加任何注释行**——新增行恰 9 行（3 块 × 3 行），确保 numstat 恰 `9 0`。除三处插入外，一切既有语句零移动、零重排、零重缩进、零措辞改动。
3. **守卫逐字**：RAW 侧 `if macroTorch.energyProbe and macroTorch.log and arg2 then`；CHAT 侧 `if macroTorch.energyProbe and macroTorch.log and arg1 then`。
4. **模板逐字**（新类型唯一字面量）：`EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s`，tx ∈ {"RAW","CHAT"} 区分传输。RAW 侧 ch=tostring(arg1)（白名单已保证其是两 periodic 通道之一）、txt=tostring(arg2)；CHAT 侧 ch=tostring(event)（即通道名）、txt=tostring(arg1)（行文本）。
5. **无法术白名单**：任何 spell 过滤都不进探针——离线分析器负责。tier-1 白名单只按通道放行（RAWC 侧），这是既有生产代码、不改。
6. **复用单开关 `macroTorch.energyProbe`**（nil-guard 已在 classes/druid/energy_probe.lua）；全部写入走 `macroTorch.log`（聊天可见 + 共享持久化，quick 260915-udx 已反转的红线）；**不得触碰 DEFAULT_CHAT_FRAME / SendChatMessage / macroTorch.show**。
7. **WoW 1.12 = Lua 5.0 语法：无 `#` 长度运算符、无 goto**；本 quick 纯插入不涉及。
8. **LF 行尾；代码注释与 commit message 英文**（项目惯例）。
9. **commit message 逐字**：`feat(260915-uzs): capture periodic damage ticks in probe via EPR|PDT dual transport (RAW + CHAT)`
10. **executor 绝不 commit 文档**（PLAN/SUMMARY/STATE 由 quick 流程 orchestrator 收口）。
11. **无名字冲突**：规划时 `git grep -cF 'EPR|PDT'` 全仓 0 实证（执行时 Step 1 复验）。

## 背景事实（2026-09-15 规划时实地核对 HEAD 37c2234，编辑锚点以本节为准；行号供定位，执行时以锚文本为准复验）

- `core/events.lua:124` `    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then` ← 分支体为空（125 行空行）。
- `core/events.lua:126` `    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then` ← 分支体为空（127 行空行）。
- `core/events.lua:151-188` RAW_COMBATLOG 分支：152 行 nergize gate（udx 态，直调 macroTorch.log）；155-164 cpDamage gate（`if macroTorch.cpDamageLog and arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE' and arg2 then`）；170-172 tier-1 白名单（`if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then return end`）；173 起 `-- Tier 2 + Tier 3 (substring precheck + registered spell match):` 注释；181-188 `processRawAuraApply` 循环（`for spellName, pattern in pairs(macroTorch.auraApplySpellPatterns) do`）。
- udx 已落地六路 EPR 模板基线（计数待守）：events.lua `EPR|RAW|t=%.3f|ch=%s|txt=%s` == 1、`EPR|CAST|t=%.3f|spell=%s|e=%s` == 1；cat.lua `EPR|REL|t=%.3f|e=%s|next=%s|cost=%s|earn=%s` == 1；energy_probe.lua `EPR|SES|`/`EPR|EV|`/`EPR|POLL|` 各 == 1。
- 基线零计数（执行时 Step 1 复验）：`EPR|PDT` 全仓（tracked）0；`if macroTorch.energyProbe and macroTorch.log and arg2 then` == 0；`if macroTorch.energyProbe and macroTorch.log and arg1 then` == 0。

## 前置条件

1. **先行产物在位**：tt3 探针（classes/druid/energy_probe.lua + build_order.txt 行）与 udx 直调改造（六路 EPR 走 macroTorch.log）已在 HEAD——本 quick 是纯扩展，不重建这些。
2. **执行时重新核对**「背景事实」的三处锚文本与基线计数；若 HEAD 已漂移（锚文本不一致），先停手报告 orchestrator，不要按猜测改动。
3. **Lua 5.0.3 正门** `/tmp/luabuild/lua-5.0.3/bin/lua` 缺失时降级口径：`luac -p` 双门照过 + SUMMARY 偏差节如实记录（与 tt3/udx 同款 degrade policy）。

## 任务

### Task 1（原子）: 三处插入 + GATE 电池 + 单 commit

**Step 1 — 预检（改前）**：

```bash
cd /home/admin/workspace/macro-torch
# G1: 名字冲突与干净树
[ "$(git grep -cF 'EPR|PDT' | wc -l)" = "0" ] && echo "G1a COLLISION-FREE" || { echo "G1a FAIL"; exit 1; }
git status --porcelain | grep -v '^?? .planning/' | grep -q . && { echo "G1b TREE-DIRTY"; exit 1; } || echo "G1b TREE-CLEAN"
# G2: 新字面量基线必须为 0
[ "$(grep -cF 'EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s' core/events.lua)" = "0" ] && echo "G2a TEMPLATE-BASE-0 OK"
[ "$(grep -cF 'if macroTorch.energyProbe and macroTorch.log and arg2 then' core/events.lua)" = "0" ] && echo "G2b ARG2-GUARD-BASE-0 OK"
[ "$(grep -cF 'if macroTorch.energyProbe and macroTorch.log and arg1 then' core/events.lua)" = "0" ] && echo "G2c ARG1-GUARD-BASE-0 OK"
# G3: 锚文本仍与「背景事实」一致（人工目视比对）
sed -n '124p;126p;152p;170,175p;181,182p' core/events.lua
```

预期：G1a/G1b/G2a/G2b/G2c 全 OK；G3 打印行与背景事实逐字一致。

**Step 2 — 三处 Edit（全部 additive，改后行与既有语句零覆盖）**：

Edit 1（PDT-RAW tap）——插入点：tier-1 白名单块 `return`/`end` 之后、`-- Tier 2 + Tier 3 ...` 注释行之前（规划时 172 与 173 行之间）。old_string 取白名单三行 + Tier-2 注释首行（唯一匹配）：

```text
        if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then
            return
        end
        -- Tier 2 + Tier 3 (substring precheck + registered spell match):
```

new_string（在 `        end` 与注释行之间插入恰恰 3 行，8 空格缩进）：

```text
        if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then
            return
        end
        if macroTorch.energyProbe and macroTorch.log and arg2 then
            macroTorch.log(string.format("EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s", GetTime(), "RAW", tostring(arg1), tostring(arg2)))
        end
        -- Tier 2 + Tier 3 (substring precheck + registered spell match):
```

Edit 2（PDT-CHAT tap, creature）——插入点：creature 空分支体（规划时 124 与 126 行之间；125 行空行原样保留在插入行之后）。old_string：

```text
    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then

    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then
```

new_string（`then` 行之后插入恰恰 3 行，8 空格缩进；空行不动）：

```text
    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        if macroTorch.energyProbe and macroTorch.log and arg1 then
            macroTorch.log(string.format("EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s", GetTime(), "CHAT", tostring(event), tostring(arg1)))
        end

    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then
```

Edit 3（PDT-CHAT tap, hostileplayer）——同形状，hostileplayer 空分支体（规划时 126 与 128 行之间；127 行空行原样保留）。old_string：

```text
    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then

    elseif event == "UNIT_CASTEVENT" then
```

new_string：

```text
    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then
        if macroTorch.energyProbe and macroTorch.log and arg1 then
            macroTorch.log(string.format("EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s", GetTime(), "CHAT", tostring(event), tostring(arg1)))
        end

    elseif event == "UNIT_CASTEVENT" then
```

执行纪律：三处 Edit 按 1→2→3 顺序（Edit 2 的 new_string 保留 hostileplayer 行原样，Edit 3 锚不破坏）；Edit 的转义按编辑工具原文（别手工加反斜杠——与 udx 偏差 1 同型教训：grep 单引号模式内的双引号不转义）。

**Step 3 — GATE 电池（改后、commit 前）**：

```bash
cd /home/admin/workspace/macro-torch
# G4: 新字面量计数（design brief 锁定门）
[ "$(grep -cF 'EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s' core/events.lua)" = "3" ] && echo "G4a TEMPLATE==3 OK"
[ "$(grep -cF 'if macroTorch.energyProbe and macroTorch.log and arg2 then' core/events.lua)" = "1" ] && echo "G4b RAW-GUARD==1 OK"
[ "$(grep -cF 'if macroTorch.energyProbe and macroTorch.log and arg1 then' core/events.lua)" = "2" ] && echo "G4c CHAT-GUARD==2 OK"
# G5: 既有 EPR 模板保持 udx 计数
[ "$(grep -cF 'EPR|RAW|t=%.3f|ch=%s|txt=%s' core/events.lua)" = "1" ] && [ "$(grep -cF 'EPR|CAST|t=%.3f|spell=%s|e=%s' core/events.lua)" = "1" ] && echo "G5a OK"
[ "$(grep -cF 'EPR|REL|t=%.3f|e=%s|next=%s|cost=%s|earn=%s' classes/druid/cat.lua)" = "1" ] && echo "G5b OK"
[ "$(grep -cF 'EPR|SES|' classes/druid/energy_probe.lua)" = "1" ] && [ "$(grep -cF 'EPR|EV|' classes/druid/energy_probe.lua)" = "1" ] && [ "$(grep -cF 'EPR|POLL|' classes/druid/energy_probe.lua)" = "1" ] && echo "G5c OK"
# G6: 既有不变式字面量（生产代码零扰动）
[ "$(grep -cF "if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then" core/events.lua)" = "1" ] && echo "G6a TIER1==1 OK"
[ "$(grep -cF 'for spellName, pattern in pairs(macroTorch.auraApplySpellPatterns) do' core/events.lua)" = "1" ] && echo "G6b AURAAPPLY-HEAD==1 OK"
[ "$(grep -cF "macroTorch.energyProbe and arg2 and string.find(arg2, 'nergize')" core/events.lua)" = "1" ] && echo "G6c NERGIZE-GATE==1 OK"
[ "$(grep -cF "macroTorch.cpDamageLog and arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE' and arg2" core/events.lua)" = "1" ] && echo "G6d CPDAMAGE-GATE==1 OK"
# G7: 纯插入 9 行 + diff 卫生
git diff --numstat core/events.lua | grep -q '^9[[:space:]]0[[:space:]]core/events.lua$' && echo "G7a INS-9-DEL-0 OK"
[ "$(git diff --numstat | wc -l)" = "1" ] && echo "G7b ONE-FILE-CHANGED OK"
git diff --check && echo "G7c CHECK-CLEAN OK"
git diff core/events.lua | grep '^+' | grep -v '^+++' | LC_ALL=C grep -c "$(printf '\r')" | grep -q '^0$' && echo "G7d NO-CR OK"
git diff core/events.lua | grep '^+' | grep -v '^+++' | LC_ALL=C grep -cP '[^\x00-\x7F]' | grep -q '^0$' && echo "G7e NO-NONASCII OK"
# G8: 构建 + 语法门
./build.sh && echo "G8a BUILD OK"
[ "$(grep -cF 'EPR|PDT' SM_Extend.lua)" -ge 1 ] && echo "G8b PRODUCT-HAS-PDT OK"
for pfx in 'EPR|SES|' 'EPR|EV|' 'EPR|POLL|' 'EPR|RAW|' 'EPR|CAST|' 'EPR|REL|'; do grep -qF "$pfx" SM_Extend.lua || { echo "G8c MISSING $pfx"; exit 1; }; done; echo "G8c SIX-PREFIXES OK"
/usr/bin/luac -p core/events.lua && /usr/bin/luac -p SM_Extend.lua && echo "G8d LUAC-STD OK"
/tmp/luabuild/lua-5.0.3/bin/lua -e 'assert(loadfile("SM_Extend.lua"))' && echo "G8e LUA50-LOADFILE-OK"
git check-ignore SM_Extend.lua | grep -q '^SM_Extend.lua$' && echo "G8f SM-GITIGNORED OK"
echo "TASK1 GATES 4-8 OK"
```

G8e 前置条件 3 降级口径：5.0.3 缺失 → 跳过该门、G8d 双门作语法权威、SUMMARY 偏差节记录。

**Step 4 — 原子 commit**：

```bash
cd /home/admin/workspace/macro-torch
git add core/events.lua
git diff --cached --numstat          # 恰 "9	0	core/events.lua"
git diff --cached --name-only        # 恰 core/events.lua 一行
git commit -m "feat(260915-uzs): capture periodic damage ticks in probe via EPR|PDT dual transport (RAW + CHAT)"
git show --stat --oneline HEAD | sed -n '2,4p'   # 1 file changed, 9 insertions(+)
git diff HEAD~1 HEAD --name-only | sort          # 恰 core/events.lua
git diff HEAD~1 HEAD --numstat                   # 恰 "9	0	core/events.lua"
echo "TASK1 COMMIT OK"
```

**完成标准**：G1-G3 预检全 OK、三处 Edit 逐字落地、GATES 4-8 全绿、TASK1 COMMIT OK（message 逐字、恰 1 文件、9 插入 0 删除）。任何一门 FAIL → 先修复再 commit；修不了 → 按「失败即回退」处理。

### Task 2（收口，无代码）: 提交后复核 + SUMMARY.md

```bash
cd /home/admin/workspace/macro-torch
# T2 GM: 提交后对 HEAD 复跑核心门
git status --porcelain | grep -v '^?? .planning/' | grep -q . && { echo "T2a CODE-RESIDUE"; exit 1; } || echo "T2a ZERO-RESIDUE OK"
[ "$(grep -cF 'EPR|PDT|t=%.3f|tx=%s|ch=%s|txt=%s' core/events.lua)" = "3" ] && echo "T2b TEMPLATE==3 OK"
[ "$(grep -cF 'if macroTorch.energyProbe and macroTorch.log and arg2 then' core/events.lua)" = "1" ] && [ "$(grep -cF 'if macroTorch.energyProbe and macroTorch.log and arg1 then' core/events.lua)" = "2" ] && echo "T2c GUARDS OK"
git diff --check HEAD~1 HEAD && echo "T2d DIFF-CHECK OK"
./build.sh && /usr/bin/luac -p core/events.lua && /usr/bin/luac -p SM_Extend.lua && /tmp/luabuild/lua-5.0.3/bin/lua -e 'assert(loadfile("SM_Extend.lua"))' && echo "T2e REBUILD-SYNTAX OK"
git log --oneline -1    # 逐字: feat(260915-uzs): capture periodic damage ticks in probe via EPR|PDT dual transport (RAW + CHAT)
echo "TASK2 ALL GATES OK"
```

随后写出 `/home/admin/workspace/macro-torch/.planning/quick/260915-uzs-energy-tick-pdt-raw-combatlog-periodic-c/260915-uzs-SUMMARY.md`（frontmatter `status: complete`，镜像 udx SUMMARY 结构：任务完成表 / 验证电池结果 / Deviations / Unrun Verification / Threat Flags / Self-Check），必须含 design brief 点名的三段：

- **(a) scope note**：仅捕获**我方对 creature / hostile player 的 period damage**；SELF 侧 periodic（怪物流血打在玩家身上）与 PARTY / FRIENDLYPLAYER periodic 通道未覆盖——如未来需要，按同形状每个通道加一个分支即可（one-branch-per-channel follow-up，本期不做）。
- **(b) volume guidance update**：PDT 双传输落地后，探针全通道合计输出约 **3–4 行/s（战斗中）**；实机取完整会话必须上调共享缓冲：`/run macroTorch.energyProbe = true macroTorch.LOG_MAX_SIZE = 20000`（替代 udx 指引的 10000）。该缓冲与其他 macroTorch.log 流量（cpBuildLog 等）共享，会被互相挤占。
- **(c) unrun-verify checklist**（Windows+Cygwin 客户端，执行器本机无 WoW）：沿用 tt3/udx 清单——默认关零输出等价；`/run macroTorch.energyProbe = true` 后聊天窗口立即出现 EPR|SES/EV/POLL 行；ReloadUI 退出后 `MACRO_TORCH_LOG.messages` 含各 EPR 行且无 probeTick 段；切换形态 form 字段跟随、关开关立即静默；**新增本条：对训练木桩保持 Rake/Rip 流血期间必须出现 EPR|PDT 行（tx=RAW 与 tx=CHAT 两种都要有）**。

executor **绝不 commit** 任何东西——SUMMARY.md 与 STATE.md 表行由 quick 流程 orchestrator 收口。

**完成标准**：T2a-e 全 OK、SUMMARY.md 存在于上述绝对路径、含 (a)(b)(c) 与 Deviations（如有，含 5.0.3 降级记录）。

## 失败即回退

- Edit 中途锚文本失配或 GATE 失败无法修复：`git checkout -- core/events.lua`（其余文件原则不得有改动）、报告 orchestrator，附最后一条 FAIL 与 `git status --porcelain`。
- 已 commit 但复核发现污染：`git revert --no-edit HEAD`（与 orchestrator 确认后执行）；只需动 core/events.lua 一文件的插入、无交叉依赖，回退安全。

## 威胁模型（STRIDE 简表）

| Threat ID | 类别 | 组件 | 严重度 | 处置 | 缓解 |
|-----------|------|------|--------|------|------|
| T-260915-uzs-01 | DoS | core/events.lua 双 PDT tap 高频行输出 + 共享缓冲膨胀 | medium | mitigate | energyProbe 默认 false、逐登录重挂（session-scoped opt-in）；双传输合计 ≈3–4 行/s 属可控量级；MACRO_TORCH_LOG.messages 由 LOG_MAX_SIZE 裁剪有界，SUMMARY (b) 给上调指引（显式、可选） |
| T-260915-uzs-02 | Information Disclosure | 周期性伤害 tick 时序数据聊天可见 | low | accept | 单机本地客户端、自看自用；双传输聊天可见正是用户点名要的到达时序证据（与 udx T-02 accept 同口径，与既有 macroTorch.log 各调用同暴露面） |
| T-260915-uzs-03 | Elevation | 格式串 / nil 路径 / 异常中断事件链 | low | mitigate | 全 tostring 纪律不变；双守卫 `energyProbe and macroTorch.log and argN`；RAW 侧 tap 位于 tier-1 白名单之后，arg1 已被保证合法；CHAT 侧守卫 arg1 真值 |
| T-260915-uzs-SC | Tampering | npm/pip/cargo installs | — | — | 本 quick 零包管理器安装，package legitimacy 门与 T-SC 行不适用 |

## 输出

- `.planning/quick/260915-uzs-energy-tick-pdt-raw-combatlog-periodic-c/260915-uzs-SUMMARY.md`（Task 2 写、orchestrator commit）
- 代码 commit：`feat(260915-uzs): capture periodic damage ticks in probe via EPR|PDT dual transport (RAW + CHAT)`（Task 1，恰 core/events.lua 9 插入 0 删除）