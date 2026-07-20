---
phase: 20-spell-id-auto-correct-spellid
reviewed: 2026-07-20T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - classes/druid/combo.lua
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Code Review: isSpellExist Guards in combo.lua

**Reviewed:** 2026-07-20
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed the addition of `isSpellExist()` guards to druid caster-form combat functions in `classes/druid/combo.lua`. This fix adds 13 new `isSpellExist` checks across 5 functions (`casterAtk`, `druidAoe`, `druidHeal`, `druidDefend`, `druidControl`) to prevent attempts to cast unlearned spells on low-level druids.

**Overall assessment:** The fix is correctly implemented. All spell name strings exactly match their `castSpellByName` targets in `classes/druid/Druid.lua`. All guards use the correct `'spell'` bookType parameter. The `catAtk()` Lv60 cat DPS rotation was not touched. Fallback paths are logically sound — when a spell is unavailable, the rotation correctly falls through to the next available option or the innate spell (Wrath / Healing Touch).

**One warning found:** A pre-existing inconsistency in `druidCharge()` where three `isSpellExist` calls omit the `'spell'` bookType parameter, now highlighted by the consistent usage in the newly-added guards.

## Warnings

### WR-01: druidCharge() isSpellExist calls missing 'spell' bookType

**File:** `classes/druid/combo.lua:314,323,328`
**Issue:** Three `isSpellExist` calls in `druidCharge()` do not pass the `'spell'` bookType parameter:

- Line 314: `macroTorch.isSpellExist("Dire Bear Form")`
- Line 323: `macroTorch.isSpellExist("Feral Charge")`
- Line 328: `macroTorch.isSpellExist("Bash")`

All 13 newly-added `isSpellExist` guards in this diff consistently pass `'spell'`: `isSpellExist('Faerie Fire', 'spell')`, etc. The `getSpellIdByName` function passes `bookType` directly to `GetSpellName(i, bookType)`. If the WoW 1.12.1 client does not default `nil` to the spell book, the pcall wrapper would catch the error and `getSpellIdByName` would return `nil`, causing `isSpellExist` to return `false` for all three checks.

Impact if the client does NOT handle nil bookType:
- `isSpellExist("Dire Bear Form")` always false → level 40+ druids never use Dire Bear Form, always fall to normal Bear Form
- `not isSpellExist("Feral Charge")` → `not false` → `true` → always returns early at range >= 8, never casts Feral Charge
- `not isSpellExist("Bash")` → `not false` → `true` → always returns early at range < 8, never casts Bash

This is a pre-existing bug (not introduced by this diff) but is now more visible because every other `isSpellExist` call in the file consistently passes `'spell'`.

**Fix:**
```lua
-- Line 314: add 'spell'
if macroTorch.isSpellExist("Dire Bear Form", 'spell') then

-- Line 323: add 'spell'
if not macroTorch.isSpellExist("Feral Charge", 'spell') then

-- Line 328: add 'spell'
if not macroTorch.isSpellExist("Bash", 'spell') then
```

## Verified Correct

The following aspects of the fix were verified and found to be correct:

### 1. Spell Name Accuracy
All 13 `isSpellExist` spell name strings were cross-referenced against the `{ en = '...' }` definitions in the Druid spell methods (`classes/druid/Druid.lua`). Every name has an exact match:

| Guard Location | Spell Name | Druid.lua Definition |
|---|---|---|
| casterAtk:10,20 | `'Faerie Fire'` | `{ en = 'Faerie Fire' }` line 112 |
| casterAtk:17 | `'Moonfire'` | `{ en = 'Moonfire' }` line 96 |
| casterAtk:23 | `'Insect Swarm'` | `{ en = 'Insect Swarm' }` line 116 |
| casterAtk:26,34 | `'Starfire'` | `{ en = 'Starfire' }` line 100 |
| druidAoe:194 | `'Hurricane'` | `{ en = 'Hurricane' }` line 184 |
| druidHeal:222,243 | `'Regrowth'` | `{ en = 'Regrowth' }` line 221 |
| druidHeal:225,232,238 | `'Rejuvenation'` | `{ en = 'Rejuvenation' }` line 225 |
| druidDefend:253 | `'Barkskin'` | `{ en = 'Barkskin' }` line 166 |
| druidDefend:264 | `'Frenzied Regeneration'` | `{ en = 'Frenzied Regeneration' }` line 196 |
| druidControl:296 | `'Hibernate'` | `{ en = 'Hibernate' }` line 108 |
| druidControl:298 | `'Entangling Roots'` | `{ en = 'Entangling Roots' }` line 104 |

No typos, no locale mismatches.

### 2. catAtk() Untouched
The Lv60 cat DPS rotation `catAtk()` (lines 44-173) was **not modified** in this diff. The `hasPounce`/`hasRavage` guards at lines 129-130 pre-date this commit (added in an earlier phase). The rest of the cat form rotation logic — including the module priority order, energy calculations, relic dance, and reshift logic — is unchanged.

### 3. casterAtk() Fallback Logic
When all optional spells (Moonfire, Faerie Fire, Insect Swarm, Starfire) are unavailable:
- The `else` branch at line 31 falls through to `player.wrath()` (innate, always available)
- `starfireNext` flag is only set when Starfire exists (line 34-36), avoiding unnecessary state cycling on low-level druids

### 4. druidHeal() Fallback Logic
- Group healing: When Regrowth/Rejuvenation are unavailable for their respective HP thresholds, falls through to `healing_touch()` (innate)
- Solo healing: Rejuvenation (guarded) → Regrowth (guarded) → Healing Touch (innate, no guard needed)
- Healing Touch correctly has no guard (learned at level 1)

### 5. druidControl() Edge Cases
- Beast/Dragonkin target without Hibernate learned: correctly falls through to Entangling Roots check (if available) rather than no-op
- No spells available: function gracefully does nothing, no error

### 6. druidDefend() Barkskin Guard
The guard `isSpellExist('Barkskin', 'spell')` is correct. The `barkskin()` method dynamically selects `'Barkskin'` vs `'Barkskin (Feral)'` based on the druid's current form, and at the point of this guard, the druid is in caster form, so the base `'Barkskin'` spell is what would be cast.

---

_Reviewed: 2026-07-20T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_