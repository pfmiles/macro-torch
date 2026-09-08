# Phase 28: catatk claw/shred/bite damage instrumentation — opt-in combat log + offline analyzer - Context

**Gathered:** 2026-09-08
**Status:** Ready for planning

<domain>
## Phase Boundary

为 catAtk 两大核心输出决策提供实测数据支撑的可复用打桩系统：

1. **游戏内采集端** — `macroTorch.cpDamageLog` bool 开关（默认 false 关闭）控制的打桩逻辑：战斗中对 Training Dummy 施放的 claw/shred/bite，采集真实伤害与必要状态，以 `[cpDamage] ` 前缀 + JSON 单行条目写入既有 `MACRO_TORCH_LOG.messages` 持久化环。
2. **离线分析端** — repo `tools/` 下独立可运行 Lua 脚本（Lua 5.0 方言，自包含），用户以 SuperMacro.lua SavedVariables 路径为参数运行，自动提取解析并输出统计与决策建议。

**实验回答三个独立问题**（本 phase 产物的意义锚点）：

1. **energy efficiency 对比**（claw vs shred，按目标流血效果数 0/1/2/3 分档）→ catAtk 常规循环（非 OOC）选哪个 CP builder 的依据；
2. **单次伤害对比**（同分档，不看能量）→ OOC 触发时（技能免费）选哪个技能的独立依据；
3. **bite 多余能量边际转化率 b**（超出 35 点门槛的能量每点换多少伤害）→ 与 1 的最佳 builder 效率对比，决定 bite 前是否先 claw/shred 泄能；该结论依赖前两者的统计结果。

**复用性设计**：常设开关 + 进/脱战自动分批 + 每批次/聚合两层报告 — 装备/天赋变化后随时重新打桩采纳当时结论，不是一次性数据实验。

**范围限定**：仅木桩（Training Dummy）打点、仅 claw/shred/bite 三门技能、仅采集不修改任何 catAtk 决策逻辑；分析器只做统计不写回游戏数据。新能力（如真实敌人目标采集、多猫环境取证）属其他 phase。
</domain>

<decisions>
## Implementation Decisions

### 伤害采集与配对

- **D-01: 伤害源 = RAW_COMBATLOG SPELL_DAMAGE 事件** — 无聊天报文兜底链路。白名单过滤：仅 claw/shred/bite 三门技能 + 来源 GUID = 本人 + 排除 SPELL_PERIODIC_DAMAGE（rake/rip tick）与 aura 类子事件。客户端 RAW_COMBATLOG 可用性有既有先例（rawdiag2 白名单前 scout）。**Reversibility:** reversible

- **D-02: cast→damage 配对复用 Phase 27 land 架构** — cast 时记 intent（技能名 + 来源 GUID + 时间戳），SPELL_DAMAGE 事件按 技能名 + 来源 GUID + 时间窗 配对；配对窗口对齐 land 的 2s 过期参数；未配对 intent 自然过期丢弃。**Reversibility:** reversible

- **D-03: 未命中完全不记录** — immune/miss/dodge/resist 不写入日志。用户口径原文：目的是纯技能伤害比较，偶发因素对任何一个攻击技能的概率相同，可以忽略。架构上对称简化：无伤害事件 → 无配对 → 无条目，零额外处理。

- **D-04: bleed 档位 = cast 时刻 UnitDebuff 扫描快照** — UnitDebuff 1..40 + texture_map 贴图匹配，计数 0-3（rake/rip/pounce）。**口径：任意来源**（其他猫挂的流血也计入 claw 加成），多猫团本场景下 claw 样本按当时实际档位入桶。**Reversibility:** reversible

- **D-05: 仅 Training Dummy 打点** — `clickContext.isTargetDummy`（combo.lua:104 已有现成判断）为硬门；骷髅级/60/1 级等多档木桩覆盖测试情形，暂不考虑真实敌人。木桩不会死 → overkill 样本天然不存在，分析器无需任何 overkill 处理。

### 打点开关与条目结构

- **D-06: 开关 `macroTorch.cpDamageLog`** — bool 默认 false；login/reload 复位；进 CONFIG_OPTIONS 注册表第 5 项（登录横幅含默认值与 /run 设置命令）。沿用 cpBuildLog 三大惯例。

- **D-07: 条目 11 字段** — `spell`（claw/shred/bite）、`dmg`、`crit`、`e`（该技能理论能耗）、`energyPool`（施法时刻能量池快照）、`bleedCount`（0-3）、`isOoc`、`isBehind`、`cp`（连击点）、`t`（GetTime）、`batch`（进战斗 GetTime）。

- **D-08: 能耗取 clickContext 动态值（已代码实查）** — `CLAW_E = macroTorch.computeClaw_E()`（Druid.lua:501：45 − 3(Idol of Ferocity) − talentRank('Ferocity')）；`SHRED_E = macroTorch.computeShred_E()`（Druid.lua:642：60 − talentRank('Improved Shred')×6）；`BITE_E = 35` 硬编码门槛常数（combo.lua:62）。catAtk 每按键开头已算好放入 clickContext（combo.lua:57-65），hook 直接引用即可，无需重复计算。

