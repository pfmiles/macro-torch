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

## User-side UAT (resolved — 主线路实机全绿，冷路径按用户裁决跳过)

**已实测通过（用户实机，最新 build；2026-10-19/20/22 收口）**：装载/释放 A/B/C 三场景全部收敛、
无光标滞留（slot 13 与 17、单双持、副手空/占用均覆盖）；光标 Empty 新回归点所有路径按键收尾后
≤1.5s 落定为空；连打/骚扰/重复按键幂等并最终收敛；CD 命中显示「Useable item is in CD,
restoring:」转入恢复且不重新触发 CD（Decoy 远程 ≤30s 窗口 + Onyxian Brood Egg（slot 13）反复实测）；
释放键第 1 下真实使用物品（实机确认 CD-after 时间推进）。

**用户裁决跳过（低概率冷路径，2026-10-22，不再安排实机）**：
1. 队列中途进战斗 → PAUSE 零动作不丢状态 → 脱战 pump 自动续跑（附加收敛点 Step 4）；
2. CD 命中且当时正在战斗中（恢复臂战斗静默暂停、状态不丢）；
3. 背包满 deposit 无空位 rollback 兜底（F7 自愈冷路径）。
裁决依据：pokemon 实际使用由战斗前人工择时保证；释放键在进战斗前恢复战斗装备的主线路已实测可靠
（战斗中按下由战斗暂停臂保护状态 by design），三条冷路径不影响 raid 使用。

**状态：** unrun-verify 解除——主线路 verified + 冷路径 waived-by-user；本 quick UAT 完结。

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