---
phase: 05-druid-player-cast-druid
plan: 02
subsystem: classes/druid
tags: [skill-methods, locale, refactoring, druid]
requires:
  - 05-01 (Player._castSpell infrastructure)
provides:
  - Druid skill method surface (~43+ methods)
  - Form-agnostic skill interfaces per D-04
affects:
  - classes/druid/Druid.lua
tech-stack:
  added: []
  patterns:
    - Three skill method signatures (Type A/B/C) for target type differentiation
    - Inline locale tables per D-02
    - Function references for dynamic energy costs
    - Fixed numeric costs for bear rage and cat fixed-cost skills
key-files:
  created: []
  modified:
    - classes/druid/Druid.lua (218 insertions, 19 deletions)
decisions:
  - D-02: "Inline locale tables {en, zh} used in every method — no centralized constants"
  - D-04: "All 53 Druid skill methods centralized in Druid:new() as form-agnostic interface"
  - D-07: "Three signature types: Type A (onSelf=false, 24 methods), Type B (onSelf=true, 20 methods), Type C (onSelf exposed, 9 methods)"
  - D-08: "resourceCost dual-mode: function refs for cat energy, fixed numbers for bear rage, nil for caster mana"
  - "Bear form rage costs: fixed numbers (MAUL=10, SWIPE=15, etc.) — dynamic functions deferred per RESEARCH.md Open Question 1"
  - "Caster form skills: nil resourceCost — preserves existing no-mana-check behavior"
  - "ferocious_bite covers both cat and bear forms — 'Savage Bite' is bear form FB per RESEARCH.md line 676"
metrics:
  duration: "~60s"
  completed: "2026-06-13"
---

# Phase 05 Plan 02: Druid Skill Method Definitions Summary

Add 53 Druid skill methods as typed object method interfaces inside `Druid:new()`, replacing the old string-based `player.cast()` pattern and removing legacy method stubs.

## Implementation Summary

**Objective achieved:** All ~43+ Druid skill methods are now defined in `classes/druid/Druid.lua`'s `Druid:new()` constructor. Each method is a 1-line thin wrapper forwarding parameters to `self:_castSpell(...)` with inline locale tables (`{ en = '...', zh = '...' }`). Old `obj.prowl()` and `obj.trackHumanoids()` methods without mode parameters removed and replaced by Type B skill methods. Commented-out `obj.cast()` block removed per Pitfall 2 to prevent accidental uncommenting shadowing `Player.cast()`.

## Tasks Executed

### Task 1: Remove old prowl/trackHumanoids methods and commented-out cast block

Removed three legacy blocks from `Druid:new()`:
1. **Lines 22-27:** Commented-out `obj.cast(spellName, onSelf)` block — removal prevents shadowing `Player.cast()` if uncommented
2. **Lines 85-89:** Old `obj.prowl()` method without mode parameter — replaced by Type B `obj.prowl(mode)` in Task 2
3. **Lines 91-95:** Old `obj.trackHumanoids()` method without mode parameter — replaced by Type B `obj.track_humanoids(mode)` in Task 2

After removal, `Druid:new()` flows cleanly: `local obj = {}` -> `setmetatable(...)` -> `showEnergyUsageSet`.

**Commit:** b275e0f

### Task 2: Add all 53 Druid skill methods to Druid:new()

Inserted 53 skill methods between `setmetatable` and `showEnergyUsageSet`, organized by type and form:

**Type A — Enemy target only (onSelf=false): 24 methods**
- Cat form (9): claw, shred, rake, rip, ferocious_bite, pounce, cower, faerie_fire_feral, ravage
- Bear form (7): growl, bash, swipe, maul, demoralizing_roar, feral_charge, challenging_roar
- Caster form (8): wrath, moonfire, starfire, entangling_roots, hibernate, faerie_fire, insect_swarm, soothe_animal

**Type B — Self target only (onSelf=true): 20 methods**
- Forms (5): bear_form, dire_bear_form, cat_form, travel_form, aquatic_form
- Self buffs (15): prowl, dash, tiger_fury, barkskin, track_humanoids, natures_swiftness, tranquility, hurricane, innervate, rebirth, frenzied_regeneration, enrage, reshift, berserk, natures_grasp

**Type C — Flexible target (onSelf exposed): 9 methods**
- healing_touch, regrowth, rejuvenation, remove_curse, abolish_poison, cure_poison, mark_of_the_wild, gift_of_the_wild, thorns

**Resource cost conventions:**
- Cat energy dynamic: `macroTorch.computeClaw_E`, `computeShred_E`, `computeRake_E`, `computeTiger_E` (function references)
- Cat energy fixed: 30 (Rip), 35 (Ferocious Bite), 50 (Pounce/Ravage), 20 (Cower), 0 (FF feral)
- Bear rage fixed: 10 (Growl, Bash, Maul, Demoralizing Roar, Frenzied Regeneration), 15 (Swipe, Challenging Roar)
- Feral Charge: 25 range, nil cost
- Caster mana: nil (no mana check, preserves existing behavior)
- Self buffs: 0 cost for prowl, dash, barkskin, track_humanoids, natures_swiftness, innervate, enrage, reshift, berserk

**Commit:** 164e953

## Verification Results

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Skill method count | >= 43 | 53 | PASS |
| No old `buffed('Prowl')` | 0 | 0 | PASS |
| No old `buffed('Track Humanoids')` | 0 | 0 | PASS |
| No commented `obj.cast` | 0 | 0 | PASS |
| `obj.claw()` present | 1 | 1 | PASS |
| `obj.prowl()` present | 1 | 1 | PASS |
| `obj.mark_of_the_wild()` present | 1 | 1 | PASS |
| `obj.faerie_fire_feral` + `obj.faerie_fire` distinct | 2 separate | 2 separate | PASS |
| Build (`./build.sh`) | exit 0 | Build OK | PASS |
| SM_Extend.lua contains skill methods | present | present | PASS |

## Deviations from Plan

None — plan executed exactly as written.

- Commented-out `obj.cast()` block removed as specified
- Old `obj.prowl()` and `obj.trackHumanoids()` removed as specified
- All 53 skill methods added (plan stated "~43" as a minimum; RESEARCH.md mapping yields exactly 53 including ravage, berserk, natures_grasp)
- All Type A methods use `onSelf=false`, Type B use `onSelf=true`, Type C expose `onSelf` parameter

## Known Stubs

None introduced by this plan. Pre-existing TODOs (wolfheart enchant, bear form separation) remain in the `catAtk()` function body and are out of scope for this plan.

## Threat Flags

None. This plan is pure code addition with no new security surface — all methods forward to existing `_castSpell` infrastructure implemented in Plan 05-01.

## Dependency Graph

- **Requires:** Phase 05 Plan 01 (`_castSpell`, `_isInRange`, `_hasResource` in Player base class)
- **Provides:** Complete Druid skill method surface for Plans 05-03 (cat.lua), 05-04 (bear.lua), 05-05 (utility.lua) call-site replacements

## Next Steps

Subsequent plans (05-03, 05-04, 05-05) replace `player.cast()` call sites and delete safe/ready wrapper functions in `cat.lua`, `bear.lua`, and `utility.lua`, using the skill methods defined here.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| classes/druid/Druid.lua modified | FOUND |
| 05-02-SUMMARY.md created | FOUND |
| Commit b275e0f (Task 1) | FOUND |
| Commit 164e953 (Task 2) | FOUND |