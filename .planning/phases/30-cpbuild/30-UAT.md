---
status: testing
phase: 30-cpbuild
source: [30-VERIFICATION.md]
started: 2026-09-10T16:00:00Z
updated: 2026-09-10T16:00:00Z
---

## Current Test

number: 1
name: 游戏内 /mt 全绿（Windows+Cygwin rebuild 后，Category S-05..S-12 共 8 条全过、无红色 FAIL）
expected: |
  8 条 DKI stubbed 测试在 WoW 1.12 客户端内全部通过；登录横幅仍为 CONFIG_OPTIONS 4 项（本 phase 未增删配置项）
awaiting: user response

## Tests

### 1. 游戏内 /mt 全绿（Windows+Cygwin rebuild 后，Category S-05..S-12 共 8 条全过、无红色 FAIL）
expected: 8 条 DKI stubbed 测试在 WoW 1.12 客户端内全部通过；登录横幅仍为 CONFIG_OPTIONS 4 项（本 phase 未增删配置项）
result: [pending]

### 2. 目标态循环下实机采集（HUMAN-UAT Phase 30 part 3/4）：/run macroTorch.cpBuildLog=true 热开 → 打骷髅 → 观察聊天通道 [cpBuildT] ok t= 行与偶发 [cpBuildT] fail 行；随后 /run macroTorch.cpBuildLog=false 继续循环应无任何新 [cpBuild]/[cpBuildT] 行
expected: ok 行 cadence 大致等于窗口周期（一窗一样本）；fail 与 ok 之比即未达标率；开关关闭后零新行且帧表现无变化（D-01 零 API 路径）
result: [pending]

### 3. 战斗中途切换目标或脱战时不新增任何行（HUMAN-UAT part 3，D-04 bypass 2 实机路径）
expected: BUILDING 中切换目标 → 状态静默回 WAIT_ANCHOR、不写行；脱战同样；历史已落盘样本不经重置清空
result: [pending]

### 4. 用户 Windows+Cygwin 上 lua tools/cpbuild.lua --selftest 原机重跑 + 真实 SuperMacro 存档日志解码（HUMAN-UAT part 5）
expected: 输出 selftest: ALL 26 PASSED、exit 0；真实日志报告含 k 均值 + 六档直方图 + 断链计数 + T̄ + T 分布直方图 + 双档达标率 + ok/fail 窗口矩阵
result: [pending]

### 5. WINDOWS.md unrun-verify 账本条目闭环（rebuild、游戏内 selftest 零红线）
expected: 账本中 Phase 30 相关 unrun 条目逐项勾销
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps