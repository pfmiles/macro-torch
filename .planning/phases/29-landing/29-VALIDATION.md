---
phase: "29"
slug: "landing"
status: validated
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-10"
---

# Phase 29 — Validation Strategy

> Per-phase validation contract. Reconstructed from artifacts (State B) at execute:post Nyquist hook — no RESEARCH.md exists for this phase (research skipped by user at plan time; validation depth carried by CONTEXT D-15..D-17 selftest groups).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | In-game selftest (Lua, WoW 1.12 client) + static gates (bbcheck / grep battery) |
| **Config file** | none — selftest registry lives in `classes/druid/selftest.lua` (Q-01..Q-16) |
| **Quick run command** | `bbcheck <changed.lua>` + task-level grep assertion blocks (no headless lua interpreter on this machine) |
| **Full suite command** | user machine in-game `/mt` self-check (Q-01..Q-16 all green) — see `classes/druid/HUMAN-UAT.md` Phase 29 protocol |
| **Estimated runtime** | static battery ~seconds; in-game UAT ~10 min (weekly-CD paced) |

---

## Sampling Rate

- **After every task commit:** task `<verify>` + `<acceptance_criteria>` gates (executed by gsd-executor; all green through Waves 1-3)
- **After every plan wave:** post-merge test gate (no headless runner → stub-pass) + drift gates (schema-drift blocking, codebase-drift advisory)
- **Before `/gsd-verify-work`:** user-machine rebuild (SM_EXTEND.lua) + in-game `/mt` per HUMAN-UAT.md

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 29-01-01 | 01 | 1 | D-01 | — | 单行道删除经用户检查点裁决（option-a） | decision gate | checkpoint:decision + user ruling | ✅ | ✅ |
| 29-01-02 | 01 | 1 | D-02/D-04/D-05/D-06/D-07/D-09/D-10 | — | 统一 OR 证据核：dedup 谓词 / fail 否决窗 / ttl 贯通 | static | bbcheck + predicate-anchor grep (+`git diff --check`) | ✅ | ✅ |
| 29-01-03 | 01 | 1 | D-08/D-11/D-12 | — | FB 续期豁免入口 / Hunter ttl=2 | static | grep anchors (Renewal ×2 + intentTtl=2 ×2) | ✅ | ✅ |
| 29-01-04 | 01 | 1 | D-15 | — | Q-01/Q-02 基线重对齐 0.9 窗 | selftest | grep registry asserts (6 tracingSpells / TTL 0.9 / Q 总数) | ✅ | ✅ |
| 29-02-01 | 02 | 2 | D-03/D-13/D-14 | — | 反推兜底：静默窗触发 / 蓝色 (inferred) 通告 | static | 六步谓词链 grep（`blip <= ttl`=1 等） | ✅ | ✅ |
| 29-02-02 | 02 | 2 | D-04/D-16(part) | — | Q-09/Q-11/Q-13 行为断言 | selftest | BBALANCED + registry count regression | ✅ | ✅ |
| 29-03-01 | 03 | 3 | D-16 | — | Q-12/Q-14/Q-15/Q-16 边界用例 | selftest | registry count = 16 + verify 4 项 | ✅ | ✅ |
| 29-03-02 | 03 | 3 | D-17/D-18 | — | HUMAN-UAT.md 六节协议 / cpDamage 零改动声明 | doc | grep D-17/D-18 注记各 1 处 | ✅ | ✅ |
| 29-03-03 | 03 | 3 | all | — | 全阶段静态电池 10/10 | static | 残留清零 / 字节一致 / CJK·CRLF·注释门 | ✅ | ✅ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] No headless test framework exists or can execute this Lua addon — no stubs to install.
- Existing infrastructure (bbcheck + grep gates + in-game selftest registry) covers all phase requirements at the static level; the runtime layer is manual by design (below).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Q-01..Q-16 in-game execution (`/mt` self-check all green) | D-15/D-16 | No WoW client or lua interpreter on dev machine; selftest runs in-game only | Rebuild on Windows+Cygwin, `/mt` in game — see HUMAN-UAT.md §单人木桩/§多猫 |
| Multi-druid `(inferred)` fallback visible + ripLeft starts normally | D-03/D-13 | Requires live target with competing aura-apply suppression | HUMAN-UAT.md §多猫选做 |
| Hunter Serpent/Scorpid 2s ttl pairing at range | D-12/D-16 | Projectile flight-time behavior is real-machine only | HUMAN-UAT.md §猎人钉刺 |
| Remote inference anchor bias accepted (D-18) | D-18 | Design-locked acceptance of early-anchor form; observation-only | HUMAN-UAT.md D-18 note |
| SM_EXTEND.lua rebuild + CONFIG_OPTIONS banner | — | Build runs on user's Windows+Cygwin side by convention | HUMAN-UAT.md §Prerequisites |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify (static) or in-game selftest assertions — no unverified task
- [x] Sampling continuity: every task commit ran its verify gates green (29-01..29-03)
- [x] Wave 0 covers all MISSING references — no MISSING class exists; runtime items are manual by design
- [x] No watch-mode flags (no headless runner to watch)
- [ ] `nyquist_compliant: true` — NOT set: manual-only items above are design-mandated (in-game verification), resolved via HUMAN-UAT.md + weekly-CD pacing; per user ruling at Step 4 these are marked manual-only, not gaps

**Approval:** user (2026-09-10, Nyquist Step-4 gate: mark manual-only)