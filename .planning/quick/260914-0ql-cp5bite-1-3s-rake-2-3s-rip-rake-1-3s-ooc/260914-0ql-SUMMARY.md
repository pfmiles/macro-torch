---
quick_id: 260914-0ql
phase: quick
plan: 260914-0ql
subsystem: druid-cat
tags: [cp5Bite, rake, rip, discharge, lua-5.0, 1.3s-threshold]
requires: []
provides: ["cp5Bite 在 rake 剩余 <=1.3s 时跳过泄能直接 bite 以续 rake（与 2.3s 保 rip 平行）"]
affects: [classes/druid/cat.lua]
status: complete
---

# Quick Task 260914-0ql: cp5Bite 新增 1.3s 保 rake 跳过泄能条件（与 2.3s 保 rip 平行）Summary

`macroTorch.cp5Bite`（classes/druid/cat.lua）的泄能跳过链上，于既有 `-- Check Rip duration` 2.3s 保 rip 块之后纯插入一条同构的保 rake 条件：`if shouldDischarge and macroTorch.isRakePresent(clickContext) and macroTorch.rakeLeft(clickContext) <= 1.3 then shouldDischarge = false end`。rake 在场且剩余 <=1.3s（约等于一次泄能 GCD 1s + 兜底路径余量）时，跳过 `energyDischargeBeforeBite`（含 ooc 泄能消耗），直接进入 ooc → readyBite / 否则 safeBite 判定，由 Ferocious Bite 落地续期机制续上 rake（Druid.lua:948-970 监听器已有续期能力，本次零改动）。变更面钉死：单文件 `classes/druid/cat.lua`、纯 6 行插入、0 删除；入口门槛（122 行）、伪无限能量门（130-132 行）、2.3s rip 块、泄能分支（139-147 行）、ooc/readyBite/safeBite 分支（150-154 行）逐字未动；fast battle 天然免疫（不施放 rake、isRakePresent 恒 false）。

## Tasks Completed

### Task 1: cat.lua 新增 1.3s 保 rake 条件（纯插入 6 行）+ 单文件 commit
- **Commit:** `e776e98` — `feat(cat): cp5Bite skips discharge when rake <=1.3s (bite renews rake)`（逐字命中锁定消息）
- **Changes:** 仅 `classes/druid/cat.lua`（+6 行，0 删行）。锚点块（`-- Check Rip duration` 2.3s rip 块）原文不动，其后纯插入空行 + 锁定 rake 块（8 空格行首缩进，注释英文：`-- Check Rake duration: <=1.3s left = one discharge GCD (1s) + slack; an` / `-- immediate bite renews Rake, discharge would let it fall off`），落点恰为 rip 块 `end` 之后、`if shouldDischarge then` 之前。
- **验证电池（全部命中）:**
  - `grep -c "Check Rake duration"` = 1；`grep -c "rakeLeft(clickContext) <= 1.3"` = 1
  - `grep -c "ripLeft(clickContext) <= 2.3"` = 1；`grep -c "Check Rip duration"` = 1（rip 块未重复未改）
  - 上下文顺序: if 行前紧随两行 rake 注释、其后 `shouldDischarge = false` / `end` / 空行 / `if shouldDischarge then`（行 139-145）
  - 变更面钉死: 新增 `if` 恰一条（见下方偏差说明），删除行 `git diff -U0` 计数 = **0**
  - 新增行 CJK 门: 0 命中
  - bbcheck: `classes/druid/cat.lua: BALANCED`
  - Lua 5.0.3 `loadfile` 编译门: exit 0 无输出
  - Token 门（`#` / `goto ` / `::`）: 0；CRLF: 0；`git diff --check` 干净
- **提交验证:** `git log -1 --format=%s` 逐字命中；`git show --stat` 仅 `classes/druid/cat.lua`，恰 `6 insertions(+), 0 deletions(-)`。

### Task 2: 全静态电池复核 + 备案 + SUMMARY 输出（零代码变更；无缺陷，无补 commit）
1. **三解释器编译门:** 5.0.3 / 5.1.5 / 5.4.7 依次 `loadfile` assert 全过，打印 `3-INTERPRETER COMPILE OK`。
2. **提交面复核:** `git diff HEAD~1 HEAD --shortstat` = ` 1 file changed, 6 insertions(+)`；stat 仅一行 `classes/druid/cat.lua`；head~1 -U0 删除行计数 = **0**。
3. **联合门重跑:** bbcheck BALANCED、token 门 0、CRLF 0、`git diff --check` 干净。
4. **工作树口径:** `git status --porcelain` 仅 ` M .planning/config.json`（编排者/用户拥有的未提交配置改动，本任务全程未触碰、未提交）；`SM_Extend.lua` 未被触碰（全程未运行 build.sh）。

## Deviations from Plan

### Regex/命令口径修正（零代码偏差，plan gate 拼写层）

**1. Task 1「恰一条新增 if」grep 模式的空格数与锁定块缩进不匹配**
- **Found during:** Task 1 验证电池项 [4]
- **Issue:** PLAN 的 gate `git diff HEAD -- classes/druid/cat.lua | grep -c '^+    if'` 实测模式含 5 个空格，而锁定块行首缩进为 8 空格（锁定约束 3 明文）——按原拼写该模式对任何合法实现都恒输出 0。
- **Fix:** 按 gate 意图（"恰一条新增 if"）用 `'^+        if'`（8 空格）与 `'^+[[:space:]]*if '` 复核，均输出 **1**；零删除门、单条件门（isRakePresent diff 内恰 1 次）同步命中。代码逐字未变。
- **Files modified:** 无（仅验证命令拼写）

**2. Task 2 提交面复核改用树对树 diff**
- **Found during:** Task 2 电池项 [2]
- **Issue:** PLAN 的 `git diff HEAD~1 --shortstat` 是"工作树 vs 上一提交"，会把编排者拥有、明令不许提交的 `.planning/config.json` 未提交改动计入（输出 2 files/7+/1-，误报提交面）。
- **Fix:** 提交面本身用 `git diff HEAD~1 HEAD`（树对树，不含工作树）复核：`1 file changed, 6 insertions(+)`、仅 cat.lua、0 删除。工作树中 config.json 改动保持未提交原状（依编排约束）。
- **Files modified:** 无（仅验证命令口径）

## Unrun Verification

本机无 WoW 客户端，行为级观察走 unrun-verify 口径。用户 Windows+Cygwin 重建 `/mt` 后实机观察：**5 星且 rip 在场（或免疫流血）、rake 剩余 <=1.3s 时，宏应立即咬击、不插入泄能动作**；战斗记录可见 Ferocious Bite 落地后 rake/rip 双续期。对比改前同一窗口常以 rake 到期断档收尾（木桩样本口径：5cp 到达时 rake 剩余 ∈ (0,1.3] 约 16% 周期，现状 71% 以 rake 已死收尾）。

## Threat Flags

无。变更系纯插入一条只读判定（调用既有、clickContext 上 memoize 的 `isRakePresent`/`rakeLeft`），不新增网络面、端点、持久化写路径或信任边界；条件带 `shouldDischarge and` 短路由（与 rip 条件同构），伪无限能量已跳过时不额外调用 rakeLeft。

## Known Stubs

无。无硬编码空值、占位文本或未接数据源组件；插入块即完整生效逻辑。

## Self-Check: PASSED

- `classes/druid/cat.lua` 存在且含新条件（grep 双 1 已验证）
- commit `e776e98` 存在（`git log` 已见）；`git show --stat` = 单文件 6 insertions(+)
- 三解释器编译 OK；bbcheck BALANCED；工作树仅残留编排者拥有的 config.json