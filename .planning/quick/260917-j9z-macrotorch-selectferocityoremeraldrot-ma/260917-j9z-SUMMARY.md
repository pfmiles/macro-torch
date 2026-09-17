---
phase: quick-260917-j9z
plan: 260917-j9z
quick_id: 260917-j9z
slug: macrotorch-selectferocityoremeraldrot-ma
subsystem: druid-cat relic 选择函数纯机械改名 selectFerocityOrEmeraldRot → selectBuilderRelic（Druid.lua 5 处 + selftest.lua 24 处（12 stub 调用 + 12 assert 报错文案）+ catAtk-core-principles.md 工作树 1 处）
tags: [druid-cat, relic, rename, symbol-rename, selftest, lua50, zero-semantic-change, builder-relic]
status: complete
date: 2026-09-17
one_liner: "纯机械符号改名：macroTorch.selectFerocityOrEmeraldRot → macroTorch.selectBuilderRelic 全量落地（Druid.lua 4 调用点 + 1 定义行、selftest.lua 12 stub 调用 + 12 assert 报错文案内嵌旧名、untracked 参考文档行 347 反引号标识符），恰 2 个锁定 message 的原子 commit（5+5 与 24+24 行内替换），零语义改动：行数 1795/2783 逐行不变、Cat O- 注册计数 16 不变、两处 2.5 秒能量门（Druid.lua:693 / cat.lua:326）逐字节不变、Idol of Ferocity / Idol of the Emerald Rot 物品名字面量与注释保留（diff 含 'Idol of' 变更行 0）、cat.lua / SM_Extend.lua / 全部历史归档零 diff；bbcheck BALANCED + 三解释器 loadfile + diff 形状门 0 + CRLF 0 全绿"
key_files:
  modified: [classes/druid/Druid.lua, classes/druid/selftest.lua]
  worktree_only: [.planning/catAtk-core-principles.md]
decisions:
  - "零代码偏差执行：Task 1/2 锚点字节级核对一致（结论：计划背景事实为实，无漂移/无并发落地，规划 BASE 34aa9228 即执行起始 HEAD），每文件恰一次 Edit(replace_all, old=selectFerocityOrEmeraldRot, new=selectBuilderRelic)、一次命中、无 sed/perl；Task 1 commit 6e7b759 恰含 Druid.lua（5 ins / 5 del，锁 1795 行），Task 2 commit b30ca29 恰含 selftest.lua（24 ins / 24 del，锁 2783 行），message 逐字符合锁定文本；两任务 verify 内门首轮全绿（含 5 个 hunk 全落 600-635 带、24 个 hunk 全落 947-1224 带）"
  - "Task 3 收口门重锚定（#3786 活体观测权威）：规划侧 `git status --porcelain = 0` 基于规划时工作树（quick 计划目录尚未创建）；执行时该计划目录自身 untracked（?? .planning/quick/260917-j9z-.../），门原样必然不可满足。重锚为等价不变式——porcelain 恰 1 行、该行恰为本 quick 自建计划目录、零 tracked 改动、零其他 untracked 文件——同一真实约束（执行者零残留）实锤通过；其余收口断言（BASE..HEAD 恰 2 文件、cat.lua/SM_Extend.lua 零 diff、'Idol of' 变更行 0、repo 范围旧名归零、cat.lua:326 逐字节、两条 commit message 逐字）无需重锚即首轮全绿"
  - "SM_Extend.lua（build 产物）内旧名 5 处按规划零触碰：repo 范围旧名归零门豁免该文件与 .planning/，待用户下次 build.sh 重建自动再生为新名"
  - "实机 /mt 电池（O-08..O-16）按 quick-260916-utm 同一 unrun-verify 口径仅 SUMMARY 备案，WINDOWS.md 零触碰（规划锁定）"
commits:
  code: "6e7b759, b30ca29"
duration_seconds: 180
estimate:
  tokens: 36000
  raw_tokens: 18000
  tasks: 3
  confidence: low
actuals:
  tokens: 921
  raw_tokens: 921
  tasks: 3
  commits: 2
---

# Quick 260917-j9z Summary

`macroTorch.selectFerocityOrEmeraldRot` → `macroTorch.selectBuilderRelic` 纯机械符号改名落地：`classes/druid/Druid.lua` 5 处（computeNormalRelic 内 603/607/615/619 四个 return 调用点 + 631 定义行）、`classes/druid/selftest.lua` 24 处（O-08..O-16 的 12 处 stub 调用 `return macroTorch.selectBuilderRelic(...)` + 12 处 assert 报错文案 `"selectBuilderRelic pcall failed: " .. tostring(res)`）、untracked 参考文档 `.planning/catAtk-core-principles.md` 行 347 反引号标识符（工作树 only，不入 commit）。零语义改动：两 Lua 文件行数 1795/2783 逐一不变，两处 2.5 秒能量门、Idol 物品名字面量与描述注释、Cat O- 注册计数 16 全部逐字节/逐计数锁定；`cat.lua`、`SM_Extend.lua`（build 产物）与全部历史归档（STATE/ROADMAP/既有 PLAN/SUMMARY/REVIEW）零 diff。恰 2 个代码 commit（每条 message 按规划逐字锁定），principles 文档仅落工作树。

## 任务完成

| Task | 内容 | 结果 | Commit |
|------|------|------|--------|
| 1 | Druid.lua 纯改名 5 处 | 旧名 0 / 新名 5；行数 1795；diff 恰 5 个 hunk（603/607/615/619/631） | `6e7b759`（5 ins / 5 del，恰 1 文件） |
| 2 | selftest.lua 纯改名 24 处 | 旧名 0 / 新名 24（12 调用 + 12 文案）；行数 2783；Cat O- 注册 16；diff 恰 24 个 hunk（全落 947-1224 带） | `b30ca29`（24 ins / 24 del，恰 1 文件） |
| 3 | 参考文档工作树更新 + 收口门 | 行 347 反引号标识符更名、语义文案「残忍圣物 vs 翡翠腐朽圣物选择」一字不动；文件仍 gitignored（check-ignore 通过）；收口门全绿 | 零 commit（工作树 only） |

**验证 gates（全绿，首轮通过）：**

- 标识符计数门：Druid 旧 0/新 5；selftest 旧 0/新 24；principles 旧 0/新 1。
- 行数门：1795 / 2783 逐行不变（纯 1:1 行内替换）。
- 语义不变门：Druid.lua:693 与 cat.lua:326 两处 2.5 秒能量门 sed 逐字节比对通过；`git diff BASE..HEAD` 中含 `Idol of` 的变更行数 0；cat.lua 与 SM_Extend.lua 零 diff；Cat O- 注册计数 16 不变。
- 语法门：bbcheck 两文件 BALANCED；lua-5.0.3（权威）/ 5.1.5 / 5.4.7 三解释器 `assert(loadfile(...))` 通过。
- hygiene 门：diff 新增行 Lua 5.0 令牌（`#` / `goto ` / `::`）0；CRLF 0；`git diff --check` clean；diff 形状门 0（每个变更行必携带新旧标识符之一）。
- 交付门：恰 2 个 commit，message 逐字与锁定文本一致；`git log --format='%s' BASE..HEAD` 逐字等于规划锁定两行；repo 范围（豁免 .git/.planning/SM_Extend.lua）旧名 `grep -rln` 归零。

## 偏差

### 收口门重锚定（#3786 活体观测权威，非实现偏差；零代码影响）

1. **[Plan gate re-anchor] `git status --porcelain | wc -l = 0` 不可满足。** 规划侧背景事实「工作树 clean（porcelain 为空）」取证于 quick 计划目录创建之前；执行时该目录自身以 `?? .planning/quick/260917-j9z-macrotorch-selectferocityoremeraldrot-ma/` 形式 untracked（docs 收口在 orchestrator Step 8，不在执行者职责内），原门必然失败。重锚为等价不变式：porcelain 恰 1 行、该行恰为本 quick 计划目录、零 tracked 改动、零其他 untracked 文件——同一真实约束（执行者工作树零残留）实锤通过。git-diff 建模无缺陷，其余全部断言按规划原样首轮通过。

其余按规划零偏差：Task 1/2 锚点字节级核对一致（结论：计划背景事实为实，无文件漂移、无并发会话落地，规划 BASE `34aa9228...` 即执行起始 HEAD）、每文件恰一次 `Edit(replace_all)` 一次命中（禁用 sed/perl 落位）、principles 文档 worktree-only（禁止 add/commit 落实）、SM_Extend.lua 零触碰、威胁模型 T-01/T-02 的 mitigate 门全部执行。

## Unrun Verification（实机电池 — 按规划仅 SUMMARY 备案，不改 WINDOWS.md）

本机无 WoW 客户端。静态门全绿后，用户 Windows+Cygwin 重建 `/mt` 后实机目视 O-08..O-16 电池（与 quick-260916-utm 同一 unrun-verify 口径，规划锁定零触碰 WINDOWS.md）：

1. 重建后运行 `/run macroTorch.SelfTest:run()`，Cat O-08..O-16 全部 PASS、无抛错（运行时接线由替换的 24 处同步保证：stub 调用与 pcall 报错文案同时指向新名）。
2. 重建产物 SM_Extend.lua 中旧名 5 处应随 build.sh 自动再生为新名（本次未改写 build 产物）。
3. 若任何 O- 测试报错文案中出现旧函数名，说明构建未刷新——删除 SM_Extend.lua 后重新 build.sh 即可。

## Threat Flags

无超出规划 `<threat_model>` 的新攻击面。纯标识符文本替换，不改变任何输入/输出面与数据流：T-260917-j9z-01（Druid.lua 神像选择链路）= mitigate，diff 形状门 + 693 行逐字节 + 行数门 + 三解释器全绿；T-260917-j9z-02（selftest 断言与 stub）= mitigate，注册计数 16 + 行数门 + 旧 0/新 24 + 三解释器全绿；T-260917-j9z-SC（供应链）= accept，零 package 安装、零新依赖，package legitimacy 门不适用。

## Self-Check

- [x] `classes/druid/Druid.lua` 1795 行、旧名 0 / 新名 5（GATE Task 1）
- [x] `classes/druid/selftest.lua` 2783 行、旧名 0 / 新名 24、Cat O- 注册 16（GATE Task 2）
- [x] commit `6e7b759` / `b30ca29` 存在且各自文件集合恰为一个代码文件（`git show --name-only --format= HEAD`）
- [x] `.planning/catAtk-core-principles.md` 行 347 更名、仍 gitignored、未入库（GATE Task 3）
- [x] 本 SUMMARY.md 已写到 `.planning/quick/260917-j9z-.../`（未进入代码 commit，留给 quick 流程 docs 收口）
- [x] commit 后 `git status --porcelain` 仅剩本 quick 计划目录 `??`

## Self-Check: PASSED