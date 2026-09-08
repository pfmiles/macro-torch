# Phase 28: catatk claw/shred/bite damage instrumentation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-08
**Phase:** 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
**Areas discussed:** 伤害采集与配对, 打点开关与条目结构, 持久化桥与离线脚本, 分析口径与公式

---

## 伤害采集与配对

| Option | Description | Selected |
|--------|-------------|----------|
| 任意来源的流血 | claw 加成计任意人挂的 rake/rip/pounce | ✓ |
| 仅自己挂的流血 | 只计自己 land 成功的流血 | |
| 不确定按任意来源设计 | 保守口径 | |
| UnitDebuff 扫描快照 | cast 时刻 1..40 扫描 + 贴图匹配 | ✓ |
| land 追踪重建 | 只认自己的流血状态机 | |
| 扫描为主 + land 兜底 | 双链路 | |
| RAW_COMBATLOG 解析无兜底 | SPELL_DAMAGE 事件真实伤害 roll | ✓ |
| RAW + 聊天报文兜底 | 双 parser | |
| 仅聊天报文 parse | 正则解析 | |
| 复用 Phase 27 land 配对 | cast intent + 技能名 + GUID + 时间窗 | ✓ |
| 简化最近匹配 | 最近一次同技能 cast | |
| 完全不记录未命中 | 用户：偶发因素等概率可忽略，纯伤害比较 | ✓ |
| 记录零伤害条目 | 顺带命中率 | |
| 动态理论常量 | CLAW_E/SHRED_E compute 方法值，BITE_E=35 | ✓ |
| 施法帧实际耗能 | UnitMana 差值 | |
| 对齐 land 2s 窗口 | 已验证参数 | ✓ |
| 放宽 3-5s | 高负载容错 | |
| 测试协议规避 overkill | 打木桩不死，天然规避 | ✓ |
| 分析器剔除 overkill | 识别不可靠 | |
| 三门 + 来源本人 + 排除 tick | 白名单 | ✓ |
| 仅木桩 | isTargetDummy 门，骷髅/60/1 级梯度 | ✓ |
| 只记非玩家目标 | 木桩可选 | |

**User's choice:** RAW_COMBATLOG SPELL_DAMAGE + Phase 27 land 配对 + 未命中忽略 + 动态理论能耗 + 2s 窗口 + 仅木桩。
**Notes:** 用户关键机制澄清——(1) 流血加成口径是**任意来源**（其他猫的 rake/rip/pounce 也算），因此 bleedCount 必须是 cast 时刻 UnitDebuff 扫描快照，land 追踪覆盖不了此口径；(2) claw/shred 的记录不关心 OOC，一律记理论能耗——OOC 只是 catAtk 执行层的决策场景，不影响效率统计口径；(3) **bite 例外**——OOC 时 bite 能耗被省略，多余能量 = 当时全部能量（≤100 全部被 bite 转换清空），所以 bite 必须额外记 energyPool + isOoc；(4) 测试基本都打木桩，木桩不死 → overkill 无需任何处理。另按用户要求实查了代码：computeClaw_E（Druid.lua:501）、computeShred_E（Druid.lua:642）是动态方法调用，BITE_E=35 是 combo.lua:62 硬编码门槛常数。

## 打点开关与条目结构

| Option | Description | Selected |
|--------|-------------|----------|
| macroTorch.cpDamageLog | cpBuildLog 同族命名 + CONFIG_OPTIONS 第 5 项 | ✓ |
| macroTorch.dmgLog | 更短 | |
| 全字段 11 项 | spell/dmg/crit/e/energyPool/bleedCount/isOoc/isBehind/cp/t/batch | ✓ |
| 精简 7 项 | 无 cp/crit/behind | |
| 复用 LOG_MAX_SIZE(500) | 用户 /run 自调，自行控制 | ✓ |
| 独立 DMG_LOG_MAX_SIZE=5000 | 更大容量 | |
| batch 字段自动分批 | PLAYER_REGEN_DISABLED 取 GetTime() | ✓ |
| 哨兵条目切分 | 异质数组 | |
| 脱战 flush 历史表 | 历史表管理 | |
| /run 手动清空 | 手动批次 | |

