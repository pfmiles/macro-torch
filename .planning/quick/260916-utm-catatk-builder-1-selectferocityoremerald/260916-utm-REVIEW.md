---
phase: quick-260916-utm
reviewed: 2026-09-16T15:08:57Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/selftest.lua
findings:
  critical: 0
  warning: 0
  info: 3
  total: 3
status: clean
---

# Phase quick-260916-utm: Code Review Report

**Reviewed:** 2026-09-16T15:08:57Z
**Depth:** standard
**Files Reviewed:** 2（classes/druid/Druid.lua +25/-11、classes/druid/selftest.lua +279 纯插入；diff base `4854eaaa^`，范围 `4854eaaa^..fa1b359` 共 3 个 commit：4854eaa=Task 1 代码、619452e=Task 2 代码、fa1b359=docs）
**Status:** clean（0 critical / 0 warning / 3 info 纪律备忘，无缺陷）

## Summary

本 review 覆盖 quick 260916-utm 的最终态：`selectFerocityOrEmeraldRot` 增加 `clickContext` 并重构为三层优先级（8/8 T1 → 战斗粘性 → 战斗类型），`computeNormalRelic` 4 处调用点传参，selftest 新增 Cat O-08..O-16 九项。整体实现与锁定 PLAN 逐字一致：三层判定顺序、表达式原文、单件/默认分支字节语义均未偏离；执行层（recoverNormalRelic 673 行起 / ensureRelicEquipped / equipRelic / cat.lua / combo.lua）零 diff。静态门全部复核通过（三解释器 loadfile、bbcheck、token 门、CRLF、注册计数 16、插入位置、hunk 范围）。核心风险点"粘性不变式闭合"经调用链追踪确认无 F↔E 抖动路径。九项 selftest 的 stub 三拍纪律（rawget 快照 → rawset 遮蔽 → rawset 还原）全部先于任何 assert，无失败路径泄漏。未发现 Critical/Warning 级缺陷。

### 六项 review focus 验证结论（对照 live code，非文档）

1. **调用点完备性 — 通过**。全仓 grep（`--include="*.lua"`，排除 .planning）：`selectFerocityOrEmeraldRot` 定义 1 处（Druid.lua:631），生产调用面仅 `computeNormalRelic` 内 4 处（603/607/615/619），全部传 `clickContext`；无参形式 `selectFerocityOrEmeraldRot()` 全仓残留 0（grep exit 1）。`clickContext` 即函数形参，4 处调用点均在其作用域内，无局部遮蔽。selftest 内 15 处调用全部传 `{}` 或种子 ctx。`computeNormalRelic` 的唯一生产调用点 combo.lua:102 传入的是当次按键新建的 clickContext（非 nil）；`recoverNormalRelic` 唯一调用点 combo.lua:111 同步传同一 ctx。

2. **三层优先级正确性 — 通过**。第 1 层 `countEquippedItemNameContains('Cenarion') >= 8` → F 恒最先判（D-01）；第 2 层 `player.isInCombat` 守卫内先判 Ferocity（isRelicEquipped 655 行）再判 Emerald Rot（658 行），命中即返回当前穿戴件（D-02）；第 3 层 `macroTorch.isTrivialBattleOrPvp(clickContext) or macroTorch.isFastBattleNotPvp(clickContext)` → F else E（D-04，顺序与原文逐字一致）。**fast⊂trivial 压缩无分支缺失**：`willDieInSeconds(s)`（entity/Target.lua:119）单阈值线性实现 `health <= currentHRPS()*s`，对 s 单调；健康度臂 `healthMax <= (mates+1)*dps*s` 同为线性阈值。同一帧内 8.5s 臂两 disjunct 各自蕴含 25s 臂对应 disjunct（HRPS≤0 时两臂同 false；dps/mates/healthMax 同帧一致），故 fast=true ⟹ trivial=true，第二臂在数学上防御性冗余、绝无"fast 为真而 trivial 为假"的缺口场景（详见 IN-01）。

3. **nil 安全 — 通过**。第 3 层两个谓词接收 clickContext：生产链路（combo.lua 每次按键新建 ctx）与 selftest 链路均非 nil；`isTrivialBattle`/`isFastBattleNotPvp` 对 null 字段走 `== nil` 懒缓存分支（既有惯例），缺失字段安全；PvP 判定读 `target.isPlayerControlled`（UNIT_FIELD_FUNC_MAP accessor，Unit.lua:186，`toBoolean` 包裹恒返回布尔）；`player.isInCombat`（Unit.lua:226，同样 toBoolean 包裹）。Lua 5.0 下无 nil 参加算术/比较的路径：`>=` 两侧分别为函数返回数与字面量 8（该表达式为变更前既有字节）；`or` 链对 nil/布尔/数字均合法。4 处无参调用清零后不存在"nil 透传进第 3 层"的入口。

