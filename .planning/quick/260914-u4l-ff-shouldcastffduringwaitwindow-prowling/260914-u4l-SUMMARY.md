---
phase: quick
plan: 260914-u4l
quick_id: 260914-u4l
slug: ff-shouldcastffduringwaitwindow-prowling
subsystem: druid-cat 潜行帧 FF 等待窗守卫（classes/druid/Druid.lua + classes/druid/selftest.lua）
tags: [catatk, ff-fill, prowling, stealth, wait-window, guard, selftest, pin]
status: complete
date: 2026-09-14
one_liner: "shouldCastFFDuringWaitWindow 基础排除块新增 or clickContext.prowling 臂（潜行帧 FF 等待窗填充零触发，守护 Pounce/Ravage 起手）+ 与 WR-01 反义镜像的 prowling 拒绝 pin 双文件落地"
key_files:
  created: []
  modified: [classes/druid/Druid.lua, classes/druid/selftest.lua]
decisions:
  - "修复位置在决策函数 shouldCastFFDuringWaitWindow 而非 keepFF/safeFF（用户裁定）：prowling 帧在 OR 链第二臂短路 return false，永不触达 isImmune/shouldDoReshift/isKillShot/能量算术"
  - "nil 容错成对覆盖：既有 WR-01 构造 ctx 无 prowling 字段（nil→falsy→不排除）继续判 true，新 pin 用 prowling=true 钉死排除侧，一含一不含钉死 nil 容忍契约"
  - "新 pin stub 纪律镜像 WR-01：pcall 内执行，4 函数 stub + 2 own-key shadow 全部于 assert 之前按 rawget 快照/引用还原（CR-01）；shouldDoReshift 不 stub"
commits:
  code: b0a610a
duration_seconds: 337
actuals:
  tokens: 554
  tasks: 2
  commits: 1
---

# Quick 260914-u4l Summary

潜行帧禁止 FF 等待窗填充：`shouldCastFFDuringWaitWindow` 基础排除块新增 `or clickContext.prowling` 臂（净增 3 行）+ selftest 反义镜像 pin（净增 48 行 = 47 行 pin + 1 分隔空行），全部锁定约束逐字落地，验证电池跑绿后原子提交 `b0a610a`。

## 任务完成

| 变更 | 文件 | 内容 |
|------|------|------|
| prowling 排除臂 | classes/druid/Druid.lua | `shouldCastFFDuringWaitWindow` 基础排除块（1173-1178 行区域）纯插入 3 行：ooc 臂之后新增第二臂 `or clickContext.prowling` + 2 行英注释（位于当前 1174-1176 行）；零删除，头注释与块内其余行字节不动 |
| 反义回归 pin | classes/druid/selftest.lua | WR-01 块结尾（827 行 `end, true)`）之后、828 空行之后、`-- End of Batch 2` 之前插入 47 行新 register 块 + 1 分隔空行：与 WR-01 完全相同帧（razor edge 能量窗全条件满足），唯一差异 `prowling = true`，断言返回 false；注册名/断言文案逐字锁定 |

提交：`b0a610a` — `fix(260914-u4l): exclude prowling frames from FF wait-window fill; add stealth-refusal selftest pin`。恰含两个锁定代码文件（Druid.lua 3 insertions；selftest.lua 48 insertions；两文件 0 deletions，合计 51 insertions）；`.planning/` 工件（PLAN.md / 本 SUMMARY / STATE.md 表行）由 quick 流程 docs commit 收口，代码 commit 零夹带。

## 验证电池结果

- **GATE 0** 三解释器（Lua 5.0.3 / 5.1.5 / 5.4.7）对两文件 loadfile 编译：LOADFILE-OK ×3。提交后复跑（Task 2）再次 LOADFILE-OK ×3。
- **GATE 1** 16 项结构 grep 全字面绝对计数全部达标：`or clickContext.prowling`=1、两行注释各 1、isImmune 臂 1、新注册名/razor-edge 注/pcall 体/crash 断言/判定断言各 1、`prowling = true` 2（基线 1+新 1）、computeErps 60 stub 2、origImmune 2、mana 还原 2、WR-01 注册名/断言各 1、`-- End of Batch 2` 1。
- **GATE 2** 删除面：两文件删除行合计 0（纯插入）。
- **GATE 3** hunk 范围：全部 `@@` 落在锁定区（Druid 1160-1189、selftest 820-869）。
- **GATE 4** bbcheck 全文件门：两文件均 BALANCED。提交后复跑再次 BALANCED ×2。
- **GATE 5** 新增行无 `#`/`goto`/`::`、无非 ASCII 字节（CJK 门）、两文件 CR 字节 0（全 LF）、`git diff --check` 干净。
- **GATE 6** 变更面 = 恰两个锁定文件（+ orchestrator 的未跟踪 quick planning 目录豁免，见偏差 3）；新增行数按 numstat 权威口径 Druid 3 / selftest 48（见偏差 1）；principles doc 零触碰；SM_Extend.lua 存在性检查为误报（见偏差 2）。
- **GATE 7** Druid.lua 1171-1182 行逐行钉死全部一字不差。
- **Task 2 提交后复核** porcelain 仅剩未跟踪 quick 目录（代码零残留）；`git diff HEAD~1 --check` 无输出；跨提交删除行 0；numstat `3 0` / `48 0`；非空新增行合计 50（与计划 Task 2 验证节的 `50` 吻合）；commit message 逐字复核一致。

