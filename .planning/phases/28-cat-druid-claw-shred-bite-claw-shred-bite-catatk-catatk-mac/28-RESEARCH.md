# Phase 28: catatk claw/shred/bite 伤害打桩 — Research

**Researched:** 2026-09-08
**Domain:** WoW 1.12(+SuperWoW) 客户端战斗日志采集 + 5.0 方言离线统计分析
**Confidence:** HIGH（9 个研究问题中 8 个以仓内代码/真实客户端样本为第一证据；2 个外部事实以容错设计兜底，见 Assumptions Log）

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01: 伤害源 = RAW_COMBATLOG SPELL_DAMAGE 事件** — 无聊天报文兜底链路。白名单过滤：仅 claw/shred/bite 三门技能 + 来源 GUID = 本人 + 排除 SPELL_PERIODIC_DAMAGE（rake/rip tick）与 aura 类子事件。客户端 RAW_COMBATLOG 可用性有既有先例（rawdiag2 白名单前 scout）。**Reversibility:** reversible

- **D-02: cast→damage 配对复用 Phase 27 land 架构** — cast 时记 intent（技能名 + 来源 GUID + 时间戳），SPELL_DAMAGE 事件按 技能名 + 来源 GUID + 时间窗 配对；配对窗口对齐 land 的 2s 过期参数；未配对 intent 自然过期丢弃。**Reversibility:** reversible

- **D-03: 未命中完全不记录** — immune/miss/dodge/resist 不写入日志。用户口径原文：目的是纯技能伤害比较，偶发因素对任何一个攻击技能的概率相同，可以忽略。架构上对称简化：无伤害事件 → 无配对 → 无条目，零额外处理。

- **D-04: bleed 档位 = cast 时刻 UnitDebuff 扫描快照** — UnitDebuff 1..40 + texture_map 贴图匹配，计数 0-3（rake/rip/pounce）。**口径：任意来源**（其他猫挂的流血也计入 claw 加成），多猫团本场景下 claw 样本按当时实际档位入桶。**Reversibility:** reversible

- **D-05: 仅 Training Dummy 打点** — `clickContext.isTargetDummy`（combo.lua:104 已有现成判断）为硬门；骷髅级/60/1 级等多档木桩覆盖测试情形，暂不考虑真实敌人。木桩不会死 → overkill 样本天然不存在，分析器无需任何 overkill 处理。

- **D-06: 开关 `macroTorch.cpDamageLog`** — bool 默认 false；login/reload 复位；进 CONFIG_OPTIONS 注册表第 5 项（登录横幅含默认值与 /run 设置命令）。沿用 cpBuildLog 三大惯例。

- **D-07: 条目 11 字段** — `spell`（claw/shred/bite）、`dmg`、`crit`、`e`（该技能理论能耗）、`energyPool`（施法时刻能量池快照）、`bleedCount`（0-3）、`isOoc`、`isBehind`、`cp`（连击点）、`t`（GetTime）、`batch`（进战斗 GetTime）。

- **D-08: 能耗取 clickContext 动态值（已代码实查）** — `CLAW_E = macroTorch.computeClaw_E()`（Druid.lua:501：45 − 3(Idol of Ferocity) − talentRank('Ferocity')）；`SHRED_E = macroTorch.computeShred_E()`（Druid.lua:642：60 − talentRank('Improved Shred')×6）；`BITE_E = 35` 硬编码门槛常数（combo.lua:62）。catAtk 每按键开头已算好放入 clickContext（combo.lua:57-65），hook 直接引用即可，无需重复计算。

- **D-09: OOC 口径（用户明确指出）** — claw/shred 的记录不关心 OOC：一律记理论能耗入效率统计（分母口径干净无偏）。**bite 例外**：OOC 时 bite 能耗被省略，多余能量 = 当时全池（≤100，全部被 bite 转换清空），因此 bite 条目必须记录 `energyPool`（施法时刻 `player.mana` 快照，cpBuildLogSample 的 e 字段有现成先例 Druid.lua:332）+ `isOoc` 标记；常规 bite 多余能量 = energyPool − 35。

- **D-10: 缓冲复用 MACRO_TORCH_LOG.messages + LOG_MAX_SIZE** — 不新开子表；上限默认 500，用户游戏内 /run 赋值自调（如 `/run macroTorch.LOG_MAX_SIZE=3000`）。

- **D-11: 进/脱战自动分批** — `PLAYER_REGEN_DISABLED`（进战斗）时取 GetTime() 作 `batch` 写入每条条目；脱战自动进入下一批。`core/combat_context.lua` 已有该事件对与 context 生命周期，挂点现成。木桩场景：开打=进战斗=新批次，停手约 5s 自动脱战=批次结束；无任何手动操作，同一环多批次共存，分析器按 batch 分组。

- **D-12: `[cpDamage] ` 前缀 + JSON body（用户指定，仿 cpBuild）** — 条目 = `'[cpDamage] ' .. jsonString`，走 `macroTorch.log` 同一写入路径入 `MACRO_TORCH_LOG.messages` 环，与 `[cpBuild]` 行为兄弟行；WTF 文件里人肉可读。

- **D-13: 分析器按前缀识别** — `[cpDamage]` 前缀过滤 → 剥前缀 → JSON decode，识别确定性 100%，无需启发式。

- **D-14: 分析器落位** — repo `tools/` 子目录独立脚本（**不入 build_order.txt**，绝不编入 SM_Extend.lua）；用户运行：`lua tools/<script>.lua <path/to/WTF/Account/<acc>/SavedVariables/SuperMacro.lua>`，脚本自动定位提取 MACRO_TORCH_LOG 段。注意 SavedVariables 是 Lua table 语法而非纯 JSON——脚本需内置对 1.12 序列化格式的提取（marker + 括号配平）。

- **D-15: Lua 5.0 方言兼容（用户要求与游戏内代码一致）** — 禁 `#` 长度运算符、goto 等 5.1+ 特性；同一脚本在 5.1–5.4 任意标准解释器可运行；自包含无外部依赖；语法自验必须覆盖 5.0。

- **D-16: 输出 = 终端统计表 + `--json-out` 可选结果文件** — JSON 结果文件服务于跨装备/天赋阶段的结论归档对比（多次复用测试的核心诉求）。

- **D-17: 两层报表** — 每批次（每次进/脱战）统计 + 全批次聚合总结；低样本档位标注 n 值警告。

- **D-18: 效率统计口径** — claw/shred 按 bleedCount 0/1/2/3 四档分桶：每档 n / avg dmg / avg dmg ÷ e（每点能量伤害）；另列每档单次伤害 avg（不含能量的纯伤害均值）。

- **D-19: OOC 结论也分档** — claw 的单次伤害随流血档变化，OOC 时选谁取决于当时档位，故 OOC 对比按档输出；正面站位 shred 不可用 → OOC 结论仅用背位样本（isBehind 筛选）。

- **D-20: bite 拟合模型** — 筛 5cp bite 样本，最小二乘拟合 `dmg = a + b×(energyPool−35)`（OOC 样本用 energyPool−0）；b = 每点溢出能量边际伤害。与 claw/shred 最佳 builder 效率对比：b 更高 → 不泄能直接咬；b 更低 → 先 claw/shred 泄能再咬。拟合自然验证"你的服 bite 额外能量有无上限"。

- **D-21: 明确输出决策建议** — 分析器除统计表外输出可直接执行的 catAtk 决策建议行：每流血档该用哪个 builder、OOC 时选哪个技能（分档）、bite 前是否先泄能。

### Claude's Discretion

- cast-intent 队列与配对实现细节（在 Phase 27 land 架构基础上）
- `crit` 字段可检测性：客户端 RAW_COMBATLOG 是否携带暴击标记由 researcher 核实——不可检测则条目中省略或标注未知（伤害均值统计不受影响）
- 分析器：SavedVariables 提取的具体 parser 写法、JSON decode 实现、终端表格排版、报告文案
- 打点 hook 的精确挂点（catAtk 模块链 or Druid.lua 技能方法，参考 cpBuildLog 挂点体系）
- SelfTest 具体用例与桩函数写法（遵循 Category 字母编号 + `isOptional=true` + `UnitClass('player')` guard 传统）

### Deferred Ideas (OUT OF SCOPE)

- `druid-rip-land-forensics-next-cd.md`（.planning/todos/pending/）— 下个 CD 实机取证 rip landing 抑制（需网友配合双层协议）——用户选择**不折入** Phase 28，保持独立 pending todo。Phase 28 只采集 claw/shred/bite 直伤，与该取证（rip 存在性）不同问题域。
</user_constraints>

## Summary

本 phase 在既有架构上叠加一层纯观测通道：**cast 侧**在 Druid.lua 三技能方法（obj.claw/obj.shred/obj.ferocious_bite）内做 11 字段快照采样并种下伤害 intent；**事件侧**在 core/events.lua 的 RAW_COMBATLOG 分支加一条白名单通道解析本人直伤行，与 intent 按时间窗配对后以 `[cpDamage] ` + JSON 单行写入既有持久化环；**离线侧**新增 repo `tools/cpdamage.lua`（Lua 5.0 方言、自包含），读 SuperMacro.lua SavedVariables、括号配平提取 `MACRO_TORCH_LOG` 段、前缀过滤 + 迷你 JSON 解码、双层统计 + 最小二乘拟合 + 决策建议输出。

**两个决定性研究结论**（改写了 D-01 的措辞、解锁了 crit）：
1. 该客户端（1.12 + SuperWoW）**不存在**名为 `SPELL_DAMAGE` 的事件；D-01 的"SPELL_DAMAGE 事件"在真实事件流中 = RAW_COMBATLOG 的 `arg1='CHAT_MSG_SPELL_SELF_DAMAGE'` 通道，payload 为 `arg2='Your <Spell> hits|crits <目标GUID> for <N>.'` 纯文本行。**crit 完全可检测**（hits/crits 动词），且真实样本证明 miss/dodge/parry 行同通道到达但不匹配伤害句式 → D-03 自动成立。
2. **能量快照依赖的 intent 队列不能复用 intentTable**：Ferocious Bite 已在 Phase 27 land 架构中占用 intentTable/pairLandIntent（land 语义，fail-wins 撤销），Phase 28 必须并行一份独立的 cpDamage intent 队列（复用 LRUStack + TTL=2 模式），否则 bite 的 land 配对与伤害配对待在同一队列互相消费。

**Primary recommendation:** 全链路复用现有资产——cpBuildLogSample 采样模板、LRUStack + LAND_INTENT_TTL 配对模式（独立新表）、macroTorch.log 落盘、DataMatrix 载荷全 ASCII 的迷你 JSON 编解码——不引入任何新依赖、不改 build_order.txt；验证以 bbcheck.js + build.sh + Selftest 注册 + 分析器内置 `--selftest` 四条腿构成。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 11 字段快照采样（cast 时） | 游戏内 addon（Druid.lua 技能方法） | — | cast 前 GCD 探测 + energyPool/cp/bleed 快照只能在技能释放点取 |
| 伤害意图配对（cast→damage） | 游戏内 addon（spell_trace_core.lua 家族 + events.lua RAW 分支） | — | RAW 事件只有客户端内可收 |
| 条目序列化（JSON encode） | impl_util.lua（核心库） | — | 纯 Lua 值→字符串，被游戏内打点调用 |
| batch 生命周期 | core/combat_context.lua | events.lua 事件对 | PLAYER_REGEN_DISABLED 时刻取 GetTime 存 context |
| 持久化 | SuperMacro SavedVariables（WTF 文件） | macroTorch.log(interface_debug.lua) | 既有唯一落盘路径 |
| 提取 + 解析 + 统计 + 输出 | 离线层 tools/cpdamage.lua | — | D-14/D-15/D-16 钦定独立脚本 |
| 验证（bracket 平衡、汇编、注册完整性） | node bbcheck.js + build.sh | Selftest（游戏内） | 本机无 Lua 运行时，见 Environment Availability |

## 1. RAW_COMBATLOG 事件结构与 crit 可检测性

**结论:**
- 该客户端的真实事件流里**没有名为 SPELL_DAMAGE 的事件**。D-01 的"SPELL_DAMAGE 事件"落在此客户端的实际形态是：SuperWoW 事件 `RAW_COMBATLOG`，`arg1 = 原始事件名`（即 CHAT_MSG_* 通道名），`arg2 = 带 GUID 的原始文本行`，**无 arg3+ 结构化字段**。
- **本人直伤 = 通道 `CHAT_MSG_SPELL_SELF_DAMAGE`**，行格式实锤（真实客户端样本）：
  - 命中：`Your Ferocious Bite hits 0xF13000C55226FDD2 for 864.`
  - 暴击：`Your Ferocious Bite crits 0xF13000C55226FDD2 for 1647.`、`Your Rake crits 0xF13000C55226FDD2 for 445.`
  - 未命中：`Your Ferocious Bite was dodged by 0xF13000C55226FDD2.`、`Your Ferocious Bite is parried by 0xF13000C55226FDD2.`（同通道，但不匹配 `for N.` 句式）
- **crit 可检测**（Claude's Discretion 已核实）：以 `hits`/`crits` 动词判别，随 `dmg` 一并解析；dmg 取的是含暴击乘数的最终 roll 值。
- **SPELL_PERIODIC_DAMAGE 与 aura 子事件的过滤 = tier-1 通道白名单，一票排除**：真实通道普查（6 个样本文件约 2600 行）——`CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE`（1072）、`_SPELL_AURA_GONE_OTHER`（511）、`_AURA_GONE_SELF`（273）、`_SPELL_SELF_DAMAGE`（197）、`_FRIENDLYPLAYER_DAMAGE`（77）、`_COMBAT_SELF_HITS`（43）、其余 buff/交易技能通道若干。喘息句：`0xF13000C55226FDD2 suffers 277 Physical damage from your Rip.` 走 PERIODIC 通道；aura 行走 AURA_* 通道。白名单只放行 SELF_DAMAGE，periodic/aura/他人事件全部不进解析。

