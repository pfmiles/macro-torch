---
quick_id: 260914-3vh
phase: quick
plan: 260914-3vh
subsystem: planning
tags: [catatk, principles, doc-revision, bleed-protection, rake-1.3s, kill-shot-gate, zero-delta]
requires: [260914-0ql, 260914-1t0, 260910-ilu]
provides: ["catAtk-core-principles.md 与代码（cp5Bite 双流血保护 / shouldCastFFDuringWaitWindow kill-shot 门）行为同步"]
affects: [.planning/catAtk-core-principles.md]
status: complete
---

# Quick Task 260914-3vh: catAtk 原则文档 4 处锁定修订（工作树-only）Summary

对 untracked 本地原则宪章 `.planning/catAtk-core-principles.md`（`.gitignore:34`）执行恰好 4 处锁定编辑，把代码侧已落地的行为同步进原则文档：(1) 规则 3 例外从「仅保护割裂 2.3s」扩展为「双流血保护：割裂 ≤ 2.3s 或扫击 ≤ 1.3s」，标题改为「流血保护优先于泄能」，并新增阈值非对称理由句；(2) 附录 B 新增「撕咬扫击刷新保护 | 1.3s」行；(3) 规则 8 等待窗 IF 块新增 `AND NOT isKillShotOrLastChance` 排除门（斩杀期暂停一切等待窗类动作，对齐规则 9）；(4) 页脚时间戳 `2026-08-23` → `2026-09-14`（行末 2 尾随空格保留）。ZERO-DELTA 由 /tmp 快照 diff 证明：4 hunk、-3/+5、`wc -l` 492 → 494、伪代码围栏 30 不变、作者行逐字未动、末行仍无换行符；文档本体未 commit（工作树-only，untracked 状态由三项 git 守卫证明）。

## 四编辑对照

| # | 位置 | 旧（要点） | 新（要点） |
|---|------|-----------|-----------|
| E1 | 规则 3 例外段（原 87-88 行） | 标题「割裂保护优先于泄能」+「撕咬会刷新…割裂持续时间。若割裂剩余 ≤ 2.3s，跳过泄能立即撕咬，防止割裂断档」 | 标题「流血保护优先于泄能」+「刷新已存在的流血（割裂/扫击）…若割裂剩余 ≤ 2.3s 或扫击剩余 ≤ 1.3s…防止流血断档」+ 阈值非对称理由句（扫击可随时重补不耗连击点，割裂需重建 5 星故窗口更宽） |
| E2 | 附录 B（原 454 行后） | — | 新增行 `\| 撕咬扫击刷新保护 \| 1.3s \| 扫击 ≤ 1.3s 剩余时跳过泄能以保护扫击 \|` |
| E3 | 规则 8 IF 块（`AND NOT shouldDoReshift` 与 `THEN ff()` 之间） | — | 插入 `AND NOT isKillShotOrLastChance                     -- 斩杀期暂停所有等待窗类动作（规则9）`（`--` 注释标记字节级对齐块内既有第 50 列，21 空格） |
| E4 | 页脚（原 492 行） | `*最后更新：2026-08-23*␣␣` | `*最后更新：2026-09-14*␣␣`（2 尾随空格标记 markdown 软换行，保留；作者行不动） |

除这 4 处外所有字节逐字不变（快照 diff 仅 4 hunk）。

## Tasks Completed

### Task 1: 快照基线 + 4 处锚定编辑（全部经 Edit 工具，旧→新逐字替换）

- **基线断言（Step 0 全绿）:** 文件存在；`git check-ignore` 输出该路径（证明 ignored/untracked）；`git status --porcelain` 为空；围栏 `^```` 计数 = 30；`wc -l` = 492；5 个锚点预检 `ANCHORS-OK`（每个 old 锚点全文件恰好 1 次）；快照落盘 `/tmp/catAtk-core-principles.260914-3vh.before.md`（唯一回退源）。
- **先对齐，后插入：** E3 的 old 锚用「`-- 等待比变身回能更划算`+`THEN ff()`」两行缩锚（前缀列字节保留不参与匹配，diff 呈纯插入）；新行空格数经 `sed -n`+`cmp`+`perl` 三重字节级核验 = 21（`--` 落第 50 字节列，与块内 234-239 行同列，与 PLAN.md 模板第 100 行的有效对齐一致）。
- **最小自检:** `GOT-4-EDITS`（5 条 grep 全命中）。

### Task 2: ZERO-DELTA + 精确文本验证电池（纯 bash，无 git）— `ALL-TEXT-GATES-PASS`

- **G1 正向精确断言（7 条）** — 全部新文本逐字 `grep -qF` 命中（含 E1 全句、阈值非对称理由句、E2 表行、E3 门行+注释、E4 新日期）。
- **G2 旧文本清空断言（3 条）** — `割裂保护优先于泄能` / 旧 E1 整句 / `2026-08-23` 计数均 = 0。
- **G3 ZERO-DELTA 快照 diff** — 行数 492 → 494（delta +2）；hunk 恰 4（`@@` 计数 = 4）；删除行恰 3（E1 旧段 2 + E4 日期 1）；新增行恰 5（E1 新段 2 + E2 表行 1 + E3 门行 1 + E4 日期 1）。目视 4 个 hunk 仅对应 规则3 / 规则8 / 附录B / 页脚，无任何其它字节变化。
- **G4 结构与风格不变量** — 围栏数仍 30；`*作者：pf_miles*` 逐字 1 次；页脚目视：时间戳行 2 尾随空格保留、作者行原文、末行无换行符（未补加）。
- **G5 常量漂移审计** — 10 个 token（8.5s/25s/75%/15%/2.3s/10s/9s/2s/1s/1.5s）与快照计数逐一相等（E1 新句内 2.3s 计数不变、1.3s 不在 token 清单且不影响子串计数）。

### Task 3: 收尾 — 无 commit 变体（遵从 orchestrator 启动约束）

**偏离记录：** 计划 Task 3 的 docs commit（PLAN/SUMMARY/STATE.md 三路径）由 orchestrator 启动约束取代——本次执行 **创建任何 commit**，`.planning` 工件（含 PLAN.md、STATE.md）交由 orchestrator 统一处理，全部保持未提交。文档本体（`.planning/catAtk-core-principles.md`）自始至终未被 `git add`/`git commit`，修订只落工作树。

- **git 守卫（对应计划 Task 3 验证的等价项）：**
  - `git status --porcelain -- .planning/catAtk-core-principles.md` → 输出为空（未跟踪入仓；文件仍在工作树且可被 grep 命中）；
  - `git ls-files -- .planning/catAtk-core-principles.md` → 为空（从未进入任何 commit）；
  - `git check-ignore .planning/catAtk-core-principles.md` → 仍输出该路径；
  - `git status --short` → 仅 `?? .planning/quick/260914-3vh-revise-planning-catatk-core-principles-m/`（orchestrator 待取）。

## 执行过程备注

1. **E3 对齐的字节级裁决：** 插入后曾用 `awk index()` 复核 `--` 列位置，因该环境 awk 的字符/字节计数语义与 CJK 混排行不符，一度读数疑似多 2 空格（index=52）；改用 `perl` 捕获空格串 + `sed -n '240p'`/`cmp` 字节比对，证实插入行与「28 字符前缀 + 21 空格」准备稿字节级一致、`--` 与块内同列（byte col 50）。其间一次针对「多余空格」的 Edit 因 old_string 不匹配而未写入（工具报 not found，文件零变化），**未触发快照回退**——当前文件即正确终态。
2. **失败即回退机制：** 全程未触发（无任一验证失败）。
3. **禁止项合规：** 未运行 `build.sh`、Lua 解释器、bbcheck（纯 markdown 文档 N/A）；未用 Write 整体重写文档；未改行尾/LF/末行无换行符。

## 完成标准对照

- 4 处编辑全部就位，Task 2 输出 `ALL-TEXT-GATES-PASS`；快照 diff 恰 4 hunk（-3/+5），`wc -l` 492 → 494（末行仍无换行符），围栏 30 不变 — ✅
- 原则文档仍在工作树、仍被 `.gitignore` 忽略、从未进入任何 commit（porcelain 空 + ls-files 空 + check-ignore 命中）— ✅
- docs commit（PLAN/SUMMARY/STATE.md）：**由 orchestrator 启动约束延期**，本次 0 commit；STATE.md 行将由 orchestrator 按其 docs commit 的实际 sha 补入，建议行文本（计划原文，Commit 列以实际 sha 填充）：
  `| 260914-3vh | catAtk 原则文档 4 处锁定修订：规则3 例外扩展至双流血（扫击 ≤1.3s 并行门）+ 阈值非对称理由、附录B 新增撕咬扫击刷新保护 1.3s 行、规则8 补 NOT isKillShotOrLastChance 排除门、页脚时间戳→2026-09-14；工作树-only 不入 git | 2026-09-14 | <docs-commit-sha> | [260914-3vh-revise-planning-catatk-core-principles-m](./quick/260914-3vh-revise-planning-catatk-core-principles-m/) |`

## Deviations from Plan

**1. [Task 3 执行模型变更] docs commit 与 STATE.md 行移交 orchestrator**
- **原因:** orchestrator 启动约束：本任务不可 commit 文档本体，且「可以零 commit」，`.planning` 工件由 orchestrator 处理。
- **处理:** 未创建任何 commit；STATE.md 行文本已在上文给出供 orchestrator 落位；文档本体三项 git 守卫证明未入仓。

**2. [E3 锚点形式微调（字节效果不变）] old 锚取行尾 (`-- 等待比变身回能更划算` + `THEN ff()`)，非整行**
- **原因:** 避免手工复制 26 空格的前缀行（计划允许「从文件复制该行」，此处改为前缀不参与匹配）。
- **效果:** 前缀字节未触碰，diff 为纯插入（与计划预期 -3/+5 完全一致），对齐经字节级核验。

## Self-Check: PASSED

- `/home/admin/workspace/macro-torch/.planning/catAtk-core-principles.md` 存在且含 4 处新文本（G1 7/7 命中）— FOUND
- 快照 `/tmp/catAtk-core-principles.260914-3vh.before.md` 存在；diff 恰 4 hunk — FOUND
- 本次 0 commit（无 hash 可验，守卫见上文）— N/A-by-design