---
quick_id: 261016-vbt
slug: castloadeditem-cd-entity-player-lua-685-
description: "修正 castLoadedItem 的 CD 命中语义（entity/Player.lua 685-706 区，裁决 2026-10-16）：释放键按下且 pokemon 在 CD 时跳过使用（不喊 saying）、打印 CD 提示、置 useableItemUsed=true 后同一按直接落穿恢复臂换回原装备（等价成功场景第 2 下）；成功两按语义不变（第 1 下使用+喊 saying 后 return、第 2 下恢复）。raid 背景：道具 CD 没转好无时间等待，必须直接换回正确装备进 boss 战；装载后 CD 内能否释放由用户人工保证，程序不做重试保持。最小三改：①冷却成功臂末尾追加 return；②CD 分支删 else、改打印提示+置标落穿（恰 1 行注释保持净零行位移）；③702 else→if loadingTable.useableItemUsed then 承接。恢复臂正文（原 707-765）与头 1-684、尾 766 起逐字节不动。恰 1 个 code commit；SUMMARY.md status: complete 写于 quick 目录不入 git（orchestrator Step 8 收口）。"
date: 2026-10-16
phase: quick-261016-vbt
plan: 261016-vbt
type: execute
wave: 1
depends_on: []
files_modified: [entity/Player.lua]
autonomous: true
requirements: ["R-01@quick-261016-vbt", "R-02@quick-261016-vbt"]
estimate:
  tokens: 45000
  raw_tokens: 22000
  tasks: 2
  confidence: low
must_haves:
  truths:
    - "CD 命中语义（裁决 2026-10-16，R-01）：释放键按下且 useableItem 在 CD → 不 use、不 say、打印 CD 提示、置 useableItemUsed=true 并同一按落入恢复臂换回原装备；成功场景两按语义不变（第 1 下 use+say 后 return、第 2 下恢复）；无重试保持逻辑（R-01）"
    - "四带 md5 逐字节对焊 HEAD 29dbc6e：头 1-684、恢复臂正文 707-766（combat 暂停守卫起至恢复臂收尾，含三臂与幂等清表）、尾 766 起全部不动；改区 695-706 恰 12 行逐字节等于锁定 NEW 块（md5 bdbd6e2d477b0f8b973b812072849346）；文件仍 991 行（净零行位移，R-02）"
    - "计数门：useableItemUsed = true 恰 2（冷却臂保留 1 + CD 落穿新增 1）；旧 CD 提示行与旧的 keep 注释归零；新承接行 if loadingTable.useableItemUsed then 恰 1；战斗守卫行位置仍 707（R-02）"
    - "静态门全绿：lua-5.0.3 loadfile（权威）+5.1.5/5.4.7 佐证、bbcheck BALANCED、CRLF 0、单 hunk、新增行无 #/goto/::、git diff --check clean（R-02）"
    - "恰 1 个 commit 仅含 entity/Player.lua，message 逐字 fix(261016-vbt): restore same-press on pokemon CD hit (castLoadedItem)；docs/、SM_Extend.lua、core/selftest.lua、已提交的 261016-20c 制品零 diff（R-02）"
    - "SUMMARY.md 含 status: complete + UAT 口径更新（CD 命中→同按恢复）+ Truth 4 CD 重试语义覆盖备案；不改 29dbc6e 已提交制品；零 docs commit（orchestrator Step 8 收口，R-01/R-02）"
  artifacts:
    - "entity/Player.lua（castLoadedItem 695-706 区三处裁决落地，其余逐字节不动）"
    - ".planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/261016-vbt-SUMMARY.md（status: complete，不入 git）"
  key_links:
    - "冷却臂末尾 return（696）：成功分支提前退出的唯一门——漏加则成功后仍会落入 CD 提示块；区域 md5 + 三解释器 + bbcheck 兜底"
    - "702 行 else→if loadingTable.useableItemUsed then：第 2 下与 CD 落穿共用同一承接点的唯一分派行；此判断是两按语义（成功/命中）的汇聚处"
    - "净零行位移：CD 落穿块恰 1 行注释 → 707-766 恢复臂与尾部行号不飘动，是四带 md5 对焊与 991 行不变式成立的前提"
---

<objective>
将 castLoadedItem 的 CD 命中语义修正为用户裁决（2026-10-16）锁定的行为：释放键按下时若 pokemon（useableItem）处于 CD，跳过使用（不喊 saying）、打印 CD 提示、将 useableItemUsed 置 true 并同一按立即走恢复臂换回原装备——等价于释放成功场景下的第 2 下。释放成功两按语义不变（第 1 下使用+喊 saying，成功后 return；第 2 下恢复）。raid 背景：道具 CD 没转好时没有时间等待，必须直接换回正确装备进 boss 战；装载后能否在 CD 内释放完全由用户人工保证，程序不做重试保持。

Purpose: 消除 CD 命中时第 1 下被「保留重试位、下次再按才恢复」浪费按键的语义，改为同按即恢复（R-01）。
Output: entity/Player.lua 的单 hunk 最小改动（R-02）+ quick SUMMARY.md（status: complete，不入 git）。
</objective>

<execution_context>@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

## 规划时实测事实（#3786 活体观测权威，2026-10-16）

- 基线 BASE = HEAD = `29dbc6ee8ee0b1d0460bf38feb510172d724d459`（message: `docs(quick-261016-20c): add task summary + VERIFICATION (human_needed) + STATE.md row`）；工作树 clean。
- 三解释器在位且对当前 entity/Player.lua loadfile 全绿：`/tmp/luabuild/lua-5.0.3/bin/lua`（权威）、`/tmp/luabuild/lua-5.1.5/src/lua`、`/tmp/luabuild/lua-5.4.7/src/lua`；`node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js entity/Player.lua` 输出 BALANCED。
- 基线区域 md5（对 HEAD 29dbc6e 实测）：头 1-684 = `0273e4ffe03e921e787e4473fba6954a`；恢复臂 707-766 = `81258c7e5bd319bc24055525652a8a7d`；尾 766-end = `c5229c53fd2eba98dcc270bf258bc6bd`。
- 改区锁定 NEW 块（695-706，12 行）md5 = `bdbd6e2d477b0f8b973b812072849346`（规划时对 NEW 块逐字构造并模拟拼接全文件后：991 行、三解释器 5.0.3/5.1.5/5.4.7 loadfile 全绿、bbcheck BALANCED、CRLF 0、`useableItemUsed = true` 计数 2、旧文本归零、战斗守卫行仍 707——全部经模拟验证，非猜算）。
- 行锚：改前 685 守卫行 / 696 内层 else / 697 旧 CD 提示行 / 702 外层 else / 703 恢复臂头注释首行 / 707 战斗守卫行（24 空格缩进唯一）；改后 702 = if 承接行。
- 所有 automated 门命令 cwd = 仓库根。

## 锁定约束（违反即失败）

1. **只改一个文件、恰一次 Edit**：`entity/Player.lua` 的 695-706 区，old/new 块逐字取「编辑契约」。禁止 sed/perl 行级改写、禁止全文件 Write、禁止自行发挥任一字节；Edit 的 old_string 须与 OLD 块逐字节一致，漂移即停并报告。
2. **裁决三改（R-01）**：①冷却成功臂（use+show+saying+置标的末尾）追加 `return`；②CD 分支删除原 else，改为打印 CD 提示后置 `loadingTable.useableItemUsed = true` 并落穿；③原 702 行 else 改为 `if loadingTable.useableItemUsed then` 承接恢复臂。恢复臂正文（combat 暂停守卫、幂等清表、三臂）逐字节不动，仅 703 头注释首行按契约微调覆盖「press 2 / CD-skip 同按」。
3. **零触碰带**：头 1-684、恢复臂 707-766、尾 766 起与 HEAD 基线逐字节一致（md5 对焊）；净零行位移（总 991 行不变）。
4. **Lua 5.0 合规**：新增行不得出现 `#` 长度运算符、`goto`、`::`；行尾 LF，CRLF 计数 0。
5. **原子性与交付**：Task 1 恰 1 个 commit，message 逐字 `fix(261016-vbt): restore same-press on pokemon CD hit (castLoadedItem)`；Task 2 写 SUMMARY.md 收口零 commit。STATE.md 行与 PLAN/SUMMARY 提交由 quick 流程 orchestrator Step 8 收口，执行者不写不入 git。
6. **不改已提交制品**：已提交的 `261016-20c` SUMMARY/VERIFICATION（29dbc6e 制品）中 Truth 4 的「CD 重试」语义被本裁决覆盖——只在本次 quick SUMMARY 中备案，禁止改动该目录任何文件。

## 编辑契约（唯一编辑权威；置于 tasks 区之外，#429 评论文本纪律：OLD 块内归零门字面量不得出现在任一 action 正文）

old_string（现 695-706 全文）：

