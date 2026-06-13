---
phase: 05-druid-player-cast-druid
plan: 04
subsystem: Druid bear form combat
status: complete
tags:
  - bear
  - skill-methods
  - refactoring
  - safe-ready-deletion
requires:
  - 05-02
provides:
  - bear.lua updated to use mode-based skill method calls
affects:
  - classes/druid/bear.lua
tech-stack:
  added: []
  patterns:
    - mode-based skill method calls (nil='ready', 'safe', 'raw')
    - direct replace safe/ready wrappers with player.xxx(mode) calls
key-files:
  created: []
  modified:
    - classes/druid/bear.lua
decisions:
  - Deleted all 9 safe/ready wrapper functions (safeMaul, readyMaul, safeSavageBite, readySavageBite, readyGrowl, safeDemoralizingRoar, readyDemoralizingRoar, safeSwipe, readySwipe)
  - Replaced all 6 caller functions with mode-based skill method calls (bearOocMod, bearOtMod, bearDebuffMod, bearRegularAttack, bearAoe, bearReshiftMod)
  - bearFFMod unchanged -- calls safeFF from Druid.lua (not deleted, GCD checking stays external)
  - 'Savage Bite' in bear form uses player.ferocious_bite() (same spell name table covers both forms)
metrics:
  duration: 214
  completed_date: 2026-06-13
  task_count: 2
  file_count: 1
---

# Phase 05 Plan 04: Bear Form safe/ready 函数删除与方法替换

**One-liner:** 删除 bear.lua 中 9 个 safe/ready 包装函数，将 6 个调用者函数全部替换为基于 mode 参数的 skill method 调用。

## Summary

Plan 05-04 完成了 Druid 熊形态战斗模块的 `player.cast()` 替换工作。分两步执行：

1. **Task 1:** 删除 bear.lua 中全部 9 个 safe/ready 包装函数（行 2-48），包括 safeMaul/readyMaul、safeSavageBite/readySavageBite、readyGrowl、safeDemoralizingRoar/readyDemoralizingRoar、safeSwipe/readySwipe。

2. **Task 2:** 将 6 个调用者函数替换为 mode 参数的 skill method 调用：
   - `bearOocMod`: `player.ferocious_bite('ready')` -- ready 模式用于 ooc（不检查怒气消耗）
   - `bearOtMod`: `player.growl('ready')` + `player.ferocious_bite('safe')` -- safe 模式检查怒气
   - `bearDebuffMod`: `player.demoralizing_roar('safe')` -- safe 模式检查怒气
   - `bearRegularAttack`: `player.ferocious_bite('safe')` + `player.maul('safe')` -- 高怒气先 FB 泄怒，否则用 Maul
   - `bearAoe`: `player.swipe('safe')` -- safe 模式检查怒气
   - `bearReshiftMod`: `player.reshift('ready')` 替代 `player.cast('Reshift')`

`bearFFMod` 保持不变 -- 它调用 `macroTorch.safeFF(clickContext)`，该函数定义在 Druid.lua 中（包含自定义 GCD 检查逻辑，不被 `_castSpell` 覆盖）。

## Tasks Completed

| # | Task | Commit | Description |
|---|------|--------|-------------|
| 1 | Delete all 9 bear safe/ready wrapper functions | 4b948db | 删除 safeMaul/readyMaul/safeSavageBite/readySavageBite/readyGrowl/safeDemoralizingRoar/readyDemoralizingRoar/safeSwipe/readySwipe 共9个函数 |
| 2 | Replace all bear caller functions with mode-based calls | d8ef1fd | 更新 6 个调用者函数，全部使用 `player.xxx(mode)` 形式，0 处 `player.cast()` 残留 |

## Verification Results

| Check | Expected | Actual | Pass |
|-------|----------|--------|------|
| `player.cast()` in bear.lua | 0 | 0 | Yes |
| Deleted function references | 0 | 0 | Yes |
| Skill method calls | >= 6 | 8 | Yes |
| `./build.sh` exit code | 0 | 0 | Yes |

## Deviations from Plan

None - plan executed exactly as written.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: tampering | classes/druid/bear.lua | 'Savage Bite' spell name -- uses `player.ferocious_bite()` with `{en='Ferocious Bite',zh='凶猛撕咬'}` locale table. Per RESEARCH.md line 676 assumption this is the same spell covering both cat and bear forms. If wrong in-game on enUS client, spell cast will fail silently (return false). Mitigation: add separate `savage_bite` skill method with correct spell name. |

## Known Stubs

None -- all call sites are fully wired to existing skill methods in Druid.lua (added in Plan 05-02).

## Self-Check: PASSED

- `classes/druid/bear.lua` -- FOUND
- Commit `4b948db` -- FOUND
- Commit `d8ef1fd` -- FOUND
- Build `./build.sh` -- exits 0