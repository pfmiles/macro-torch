---
phase: quick-260917-j9z
reviewed: 2026-09-17T06:41:24Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - classes/druid/Druid.lua
  - classes/druid/selftest.lua
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
status: clean
---

# Phase quick-260917-j9z: Code Review Report

**Reviewed:** 2026-09-17T06:41:24Z
**Depth:** standard
**Files Reviewed:** 2（classes/druid/Druid.lua +5/-5、classes/druid/selftest.lua +24/-24；diff base `34aa922`，范围 `34aa922..6260215` 共 3 个 commit：6e7b759=Task 1 代码、b30ca29=Task 2 代码、6260215=docs（STATE.md + PLAN + SUMMARY，零 classes/ 文件））
**Status:** clean（0 critical / 0 warning / 2 info 纪律备忘，无缺陷）

## Summary

本 review 覆盖 quick 260917-j9z 的最终态：`macroTorch.selectFerocityOrEmeraldRot` → `macroTorch.selectBuilderRelic` 纯机械符号改名。对抗立场逐项取证后结论：改名完备、零语义漂移、selftest 纪律保持、语法门全绿，未发现 Critical/Warning 级缺陷。两文件逐字节 diff 除标识符（及 assert 报错字符串内嵌旧名）外无任何逻辑改写；执行层（cat.lua / combo.lua / recoverNormalRelic 等）零 diff。

### 四项 review focus 验证结论（对照 live code 与实测命令，非文档）

1. **改名完备性 — 通过**。Druid.lua 旧名 0 / 新名恰 5（603/607/615/619 四个调用点 + 631 定义行，行位置与 PLAN 锚点逐一吻合）；selftest.lua 旧名 0 / 新名恰 24（12 处 stub 调用 `return macroTorch.selectBuilderRelic(...)` + 12 处 assert 文案 `"selectBuilderRelic pcall failed: "`，行位置 967~1224 与 PLAN 预测的 24 行逐一吻合）。全仓 grep（排除 .git / .planning / SM_Extend.lua）旧名 0 命中；部分标记 `selectFerocity` 0 命中；无字符串拼接式动态构造名。新名定义全仓唯一（Druid.lua:631），无冲突占位。无半途改名：`computeNormalRelic` 生产唯一入口 combo.lua:102、`recoverNormalRelic` 入口 combo.lua:111 均为未改动既有接线，内部经 4 调用点抵达新名定义，后续维护者无需中介适配。

2. **零语义漂移 — 通过**。两个 code commit 的 `-U0` diff 每个 hunk 仅替换标识符字节（Druid 5 hunk 全落 603~631 带；selftest 24 hunk 全落 967~1224 带，均与 PLAN 锁定带一致）。diff 形状门实测 0：全部 58 个变更行（5+5+24+24）无一不含新旧标识符之一。执行层 2.5s 能量门两处逐字节比对通过：Druid.lua:693 与 PLAN 锁定文本一致（`... player.mana + (macroTorch.computeErps(clickContext) * 2.5) <= 100 ...`），cat.lua:326 与锁定文本一致（`... macroTorch.player.mana + erps * 2.5 > 100 ...`），且 cat.lua 全文件零 diff。物品名字面量 `Idol of Ferocity` / `Idol of the Emerald Rot` 与描述注释（626-630 注释头只含物品名、不含函数标识符）保留——diff 含 `Idol of` 的变更行实测 0。行数 1795/2783 逐一不变。

3. **selftest 纪律 — 通过**。12 处改动的 assert 字符串与新函数名同步（stub 调用与 pcall 报错文案同指新名，运行时接线由 24 处同步替换保证）。Cat O- 注册计数实测恰 16。O-08..O-16 九项的 snapshot→install→pcall→restore→assert 三拍纪律在 diff 前后逐字节未动：本 quick 只触碰标识符行，恢复行全部位于 assert 之前（我目视核对 949~1226 带 12 个测试体，无失败路径泄漏）；该纪律本身已由 sibling review（260916-utm-REVIEW）核验，本 quick 不改其字节，不重复展开。

4. **Lua 语法规约 — 通过**。三解释器 loadfile 6/6 exit 0（lua-5.0.3 权威 2/2、5.1.5 2/2、5.4.7 2/2）；bbcheck 两文件 BALANCED；diff 新增行 Lua 5.0 令牌（`#`/`goto `/`::`）实测 0；CRLF 两文件 0；`git diff --check` 输出 0 行。新名 `selectBuilderRelic` 无 Lua 5.0 保留字冲突（经 5.0.3 解释器实际 parse 实证）。

### Commit 与归档合规（对照实测）

- `6e7b759` 恰含 `classes/druid/Druid.lua` 一个文件（5 ins/5 del）；`b30ca29` 恰含 `classes/druid/selftest.lua` 一个文件（24 ins/24 del）；`6260215` 仅 3 个 .planning 文档（STATE.md + 本 quick PLAN/SUMMARY），零 classes/ 文件。messages `git log --format='%s' 34aa922..HEAD` 逐字符合锁定两行 + docs 一行。
- 归档零触碰：`git diff 34aa922..HEAD -- cat.lua`、`-- SM_Extend.lua` 均为空；历史归档（既有 PLAN/SUMMARY/REVIEW）零 diff（STATE.md 的行新增为 docs commit 职责，执行者零触碰的口径成立）。
- 参考文档 `.planning/catAtk-core-principles.md` 行 347 实测已更名（旧 0 / 新 1），中文语义文案「残忍圣物 vs 翡翠腐朽圣物选择」原样；文件仍被 `.gitignore:34` 忽略（`git check-ignore` 通过）、未入库（`git status --porcelain` 为空）。

## Critical Issues

无。

## Warnings

无。

## Info

### IN-01: SM_Extend.lua（build 产物）内旧名残留为双倍陈旧——不止旧名，还是旧签名（零参形式，早于 260916-utm 加 clickContext）

**File:** `SM_Extend.lua:5565/5569/5577/5581/5592`
**Issue:** build 产物中旧名 5 处仍以 `selectFerocityOrEmeraldRot()` 零参数形式存在（5565/5569/5577/5581 调用 + 5592 定义）——它的陈旧度跨越了两个 quick：260916-utm（加 clickContext 参数）与本次（更名）。本 quick 按 PLAN 锁定约束零触碰该文件（正确，禁止手改 build 产物）。实测取证：开发态运行时经 `build_order.txt` 直接加载 `classes/druid/*.lua`（build_order.txt:26-40），SM_Extend.lua 不参与运行时（cat.lua/bear.lua/utility.lua 中的 "SM_Extend_Druid" 仅为第 1 行迁移出处注释），故开发态无遮蔽风险；但凡是分发/加载合并产物 SM_Extend.lua 的场景（含用户 Windows+Cygwin 侧的成品），在用户下次 `build.sh` 重建前会运行到双倍陈旧的旧名零参函数——与本次更名后的源码行为不一致。
**Fix:** 无需改代码。SUMMARY「Unrun Verification」第 2/3 条已对本风险备案（重建后自动再生新名；若 O- 测试报错文案出现旧函数名即构建未刷新,删除 SM_Extend.lua 后重跑 build.sh）。建议用户下次取证实机前先执行一次 build.sh 刷新产物,以同一文件名分布同一语义。

### IN-02: `.planning/catAtk-core-principles.md` 行 347 的更名仅存于工作树,对 git 不可见——清理类操作可能静默丢失该更新

**File:** `.planning/catAtk-core-principles.md:347`
**Issue:** 该文档是用户主动 untrack 的本地参考文档（`.gitignore:34`），行 347 反引号内标识符已实测更新为新名、语义文案未动，但该更新不进任何 commit、不出现在任何 diff 中。任何按 git 状态驱动的工作树清理（如误跑 `git clean` 类操作、或用户侧目录级备份/还原遗漏单文件）都会在无任何 git 痕迹提示的情况下抹掉这次同步。
**Fix:** 不改代码、不 commit（锁定约束）。备忘：该文档的不入 git 是用户既定决策，行 347 的同步属于"内容跟着源码走"的维护义务——若未来再有 rename 类改动而忘记同步该行，双方将出现文档-代码错名漂移且无 CI 可抓。可在下次触碰该文档时把「更名时须同步本表反引号标识符」写进文档头备忘区。

---

_Reviewed: 2026-09-17T06:41:24Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_