4. **粘性不变式闭合 — 通过（本变更核心风险点）**：
   - **(a) worldboss in-combat gate 交互**：`recoverNormalRelic`（Druid.lua:673-697，执行层零改动）对"战斗中且非 worldboss"直接 return；仅 worldboss 战斗中允许换装。逐一推演：战斗中穿任一 builder → 选择层 sticky 恒返回穿戴件 → recovery 的 `isRelicEquipped(relicName)` 早退，**无 builder↔builder 互切**；穿 Savagery 时 rip 重现才经第 3 层择机换装，同一目标同帧 verdict 稳定（worldboss 血量/HRPS 下 isTrivial/isFast 恒 false → 恒 E），不产生每帧抖动。唯一理论边界：若 verdict 在战斗中翻转（只可能经 Savagery 中介，sticky 已禁直接互切），F→E 至多单向校正一次/战斗，E 一旦穿上 sticky 即封死回 F——不是抖动，属设计内（D-02 锁定的粘性范围就是 builder↔builder）。详见 IN-02。
   - **(b) 8/8 T1 与粘性的关系**：T1 层恒先于粘性（O-10 pin），"战斗中穿 E 时选择仍返回 F"成立；执行层侧，非 worldboss 战斗中 gate 阻断换装，故该状态下 F 选择是惰性的（需战斗结束或 worldboss 场景由 recover 一次校正 E→F）——这是 T1 覆盖粘性在"选择层已覆盖、执行层受 D-03 零改动约束"下的已知取舍，本 quick 边界内无任何"拉回抖动"路径（每 click 选择恒 F，recover 换装后即稳定）。

5. **selftest 正确性 — 通过**。O-08..O-16 九项逐一目视核对：三拍齐全（6-family 快照 → 安装 → 还原；O-16 为 4-family，两个判定函数保留真实实现）；`isInCombat` 全程 rawget 快照（正常 nil）→ rawset 遮蔽 → rawset 按快照值还原（nil 还原即删自有键、accessor 复活）；所有还原行无条件置于任何 assert 之前（stub 安装为纯赋值不会出错，pcall 失败路径亦先还原后断言，零泄漏）；O-13/O-15 多轮测试经 mutable-upvalue 闭包实现 install-once。注册计数 `grep -c 'register("Cat O-'` = 16（7→+9），九个新注册行号 949-1198 全部位于 O-07 尾（947）与 Category Q（1228）之间，且全部在文件顶 `if UnitClass('player') == 'Druid' then` 块内。Lua 5.0 合规：新增行无 `#`/`goto`/`::`（token 门 0），三解释器 loadfile 复核通过（见 Verification 表）。抽查断言种子与预期映射全部与代码路径吻合（O-10 否定种子 Vt/Vf=false、O-12 否定种子 Vt/Vf=true、O-15b 期望 E、O-16 两轮期望 F）。

6. **diff 纯度 — 通过**。`git diff 4854eaaa^..fa1b359 --name-only` 仅 5 文件：Druid.lua（4854eaa 单文件 commit）、selftest.lua（619452e 单文件 commit）、fa1b359 仅 3 个 .planning 文档。Druid.lua 4 个 hunk（@@ -600/-612/-624/-643）全部落在 600-669 行选择层带内，变更行最深处 669（默认 return 区尾），恢复层 673 行起字节零 diff；+25/-11 与 1781→1795 行、selftest +279 纯插入（2504→2783）与 SUMMARY 口径一致。无 cat.lua / combo.lua / recoverNormalRelic / ensureRelicEquipped / equipRelic 任何改动。

## Critical Issues

无。

## Info

### IN-01: D-04 表达式第二臂 `isFastBattleNotPvp` 为同帧数学冗余（无缺口，防御性冗余备忘）

**File:** `classes/druid/Druid.lua:663`
**Issue:** 在锁定表达式 `isTrivialBattleOrPvp(clickContext) or isFastBattleNotPvp(clickContext)` 中，非 PvP 目标下 fast=true 蕴含 trivial=true（证明见 Summary 第 2 条）：`willDieInSeconds(s)`（Target.lua:119-126）是 `health <= currentHRPS()*s` 单阈值，对 s 单调；两函数的健康度臂同为 `healthMax <= (mates+1)*dps*s`，8.5 < 25。因此第二臂在任何现实帧内都不可能独自点亮——第一臂为 false 时第二臂必为 false。这不是分支缺失（反向）：**没有**"fast 为真却被压缩掉"的场景，第二臂是纯防御冗余。表达式的顺序与词形是 PLAN 锁定约束第 2 条逐字项（D-04 原文），不应改写。
**Fix:** 不改。保留该表达式原样；若未来有人基于"冗余"提议化简，需先在注释注明该臂是为 HRPS 读值帧间隔/未来 estimator 改动预留的防御性冗余。

### IN-02: 粘性闭合的边界备忘——worldboss 换装允许下单向校正与 T1 惰性 F 均为设计内取舍

