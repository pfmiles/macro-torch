---
phase: 03-spell-trace
plan: 03
subsystem: events-integration + build-system
tags: [events, selftest, build-order]
requires: [03-01, 03-02]
provides: [03-04]
affects: []
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified:
    - core/events.lua
    - build_order.txt
decisions:
  - "SelfTest:run() 挂载在 onPlayerEnteringWorld() 之后，确保 Player/Target 实体已初始化"
  - "core/selftest.lua 移到 core/events.lua 之前，遵循函数定义先于调用方加载的原则 (Phase 2 D-05)"
metrics:
  duration: ""
  completed_date: "2026-06-08"
---

# Phase 03 Plan 03: SelfTest 事件挂载 + build_order 顺序修正 Summary

将 SelfTest 框架连接到事件系统，确保登录时自动运行基础设施健康检查，并修正 build_order.txt 中 selftest.lua 的加载顺序。

## Tasks Executed

### Task 1: events.lua 挂载 SelfTest:run()
- **File:** `core/events.lua` (line 52)
- **Change:** 将预留注释 `-- Phase 3: macroTorch.SelfTest:run()` 替换为实际调用 `macroTorch.SelfTest:run()`
- **Commit:** `da9a7aa`

### Task 2: 修正 build_order.txt 中 core/selftest.lua 顺序
- **File:** `build_order.txt` (line 24-25)
- **Change:** 将 `core/selftest.lua` 移到 `core/events.lua` 之前，确保函数定义先于调用方加载
- **Commit:** `97b7402`
- **Build verified:** `./build.sh` 成功，SM_Extend.lua 中包含 SelfTest:run 和 SelfTest:register 符号

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "SelfTest:run" core/events.lua` | 1 (exactly one call) |
| SelfTest:run() after onPlayerEnteringWorld() | YES (line 52 after line 51) |
| selftest.lua line < events.lua line in build_order.txt | YES (line 24 < line 25) |
| `./build.sh` success | YES |
| SelfTest symbols in SM_Extend.lua | YES (run + register) |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no new stubs introduced. The SelfTest:run() call is a real function invocation; the build_order.txt change is purely positional.

## Threat Flags

None — no new threat surfaces introduced. Existing mitigations remain: SelfTest:run() uses pcall isolation (T-03-05), build_order verified via grep and build.sh (T-03-06).

## Self-Check

- [x] core/events.lua modified with SelfTest:run() call — VERIFIED
- [x] build_order.txt reordered — VERIFIED
- [x] ./build.sh succeeds — VERIFIED
- [x] SM_Extend.lua contains SelfTest:run and SelfTest:register — VERIFIED
- [x] Both commits exist and are on the worktree branch — VERIFIED

## Self-Check: PASSED