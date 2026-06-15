---
phase: 08-druid-druid
verified: 2026-06-15T12:30:00Z
status: human_needed
score: 27/27 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Verify all 7 Rogue English skill names (Pick Pocket, Ghostly Strike, Hemorrhage, Sinister Strike, Backstab, Vanish, Preparation) match actual Turtle WoW 1.12.1 English client spell names"
    expected: "All 7 English names correspond to exact in-game spell names on the English client. The file contains an [ASSUMED] comment at line 129 of classes/rogue/Rogue.lua documenting this uncertainty."
    why_human: "Cannot verify English client spell names without access to a Turtle WoW English client. The Chinese names are confirmed correct from original code."
  - test: "Log into game as each of the 6 classes (Hunter, Warrior, Rogue, Mage, Priest, Warlock) and verify SelfTest output in chat frame"
    expected: "For each class, all SelfTest registrations pass (FIELD_FUNC_MAP, singleton existence, registry entry, individual skill method existence). Only the summary line appears for passing tests. No red (error) or yellow (warning) output for registered class tests."
    why_human: "SelfTest:run() requires actual WoW 1.12.1 client environment. Cannot verify in-game behavior programmatically."
  - test: "Verify that build_order.txt's 19 non-comment class file paths (4 druid + 15 new) all resolve to existing files"
    expected: "All 19 paths are valid relative to the repository root. The build.sh strict mode already enforces this, but manual verification confirms no missing files from git."
    why_human: "build.sh already validates this, but human spot-check of individual paths confirms directory layout matches expectations from ROADMAP.md."
---

# Phase 8: non-Druid Class Architecture Refactoring Verification Report

**Phase Goal:** Refactor all 6 non-Druid class files (Hunter, Warrior, Rogue, Mage, Priest, Warlock) to align with the Druid architecture pattern -- class subdirectories, classMetatable + FIELD_FUNC_MAP + registerPlayerClass, skill methods with _castSpell + locale tables, SpellTrace:register, SelfTest:register, CastSpellByName replaced with skill method calls, build_order.txt updated, old flat files deleted.

