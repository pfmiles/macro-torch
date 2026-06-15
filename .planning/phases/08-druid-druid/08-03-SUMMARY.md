# Plan 08-03 Summary: Priest + Warlock Class Refactoring

**Phase:** 08-druid-druid
**Plan:** 03
**Date:** 2026-06-15
**Status:** Complete

## Tasks Executed

### Task 1: Create Priest class definition, combat, and utility files
**Commit:** `87dfb35`
**Files created:**
- `classes/priest/Priest.lua` (127 lines) -- Class definition with classMetatable + PRIEST_FIELD_FUNC_MAP + 7 skill methods with locale tables + registerPlayerClass + 10 SelfTest registrations + SpellTrace placeholder
- `classes/priest/combat.lua` (75 lines) -- priestRangedAtk (CastSpellByName('Holy Fire') replaced with player.holy_fire()) + priestAtk (unchanged)
- `classes/priest/utility.lua` (68 lines) -- priestBuffs/priestDebuffs/priestCtrl/priestHeal; CastSpellByName for Heal/Lesser Heal replaced with player.heal()/player.lesser_heal(); 4 castIfBuffAbsent calls preserved

**Skill methods created (7):**
| Method | Type | Locale Table |
|--------|------|--------------|
| holy_fire | A (enemy) | {en='Holy Fire', zh='神圣之火'} |
| shadow_word_pain | A (enemy) | {en='Shadow Word: Pain', zh='暗言术：痛'} |
| inner_fire | B (self) | {en='Inner Fire', zh='心灵之火'} |
| power_word_fortitude | C (flexible) | {en='Power Word: Fortitude', zh='真言术：韧'} |
| heal | C (flexible) | {en='Heal', zh='治疗术'} |
| lesser_heal | C (flexible) | {en='Lesser Heal', zh='次级治疗术'} |
| renew | C (flexible) | {en='Renew', zh='恢复'} |

**SelfTest registrations:** 10 (3 infra + 7 skill methods)

### Task 2: Create Warlock class definition and combat files
**Commit:** `20585e8`
**Files created:**
- `classes/warlock/Warlock.lua` (99 lines) -- Class definition with classMetatable + WARLOCK_FIELD_FUNC_MAP + 4 skill methods with locale tables (for future migration) + registerPlayerClass + 7 SelfTest registrations + SpellTrace placeholder
- `classes/warlock/combat.lua` (93 lines) -- All 6 original functions preserved; all 5 castIfBuffAbsent calls preserved unchanged; NOTE comment about preservation at top

**Skill methods created (4):**
| Method | Type | Locale Table |
|--------|------|--------------|
| immolate | A (enemy) | {en='Immolate', zh='献祭'} |
| corruption | A (enemy) | {en='Corruption', zh='腐蚀术'} |
| curse_of_agony | A (enemy) | {en='Curse of Agony', zh='痛苦诅咒'} |
| demon_skin | B (self) | {en='Demon Skin', zh='恶魔皮肤'} |

**SelfTest registrations:** 7 (3 infra + 4 skill methods)

### Task 3: Create Priest/Warlock subdirectories
**Commit:** (directories created before file creation)
- `classes/priest/` directory created
- `classes/warlock/` directory created

## Verification Results

| Check | Expected | Actual |
|-------|----------|--------|
| Priest: classMetatable + PRIEST_FIELD_FUNC_MAP | 1 | 1 |
| Priest: registerPlayerClass("Priest", ...) | 1 | 1 |
| Priest: SelfTest:register | >= 10 | 10 |
| Priest: skill methods | >= 7 | 7 |
| Priest: player.holy_fire() in combat.lua | >= 1 | 1 |
| Priest: CastSpellByName('Holy Fire') in combat.lua | 0 | 0 |
| Priest: player.heal() in utility.lua | >= 1 | 1 |
| Priest: player.lesser_heal() in utility.lua | >= 1 | 1 |
| Priest: castIfBuffAbsent in utility.lua | >= 4 | 4 |
| Warlock: classMetatable + WARLOCK_FIELD_FUNC_MAP | 1 | 1 |
| Warlock: registerPlayerClass("Warlock", ...) | 1 | 1 |
| Warlock: SelfTest:register | >= 7 | 7 |
| Warlock: skill methods | >= 4 | 4 |
| Warlock: castIfBuffAbsent in combat.lua | >= 4 | 5 |
| Warlock: CastSpellByName in combat.lua | 0 | 0 |
| Warlock: wlk functions | 6 | 6 |

## Design Decisions

- **Priest healing spells as Type C**: heal, lesser_heal, renew, power_word_fortitude are all Type C (flexible target) per the plan, exposing the onSelf parameter for future use with friendly target selection
- **Warlock skill methods for future migration**: All Warlock spells currently use castIfBuffAbsent (no CastSpellByName in original). Skill methods are created for future migration; combat.lua preserves all castIfBuffAbsent calls unchanged per CONTEXT.md direction
- **castIfBuffAbsent preserved**: As specified in the plan and CONTEXT.md, castIfBuffAbsent calls are preserved for Power Word: Fortitude, Inner Fire, Shadow Word: Pain, Renew (Priest) and Immolate, Corruption, Curse of Agony, Demon Skin (Warlock)
- **Priest healing threshold logic preserved**: priestHeal() retains >440 Heal, >140 Lesser Heal, else Renew logic unchanged

## Phase 08 Progress

| Plan | Classes | Files | Status |
|------|---------|-------|--------|
| 08-01 | Hunter (3) + Warrior (3) | 6 | Complete |
| 08-02 | Rogue (2) + Mage (2) | 4 | Complete |
| 08-03 | Priest (3) + Warlock (2) | 5 | Complete |
| 08-04 | build_order.txt + cleanup | -- | Pending |

Wave 1 (3 plans, 15 files) is now complete. Wave 2 (08-04: build system update and old file deletion) remains.