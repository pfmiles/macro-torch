---
phase: "30"
slug: "cpbuild"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: false
wave_0_complete: true
created: "2026-09-10"
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Reconstructed by validate-phase (State B) from executed PLAN/SUMMARY artifacts; runtime-deferred items marked Manual-Only by user decision (2026-09-10).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | In-game stubbed selftest battery (`classes/druid/selftest.lua`) + offline analyzer selftest (`tools/cpbuild.lua --selftest`) |
| **Config file** | none — batteries follow project CR-01 stub discipline |
| **Quick run command** | `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js <file>` + `git diff --check` (static, this host) |
| **Full suite command** | `lua tools/cpbuild.lua --selftest` (verified via LuaJIT on this host; Lua 5.0-native on user's Windows+Cygwin box) + in-game `selftest.lua` battery (user box only) |
| **Estimated runtime** | ~5 s (static), ~10 s (cpbuild selftest) |

---

## Sampling Rate

- **After every task commit:** bbcheck BALANCED + `git diff --check` + Lua 5.0 glyph gates (both executors observed this per-task)
- **After every plan wave:** plan-level `<verification>` battery re-run (observed: 30-01, 30-03, 30-02 all re-ran full batteries)
- **Before `/gsd-verify-work`:** user-side full suite must be green (HUMAN-UAT Phase 30)
- **Max feedback latency:** ~5 s static; analyzer suite ~10 s; in-game battery user-paced

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 30-01-01 | 01 | 1 | D-01/D-04/D-05/D-06 (DKI block) | T-01 / — | D-01 zero-API gate when switch off; no bite line (D-03) | static + stubbed | bbcheck, 8 anchors, API census, registerPeriodicTask count, Lua 5.0 gates | ✅ | ✅ green (runtime semantics manual) |
| 30-01-02 | 01 | 1 | D-04 bypass-2 (reset wiring) | T-01 / — | reset in both existing hooks, RegisterEvent surface frozen at 20 | static | region/count greps, RegisterEvent token count, bbcheck | ✅ | ✅ green |
| 30-02-01 | 02 | 2 | D-04 six transitions + D-01 gate (S-05..S-12) | T-01 / — | CR-01 restore-before-assert discipline | stubbed unit (in-game) | 8-title, 7×8 restore literals (diff-scoped), restore order script, bbcheck, diff --check | ✅ | ✅ green static; runtime green pending user box (manual) |
| 30-02-02 | 02 | 2 | D-09/D-14 (HUMAN-UAT protocol) | T-01 / — | target-state-loop precondition recorded | manual_procedural | anchor gate battery | ✅ | ✅ green static; `manual_procedural` |
| 30-03-01 | 03 | 1 | D-07 harness copy + parser | T-01 / — | cpdamage.lua byte-untouched | other | cpdamage zero-diff gate, luaparser full parse | ✅ | ✅ green |
| 30-03-02 | 03 | 1 | D-08 k/T statistics | T-01 / — | BREAK_THRESHOLD chain-break, fail windows in pass-rate denominator | other | 26-check selftest sub-battery | ✅ | ✅ green |
| 30-03-03 | 03 | 1 | D-08 report + JSON + CLI | T-01 / — | dual pass rates d-1 / 0.9d-1 | e2e | `lua tools/cpbuild.lua --selftest` + synthetic-SavedVariables full chain (LuaJIT) | ✅ | ✅ green (5.0-native rerun manual) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all automatable phase requirements: static gates (bbcheck/diff --check/anchors) ran per task on this host; the analyzer battery ran green under LuaJIT here. No wave-0 stubs to produce.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DKI 状态机运行时语义：锚点→满星 ok 行、截断 fail 行、全局重置丢弃、开关关闭零 API（S-05..S-12 执行） | D-01, D-04 | WoW 1.12 客户端容器无法在本 Linux 机执行；测试已编写并静态全绿 | 用户 Windows+Cygwin：rebuild → 游戏内跑 selftest 电池（`/run` 入口，HUMAN-UAT Phase 30 part 3） |
| 目标态循环下 `[cpBuildT] ok/fail` 行观察 + cpBuildLog 开关热切换 | D-06, D-09 | 实机行为观察；D-09 前置要求先切换目标态循环（现行循环每窗口硬打 Rake 会低估 T̄） | HUMAN-UAT Phase 30 part 4（`/run macroTorch.cpBuildLog=true` → 打木桩 → 观察 MACRO_TORCH_LOG） |
| `lua tools/cpbuild.lua --selftest` 原生 Lua 5.0 重跑 + 真实日志解码 | D-07, D-08, D-10 | LuaJIT(5.1) 已绿（本机），非 5.0-native 证明；真实日志主路径依赖实机采集 | HUMAN-UAT Phase 30 part 5 |
| WINDOWS.md unrun-verify 条目闭环（rebuild、游戏内 selftest 零红线） | D-14 | 用户实机唯一可执行环境 | 按 `climate/WINDOWS.md` 账本条目逐项核对 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or static battery coverage
- [x] Sampling continuity: 每任务都有静态电池（无 3 任务连续无验证）
- [x] Wave 0 covers all MISSING references (无 MISSING；剩余为设计内延后项)
- [x] No watch-mode flags (分析器为一次性 CLI)
- [x] Feedback latency < 1 min 静态 / < 1 min 分析器
- [ ] `nyquist_compliant: true` set in frontmatter — **false**：4 项 Manual-Only（用户 2026-09-10 决策「标记 manual-only」；运行时语义 pin 待 HUMAN-UAT 实机转绿后可由 audit-milestone 复核）

**Approval:** pending