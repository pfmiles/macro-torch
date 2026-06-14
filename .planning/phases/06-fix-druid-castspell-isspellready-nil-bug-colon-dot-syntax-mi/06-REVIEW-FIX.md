---
phase: 06
fixed_at: 2026-06-14T15:30:00Z
review_path: .planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 0
skipped: 2
status: none_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-06-14T15:30:00Z
**Source review:** .planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 2 (WR-01, WR-02)
- Fixed: 0
- Skipped: 2

## Fixed Issues

None -- all findings were assessed as false positives / pre-existing design patterns that do not require fixing.

## Skipped Issues

### WR-01: obj.cast ignores onSelf parameter, creating divergent casting paths

**File:** `entity/Player.lua:29-31, 76-79`
**Reason:** False positive -- pre-existing design pattern from Phase 5, not a bug introduced by Phase 6.

The two-path casting design in `_castSpell` is intentional and functionally correct:
- Self-target path (`onSelf=true`): `CastSpellByName(spellName, true)` -- direct WoW API call
- Enemy-target path (`onSelf=false`): `obj.cast(spellName, false)` -> `macroTorch.castSpellByName(spellName, 'spell')` -> `CastSpell(getSpellIdByName(...), 'spell')` -- goes through spell ID lookup

The `obj.cast()` method (line 29) accepts `onSelf` as a parameter but delegates all casting to `macroTorch.castSpellByName`. While the unused parameter is a minor API inconsistency, the reviewer's proposed "Option A" fix (moving the self-target branch into `obj.cast` and unifying `_castSpell` to a single `obj.cast(spellName, onSelf)` call) would change behavior for `obj.cast()` callers outside of `_castSpell` and is not safe to apply without a full audit of every `obj.cast()` call site in the codebase. The asymmetry between `CastSpellByName(spellName, true)` and `CastSpell(getSpellIdByName(...), 'spell')` matches the WoW 1.12.1 API's different target parameters for self vs. enemy spells, making this a correct reflection of the underlying API rather than a bug.

The review itself acknowledges: "This is a pre-existing design issue, not introduced by Phase 6."

**Original issue:** The `obj.cast(spellName, onSelf)` method at line 29 accepts an `onSelf` parameter but always calls `macroTorch.castSpellByName(spellName, 'spell')` regardless of its value. This creates two divergent casting code paths for self-target vs. enemy-target spells.

### WR-02: _hasResource self.mana closure resolution chain is undocumented and fragile

**File:** `entity/Player.lua:101-103`
**Reason:** False positive -- standard metatable chain pattern used throughout the entire codebase, functionally correct.

The resolution chain is intentional and well-documented in `.claude/CLAUDE.md` under "ref Field Inheritance Chain":
```
Druid instance --[__index]--> macroTorch.Druid --[__index]--> macroTorch.Player --[__index]--> Unit instance (ref="player")
```

- `self` in `macroTorch.Player:new(self)` (line 23) is `macroTorch.Player` -- a Unit instance with `ref="player"` (created at line 19)
- `self.mana` resolves through `__index` -> `UNIT_FIELD_FUNC_MAP["mana"]` -> `UnitMana("player")`
- WoW 1.12.1's `UnitMana("player")` returns the correct resource type automatically (energy in cat form, rage in bear form, mana in caster form)

This pattern is used consistently throughout the codebase (every field access on `macroTorch.Player` prototype resolves the same way). The reviewer's concern about "subclass overrides" is addressed by the explicit metatable design: subclasses (Druid, Hunter, etc.) have their own `__index` that searches subclass FIELD_FUNC_MAP first, then falls through to Player prototype. No subclass overrides `mana` in a way that would break this.

The review itself acknowledges: "This is pre-existing, not introduced by Phase 6."

**Original issue:** The `_hasResource` function uses `self.mana` where `self` is a closure upvalue captured from `macroTorch.Player:new(self)`. The resolution chain works correctly because the Player prototype always reads the player's mana via `UnitMana("player")`.

---

_Fixed: 2026-06-14T15:30:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_