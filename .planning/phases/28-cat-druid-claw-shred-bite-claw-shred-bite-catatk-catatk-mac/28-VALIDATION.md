---
phase: "28"
slug: "cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
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
| 28-02 | 28-01/02 | 1-2 | D-06 | — | N/A | static + selftest | `grep -c "cpDamageLog" macro_torch.lua` ≥ 2；Category U 9/9（用户实机确认 2026-09-13） | ✅ | ✅ green |
| 28-02 | 28-02/03 | 2 | D-07/D-12 | T-28-05 | 前缀精确匹配 + decode 成功双门槛 | unit（纯 Lua） | Cat U 编码断言 + analyzer `--selftest` 35/35（含 G-28-5 后新增 encodeKey 断言，5.0/5.1/5.4 三解释器） | ✅ | ✅ green |
| 28-01 | 28-01 | 1 | D-01 | T-28-01 | SELF_DAMAGE 通道白名单 + `hits\|crits … for N.` 句式门 | static + live UAT | bbcheck + 实机 UAT（941 条 11 字段条目、0 坏行） | ✅ | ✅ green |
| 28-01 | 28-01 | 1 | D-02 | — | N/A | static | bbcheck + grep TTL=2 复用 | ✅ | ✅ green |
| 28-01 | 28-01 | 1 | D-11 | — | N/A | static | grep `_cpDamageBatch` in combat_context.lua（:39 锚） | ✅ | ✅ green |
| 28-03 | 28-03 | 2 | D-17~D-21 | T-28-02/04 | 解码器 pcall 包裹坏行跳过；条数上限截断 | analyzer selftest | `lua tools/cpdamage.lua --selftest` 三解释器全绿；真实 SV 输入双层报表 UAT 4 通过 | ✅ | ✅ green |
| 28-04 | 28-04 | 2 | R8 | — | 既有 catAtk 逻辑零改动 | regression | `git diff` 范围审计 + SM_Extend.lua 既有符号 grep 不变；屏显字节级不变（quick 260913-2wo 实证） | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tools/cpdamage.lua` — 分析器本体 + `--selftest` 内置 fixture（35 项断言，5.0.3/5.1.5/5.4.7 三解释器绿）
- [x] `classes/druid/selftest.lua` Category U 注册段（U-01..U-09，用户实机确认 9/9，2026-09-13）
- [x] 游戏内 JSON 编码器单元断言（Cat U 内纯函数断言，含发射逐字 JSON 断言）
- [x] 验证电池命令复制进各 plan verify 段（bbcheck 路径、grep 期望数——28-VERIFICATION.md 各锚点行已实跑）

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions | Resolution |
|----------|-------------|------------|-------------------|------------|
| 实机打桩→落盘→分析闭环 | D-01/D-05/D-08 | 游戏客户端无法在本构建机运行；真实伤害 roll 需实机 | 用户机 UAT：`/run macroTorch.cpDamageLog=true` 打木桩 1 分钟 → repload → `lua tools/cpdamage.lua <SuperMacro.lua 路径>` 出表 → `--selftest` 于 5.0 与 5.4 解释器各跑一次 | ✅ 已闭环 2026-09-13：941 条样本（claw 486/shred 244/bite 211）、双层报表、UAT 3/4 通过 |
| SavedVariables 变体人工确认 | D-14 | workspace 两份 SuperMacro toc 仅 paw 版声明 `MACRO_TORCH_LOG`，实际注册形态依赖用户实机文件 | 用户实机确认 WTF SavedVariables 中 `MACRO_TORCH_LOG` 段存在；无则该 ext 环境下打点开关位为 MISSING（见 RESEARCH Assumptions Log） | ✅ 已闭环 2026-09-13：用户导出 SavedVariables messages 数组（cpDmgLog.txt），段持久化实证（UAT 1 通过） |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-09-13（UAT 5/5 + analyzer 三解释器 35/35 + quick 260913-2wo G-28-5 闭合）

---

## Validation Audit 2026-09-13

| Metric | Count |
|--------|-------|
| Gaps found | 0（Wave 0 四条腿全部落地且当日复绿） |
| Resolved | 2 manual-only items（实机闭环 + SavedVariables 变体） |
| Escalated | 0 |