---
phase: 16-catatk-dps-catatk-catleveling-3-debuff-buff-ravage-pounce-ra
plan: 02
subsystem: druid/leveling/selftest
tags: [druid, cat-form, leveling, selftest, testing]
requires:
  - 16-01
provides: [catLeveling-selftest]
affects: []
tech-stack:
  added: []
  patterns: [self-test-registration, UnitClass-guard, pcall-isolation]
key-files:
  created: []
  modified: [core/selftest.lua]
decisions:
  - "Category J 测试使用 UnitClass guard — 非 Druid 职业登录时安全跳过"
  - "测试2 (共享函数引用) 和 测试4 (catAtk 不变性) 标记为 isOptional=false 作为核心测试"
  - "不检查 shouldUseShred 和 shouldCastFFDuringWaitWindow — catLeveling 不调用它们"
  - "测试5 只类型验证 computeErps 存在但不追踪引用 — pcall(catLeveling) 成功即验证无依赖"
duration: 87
completed: 2026-06-22T16:31:18Z
status: complete
---

# Phase 16 Plan 02: catLeveling Selftest 自动化测试

为 catLeveling() 函数添加 5 条 SelfTest 注册到 core/selftest.lua，验证函数存在性、共享判定函数引用完整性、点击上下文正确性、catAtk 不变性、以及无 ERPS/reshift 依赖。

## Completed Tasks

| # | Type | Name | Commit | Status |
|---|------|------|--------|--------|
| 1 | feat | 添加 5 条 catLeveling SelfTest 注册 (Category J) | 9798da5 | done |

## Execution Summary

- **模式 A（全自动）** — 单任务、无检查点
- **构建验证通过**: `./build.sh && echo Build OK`
- **所有验收标准满足**: grep -c '"J: ' == 5, isOptional=false == 2 条核心测试, isOptional=true == 3 条可选测试, 无 shouldUseShred/shouldCastFFDuringWaitWindow 引用, 非 Druid 安全跳过

## Implementation Details

### 5 条 Category J SelfTest 注册

| 测试名称 | isOptional | 说明 |
|---------|-----------|------|
| J: catLeveling function exists and is callable | true | 验证 catLeveling 全局函数存在 |
| J: shared decision functions remain accessible (no local redefinition) | **false** | 验证 isKillShotOrLastChance/shouldCastRip/shouldUseBite 全局引用未受覆盖 |
| J: catLeveling invocation does not error (clickContext correctness) | true | pcall 验证 catLeveling 调用不报错 |
| J: catAtk remains unmodified (Phase 16 does not change catAtk) | **false** | 验证 catAtk 全局函数未被修改 |
| J: catLeveling has no ERPS/reshift dependency | true | 验证 computeErps 全局存在 + pcall(catLeveling) 成功 |

### 设计要点

- 所有 Cat J 测试通过 `UnitClass('player') ~= 'Druid'` 守卫 — 非 Druid 登录时安全跳过
- 核心测试 (isOptional=false) 覆盖关键不变量：共享函数引用 + catAtk 不变性
- 可选测试 (isOptional=true) 覆盖功能验证：函数存在 + 调用无错 + 无 ERPS 依赖
- 插入位置：Category F 最后一个注册之后（line 568），`/mt SLASH command` 注释块之前
- 不检查 shouldUseShred/shouldCastFFDuringWaitWindow — 这些函数内部调用 computeErps，catLeveling 不使用

## Acceptance Criteria Results

| Criteria | Expected | Actual | Status |
|----------|----------|--------|--------|
| grep -c '"J: ' core/selftest.lua | == 5 | 5 | PASS |
| isOptional=false count | == 2 | 2 | PASS |
| isOptional=true count | == 3 | 3 | PASS |
| J 注册在 /mt SLASH 之前 | yes | yes (line 570 vs 612) | PASS |
| shouldUseShred/shouldCastFFDuringWaitWindow refs | == 0 | 0 | PASS |
| ./build.sh | OK | OK | PASS |

## Deviations from Plan

无 — 计划完全按书中执行。

## Self-Check: PASSED

- [x] `core/selftest.lua` contains 5 registrations with "J: " prefix
- [x] Commit `9798da5` exists in git history
- [x] `./build.sh` passes with exit code 0
- [x] All acceptance criteria verified via grep and awk