- **D-09: OOC 口径（用户明确指出）** — claw/shred 的记录不关心 OOC：一律记理论能耗入效率统计（分母口径干净无偏）。**bite 例外**：OOC 时 bite 能耗被省略，多余能量 = 当时全池（≤100，全部被 bite 转换清空），因此 bite 条目必须记录 `energyPool`（施法时刻 `player.mana` 快照，cpBuildLogSample 的 e 字段有现成先例 Druid.lua:332）+ `isOoc` 标记；常规 bite 多余能量 = energyPool − 35。

- **D-10: 缓冲复用 MACRO_TORCH_LOG.messages + LOG_MAX_SIZE** — 不新开子表；上限默认 500，用户游戏内 /run 赋值自调（如 `/run macroTorch.LOG_MAX_SIZE=3000`）。

- **D-11: 进/脱战自动分批** — `PLAYER_REGEN_DISABLED`（进战斗）时取 GetTime() 作 `batch` 写入每条条目；脱战自动进入下一批。`core/combat_context.lua` 已有该事件对与 context 生命周期，挂点现成。木桩场景：开打=进战斗=新批次，停手约 5s 自动脱战=批次结束；无任何手动操作，同一环多批次共存，分析器按 batch 分组。

### 持久化桥与离线脚本

- **D-12: `[cpDamage] ` 前缀 + JSON body（用户指定，仿 cpBuild）** — 条目 = `'[cpDamage] ' .. jsonString`，走 `macroTorch.log` 同一写入路径入 `MACRO_TORCH_LOG.messages` 环，与 `[cpBuild]` 行为兄弟行；WTF 文件里人肉可读。

- **D-13: 分析器按前缀识别** — `[cpDamage]` 前缀过滤 → 剥前缀 → JSON decode，识别确定性 100%，无需启发式。

- **D-14: 分析器落位** — repo `tools/` 子目录独立脚本（**不入 build_order.txt**，绝不编入 SM_Extend.lua）；用户运行：`lua tools/<script>.lua <path/to/WTF/Account/<acc>/SavedVariables/SuperMacro.lua>`，脚本自动定位提取 MACRO_TORCH_LOG 段。注意 SavedVariables 是 Lua table 语法而非纯 JSON——脚本需内置对 1.12 序列化格式的提取（marker + 括号配平）。

- **D-15: Lua 5.0 方言兼容（用户要求与游戏内代码一致）** — 禁 `#` 长度运算符、goto 等 5.1+ 特性；同一脚本在 5.1–5.4 任意标准解释器可运行；自包含无外部依赖；语法自验必须覆盖 5.0。

- **D-16: 输出 = 终端统计表 + `--json-out` 可选结果文件** — JSON 结果文件服务于跨装备/天赋阶段的结论归档对比（多次复用测试的核心诉求）。

### 分析口径与公式

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
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 需求与原则文档
- `.planning/ROADMAP.md` §Phase 28 — Goal 原文（用户完整中文需求描述，含两大决策的机制讲解）
- `.planning/REQUIREMENTS.md` — R7（build_order.txt 声明式构建）、R8（猫德逻辑保持不变）
- `.planning/catAtk-core-principles.md` — catAtk 决策原则（本 phase 的实验产物将反哺其中决策的实证依据；原则文档写作要求精华风格）

### 核心代码（采集端）
- `classes/druid/Druid.lua:501-509` — `computeClaw_E`（45 − Idol of Ferocity 3 − Ferocity 天赋）
- `classes/druid/Druid.lua:642-645` — `computeShred_E`（60 − Improved Shred×6）
- `classes/druid/Druid.lua:329-355` — `cpBuildLogSample` / `cpBuildLogEvent`（cast 前 GCD probe + {t, cp, e} 采样模板 + 前缀打点先例）
- `classes/druid/combo.lua:57-65` — clickContext 能量常量初始化（每按键算好的动态值）
- `classes/druid/combo.lua:104` — `isTargetDummy` 现成判断
- `classes/druid/combo.lua:49-191` — `catAtk` 模块链（hook 挂点锚位）
- `classes/druid/cat.lua` — `regularAttack` / `energyDischargeBeforeBite` / `cp5Bite` / `termMod`（claw/shred/bite 释放路径锚点）
- `core/combat_context.lua` — PLAYER_REGEN_DISABLED/ENABLED 进脱战事件与 context 生命周期（batch 挂点）
- `core/spell_trace_core.lua` — Phase 27 land 配对架构 + rawdiag2 RAW_COMBATLOG 白名单收流先例（配对与过滤骨架）
- `entity/Unit.lua` `hasBuff` + `texture_map.lua` — UnitDebuff 扫描与流血贴图匹配（bleedCount 快照链路）
- `macro_torch.lua` — CONFIG_OPTIONS 注册表（第 5 项加入点）+ `LOG_MAX_SIZE` nil-guard
- `core/selftest.lua` — SelfTest:register API 与既有 Category 测试注册模式

