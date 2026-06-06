# Codebase Concerns

**Analysis Date:** 2026-06-06

## Tech Debt

### Duplicated Code: SM_Extend.lua and SM_Extend_Druid.lua

- Issue: `SM_Extend.lua` (5239 lines, ~196KB) is a generated file that concatenates all source files. However, it contains all Druid logic duplicated from `SM_Extend_Druid.lua` (1751 lines) and also contains the Druid class implementation (`catAtk`, `shouldUseShred`, etc.) inline. Since `SM_Extend.lua` is gitignored, the logic editable only in `SM_Extend_Druid.lua` is also present in the concatenated output, meaning the `SM_Extend_Druid.lua` file is the source of truth but the `SM_Extend.lua` also exists as a standalone Druid implementation. These are effectively two separate (but seemingly identical) copies of the Druid logic -- one in the standalone file and one concatenated into `SM_Extend.lua`.
- Files: `SM_Extend_Druid.lua`, `SM_Extend.lua` (in source tree, gitignored)
- Impact: If `SM_Extend_Druid.lua` is included in the `find` step of `build.sh`, the Druid logic gets concatenated twice into the output. The build script's `find ... grep -v ...` excludes only specific named files (macro_torch.lua, impl_util.lua, interface_debug.lua, Unit.lua) -- the Druid file IS included by the wildcard grep, so it would be concatenated AFTER all other files, potentially doubling the Druid implementation.
- Fix approach: Either add `SM_Extend_Druid.lua` to the `grep -v` exclusion list in `build.sh`, or rely on the fact that `SM_Extend.lua` is excluded from the `find` by `grep -v "$target"` (which excludes `SM_Extend.lua`). Verify whether `SM_Extend_Druid.lua` is correctly excluded from the concatenation.

### Bear Form Logic Embedded in catAtk

- Issue: Bear form logic (`bearAtk()` call at line 200 of `SM_Extend_Druid.lua`) is embedded inside the `catAtk` function with a condition `if clickContext.isInBearForm then bearAtk(); return end`. The TODO at line 198 explicitly states this should be separated into a top-level routing decision.
- Files: `SM_Extend_Druid.lua:198-201`, duplicated at `SM_Extend.lua:2449-2452`
- Impact: Mixing cat and bear logic in `catAtk` violates Single Responsibility. Every catAtk call must initialize bear-unnecessary context data (Rip ERPS, Pounce ERPS, etc.) even when in bear form. Makes the function harder to test and reason about.
- Fix approach: Move the bear/cat form routing to the macro invocation level. The top-level macro should check current form and route to `bearAtk()` or `catAtk()` accordingly, never calling `catAtk` from bear form.

### Unresolved TODO: Wolfheart Head Enchant

- Issue: Multiple TODO comments (lines 151,241 of `SM_Extend_Druid.lua`, duplicated at 2402,2492 of `SM_Extend.lua`) note that reshift energy restore calculations should account for the Wolfheart head enchant, which increases energy restored on reshift. Currently hardcoded to `RESHIFT_ENERGY = 60`.
- Files: `SM_Extend_Druid.lua:151`, `SM_Extend_Druid.lua:241`
- Impact: Players with Wolfheart enchant get suboptimal reshift timing. The addon may reshift when not needed (wasting a GCD) or not reshift when beneficial (missing energy gain), since it calculates based on 60 energy rather than the enchant-enhanced value.
- Fix approach: Detect whether Wolfheart helm enchant is active, adjust `RESHIFT_ENERGY` accordingly. This requires reading enchant info from the head slot inventory item.

### Unresolved TODO: Mana Reading Fix

- Issue: The `humanFormMana` field in `DRUID_FIELD_FUNC_MAP` at `SM_Extend_Druid.lua:265-268` uses `UnitMana(self.ref)` which returns energy/rage when in forms, not "mana in human form." The code at `SM_Extend_Druid.lua:184` checks `player.humanFormMana < 350` to decide whether to use a Mana Potion -- this check uses the current power value (energy/rage in form) rather than actual mana pool.
- Files: `SM_Extend_Druid.lua:265-268`, `SM_Extend_Druid.lua:184`
- Impact: Mana potion logic is unreliable -- a druid in cat form with 100 energy will incorrectly skip a mana potion even if human-form mana is near zero. This was noted in CLAUDE.md TODOs as "mana reading fix."
- Fix approach: Need a way to read mana in human form while shapeshifted, possibly by caching the value on form change or using a SuperWoW API extension.

### Unresolved TODO: Texture Path Server Differences

- Issue: The `hasEssenceOfTheRed` field function at `Unit.lua:485-488` and the `listTargetBuffTypes` at `Unit.lua:73-74` include TODO comments about updating texture paths if different in the game client. The `SPELL_TEXTURE_MAP` and `ITEM_TEXTURE_MAP` tables at `SM_Extend.lua:614-627` are incomplete (only Warrior spells defined) and lack an easy way for users to customize.
- Files: `Unit.lua:487`, `Unit.lua:248`
- Impact: Texture-based buff detection (the core buff-tracking mechanism) may fail on different WoW clients or private server configurations where texture paths differ from the hardcoded values. Users on non-standard clients can't easily fix this.
- Fix approach: Provide a configuration table or external configuration file for users to override texture paths. Document required texture paths per spell/buff.

## Known Fragile Patterns

### Double-Negation (`not not`) Pattern

- Issue: Four instances of the `if not not variable then` pattern exist in the codebase, which is equivalent to `if variable then` but with doubled negation that may produce unexpected behavior with nil/false distinctions in Lua.
- Files: `SM_Extend_Druid.lua:1141`, `SM_Extend_Druid.lua:1228`, `SM_Extend.lua:3392`, `SM_Extend.lua:3479`
- Impact: While `not not x` is equivalent to `x ~= nil and x ~= false` in Lua, it is an antipattern that often signals a bug was introduced and then hastily "fixed." In the `tigerLeft` and `ffLeft` functions, these are equivalent to `if macroTorch.loginContext.tigerTimer then` but the double negation is unnecessary and confusing.
- Fix approach: Replace with plain `if macroTorch.loginContext.tigerTimer then` and equivalent.

### Unused `buffName` Path in `buffed()` Method

- Issue: The `buffed()` method at `Unit.lua:36-46` has a branch `if buffName then if buffed(buffName) then return true end end` that calls a global `buffed` function (not `obj.buffed` or `self.buffed`). This appears to be a recursive/global lookup that may not be defined or may behave unexpectedly.
- Files: `Unit.lua:37-39`
- Impact: If a caller passes only `buffName` without `buffTexture`, the code calls a bare global `buffed()` function. This global function is not defined elsewhere in the codebase. All callers either pass `buffTexture` only or both, so this codepath may be dead, but if accidentally invoked would cause a nil-call error.
- Fix approach: Either remove the `buffName` branch if it has no defined behavior, or define the proper global `buffed` function.

### `Unit.debuff` Granted by `Unit.lua` diff -- Build Order Hazard

- Issue: The `Unit.lua` source file at line 26 iterates buffers 1-40 for `hasBuff()`, checking both `UnitDebuff` and `UnitBuff`. However, there is a separate `Unit.lua` file at line 265 (in `SM_Extend.lua`) which is the same code from the build concatenation. The concatenation order (macro_torch.lua -> impl_util.lua -> interface_debug.lua -> Unit.lua -> all other .lua) means any file appearing later in the build order wins for duplicate global definitions. If two files define the same `macroTorch.X` table, the later one overwrites the earlier.
- Files: `Unit.lua` (as source), `SM_Extend.lua` (as build output)
- Impact: The build process could produce subtle bugs if two source files accidentally define the same global table or function.

### Hard `error()` Call on Talent Not Found

- Issue: `getTalentRank()` at `biz_util.lua:237` and `SM_Extend.lua:1312` calls `error("talent not found: ...")` when a talent name doesn't match. This will halt Lua execution entirely -- a crash in WoW macro context means the macro button stops working.
- Files: `biz_util.lua:237`, `SM_Extend.lua:1312`
- Impact: If a user respecced and no longer has a talent, or the talent name changed in a game update, the addon crashes. Affected functions include `computeClaw_E()`, `computeShred_E()`, `computeRake_E()`, `computeTiger_Duration()`, `computeRake_Erps()`, `computeRip_Erps()`, `computePounce_Erps()` -- essentially the entire Druid rotation.
- Fix approach: Return 0 instead of calling `error()`. A missing talent means rank 0, which is the correct fallback. Add a warning log instead.

### Cross-Target Context Leakage

- Issue: When switching targets in combat (`PLAYER_TARGET_CHANGED` event), the code clears `ffTimer` and `targetHealthVector` but does NOT clear target-specific immune tables or the `loginContext.castTable`/`landTable`/`failTable` entries for the previous target. These tables are keyed by target name (`mob`) via nested dictionaries.
- Files: `battle_event_queue.lua:79-88`, `battle_event_queue.lua:255-275`
- Impact: `castTable`, `landTable`, and `failTable` grow unboundedly over a play session as the player fights different mobs. The LRU stacks per mob cap at 100 entries each, but the outer structure (mob name -> LRUStack) never prunes old mob entries. Over long sessions this accumulates memory.
- Fix approach: Add periodic cleanup of old mob entries in `castTable`, `landTable`, and `failTable` when the mob name hasn't been referenced in N minutes.

## Security Considerations

### No Input Validation on User-Provided Names

- Issue: Item and spell names passed via `macroTorch.castIfBuffAbsent()`, `macroTorch.castSpellByName()`, and other utility functions come from hardcoded values in the addon source, not user input. Low risk in WoW addon context.
- Files: All files using `CastSpellByName()`, `UseContainerItem()`, `EquipCursorItem()`
- Current mitigation: Names are hardcoded by the addon author, not user-supplied. The risk of injection is minimal in the WoW 1.12.1 Lua sandbox.
- Recommendations: Continue to avoid user-controlled string concatenation into API calls.

### Persistent Data in SM_EXTEND Global

