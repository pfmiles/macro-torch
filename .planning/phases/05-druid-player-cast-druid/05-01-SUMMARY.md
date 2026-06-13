---
phase: 05-druid-player-cast-druid
plan: 01
subsystem: Player base class spell casting infrastructure
tags: [spell-casting, locale, shared-helpers, druid-refactor, Player-base-class]
requires: []
provides: [player._castSpell, player._isInRange, player._hasResource]
affects: [entity/Player.lua]
tech-stack:
  added: []
  patterns: [closure-based-methods, locale-table-lookup, type-based-dispatch, guard-clause-early-return]
key-files:
  created: []
  modified: [entity/Player.lua]
decisions:
  - "D-05: _castSpell localeNames uses { en, zh } short keys; GetLocale() maps 'zhCN' to zh key, falls back to en"
  - "D-06: Mode parameter nil/ready (default), 'raw' (no checks), 'safe' (ready+distance+resource)"
  - "D-08: resourceCost accepts number (fixed cost) or function reference (dynamic cost, called with zero args)"
metrics:
  duration: ~5min
  completed_date: 2026-06-13T04:06:35Z
---

# Phase 5 Plan 01: _castSpell / _isInRange / _hasResource 共享辅助方法

**One-liner:** Three shared spell casting helper methods (_castSpell, _isInRange, _hasResource) added to the Player base class, providing locale-aware spell name selection, mode-driven readiness/distance/resource checks, and form-agnostic resource validation -- foundational infrastructure for all ~43 Druid skill methods in Plans 05-02 through 05-05.

## Task Summary

| Task | Name                                    | Type | Commit   | Result |
|------|-----------------------------------------|------|----------|--------|
| 1    | Add _castSpell to entity/Player.lua     | auto | fc6df4a  | PASS   |
| 2    | Add _isInRange to entity/Player.lua     | auto | 8090fea  | PASS   |
| 3    | Add _hasResource to entity/Player.lua   | auto | 401448c  | PASS   |

**Total:** 3/3 tasks complete. All builds pass (`./build.sh` exits 0).

## Verification Results

### Per-task

| Check                              | Expected  | Actual | Status |
|------------------------------------|-----------|--------|--------|
| `function obj._castSpell` count    | 1         | 1      | PASS   |
| `function obj._isInRange` count    | 1         | 1      | PASS   |
| `function obj._hasResource` count  | 1         | 1      | PASS   |
| All three methods exist            | 3         | 3      | PASS   |
| `GetLocale()` call                 | >= 1      | 1      | PASS   |
| `type(resourceCost) == 'function'` | >= 1      | 1      | PASS   |
| `self:cast(spellName, onSelf or false)` | >= 1  | 1      | PASS   |
| `./build.sh` exit code             | 0         | 0      | PASS   |

### Acceptance Criteria

- [x] entity/Player.lua contains `obj._castSpell`, `obj._isInRange`, `obj._hasResource` inside `Player:new()`
- [x] `_castSpell` handles nil (ready), 'raw' (no checks), and 'safe' (all checks) modes correctly
- [x] `_castSpell` uses `GetLocale()` for locale-based spell name selection with zh/en fallback
- [x] `_castSpell` accepts both numeric and function resourceCost via `type()` check
- [x] `_isInRange` handles nil target gracefully (returns false)
- [x] `_isInRange` handles melee range (nil/0 returns true if target exists)
- [x] `_hasResource` uses `self.mana` for form-agnostic resource checking
- [x] `./build.sh` exits 0 on all three task commits
- [x] No existing Player methods modified or broken

## Deviations from Plan

None -- plan executed exactly as written, all three methods added per the specification from RESEARCH.md Pattern 1 and spell_refactor_plan_druid.txt.

## Method Placement in Player:new()

```
Player:new()
  └─ obj.cast()              (existing, line 29)
  └─ obj._castSpell()        (NEW, line 34) -- locale select + mode dispatch
  └─ obj._isInRange()         (NEW, line 82) -- distance guard
  └─ obj._hasResource()       (NEW, line 94) -- resource guard
  └─ obj.use()                (existing)
  └─ ... (remaining methods unchanged)
```

## Key Design Decisions

1. **Locale table short keys:** `{ en = 'Claw', zh = '爪击' }` with `GetLocale()` mapping 'zhCN' to zh key, all other locales fall back to en. Keeps skill method locale tables compact.

2. **Mode dispatch logic:** `mode ~= 'raw'` (covers nil default + 'ready') triggers `isSpellReady` check. `mode == 'safe'` additionally triggers `_isInRange` + `_hasResource` checks. Only three effective behaviors from two boolean conditions.

3. **Dynamic resourceCost:** `type(resourceCost) == 'function'` calls it with zero args for current cost, else uses the number directly. This enables talent/item-dependent energy costs (e.g., `macroTorch.computeClaw_E`) without baking clickContext dependency into `_castSpell`.

4. **onSelf fallback:** `onSelf or false` in the final cast call. Handles nil for Type A skills (enemy target) and explicit true/false for Type B (self) and Type C (flexible) skills.

## Self-Check: PASSED

- All 3 commits verified in git log (fc6df4a, 8090fea, 401448c)
- entity/Player.lua exists and contains all 3 new methods
- ./build.sh exits 0 on final state