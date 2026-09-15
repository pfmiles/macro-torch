---
phase: quick-260916-0hh
plan: 260916-0hh
quick_id: 260916-0hh
slug: fix-260915-uzs-review-warnings-wr-01-02-
subsystem: druid-cat energy tick 探针 260915-uzs 评审 WR-01/02/03 修复（core/events.lua RAW tap 大小写不敏感 + energy_probe.lua EV 列契约/UnitMana 守卫）
tags: [druid-cat, energy-tick, probe, review-fix, wr-01, wr-02, wr-03, case-insensitive, string-lower, lua50]
status: complete
date: 2026-09-16
one_liner: "260915-uzs 评审 3 条 Warning 逐字落地：WR-01 core/events.lua RAW tap 重构为外层 flag 门 + string.lower 后 find 的嵌套块（任意大小写 energize 行均捕获，tap 保持只读落穿、OFF 零求值）；WR-02 energy_probe.lua EV 模板改为 EPR|EV|t=...|ev=...（t= 紧跟 TYPE，8 线路型全部满足 EPR|<TYPE>|t= 固定列契约，旧模板源码/产物零残留）；WR-03 两处 UnitMana 第一返回值补 e = e or 0 守卫 + POLL 的 d 补 math.floor 对齐 EV。恰 2 文件、1 原子 commit（4 删 9 增，行数锁定 222/119）、三解释器 + luac 语法门全绿、build 冒烟后 SM_Extend.lua 8 线路型契约全绿"
key_files:
  modified: [core/events.lua, classes/druid/energy_probe.lua]
decisions:
  - "零代码偏差执行：4 次 Edit 按锁定 before/after 一次命中、落位字节与规划 after 状态逐字一致（222/119 行数锁定、EOF 无换行现状保持、第 50 行 EV d 零改动）；GATE A/C 首轮全绿，GATE B/E 首轮全绿"
  - "GATE D 三条子断言因规划侧 git-diff 建模缺陷不可满足（非实现偏差）：(1) 删除面 wc -l = 5——旧 tap end 行与锁定 after 状态的新 end 行字节相同，任何 diff 算法都按 LCS 对齐为 unchanged，不可能呈现为删除行；(2) git status --porcelain 恰 2 行——quick 流程自建计划目录未 track，必然多一行 ??；(3) hunk 范围正则要求行号后带逗号——-U0 单行改动 hunk 头为 `@@ -57 +58 @@`（无 `,1`），正则永不匹配。三条断言所验证的真不变式（恰 5 个枚举旧行被消费/重写、工作树恰 2 个 tracked 文件被改、hunk 全落在 40-119/150-199 带内）均以等价检查实锤通过，见下与正文 GATE D'"
  - "WINDOWS.md 按规划锁约束零触碰：unrun-verify 电池仅在 SUMMARY 备案（4 项实机验证点），260915 系列电池全绿后由用户另行 close"
commits:
  code: 69c2e4b
duration_seconds: 240
estimate:
  tokens: 32000
  raw_tokens: 16000
  tasks: 2
  confidence: low
actuals:
  tokens: 227
  raw_tokens: 227
  tasks: 2
  commits: 1
---

# Quick 260916-0hh Summary

260915-uzs 代码评审的 3 条 Warning（WR-01/02/03）按其 Fix 段逐字落地，恰改 `core/events.lua` 与 `classes/druid/energy_probe.lua` 两文件：WR-01 把 RAW_COMBATLOG tap 的单条件 `string.find(arg2, 'nergize')` 重构为外层 flag 门 + `string.lower` 后 find 的嵌套块（任意大小写 energize raw 行——`SPELL_ENERGIZE`/`SPELL_PERIODIC_ENERGIZE` 及小写变体——皆命中；`string.lower` 在 flag 门内才求值，probe OFF 仍零计算零输出；tap 不加 return、不消费 arg2，cpDamage gate 与 tier-1 白名单可达性不变）；WR-02 把 EV 模板改列契约 `EPR|EV|t=<ts>|ev=<事件名>|earg=...`（t= 紧随 TYPE，事件名后移到 ev= KV，8 种线路型头字段序全对齐，离线 pipe-split 解析器 `fields[2]` 恒为 t= 字段）；WR-03 在 recordEvLine 与 probeOnUpdate 两处 UnitMana 调用后、任何算术前插入 `e = e or 0` 守卫，POLL 的 `d` 补 `math.floor` 对齐 EV 写法（第 50 行 EV d 句零改动，`m = m or 0` 保留）。

## 任务完成

### Task 1：三处锁定 Edit（4 次精确 Edit 一次命中）

| 变更 | 文件 | 内容 |
|------|------|------|
| Edit (a) RAW tap 重构 | core/events.lua | 旧 3 行（158-160）换为 6 行嵌套块：`if macroTorch.energyProbe and arg2 then` → `local lum = string.lower(arg2 or '')` → `if string.find(lum, 'nergize') then` → log 行（16 空格）→ 双 `end`（12/8 空格）。行数 219→222，其余 216 行字节零动；无 return、log 调用位保持在 RAW 分支头部 |
| Edit (b) recordEvLine e 守卫 | classes/druid/energy_probe.lua | `local e, m = UnitMana('player')` 后插入 `e = e or 0`（第 49 行），位于 `m = m or 0` 与 EV d floor 句之前 |
| Edit (c) EV 模板换新 | classes/druid/energy_probe.lua | `EPR|EV|%s|t=...` → `EPR|EV|t=%.3f|ev=%s|earg=%s|e=%s|m=%s|d=%d|dt=%d`，实参序 `now, evName, ...`，其余锚位不动 |
| Edit (d) probeOnUpdate 守卫 + POLL floor | classes/druid/energy_probe.lua | 第二处 UnitMana 后插入 `e = e or 0`；`local d = e - (lastPollEnergy or e)` → `local d = math.floor(e - (lastPollEnergy or e))`。pollAccum 减法与 POLL log 行（112/113）零改动 |

**验证 gates：**
- **GATE A 全绿**：lua-5.0.3 / 5.1.5 / 5.4.7 三解释器 `assert(loadfile(...))` 各打印 LOADFILE-OK，`/usr/bin/luac -p` 两文件通过。
- **GATE C 全绿**：events.lua = 222 行、energy_probe.lua = 119 行；lum 行、`string.find(lum, 'nergize')` 行、cpDamage gate 计数、tap 先于 gate 顺序、2× e 守卫、2× m 守卫、EV d 句零改动、POLL floor、新 EV 模板共 12 项断言全部 PASS。
- **GATE D（原文）三条子断言不可满足，以等价 GATE D' 全绿替代**（详见「偏差」）：4 条 git 可见删除行与枚举一一对应（旧 tap if / 旧 RAW log / 旧 EV 模板 / 旧 POLL d），第 5 条（旧 `end` 行）以"文件中旧文本零残留 + 222/119 行数锁定"证明被重写消费；hunk 行号 48/57/107/109（EP）与 158（EV）数值实测全部落在锁定带内；工作树恰 2 个 tracked 文件改动 + 唯一 untracked 为本 quick 自建计划目录；`git diff --check` 干净。

### Task 2：build 冒烟 + 8 线路型契约 + 原子 commit

- `bash build.sh` exit 0（本机非 cygwin，结尾不拷贝；SM_Extend.lua 为 git-ignored 产物，重建不产生工作树改动）。
- **GATE B 全绿**：SM_Extend.lua 含 SES/POLL/RAW/CAST/REL 各 1 + PDT 3（tx=RAW×1 + tx=CHAT×2）+ 新 EV 模板恰 1；`EPR|EV|t=%.3f|ev=%s` 顺序命中 1 次；旧 `EPR|EV|%s|t=` 在产物与源码中均 0 残留。
- **原子 commit** `69c2e4b`：message 逐字锁定 `fix(260916-0hh): case-insensitive RAW energize tap; EV line ev= KV after t=; UnitMana e nil-guard + POLL floor (WR-01/02/03)`，`git show --name-only` 恰为两代码文件、零 `.planning` 夹带。
- **GATE E 全绿** + commit 后 `git status --porcelain` 仅剩本 quick 计划目录 `???`（由 quick 流程 docs commit 收口）；`git diff --diff-filter=D HEAD~1 HEAD` 无 tracked 文件删除。

## 偏差

### 规划侧 gate 模型缺陷（非代码偏差；零实现影响）

代码五条删除行与写入枚举的对应关系逐字成立，但 GATE D 三条断言因规划时对 git diff 输出形态的错误建模而**逻辑不可满足**，均以等价检查实锤同一不变式后继续：