**Verified:** 2026-06-15
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | D-05, D-06: All 6 class skill methods use _castSpell with locale tables ({en, zh}), Type A/B/C classification, resourceCost support | VERIFIED | All 15 files audited. Hunter: 10 methods, Warrior: 17, Rogue: 7, Mage: 3, Priest: 7, Warlock: 4. All use obj._castSpell({en=..., zh=...}, mode, range, cost, onSelf). Charge (Warrior) uses range=25. Type C skills (Priest heal/lesser_heal/renew/power_word_fortitude) expose onSelf parameter. |
| 2 | D-07: 6 subdirectories created at classes/{hunter,warrior,rogue,mage,priest,warlock}/ with identical depth to classes/druid/ | VERIFIED | All 6 directories exist with lowercase naming. Directory contents: hunter/ (3 files), warrior/ (3), rogue/ (2), mage/ (2), priest/ (3), warlock/ (2). |
| 3 | Hunter has classMetatable + HUNTER_FIELD_FUNC_MAP + registerPlayerClass in classes/hunter/Hunter.lua | VERIFIED | Line 22: `setmetatable(obj, macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP"))`. Line 75: `macroTorch.HUNTER_FIELD_FUNC_MAP = {...}`. Line 81: `macroTorch.registerPlayerClass("Hunter", macroTorch.Hunter)`. |
| 4 | Hunter combat logic in classes/hunter/combat.lua uses skill methods not CastSpellByName | VERIFIED | 0 CastSpellByName in hunter/combat.lua. All calls use player.raptor_strike('safe'), player.mongoose_bite('safe'), player.hunters_mark(), player.arcane_shot('safe'), player.multi_shot('safe'), player.disengage(). |
| 5 | Hunter utility functions (hunterSting, hunterCtrl) in classes/hunter/utility.lua use skill methods | VERIFIED | hunterSting: player.serpent_sting('ready'). hunterCtrl: player.wing_clip('ready'), player.concussive_shot('ready'). |
| 6 | Warrior has classMetatable + WARRIOR_FIELD_FUNC_MAP + registerPlayerClass in classes/warrior/Warrior.lua | VERIFIED | Line 22: `setmetatable(obj, macroTorch.classMetatable(self, "WARRIOR_FIELD_FUNC_MAP"))`. Line 98: `macroTorch.WARRIOR_FIELD_FUNC_MAP = {...}`. Line 104: `macroTorch.registerPlayerClass("Warrior", macroTorch.Warrior)`. |
| 7 | Warrior combat logic in classes/warrior/combat.lua uses skill methods not CastSpellByName (for spells) | VERIFIED | Spell cast replaced with skill methods: throw(), taunt(), revenge(), sunder_armor(), shield_slam(), cleave(), charge(). CastShapeshiftForm preserved for stance changes (2 calls). castIfBuffAbsent preserved for Rend/Demoralizing Shout/Thunder Clap (5 calls across combat + utility). 1 commented-out CastSpellByName('Slam') on line 78. 4 CastSpellByName('Battle Stance'/'Defensive Stance') preserved in utility.lua as stance changes per CONTEXT.md direction. |
| 8 | Warrior utility functions in classes/warrior/utility.lua maintain original logic with skill method calls | VERIFIED | bloodrage(), hamstring(), charge(), shield_bash(), disarm(), shield_wall() all use skill methods. castIfBuffAbsent for Shield Block/Battle Shout preserved. Stance changes (Battle/Defensive Stance) kept as CastSpellByName. |
| 9 | Rogue has classMetatable + ROGUE_FIELD_FUNC_MAP + registerPlayerClass in classes/rogue/Rogue.lua | VERIFIED | Line 22: `setmetatable(obj, macroTorch.classMetatable(self, "ROGUE_FIELD_FUNC_MAP"))`. Line 58-62: `ROGUE_FIELD_FUNC_MAP` with comboPoints field. Line 65: `macroTorch.registerPlayerClass("Rogue", macroTorch.Rogue)`. |
| 10 | Rogue combat logic in classes/rogue/combat.lua uses skill methods not CastSpellByName | VERIFIED | rogueBattle: player.ghostly_strike(), player.hemorrhage(), player.sinister_strike(). rogueBattleBack: player.backstab(). readyVanish: player.vanish(), player.preparation(). pickPocketBeforeCast: player.pick_pocket() for hardcoded call, CastSpellByName(spell) for variable parameter (deferred, documented per CONTEXT.md). lockNearestEnemyThenCast: CastSpellByName(sp) preserved (deferred, documented per CONTEXT.md). |
| 11 | Mage has classMetatable + MAGE_FIELD_FUNC_MAP + registerPlayerClass in classes/mage/Mage.lua | VERIFIED | Line 22: `setmetatable(obj, macroTorch.classMetatable(self, "MAGE_FIELD_FUNC_MAP"))`. Line 43-45: `MAGE_FIELD_FUNC_MAP` (empty). Line 49: `macroTorch.registerPlayerClass("Mage", macroTorch.Mage)`. |
| 12 | Mage combat logic in classes/mage/combat.lua uses skill methods where applicable, preserves castIfBuffAbsent | VERIFIED | mageRangedAtk/mageMeleeAtk: player.frostbolt() replaces CastSpellByName('Frostbolt') (2 sites). 0 CastSpellByName in combat.lua. mageBuffs: 2 castIfBuffAbsent calls for Frost Armor and Arcane Intellect preserved per CONTEXT.md. |
| 13 | Priest has classMetatable + PRIEST_FIELD_FUNC_MAP + registerPlayerClass in classes/priest/Priest.lua | VERIFIED | Line 22: `setmetatable(obj, macroTorch.classMetatable(self, "PRIEST_FIELD_FUNC_MAP"))`. Line 59-62: `PRIEST_FIELD_FUNC_MAP` (empty). Line 65: `macroTorch.registerPlayerClass("Priest", macroTorch.Priest)`. |
| 14 | Priest combat logic in classes/priest/combat.lua uses skill methods not CastSpellByName | VERIFIED | priestRangedAtk: player.holy_fire() replaces CastSpellByName('Holy Fire'). 0 CastSpellByName('Holy Fire'). 1 commented-out CastSpellByName('Starshards') on line 33. |
| 15 | Priest utility functions (healing, buffs, debuffs, ctrl) in classes/priest/utility.lua use skill methods where applicable, preserve castIfBuffAbsent | VERIFIED | priestHeal: player.heal() and player.lesser_heal(). Threshold logic (>440 Heal, >140 Lesser Heal, else Renew) preserved. 4 castIfBuffAbsent calls preserved (Power Word: Fortitude, Inner Fire, Shadow Word: Pain, Renew). priestBuffs/priestDebuffs: no CastSpellByName, all castIfBuffAbsent. |
| 16 | Warlock has classMetatable + WARLOCK_FIELD_FUNC_MAP + registerPlayerClass in classes/warlock/Warlock.lua | VERIFIED | Line 22: `setmetatable(obj, macroTorch.classMetatable(self, "WARLOCK_FIELD_FUNC_MAP"))`. Line 46-49: `WARLOCK_FIELD_FUNC_MAP` (empty). Line 52: `macroTorch.registerPlayerClass("Warlock", macroTorch.Warlock)`. |
| 17 | Warlock combat logic in classes/warlock/combat.lua preserves castIfBuffAbsent pattern, adds curse/buff/ctrl functions | VERIFIED | 5 castIfBuffAbsent calls preserved (Immolate, Corruption, Curse of Agony, Demon Skin). 0 CastSpellByName (none in original either). 6 wlk functions present: wlkCurses, wlkRangedAtk, wlkMeleeAtk, wlkBuffs, wlkAtk, wlkCtrl. NOTE comment at top documents castIfBuffAbsent preservation. |
| 18 | D-07: All 6 old flat files replaced by subdirectory paths -- directory depth matches classes/druid/ | VERIFIED | All 6 old flat files deleted. build_order.txt contains exactly 15 subdirectory paths across 6 class directories, 0 old flat paths. |
| 19 | build_order.txt lists all new subdirectory paths and no old flat paths | VERIFIED | 15 subdirectory paths verified (hunter:3, warrior:3, rogue:2, mage:2, priest:3, warlock:2). 0 old paths. 19 total non-comment class paths (4 druid + 15 Phase 8). |
| 20 | build.sh succeeds with new file paths | VERIFIED | `./build.sh` exit code 0. SM_Extend.lua generated successfully. |
| 21 | All 6 old flat classes/Xxx.lua files are deleted | VERIFIED | All 6 files confirmed deleted: Hunter.lua, Warrior.lua, Rogue.lua, Mage.lua, Priest.lua, Warlock.lua. |
| 22 | Old flat file paths replaced by subdirectory paths in build_order.txt | VERIFIED | grep confirms 0 occurrences of `classes/(Hunter|Warrior|Rogue|Mage|Priest|Warlock)\.lua` in build_order.txt. |
| 23 | REQ-08-CLASS-DEF: All 6 classes have classMetatable + FIELD_FUNC_MAP + registerPlayerClass | VERIFIED | Each of 6 class definition files passes the triad check: classMetatable (1), FIELD_FUNC_MAP (1), registerPlayerClass (1). Total 7 registerPlayerClass calls across all files (Druid + 6 Phase 8). |
| 24 | REQ-08-SKILL-METHODS: CastSpellByName replaced with _castSpell skill methods with locale support | VERIFIED | Total 48 skill methods across 6 classes (Hunter:10, Warrior:17, Rogue:7, Mage:3, Priest:7, Warlock:4). Residual CastSpellByName in new code paths: 4 stance changes (Warrior, intentional), 3 variable-parameter utilities (Rogue, documented deferral per CONTEXT.md). 1 commented-out line. All actual spell casts use skill methods. |
| 25 | REQ-08-SPELLTRACE: Each class has SpellTrace:register for applicable skills | VERIFIED | Hunter: SpellTrace:register('Serpent Sting', {immune=true, debuffTexture='Ability_Hunter_SniperShot'}). All other classes: placeholder comments ("no ... spells currently traced") -- correct since original code had no spell trace calls. |
| 26 | REQ-08-SELFTEST: Each class has SelfTest:register entries | VERIFIED | Hunter:13, Warrior:20, Rogue:11, Mage:6, Priest:10, Warlock:7. Total 67 SelfTest registrations. All use isOptional=true with UnitClass guard. All include FIELD_FUNC_MAP type check, singleton existence, PLAYER_CLASS_REGISTRY entry, and per-skill-method existence checks. |
| 27 | REQ-08-INITPLAYER: All 6 classes registered in PLAYER_CLASS_REGISTRY | VERIFIED | registerPlayerClass calls: Hunter, Warrior, Rogue, Mage, Priest, Warlock, Druid = 7 total. initPlayer() at core/class.lua:94 looks up UnitClass('player') in PLAYER_CLASS_REGISTRY and calls :new(). All 6 classes follow the exact pattern. |

**Score:** 27/27 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `classes/hunter/Hunter.lua` | Hunter class definition, 10 skill methods, HUNTER_FIELD_FUNC_MAP, singleton, registerPlayerClass, SpellTrace:register, SelfTest:register | VERIFIED | 156 lines. 10 skill methods with {en,zh} locale. SpellTrace:register('Serpent Sting',...). 13 SelfTest entries. |
| `classes/hunter/combat.lua` | hunterAtk + htOtMod refactored with skill methods | VERIFIED | 78 lines. 0 CastSpellByName. All safe/ready wrappers deleted. Player method calls: 15. |
| `classes/hunter/utility.lua` | hunterSting, hunterCtrl refactored with skill methods | VERIFIED | 32 lines (including license). 0 CastSpellByName. |
| `classes/warrior/Warrior.lua` | Warrior class definition, 17 skill methods, WARRIOR_FIELD_FUNC_MAP, singleton, registerPlayerClass, SelfTest:register | VERIFIED | 212 lines. 17 skill methods. 20 SelfTest entries. SpellTrace placeholder. |
| `classes/warrior/combat.lua` | wroAtk + 6 combat functions, CastShapeshiftForm preserved, castIfBuffAbsent preserved | VERIFIED | 147 lines. CastShapeshiftForm: 2 calls. castIfBuffAbsent: 3 calls. Skill methods used for all spells. |
| `classes/warrior/utility.lua` | 5 utility functions, stance changes preserved as CastSpellByName | VERIFIED | 80 lines. CastSpellByName: 4 stance-change calls (Battle/Defensive Stance). castIfBuffAbsent: 2 calls. Skill methods for bloodrage/hamstring/charge/shield_bash/disarm/shield_wall. |
| `classes/rogue/Rogue.lua` | Rogue class definition, 7 skill methods, ROGUE_FIELD_FUNC_MAP (comboPoints), singleton, registerPlayerClass, SelfTest:register | VERIFIED | 131 lines. 7 skill methods. comboPoints in FIELD_FUNC_MAP. 11 SelfTest entries. [ASSUMED] comment for English names. |
| `classes/rogue/combat.lua` | rogueAtk, rogueAtkBack, rogueSneak, rogueBattle, rogueBattleBack, pickPocketBeforeCast (preserved), readyVanish, lockNearestEnemyThenCast (deferred) | VERIFIED | 157 lines. Skill methods used: ghostly_strike, hemorrhage, sinister_strike, backstab, vanish, preparation, pick_pocket. CastSpellByName preserved in pickPocketBeforeCast (variable param) and lockNearestEnemyThenCast (deferred, documented). |
| `classes/mage/Mage.lua` | Mage class definition, 3 skill methods, MAGE_FIELD_FUNC_MAP, singleton, registerPlayerClass, SelfTest:register | VERIFIED | 86 lines. 3 skill methods. 6 SelfTest entries. SpellTrace placeholder. |
| `classes/mage/combat.lua` | mageAtk + mageRangedAtk + mageMeleeAtk + mageBuffs + mageCtrl, castIfBuffAbsent preserved | VERIFIED | 84 lines. player.frostbolt(): 2 sites. castIfBuffAbsent: 2 calls. 0 CastSpellByName. |
| `classes/priest/Priest.lua` | Priest class definition, 7 skill methods, PRIEST_FIELD_FUNC_MAP, singleton, registerPlayerClass, SelfTest:register | VERIFIED | 120 lines. 7 skill methods (Type C heal/lesser_heal/renew/power_word_fortitude with onSelf param). 10 SelfTest entries. |
| `classes/priest/combat.lua` | priestRangedAtk + priestAtk, CastSpellByName('Holy Fire') replaced | VERIFIED | 71 lines. player.holy_fire(): 1 call. 0 CastSpellByName('Holy Fire'). |
| `classes/priest/utility.lua` | priestBuffs, priestDebuffs, priestCtrl, priestHeal -- castIfBuffAbsent preserved, heal CastSpellByName replaced | VERIFIED | 59 lines. player.heal() and player.lesser_heal(). Threshold logic preserved. 4 castIfBuffAbsent calls. |
| `classes/warlock/Warlock.lua` | Warlock class definition, 4 skill methods, WARLOCK_FIELD_FUNC_MAP, singleton, registerPlayerClass, SelfTest:register | VERIFIED | 92 lines. 4 skill methods (for future migration). 7 SelfTest entries. SpellTrace placeholder. |
| `classes/warlock/combat.lua` | 6 wlk functions, all castIfBuffAbsent preserved | VERIFIED | 94 lines. 5 castIfBuffAbsent calls. 0 CastSpellByName. NOTE comment about preservation. |
| `build_order.txt` | Updated with 15 subdirectory paths, 0 old flat paths | VERIFIED | 51 lines. 15 Phase 8 paths + 4 Druid paths. 0 old flat paths. |
| `classes/Hunter.lua` (old) | DELETED | VERIFIED | Confirmed deleted. |
| `classes/Warrior.lua` (old) | DELETED | VERIFIED | Confirmed deleted. |
| `classes/Rogue.lua` (old) | DELETED | VERIFIED | Confirmed deleted. |
| `classes/Mage.lua` (old) | DELETED | VERIFIED | Confirmed deleted. |
| `classes/Priest.lua` (old) | DELETED | VERIFIED | Confirmed deleted. |
| `classes/Warlock.lua` (old) | DELETED | VERIFIED | Confirmed deleted. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| classes/hunter/Hunter.lua | core/class.lua | classMetatable + registerPlayerClass | VERIFIED | Line 22: `macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP")`. Line 81: `registerPlayerClass("Hunter", macroTorch.Hunter)`. |
| classes/hunter/combat.lua | classes/hunter/Hunter.lua | player.skill_method() calls | VERIFIED | 15 player.*() calls resolved through metatable chain: raptor_strike, mongoose_bite, hunters_mark, arcane_shot, multi_shot, disengage. |
| classes/warrior/Warrior.lua | core/class.lua | classMetatable + registerPlayerClass | VERIFIED | Line 22: `classMetatable(self, "WARRIOR_FIELD_FUNC_MAP")`. Line 104: `registerPlayerClass("Warrior",...)`. |
| classes/warrior/combat.lua | classes/warrior/Warrior.lua | macroTorch.player.skill_method() calls | VERIFIED | throw(), taunt(), revenge(), sunder_armor(), shield_slam(), cleave(), charge() all resolved through Warrior metatable. |
| classes/rogue/Rogue.lua | core/class.lua | classMetatable + registerPlayerClass | VERIFIED | Line 22: `classMetatable(self, "ROGUE_FIELD_FUNC_MAP")`. Line 65: `registerPlayerClass("Rogue",...)`. |
| classes/rogue/combat.lua | classes/rogue/Rogue.lua | macroTorch.player.skill_method() calls | VERIFIED | ghostly_strike(), hemorrhage(), sinister_strike(), backstab(), vanish(), preparation(), pick_pocket() resolved through Rogue metatable. |
| classes/mage/Mage.lua | core/class.lua | classMetatable + registerPlayerClass | VERIFIED | Line 22: `classMetatable(self, "MAGE_FIELD_FUNC_MAP")`. Line 49: `registerPlayerClass("Mage",...)`. |
| classes/mage/combat.lua | classes/mage/Mage.lua | player.frostbolt() calls | VERIFIED | 2 player.frostbolt() calls resolved through Mage metatable. |
| classes/priest/Priest.lua | core/class.lua | classMetatable + registerPlayerClass | VERIFIED | Line 22: `classMetatable(self, "PRIEST_FIELD_FUNC_MAP")`. Line 65: `registerPlayerClass("Priest",...)`. |
| classes/priest/combat.lua | classes/priest/Priest.lua | player.holy_fire() | VERIFIED | 1 player.holy_fire() call resolved through Priest metatable. |
| classes/priest/utility.lua | classes/priest/Priest.lua | player.heal(), player.lesser_heal() | VERIFIED | Both calls resolved through Priest metatable. |
| classes/warlock/Warlock.lua | core/class.lua | classMetatable + registerPlayerClass | VERIFIED | Line 22: `classMetatable(self, "WARLOCK_FIELD_FUNC_MAP")`. Line 52: `registerPlayerClass("Warlock",...)`. |
| build_order.txt | classes/{hunter,warrior,rogue,mage,priest,warlock}/ | build.sh file concatenation | VERIFIED | build.sh reads all 19 class paths in order. build succeeds (exit 0). SM_Extend.lua contains all classes. |
| All 6 class files | core/class.lua | PLAYER_CLASS_REGISTRY + initPlayer | VERIFIED | 7 registerPlayerClass calls in SM_Extend.lua (Druid + 6 Phase 8). initPlayer() at core/class.lua:94 looks up UnitClass('player') in registry. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| classes/hunter/combat.lua: hunterAtk | player skill methods | obj._castSpell -> WoW API CastSpellByName | FLOWING (WoW API) | The _castSpell infrastructure calls CastSpellByName internally -- this is the correct WoW addon pattern. The locale names flow to GetLocale() selection. |
| classes/warrior/combat.lua: wroAtk | player skill methods | obj._castSpell -> WoW API CastSpellByName | FLOWING (WoW API) | Same pattern. castIfBuffAbsent calls also ultimately use CastSpellByName internally (verified in entity/Player.lua). |
| classes/rogue/combat.lua: rogueBattle | player skill methods | obj._castSpell -> WoW API | FLOWING (WoW API) | No static returns. No hardcoded empty values. All skill methods delegate to _castSpell. |
| classes/mage/combat.lua: mageRangedAtk | player.frostbolt() | obj._castSpell -> WoW API | FLOWING (WoW API) | No stubs. |
| classes/priest/utility.lua: priestHeal | player.heal() / player.lesser_heal() | obj._castSpell -> WoW API | FLOWING (WoW API) | Healing threshold logic intact. |
| classes/warlock/combat.lua: wlkCurses | castIfBuffAbsent | macroTorch.castIfBuffAbsent in entity/Player.lua -> CastSpellByName | FLOWING (WoW API) | Preserved per CONTEXT.md. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| build.sh succeeds | `./build.sh` | exit code 0 | PASS |
| SM_Extend.lua contains all 6 class prototypes | `grep -c "macroTorch\.\(Hunter\|Warrior\|Rogue\|Mage\|Priest\|Warlock\) = macroTorch.Player:new()" SM_Extend.lua` | 6 | PASS |
| SM_Extend.lua has registerPlayerClass for all classes | `grep -c "registerPlayerClass" SM_Extend.lua` | 8 (1 infra def + 7 calls) | PASS |
| No old flat files remain | `test -f classes/Hunter.lua ...` for all 6 | All DELETED | PASS |
| All 6 directories exist | `ls classes/{hunter,warrior,rogue,mage,priest,warlock}/` | All exist | PASS |
| Hunter combat has no CastSpellByName | `grep -c "CastSpellByName" classes/hunter/combat.lua` | 0 | PASS |
| Warrior CastShapeshiftForm preserved | `grep -c "CastShapeshiftForm" classes/warrior/combat.lua` | 2 | PASS |
| Rogue pickPocketState preserved | `grep -c "pickPocketState" classes/rogue/combat.lua` | 3 | PASS |
| Mage castIfBuffAbsent preserved | `grep -c "castIfBuffAbsent" classes/mage/combat.lua` | 2 | PASS |
| Priest healing threshold preserved | `grep -c "440\|140" classes/priest/utility.lua` | 2 | PASS |
| Warlock has no CastSpellByName | `grep -c "CastSpellByName" classes/warlock/combat.lua` | 0 | PASS |
| No colon syntax in any new file | `grep -rn "self:" classes/{hunter,warrior,rogue,mage,priest,warlock}/ --include="*.lua"` excluding SpellTrace/SelfTest/classMetatable | 0 instances | PASS |

### Probe Execution

Step 7c: SKIPPED (no probe scripts declared in any PLAN or SUMMARY for this phase; this is a code-structure refactoring phase without migration probes)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REQ-08-CLASS-DEF | 08-01, 08-02, 08-03 | All 6 non-Druid classes have classMetatable + FIELD_FUNC_MAP + registerPlayerClass | SATISFIED | Each of 6 class definition files verified with all 3 elements. Total 7 registerPlayerClass calls (Druid + 6 Phase 8) in SM_Extend.lua. |
| REQ-08-SKILL-METHODS | 08-01, 08-02, 08-03 | All CastSpellByName calls replaced with skill methods | SATISFIED | 48 skill methods across 6 classes. Residual CastSpellByName: 4 stance changes (Warrior, intentional), 3 variable-param utilities (Rogue, documented deferral), 1 commented-out line. |
| REQ-08-SPELLTRACE | 08-01, 08-02, 08-03 | Each class has SpellTrace:register for applicable skills | SATISFIED | Hunter: Serpent Sting registered with immune=true, debuffTexture. Other classes: placeholder comments (no spells to trace in original code). |
| REQ-08-SELFTEST | 08-01, 08-02, 08-03 | Each class has SelfTest:register entries | SATISFIED | 67 SelfTest registrations total. All isOptional=true, UnitClass guard, FIELD_FUNC_MAP check, singleton check, registry check, per-skill checks. |
| REQ-08-BUILD | 08-04 | build_order.txt updated, build.sh succeeds | SATISFIED | 15 subdirectory paths, 0 old paths. build.sh exit 0. SM_Extend.lua verified with all 6 new class prototypes. |
| REQ-08-NO-FLAT | 08-04 | Old flat files deleted | SATISFIED | All 6 old files confirmed deleted. No residual flat files in classes/ directory. |
| REQ-08-INITPLAYER | 08-01, 08-02, 08-03 | All classes in PLAYER_CLASS_REGISTRY via registerPlayerClass | SATISFIED | 7 registerPlayerClass calls confirmed. initPlayer() factory function verified at core/class.lua:94. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| N/A | N/A | No TBD/FIXME/XXX markers found | None | N/A |
| N/A | N/A | No TODO/HACK/PLACEHOLDER markers found | None | N/A |
| N/A | N/A | No console.log implementations | None | N/A |
| N/A | N/A | No return null/empty stubs in user-facing code | None | N/A |

No anti-patterns detected. The empty FIELD_FUNC_MAP tables in Hunter, Warrior, Mage, Priest, and Warlock are intentional (no class-specific lazy-computed fields currently exist). These match the original code and are not stubs.

### Residual CastSpellByName Audit

| File | Line | Call | Classification |
|------|------|------|----------------|
| classes/warrior/utility.lua | 47 | `CastSpellByName('Battle Stance')` | Intentional -- stance change, not spell. Deferred per CONTEXT.md. |
| classes/warrior/utility.lua | 53 | `CastSpellByName('Battle Stance')` | Intentional -- stance change, not spell. Deferred per CONTEXT.md. |
| classes/warrior/utility.lua | 62 | `CastSpellByName('Defensive Stance')` | Intentional -- stance change, not spell. Deferred per CONTEXT.md. |
| classes/warrior/utility.lua | 70 | `CastSpellByName('Defensive Stance')` | Intentional -- stance change, not spell. Deferred per CONTEXT.md. |
| classes/warrior/combat.lua | 78 | `---CastSpellByName('Slam')` | Commented out -- not active code. |
| classes/rogue/combat.lua | 40 | `CastSpellByName(spell)` | Documented deferral -- pickPocketBeforeCast state machine with variable spell parameter. |
| classes/rogue/combat.lua | 46 | `CastSpellByName(spell)` | Documented deferral -- pickPocketBeforeCast state machine with variable spell parameter. |
| classes/rogue/combat.lua | 137 | `CastSpellByName(sp)` | Documented deferral -- lockNearestEnemyThenCast generic utility. |
| classes/rogue/combat.lua | 141 | `CastSpellByName(sp)` | Documented deferral -- lockNearestEnemyThenCast generic utility. |
| classes/priest/combat.lua | 33 | `-- CastSpellByName('Starshards')` | Commented out -- not active code. |

