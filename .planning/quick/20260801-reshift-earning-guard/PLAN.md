# reshift earning guard

**Date:** 2026-08-01
**Type:** bugfix

## Problem

`shouldDoReshift` 只检查 "等 1.5s 够不够"（`projectedEnergy < nextAbilityCost`），没有检查 "reshift 是否比等更划算"。

Reshift 会抹除猛虎之怒，需立即瞬补。有效能量 = `RESHIFT_ENERGY - TIGER_E`（猛虎存在时）。
两条路径在 1.5s 内 erps 回能相同（抵消），净收益 = `effectiveEnergy - currentEnergy`。

当 `effectiveEnergy <= currentEnergy`（earning <= 0）时，reshift 不仅不解决问题，反而让能量倒退。
这在非 BiS 配置（如 Furor 5 无狼心：有效能量仅 10）下触发。

## Changes

### 1. `classes/druid/cat.lua` — `shouldDoReshift`
- 新增 `effectiveEnergy` 计算（扣除猛虎消耗）
- return 增加 `effectiveEnergy > currentEnergy` 条件
- 新增 reshift economics 注释

### 2. `classes/druid/Druid.lua` — 三处注释
- `getNextAbilityCost`: 注明返回值不含猛虎，变身场景调用方需自行扣除
- `computeReshiftEnergy`: 注明返回原始值，猛虎扣除由调用方处理
- `tigerSelfGCD`: 澄清是内置 CD 而非全局 GCD

### 3. `classes/druid/selftest.lua` — 测试更新
- R2-07: RESHIFT_ENERGY 40→60，增加 earning guard skip
- R2-08: 新增 earning <= 0 时不应 reshift 的测试