```text
                            loadingTable.useableItemUsed = true
                        else
                            macroTorch.show("Useable item is in CD: " .. loadingTable.useableItem)
                            -- keep useableItemUsed = false: the use did not
                            -- happen, so the next press retries instead of
                            -- restoring
                        end
                    else
                        -- Release press 2: restore the original equipment.
                        -- Combat pause: protected equip actions are
                        -- client-refused in combat; press again after combat,
                        -- state is kept.
```

new_string（695-706 新全文，12 行）：

```text
                            loadingTable.useableItemUsed = true
                            return
                        end
                        macroTorch.show("Useable item is in CD, restoring: " .. loadingTable.useableItem)
                        -- On cooldown the use is skipped; the same press restores the original equipment
                        loadingTable.useableItemUsed = true
                    end
                    if loadingTable.useableItemUsed then
                        -- Restore arm: press 2, or the same press after a CD skip, restores the original equipment.
                        -- Combat pause: protected equip actions are
                        -- client-refused in combat; press again after combat,
                        -- state is kept.
```

（行 704-706 三条 = OLD 块尾三条逐字不动；OLD 块 8 行、NEW 块头部 7 行 + 头注释 1:1 替换 → 净零行位移。）

<tasks>

<task type="auto">
  <name>Task 1: castLoadedItem CD 语义三改（单 Edit + 单 commit）</name>
  <files>entity/Player.lua</files>
  <precondition>HEAD = `29dbc6ee8ee0b1d0460bf38feb510172d724d459`（其 message 为 `docs(quick-261016-20c): add task summary + VERIFICATION (human_needed) + STATE.md row`）；porcelain 为空或恰为 `?? .planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/` 一行且零 tracked 改动、零其他 untracked；/tmp/luabuild 三解释器（5.0.3 权威、5.1.5/5.4.7 佐证）与 `.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js` 在位（2026-10-16 规划时实测）。任一不满足→停下报告，禁止绕行、禁止重锚定（md5 基线按 29dbc6e 钉死，BASE 漂移即本计划失效）。</precondition>
  <action>1. Read entity/Player.lua 675-775 区间一次；改前锚点断言（cwd=仓库根）：`grep -n -F 'if loadingTable.useableItemUsed == false then' entity/Player.lua` 恰在 685、`grep -n -F '                    else' entity/Player.lua` 恰含 702、`grep -n -F 'if UnitAffectingCombat("player") then' entity/Player.lua | tail -1` 恰在 707，且 685-706 区与「编辑契约」OLD 块逐字节一致；任一不匹配→停下报告，禁止自行适应。
  2. 恰一次 Edit：old_string = 编辑契约 OLD 块全文、new_string = 编辑契约 NEW 块全文（逐字取用，不增删改任一字节）；仅此一个修改，禁止其它任何改动（含空白与行尾）。这正是裁决 2026-10-16 的三改：冷却臂末 return、CD 分支去 else 改提示+置标落穿、702 else→if 承接（R-01）。
  3. 跑本 task verify 的第一段「提交前门」。全绿后：`git add entity/Player.lua`，`git commit -m "fix(261016-vbt): restore same-press on pokemon CD hit (castLoadedItem)"`（message 逐字英文，单行）。
  4. 跑本 task verify 的第二段「提交后门」。任一失败：停在当场报告；禁止伪造绿、禁止修改门。</action>
  <verify>
    <automated># ---- 提交前门：在 git add/commit 之前跑。cwd = 仓库根 ----
set -euo pipefail
F=entity/Player.lua
# 四带 md5 对焊（满铺互斥：头/改区/恢复臂/尾）+ 总行数净零不变式
test "$(sed -n '1,684p' $F | md5sum | cut -d' ' -f1)" = "0273e4ffe03e921e787e4473fba6954a"
test "$(sed -n '695,706p' $F | md5sum | cut -d' ' -f1)" = "bdbd6e2d477b0f8b973b812072849346"
test "$(sed -n '707,766p' $F | md5sum | cut -d' ' -f1)" = "81258c7e5bd319bc24055525652a8a7d"
test "$(sed -n '766,$p' $F | md5sum | cut -d' ' -f1)" = "c5229c53fd2eba98dcc270bf258bc6bd"
test "$(wc -l < $F)" = "991"
# 计数门（规划时实测钉死）
test "$(grep -oc 'useableItemUsed = true' $F)" = "2"
test "$(grep -ocF 'Useable item is in CD: ' $F)" = "0"
test "$(grep -ocF -- '-- keep useableItemUsed = false: the use did not' $F)" = "0"
test "$(grep -ocF 'Useable item is in CD, restoring: ' $F)" = "1"
test "$(grep -ocF 'if loadingTable.useableItemUsed then' $F)" = "1"
test "$(grep -n -F 'if UnitAffectingCombat("player") then' $F | tail -1 | cut -d: -f1)" = "707"
# 语法门：5.0.3 loadfile（权威，通过即 Lua 5.0 合规）+ 5.1.5/5.4.7 佐证 + bbcheck BALANCED + CRLF 0
/tmp/luabuild/lua-5.0.3/bin/lua -e "assert(loadfile('entity/Player.lua'))"
/tmp/luabuild/lua-5.1.5/src/lua -e "assert(loadfile('entity/Player.lua'))"
/tmp/luabuild/lua-5.4.7/src/lua -e "assert(loadfile('entity/Player.lua'))"
node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js entity/Player.lua | grep -F BALANCED
test "$(grep -oc $'\r' entity/Player.lua)" = "0"
# diff 卫生门：恰 1 hunk、新增行无 #/goto/::、diff --check clean、改动恰 1 文件
G="$(git diff -- entity/Player.lua)"
test -n "$G"
test "$(printf '%s' "$G" | grep '^+[^+]' | grep -oc '#\|goto\|::')" = "0"
test "$(printf '%s' "$G" | grep -oc '^@@')" = "1"
test -z "$(git diff --check -- entity/Player.lua)"
DT="$(git diff --name-only)"
test "$(printf '%s\n' "$DT" | wc -l)" = "1"
test "$DT" = "entity/Player.lua"</automated>
    <automated># ---- 提交后门：单 commit 形状 + 零触碰带。cwd = 仓库根 ----
set -euo pipefail
test "$(git show --stat --format= --name-only HEAD)" = "entity/Player.lua"
test "$(git log -1 --format=%s)" = "fix(261016-vbt): restore same-press on pokemon CD hit (castLoadedItem)"
BASE="$(git rev-parse HEAD~1)"
test "$BASE" = "29dbc6ee8ee0b1d0460bf38feb510172d724d459"
test "$(git log --oneline "$BASE..HEAD" | wc -l)" = "1"
test -z "$(git diff "$BASE..HEAD" -- docs/)"
test -z "$(git diff "$BASE..HEAD" -- SM_Extend.lua)"
test -z "$(git diff "$BASE..HEAD" -- core/selftest.lua)"
test -z "$(git diff "$BASE..HEAD" -- .planning/quick/261016-20c-pokemon-entity-player-lua-loaduseableite/)"
test -z "$(git diff --check "$BASE..HEAD")"
# porcelain 等价门（#3786 计划内预锚定）：空或恰为本 quick 目录一行，零 tracked 改动、零其他 untracked
SP="$(git status --porcelain)"
if [ -n "$SP" ]; then
    test "$SP" = '?? .planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/'
fi</automated>
  </verify>
  <done>单次 Edit 逐字节符合编辑契约：695-706 改区 md5 = bdbd6e2d477b0f8b973b812072849346；头 1-684 / 恢复臂 707-766 / 尾 766 起 md5 与 HEAD 29dbc6e 对焊（0273e4ff…/81258c7e…/c5229c53…）；文件仍 991 行；计数门 2/0/0/1/1 与战斗守卫 707 全中；lua-5.0.3 + 5.1.5 + 5.4.7 loadfile 全绿、bbcheck BALANCED、CRLF 0、恰 1 hunk、新增行无 #/goto/::、diff --check clean；恰 1 个 commit 仅含 entity/Player.lua，message 逐字符合锁定文本；docs/SM_Extend.lua/selftest/261016-20c 已提交制品零 diff；porcelain 等价门通过。</done>
</task>

<task type="auto">
  <name>Task 2: quick SUMMARY 收口（status: complete，零 commit）</name>
  <files>.planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/261016-vbt-SUMMARY.md</files>
  <action>1. 零新增代码改动、零 commit；不碰 entity/Player.lua 与其它任何 tracked 文件；不改已提交的 261016-20c 目录（29dbc6e 制品）。
  2. Write 本 quick SUMMARY.md（路径见本 task 的 files 字段；不入 git，提交归 orchestrator Step 8），内容须含：
     - `status: complete`
     - 裁决 2026-10-16 备案：释放键按下且 pokemon 在 CD → 跳过使用（不喊 saying）、打印 CD 提示、置 useableItemUsed=true、同一按立即走恢复臂换回原装备（等价成功场景第 2 下）；成功两按语义不变（第 1 下 use+say 后 return）；无重试保持；raid 背景理由一句话。
     - UAT 口径更新：CD 命中 → 同按恢复（原 261016-20c SUMMARY/VERIFICATION 中 Truth 4 的「CD 重试」语义被本裁决覆盖；已提交 29dbc6e 制品不改，仅在本 quick SUMMARY 备案——文中明确写 261016-20c 与 Truth 4 字样）。
     - Task 1 代码 commit 哈希与 gates 全绿清单（三解释器/bbcheck BALANCED/CRLF 0/diff --check clean/四带 md5 对焊/计数门/单 hunk）。
  3. 跑本 task 的收口门（见下方 verify）。</action>
  <verify>
    <automated>set -euo pipefail
test "$(git log -1 --format=%s)" = "fix(261016-vbt): restore same-press on pokemon CD hit (castLoadedItem)"
test "$(git log --oneline 29dbc6ee8ee0b1d0460bf38feb510172d724d459..HEAD | wc -l)" = "1"
test "$(git diff --name-only HEAD)" = ""
S=.planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/261016-vbt-SUMMARY.md
test -f "$S"
grep -q 'status: complete' "$S"
grep -q '261016-20c' "$S"
grep -q 'Truth 4' "$S"
# porcelain 等价门：恰为本 quick 目录一行（含 SUMMARY 的 untracked），零 tracked 改动、零其他 untracked
SP="$(git status --porcelain)"
test -n "$SP"
test "$SP" = '?? .planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/'</automated>
  </verify>
  <done>SUMMARY.md 存在且含 status: complete、裁决 2026-10-16 语义备案、UAT 口径更新（CD 命中→同按恢复）与 261016-20c Truth 4 覆盖注记（29dbc6e 制品零改动）；零新增 commit；工作树 tracked 零改动；porcelain 恰为 quick 目录一行。</done>
</task>

</tasks>

## GATE 汇总（命令即 task 内 verify，不复述）

- 改前锚点门：685 守卫 / 702 else / 707 战斗守卫（24 空格缩进、tail -1 定位）位置钉死；Edit old_string 漂移即停。
- 四带 md5 对焊门：头 1-684、改区 695-706（bdbd6e2d…）、恢复臂 707-766、尾 766 起（另 991 行净零不变式）——满铺互斥，覆盖全文件。
- 计数门：`useableItemUsed = true`=2、旧 CD 提示行=0（`Useable item is in CD: ` 裸 == 0 合法：新文案不含该字面量）、旧 keep 注释=0、新 CD-restoring 提示=1、if 承接行=1、战斗守卫行号=707。
- 语法门：lua-5.0.3 loadfile（权威）+ 5.1.5/5.4.7 佐证 + bbcheck BALANCED + CRLF 0。
- diff 卫生门：恰 1 hunk、新增行无 `#`/`goto`/`::`、`git diff --check` clean、改动恰 entity/Player.lua 一个文件。
- 交付门：恰 1 commit message 逐字核对、BASE=29dbc6e 精确锚定、docs/SM_Extend/selftest/261016-20c 制品零 diff、porcelain 等价门（空或恰为本 quick 计划目录一行，零 tracked 改动、零其他 untracked——计划内预锚定，#3786）。
- Task 2 收口门：SUMMARY 三关键词 + 零新增 commit + 零 tracked 改动 + porcelain 恰本目录一行。

## 验证（整体）

Task 1/2 各自 verify 全绿即整体通过。崩溃类分支（BASE 漂移、锚点漂移、解释器/工具缺失、Edit 失败、任一 gate 未中）按 task 内说明停下报告，禁止自行适应（本 quick 不做 BASE 重锚定：四带 md5 基线钉死于 29dbc6e）、禁止伪造绿。**实机验证为 user-side unrun-verify（不并入本 quick 自动门，SUMMARY 备案口径，与 261016-20c/Phase 27-30 先例一致）**：用户 Windows+Cygwin 重建 SM_Extend.lua 后木桩验证——装载宠物道具待其 CD，按释放键观察：打印 CD 提示后同一按恢复原装备（无 saying）；道具可用时第 1 下使用+喊 saying、第 2 下恢复。

<success_criteria>
- entity/Player.lua 净化后四带 md5 全对焊、991 行、计数门全中
- 三解释器 loadfile 全绿（5.0.3 权威）+ bbcheck BALANCED + CRLF 0 + 单 hunk + diff --check clean
- 恰 1 个 code commit（message 锁定文本）仅含 entity/Player.lua
- SUMMARY.md status: complete（含 UAT 口径与 Truth 4 覆盖备案），零 docs commit
</success_criteria>

<output>
Create .planning/quick/261016-vbt-castloadeditem-cd-entity-player-lua-685-/261016-vbt-SUMMARY.md when done（status: complete；由 orchestrator Step 8 收口提交）
</output>