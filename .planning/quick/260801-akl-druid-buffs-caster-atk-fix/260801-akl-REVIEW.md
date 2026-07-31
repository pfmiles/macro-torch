---
status: clean
files_reviewed: 2
critical: 0
warning: 0
info: 0
total: 0
depth: standard
date: 2026-08-01
phase: quick/260801-akl
---

# Code Review: quick/260801-akl — druidBuffs self-cast & casterAtk auto-atk

## Review Summary

| Category | Count |
|----------|-------|
| Critical | 0 |
| Warning  | 0 |
| Info     | 0 |
| **Total**| **0** |

**Verdict:** Clean. No bugs, security issues, or code quality problems found.

---

## Scope

| File | Change Summary |
|------|---------------|
| `classes/druid/utility.lua` | `druidBuffs()`: replaced `macroTorch.player.mark_of_the_wild('ready', true)` / `thorns('ready', true)` with `CastSpellByName(name, true)` + explicit `isSpellReady` check |
| `classes/druid/combo.lua` | `casterAtk()`: added `macroTorch.startAutoAtk()` call at the top of the in-combat branch |

---

## Per-File Analysis

### 1. `classes/druid/utility.lua` — druidBuffs self-cast fix

**Change:** Mark of the Wild and Thorns now use `CastSpellByName('SpellName', true)` instead of `macroTorch.player.mark_of_the_wild('ready', true)` / `thorns('ready', true)`.

**Correctness analysis:**

- **Root cause addressed:** The original `_castSpell` → `CastSpell(spellId, 'spell')` path does not honor `onSelf=true` for Type C spells (castable on any friendly target). `CastSpellByName(name, true)` is the correct WoW 1.12 API call for forced self-cast, bypassing the macroTorch spell routing layer entirely.

- **`isSpellReady` guard correctly added:** The original `'ready'` mode internally checked spell readiness before casting. The replacement `CastSpellByName` has no such guard, so the explicit `isSpellReady('Mark of the Wild')` / `isSpellReady('Thorns')` check is necessary and correctly placed as an additional `and` condition.

- **Existing guards retained:** `isSpellExist` and `buffed()` checks remain in place, preventing attempts to cast unlearned spells or re-buff when already active.

- **Nature's Grasp unchanged (correct):** This is a Type B self-only spell — `CastSpell` automatically targets self for self-only spells, so no fix needed.

- **No regression risk:** The `CastSpellByName` API respects GCD and range natively in the WoW client. Error handling is implicit — if the spell fails (OOM, silenced, etc.), it simply doesn't cast, same as the original path.

### 2. `classes/druid/combo.lua` — casterAtk auto-attack

**Change:** Added `macroTorch.startAutoAtk()` at the top of the in-combat branch (`else` → `isInCombat == true`).

**Correctness analysis:**

- **Structural change is sound:** The original `elseif` chain was restructured to `else` + nested `if` to accommodate `startAutoAtk()` before the spell priority chain. The control flow is semantically identical — the spell chain still runs after auto-attack is started.

- **Auto-attack is idempotent:** Calling `startAutoAtk()` repeatedly is safe — WoW's API is a no-op if auto-attack is already active. Matches the pattern in `catAtk` (line 130).

- **Guard is appropriate:** The `isInCombat` check (`else` branch of `if not isInCombat`) is the correct guard. In pre-combat (Wrath opener), auto-attack should not fire since it would break ranged pulling. This mirrors `catAtk`'s `isFightStarted(clickContext)` guard (the casterAtk equivalent using `isInCombat` as a simpler, correct alternative).

- **Placement is correct:** `startAutoAtk()` before the spell chain ensures auto-attack begins immediately on entering combat, maximizing melee uptime during mana downtime. The spell chain still executes afterward, so no spell is skipped.

- **No regression:** The indentation change (4 extra spaces for the nested `if` block) is purely cosmetic and matches the codebase's 4-space indentation convention.

---

## Cross-File Consistency

| Pattern | catAtk (reference) | casterAtk (this change) |
|---------|-------------------|------------------------|
| Auto-atk guard | `isFightStarted(clickContext)` (line 129) | `isInCombat` (else branch) |
| Auto-atk placement | Before spell chain (line 130) | Before spell chain (line 21) |
| Idempotent call | `player.startAutoAtk()` | `macroTorch.startAutoAtk()` |

The patterns are consistent. The `macroTorch.startAutoAtk()` vs `player.startAutoAtk()` difference is because `casterAtk` uses `macroTorch.*` directly while `catAtk` aliases `player = macroTorch.player` — functionally identical.

---

## What Was NOT Found

- No null/nil dereference risks
- No infinite loop potential
- No race conditions (Lua is single-threaded in WoW)
- No security issues (client-side WoW macro, no external input)
- No performance regressions
- No deviation from existing codebase patterns