**Summary:** All 4 active CastSpellByName in Warrior are stance changes (Battle/Defensive Stance), intentionally preserved as WoW API calls rather than spells -- explicitly called out in PLAN 08-01 task 3 ("Stance changes are NOT skill methods"). All 4 active CastSpellByName in Rogue are in generic utility functions with variable spell name parameters, documented as deferred per CONTEXT.md. The 2 remaining are commented-out code. No active spell CastSpellByName remains in any new file.

### Human Verification Required

#### 1. Rogue English Skill Name Verification

**Test:** Open `classes/rogue/Rogue.lua` and verify all 7 English skill names in locale tables match actual Turtle WoW 1.12.1 English client spell names.

**Expected:** The following English names should correspond to exact in-game spell names: Pick Pocket, Ghostly Strike, Hemorrhage, Sinister Strike, Backstab, Vanish, Preparation.

**Why human:** Cannot verify English client spell names without access to Turtle WoW English client. The Chinese names are confirmed correct from original code. The file contains an [ASSUMED] comment at line 129 documenting this uncertainty. Plan 08-02 Task 3 is a checkpoint:human-verify for this, and the SUMMARY reports user approval, but the code still carries the [ASSUMED] marker.

#### 2. In-Game SelfTest Validation

**Test:** Log into game as each class (Hunter, Warrior, Rogue, Mage, Priest, Warlock) and verify SelfTest output appears in chat frame.