## Deviations from Plan

**代码/文本零偏差**：Druid.lua 与 selftest.lua 的两次 Edit 均为计划锁定 before/after 块逐字落地（Edit 前 cat -A 实测锚点全部吻合；插入区域 48 行与计划 after 块逐字节 diff 全等）。以下 3 项均为验证电池脚本自身的缺陷/环境既有事实，在真实 diff 上逐项实证意图成立后如实记录（与 260914-49l 同类处理），不构成代码偏差：

1. **[GATE 6 selftest 计数正则不可满足]** 计划电池 `grep '^+[^+]'` 对 selftest 期望 48，但锁定的最后 1 行是**空分隔行**——diff 中空新增行为裸 `+` 行，`[^+]` 要求 `+` 后至少一个字符，恒不可能被计数（物理值 47 = 47 行 pin 块）。意图实证：① 文件插入区域（829-876 行）与计划 after 块（105-152 行）逐字节 diff 全等（48 行）；② `git diff --numstat` 权威口径 `48 0`，与锁定约束 #2"净增恰 48 行 = 47 行 pin 块 + 1 行块尾分隔空行"完全一致；③ 两文件非空新增合计 50，恰为计划 Task 2 验证节的期望值 `50`。另注：计划内部本处计数自相矛盾（Task 2 step 4 期望 `51`，验证节期望 `50`），物理真值为 50。**处理**：以锁定字节内容与约束 #2 为最高优先级，不改动文件；GATE 6 该子项以 numstat（48/0）+ 逐字节全等替代实证后放行。
2. **[GATE 6 `test ! -e SM_Extend.lua` 环境性误报]** 仓库根存在 `SM_Extend.lua`，但系**本 quick 开始前已存在**的 ignored 构建产物（mtime 2026-09-11 03:02，早于执行 3 天；`.gitignore:26` 已忽略，porcelain 全程不可见）。本 quick 期间未运行 build.sh（该 gate 的真实意图——"build.sh 未被运行"——成立）。**处理**：以 mtime + ignore 规则 + porcelain 静默三重证据证明非本次执行产物后放行，不做任何文件操作。
3. **[GATE 6 变更面 porcelain 检查]** `git status --porcelain` 出现 `?? .planning/quick/260914-u4l-.../`（planning 目录为本 quick 工作目录，执行起点已存在，orchestrator 所有、不得提交）。与 260914-49l 偏差 3 同型：显式豁免该行后变更面归零；除两个锁定代码文件外无任何中间产物。

## Unrun Verification（经 `/mt` 实机电池）

本机无 WoW 客户端（unrun-verify 备案）：

- 用户 Windows+Cygwin 重建 `/mt` 后：① PvP 潜行等待期间（能量等待窗带 [15,20]、无 Tiger 时 min=TIGER_E）应不再发出 FF 填充，隐形保持、Pounce/Ravage 起手可用；② selftest FF 相关 pin 全绿：WR-01 仍判 true（ctx 无 prowling 字段 → nil 容忍路径），新 pin "FF wait window: prowling frame refused (stealth never FF-fills)" 判 false——若新 pin 红名说明 prowling 臂失效或 stub 断链；③ PvE 行为无变化（旧 pin 全绿即证明）。
- 方向预证（纯 Trace）：臂缺失时新 pin 必红——同帧无 prowling 臂时 OR 链走完：isImmune stub false → shouldDoReshift 未 stub 且 cat.lua 自身对 prowling 帧返回 false（不触发外层排除）→ isKillShot stub false → 进入窗口算术 → waitSeconds=60/60=1.0 ≥ 1.0 → 返回 true → `true == false` → res=false → 判定断言红名。

## Threat Flags

无超出计划 `<threat_model>` 的新安全/信任面（本次改动为决策函数内只读条件臂：只读 `clickContext.prowling`，不写任何状态、不接外部输入、不新增调用路径）。计划 4 项 STRIDE 行按既定 disposition 落地：T-01（stub 污染，medium/mitigate）CR-01 缓解已实现并在 GATE 1 钉死 capture/restore 字面量计数（4 函数 stub 引用还原 + 2 own-key rawset 还原，全部先于两条 assert）；T-02（误伤非潜行帧，low/accept）由 nil/false 短路等价 + 成对 pin 覆盖 nil 容错；T-03（自测红名，low/accept）；T-04（文案注入，low/accept，全静态字面量）。

## Known Stubs

无。本 quick 未引入任何占位数据、空实现或未接线组件；新 pin 为完整可执行测试。

## Self-Check: PASSED

- 提交 `b0a610a` 存在：`2 files changed, 51 insertions(+)`，0 deletions，只含 classes/druid/Druid.lua（3 insertions）与 classes/druid/selftest.lua（48 insertions），无 tracked 文件删除。
- commit message 与锁定文案逐字一致（Task 2 复核 `git log -1 --format=%s`）。
- 插入区域与计划锁定 after 块逐字节 diff 全等（48 行）；Druid.lua 1171-1182 行 GATE 7 钉死通过。
- 三解释器 LOADFILE-OK ×3（GATE 0，提交前后各一轮）；bbcheck BALANCED ×2（GATE 4，提交前后各一轮）。
- `git diff --check` 干净；CR 字节 0；非 ASCII 新增字节 0；`#`/`goto`/`::` 新增 0。