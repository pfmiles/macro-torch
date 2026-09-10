---
phase: 30-cpbuild
fixed_at: 2026-09-10T16:40:29Z
review_path: .planning/phases/30-cpbuild/30-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 30: Code Review Fix Report

**Fixed at:** 2026-09-10T16:40:29Z
**Source review:** `.planning/phases/30-cpbuild/30-REVIEW.md` (iteration 2)
**Iteration:** 1
**Scope:** critical_warning — WR-01 / WR-02 / WR-03（Info 4 条不在范围内）

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Adjudication Table

| ID | Adjudication | Action | Commit / Reason | Evidence (one line) |
|----|--------------|--------|-----------------|---------------------|
| WR-01 | by-design | fixed (docs only) | `e34c510` | D-04/D-03 lock the mechanical cp down-jump anchor (no finisher discriminator by contract); D-09 target-state loop is the designated data-validity safeguard — pollution only occurs when the user violates D-09, so the fix is the mandated documentation strengthening, not a protocol change. |
| WR-02 | real | fixed (docs only) | `5f03a82` | `[cpBuild]` needs `cpLog.gcdOk` (Druid.lua:349 Rake probe) while `[cpBuildT]` reads only `GetComboPoints()` (Druid.lua:408-472) — line 317 falsely attributed the GCD probe to `[cpBuildT]`; troubleshooting split into dual-channel checks. |
| WR-03 | real | fixed | `7f85576` | Bare `macroTorch.resetCpBuildDki()` at both reset hooks would nil-call error if Druid.lua ever skipped loading, cascading into pre-existing branch logic; added free `if macroTorch.resetCpBuildDki then` guards that are always true on the normal path (zero behavior change). |

## Fixed Issues

### WR-01: DKI 下跳谓词把一切连击点终结技当作咬击锚

**Adjudication:** by-design under the phase contract。30-CONTEXT.md D-04 明确锁定锚点为"从 >1 下跳至 ≤1"的纯 cp 检测，D-03 规定 bite 锚点由 DKI 下跳提供（不记录 bite 行、无终结技种别判别）；D-09 的目标态循环前置是协议唯一的数据有效性保护。增加终结技判别器 = 修改封版协议 → 被禁止（用户条件：协议锁定面不做协议变更）。

**Files modified:** `classes/druid/HUMAN-UAT.md`
**Commit:** `e34c510`
**Applied fix (documentation only, per mandate):**
1. Phase 30 第 3 节新增一行：采集全程终结技仅限 5 星 Ferocious Bite 与目标态下的斩杀咬，禁止 Rip / 非 5 星咬（违者弃档重采），并注明原因是 DKI 锚点是纯 cp 下跳（D-04）、Rip 下跳经活体背查会伪锚污染窗口（D-09 前置的细化）。
2. 第 6 节新增排查条：fail 占比异常偏高且 ok 明显偏短 → 自查是否中途打过 Rip 或目标被流血跳死。

### WR-02: HUMAN-UAT 排障条目把 GCD 探针要求错误归因到 [cpBuildT]

**Adjudication:** real documentation defect。核验：`[cpBuild]` 行要求 `cpLog.gcdOk` 为真（Druid.lua:29/43/55），gcdOk 来自 `isActionCooledDown('Ability_Druid_Rake')` 探针（Druid.lua:349），Rake 不在动作条 → 无施法采样；而 DKI tick（Druid.lua:408-472）只读 `GetComboPoints()` 与纯字段，`[cpBuildT]` 行照常产出。原文把 GCD 探针归因进了 [cpBuildT] 排查。

**Files modified:** `classes/druid/HUMAN-UAT.md`
**Commit:** `5f03a82`
**Applied fix:** 原"无 ok 无 fail"单行拆为双通道：`[cpBuild]` 缺失 → 查开关 + GCD 探针警告；`[cpBuildT]` 缺失 → 查 `macroTorch.cpBuildLog` 热开、目标态循环是否真发生 cp 下跳（无下跳则永无锚）、`macroTorch.LOG_MAX_SIZE` 是否裁剪。

### WR-03: events.lua 对 resetCpBuildDki 的无守卫调用会级联打断既有逻辑

**Adjudication:** real (latent) defect。正常路径下 build_order 保证函数存在（守卫恒真、零行为变化）；但 Druid.lua 加载失败时，分支内裸 nil 调用会抛错——PLAYER_TARGET_CHANGED 分支会中止后续 ffTimer/targetHealthVector 清理与 "Target change in combat!" 提示，PLAYER_REGEN_ENABLED 分支每次脱战刷错误。本 phase 新插入的 side-effect join 不应扩大 Druid.lua 载入失败的爆炸半径。

**Files modified:** `core/events.lua`
**Commit:** `7f85576`
**Applied fix:** 两处（PLAYER_TARGET_CHANGED 首个语句位、PLAYER_REGEN_ENABLED 的 onCombatExit 之后）均改为 `if macroTorch.resetCpBuildDki then macroTorch.resetCpBuildDki() end`。守卫只包裹调用本身，既有分支控制流逐语句保留（guard 是 side-effect join，非 gate）；RegisterEvent 计数字面保持 20 不变；Lua 5.0 方言（无 `#`、无 goto）；bbcheck BALANCED、`git diff --check` 干净。

## Verification Notes

- Static gates ran **inside the isolated worktree** (`.claude/worktrees/rf-30-...`) after each fix: `node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js <file>` reported BALANCED for both `classes/druid/HUMAN-UAT.md` and `core/events.lua`; `git diff --check` clean on every fix; before each commit `git status --porcelain` showed only the intended file.
- events.lua 修改后 re-read 确认：两处守卫缩进正确、分支上下文（ffTimer/targetHealthVector 清理、`macroTorch.show`、`onCombatExit()` 顺序）逐句未动。
- No Lua runtime on this host (D-14) — events.lua change is a statement-wrap (`if/then/end`), no new syntax surface; bbcheck is the mandated static gate for this phase.

---

_Fixed: 2026-09-10T16:40:29Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_