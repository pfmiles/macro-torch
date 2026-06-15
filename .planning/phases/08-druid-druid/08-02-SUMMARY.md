# Plan 08-02 Summary: Rogue + Mage Druid-Aligned Architecture Refactoring

## Status: COMPLETE

**Phase**: 08-druid-druid
**Plan**: 02
**Wave**: 1
**Date**: 2026-06-15

## Tasks Completed

| # | Task | Type | Status | Commit |
|---|------|------|--------|--------|
| 1 | Create Rogue class definition and combat files | auto | done | e2d2f47 |
| 2 | Create Mage class definition and combat files | auto | done | 3dd8abb |
| 3 | Verify Rogue English skill names | checkpoint:human-verify | resolved | N/A (user approved) |

## Artifacts Created

| File | Lines | Description |
|------|-------|-------------|
| `classes/rogue/Rogue.lua` | 131 | Rogue class definition: classMetatable, 7 skill methods, ROGUE_FIELD_FUNC_MAP (comboPoints), singleton, registerPlayerClass, SpellTrace placeholder, 11 SelfTest registrations |
| `classes/rogue/combat.lua` | 157 | Rogue combat: isTargetRogueFaint, pickPocketBeforeCast (state machine preserved), rogueSneak/rogueBattle/rogueAtk, rogueSneakBack/rogueBattleBack/rogueAtkBack, lockNearestEnemyThenCast, readyVanish, restoreIfNeeded |
| `classes/mage/Mage.lua` | 86 | Mage class definition: classMetatable, 3 skill methods, MAGE_FIELD_FUNC_MAP (empty), singleton, registerPlayerClass, SpellTrace placeholder, 6 SelfTest registrations |
| `classes/mage/combat.lua` | 84 | Mage combat: mageRangedAtk, mageMeleeAtk, mageBuffs (castIfBuffAbsent preserved), mageAtk, mageCtrl |

## Key Decisions

### Rogue
- **7 skill methods** created with locale tables {en, zh}: pick_pocket (Type A), ghostly_strike (Type A), hemorrhage (Type A), sinister_strike (Type A), backstab (Type A), vanish (Type B/self), preparation (Type B/self)
- **comboPoints** added to ROGUE_FIELD_FUNC_MAP (Rogue uses combo points like Druid)
- **pickPocketBeforeCast state machine** preserved (pickPocketState = 0/1), hardcoded CastSpellByName("偷窃") replaced with player.pick_pocket(), variable CastSpellByName(spell) calls kept as-is
- **lockNearestEnemyThenCast** kept as-is (generic utility with variable spell names, deferred migration)
- **English skill names** verified by user: Pick Pocket, Ghostly Strike, Hemorrhage, Sinister Strike, Backstab, Vanish, Preparation

### Mage
- **3 skill methods** created: frostbolt (Type A, range 30), frost_armor (Type B/self), arcane_intellect (Type C/flexible)
- **castIfBuffAbsent** calls for Frost Armor and Arcane Intellect preserved per CONTEXT.md directive
- Only **2 CastSpellByName('Frostbolt')** sites converted to player.frostbolt()
- Pet management (PetDefensiveMode, PetAttack) kept as-is

## Verification Results

All automated verification checks from the plan passed:
- Rogue.lua: classMetatable + ROGUE_FIELD_FUNC_MAP, registerPlayerClass("Rogue", ...), 7 skill methods, comboPoints in FIELD_FUNC_MAP
- Rogue combat.lua: player.ghostly_strike/hemorrhage/sinister_strike/backstab/vanish/preparation calls in place, pickPocketState preserved
- Mage.lua: classMetatable + MAGE_FIELD_FUNC_MAP, registerPlayerClass("Mage", ...), 3 skill methods
- Mage combat.lua: player.frostbolt() replaces CastSpellByName('Frostbolt'), castIfBuffAbsent preserved (2 calls)

## Threat Model

No new threats introduced — pure code structure refactoring within WoW 1.12.1 addon sandbox. No file I/O, no network, no dependency changes.