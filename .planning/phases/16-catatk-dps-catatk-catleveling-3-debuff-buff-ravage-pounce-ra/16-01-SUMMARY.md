---
phase: 16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra
plan: 01
subsystem: druid/leveling
tags: [druid, cat-form, leveling, macro, refactor]
requires: []
provides: [catLeveling-function]
affects: []
tech-stack:
  added: []
  patterns: [inline-modules, clickContext-snapshot, isSpellExist-guard]
key-files:
  created: []
  modified: [classes/druid/leveling.lua]
decisions:
  - "catLeveling 不接受 rough 参数 — 所有战斗按正常模式处理"
  - "不计算 ERPS/reshift/relic — 练级阶段不需要这些 endgame 优化"
  - "内联简化 FF 穿插（能量低于 Claw 消耗即填充）和 Shred vs Claw（仅背后+未失败）"
  - "isSpellExist guard 覆盖所有 8 个技能调用点"
duration: 141
completed: 2026-06-22T16:25:17Z
status: complete
---

# Phase 16 Plan 01: catLeveling 练级版一键宏实现

将 `classes/druid/leveling.lua` 从 77 行骨架代码重构为 210 行完整的 `catLeveling()` 一键宏实现，独立于 `catAtk`，不共享任何 rough/ERPS/reshift/relic 逻辑。

## Completed Tasks

| # | Type | Name | Commit | Status |
|---|------|------|--------|--------|
| 1 | feature | 重构 leveling.lua — 实现完整的 catLeveling() 一键宏 | 7ef37a1 | done |

## Execution Summary

- **单任务执行，无检查点** — 模式 A（全自动）
- **构建验证通过**: `./build.sh && echo Build OK`
- **所有验收标准满足**: isSpellExist >= 7, 无 level < 分支, 无 ERPS/reshift/relic, 无 rough 参数

## Implementation Details

### catLeveling() 函数结构（9 个模块按优先级执行）

| 优先级 | 模块 | 关键判定 | 使用的 shared helper |
|--------|------|---------|---------------------|
| 0 | 守卫 | 非猫形态/目标不可攻击 → return | — |
| 1 | 起手技 | Prowling → Pounce（非快速+可用+非免疫+血量>=阈值）/ Ravage | isTrivialBattleOrPvp, getOpenerHealthThreshold |
| 2 | 自动攻击 | 战斗中（非潜行）→ startAutoAtk | — |
| 3 | 斩杀 | isKillShotOrLastChance + CP>0 → ferocious_bite('raw') | isKillShotOrLastChance |
| 4 | 猛虎之怒 | 无 TF + 距离<=20 + selfGCD==0 + 能量够 → tigers_fury | isTigerPresent, tigerSelfGCD |
| 5 | Rip | shouldCastRip + GCD OK + 近战距离 → rip | shouldCastRip, isGcdOk, isNearBy |
| 6 | Rake | 无 Rake 存在 + 非免疫 + GCD OK + CP<5 → rake | isRakePresent, isGcdOk, isNearBy |
| 7 | 精灵之火(野性) | 非 OOC + 非免疫 + isSpellReady + GCD OK + 能量<Claw消耗 → FF | isGcdOk |
| 8 | Bite | OOC+CP>0 → bite('ready'); 否则 shouldUseBite+能量够 → bite | shouldUseBite |
| 9 | 攒星 | 战斗中 CP<5 → Shred(背后+能量够) / Claw(能量够); OOC时可无视能量 | isFightStarted |

### clickContext 字段清单（无 rough/ERPS/reshift/relic）

- 能量消耗: `POUNCE_E=50`, `CLAW_E`, `SHRED_E`, `RAKE_E`, `BITE_E=35`, `RIP_E=30`, `TIGER_E`
- 持续时间: `TIGER_DURATION`
- 状态快照: `prowling`, `comboPoints`, `ooc`, `isBehind`
- 免疫标记: `isImmuneRake`, `isImmuneRip`

### 明确排除

- 不设置: `rough`, `AUTO_TICK_ERPS`, `TIGER_ERPS`, `RAKE_ERPS`, `RIP_ERPS`, `POUNCE_ERPS`, `BERSERK_ERPS`, `hasEssenceOfTheRed`, `RESHIFT_ENERGY`, `normalRelic`, `FF_DURATION`
- 不调用: `computeErps`, `shouldUseShred`, `shouldCastFFDuringWaitWindow`, `shouldDoReshift`, `computeReshiftEnergy`, `getMinimumAffordableAbilityCost`
- 不调用: `computeNormalRelic`, `recoverNormalRelic`, `dischargeEnergyChangeRelic` 等任何 idol 函数
- 不调用: `keepRip`, `keepRake`, `keepTigerFury`, `keepFF`, `regularAttack` 等 catAtk 模块

## Acceptance Criteria Results

| Criteria | Expected | Actual | Status |
|----------|----------|--------|--------|
| `function macroTorch.catLeveling()` count | == 1 | 1 | PASS |
| `isSpellExist` count | >= 7 | 12 | PASS |
| `if level <` count | == 0 | 0 | PASS |
| ERPS/reshift-related function calls | == 0 | 0 (non-comment) | PASS |
| ERPS field references | == 0 | 0 | PASS |
| Idol/relic function calls | == 0 | 0 | PASS |
| catAtk module calls | == 0 | 0 | PASS |
| Player skill method calls | >= 4 | 6 | PASS |
| `./build.sh` | OK | OK | PASS |

## Deviations from Plan

无 — 计划完全按书中执行。

## Self-Check: PASSED

- [x] `classes/druid/leveling.lua` exists and is 210 lines
- [x] Commit `7ef37a1` exists in git history
- [x] `./build.sh` passes with exit code 0
- [x] All acceptance criteria verified via grep