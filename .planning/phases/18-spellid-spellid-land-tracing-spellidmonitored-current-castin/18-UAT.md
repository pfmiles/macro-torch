---
status: testing
phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin
source: [18-VERIFICATION.md]
started: 2026-07-04T12:30:00Z
updated: 2026-07-04T12:30:00Z
---

## Current Test

number: 1
name: /mt Self-Test Run — Category L all pass
expected: |
  Selftest 汇总显示 Category L 全部5项（L1-L5）均应 PASS（包括 L4 — monitorSpellId=true+land=false 路径）。
  Category K 全部 PASS（无回归）。
awaiting: user response

## Tests

### 1. /mt Self-Test Run — Category L all pass
expected: Selftest 汇总显示 Category L 全部5项（L1-L5）均应 PASS。Category K 全部 PASS（无回归）。
result: [pending]

### 2. SpellId Correction Pipeline — SuperWow 下施放白名单技能
expected: UNIT_CASTEVENT 触发时，若客户端 spellId 与静态映射不一致，聊天框中出现 '[macro-torch] spellId corrected: ...' 黄色日志
result: [pending]

### 3. Non-Whitelist Pollution Prevention — 施放非白名单技能
expected: FF(Feral)、Healing Touch 等非白名单技能不会设置 current_casting_spell，也不会触发 stale 检测 warning
result: [pending]

### 4. Non-SuperWow Stale Warning Level (Optional)
expected: 每次施放白名单技能出现 stale yellow warning。确认噪音水平可接受。
result: [pending]

### 5. Stale Detection State Transition
expected: 残留 current_casting_spell 时再施放白名单技能，出现黄色 warning: "current_casting_spell was not cleared: ... , now overwritten by: ..."
result: [pending]

### 6. Whitelist-Gated SpellId Correction
expected: Rake 触发 spellId 比较（staticSpellId vs event spellId），FF(Feral) 不触发
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps