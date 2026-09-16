---phase: quick-260916-utm
plan: 260916-utm
subsystem: gameplay
tags: [lua-5.0, wow-1.12, catatk, idol-selection, selftest, builder-relic]
status: complete

# Dependency graph
requires:
  - phase: 23-idol-dance-refactor
    provides: [computeNormalRelic 5-branch chain, Category O self-tests O-01..O-07, recoverNormalRelic execution layer]
  - phase: 26-catatk-fast-battle
    provides: [macroTorch.isFastBattleNotPvp, P series stub/restore discipline CR-01]
provides:
  - "selectFerocityOrEmeraldRot(clickContext) 3-layer priority: 8/8 Cenarion T1 > in-combat stickiness > battle type"
  - "Cat O-08..O-16 nine selftest registrations pinning T1/sticky/battle-type semantics"
affects: [catatk-builder-relic-rotation, druid-idol-management, selftest-Category-O]

# Actuals (#2632) — pairs with the plan's `estimate` to calibrate future estimates.
actuals:
  tokens: 3772     # chars/4 over the realized diff (git diff 15088 chars)
  tasks: 2         # tasks completed
  commits: 2       # MEASURED: git rev-list --count <plan_head_before>..HEAD
plan_head_before: 6f3e4f167328921631e32a91777e2e58208eae99

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "3-layer verdict chain in relic selection (T1 > sticky > battle-type), clickContext threaded through selection layer only"
    - "selftest multi-round stubs via mutable-upvalue closures (install-once contract)"

key-files:
  created: []
  modified:
    - "classes/druid/Druid.lua - selectFerocityOrEmeraldRot 3-layer rewrite + 4 clickContext call sites"
    - "classes/druid/selftest.lua - Cat O-08..O-16 nine registrations (Category O: 7 -> 16)"

key-decisions:
  - "Sticky guard scoped inside the both-owned branch only; single-owned/neither-owned branch bytes unchanged (D-03 zero-regression contract)"
  - "Multi-round tests install verdict stubs once via mutable-upvalue closures, satisfying install-once + per-round-pcall contract"
  - "O-16 pins real verdict wiring by pre-seeding ctx.isTrivialBattle / ctx.isFastBattleNotPvp lazy-cache fields, with target isCanAttack/isPlayerControlled guards aligned to P series"

patterns-established:
  - "Cat O builder pins: per-test 6-family snapshot/install/restore with rawget/rawset round-trip for the isInCombat accessor, all restores precede first assert"

requirements-completed: ["D-01@quick-260916-utm", "D-02@quick-260916-utm", "D-03@quick-260916-utm", "D-04@quick-260916-utm", "D-05@quick-260916-utm"]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "selectFerocityOrEmeraldRot 3-layer selection logic (T1 > stickiness > battle type) in Druid.lua"
    requirement: "D-01@quick-260916-utm"
    verification:
      - kind: unit
        ref: "/tmp/sandbox_utm.lua — real function bytes from Druid.lua executed under 9 official seeds + 2 negative probes on lua-5.0.3/5.1.5/5.4.7"
        status: pass
      - kind: other
        ref: "static gates: bbcheck BALANCED; loadfile assert on 3 interpreters; Lua-5.0 token gate 0; CRLF 0; hunk range <660"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cat O-08..O-16 in-game selftest battery (registered, static-verified; runtime /mt run pending user Windows+Cygwin rebuild)"
    requirement: "D-02@quick-260916-utm"
    verification:
      - kind: other
        ref: "static gates: register count 7->16; insertion between O-07 and Category Q; bbcheck BALANCED; 3-interpreter loadfile; token gate 0; CRLF 0; restore-discipline script 9/9 blocks clean"
        status: pass
      - kind: manual_procedural
        ref: "in-game /mt run of O-08..O-16 on user's Windows+Cygwin client (unrun-verify per plan; no local WoW client)"
        status: unknown
    human_judgment: true
    rationale: "Nine registrations simulate client APIs via stubs in-game; a local WoW client is unavailable so the /mt runtime run must happen on the user's machine (plan-declared unrun-verify flow)"

# Metrics
duration: 4min
completed: 2026-09-16
---

# Quick 260916-utm: catAtk builder 神像选择三层化 Summary

**selectFerocityOrEmeraldRot gains clickContext and a 3-layer priority (8/8 Cenarion T1 → in-combat stickiness → battle-type verdict) with 4 call sites updated and 9 new Cat O-08..O-16 selftest pins; execution layer untouched (D-03)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-09-16T14:22:50Z
- **Completed:** 2026-09-16T14:26:30Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Druid.lua `selectFerocityOrEmeraldRot(clickContext)` rewritten to the locked 3-layer chain: Layer 1 `countEquippedItemNameContains('Cenarion') >= 8` unconditionally returns Ferocity; Layer 2 in-combat stickiness checks Ferocity-then-Emerald-Rot equipped state and returns the worn builder, forbidding builder-to-builder swap; Layer 3 `isTrivialBattleOrPvp(clickContext) or isFastBattleNotPvp(clickContext)` maps fast/trivial/pvp to Ferocity and normal battles to Emerald Rot. All 4 `computeNormalRelic` call sites now pass clickContext (grep: 4 with-arg, 0 no-arg). File 1781 → 1795 lines; all hunks < 660; recoverNormalRelic/equipRelic/discharge chain byte-identical.
- selftest.lua Category O grows 7 → 16 registrations with O-08..O-16 inserted between O-07 and Category Q: single-ownership both directions (O-08/O-09), T1 beats stickiness (O-10), stickiness both directions (O-11/O-12), both verdict arms (O-13), normal battle (O-14), in-combat non-builder fall-through (O-15), and real verdict-function wiring via seeded clickContext caches (O-16, both real functions un-stubbed).
- CR-01 stub discipline verified programmatically on all 9 blocks: 6-family snapshot/install/restore pairs, rawget/rawset round-trip for the isInCombat accessor, every restore before the first assert, all calls inside pcall; O-16 carries only the 4 player-side stubs.
- Sandbox logic battery on the REAL extracted function bytes (selectFerocityOrEmeraldRot + isTrivialBattleOrPvp + isTrivialBattle + isFastBattleNotPvp) passed all 9 official seeds plus 2 negative probes (both-owned normal → E; neither-owned → F) on lua-5.0.3, 5.1.5, and 5.4.7.

## Task Commits

Each task was committed atomically:

1. **Task 1: Druid.lua 三层选择重构 + 4 调用点传参** - `4854eaa` (feat)
2. **Task 2: selftest Cat O-08..O-16 九项注册** - `619452e` (test)

## Files Created/Modified

- `classes/druid/Druid.lua` - 3-layer selection rewrite (25 insertions / 11 deletions, net +14 → 1795 lines); 4 return call sites threaded with clickContext
- `classes/druid/selftest.lua` - nine O-08..O-16 registrations (279 pure insertions → 2783 lines)

## Gate Results (per plan GATE 汇总)

- commits: exactly 2, messages verbatim per locked text; `git log -2 --format='%s'` verified
- worktree: only untracked `.planning/quick/260916-utm-catatk-builder-1-selectferocityoremerald/` remains (docs commit handled by quick flow)
- `git diff --check`: clean on both commits
- Task 1 gates 1-8 all green: with-arg count 4 / no-arg count 0 / 1795 lines / bbcheck BALANCED / 3 interpreters loadfile OK / token gate 0 / CRLF 0 / hunks all < 660
- Task 2 gates 1-8 all green: register count 16 / insertion position (949-1198 between O-07@942 and Category Q@1228) / bbcheck BALANCED / 3 interpreters OK / token gate 0 / CRLF 0 / restore discipline script 9/9 blocks clean / single hunk
- Sandbox (bonus, beyond plan): 12/12 scenarios pass on all three Lua interpreters

## Decisions Made

- Multi-round tests (O-13/O-15) provide verdict stubs as closures over mutable local upvalues — install-once contract kept while each round reads its own verdict pair.
- O-16 guards (`if not macroTorch.target.isCanAttack then return end` / `if macroTorch.target.isPlayerControlled then return end`) mirror the P-series guard style so the real-function wiring test silently skips when no valid attackable target exists.
- Committed on `main` per project config `use_worktrees: false` and the established quick-task pattern (every prior quick commit lands on main).

## Deviations from Plan

No Rule 1-4 deviations; implementation followed the locked plan. Three documentation-level clarifications:

1. **Task 2 gate 7 count wording** — plan text says "O-16 只有 5 项 stub（不动两个判定函数）", but the plan's own stub list (6 items minus the two excluded verdict functions) yields 4. Implementation carries 4 player-side stubs (hasItem / isRelicEquipped / countEquippedItemNameContains / isInCombat-via-rawset) with both verdict functions untouched — the substantive requirement met exactly; plan count is a typo.
2. **Task 2 gate 8 wording** — "2504 之后的增行带" cannot apply to the plan's own mid-file insertion anchor (947/949). The realized diff is one insertion hunk anchored at old line 948, fully inside the required 940-960 band; no hunks exist outside the region.
3. **Bonus sandbox verification** — the plan's GATE section stops at static gates (unrun-verify in-game). Executor additionally extracted the real function bytes and ran a 12-scenario logic battery on three Lua interpreters, all pass (see coverage D1).

## Issues Encountered

- Harness-side only: an awk extraction initially captured `isTrivialBattleOrPvp` under the `isTrivialBattle` prefix pattern; fixed with an escaped-paren pattern in the extraction script. No repository code affected.

## Unrun Verification (plan-declared)

In-game `/mt` runtime run of O-08..O-16 is pending the user's Windows+Cygwin rebuild (no local WoW client). Per plan, this quick does not touch WINDOWS.md; tracked here and in the coverage block (D2, human_judgment: true).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Builder-rotation logic ready for user machine verification; after the in-game run, O-16's real wiring pin double-confirms the D-04 expression's clickContext plumbing end-to-end.

## Self-Check: PASSED

- `classes/druid/Druid.lua` — present, 1795 lines, committed in `4854eaa`
- `classes/druid/selftest.lua` — present, 2783 lines, committed in `619452e`
- `git log --oneline -2` confirms `619452e` and `4854eaa` on `main`

---

*Phase: quick-260916-utm*
*Completed: 2026-09-16*