**File:** `classes/druid/Druid.lua:631-671`（选择层）× `673-697`（执行层，本次零改动）
**Issue:** 两条闭合边界值得书面固定，防止后续维护误判为回归：（1）worldboss 战斗中 recovery 允许经 Savagery 中介换装，若战斗类型 verdict 在两次 rip 周期之间翻转（例如低血量时 `health <= HRPS*25` 由假转真），可发生一次 F→Savagery→E 单向校正；E 穿上后 sticky 封死回 F，故至多一次/战斗、无每帧抖动——粘性的设计范围（D-02）本来就是"builder↔builder 直接互切"而非"绝对不换装"。（2）8/8 T1 下若战斗中已穿 E（只能由人工换装等改动外路径产生），选择层恒返 F 但非 worldboss 战斗中执行层 gate（682 行）阻断换装，F 选择保持惰性至战斗结束或 worldboss 场景由 recover 一次性校正——这是 D-03 零改动约束下的已知取舍，O-10 只 pin 选择层语义，与执行层无冲突。
**Fix:** 不改代码。建议在下次触碰 recoverNormalRelic 注释时补一句"T1 覆盖仅在选择层，非 worldboss 战斗中不触发换装"以固化本结论。

### IN-03: selftest stub 的 `string.find` 未用 plain 参数 + O-16 实机验证依赖有效目标（unrun 标注）

**File:** `classes/druid/selftest.lua:958/988/1019/1049/1079`（hasItem/isRelicEquipped stub 内）
**Issue:** 五处 stub 用 `string.find(name, 'Ferocity'/'Emerald')` 未传第 4 参 `true`，与仓库既有 plain-literal 惯例（如 selftest.lua:1564 `string.find(msg, '...', 1, true)`）不一致。当前 'Ferocity'/'Emerald' 无任何 Lua pattern magic 字符，语义正确、零风险，仅纪律备忘。另：O-16 依赖实机存在可攻击的非玩家目标（守卫 `isCanAttack`/`isPlayerControlled` 不满足时静默跳过），九项新测试的 /mt 运行时行为本机 unrun（无 WoW 客户端），由用户 Windows+Cygwin 重建后目视；本 review 不臆断实机行为。
**Fix:** 未来新增类似 stub 时统一 `string.find(name, 'Ferocity', 1, true)`；O-16 实机运行需带任意攻击目标（木桩即可），无目标时该 pin 静默跳过属设计内（对齐 P 系列守卫风格）。

## Verification（实际执行的工具门与结果）

| 门 | 命令 / 对象 | 结果 |
|----|------------|------|
| 变更范围取证 | `git log --oneline 4854eaaa^..fa1b359` + 逐 commit `--stat` | 恰 3 commit；两个代码 commit 各恰 1 文件；执行层零文件 |
| Druid.lua diff 取证 | `git diff 4854eaaa^..4854eaa -- classes/druid/Druid.lua` | +25/-11；4 个 hunk 全部 < 660（@@ -600/-612/-624/-643） |
| selftest diff 取证 | `git diff 4854eaaa^..619452e -- classes/druid/selftest.lua` | 单 hunk @@ -946,6 +946,285 = 279 纯插入 |
| 调用点完备性 | 全仓 grep `selectFerocityOrEmeraldRot`（*.lua，除 .planning） | 定义 1 + 生产调用 4（全带参）+ selftest 15；无参形式 0（grep exit 1） |
| 三层优先级目视 | live code 631-671 逐行对照 PLAN 锁定约束 | D-01/D-02/D-04 顺序、词形、F-先于-E 全部一致 |
| 粘性闭合推演 | 选择层 × recoverNormalRelic 调用链（combo.lua:102/111）逐场景推演 | 无 F↔E 抖动；worldboss/T1 边界见 IN-02 |
| 注册计数 | `grep -c 'register("Cat O-' classes/druid/selftest.lua` | 16（7→+9） |
| 插入位置 | O-08..O-16 行号 949-1198 vs O-07 尾 947 vs Category Q 1228 | 全部在 947 与 1228 之间 |
| 语法门（三解释器） | lua-5.0.3 / 5.1.5 / 5.4.7 各 `assert(loadfile(...))` × 两文件 | 6/6 exit 0 |
| bbcheck | `node .../bbcheck.js classes/druid/Druid.lua classes/druid/selftest.lua` | BALANCED ×2 |
| Lua 5.0 token 门 | 两 commit 各自 diff 新增行 `grep -cE '#\|goto \|::'` | 0 / 0 |
| CRLF | `grep -c $'\r'` 两文件 | 0 / 0 |
| 行数 | `wc -l` | Druid.lua 1795、selftest.lua 2783，与 SUMMARY 一致 |

未执行的门：九项新 selftest 的 /mt 运行时运行（unrun-verify，本机无 WoW 客户端；SUMMARY D2 已备案 human_judgment: true）。SUMMARY 的两条文档级勘误（gate 7 计数 5→4 笔误、gate 8 措辞偏差）已在 SUMMARY Deviations 第 1/2 条自述备案，不重复列报。

---

_Reviewed: 2026-09-16T15:08:57Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_