---
status: testing
phase: 29-landing
source: [29-VERIFICATION.md]
started: 2026-09-10T20:10:00Z
updated: 2026-09-10T20:10:00Z
---

## Current Test

number: 1
name: Windows+Cygwin rebuild & login banner
expected: |
  在用户机 Windows+Cygwin 侧执行重建（./build.sh 无报错）；登录后横幅 CONFIG_OPTIONS 仍显示 4 项。SM_EXTEND.lua 为 build 产物，本次 Phase 29 源码未触碰它（逐字节等于 HEAD 已机器验证）。
awaiting: user response

## Tests

### 1. Windows+Cygwin rebuild & login banner
expected: `./build.sh` 无报错；登录横幅 CONFIG_OPTIONS 仍 4 项（协议 HUMAN-UAT.md §1-2）
result: [pending]

### 2. In-game /mt self-check — Category Q-01..Q-16 all green
expected: 游戏内 `/mt` 自检 Category Q-01..Q-16 全绿、无红 FAIL（HUMAN-UAT.md §2）。这是 D-02（去重压制）、D-03（反推兜底）、D-04（fail 否决窗）、D-06（fail-wins 撤销）四条行为钉的闭环总入口
result: [pending]

### 3. Single-dummy landing behavior
expected: 单人木桩：Rake/FB 恒绿 landed；Pounce/Rip 绿或偶发蓝 (inferred)；无红 failed-on；ripLeft 正常启动（§3）
result: [pending]

### 4. Multi-druid same target (optional)
expected: 多猫同目标时 apply 被抑制 → ~1s 内蓝色 (inferred) 兜底 + ripLeft 启动、不再每帧重放；他人技能行不触发我方通告（§4）
result: [pending]

### 5. Hunter stings meeting range
expected: Serpent/Scorpid Sting 落地可见、远程位 ~2s 弹道窗内落地（§5）
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps