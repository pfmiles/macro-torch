---
phase: 05-druid-player-cast-druid
verified: "2026-06-13T12:00:00Z"
status: passed
score: 10/10 must-haves verified
overrides_applied: 0
---

# Phase 5: Druid 技能方法封装改造 — 验证报告

**Phase Goal:** Refactor `player.cast('SkillName')` string-based spell casting into typed skill object methods (`player.claw()`, `player.wrath('safe')`) with multi-locale support (en/zh). Druid pilot phase covering ~53 skill methods and ~32 call sites across 5 files.

**Verified:** 2026-06-13
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1   | `_castSpell` selects spell name from locale table based on `GetLocale()` | VERIFIED | `entity/Player.lua:40-48`: calls `GetLocale()`, maps `'zhCN'` to `localeNames.zh` with nil-fallback to `localeNames.en` |
| 2   | `_castSpell` returns false when mode is not 'raw' and spell is not ready | VERIFIED | `entity/Player.lua:51-55`: `if mode ~= 'raw' then if not self:isSpellReady(spellName) then return false end end` |
| 3   | `_castSpell` returns false when mode is 'safe' and target is out of range | VERIFIED | `entity/Player.lua:59-61`: `if mode == 'safe' then if range and not self:_isInRange(range) then return false end` |
| 4   | `_castSpell` returns false when mode is 'safe' and player lacks resource | VERIFIED | `entity/Player.lua:62-72`: `if resourceCost then ... if not self:_hasResource(cost) then return false end` |
| 5   | `_castSpell` calls `self:cast(spellName, onSelf or false)` and returns true on success | VERIFIED | `entity/Player.lua:76-77`: `self:cast(spellName, onSelf or false); return true` |
| 6   | `_isInRange` returns false when target is nil or does not exist | VERIFIED | `entity/Player.lua:84-85`: `if not macroTorch.target or not macroTorch.target.isExist then return false end` |
| 7   | `_isInRange` returns true for nil/0 range (melee) when target exists | VERIFIED | `entity/Player.lua:87-88`: `if type(range) ~= 'number' or range <= 0 then return true end` |
| 8   | `_hasResource` returns `self.mana >= cost` | VERIFIED | `entity/Player.lua:97-98`: `return self.mana >= cost` |
| 9   | 53 Druid skill methods defined as typed wrappers forwarding to `_castSpell` | VERIFIED | `grep -c "function obj\.\w\+(mode" classes/druid/Druid.lua` returns 53, all 1-line `return self:_castSpell(...)` wrappers with inline locale tables |
| 10  | Zero `player.cast()` calls remain in cat.lua, bear.lua, Druid.lua, utility.lua | VERIFIED | All four files: `grep -c "player\.cast("` returns 0 for each |

**Score:** 10/10 truths verified

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| R8 | 05-01, 05-02, 05-03, 05-04, 05-05 | Druid 猫德逻辑保持 | SATISFIED | All 7 core functions (keepFF, keepRake, keepRip, regularAttack, shouldCastRip, shouldUseBite, shouldUseShred) present in SM_Extend.lua; catAtk preserved as Druid instance method. Energy constants preserved (36 references). Note: `canDoReshift` was renamed to `shouldDoReshift` in Phase 2 refactoring -- same logic, cleaner name. |
| D-01 | 05-02, 05-03, 05-04, 05-05 | Full replacement of all `player.cast()` + safe/ready functions | SATISFIED | Zero `player.cast()` in all 4 Druid files. 5 safe/ready functions deleted from cat.lua (safeShred, readyShred, safeClaw, readyClaw, safePounce). 9 deleted from bear.lua. Functions with side effects (safeRake, safeRip, safeTigerFury, safeBite, safeCower, readyCower) kept with internal replacements. |
| D-02 | 05-02 | Inline locale tables `{en, zh}` in every method | SATISFIED | All 53 skill methods in Druid.lua use inline `{ en = '...', zh = '...' }`. No centralized constants table. |
| D-03 | 05-03, 05-04, 05-05 | Core-first migration order | SATISFIED | Migration executed in planned order: Druid.lua (05-02) -> cat.lua (05-03) -> bear.lua (05-04) -> utility.lua (05-05). |
| D-04 | 05-02 | All Druid skill methods centralized in Druid:new() | SATISFIED | All 53 skill methods defined inside `Druid:new()` between setmetatable and showEnergyUsageSet (grep confirms all `function obj.*` patterns). |
| D-05 | 05-01 | `_castSpell` in Player base class with locale/mode/dispatch | SATISFIED | `entity/Player.lua:40-78` -- complete implementation with GetLocale(), mode dispatch ('raw' bypass, 'safe' adds checks), resourceCost type resolution. |
| D-06 | 05-01, 05-03, 05-04 | Mode parameter nil='ready', 'raw', 'safe' | SATISFIED | `_castSpell` implements correct mode dispatch. Call sites use appropriate modes: nil for ooc paths, 'safe' for normal combat, 'raw' for kill shot (tryBiteKillShot) and FF (safeFF, barkskin). |
| D-07 | 05-02, 05-05 | Three signature types (A/B/C) | SATISFIED | Type A (24 methods, onSelf=false): enemy target. Type B (20 methods, onSelf=true): self target. Type C (9 methods, onSelf exposed): flexible target. All verified in Druid.lua. |
| D-08 | 05-01, 05-02 | resourceCost dual-mode: number or function reference | SATISFIED | `_castSpell` uses `type(resourceCost) == 'function'` check. Cat energy skills use function refs (computeClaw_E, computeShred_E, computeRake_E, computeTiger_E). Bear rage skills use fixed numbers (10, 15). Caster skills use nil. |

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `entity/Player.lua` | Contains `_castSpell`, `_isInRange`, `_hasResource` | VERIFIED | All 3 methods present and substantive (lines 40-99). Each has guard clauses, locale logic, and proper wiring. |
| `classes/druid/Druid.lua` | Contains ~53 skill methods, old wrappers removed | VERIFIED | 53 methods counted. Old prowl/trackHumanoids removed (grep returns 0). Commented-out cast block removed (grep returns 0). |
| `classes/druid/cat.lua` | All `player.cast()` replaced, 5 safe/ready functions deleted | VERIFIED | Zero `player.cast()` remaining. safeShred/readyShred/safeClaw/readyClaw/safePounce all removed. Snapshot side effects preserved in safeRake/safeRip/safeTigerFury. |
| `classes/druid/bear.lua` | All `player.cast()` replaced, 9 safe/ready functions deleted | VERIFIED | Zero `player.cast()` remaining. All 9 deleted function names absent from bear.lua. 6 callers updated with skill method calls. |
| `classes/druid/utility.lua` | All 13 `player.cast()` replaced | VERIFIED | Zero `player.cast()` remaining. 13 skill method calls verified. Barkskin uses 'raw' mode correctly. Nature's Grasp uses Type B implicit onSelf. |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `_castSpell` (Player.lua) | `isSpellReady` (Player.lua) | `self:isSpellReady(spellName)` | WIRED | Line 52: guards `mode ~= 'raw'` before calling, returns false on not-ready |
| `_castSpell` (Player.lua) | `_isInRange` (Player.lua) | `self:_isInRange(range)` | WIRED | Line 59: called when `mode == 'safe'` and `range` is truthy |
| `_castSpell` (Player.lua) | `_hasResource` (Player.lua) | `self:_hasResource(cost)` | WIRED | Line 69: called when `mode == 'safe'` and `resourceCost` is truthy |
| `_castSpell` (Player.lua) | `obj.cast` (Player.lua) | `self:cast(spellName, onSelf or false)` | WIRED | Line 76: final execution step, returns true |
| `_isInRange` (Player.lua) | `macroTorch.target.distance` (Unit.lua) | `macroTorch.target.distance <= range` | WIRED | Line 90: reads existing Unit.lua FIELD_FUNC_MAP property |
| `obj.claw` (Druid.lua) | `_castSpell` (Player.lua) | `self:_castSpell(...)` | WIRED | Returns result of _castSpell call with correct locale table, mode, resourceCost |
| `regularAttack` (cat.lua) | `obj.shred`/`obj.claw` (Druid.lua) | `macroTorch.player.shred('safe')` etc. | WIRED | 4-branch if/else using ooc for mode selection |
| `druidBuffs` (utility.lua) | `obj.mark_of_the_wild`/`obj.thorns`/`obj.natures_grasp` (Druid.lua) | `macroTorch.player.mark_of_the_wild(nil, true)` etc. | WIRED | All 3 calls use correct onSelf semantics |
| `safeFF` (Druid.lua) | `obj.faerie_fire_feral` (Druid.lua) | `macroTorch.player.faerie_fire_feral('raw')` | WIRED | Raw mode avoids double-checking readiness. External isGcdOk+isSpellReady checks preserved. ffTimer side effect preserved. |

### Behavioral Spot-Checks

Step 7b: SKIPPED (no runnable entry points -- WoW addon requires in-game client; `./build.sh` is the only verification tool and it was already confirmed to exit 0)

### Probe Execution

Step 7c: SKIPPED (no probe scripts found in `scripts/*/tests/probe-*.sh`; phase does not declare probes in PLAN/SUMMARY)

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| classes/druid/Druid.lua | 333 | TODO (wolfheart enchant) | WARNING | Pre-existing -- not introduced by Phase 5. Documented deferred item in CLAUDE.md |
| classes/druid/Druid.lua | 380 | TODO (bear form separation) | WARNING | Pre-existing -- not introduced by Phase 5. Documented deferred item in CLAUDE.md |
| classes/druid/Druid.lua | 425 | TODO (wolfheart enchant) | WARNING | Pre-existing -- not introduced by Phase 5. Documented deferred item in CLAUDE.md |

No new anti-patterns, stubs, or debt markers were introduced by Phase 5 changes. All three TODO markers are pre-existing in Druid.lua's `catAtk()` function body and are documented in CLAUDE.md as known items outside this phase's scope.

### Human Verification Required

The following items cannot be verified programmatically and require in-game testing with a WoW 1.12.1 (Turtle WoW) client:

1. **Multi-locale spell name resolution**
   - **Test:** Log in on both enUS and zhCN Turtle WoW clients, trigger all 53 Druid skills
   - **Expected:** Each skill casts successfully on the correct locale client. No "spell not found" errors
   - **Why human:** `GetLocale()` returns different values per client; WoW API cannot be tested outside the game

2. **Cat form combat rotation behavior preservation (R8)**
   - **Test:** Engage in combat using catAtk() one-button macro. Compare behavior pre- and post-refactor
   - **Expected:** Identical combat rotation behavior: Rip/Rake maintenance, Shred/Claw building, Bite at 5cp, energy management, reshift triggering, FF casting during wait windows, relic dance, ooc weaving
   - **Why human:** Combat state, energy ticks, debuff timers, combo point tracking all require the live game engine

3. **Bear form combat logic preservation**
   - **Test:** Use bear form combat abilities (Growl, Swipe, Maul, Demoralizing Roar, Ferocious Bite, Reshift)
   - **Expected:** All abilities function correctly. 'Savage Bite' spell name maps correctly to `ferocious_bite` (see RESEARCH.md assumption A2)
   - **Why human:** Bear form rage mechanics require in-game verification; spell name assumption for 'Savage Bite' needs confirmation

4. **Utility function behavior preservation**
   - **Test:** Use druidBuffs, druidStun, druidDefend, druidControl functions
   - **Expected:** Self-buffs apply correctly (MotW, Thorns, Nature's Grasp), stun abilities work, defensive cooldowns trigger, CC works (Hibernate, Entangling Roots)
   - **Why human:** Barkskin name assumption ('Barkskin (Feral)' vs 'Barkskin') needs in-game verification; onSelf passthrough behavior needs confirmation

---

**Verified: 2026-06-13T12:00:00Z**
**Verifier: Claude (gsd-verifier)**