### 持久化与提取
- 游戏内：`WTF/Account/<account>/SavedVariables/SuperMacro.lua` 的 `MACRO_TORCH_LOG.messages`（500 环形缓冲，Lua table 序列化格式，分析器需内置提取）

### 直接依赖 Phase 的 CONTEXT
- `.planning/phases/26-phase-fast/26-CONTEXT.md` — `shouldUseShred` bleedCount 决策树（claw vs shred 现状逻辑，本 phase 实验要回答的正是其参数依据）
- `.planning/phases/23-idol-dance-refactor/23-CONTEXT.md` — Category SelfTest 命名与 clickContext 预设测试传统

### 构建系统
- `build_order.txt` — 分析器脚本**不加入**；打点代码所在文件已在列表内
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase 27 land 配对架构**（`core/spell_trace_core.lua`）— cast intent + GUID + 2s 窗口配对骨架，伤害事件的配对直接复用
- **RAW_COMBATLOG 收流先例**（rawdiag2 白名单前 scout）— 事件侧过滤模式的成熟代码
- **`cpBuildLogSample()`**（Druid.lua:332）— cast 前 GCD probe + 能量快照采样模板，伤害打点采样的直接蓝图
- **`macroTorch.log` + `LOG_MAX_SIZE` 环** — 统一持久化写入口，零新增存储结构
- **clickContext 动态值全集** — `computeClaw_E/computeShred_E/BITE_E/ooc/isBehind/comboPoints/isTargetDummy` 每按键现成
- **`hasBuff` + `texture_map`** — UnitDebuff 流血扫描链路
- **CONFIG_OPTIONS 横幅机制** — 新开关的注册与展示点

### Established Patterns
- **前缀打点**：`[cpBuild] ` → 本 phase `[cpDamage] `（用户钦定同族风格）
- **per-session 配置 bool**：默认 false、login/reload 复位、横幅含设置命令（cpBuildLog/rawdiag2Enabled/LOG_MAX_SIZE 三先例）
- **SelfTest Category 字母**：`"Cat X-NN: description"` + `isOptional=true` + `UnitClass` guard
- **Lua 5.0 方言**：游戏内代码与离线分析器同约束（无 `#` 运算符/goto），全仓库自验覆盖 5.0
- **英文注释与 commit**：全仓库惯例

### Integration Points
- `macroTorch.log` — 伤害条目唯一写入出口（进 messages 环）
- `core/combat_context.lua` 进/脱战事件 — batch 字段的取值点
- 技能释放路径 — `regularAttack`（claw/shred 攒星）/ `termMod`（bite）附近挂采样 hook（与 cpBuildLog 同体系）
- RAW_COMBATLOG 事件流 — spell_trace_core 的事件收流处追加 SPELL_DAMAGE 白名单
- `build_order.txt` — 打点代码所在既有文件无需新增行；`tools/` 分析器**不加入**
</code_context>

<specifics>## Specific Ideas

- 用户原文核心机制（ROADMAP Goal 全文为准）："划算"的判定标准 = 伤害/能量消耗（energy efficiency）；claw 伤害随目标流血效果数（0/1/2/3，最多 rake/rip/pounce 三种）差异很大 → 结论必须分档与 shred 对比；OOC 触发时下一技能免费 → 应使用单次伤害更高的技能（原话含一处输入法乱码"即讷讷更"，已修正为"技能"，用户已同意）；bite 超出 35 点的多余能量转化效果决定"先泄能泄到 35 再咬还是让 bite 清空所有能量"，该计算依赖 claw/shred 的实验结果
- 反复强调：**可开关、可多次复用的功能而非一次性实验**——装备/天赋会变化，不同阶段多次测试采纳当时结果
- 用户钦定细节：`[cpDamage]` 前缀（仿 cpBuild）；复用 LOG_MAX_SIZE 且自行 /run 调节；进/脱战事件自动分批
- 环境事实：客户端 RAW_COMBATLOG 有 SPELL_DAMAGE/aura 事件（既有采信使用）；SuperMacro SavedVariables 是 Lua 表语法文件非纯 JSON，分析器需自行提取
- 反面约束：打点只限木桩（isTargetDummy 门），真实敌人/多猫环境是未来 phase 的事
</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
- `druid-rip-land-forensics-next-cd.md`（.planning/todos/pending/）— 下个 CD 实机取证 rip landing 抑制（需网友配合双层协议）——用户选择**不折入** Phase 28，保持独立 pending todo。Phase 28 只采集 claw/shred/bite 直伤，与该取证（rip 存在性）不同问题域。

无其他范围蔓延——讨论保持在 Phase 28 边界内。
</deferred>

---

*Phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac*
*Context gathered: 2026-09-08*