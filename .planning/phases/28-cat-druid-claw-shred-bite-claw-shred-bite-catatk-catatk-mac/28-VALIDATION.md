---
phase: "28"
slug: "cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-08"
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | 无传统测试框架 — 四条腿：① `node bbcheck.js`（bracket 平衡静态门，本机可用）② `./build.sh` 汇编完整性 ③ 游戏内 SelfTest 注册（Category U，最高现有字母 T 的下一位）④ `tools/cpdamage.lua --selftest` 内置断言（用户机跑） |
| **Config file** | none（脚本直接跑；SelfTest 复用 `core/selftest.lua` 框架） |
| **Quick run command** | `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js <changed .lua files>` |
| **Full suite command** | `./build.sh && node .../bbcheck.js <all touched> && git diff --check && <grep 断言组>`（本机无 lua 解释器；`tools/cpdamage.lua` 运行级验证在用户机执行） |
| **Estimated runtime** | ~30 秒（不含用户机 UAT） |

---

## Sampling Rate

- **After every task commit:** 跑该任务触及文件的 `bbcheck.js` + `git diff --check`
- **After every plan wave:** `./build.sh`（exit 0）+ 全触及文件 bbcheck + grep 断言组 + SelfTest 注册计数
- **Before `/gsd-verify-work`:** 全电池绿 + 用户机 UAT（打桩 1 分钟 + analyzer 出表 + `--selftest` 两种解释器各跑一次）
- **Max feedback latency:** ~60 秒（bbcheck + build 均为秒级；用户机 UAT 为 phase 门级一次）

---

## Per-Task Verification Map

（无正式 REQ ID — ROADMAP Requirements: TBD。锚定 D-xx 决策；Task ID 于 PLAN 生成后回填。）

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | D-06 | — | N/A | static + selftest | `grep -c "cpDamageLog" macro_torch.lua` ≥ 2；Category U 注册 | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-07/D-12 | T-28-05 | 前缀精确匹配 + decode 成功双门槛 | unit（纯 Lua） | Cat U 编码断言 + analyzer `--selftest` 往返 fixture | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-01 | T-28-01 | SELF_DAMAGE 通道白名单 + `hits\|crits … for N.` 句式门 | static | bbcheck + 实机 UAT 打桩 | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-02 | — | N/A | static | bbcheck + grep TTL=2 复用 | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-11 | — | N/A | static | grep `_cpDamageBatch` in combat_context.lua | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-17~D-21 | T-28-02/04 | 解码器 pcall 包裹坏行跳过；条数上限截断 | analyzer selftest | `lua tools/cpdamage.lua --selftest`（用户机） | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | R8 | — | 既有 catAtk 逻辑零改动 | regression | `git diff` 范围审计 + SM_Extend.lua 既有符号 grep 不变 | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tools/cpdamage.lua` — 分析器本体 + `--selftest` 内置 fixture（最粗空缺）
- [ ] `classes/druid/selftest.lua` Category U 注册段（随 Phase 23/27 传统）
- [ ] 游戏内 JSON 编码器单元断言（Cat U 内纯函数断言，无需独立框架）
- [ ] 验证电池命令复制进各 plan verify 段（bbcheck 路径、grep 期望数）

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 实机打桩→落盘→分析闭环 | D-01/D-05/D-08 | 游戏客户端无法在本构建机运行；真实伤害 roll 需实机 | 用户机 UAT：`/run macroTorch.cpDamageLog=true` 打木桩 1 分钟 → repload → `lua tools/cpdamage.lua <SuperMacro.lua 路径>` 出表 → `--selftest` 于 5.0 与 5.4 解释器各跑一次 |
| SavedVariables 变体人工确认 | D-14 | workspace 两份 SuperMacro toc 仅 paw 版声明 `MACRO_TORCH_LOG`，实际注册形态依赖用户实机文件 | 用户实机确认 WTF SavedVariables 中 `MACRO_TORCH_LOG` 段存在；无则该 ext 环境下打点开关位为 MISSING（见 RESEARCH Assumptions Log） |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending