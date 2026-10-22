---
phase: quick-261016-vbt
plan: 261016-vbt
quick_id: 261016-vbt
slug: castloadeditem-cd-entity-player-lua-685-
subsystem: entity/Player
tags: [pokemon, cooldown, restore-same-press, state-machine]
required_by: []
provides: []
tech-stack:
  added: []
  patterns:
    - "CD 命中同按恢复：CD 分支删 else 落穿 + 置 loadingTable.useableItemUsed=true，与成功场景第 2 下共用同一承接行 `if loadingTable.useableItemUsed then`（两按语义汇聚处）"
    - "冷却成功臂末尾 return 是成功分支提前退出的唯一门——漏加则成功后仍会落入 CD 提示块"
    - "净零行位移：CD 落穿块恰 1 行注释 → 恢复臂 707-766 与尾部行号不漂移，四带 md5 对焊与 991 行不变式成立"
key-files:
  modified:
    - entity/Player.lua
decisions:
  - "裁决 2026-10-16：释放键按下且 pokemon 在 CD → 跳过使用（不喊 saying）、打印 CD 提示、置 useableItemUsed=true、同一按立即走恢复臂换回原装备（等价成功场景第 2 下）；成功两按语义不变（第 1 下 use+say 后 return）；无重试保持逻辑"
  - "CD 命中不做重试保持：raid 背景道具 CD 没转好时无时间等待，必须直接换回正确装备进 boss 战；装载后 CD 内能否释放由用户人工保证"
  - "UAT 口径覆盖：261016-20c SUMMARY/VERIFICATION 已提交制品（db9edbd）中 Truth 4 的「CD 重试」语义被本裁决覆盖——制品不改（约束），仅在本 quick SUMMARY 备案"
metrics:
  duration_sec: ~240
  completed_date: 2026-10-16
status: complete
actuals:
  tokens: 377
  tasks: 2
  commits: 1
  files_changed: 1
---

# Quick 261016-vbt: castLoadedItem CD-hit same-press restore (entity/Player.lua 685-706)

**castLoadedItem 的 CD 命中语义落地裁决 2026-10-16：CD 命中时同按即恢复（等价成功场景第 2 下），关闭原「保留重试位、下次再按才恢复」的按键浪费语义；单 hunk 12:12 净零行位移，恢复臂与文件其余部分逐字节不动。**

## 结果

entity/Player.lua 单文件最小三改（恰 1 次 Edit 逐字节取编辑契约）：

1. 冷却成功臂末尾追加 `return`（28 空格缩进，紧随 `loadingTable.useableItemUsed = true`）——成功分支提前退出的唯一门。
2. CD 分支删除原 `else`，改为打印新提示 `macroTorch.show("Useable item is in CD, restoring: " .. ...)` 后置 `loadingTable.useableItemUsed = true` 并落穿（恰 1 行注释，净零行位移）。
3. 原外层 `else` 改为 `if loadingTable.useableItemUsed then` 承接恢复臂——CD 落穿与成功第 2 下共用同一分派行；恢复臂头注释首行微调为「Restore arm: press 2, or the same press after a CD skip...」。

恢复臂正文（707-766：combat 暂停守卫、幂等清表、三臂）与头 1-684、尾 766 起逐字节不动；文件仍 991 行。

## 裁决 2026-10-16 备案（R-01）

- **释放键按下且 useableItem 在 CD** → 跳过使用（不喊 saying）、打印 CD 提示、置 `useableItemUsed = true`，**同一按立即落入恢复臂**换回原装备——等价于释放成功场景下的第 2 下。
- **释放成功两按语义不变**：第 1 下使用 + 喊 saying 后 `return`；第 2 下恢复原装备。
- **无重试保持逻辑**：装载后能否在 CD 内释放完全由用户人工保证，程序不做重试等待。
- **raid 背景理由**：道具 CD 没转好时无时间等待，必须直接换回正确装备进 boss 战。

## UAT 口径更新

- **CD 命中 → 同按恢复**（本条裁决）。
- 原 `261016-20c` SUMMARY/VERIFICATION（已提交于 db9edbd 制品）中 **Truth 4** 的「CD 重试」语义（CD 命中不置 used、下次再按才恢复）已被本裁决覆盖；已提交的 `261016-20c` 制品**零改动**（约束 6），覆盖备案仅落在本 quick SUMMARY 中。

## 交付

| 项 | 值 |
|----|----|
| commit | `f32705c` `fix(261016-vbt): restore same-press on pokemon CD hit (castLoadedItem)` |
| 文件 | 恰 `entity/Player.lua`（+7/-7，改区恰 1 hunk） |
| BASE | `db9edbd`（`docs(quick-261016-20c): add task summary + VERIFICATION + STATE.md row`，无重锚定） |

## 静态门（全部实测绿，无规避）

- **四带 md5 对焊**：头 1-684 = `0273e4ff…`、改区 695-706 = `bdbd6e2d…`（NEW 锁定块）、恢复臂 707-766 = `81258c7e…`、尾 766 起 = `c5229c53…`；总行数 991（净零线位移）。
- **计数门**：`useableItemUsed = true` 恰 2、旧 CD 提示行（`Useable item is in CD: `）0、旧 keep 注释 0、新 restoring 提示恰 1、承接行 `if loadingTable.useableItemUsed then` 恰 1、战斗守卫行仍 707。
- **语法门**：lua-5.0.3 `loadfile`（权威）+ 5.1.5 / 5.4.7 `loadfile` 全绿、bbcheck **BALANCED**、CRLF 0、新增行无 `#`/`goto`/`::`。
- **diff 卫生门**：恰 1 hunk、`git diff --check` clean、改动恰 entity/Player.lua 一个文件。
- **交付门**：恰 1 个 commit message 逐字对焊、`HEAD~1` = `db9edbd` 精确锚定、docs/ / SM_Extend.lua / core/selftest.lua / 261016-20c 目录零 diff、porcelain 等价门（恰为本 quick 目录一行 untracked）。

## Deviations from Plan

None — plan executed exactly as written：恰 1 次 Edit 逐字节采用编辑契约、恰 1 个 atomic commit（message 锁定文本）、全部门一次通过、零门编辑、零伪造绿。

## 实机验证（user-side unrun-verify，备案口径，与 261016-20c/Phase 27-30 先例一致）

用户 Windows+Cygwin 重建 SM_Extend.lua 后木桩验证：

- 装载宠物道具待其 CD，按释放键：打印 CD 提示后**同一按**恢复原装备（无 saying）。
- 道具可用时：第 1 下使用 + 喊 saying、第 2 下恢复原装备。

## Known Stubs

None.

## Self-Check: PASSED

- `entity/Player.lua` 已提交于 HEAD `f32705c`（`git show --stat --format= --name-only HEAD` = `entity/Player.lua`，message 逐字对焊；`git merge-base --is-ancestor f32705c HEAD` 成立）
- Task 1 两段 `<verify>`（提交前门 + 提交后门）全绿；Task 2 收口门全绿（SUMMARY 三关键词 + 零新增 commit + 零 tracked 改动 + porcelain 恰本目录一行）
- 本文件不产生 commit；docs 收口归 orchestrator Step 8