- Issue: `SM_EXTEND.immuneTable` and `SM_EXTEND.definiteBleedingTable` are stored in a global `SM_EXTEND` table (SuperMacro's persistent variable). These hold cross-session data about which mobs are immune to which abilities. While not security-sensitive, persistence across sessions can lead to data staleness.
- Files: `battle_event_queue.lua:484-518`
- Impact: If game content is updated or mob attributes change, stale immune data persists across WoW sessions. The tables have no eviction/expiration mechanism.
- Fix approach: Add timestamp entries and expire entries older than N hours. Provide a `/resetimmune` slash command for manual clearing.

## Performance

### Per-Frame Computation in Background Periodic Tasks

- Issue: Three periodic tasks run at 100ms intervals: `maintainLandTables`, `spellsImmuneTracing`, and `maintainTHV`. In combat, each of these iterates over tracing tables and performs multiple API calls (UnitDebuff, UnitBuff, GetTime, etc.).
- Files: `battle_event_queue.lua:212,251`, `SM_Extend.lua:2104` (in `battle_event_queue.lua` terms)
- Impact: In WoW's constrained Lua environment (50ms frame budget typical), three 100ms-periodic tasks that each do string matching across 40 buff/debuff slots per spell traced can contribute to frame rate drops, especially in raids with many addon users.
- Causes: Each `hasBuff` call iterates 40 debuff slots and 40 buff slots with `string.find` on `tostring()` results. Called from immune tracing which runs every 100ms for each traced spell.
- Improvement path: Batch periodic task execution to stagger across frames. Cache buff/debuff results within a single frame rather than re-querying from different periodic tasks.

### No-Operation Event Handlers

- Issue: Several event handlers in `eventHandle()` perform no operations (empty branches for `SPELLCAST_START`, `SPELLCAST_STOP`, `SPELLCAST_FAILED`, `SPELLCAST_INTERRUPTED`, `PLAYER_DEAD`, etc.), yet the events are registered and the handler is invoked for each. Also, some registered events (`CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE`, `CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE`) have empty handlers.
- Files: `battle_event_queue.lua:49-63`
- Impact: While the per-invocation cost is trivial, deregistering unused events reduces the number of C-to-Lua callbacks, marginally improving performance.
- Fix approach: Comment out the `RegisterEvent` calls for events with empty handlers, keeping the registration line as documentation.

### `containsAnyKeyword` Inside Hot Loop

- Issue: `isActionCooledDown()` at `interface_debug.lua:19-26` iterates 1-172 action slots per call and calls `containsAnyKeyword()` which does string searching. This is used by `isGcdOk()` at `SM_Extend_Druid.lua:1340-1345` which is called on every ability cast decision in combat.
- Files: `interface_debug.lua:19-26`, `SM_Extend_Druid.lua:1340-1345`
- Impact: Each GCD check scans up to 172 action slots with string matching. In the Druid rotation where `isGcdOk` is called before every ability cast (bite, rip, rake, FF, cower), this adds measurable overhead.
- Improvement path: Cache the action slot index for the GCD-indicator texture on first lookup. Only re-scan when the action bar changes (detectable via events).

### `isAutoAttacking` Polls All Action Slots

- Issue: `isAutoAttacking` at `Player.lua:510-512` calls `findAttackActionSlot()` which scans up to 120 action slots, then checks `IsCurrentAction()`. Called on every `startAutoAtk()` and `stopAutoAtk()` invocation.
- Files: `Player.lua:133,140,510-512`
- Impact: Auto-attack toggling incurs a 120-slot scan. While auto-attack state changes infrequently, the scan is unnecessary since `findAttackActionSlot()` already caches in `macroTorch.context.attackSlot`.
- Improvement path: Use the cached slot directly; only re-scan when cache is nil (first call or context reset).

## Test Coverage Gaps

### Complete Absence of Automated Testing

- Issue: There are zero test files, no test framework, no CI/CD, and no automated verification of any kind. The CLAUDE.md states "Testing: Always test changes in-game as Lua errors break WoW macros."
- Files: No test files exist in the repository
- Risk: Every change must be manually tested in-game. Regression bugs are caught only by the developer playing. Complex energy calculation logic (`computeRake_Erps`, `computeRip_Erps`, ancient brutality talent math, Savagery idol snapshot effects) has no validation beyond in-game observation.
- Priority: High for core math functions (energy/duration calculations), Medium for rotation logic

### High-Risk Untested Areas

**Energy calculation functions:**
- What's not tested: `computeClaw_E()`, `computeShred_E()`, `computeRake_E()`, `computeRake_Erps()`, `computeRip_Erps()`, `computePounce_Erps()`, `computeErps()`, `computeTiger_E()`, `computeTiger_Duration()`
- Files: `SM_Extend_Druid.lua:403-493`, `SM_Extend_Druid.lua:853-882`
- Risk: Incorrect energy values cascade into wrong rotation decisions (premature reshift, missed ability opportunities, energy overflow)
- Priority: High

**Remaining time calculation functions:**
- What's not tested: `ripLeft()`, `rakeLeft()`, `ffLeft()`, `tigerLeft()`, `pounceLeft()`
- Files: `SM_Extend_Druid.lua:1138-1271`
- Risk: These reimplement buff/debuff duration tracking to work around WoW API inaccuracies. Errors cause wrong refresh timing for DoTs and debuffs.
- Priority: High

**Kill Shot threshold calculations:**
- What's not tested: `isKillShotOrLastChance()`
- Files: `SM_Extend_Druid.lua:769-831`
- Risk: Complex multi-branch logic with many hardcoded threshold values. Wrong thresholds cause wasted combo points or missed kill opportunities.
- Priority: Medium

**Immune tracking system:**
- What's not tested: Immune detection from fail events and land events, `recordImmune()`, `removeImmune()`, `isDefiniteBleeding()`
- Files: `battle_event_queue.lua:216-249`
- Risk: Incorrect immune tracking leads to repeated casting of immune abilities, wasting GCDs and potentially causing LUA errors.
- Priority: Medium

## Dependency Risks

### SuperMacro Addon Hard Dependency

- Risk: The entire addon depends on the SuperMacro addon to function. If SuperMacro becomes incompatible with a game update or is abandoned, macro-torch becomes non-functional.
- Files: All class entry points call into SuperMacro's macro execution context.
- Impact: Total loss of functionality. There is no fallback mechanism.
- Mitigation: Macro-torch is a Turtle WoW-specific addon and SuperMacro is the standard macro extension addon for that server. The risk is low as long as Turtle WoW remains on the 1.12.1 client.

### SuperWoW Extension (Optional but Critical for Accuracy)

- Risk: `SUPERWOW_STRING` global enables `UNIT_CASTEVENT` event registration at `battle_event_queue.lua:66-69` and enables GUID retrieval at `Unit.lua:117-122`. Without SuperWoW, the cast-tracking system relies on chat message parsing (`CHAT_MSG_COMBAT_SELF_MISSES`, `CHAT_MSG_SPELL_SELF_DAMAGE`) which only captures misses/dodges/parries -- successful land events are NOT captured, meaning the `landTable` generation is entirely disabled.
- Files: `battle_event_queue.lua:66-69`, `Unit.lua:117-122`
- Impact: Without SuperWoW: no `landTable` data, so `ripLeft()`, `rakeLeft()`, `pounceLeft()` all return 0 (meaning those abilities appear to never be present). The immune tracing system can still work via fail events, but cannot record definite bleedings. This fundamentally breaks the Druid rotation's bleeding management.
- Mitigation: The build/install instructions should clearly state that SuperWoW is required for full functionality.

### TWT (Threat Meter) Optional Dependency

- Risk: The `threatPercent` field at `Player.lua:490-497` reads from a global `macroTorch.TWT` table that is never assigned in this codebase. It relies on an external threat meter addon populating `TWT.threats[TWT.name].perc`.
- Files: `Player.lua:490-497`
- Impact: If no threat meter is installed, `threatPercent` always returns 0, which means Cower OT logic (`otMod`) and threat-based decisions never activate. The addon silently loses threat management capability.
- Mitigation: Document the TWT dependency in installation instructions. Add a graceful warning when `TWT` is nil after combat starts.

### UnitXP (Distance Between) Optional Dependency

- Risk: `unitTargetDistance()` at `biz_util.lua:183-192` and `isBehindTarget` at `Player.lua:503-506` use `UnitXP()` which is a SuperWoW-specific function or part of a specific API extension addon. The `distance` field on units at `Unit.lua:148-149` also uses `UnitXP("distanceBetween", ...)` with a fallback to 0.
- Files: `biz_util.lua:183-192`, `Player.lua:503-506`, `Unit.lua:148-149`
- Impact: Without UnitXP: `mateNearMyTargetCount` always returns 0 (affecting kill shot thresholds and trivial battle detection). Behind-target checks fail (Shred always treated as not usable from behind). Distance checks return 0, potentially breaking range-based decisions.
- Mitigation: Same as SuperWoW -- document the dependency.

## Architecture and Design Concerns

### Build System: Order-Dependent Concatenation

- Issue: The `build.sh` script concatenates files in a specific hardcoded order. If a new file is added that defines a symbol used by later files, it must be manually added to the explicit ordering at the top of `build.sh`. Otherwise, it gets concatenated at the end (via the `find` step) and may be defined too late.
- Files: `build.sh`
- Impact: Adding a new shared module requires careful consideration of build order. The current approach of listing only 4 files explicitly and then cating "all others" via `find` means any new dependency chain that spans across the boundary between explicitly-listed and wildcard files creates fragile ordering.
- Fix approach: Consider defining a manifest file that specifies the concatenation order explicitly, rather than relying on a hybrid of explicit + wildcard ordering.

### Very Large Generated File

- Issue: `SM_Extend.lua` (5239 lines, ~196KB) is the single monolithic output from the build. This is loaded entirely into SuperMacro's Lua environment on every macro execution.
- Impact: While not a correctness concern, the file size means SuperMacro must parse 196KB of Lua on every reload. Could increase load times.
- Note: This is inherent to the WoW 1.12.1 addon model and SuperMacro's design. No easy fix without changes to SuperMacro itself.

### Class Implementation Disparity

- Issue: Class implementations vary dramatically in depth:
  - Druid: 1751 lines -- full modular rotation with energy management, immune tracking, relic dance, reshift logic
  - Hunter: 218 lines -- basic rotation with melee/ranged split
  - Warrior: 210 lines -- stance management, basic rotation
  - Rogue: 149 lines -- simple front/back combat, no combo point management
  - Priest: 111 lines -- basic buffs, simple heal/damage
  - Warlock: 92 lines -- basic curses, no pet management
  - Mage: 81 lines -- single spell (Frostbolt) for both ranged/melee
- Files: All `SM_Extend_*.lua` files
- Impact: Users of non-Druid classes get a much less sophisticated macro experience. The Druid implementation has 8x more logic than most other classes. The framework (OOP pattern, periodic tasks, immune tracing) is available for all classes but only fully utilized by Druid.

### Mixed Language Comments (Chinese/English)

- Issue: Comments are a mix of Chinese and English throughout the codebase. Function docstrings are mostly English-style, but inline comments explaining logic are sometimes Chinese, sometimes English.
- Files: Throughout, but most prevalent in `SM_Extend_Druid.lua` and `SM_Extend.lua`
- Impact: Contributors who don't read Chinese cannot understand some of the combat logic documentation. The CLAUDE.md provides translations for key abbreviations, but the code itself remains bilingual.
- Fix approach: CLAUDE.md already provides a good translation table. Consider adding that as a comment block at the top of the Druid file for offline reference.

### Stale Generated File in Repository

- Issue: `SM_Extend.lua` is listed in `.gitignore` (line that reads `SM_Extend.lua`) but appears in the working tree. Since the file is gitignored, its state in the working tree is from the last build run, not from git history.
- Files: `.gitignore`, `SM_Extend.lua` (in working tree)
- Impact: The build output file in the working tree may be stale if the developer hasn't run `./build.sh` after pulling new changes. However, since CLAUDE.md tells developers to never manually edit `SM_Extend.lua` and it's gitignored, this is functioning as intended. The concern is that CI/CD would need to run `./build.sh` before deploying.

## Scaling Limits

### Monolithic File Growth

- Current capacity: `SM_Extend.lua` is 5239 lines / ~196KB. Each new class feature adds to this monolithic output.
- Limit: There is no hard limit, but WoW 1.12.1 has a known memory ceiling for addon code. Macro execution via SuperMacro may have its own size limits.
- Scaling path: If the file grows significantly, consider splitting into multiple SuperMacro macros, each responsible for a subset of functionality. The current design already supports this via the `macroTorch.druidAtk()`, `macroTorch.hunterAtk()`, etc. entry points.

### Context State Growth Per Session

- Current capacity: `castTable`, `failTable`, `landTable` per-spell per-mob grow unboundedly over a play session (LRU stacks cap at 100 per mob, but mob entries never expire).
- Limit: After many hours of gameplay, these tables could accumulate hundreds of mob entries.
- Scaling path: Add time-based eviction for old mob entries. A reasonable cutoff would be 30 minutes since last reference.

---

*Concerns audit: 2026-06-06*