**证据:**
- `docs/superwow_features.md:10`（SuperWoW 官方特征文档仓内存档，逐字）：`Added "RAW_COMBATLOG" event that signals the RAW version of all combat log events. arg1: original event name. arg2: event text with GUIDs` — [VERIFIED: docs/superwow_features.md:10]
- `core/events.lua:47-51`（事件注册条件与命名，逐字）：`if SUPERWOW_STRING ~= nil then frame:RegisterEvent("UNIT_CASTEVENT") frame:RegisterEvent("RAW_COMBATLOG") end` — [VERIFIED: core/events.lua:47-51]
- `.planning/debug/catatk-premature-rip-recast.md:92`（实机取证结论，逐字摘要）：`① RAW_COMBATLOG 布局:arg1=CHAT_MSG_* 通道名,arg2=含 GUID 的原始文本(无名字),无 arg3+ 结构化字段;② APPLY 事件存在且近零延迟...;③ FAIL 事件存在且同批:"Your Rip is parried by ..."/"Your Ferocious Bite was dodged by"/"Your Rake is parried" 走 CHAT_MSG_SPELL_SELF_DAMAGE` — [VERIFIED: .planning/debug/catatk-premature-rip-recast.md:92]
- 真实客户端样本（用户机器拷回，`Your Ferocious Bite crits 0xF13000C55226FDD2 for 1647.` / `Your Rake crits 0xF13000C55226FDD2 for 445.` / `Your Ferocious Bite was dodged by 0xF13000C55226FDD2.` / `0xF13000C55226FDD2 suffers 277 Physical damage from your Rip.`）— [VERIFIED: .planning/samples/sample_back_again.txt:1,26,53；通道计数 grep 全样本集]
- 现有白名单先例（rawdiag2 前 scout 与 Phase 27 三层过滤器）— [VERIFIED: core/events.lua:135-205，其中 tier-1 逐字：`if arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE' and arg1 ~= 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE' then return end`（187-189）]

**对计划影响:**
- 计划文案须把 D-01 的"SPELL_DAMAGE"改写为可执行通道名：**RAW_COMBATLOG 分支内新增 `arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE'` 通道门**，位置在 rawdiag2 scout 之后、现有 tier-1 提前 return 之前（该 return 只放行两条 PERIODIC 通道，必须重构调度点让两条消费者各见各的通道——推荐按通道分派而非改白名单集合，避免扰动 Phase 27 语义）。
- 伤害行解析正则（英文客户端实锤样本）：`^Your (.+) (hits|crits) (0x[0-9A-Fa-f]+) for (%d+)%.`——不锚定行尾（容忍 `(M absorbed/blocked)` 尾缀；木桩无此场景但防御性保留）；miss/dodge/parry/resist/immune 行天然不匹配 → D-03 零额外代码。
- **crit 字段建议写入 true/false**（Claude's Discretion 可检性已正面核实），动词不在 {hits, crits} 白名单时（非英文客户端）写 `null`；分析器对缺失/未知 crit 的桶不受影响（均值统计不依赖 crit，可另列 crit 提示）。
- RAW_COMBATLOG 注册本身已被 `SUPERWOW_STRING ~= nil` 门保护；cpDamageLog 依赖 SuperWoW（插件未装时静默无事件，intent 自然过期），计划中作为执行前置条件注明，不新增降级链路（D-01 钦定无兜底）。

## 2. SuperMacro SavedVariables 文件格式

**结论:**
- **注册点已确认存在**（外部仓内副本）：`SuperMacro-turtle-paw/SuperMacro.toc` 逐字含 `## SavedVariables: SM_VARS SM_EXTEND SM_ACTION_SUPER SM_SUPER MACRO_TORCH_LOG`；但 **SuperMacro-turtle-SuperWoW 变体（3.19）的 toc 没有 MACRO_TORCH_LOG**。debug 文档记录游戏机端 toc 已声明（quick 260817-sg1 已确立），本仓库无 .toc。
- 文件形态：SavedVariables 是合法 Lua 表赋值文本（`MACRO_TORCH_LOG = { ... }`，string key 写作 `["messages"]`，数组行带 tab 缩进；真实摘抄样本显示 `[1] = "..."` 显式键形式，客户端另有 ` -- [1]` 注释尾缀形式）。**提取策略 = marker 定位 + 字符串/注释感知的括号配平 + loadstring 整段执行**——因为该段本身就是合法 Lua，由 Lua 自身完成转义/键形式/中文等所有格式歧义，无需手写反序列化。
- 括号配平的**关键陷阱**：条目 body 是嵌在字符串里的 JSON（含 `{`/`}`/引号/反斜杠），裸括号计数必然错配。配平扫描器必须跳过字符串字面量（`\"`、`\\`、`\ddd` 转义感知）与 `--` 注释；bbcheck.js 的 strip 逻辑（见第 9 节）是现成的参考实现。

**证据:**
- `## SavedVariables: ... MACRO_TORCH_LOG` — [VERIFIED: /home/admin/workspace/SuperMacro-turtle-paw/SuperMacro.toc:24（逐字）]；SuperWoW 变体缺失 —— [VERIFIED: /home/admin/workspace/SuperMacro-turtle-SuperWoW/SuperMacro.toc:24]
- 游戏内存结构 `MACRO_TORCH_LOG = { messages = {}, maxSize = 500 }`、trim 用 `table.remove(messages, 1)` 保持数组连续 — [VERIFIED: interface_debug.lua:21-23, 106-124，逐字：`MACRO_TORCH_LOG = { messages = {}, maxSize = 500 }`（22）、`table.remove(messages, 1)`（121）]
- 真实 SV 序列化形态样本（用户拷回后摘录的本环内容）：`[1] = "[RAWDIAG] #48 t=13415.600 arg1=CHAT_MSG_SPELL_SELF_DAMAGE | arg2=Your Ferocious Bite crits 0xF13000C55226FDD2 for 1647.",` 且 `[2]` 行前有保存文件特有的 tab 缩进 — [VERIFIED: .planning/samples/sample_back_again.txt:1-2]
- 无真实 WTF 全文件样本落库（workspace 搜遍无 MACRO_TORCH_LOG 内容文件；es.txt 为第三方解析格式 `0|HEADER|...` 非原始 SV）— [VERIFIED: 全 workspace grep]
- 客户端写的具体 key 形式（` -- [1]` 注释尾缀 vs `[1] =` 显式键）与转义细节未获权威资料 — [ASSUMED]（对提取策略无影响：loadstring 两种形式都吃）

**对计划影响:**
- 提取器流程：读全文件（`io.read("*a")` 或按行累积）→ `string.find` 定位 `"MACRO_TORCH_LOG"` → 向后扫描到第一个 `{` → 配平括号（跳过字符串与 `--` 注释）到闭合 `}` → 取整段 → 沙箱 `loadstring(block)` 执行 → 读全局 `MACRO_TORCH_LOG["messages"]`。
- 段形式防御：允许 `MACRO_TORCH_LOG = nil`（玩家清空过时）与 `MACRO_TORCH_LOG = { }`（无 entries），输出友好空结果而非报错。
- **执行面建议沙箱**（见 Security Domain）：5.0/5.1 用 `setfenv` 空环境；5.2+ 用 `load(block, nil, 't', env)`。
- 计划须包含一个 **checkpoint:human-verify**：确认游戏机端实际 SuperMacro .toc 含 `MACRO_TORCH_LOG`（本 workspace 两变体中仅 paw 变体有——玩家实际部署的哪个变体是本机无法确定的；若缺失则需玩家在 toc 加一行，否则打点不存在=静默零数据，与"SavedVariables 加载覆盖"问题同源，interface_debug.lua:17 注释已注明依赖该声明）。