**Expected:** For each class, all SelfTest registrations pass (FIELD_FUNC_MAP existence, singleton existence, PLAYER_CLASS_REGISTRY entry, individual skill method existence). Only the summary line "[macro-torch] Self-test: X passed, 0 failed, 0 warnings" appears in chat.

**Why human:** SelfTest:run() requires the actual WoW 1.12.1 client environment. The framework and test registrations are structurally verified in this report, but runtime behavior can only be validated in-game.

### Gaps Summary

**No gaps found.** All 27 must-have truths are VERIFIED. All 7 requirements (REQ-08-CLASS-DEF through REQ-08-INITPLAYER) are SATISFIED. All artifacts pass existence (Level 1), substantive (Level 2), wired (Level 3), and data-flow (Level 4) checks.

The phase goal -- refactoring all 6 non-Druid classes to align with the Druid architecture pattern -- is achieved in the codebase.

**Status is human_needed** because 2 items require in-game verification that cannot be performed programmatically:
1. Rogue English skill name confirmation on Turtle WoW client
2. In-game SelfTest runtime validation across all 6 classes

### Build Output Verification

SM_Extend.lua (generated output) was verified:
- 6 new class prototypes confirmed: Hunter, Warrior, Rogue, Mage, Priest, Warlock
- 7 registerPlayerClass calls: Druid + 6 Phase 8 classes (+ 1 for the function definition itself = 8 total matches in the file)
- 0 errors from build.sh
- All functions concatenated in build_order.txt order

---

_Verified: 2026-06-15T12:30:00Z_
_Verifier: Claude (gsd-verifier)_