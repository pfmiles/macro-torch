---
status: testing
phase: 26-phase-fast
source: [26-VERIFICATION.md]
started: 2026-08-22T00:00:00Z
updated: 2026-08-22T00:00:00Z
---

## Current Test

number: 1
name: P-06 行为回归 + 快速战斗状态转移（D-08 cp5Bite 5CP 触发）
expected: |
  游戏内运行 `/mt` 自检，Category P 六条全部通过（无红字）。
  攻击弱怪（8.5s 内死亡），无 Rake/Rip 无流血免疫，攒满 5 星时触发 Bite。
awaiting: user response

## Tests

### 1. P-06 行为回归 + 快速战斗状态转移（D-08 cp5Bite 5CP 触发）
expected: /mt 自检 Category P 全绿；5CP 快速战斗中 Bite 触发（cp5Bite 经新增 `or isFastBattleNotPvp` 分支 → safeBite/readyBite）
result: [pending]

### 2. P-02 SelfTest 影子字段副作用（Warning）
expected: 运行 /mt 后选中 PvP 玩家目标，isFastBattleNotPvp 立即返回 false（PvP 排除正常）；若行为异常需将恢复改为 `macroTorch.target.isPlayerControlled = nil`
result: [pending]

### 3. fast ⇄ normal 逐帧切换
expected: 对中等血量 mob 开战，血量降至/升回 8.5s 死亡预测线时，下一帧行为正确切换（fast→直伤无流血，normal→keepRip/keepRake 恢复），无粘滞无死锁
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps