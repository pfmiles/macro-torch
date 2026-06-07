---
status: partial
phase: 01-classmetatable-entity
source: [01-VERIFICATION.md]
started: 2026-06-08T02:50:00Z
updated: 2026-06-08T02:50:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Druid 登录获取 Druid 实例
expected: `macroTorch.player` 是 Druid 实例，可访问 `comboPoints`, `isOoc`, `isProwling` 等字段
result: [pending]

### 2. 非 Druid 登录 fallback
expected: `macroTorch.player` 是 Player 实例（因 PLAYER_CLASS_REGISTRY 中未注册当前职业，fallback 到 Player:new()）
result: [pending]

### 3. 周期性任务调度
expected: `macroTorch.onPeriodicUpdate` 通过 core/periodic.lua 的独立 OnUpdate Frame 正常运行；周期性任务以设置的时间间隔执行，无报错
result: [pending]

### 4. classMetatable 字段解析链
expected: `druid.health` 遍历完整分层 __index 链（DRUID_FIELD_FUNC_MAP → Druid → PLAYER_FIELD_FUNC_MAP → Player → UNIT_FIELD_FUNC_MAP → Unit）返回正确值
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps