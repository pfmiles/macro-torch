# Testing Patterns

**Analysis Date:** 2026-06-06

## Test Framework

**None.** This codebase has no automated test framework. There are:
- No test runner (no jest, vitest, busted, luaunit, or similar)
- No assertion library
- No test files (`*.test.*`, `*.spec.*`, `*_test.*` -- zero matches)
- No test configuration files (`jest.config.*`, `vitest.config.*`, `.busted` -- zero matches)
- No CI pipeline with testing

### Why No Automated Tests

This is a World of Warcraft addon for WoW 1.12.1 (Vanilla/Turtle WoW) that generates SuperMacro addon code. It runs inside the WoW client Lua environment and depends on WoW API functions (`UnitHealth`, `CastSpellByName`, `UnitDebuff`, etc.) that are only available in-game. There is no WoW API mock/stub framework available for offline testing.

## Test Approach: Manual In-Game Testing

**All testing must be done in-game**, as stated in `CLAUDE.md`:
> Always test changes in-game as Lua errors break WoW macros

The testing workflow is:
1. Write code in source `.lua` files
2. Run `./build.sh` to concatenate into `SM_Extend.lua`
3. Copy `SM_Extend.lua` to the SuperMacro addon directory (automated on Windows/Cygwin via build script)
4. Launch WoW and test the changes in-game
5. Observe combat rotations, debug output in chat (`macroTorch.show()` messages)

### Quality Gate

The implicit quality gate is: **does the macro work correctly in-game without Lua errors?** A single Lua error will break the SuperMacro execution, so correctness is paramount.

### Debug/Verification Patterns Used In-Game

The codebase includes several debugging utilities that serve as manual test helpers:

**Listing functions** for inspecting game state:
```lua
-- Unit.lua
function obj.listBuffs()     -- Lists all buff textures on a unit
function obj.listDebuffs()   -- Lists all debuff textures on a unit

-- Player.lua
function obj.listAllSpells() -- Lists all spells in spellbook

-- Target.lua
function macroTorch.listTargetDebuffs(t) -- Lists debuffs on a target
function macroTorch.listTargetBuffs(t)   -- Lists buffs on a target

-- interface_debug.lua
function macroTorch.showAllActions()     -- Lists all action bar slots
function macroTorch.showAllActionProps() -- Shows all action properties
```

**Energy cost calculation display:**
```lua
-- SM_Extend_Druid.lua:48
function obj.showEnergyUsageSet()
    -- Displays all energy costs and durations for debugging
    macroTorch.show('POUNCE_E: ' .. macroTorch.POUNCE_E .. ', CLAW_E: ' .. macroTorch.CLAW_E ...)
end
```

**Chat output for state transitions:**
```lua
macroTorch.show('Entering combat!')
macroTorch.show('Exiting combat!')
macroTorch.show('Target change in combat!')
macroTorch.show("Useable item loaded: " .. useableItem)
macroTorch.show("Spell: " .. spellName .. " is recorded IMMUNE to " .. obj.name, 'yellow')
```

**Error catching via pcall** (the closest thing to a test harness):
```lua
-- battle_event_queue.lua:192-197
local success, errorMsg = pcall(macroTorch.onPeriodicUpdate)
if not success then
    macroTorch.show("onPeriodicUpdate执行错误: " .. tostring(errorMsg), "red")
end
```

This ensures that errors in the periodic update loop don't crash the entire addon.

## Test File Organization

**Not applicable** -- no test files exist.

If one were to add tests, the likely approach would be:
- In-game unit testing via a WoW addon testing framework (none exists as of this analysis)
- Manual checklist testing: verify each combat module functions correctly
- Observing `macroTorch.show()` output in chat for correct behavior

## Test Structure

**None.** However, the combat module priority order in `catAtk()` effectively defines a "test order" for manual verification:

```
0. Idol Recover
1. Health & Mana Saver
2. Target Enemy
3. Keep AutoAttack
4. Rush Mod (Shift key)
5. Opener Mod (Pounce/Ravage)
7. oocMod
6. Term Mod (Bite)
8. OT Mod (Cower)
9. Tiger Fury
10. Debuff Mod (Rip, Rake, FF)
11. Regular Attack (Shred/Claw)
12. Reshift Mod
```

Each module should be verified independently when changed.

## Mocking

**Not applicable.** There is no mocking framework and no offline test environment.

The closest pattern to mocking is the **context caching** mechanism:
- `clickContext` serves as a cache for per-click execution, avoiding repeated expensive WoW API calls
- `macroTorch.context` serves as a persistent state store across combat ticks

These contexts could theoretically be pre-populated with test data for testing, but this is not done in practice.

## Fixtures and Factories

**Not applicable.** No test data, no test fixtures, no factory functions.

The closest equivalent is the **hardcoded item/spell tables** used in various class files:
```lua
-- texture_map.lua
macroTorch.SPELL_TEXTURE_MAP = {
    ['Defensive Stance'] = 'Ability_Warrior_DefensiveStance',
    ['Rend'] = 'Ability_Gouge',
    ...
}

-- SM_Extend_Druid.lua (pokemonLoad)
local orderedTable = {
    keys = { ... },
    values = { ... },
    toSlots = { ... },
    backupItem = { ... }
}
```

These tables define expected game data and could serve as test fixture seeds.

## Coverage

**Not enforced.** There are no coverage tools, no coverage reports, and no coverage targets.

## Test Types

### Unit Tests

**None.** No unit tests exist. The codebase logic is tightly coupled to WoW API calls, making unit testing impractical without a WoW API mock layer.

### Integration Tests

**None.** The only integration testing happens in-game by running the addon against a live WoW client.

### E2E Tests

**None.** Manual gameplay testing is the only E2E validation.

### Regression Testing

**Not automated.** The codebase relies on:
1. The developer's memory of past behavior
2. Git history for reference on previous correct states
3. In-game verification after each change

## Common Patterns for Safe Testing

### Context Reset Pattern

When entering/exiting combat, context is reset:
```lua
-- battle_event_queue.lua:100-101
if macroTorch.context then
    macroTorch.inCombat = false
    macroTorch.context = {}
end
```

This ensures a clean state for the next combat encounter.

### Feature Flag Pattern

Some behavior is controlled by toggle-like variables:
```lua
-- SM_Extend_Druid.lua
clickContext.rough = macroTorch.toBoolean(rough)  -- rough mode for quick battles
```

This allows testing different code paths by changing a single parameter.

### Comment-Based Change Tracking

Commits often include "tested" in their message:
```
ea1abbb minor mod, tested
5091374 druid energy before bite logic tested
```

## Testing Wisdom from the Codebase

1. **Lua errors break WoW macros.** Any unhandled error in the addon code will cause the SuperMacro to stop executing. `pcall` is used sparingly (only once) to protect the periodic update loop. All new code must handle errors gracefully.

2. **WoW API results are unreliable.** From `CLAUDE.md`:
   > WoW client API returns are not always accurate (e.g., debuff/buff durations). The addon implements custom tracking for precise timing.

   This means testing must verify against in-game observed behavior, not API documentation.

3. **Build before test.** Always run `./build.sh` before testing -- edits to source files are not reflected in-game until built.

4. **Texture-based identification is fragile.** Buff detection relies on texture strings (e.g., `'Spell_Shadow_ManaBurn'`). If Blizzard updates a texture path, detection silently breaks. The `TODO` in `Unit.lua:248` acknowledges this:
   ```lua
   -- TODO Update the texture path if different in your game client
   ```

5. **Energy/combat state calculations are critical.** The most fragile logic is the energy overflow prevention and relic dance calculations. Any change to energy costs, durations, or talent interactions requires thorough in-game combat testing.

6. **No automated quality gates.** The absence of tests means all quality control is manual. Each change must be verified by:
   - Building the addon
   - Testing in-game with relevant combat scenarios
   - Checking that no Lua errors appear
   - Verifying combat rotation correctness by observing in-game behavior and debug output

## Recommendations for Future Testing

If test infrastructure were to be added, the most valuable approach would be:

1. **In-game assertion utility**: A `macroTorch.assert()` function that checks conditions and reports failures to chat, usable during development.
2. **State snapshot recording**: Log combat state transitions to chat for later analysis of rotation correctness.
3. **Configuration validation**: Verify that required spells are in spellbook and required items are in bag on login.
4. **Texture path validation**: Warn if expected buff/debuff textures are not found, preventing silent failures.

---

*Testing analysis: 2026-06-06*