1. **[Plan gate defect] 删除面 `wc -l /tmp/0hh_del.txt = 5` 不可满足。** 锁定的 after 状态中嵌套块关闭行 `        end`（8 空格）与旧 tap 关闭行字节完全相同；git 任何 diff 算法（Myers/patience/histogram——`end` 行非唯一，后两者同样回退到 Myers 区间匹配）都按 LCS 把相同字节行对齐为 unchanged，不可能呈现为 `-` 行。实锤等价：git 可见删除恰 4 行、与枚举条目一一对应（`string.find(arg2, 'nergize')`×1 / `EPR|RAW`×1 / `EPR|EV|%s|t=`×1 / `e - (lastPollEnergy or e)`×1），旧文本在源码中零残留，事件.lua 222 行与 energy_probe.lua 119 行锁定证明换行面恰为 5 行、无第 6 处改写。commit 统计 4 deletions / 9 insertions 与此一致（规划预测 5 删 10 增，差 1 即同字节 end 行）。
2. **[Plan gate defect] `git status --porcelain` 恰 2 行不可满足。** quick 流程自建的计划目录 `.planning/quick/260916-0hh-.../` 在 docs commit 之前必然 untracked，`--porcelain` 必多一行 `??`。实锤等价：改动的 tracked 文件恰 2 个（该两代码文件），untracked 恰 1 个且为本 quick 计划目录。
3. **[Plan gate defect] hunk 范围正则 `^@@ -([4-9][0-9]|1[01][0-9]),` 不可满足。** `-U0` 下纯插入 hunk 头为 `@@ -48,0 +49 @@`、单行改动 hunk 头为 `@@ -57 +58 @@`（git 省略 `,1` 计数），正则要求的逗号在 `-57`/`-109` 头上不存在。实锤等价：数值解析 hunk 头行号 = EP 48/57/107/109（全部 ∈ [40,119]）、EV 158（∈ [150,199]），hunk 计数 4+1，全部落在锁定带内。

其余全部按规划零偏差：锚点字节级核对一致、4 次 Edit 一次命中、三解释器 + luac 语法门首轮全绿、GATE B/E 首轮全绿、WINDOWS.md 与 build_order.txt/cat.lua/其余文件零触碰、energy_probe.lua 文件尾无换行现状保持（`tail -c 3` 末字节为 `)`, 无 `\n`）、IN-01..IN-04 评审 Info 条目未顺手修。

## Unrun Verification（实机电池 — 按规划仅 SUMMARY 备案，不改 WINDOWS.md）

本机无 WoW 客户端。静态门全绿后，用户 Windows+Cygwin 重建 `/mt` 实机验证（承接 quick-260915-uzs 既有电池，本次修复使其更容易通过）：

1. `/run macroTorch.energyProbe = true` 后，出现大写 `SPELL_ENERGIZE`/`SPELL_PERIODIC_ENERGIZE` raw 行时应看到 `EPR|RAW` 行（WR-01 修复点；若仍无则属于未检测到该类 raw 事件，而非大小写失配）。
2. EPR|EV 行目测格式 `EPR|EV|t=<ts>|ev=UNIT_ENERGY|...`（t= 紧随 EV|，事件名在 ev= 后）。
3. POLL 行在能量显示正常期间与既有一致；d 恒为整数。
4. WINDOWS.md ledger 无新增行（本次零触碰）；后续若 260915 系列电池实机全绿，由用户另行 close。

## Threat Flags

无超出规划 `<threat_model>` 的新攻击面。三处改动与既定处置一致：T-0hh-01（RAW tap arg2 → lower/find → %s 落盘）= accept，与修复前攻击面相同（tap 仍只读）；T-0hh-02（UnitMana 异常返回值）= mitigate，WR-03 双守卫消灭 nil 算术抛错与 POLL 逐帧重抛放大；T-0hh-03（探针 EPR| 行内容）= accept，`macroTorch.energyProbe` nil-guard 默认 false 未动。零包管理器安装，package legitimacy 门不适用。

## Self-Check

- [x] `core/events.lua` 222 行、`classes/druid/energy_probe.lua` 119 行（GATE C）
- [x] commit `69c2e4b` 存在且文件集合恰为两代码文件（`git show --name-only --format= HEAD`）
- [x] 本 SUMMARY.md 已写到 `.planning/quick/260916-0hh-.../`（未进入代码 commit，留给 quick 流程 docs commit）
- [x] `git status --porcelain` commit 后仅剩本 quick 计划目录 `???`

## Self-Check: PASSED