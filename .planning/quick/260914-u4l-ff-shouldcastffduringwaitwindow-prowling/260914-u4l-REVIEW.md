---
phase: quick-260914-u4l
reviewed: 2026-09-14T14:46:34Z
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
status: issues_found
---

# Phase quick-260914-u4l: Code Review Report

**Reviewed:** 2026-09-14T14:46:34Z
**Depth:** standard
**Files Reviewed:** 2（classes/druid/Druid.lua +3 行、classes/druid/selftest.lua +48 行，纯插入零删除，commit b0a610a）
**Status:** issues_found（0 critical / 0 warning / 3 info）

## Summary

对 commit `b0a610a`（diff base `b0a610a^`）的两个文件做了标准深度审查，并对 PLAN 的 6 项 review focus 逐项对照实测代码验证。**核心改动本身无 bug**：`shouldCastFFDuringWaitWindow` 基础排除块新增 `or clickContext.prowling` 臂语义正确、nil 容错成立、臂序无副作用；新 selftest pin 是方向正确型（修复前必红/修复后绿），stub 纪律合规。3 条 Info 均为注释精度/可维护性观察，不构成行为缺陷。

### 六项 review focus 验证结论（对照 live code，非文档）

1. **nil 容错（focus 1）— 通过**。生产链路 combo.lua:89 `clickContext.prowling = player.isProwling` 恒写该字段；既有 FF selftest 全部构造无 `prowling` 字段的 ctx（逐一到读：R8-01 `{ooc=true}`、R8-02/R8-03 `{ooc=false}`、R8-04/R8-05/R8-06、WR-01 的 15 字段 ctx 均无该键）→ nil → falsy → 臂不触发 → 判定路径与改动前逐字节等价。selftest 中唯一的既有 `prowling = true` 赋值在 R2-03（selftest.lua:128，测试 `shouldDoReshift`），不触达本决策函数，无冲突。Lua 5.0/5.1/5.4 三解释器对两文件 loadfile 编译全通过。
2. **臂序/短路语义（focus 2）— 通过**。新臂位于 ooc 臂之后、isImmune 臂之前。ooc=true 的帧（含 ooc 与 prowling 同真的帧）在第一臂即短路 return false，改动前后行为无差；唯一行为差为 ooc=false 且 prowling=true 的帧（本 quick 的目标帧）。排除块是纯只读谓词的 OR 链，函数不消费/改写 `clickContext.ooc`，与上游 oocMod/combo.lua 无状态交互。顺带效应：prowling 帧不再触达 `macroTorch.target.isImmune('Faerie Fire (Feral)')` 真实 API 调用，纯减负无语义。
3. **调用路径覆盖（focus 3）— 通过（附 1 条 Info 备案）**。`shouldCastFFDuringWaitWindow` 的生产调用点唯一：cat.lua:399 keepFF（combo.lua:185 在 catAtk 模块链 step 10 无守卫调用——正是暴露面，本改动闭合）。其余 FF 路线逐一核查：bear.lua:42 bearFFMod 直接调 safeFF，但潜行需猫形态、与熊形态互斥，结构上不可达；leveling.lua:226 内联 FF 分支自带 `and not player.isProwling` 守卫；combo.lua:418 druidMobTagging 的 FF 是主动引怪 hits（故意破隐 tag），非等待窗填充，out of scope——记为信息性不对称备注（见 IN-03）。另注意 Druid.lua:1313 既有政策注释 "no FF in: … 8) prowling …" 早已声明此规则，本改动使代码首次与既有文档一致。
4. **pin 方向性（focus 4）— 通过（逐节点实测 Trace）**。新 pin ctx 与 WR-01 selftest.lua:767-783 的 15 字段逐一比对完全相同，唯一增量 `prowling = true`。修复前 Trace：ooc=false →（无臂）isImmune stub false → shouldDoReshift（未 stub，cat.lua:258 自身含 `clickContext.prowling` 排除 → return false，不触发外层排除；RESHIFT_ENERGY=40 过首检）→ isKillShot stub false → computeErps stub 60 → getNextAbilityCost：shouldUseBite false（cp=1、isImmuneRip=true，CP5 与 trivial 分支均不命中）→ isTigerPresent(ctx)=true 跳过 Tiger → shouldCastRip 因 isRipPresent=true 短路 false（不触 isFightStarted）→ Rake 因 isRakePresent 跳过 → shouldUseShred 走 3-bleed else 支返回 `(ooc or infiniteEnergy) and isBehind and not isBehindAttackJustFailed` = true → minAbilityCost=SHRED_E=60 → current=0 < 60、projected=90 ≥ 60 → waitSeconds=60/60=1.0 ≥ 1.0 → 返回 true → pcall 体 `true == false` → res=false → 判定断言红名。路径上唯一读 prowling 的函数是 shouldDoReshift（读入方向同为 false），isFightStarted（Druid.lua:1092）虽含 prowling 语义但该帧不被触达（shouldCastRip 已短路）——**pin 必为方向正确型**。修复后：第二臂真值短路 return false → `false == false` → 绿。crash 面：`assert(ok, …)` 优先于判定断言 ✓；6 个 stub/own-key shadow（2 own-key rawget 快照 + 4 函数引用）全部于 assert 之前按 WR-01 同序 rawset/赋值还原，pcall 失败也不污染会话 ✓。
5. **Lua 5.0 合规（focus 5）— 通过（本次独立复跑）**。三解释器 loadfile LOADFILE-OK ×3；新增行 `#`/`goto`/`::` 计 0；非 ASCII 字节计 0；两文件 CR 字节计 0（全 LF）；`git diff b0a610a^ b0a610a --check` 干净；bbcheck 两文件均 BALANCED；删除面 0 行、新增 3/48（numstat 3 0 / 48 0）、变更面恰两个锁定文件。
6. **principles doc 边界（focus 6）— 通过**。commit 仅含两个代码文件（`git show --stat` 复核），`.planning/catAtk-core-principles.md` 零触碰。

