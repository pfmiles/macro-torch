# Todo: 下个 CD 实机取证 Rip 存在性误判的两条候选通道

> 日期：2026-09-07 | 优先级：high | 来源：`/gsd-explore`（Solnius Rip re-cast 排查，见 `notes/solnius-rip-presence-raid-evidence.md`）

## 背景

Solnius 战 Jadepaw 正常阶段 9 个 5cp 全部重放 Rip、0 bite。离线证据已确认 isRipPresent 恒 false，候选通道两条：(i) hasBuff 在 boss 上恒 false（日志强烈支持）；(ii) land/ripLeft 证据链断裂（A1 intent 配对，未排除）。以下步骤在**下一场正常模式 boss 战**中按顺序执行，一次战斗可全部完成。

## 取证步骤

1. **确认 UnitDebuff 是否能看到自己的 Rip（判 (i)）**
   - 挂上 Rip 后，鼠标悬停 boss 的 debuff 图标：自己的 Rip 图标（Ability_GhoulFrenzy）是否可见。
   - 或临时用 `macroTorch.listTargetDebuffs('target')` 打印目标全部 debuff。
   - 判定：看不到 Rip → (i) 成立，修复方向锁定"tick 活性/fade 事件替代 hasBuff"（与既有 debug doc 的事件驱动方向一致）；看得到 → (i) 排除。
2. **绿色 landed 行对照（判 (ii)）**
   - 战斗中观察绿色 `Rip cast on <mob> landed: ...` 是否出现。
   - **对照物：** Rake 走 self-hit 通道应有绿色 landed 行。Rake 有 / Rip 无 → aura-apply 配对链断裂，下一步打印 RAW 行；两者都无 → 桥（`_pendingCastSpellName` / UNIT_CASTEVENT）或聊天通道整体问题（A1 强化）。
3. **RAW_COMBATLOG 原始行打印（如步骤 2 指向配对链）**
   - 临时在 `core/events.lua` RAW_COMBATLOG 分支打印 arg1/arg2 原文（注意白名单当前只放行两个 periodic 频道——打印需放在白名单判断之前，且限流量≥防刷屏约束与既有 RAWDIAG 设施一致）。
   - 目标：确认 `0x… is afflicted by Rip.` 行确实到达、GUID 与 `macroTorch.target.guid` 一致、且当时有 pending intent。
4. **开启 cpBuildLog（顺带采样）**
   - 开 `macroTorch.cpBuildLog`，采集 5cp 时刻的 cp/能量节奏，用于复算"每个 5cp 是否被 Rip 吃掉"的代码路径。
5. **回报数据**：把打印结果与样本拷回后，据实定稿修复方案（预期落在事件驱动 land 机制的 hasBuff 替代腿上；修复动作另行走 GSD 阶段流程，不在本 todo 内）。