**User's choice:** cpDamageLog + 全字段（因 batch 方案 10→11 项）+ 复用 LOG_MAX_SIZE + batch 字段自动分批。
**Notes:** 用户问"能否靠进/脱战事件自动分批"——能，core/combat_context.lua 已有 PLAYER_REGEN 事件对；木桩场景开打即新批次、停手约 5s 自动脱战结束批次，与"换装备/天赋后重采"的复用诉求天然契合。

## 持久化桥与离线脚本

| Option | Description | Selected |
|--------|-------------|----------|
| [cpDamage] 前缀 + JSON body 入 messages 环 | 用户钦定，仿 cpBuild 模式 | ✓ |
| 新开子表存 JSON 字符串 | 字面 json array 独立区 | |
| 原生 Lua 嵌套 table | SavedVariables 本机序列化 | |
| 前缀过滤 + 剥前缀 + decode | 确定性识别 | ✓ |
| 无前缀纯 JSON + 字段识别 | 启发式 | |
| 前缀哨兵字符 | 控制字符可读性差 | |
| Lua 5.0 方言兼容 | 用户要求与游戏内代码同方言 | ✓ |
| 仅 Lua 5.4 | 现代特性 | |
| 终端表 + --json-out | 跨阶段结论归档对比 | ✓ |
| 仅终端 / Markdown | | |
| repo tools/ + 路径参数 | 不入 build_order.txt | ✓ |
| 手动复制段到单独文件 | 手工步骤 | |

**User's choice:** `[cpDamage] ` 前缀 + JSON body 复用 messages 环；Lua 5.0 方言（禁 # 运算符/goto，与游戏内代码一致，5.1–5.4 解释器均可运行）；终端表 + --json-out；repo tools/ 独立脚本 + SuperMacro.lua 路径参数。
**Notes:** 用户主动建议沿用 [cpBuild] 前缀模式；明确要求不新开 SavedVariables 子表（SuperMacro 可落盘的只有已注册表），LOG_MAX_SIZE 即约束该环。

## 分析口径与公式

| Option | Description | Selected |
|--------|-------------|----------|
| 每批次 + 聚合两层 | 单批趋势 + 大样本均值，低样本 n 警告 | ✓ |
| 仅聚合 / 仅每批次 | | |
| 线性拟合边际转化率 b | dmg=a+b×(能量−35)，OOC 用能量−0 | ✓ |
| 能量桶平均伤害 | 每 10 点一档人工判读 | |
| 输出明确决策建议 | 各档 builder/OOC 技能/bite 泄能 | ✓ |
| 仅统计表 | 人肉对比 | |
| OOC 结论也分档 | claw 单次伤害随档位变，背位样本 | ✓ |
| OOC 不分档 | 总体均值 | |

**User's choice:** 两层报表 + 线性拟合 b + 明确决策建议 + OOC 分档。
**Notes:** 用户纠正了主持人一句叙述——"实验只回答单次伤害谁高"不完整：实验回答**两个**独立问题（非 OOC 的 energy efficiency 对比 + OOC 的单次伤害对比）；采集口径（claw/shred 一律记理论能耗）不变，它保证效率分母口径干净。

## Claude's Discretion

- cast-intent 队列与配对实现细节（Phase 27 land 架构上）
- crit 字段可检测性由 researcher 核实 RAW 事件格式
- 分析器 parser/decode/表格排版
- 打点 hook 确切挂点（cpBuildLog 挂点体系内）
- SelfTest 用例与桩函数写法（Category 字母 + isOptional + UnitClass guard 传统）

## Deferred Ideas

- `druid-rip-land-forensics-next-cd.md` todo 不折入（用户决定），保持独立 pending——rip landing 取证与 claw/shred/bite 伤害打点是不同问题域
- 多猫环境 / 真实敌人目标采集——未来 phase