## 3. JSON 编解码路径

**结论:**
- **游戏内编码**：仓内无任何 JSON 实现（grep `json` 全仓零命中，macroTorch.log 只做 `tostring`）；1.12 无 json 库。需手写 5.0 兼容微编码器。条目 11 字段中唯一字符串字段 `spell` 恒为 ASCII token（"claw"/"shred"/"bite"），数字/布尔/空值无转义需求 → 编码器只需处理字符串转义，约 30 行。落点推荐 `impl_util.lua`（已在 build_order 内，符合"零新文件"策略）。
- **离线解码**：纯 Lua 5.0 递归下降迷你 JSON 解析器，约 80-120 行，只支持 object/array/string/number/true/false/null。读写双方均为本 phase 自控 → **严格互认契约**：编码器只输出这 6 种形态 + 固定字段序，解码器不用处理 unicode 转义（`\uXXXX` 可声明不支持，源侧不产生）；string 转义只需 `\"` `\\` `\n` `\r` `\t` 与控制字符 `\u00XX` 的形式之一，建议编码端直接全部映射为 `\u00XX` 四字符宽形式（数字+字母，最远 32 行代码），两端天然一致。

**证据:**
- 无 JSON 引用（`grep -in json` 全部源码与 md：0 命中）— [VERIFIED: 全仓 grep]
- `macroTorch.log` 序列化 = `table.insert(messages, tostring(a))`，无结构化 — [VERIFIED: interface_debug.lua:123]
- 11 字段中 `spell` 取值域由采集代码自身定义（D-07），其他 10 字段为 number/boolean — [VERIFIED: CONTEXT D-07]
- Lua 5.0 `string.gsub` 替换项仅 string/function（**无 table 形式，5.1 才支持**）、`string.format` 支持 `%q`（Lua 引号风格而非 JSON）——两个特性均限定了编码器写法 — [VERIFIED: https://www.lua.org/manual/5.0/manual.html（已下载全文核验，逐字：`If repl is a string... If repl is a function...`；format 段：`there is an extra option, q. The q option formats a string in a form suitable to be safely read back by the Lua interpreter`）]

**对计划影响:**
- 编码器：`macroTorch.jsonEncodeScalar(v)`型分派 + string 转义用 `gsub(..., function(c) ... end)`（5.0 合法）；禁止使用 `%q` 直接产 JSON（产的是 Lua 引号形式，`\ddd` 转义在 JSON 里非法）。
- 解码器作为分析器内部模块（同文件或同名子函数），接收已有 `[cpDamage] ` 前缀剥除后的纯 JSON 字符串；遇到未知字段跳过（前向兼容）、缺字段按类型缺省（crit 可缺省 → `crit=null` 语义）。
- 编码器配 `Cat U` SelfTest：固定条目表 → 期望字符串逐字断言（纯函数，不依赖游戏 API，可在 `/mt` 自检跑通）。

## 4. Phase 27 land 配对架构复用锚点

**结论（每个锚点含精确挂点）:**

| 关注点 | 现有锚点 | Phase 28 使用方式 |
|--------|----------|-------------------|
| cast intent 结构 | `intentTable[spell][mob]` LRUStack(32)，元素 `{ state='pending', castAt=GetTime(), landAt=nil }` | **不复用该表**——新建 `loginContext.cpDamageIntents`（LRUStack，如容量 8），元素 `{ spell, guid, castAt, sample }`。理由：`Ferocious Bite` 已在 Phase 27 以 `SpellTrace:register('Ferocious Bite', { land=true, immune=false })` 占用 intentTable（land 状态机 + fail-wins 撤销），伤害配对若共享队列将与 pairLandIntent/finalizeFail 互相消费、污染 land 语义与 R8 不变性 |
| TTL 常量 | `macroTorch.LAND_INTENT_TTL = 2`（spell_trace_core.lua:15） | 直接复用同名常量（D-02 钦定对齐 2s） |
| 配对模式 | `pairLandIntent`：过期 purge 一趟 + 最新 pending 逆向匹配 | 照抄结构到 `macroTorch.pairCpDamageIntent(guid, now)`：purge（now − castAt > TTL）→ 从最新往前找 `pending` 且 `guid` 等于行内 GUID 且在窗内 → 置 `consumed` 并返回 sample |
| 采样模板 | `cpBuildLogSample()`（cast 前 GCD probe + `{ t, cp, e, gcdOk }`），`cpBuildLogEvent()` 前缀打点 | 新 `cpDamageSample`/`cpDamageCast` 同构：probe 必须在 `_castSpell` 之前 |
| 技能方法挂点 | `obj.claw`（Druid.lua:25-32）、`obj.shred`（34-41）、`obj.ferocious_bite`（56-58）；cpBuildLog 三件套已嵌 claw/shred（bite 无） | claw/shred 沿用既有三件套结构原地扩展第三个函数；**bite 补同样结构**（当前无采样） |
| RAW 事件注册点 | `frame:RegisterEvent("RAW_COMBATLOG")`（events.lua:50，SUPERWOW 门内）、事件消费分支 events.lua:135-205 | 分支内 tier-1 前插 cpDamage 通道门（格式见第 1 节） |
| batch 取值点 | `onCombatEnter()`（combat_context.lua:29-35），由 events.lua:97 `PLAYER_REGEN_DISABLED` 调用 | 在 onCombatEnter 末尾 `macroTorch.context._cpDamageBatch = GetTime()`；context 在脱战被整体清空 → 下一批自动取新值 |
| 队列容器 | `macroTorch.LRUStack:new(maxSize)` push/pop/top/anyMatch/allMatch/removeMatch，push 自带头部淘汰 | cpDamage intent 直接 new(8) |

**证据（逐字，本会话 Read）：**
- `macroTorch.LAND_INTENT_TTL = 2` + intent 元素 `push({ state = 'pending', castAt = GetTime(), landAt = nil })` — [VERIFIED: core/spell_trace_core.lua:15,125]
- `pairLandIntent` purge/pair 逻辑 — [VERIFIED: core/spell_trace_core.lua:179-210]
- `SpellTrace:register('Ferocious Bite', { spellName = 'Ferocious Bite', land = true, immune = false })` — [VERIFIED: classes/druid/Druid.lua:740-743]
- LRUStack push 淘汰 — [VERIFIED: core/periodic.lua:31-35]
- 技能方法 cpBuild 三件套 — [VERIFIED: classes/druid/Druid.lua:25-50]；`cpBuildLogSample` 字段 `t = GetTime(), cp = macroTorch.player.comboPoints, e = macroTorch.player.mana, gcdOk = gcdOk` — [VERIFIED: classes/druid/Druid.lua:342-347]
- 进脱战函数 — [VERIFIED: core/combat_context.lua:21-35]；事件对接线 — [VERIFIED: core/events.lua:95-98]

**对计划影响:**
- 任务拆分自然的三个落刀点：① Druid.lua（三技能方法内采样/intent 种植 + 三个新函数，仿 cpBuild 位置），② events.lua + spell_trace_core.lua（RAW 通道门 + 解析 + 配对 + 条目发射函数，配对族与 land 函数并排），③ macro_torch.lua（nil-guard + CONFIG_OPTIONS 第 5 项）+ combat_context.lua（batch 一行）+ impl_util.lua（JSON 编码器）。
- **采样时机的关键约束**（cpBuildLog WR-01 教训直接沿用）：GCD probe 必须先于 `_castSpell`，且只有 `cast` 返回真才种 intent 与发条目；能量/连击点等快照在 probe 一刻取（Druid.lua:330 注释逐字：`The GCD probe must run BEFORE the cast because casting starts the GCD and would falsify the reading`）。
- 技能方法内无 clickContext——快照就地取：`e` 直接调 `computeClaw_E()/computeShred_E()/35`（每按键已算过但幂等廉价，D-08 允许"hook 直接引用"即指此），`energyPool=player.mana`、`cp=player.comboPoints`、`isOoc=player.isOoc`、`isBehind=player.isBehindTarget`、`bleedCount`=扫描（第 5 节）、`isTargetDummy` 门 = `macroTorch.toBoolean(macroTorch.target.isCanAttack and string.find(macroTorch.target.name, 'Training Dummy'))`（combo.lua:104-106 逐字同表达式）。
- 一个 cast 帧恰好一条 intent（每按键一 action 的红线），队列深度恒为 1：配对可简化但**保留 purge+逆序扫描骨架**（对新事件/顺序噪声免疫，且与 land 架构可读性一致）。

## 5. UnitDebuff 扫描范围（1.12）

**结论:**
- 40 确为 WotLK 记忆值；1.12 客户端的名义 debuff 槽上限为 **16** — [ASSUMED]（权威来源未能在线核验：GitHub 搜索/wowpedia fetch 均失败；"2.4 把 debuff 从 16 提到 40"系训练常识，未获可引文档）。D-04 的 `1..40` 无功能危害（16 之后的 UnitDebuff 恒 nil，无报错），仅 24 次空调用——**建议不修改 hasBuff 的现有 `1..40`（R8 禁令域）**，新扫描同样直接复用 hasBuff。
- **推荐方案：bleedCount = 复用 `target.hasBuff(texture)` × 3**：纹理常量已现成（`Ability_Druid_Disembowel`=Rake、`Ability_GhoulFrenzy`=Rip、`Ability_Druid_SupriseAttack`=Pounce，均为 SpellTrace:register 的 immuneTexture 现成值），`getSpellOrItemBuffTexture` 对未映射字符串直接透传（texture_map.lua:45），hasBuff 扫描 `UnitDebuff+UnitBuff` 的**全部来源源**——这正是 D-04"任意来源"口径的现成实现（其他猫的流血同样在 target 的 UnitDebuff 里）。
- 附加红利：bleedCount 与 `shouldUseShred` 的判定输入（isRakePresent/isRipPresent/isPouncePresent）同源同链，采集簿与决策簿永不打架。
- 可选精确化：若计划选择新写专用扫描，用 nil-break 循环（`for i=1,64 do local t=UnitDebuff('target',i); if not t then break end ... end`）对任意客户端上限自适应；并提供一条 2 秒实机探针抄给用户：`/run for i=1,64 do local t=UnitDebuff('target',i) if not t then macroTorch.show('debuff cap: '..(i-1)) break end end`

**证据:**
- 现 hasBuff `for i = 1, 40 do`（含 `string.find(tostring(UnitDebuff(obj.ref, i)), texture)`）— [VERIFIED: entity/Unit.lua:26-34（逐字行 28-29）]
- 三流血纹理 — [VERIFIED: classes/druid/Druid.lua:726,731,737]
- 透传语义 `return spellOrItemName` — [VERIFIED: texture_map.lua:40-46]
- `isRipPresent` 等三判断同用 hasBuff+纹理 — [VERIFIED: classes/druid/Druid.lua:1137-1143, 1164-1170, 1281-1287]
- 1.12 上限=16 — [ASSUMED]

**对计划影响:**
- bleedCount 快照函数可以直接落在 Druid.lua cpDamage 采样函数内（一次 clickContext 不构建——技能方法层直接三次 hasBuff；性能：每次 cast ≤ 240 次 UnitDebuff 调用，微秒级）。
- 若计划内含扫描范围常量，写 16 并在注释注明"1.12 名义上限；nil 安全，不依赖精确值"；不改 hasBuff。

## 6. Lua 5.0 分析器兼容性清单 + 最小二乘公式

**结论（兼容清单，逐项给 5.0 真相）:**

| 特性 | 5.0 行为 | 对分析器/编码器的影响 |
|------|----------|----------------------|
| `#` 长度运算符 | 不存在 | 用 `table.getn`/自写计数；utf-8 安全用 `string.len`（字节），数组长用 `ipairs` 计数或 `table.getn`（非洞数组才准；本 phase 数据均为连续数组，D-15 已禁 `#`，5.1+ 运行时可安全比对） |
| `goto`/label | 不存在 | 禁用 |
| `string.gsub` table 替换 | **不支持**（仅 string/function）— [VERIFIED manual] | 需要 map 替换时全部用 function 分支 |
| `string.format(' %q ')` | **支持**，Lua 引号风格转义 — [VERIFIED manual] | 可用于调试打印，**不可用于产 JSON** |
| `unpack` | 全局函数 — [VERIFIED manual] | 避免使用；`arg` 传参用 `arg[1]..arg[n]` 直取 |
| `loadstring` | 存在（基库）— [VERIFIED manual] | 5.2+ 需 `local load_chunk = loadstring or load` shim；沙箱 env 注入需 setfenv(5.0/5.1) 与 `load(s,nil,'t',env)`(5.2+) 双路径 |
| `math.mod` | 存在但 5.2 移除 | 用 `%` 运算符（全版本） |
| `%q`/`//`/整数除、`\x`、`\z`、`\u{}` 字符串转义 | `//`、`\x`、`\z`、`\u{}` 均不存在 | 字符串转义只用 `\ddd` 十进制或 `gsub` 生成 |
| `table.pack/unpack` | 不存在于 5.0 table 库 | 用 `table.insert/remove/concat`（5.0 已有） |
| `io/os/string/math` | 齐备（5.0 完整基础库） | 文件读 `io.read("*a")`、`os.exit`、`pairs/ipairs`、`tonumber`、`string.format %.Nf` 均可用 |
| `tostring(数字)` | 5.0 亦稳定 | 输出侧统一 `%.4f` 格式化以跨版本对齐 |
| for-pairs 无序 | 同 5.1 | 报表循环显式按 bleedCount 0→3 / batch 升序迭代，不依赖 pairs |

**最小二乘（D-20）纯 Lua 要点:**
- 模型 `dmg = a + b·x`，x 的定义分两式：常规 bite `x = energyPool − 35`；OOC bite `x = energyPool − 0`（D-20 钦定）。
- 标准公式（单趟累积）：`n`、`sx`、`sy`、`sxx`、`sxy`；`b = (n·sxy − sx·sy) / (n·sxx − sx·sx)`；`a = (sy − b·sx) / n`；分母为 0（全部同 x）时声明"无斜率，dmg 与 x 无关"并跳过拟合；`n < 3` 时仅输出均值不拟合并警告。
- 数值卫生：x 用浮点运算（Lua 5.0 全部为 double），`tonumber` 严格校验 6 个数值字段（dmg/energyPool 必须是数字否则整条丢弃并计数告警）；不做高维矩阵、不引入外部库——D-15 自包含。

**证据:** 5.0 手册全文已下载核验（gsub/format/unpack/loadstring 逐条命中）— [VERIFIED: lua.org/manual/5.0，下载于本会话 /tmp/lua50manual.html]；最小二乘公式为教科书标准 — [ASSUMED 为常识，公式本身无版本歧义]

**对计划影响:**
- 分析器头部固定一段 5.0 兼容性自检 preamble（shim `load_chunk`）；`--selftest` 模式内嵌 5.0 敏感断言（不含 `#`/goto/gsub-table 的静态规避靠执行者的写作纪律 + bbcheck 把关，运行态靠用户各解释器实测）。
- 计划任务分解建议：analyzer 分 4 个子任务——提取器/JSON 解码器/统计与拟合/报表与 --json-out，每个子任务自带可 grep 的验证锚（前缀函数名）。

## 7. 动态能耗与点击路径事实复查

**结论: 全部确认可用，无一需新增计算路径。**
- clickContext 常量名（逐字）：`clickContext.CLAW_E = macroTorch.computeClaw_E()`、`clickContext.SHRED_E = macroTorch.computeShred_E()`、`clickContext.BITE_E = 35` — [VERIFIED: classes/druid/combo.lua:57-65]
- 方法名逐字：`function macroTorch.computeClaw_E()`（Druid.lua:501-509，含 `local CLAW_E = 45`（502）、`CLAW_E = CLAW_E - 3`（505）、`CLAW_E = CLAW_E - player.talentRank('Ferocity')`（507））；`function macroTorch.computeShred_E()`（Druid.lua:642-645，`local SHRED_E = 60`、`return SHRED_E - macroTorch.player.talentRank('Improved Shred') * 6`）— [VERIFIED: classes/druid/Druid.lua:501-509, 642-645]
- 点击时现成字段（全在 clickContext，逐字）：`clickContext.comboPoints = player.comboPoints`（combo.lua:91）、`clickContext.ooc = player.isOoc`（92）、`clickContext.isBehind = target.isCanAttack and player.isBehindTarget`（94）、`clickContext.isTargetDummy = macroTorch.toBoolean(macroTorch.target.isCanAttack and string.find(macroTorch.target.name, 'Training Dummy'))`（104-106）— [VERIFIED: classes/druid/combo.lua:88-107]
- `isBehindTarget` 定义：`macroTorch.target.isExist and macroTorch.isFunctionExist('UnitXP') and UnitXP('behind', 'player', 'target')` — [VERIFIED: entity/Player.lua:602-605]
- `player.mana` = UNIT_FIELD_FUNC_MAP → `UnitMana(self.ref)`（猫形态即能量）— [VERIFIED: entity/Unit.lua:114-116]

**对计划影响:**
- 技能方法层 hook（第 4 节方案）可自足取得全部 11 字段，**不依赖 clickContext 传入**——避免了给 `regularAttack/termMod/safeBite` 全链路加参数的侵入；`e` 值在 hook 内重调 compute 方法（幂等且每点击已由 superMacro 算过一次，开销可忽略）。
- OOC bite 的 `energyPool` 快照来源 `macroTorch.player.mana` 与 cpBuildLogSample 的 `e` 同源，两套日志可比。

## 8. build_order.txt 约定

**结论:**
- 打点会触及的全部文件（macro_torch.lua、impl_util.lua、interface_debug.lua、core/combat_context.lua、core/spell_trace_core.lua、core/events.lua、classes/druid/Druid.lua）**均已在列表中**，零新增行。
- `tools/` 目录当前不存在；build.sh 只迭代 build_order.txt 行（严格模式，缺文件即退出 1），对木 tools/ 零影响；`.gitignore` 不排除 tools/。
- build.sh 在 Cygwin 下还会把 SM_Extend.lua 拷到两个游戏目录（TurtleWoW_bak、capybara_wow_v1181）——分析器脚本不会被拷（不编入 SM_Extend），但若执行者在本机（非 Cygwin）跑 build.sh 无拷贝副作用。
- R8 的"模块执行顺序不变"验收链与本 phase 无交叠（全部改动为观测侧，无决策分支改动）。

**证据:**
- build_order.txt 全量内容（46 行清单含上述 7 文件）— [VERIFIED: build_order.txt:1-46]
- `while IFS= read -r line; do ... [ -f "$line" ] ... "ERROR: File not found in build_order.txt" ... done < build_order.txt` 严格模式 — [VERIFIED: build.sh:18-30]
- `.gitignore` 内容无 tools 条目 — [VERIFIED: .gitignore]

**对计划影响:**
- 计划任务一律声明"不修改 build_order.txt / 不改 build.sh"；新写 `tools/cpdamage.lua`（建议名）单独验证（bbcheck + node 无关，直接由 Lua 语义确保）。
- 若实现者受引诱新建 core 文件（如 core/cp_damage.lua），必须同时编辑 build_order.txt——计划应明确禁止这条路径（推荐全部纳入既有 7 文件，blast radius 最小、与 Phase 27 记账口径一致）。

## 9. 验证命令资产

**结论:**
- **bbcheck.js**（.planning/phases/27-.../tools/bbcheck.js）是 Lua 感知括号平衡检查器：先剥离块注释 `--[[ ]]`、长字符串 `[=[ ]=]`、行注释 `--`、短字符串字面量（`"..."`/`'...'` 含转义），再对 `()[]{}` 做栈平衡；逐文件输出 `BALANCED`/`MISMATCH`，exit code 0/1。**是本机无 Lua 环境下的事实语法门**，Phase 27 验证模板逐字：`node <path>/bbcheck.js <files...>`　+ `git diff --check` 干净 + `./build.sh` 重建 SM_Extend.lua + 新符号 grep 到位 + leftover 标识符清零。
- **build.sh**（root）：删旧 SM_Extend.lua → 按 build_order.txt 严格拼接（缺文件即 exit 1）→ Cygwin 才拷贝到游戏目录。
- 无现成 Lua 解释器（`command -v lua/luac/lua5.*` 全空）——分析器的运行级验证不能在本机发生；bbcheck.js 即仓库为之设计的补偿机制（27-SECURITY.md:24 明言"Repo-local node script… simple, reviewable, no network"）。
- SelfTest 注册表字母现状：Category O/Q/R/S/T 已占用（Cat T-01 = LOG_MAX_SIZE 默认 500 测试）— **Phase 28 用 Category U**，格式 `"Cat U-01: <desc>"` + `isOptional=true` + `UnitClass('player') ~= 'Druid' then return end` 门。

**证据:**
- bbcheck.js 全文（strip 顺序与栈逻辑）— [VERIFIED: .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js:1-28]
- 27-03 计划的验证电池模板（`node …bbcheck.js <7 files>；git diff --check；./build.sh…`）— [VERIFIED: .planning/phases/27-…/27-03-selftest-verification-cleanup-PLAN.md:104,125]
- Category 占用普查（`"Cat T` 存在，`"Cat U` 不存在）— [VERIFIED: 全仓 grep，classes/druid/selftest.lua 等]
- 本机依赖探测 — [VERIFIED: 本会话 `command -v` 探测]

**对计划影响:**
- **建议 Phase 28 verify 电池**（每个 plan 的自动 verify 段直接抄）：`node .planning/phases/27-…/tools/bbcheck.js <本 phase 触及的全部 .lua 含 tools/cpdamage.lua>`（全 BALANCED）→ `./build.sh`（exit 0 且 SM_Extend.lua 出现 `cpDamage` 新符号 ≥ 预期计数）→ `git diff --check` → 特定 grep 断言（如 `grep -c "cpDamageLog" macro_torch.lua` 期望数、`grep -c "build_order" git diff` = 0）。
- **cpdamage.lua 自身内置 `--selftest` 子命令**（纯函数断言 + 内嵌小样本 SuperMacro.lua 形态 fixture），供用户机器 `lua tools/cpdamage.lua --selftest` 一次验证 5.0/5.1/5.4 全链——把"语法自验覆盖 5.0"落到用户实机（UAT 项），本机则以 bbcheck 为自动门。
- 一个 `checkpoint:human-verify` 挂在 UAT：用户实机运行 `/run macroTorch.cpDamageLog=true` 打骷髅桩 1 分钟 → ReloadUI → 拷回 SuperMacro.lua → 跑 analyzer 出第一张真实统计表（端到端闭环）。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SavedVariables 反序列化 | 自己解析 Lua 表转义/key 形式 | marker + 括号配平 + `loadstring`(沙箱) | 该段本身是合法 Lua；手写 parser 必在转义/key 变体上翻车 |
| 括号配平的字符串误配 | 裸字符计数 | 字符串/注释感知扫描（bbcheck.js strip 逻辑同构） | JSON body 内含 `{}` 引号必然错配 |
| cast→damage 配对 | 从零设计队列 | LRUStack + LAND_INTENT_TTL + pairLandIntent 模式（独立新表） | Phase 27 已考过序噪声/fail-wins；复刻可读性最好 |
| JSON 编解码 | 找 1.12 时代的 json 库 | 两端自控制的 ~30/100 行迷你实现 | 1.12 无库；字段集合封闭，通用库是负资产 |
| 伤害行正则 | 按名匹配技能名的启发式 | 通道白名单 + `hits|crits … for N.` 句式 + GUID 窗口配对 | 技能名随 locale 变；耿直 channel/template 实锤 |

**Key insight:** 本 phase 的全部"难"点（事件噪声、配对乱序、序列化歧义、库缺失）都有仓内或官方文档的现成答案——实现成本集中在 disciplined reuse，而非新算法。

## Validation Architecture

> config.json `workflow.nyquist_validation: true` → 本节省略条件不成立。

### Test Framework
| Property | Value |
|----------|-------|
| Framework | 无传统测试框架。四条腿：① node bbcheck.js（bracket 平衡静态门）② ./build.sh 汇编完整性 ③ 游戏内 SelfTest 注册（Category U）④ tools/cpdamage.lua --selftest 内置断言 |
| Config file | none（脚本直接跑；SelfTest 复用 core/selftest.lua 框架） |
| Quick run command | `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js <changed .lua files>` |
| Full suite command | `./build.sh && node .../bbcheck.js <all touched> && git diff --check && <grep 断言组>`（此机无 lua；cpdamage.lua 运行级在用户机 `lua tools/cpdamage.lua --selftest`） |

### Phase Requirements → Test Map
（无正式 REQ ID — ROADMAP Requirements: TBD。按 D-xx 决策映射:）
| 锚 | 行为 | 测试类型 | Automated Command | File Exists? |
|----|------|----------|-------------------|-------------|
| D-06 | cpDamageLog nil-guard 默认 false + CONFIG_OPTIONS 第 5 项 | 静态+Selftest | `grep -c "cpDamageLog" macro_torch.lua` ≥ 2；Cat U 注册 | ❌ Wave 0（新写） |
| D-07/D-12 | 编码器输出 11 字段 JSON 字面量 | unit（纯 Lua） | Cat U 编码断言 + analyzer `--selftest` 往返 fixture | ❌ Wave 0 |
| D-01 | SELF_DAMAGE 通道门 + 句式解析（hits/crits/for N.） | 静态+集成（实机） | bbcheck + 实机 UAT 打桩 | ❌ Wave 0 |
| D-02 | pairCpDamageIntent TTL=2 purge/pair | 静态 | bbcheck + grep TTL 复用 | ❌ Wave 0 |
| D-11 | batch 写入 context | 静态 | grep `_cpDamageBatch` combat_context.lua | ❌ Wave 0 |
| D-17~D-21 | 两层报表/四档桶/拟合 b/建议行 | analyzer 自测 | `lua tools/cpdamage.lua --selftest`（用户机）+ 本机 fixture 无 | ❌ Wave 0 |
| R8 | 既有 catAtk 逻辑零改动 | 回归 | `git diff` 范围审计 + SM_Extend.lua 既有符号 grep 不变 | ✅ 现有 grep 断言复用 |

### Sampling Rate
- **Per task commit:** `node bbcheck.js <该任务触及文件>` + `git diff --check`
- **Per plan 收尾:** `./build.sh`（exit 0）+ 全触及文件 bbcheck + grep 断言组 + Selftest 注册计数
- **Phase gate:** 全电池绿 + 用户机 UAT（打桩 1 分钟 + analyzer 出表 + `--selftest` 两解释器各跑一次）后才 `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tools/cpdamage.lua` translate——最粗的空缺：分析器与 `--selftest` fixture 本身
- [ ] `classes/druid/selftest.lua` Category U 注册段（或 Druid.lua 尾部，随 23-27 传统）
- [ ] 编码器单元断言（Cat U 内纯函数断言即可，无需独立框架）
- [ ] 验证电池命令复制进各 plan verify 段（bbcheck 路径、grep 期望数）

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes — 分析器吃外部文件 | 括号配平 span 只取 `MACRO_TORCH_LOG =` 段；前缀过滤仅 `[cpDamage] `；JSON 解码器对字段类型严格校验（非数即弃+计数） |
| V2/V3/V4 | no | 无账号/会话/授权面 |
| V6 Cryptography | no | 无加密需求（本 phase 不锁加密存储） |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 恶意/损坏 SuperMacro.lua 注入可执行 Lua（loadstring 执行任意段） | Tampering / Elevation | 沙箱执行：5.0/5.1 `setfenv(fn, env)` 空环境 + 禁用危险全局；5.2+ `load(block, nil, 't', env)`；执行后仅允许读 `MACRO_TORCH_LOG` 键 |
| 超大文件/条目轰炸拖死分析器 | DoS | 文件上限（如 32MB）拒绝；条数上限（如 50k）截断并警告 |
| 损坏 JSON 单行致解析崩溃 | DoS | 解码器 pcall 包裹，坏行跳过并计数告警（不中断整批） |
| 游戏内比赛恶意日志注入（同环其他 `[cpDamage]`-like 文本） | Spoofing | 前缀精确匹配 + decode 成功双门槛；环里只有本 addon 写的行（MACRO_TORCH_LOG 私有表） |
| rawdiag2 双开关同开时环被 150 行/窗口的 RAW 文本挤爆 | Info Disclosure / DoS | 沿用既有 LAND 语义：LOG_MAX_SIZE 环淘汰由用户自调（D-10）；文档提醒两者不要同开 |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| node | bbcheck.js 验证门（Q9 资产） | ✓ | v24.19.0 | 无（核心门） |
| bash/sh + coreutils | build.sh、git diff | ✓ | — | — |
| lua / luac | tools/cpdamage.lua 运行级验证 | ✗ | — | 本机跳过运行级验证：bbcheck 当语法门 + 用户机（Cygwin 游戏环境）跑 `--selftest` 与 UAT |
| SuperWoW（客户端插件） | RAW_COMBATLOG / UnitExists GUID | 游戏机侧 ✓（debug 文档证） | — | 无（D-01 钦定无兜底；SUPERWOW_STRING nil 门静默降级） |
| SuperMacro .toc 含 MACRO_TORCH_LOG | 持久化 | 游戏机侧 存疑（本机两变体 toc 一有一无） | — | checkpoint:human-verify 人工确认，缺失则补一行 |

**Missing dependencies with no fallback:** 无 —— lua 缺失已被 bbcheck.js + 用户机 UAT 覆盖。
**Missing dependencies with fallback:** lua 运行时（本机）→ 静态门 + 实机 UAT。

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 1.12 客户端 UnitDebuff 名义上限 16（1..40 无危害） | 5 | 无功能风险（nil 安全 + 复用 hasBuff）；仅文档精确度 |
| A2 | 游戏机端 SuperMacro .toc 已含 MACRO_TORCH_LOG 声明（依赖 260817-sg1 确立记录） | 2 | 若缺失：打点静默零持久化 → 已设 checkpoint:human-verify |
| A3 | 非英文客户端的 hits/crits/句式不同（本样本集全英文） | 1 | 中文客户端 crit 识别失败 → 设计为动词白名单外写 null，桶均值不受影响 |
| A4 | 玩家游戏机有可用的 lua 解释器（Cygwin） | 9/Validation | 若无：`--selftest` 无法实机跑 → UAT 退化为仅看终端表的测试性保险（分析器仍可在任意在线 lua 环境验证） |
| A5 | SV 文件中数组行以 `-- [1]` 注释尾缀或 `[1] =` 两种之一（样本只见后者） | 2 | 无风险：loadstring 吃两种语法 |
| A6 | 最小二乘公式为教科书标准实现无版本坑 | 6 | 低（双精度一致） |

## Open Questions

1. **SPELL_DAMAGE 语义名 vs 实际通道名的最终确认**
   - 我们知道：无 SPELL_DAMAGE 事件名，SELF_DAMAGE 通道 + hits/crits 句式经 6 文件实锤。
   - 未确认：D-01 用"SPELL_DAMAGE"是否用户脑中 WotLK COMBAT_LOG_EVENT 子事件名的映射习惯（讨论日志显示用户选择措辞如此）。
   - 建议：planner 按本研究报告落实为通道+句式方案即可，在 plan 首任务注释里写清改名依据链接本节，无需再拉用户确认。
2. **crit 字段在非英文客户端 / 中文客户端的动词形态**（与 A3 同源）——设计已容错，不再阻塞。
3. **分析器文件名**（`tools/cpdamage.lua` vs 其它）——Claude's Discretion，planner 拍板即可。

## Sources

### Primary (VERIFIED this session)
- `core/spell_trace_core.lua`（全文; TTL=2@15、intent 元素@125、pairLandIntent@179-210、finalizeFail@319-360）
- `core/events.lua`（全文; 注册@21-51、RAW 分支@135-205、tier-1 白名单@187-189）
- `core/combat_context.lua`（onCombatEnter/Exit@21-35）
- `core/periodic.lua`（LRUStack push/top@31-86）
- `classes/druid/combo.lua`（clickContext@57-107、catAtk 链@49-191）
- `classes/druid/Druid.lua`（obj.claw/shred/ferocious_bite@25-58、cpBuildLogSample@332-348、computeClaw_E@501-509、computeShred_E@642-645、SpellTrace 注册@723-747、isRip/Rake/PouncePresent@1137-1304）
- `classes/druid/cat.lua`（regularAttack@45-61、termMod/cp5Bite/bite 调用点@109-156,217,467）
- `entity/Unit.lua`（hasBuff@26-34、guid map@103-109、mana@114-116）、`entity/Player.lua`（isBehindTarget@602-605）
- `texture_map.lua`、`macro_torch.lua`（nil-guards@26-55、CONFIG_OPTIONS@65-94）、`interface_debug.lua`（log 持久化@17-23,102-124）、`impl_util.lua`（无 JSON）
- `.planning/samples/sample_back_again.txt` 等 6 个真实客户端样本（通道普查 + 句式实锤）
- `.planning/debug/catatk-premature-rip-recast.md:92`（实机 RAW 布局结论）
- `docs/superwow_features.md:10`（SuperWoW 官方特性清单：RAW_COMBATLOG arg1/arg2）
- `/home/admin/workspace/SuperMacro-turtle-paw/SuperMacro.toc:24` 与 `SuperMacro-turtle-SuperWoW/SuperMacro.toc`（SavedVariables 声明差异）
- `.planning/phases/27-…/tools/bbcheck.js` 全文 + 27-03-PLAN 验证电池模板
- `build_order.txt`、`build.sh`、`.gitignore`
- Lua 5.0 官方手册（lua.org/manual/5.0，本会话下载核验 gsub/format %q/unpack/loadstring）

### Assumed (flagged)
- 1.12 UnitDebuff 上限 16（在线权威源未能获取；设计已 nil-安全）
- 用户机 lua 解释器存在性
- 非英文客户端动词形态

## Metadata

**Confidence breakdown:**
- 事件结构与 crit：HIGH（真实客户端样本 + 官方 SuperWoW 文档 + 实机 debug 结论三方一致）
- 配对/挂点/能耗/clickContext：HIGH（全部本会话逐行 Read + 逐字引用）
- SavedVariables：HIGH 判策略可行（loadstring 容错）+ MEDIUM 于存疑声明（checkpoint 覆盖）
- 分析器 5.0 兼容：HIGH（官方手册核验）｜1.12 debuff 上限：LOW（ASSUMED，无阻塞）

**Research date:** 2026-09-08
**Valid until:** 2026-09-22