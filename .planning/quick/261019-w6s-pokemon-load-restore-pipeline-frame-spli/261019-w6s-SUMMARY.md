---
phase: quick-261019-w6s
plan: 261019-w6s
quick_id: 261019-w6s
subsystem: entity-player-equipment
tags: [lua, wow-1.12, pokemon, frame-split, periodic-task, cursor-queue]

# Dependency graph
requires:
  - phase: quick-261016-20c
    provides: loadUseableItemToSlot/multi-arm restores snapshot state shape (itemLoadingTable entries)
  - phase: quick-261016-vbt
    provides: castLoadedItem CD-hit same-press restore fallthrough semantics (kept byte-identical)
  - phase: Phase 30
    provides: core/periodic.lua registerPeriodicTask pcall-guarded OnUpdate precedent (cpBuildDkiPoll pattern)
provides:
  - frame-split pokemon load/restore queue (macroTorch.pokemonEquipQueue, 'pokemonPipelineTick' 0.1s, one cursor op per tick, verify one tick after action)
  - F-R-01/R-02/R-03/R-04 (see key-decisions)
affects:
  - future quick tasks touching entity/Player.lua equipment pipeline
  - Phase 29+ land/combat work (registerPeriodicTask usage pattern)

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 8070    # chars/4 over the realized diff (32281 chars, BASE..HEAD entity/Player.lua) vs estimate 100000
  tasks: 2        # tasks completed
  commits: 1      # MEASURED: git rev-list --count 6e86f58..HEAD (#3968 ledger)
plan_head_before: 6e86f587e604d4848c186d614ee3d6bf246d4016
plan_head_after: 7710456bfb93092d31b3b41e1c7657766cebc5c9

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "one-cursor-op-per-tick frame-split queue with deferred (tick-after) verification reads"

key-files:
  created: []
  modified:
    - entity/Player.lua

key-decisions:
  - "F1: same-frame equip+verify abolished; both same-frame helpers (equipItemToSlotVerified/unequipToBagVerified) removed; every equip judgement reads obj.isItemNameInSlot one tick after the action"
  - "F2: two-hander repair arm fires only on confirmed refusal (deferred verify=false AND isItemExist(useableItem) AND targetSlot==17 AND non-empty main-hand snapshot); it is the sole path touching slot 16"
  - "F3: macroTorch.pokemonEquipQueue pumped by registerPeriodicTask('pokemonPipelineTick', 0.1s); 9 step handlers; idle zero-API early out; combat PAUSE mid-queue keeps steps, resumes after"
  - "F4: all three castLoadedItem restore arms ride the same queue; press-1 use arm and CD-hit same-press semantics byte-frozen"
  - "Committed on main: .planning/config.json git.allow_default_branch_commits=true asserted via gsd-tools (is-protected=false); SEQUENTIAL executor guard set"
  - "In-game UAT (three-scenario matrix + cursor-clean regression + CD-in-combat) filed as user-side unrun-verify; human must rebuild SM_Extend.lua (./build.sh on Windows/Cygwin)"
  - "EXECUTOR commits code only; PLAN.md/SUMMARY.md/STATE.md docs commit belongs to the quick-flow orchestrator"

requirements-completed:
  - R-01@quick-261019-w6s
  - R-02@quick-261019-w6s
  - R-03@quick-261019-w6s
  - R-04@quick-261019-w6s

# Coverage metadata (#1602) — one entry per shipped deliverable.
coverage:
  - id: D1
    description: "Frame-split pokemon load/restore pipeline — all equip/unequip/rollback actions via macroTorch.pokemonEquipQueue (one cursor op per tick, verify on the tick after), F1-F4"
    requirement: "R-01@quick-261019-w6s, R-02@quick-261019-w6s, R-03@quick-261019-w6s, R-04@quick-261019-w6s"
    verification:
      - kind: unit
        ref: "head-adjudication md5 e92787b8b042d8994c12477d07fff945 (matches planner pre-run byte-for-byte)"
        status: pass
      - kind: unit
        ref: "structure/zero/shape/discipline/order gates per 261019-w6s Task 1 <verify> (all green)"
        status: pass
      - kind: unit
        ref: "frozen-band md5 weld x4 vs HEAD + lua-5.0.3/5.1.5/5.4.7 loadfile + bbcheck BALANCED + CRLF 0"
        status: pass
      - kind: unit
        ref: "diff hygiene: added lines contain no #/goto/::, git diff --check clean, single-file commit"
        status: pass
    human_judgment: false
  - id: D2
    description: "In-game UAT: 20c three-scenario matrix (A two-hand weapon in 16 / B one-hand main + 17 occupied / C one-hand main + 17 empty) + new cursor-clean regression (CursorHasItem() empty after settle, <=1.5s after every keypress) + CD-hit-in-combat by-design check"
    verification: []
    human_judgment: true
    rationale: "Requires a WoW 1.12.1 client with the addon rebuilt (SM_Extend.lua via ./build.sh on the user's Windows+Cygwin side); cannot be exercised by static gates on this Linux host"

# Metrics
duration: ~15min
completed: 2026-10-19
status: complete
---

# Quick 261019-w6s: pokemon 装载/恢复管线帧拆分修复 Summary

Pokemon load/restore pipeline rebuilt from same-frame multi-step (E1/E2/E3 client facts) into a
frame-split single-action queue: one cursor op per 0.1s tick, every equip/restore judgement read
one tick after its action, two-hander repair fired only on confirmed refusal, panic rollbacks on
every deposit risk path — one byte-locked commit in entity/Player.lua.

## Performance

- **Duration:** ~15 min (single session, 3 Edit operations + gate battery + atomic commit)
- **Files changed:** 1 (entity/Player.lua, 962 → 1097 lines, +297/−170)
- **Commits:** 1 (measured via plan ledger: `gsd-plan-head-before-quick-261019-w6s`)

## What Was Done

- **Edit① (region 345–603 → contract①):** doc block rewritten with live-forensics facts;
  `obj.isItemNameInSlot` kept; both same-frame helpers (`equipItemToSlotVerified`,
  `unequipToBagVerified`) deleted (zero-count gates = 0); `loadUseableItemToSlot` enqueues only —
  resume pre-scan, swap path, empty-slot path each enqueue `pickupBag → equipCursor →
  verifyEquipLoad` and return; write of `mainHandItem`/`pendingEquip`/`pendingSaying` deferred to
  the pipeline.
- **Edit② (region 672–735 → contract②):** the three restore arms of `castLoadedItem` ride the same
  queue — swap arm (`pickupBag → equipCursor → verifyEquipRestore`), main-hand arm (target 16),
  plain-unequip arm (`pickupInventory → verifySlotEmpty`); idempotent already-restored prechecks
  and per-arm combat pause unchanged.
- **Edit③ (insert at `return obj`/`end`):** 255-line queue block — `pokemonQueueEnsure`,
  `pokemonEnqueue`, `pokemonPipelineTick` (idle zero-API early out, combat PAUSE, single dequeue),
  `registerPeriodicTask('pokemonPipelineTick', {interval=0.1, ...})`, `pokemonPipelineStep`
  dispatch, and 9 handlers: 3 action handlers (pickupBag / pickupInventory / depositCursor — 1
  cursor call each), 6 read-only verify handlers (verifySlotEmpty / verifyEquipLoad /
  verifyDepositUnequip / verifyDepositPlain / verifyEquipRestore / verifyRollback — 0 cursor
  calls), with rollbackCursor → verifyRollback chains on every deposit doubt path.

## Verification (automated, all green before commit)

- **Head adjudication:** whole-file md5 `e92787b8b042d8994c12477d07fff945` — exact planner
  pre-run match, byte-identical to a rehearsal assembly built from the plan fences before editing.
  Hit on the FIRST edit pass; zero auto-fix attempts consumed.
- **Anchors:** all 16 planning line anchors + both old-region md5s
  (`b35382e…`, `286b263…`) verified before any Edit.
- **Structure gates (12):** all present, incl. the exact registration line.
- **Zero-count gates:** `equipItemToSlotVerified` = 0, `unequipToBagVerified` = 0.
- **Shape-count gates (17):** all match planner pre-run values (pickupBag=7, equipCursor=7,
  verifyEquipLoad=5, pickupInventory=3, verifySlotEmpty=3, depositCursor=2, verifyDepositUnequip=2,
  verifyDepositPlain=2, verifyEquipRestore=3, rollbackCursor=4, verifyRollback=4,
  registerPeriodicTask=1, UnitAffectingCombat(=3, CursorHasItem=4, isItemExist(=5,
  pokemonEnqueue(=32, handler definitions=9).
- **Per-tick single-cursor discipline:** 3 action handlers = 1 each, 6 verify handlers = 0,
  dispatch = 2 (mutually exclusive branches), tick body = 0.
- **Order gates:** load: Combat pause < Resume arm pre-scan < Global lock; tick: idle early-out <
  combat PAUSE < dequeue.
- **Frozen-band welds (4 bands) vs HEAD:** pokemonLoad (7 entries + 7 sayings + toSlots), cast
  header + press-1 arm (incl. CD branch), say → classMetatable → return obj,
  PLAYER_FIELD_FUNC_MAP → EOF. All byte-identical.
- **Syntax gates:** lua-5.0.3 (authoritative), lua-5.1.5, lua-5.4.7 `loadfile` all pass; bbcheck
  `entity/Player.lua: BALANCED`; CRLF count 0.
- **Diff hygiene:** added lines contain no `#`/`goto`/`::`; `git diff --check` clean; name-only
  diff is exactly `entity/Player.lua`; 9 hunks as expected.
- **Task 2 cross-file closure (zero commits):** BASE (HEAD~1) = `6e86f58` with the planner-locked
  message (`chore(gsd): allow_default_branch_commits=true (branching_strategy none)`) — used as-is,
  no re-anchoring; BASE..HEAD = 1 commit, 1 file; docs/, SM_Extend.lua, core/selftest.lua,
  build_order.txt all zero diff; diff --check clean; porcelain equivalent gate passed (exactly the
  one untracked `?? .planning/quick/261019-w6s-…/` line, docs commit owned by the orchestrator).

## Commit

- `7710456` — `fix(261019-w6s): frame-split pokemon load/restore pipeline (Player.lua)`
  (only `entity/Player.lua`; `git show --stat --format= --name-only HEAD` outputs exactly
  `entity/Player.lua`; post-commit deletion check: none)

## Deviations from Plan

None — plan executed exactly as written: precondition verified (clean tree, HEAD `6e86f58`, toolchain
present, porcelain exactly the untracked quick-plan dir), three byte-locked Edits top-down, head
adjudication md5 matched on the first pass, full gate battery green, one commit with the
byte-locked message, Task 2 closure gates green with zero commits.

## User-side UAT (unrun-verify — filed per WINDOWS unrun-verify precedent)

**实机验证为 user-side unrun-verify（不并入本 quick 自动门，与 20c/Phase 27-30 的 WINDOWS
unrun-verify 先例一致）**：用户需在 **Windows+Cygwin 侧运行 ./build.sh 重建 SM_Extend.lua** 后在木桩
跑「20c 三场景矩阵 + 新回归点」。所有预期都建立在逐帧队列之上：装载/恢复按键后由 pump 在约
0.3-1.5 秒内自动收尾（A 场景修复链约 7 tick ≈ 0.7-1s），**无需在结算窗口内补按任何键**；重按幂等
（续跑预扫再入队同串）。观察 L16/L17 与光标 cur：

| 场景 | 装载键（1 键，pump 自动收尾） | 释放键第 1 下 | 释放键第 2 下 |
|------|--------------------|--------------------|--------------------|
| A 双手武器在 16、17 空 | 装备被确认拒绝（物品回包）→自动卸双手入包（16 空）→重装 17 并下一帧验证：L17=pokemon、L16 空 | 使用物品 + 喊对应 saying | 双手回 16（L16=双手）、L17 空、pokemon 自动回包 |
| B 单手主手 + 17 有装备 | pokemon swap 入 17（L17=pokemon），原副手入包、L16 全程不动 | 同上 | 原副手回 17（L17=原副手名）、pokemon 回包、L16 仍不动 |
| C 单手主手 + 17 空 | pokemon 装 17（L17=pokemon）、L16 不动 | 同上 | pokemon 卸下回包、L17 空、L16 仍在 |

**新回归点（本次 quick 主验点，高于一切，取代 20c A/C 场景的滞留观察）**：每次按键（装载或释放）
收尾后——屏幕提示信息落定、约 ≤1.5 秒——`CursorHasItem()` 必须为空：三场景全路径 + 装载失败收敛路径
都不允许光标滞留任何物品（E3 根治）。按键后 0~0.5 秒内 pickup 拆帧造成的短暂上光标是设计内瞬态，
判定只看落定态，不看瞬时。

**CD 命中进战斗（vbt 语义延续，by design 非 bug）**：CD 命中显示「Useable item is in CD,
restoring:」并同按转入恢复；若此刻在战斗中，恢复臂静默战斗暂停、状态不丢；脱战续按收敛。

附加收敛点（20c 抽验项延续）：装载中断/失败后重复按装载键不重复出乱、最终收敛；中途进战斗队列
PAUSE 零动作不丢状态，脱战后 pump 自动续跑至收敛。

**unrun-verify 状态：** 上述全部为 user-side pending；自动门已全绿，但实机矩阵须由用户执行。
**Required user actions:** 1) Windows/Cygwin 侧 `./build.sh` 重建 SM_Extend.lua；2) 木桩跑三场景矩阵 +
光标 Empty 回归点 + CD-in-combat 观察。

## Known Stubs

None — no stub patterns (`=[]`, `={}`, `=nil`-flowing-to-UI, TODO/FIXME, placeholder text); the queue
block is fully wired to the periodic pump.

## Threat Flags

None — no new network, file-access, auth, or cross-trust-boundary surface; all changes stay inside
the player equipment flow with the same client APIs as before.

## Self-Check: PASSED

- File exists: `entity/Player.lua` (post-edit md5 `e92787b8b042d8994c12477d07fff945` verified)
- Commit `7710456` is ancestor of HEAD and message is exactly
  `fix(261019-w6s): frame-split pokemon load/restore pipeline (Player.lua)`
- Task 2 closure gates re-run green after the commit (BASE anchor `6e86f58` matched planner message)
- SUMMARY written to this file; docs commit (PLAN.md/SUMMARY.md/STATE.md) intentionally left to the
  orchestrator per the quick-flow split