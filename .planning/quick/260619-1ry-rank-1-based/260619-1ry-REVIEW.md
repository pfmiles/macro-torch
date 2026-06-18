---
phase: quick-260619-1ry-rank-1-based
reviewed: 2026-06-19T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - biz_util.lua
  - entity/Player.lua
  - classes/druid/Druid.lua
  - classes/hunter/Hunter.lua
  - classes/mage/Mage.lua
  - classes/priest/Priest.lua
  - classes/rogue/Rogue.lua
  - classes/warlock/Warlock.lua
  - classes/warrior/Warrior.lua
findings:
  critical: 1
  warning: 1
  info: 3
  total: 5
status: issues_found
---

# Phase quick-260619-1ry-rank-1-based: Code Review Report

**Reviewed:** 2026-06-19T00:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

This review covers the "skill casting with optional rank parameter" feature. The changes introduce `macroTorch.getSpellIdByNameRank` to select spellbook entries by rank (1-based), and thread an optional `rank` parameter through 88 class skill methods into `_castSpell`.

The core design (nil defaults to highest rank, 1-based rank indexing) is sound. However, there are two behavioral bugs in the self-cast path and one design inconsistency between localization and rank self-cast syntax. Several smaller quality issues (dead/invariant conditions) from the surrounding codebase were also noted.

## Critical Issues

### CR-01: Self-cast with rank=1 broken: spellbook-computed rank syntax never emitted for rank 1

**File:** `entity/Player.lua:81-84`
**Issue:** The self-cast branch applies a "(Rank N)" suffix only when `rank > 1`:
```lua
if rank and rank > 1 then
    CastSpellByName(spellName .. "(Rank " .. rank .. ")", true)
else
    CastSpellByName(spellName, true)
end
```
This means calling a self-cast skill with `rank=1` explicitly sends the bare spell name to `CastSpellByName`. In WoW 1.12.1, `CastSpellByName("Bear Form")` always casts the **highest** rank (the same behavior as the old code). So explicit `rank=1` does NOT force the lowest rank for self-cast skills -- it silently degrades to highest-rank.

The non-self path (via `obj.cast` -> `macroTorch.castSpellByName` -> `getSpellIdByNameRank`) correctly selects spell ID index for any explicit rank value including 1, because it uses `CastSpell(spellId, bookType)` rather than string-based `CastSpellByName`.

This is inconsistent: calling `player.cat_form('safe', 1)` traverses the self-cast branch and casts the highest rank (wrong), while calling `player.claw('safe', 1)` traverses the non-self branch and correctly casts rank 1.

**Fix:** Remove the `rank > 1` guard so all explicit rank values get the suffix:
```lua
if rank then
    CastSpellByName(spellName .. "(Rank " .. rank .. ")", true)
else
    CastSpellByName(spellName, true)
end
```

---

## Warnings

### WR-01: Self-cast rank syntax incompatible with localized spell names

**File:** `entity/Player.lua:81` and `entity/Player.lua:44-49`
**Issue:** The self-cast path constructs the spell string as `spellName .. "(Rank " .. rank .. ")"`, where `spellName` is selected at runtime from `localeNames.zh` or `localeNames.en` based on locale. When the client locale is `zhCN`, `spellName` contains a Chinese name such as `"熊形态"`, and the constructed string becomes:
```
熊形态(Rank 1)
```

WoW 1.12.1's `CastSpellByName` with a rank suffix expects the **English** rank format (`"Bear Form(Rank 1)"`) even on localized clients. The `"(Rank N)"` suffix is part of the English spellbook API convention and does not localize. This means self-cast with explicit rank will fail to find the spell on zhCN clients when using the zhCN name plus an English-format rank suffix.

The non-self path does not have this problem because it resolves the spellbook index via `getSpellIdByNameRank` and calls `CastSpell(spellId, 'spell')` by numeric ID, which is locale-independent.

**Fix:** For the self-cast path with explicit rank, always use the English spell name for the CastSpellByName call:
```lua
if onSelf then
    if rank then
        -- Always use English name for CastSpellByName rank suffix syntax
        CastSpellByName(localeNames.en .. "(Rank " .. rank .. ")", true)
    else
        CastSpellByName(spellName, true)
    end
else
```
This ensures the rank suffix string format matches what the WoW client expects regardless of locale.

---

## Info

### IN-01: `getSpellIdByNameRank` iterates the full spellbook for every call (engineering note, not a bug)

**File:** `biz_util.lua:41-61`
**Issue:** `getSpellIdByNameRank` builds a table of all matching spell IDs by iterating the spellbook completely. While the spellbook in WoW 1.12.1 is small (typically under 200 entries) and the previous `getSpellIdByName` already did this scan, the new function rebuilds the `ids` table from scratch on every call instead of short-circuiting when the requested rank is found. This is not a correctness bug given the small N, but the pattern differs from the simpler single-match scan in `getSpellIdByName` and could benefit from a comment noting the trade-off.

**Fix:** Either add a comment or implement early return when `tableLen(ids) == rank`:
```lua
function macroTorch.getSpellIdByNameRank(spellName, bookType, rank)
    local ids = {}
    local i = 1
    while true do
        local ok, sName, spellRank = pcall(GetSpellName, i, bookType)
        if not ok or not sName then
            break
        end
        if macroTorch.equalsIgnoreCase(sName, spellName) then
            table.insert(ids, i)
            if rank and macroTorch.tableLen(ids) == rank then
                break  -- early return: found the requested rank
            end
        end
        i = i + 1
    end
    -- rest unchanged...
```

### IN-02: `castSpellByName` signature change could break callers not passing `bookType`

**File:** `biz_util.lua:83-89`
**Issue:** The original `macroTorch.castSpellByName` had the signature `(spellName, bookType)`. The new signature is `(spellName, bookType, rank)`. Callers that previously called `macroTorch.castSpellByName(spellName)` (without `bookType`) will now have `bookType` set to `nil`. This flows through to `getSpellIdByNameRank` which passes `nil` as `bookType` to `GetSpellName`, and to `CastSpell(spellId, nil)`. I reviewed all call sites and found that all current callers pass `'spell'` or `'pet'` explicitly, so there is no active bug. However, the implicit contract (bookType defaults to nil rather than 'spell') is fragile for future callers.

**Fix:** Consider defaulting `bookType` to `'spell'`:
```lua
function macroTorch.castSpellByName(spellName, bookType, rank)
    bookType = bookType or 'spell'
    local spellId = macroTorch.getSpellIdByNameRank(spellName, bookType, rank)
    if not spellId then
        return
    end
    CastSpell(spellId, bookType)
end
```
(No active bug; informational only.)

### IN-03: `call_pet` does not propagate `rank` parameter (by design, but worth noting)

**File:** `classes/hunter/Hunter.lua:63-68`
**Issue:** The Hunter `call_pet` method accepts `mode` but no `rank` parameter. Its internal `_castSpell` calls omit the `rank` argument entirely. This is a deliberate design choice since Call Pet and Dismiss Pet are single-rank spells that should always use their only rank. However, every other class method (87 of 88) accepts the `rank` parameter -- this is the sole exception. The inconsistency is harmless but a comment explaining the rationale would help future maintainers.

**Fix:** Add a comment above `call_pet` function declaration:
```lua
-- Call Pet / Dismiss Pet are single-rank spells, rank parameter intentionally omitted
function obj.call_pet(mode)
```

---

_Reviewed: 2026-06-19T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_