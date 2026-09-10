---
status: complete
phase: 29-landing
source: [29-VERIFICATION.md]
started: 2026-09-10T20:10:00Z
updated: 2026-09-10T18:14:08Z
---

## Current Test

[testing complete]

## Tests

### 1. Windows+Cygwin rebuild & login banner
expected: `./build.sh` 无报错；登录横幅 CONFIG_OPTIONS 仍 4 项（协议 HUMAN-UAT.md §1-2）
result: pass

### 2. In-game /mt self-check — Category Q-01..Q-16 all green
expected: 游戏内 `/mt` 自检 Category Q-01..Q-16 全绿、无红 FAIL（HUMAN-UAT.md §2）。这是 D-02（去重压制）、D-03（反推兜底）、D-04（fail 否决窗）、D-06（fail-wins 撤销）四条行为钉的闭环总入口
result: pass
note: 320 passed / 0 failed / 1 warnings — 黄色 warning 属协议可容忍项（§2：非 Q 可选项警告可容忍）

### 3. Single-dummy landing behavior
expected: 单人木桩：Rake/FB 恒绿 landed；Pounce/Rip 绿或偶发蓝 (inferred)；无红 failed-on；ripLeft 正常启动（§3）
result: issue
reported: "行为都符合预期，就是蓝色和绿色刚好搞反了：rake/bite全都是蓝色的landed, pounce和rip的inferred landed都是绿色的，没有红色"
severity: minor

### 4. Multi-druid same target (optional)
expected: 多猫同目标时 apply 被抑制 → ~1s 内蓝色 (inferred) 兜底 + ripLeft 启动、不再每帧重放；他人技能行不触发我方通告（§4）
result: pass

### 5. Hunter stings meeting range
expected: Serpent/Scorpid Sting 落地可见、远程位 ~2s 弹道窗内落地（§5）
result: pass

## Summary

total: 5
passed: 4
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-29-3
  truth: "单人木桩：绿色=landed、蓝色=inferred（HUMAN-UAT.md §247-248）；Rake/FB 恒绿 landed，Pounce/Rip 绿或偶发蓝 (inferred)"
  status: failed
  reason: "User reported: 行为都符合预期，就是蓝色和绿色刚好搞反了：rake/bite全都是蓝色的landed, pounce和rip的inferred landed都是绿色的，没有红色"
  severity: minor
  test: 3
  artifacts: []  # Filled by diagnosis
  missing: []    # Filled by diagnosis