## Critical Issues

无。

## Warnings

无。

## Info

### IN-01: 新臂注释 "mirrors" 措辞与实语义不完全一致（偏严，非偏松）

**File:** `classes/druid/Druid.lua:1176`
**Issue:** 注释 `-- mirrors keepRake isFightStarted guard and oocMod prowling guard` 暗示三处守卫语义等价，但实为"精神上同向、条件上更严"：isFightStarted（Druid.lua:1092-1097）对 `prowling and target.isAttackingMe` 判为战斗已开始（keepRake 可照常出手）；oocMod（combo.lua:155 `if not clickContext.prowling or target.isAttackingMe`）在被攻击时亦放行；而新 FF 臂对一切 prowling 帧无条件拒绝，无 isAttackingMe 例外——即"潜行 + 被攻击"角落帧中 FF 等待窗填充被一并拒绝（该取舍是用户明确裁定的"stealth must never FF-fill"，行为正确）。风险点是未来维护者按 "mirrors" 字面将 FF 臂与 oocMod 的 isAttackingMe 例外"对齐"，反而在潜行被攻击帧重新引入破隐填充。另 selftest.lua:829 的 razor-edge 注 "a true verdict would mean the prowling arm alone was exercised" 英文表达亦偏绕（真实含义：真值 = 臂失效），若后续重写可改述为 "a true verdict can only mean the prowling arm failed to exclude"。
**Fix:** 无需改行为（注释文本为规划锁定逐字节内容，且行为经用户裁定）。如未来解锁修订，建议对 Druid.lua:1176 改为 `-- same spirit as keepRake isFightStarted and oocMod prowling guards, but stricter: no isAttackingMe exception`；或在该臂上方补一行说明 difference 是有意为之。

### IN-02: 新 pin 与 WR-01 的 stub 脚手架大面积重复（约 35 行逐字节相同）

**File:** `classes/druid/selftest.lua:845-872`（对照 WR-01 810-840）
**Issue:** 4 个函数 stub + 2 个 own-key shadow + pcall + 还原序列与 WR-01 完全一致。当前逐字重复是平面锁定约束的一部分，可接受；但 FF 等待窗的第三个 pin 出现时将第三次复制该脚手架，回归面漂移风险随复制次数上升。
**Fix:** 可选（不在本 quick 范围）：提取 `local function runFFWindowTest(ctx, expect)` 助手封装 stub/repeat 还原纪律，WR-01 与新 pin 改用助手。若做，必须保持 CR-01 还原先于 assert 的不变式。

### IN-03: FF 拉怪路径（druidMobTagging）无潜行守卫——备案为有意设计，非本 quick 缺陷

**File:** `classes/druid/combo.lua:414-419`
**Issue:** `druidMobTagging`（抢怪宏）在 5-30yd 距离分区无条件 `player.faerie_fire_feral('ready')` 引怪，不检查潜行；潜行猫在该距离段会破隐放 FF。审查核实其为**主动引怪/tag 意图**（注释明示"通用兜底：野性精灵之火引怪"），与等待窗填充语义不同，且 ≤5yd 潜行+身后分支已正确路由到 druidAtk 起手（Pounce/Ravage）保护开手；故不属于本次"stealth never FF-fills"守卫覆盖域。bear.lua:42 bearFFMod 亦不查潜行，但因潜行仅存于猫形态、与熊形态互斥而结构不可达；leveling.lua:226 分支已自带 `not player.isProwling` 守卫。三条旁路均已核查，无遗漏暴露面。
**Fix:** 无需改码。如未来审阅者重查此不对称，可在 combo.lua:415 拉怪分支补一行注释 `-- deliberate pull: breaking stealth here is intended for mob tagging` 固化意图，避免被误判为守卫缺口。

---

_Reviewed: 2026-09-14T14:46:34Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_