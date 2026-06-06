# Coding Conventions

**Analysis Date:** 2026-06-06

## Naming Patterns

### Files

**Source files use PascalCase for class-based modules and snake_case for utility modules:**
- `Unit.lua`, `Player.lua`, `Target.lua`, `Pet.lua` -- base class hierarchy
- `SM_Extend_Druid.lua`, `SM_Extend_Hunter.lua`, `SM_Extend_Warrior.lua`, etc. -- class-specific extensions
- `macro_torch.lua` -- namespace initialization
- `impl_util.lua` -- utility functions
- `interface_debug.lua` -- debug interface
- `battle_event_queue.lua`, `event_stack.lua`, `biz_util.lua`, `texture_map.lua` -- lowercase modules

**Output file:** `SM_Extend.lua` -- generated file, concatenated source, never manually edited. The naming convention (`SM_Extend_*.lua`) distinguishes source module files from the generated output.

### Functions

**Public functions (global scope) use camelCase:**
```lua
function macroTorch.computeNormalRelic(clickContext)
function macroTorch.shouldUseShred(clickContext)
function macroTorch.isTrivialBattleOrPvp(clickContext)
```

**Class methods use object-oriented style with colon syntax:**
```lua
function obj.catAtk(rough)
function obj.hasBuff(spellOrItemName)
function obj.isSpellReady(spellName)
```

**Instance methods are defined inside constructor with `function obj.methodName()`:**
```lua
function macroTorch.Player:new()
    local obj = {}
    function obj.cast(spellName, onSelf) ... end
    function obj.use(itemName, onSelf) ... end
    ...
end
```

**Private/local functions are extremely rare** (only 2 `local function` occurrences across the entire codebase in `Player.lua` for inline lambda-like closures and `battle_event_queue.lua` for the WoW frame `OnUpdate` handler). All functions are on the `macroTorch` namespace or on class objects.

### Variables

**Local variables use camelCase:**
```lua
local target = macroTorch.target
local player = macroTorch.player
local clickContext = {}
local spellId, slotIndex, bagId
```

**Module-level "constants" use UPPER_SNAKE_CASE but are mutable (Lua convention):**
```lua
macroTorch.CLAW_E = 45
macroTorch.SHRED_E = 60
macroTorch.BITE_E = 35
macroTorch.RIP_E = 30
macroTorch.RAKE_E = macroTorch.computeRake_E()
macroTorch.DEBUFF_LAND_LAG = 0.2
macroTorch.COWER_THREAT_THRESHOLD = 75
```

Some constants remain in `Pascal_Snake_Case` (inconsistent -- e.g., `PLAYER_URGENT_HP_THRESHOLD` defined locally in `clickContext`).

### Class Names

**Use PascalCase, namespaced under `macroTorch`:**
```lua
macroTorch.Unit
macroTorch.Player
macroTorch.Target
macroTorch.Pet
macroTorch.Druid
macroTorch.Hunter
macroTorch.TargetTarget
```

### Field Function Maps

**Use UPPER_SNAKE_CASE with `_FIELD_FUNC_MAP` suffix:**
```lua
macroTorch.UNIT_FIELD_FUNC_MAP
macroTorch.PLAYER_FIELD_FUNC_MAP
macroTorch.DRUID_FIELD_FUNC_MAP
macroTorch.HUNTER_FIELD_FUNC_MAP
macroTorch.PET_FIELD_FUNC_MAP
macroTorch.TARGET_FIELD_FUNC_MAP
macroTorch.ES_FIELD_FUNC_MAP  -- exception: "ES" for event stack
```

## Code Style

### Indentation

Use 4-space indentation consistently throughout all source files.

### Line Length

Lines can be long -- there is no strict 80 or 120 character limit. Long expressions, concatenations, and conditional chains are routinely written on single lines up to ~150 characters.

### Semicolons

Used inconsistently. Some files use trailing semicolons on statements, some do not. The `biz_util.lua` file uses them consistently; `SM_Extend_Druid.lua` does not. Do not introduce semicolons unless continuing an existing file's style.

### Block Comments

**Multi-line block comments use `--[[ ... ]]` format:**
```lua
--[[
   Copyright 2024 pf_miles
   ...
]] --
```

Every source file starts with the Apache 2.0 license block comment.

### Single-Line Comments

**Use `--` with a space then content:**
```lua
-- cast spell by name
-- @param spellName string spell name
-- @param onSelf boolean true if cast on self, current target otherwise
```

Section separators use dashed comment lines:
```lua
---小德专用start---
---猎人专用---
```

### Comment Content

- **Chinese comments** are used extensively in the Druid file (`SM_Extend_Druid.lua`) for design rationale, algorithm explanations, and business logic documentation.
- **English comments** are used for simpler notes, parameter documentation, and license headers.
- **Bilingual comment convention**: Complex combat logic gets Chinese explanatory comments. Simple function contracts get English. When the developer explains "why" (design decisions, trade-offs), Chinese is used. When documenting "what" (parameter types, return values), either language is acceptable.

### Documentation

**LuaDoc/LDdoc-style annotations (`---@param`, `---@return`) are used in the Player.lua helper functions at the bottom of the file:**
```lua
--- 如果指定的buff在指定的目标身上不存在，则释放指定的技能
---@param t string 指定的目标
---@param sp string 指定的技能
---@param dbfTexture string 指定的debuf, texture文本
function macroTorch.castIfBuffAbsent(t, sp, dbfTexture)
```

Similarly used in `interface_debug.lua` for debug utility functions. Most complex Druid functions do NOT use `@param` annotations -- they rely on inline comments explaining the logic instead.

**Doc comments are on separate lines before the function**, not inline. Use `---` (triple dash) for doc comments and `--` (double dash) for regular comments.

## Import Organization

There is **no module system or import mechanism**. The codebase uses WoW 1.12.1's global Lua environment. All files write into the shared `macroTorch` global namespace. No `require()`, no `import`, no module loader.

File concatenation order is enforced by `build.sh`:
1. `macro_torch.lua` -- namespace init
2. `impl_util.lua` -- utilities
3. `interface_debug.lua` -- debug interface
4. `Unit.lua` -- base class
5. All other `*.lua` files (alphabetical by find)

Because there is no module system, **all file dependencies must be satisfied by the concatenation order**. The build script guarantees this order.

### Global Object Initialization

Key global singletons are initialized at the bottom of their respective files:
```lua
macroTorch.player = macroTorch.Player:new()    -- Player.lua:535
macroTorch.target = macroTorch.Target:new()     -- Target.lua:106
macroTorch.pet = macroTorch.Pet:new()           -- Pet.lua:134
macroTorch.druid = macroTorch.Druid:new()       -- SM_Extend_Druid.lua:271
macroTorch.targettarget = macroTorch.TargetTarget:new()  -- TargetTarget.lua:26
macroTorch.targetpet = macroTorch.TargetPet:new()        -- TargetPet.lua:26
macroTorch.pettarget = macroTorch.PetTarget:new()         -- PetTarget.lua:27
```

### The `SELF_FIELD_FUNC_MAP` Pattern

Each class registers a field lookup table on the `macroTorch` namespace that maps field names to computed property functions. This is the primary extension point for adding new properties to a class:

```lua
macroTorch.DRUID_FIELD_FUNC_MAP = {
    ['comboPoints'] = function(self) return GetComboPoints() end,
    ['isOoc'] = function(self) return self.buffed('Clearcasting', 'Spell_Shadow_ManaBurn') end,
    ['isProwling'] = function(self) return self.buffed('Prowl', 'Ability_Ambush') end,
}
```

## Error Handling

### Strategy

The codebase uses **defensive nil-checking and early returns** as the primary error handling strategy. There are no try-catch blocks (Lua does not have them natively), but `pcall` is used in one critical location:

```lua
-- battle_event_queue.lua:193
local success, errorMsg = pcall(macroTorch.onPeriodicUpdate)
if not success then
    macroTorch.show("onPeriodicUpdate执行错误: " .. tostring(errorMsg), "red")
end
```

### Patterns

**Return nil/false for "not found" or "invalid input":**
```lua
function macroTorch.getSpellIdByName(spellName, bookType)
    ...
    return nil  -- spell not found
end
```

**Use `macroTorch.toBoolean()` to normalize truthiness:**
```lua
function macroTorch.toBoolean(v)
    return v and true or false
end
```

This is the idiomatic Lua pattern used throughout for converting potentially nil/falsy API results to strict booleans.

**`error()` for unrecoverable programmer errors:**
```lua
-- biz_util.lua:237
error("talent not found: " .. tostring(talentName))
```

This is used once in `getTalentRank()` -- a developer error that cannot be silently handled.

**Nil-check before accessing fields:**
```lua
if not str then return false end
if not macroTorch.context then return end
```

### Defensive API Wrapping

WoW API results that may be nil are always guarded:
```lua
if not spellId then return nil end
if not bagId or not slotIndex then return false end
```

## Logging

**Framework:** Custom `macroTorch.show()` function in `interface_debug.lua` that writes to the default chat frame.

**Usage:**
```lua
macroTorch.show('Useable item loaded: ' .. useableItem)
macroTorch.show("Couldn't find attack action in any of your action slot.", 'red')
macroTorch.show('Entering combat!')
```

**Color support:**
- Default: 'white' (SAY chat type)
- 'red': YELL chat type
- 'yellow': SYSTEM chat type
- 'blue': OFFICER chat type
- 'green': custom color

**Show is used extensively** for debugging and runtime status messages. There is no separate log level, no structured logging, and no file-based logging. Everything appears in the player's chat window.

## Comments

### When to Comment

1. **Complex combat logic** at the module/function level -- explains design rationale, trade-offs, and "why" decisions (Chinese).
2. **Parameter documentation** for utility/helper functions using `---@param` (mixed Chinese/English).
3. **Algorithm explanations** for energy calculations, bleeds, and cooldown management (Chinese).
4. **Section separators** for file regions (`---小德专用start---`).
5. **TODOs** for known incomplete features or future improvements.

### When NOT to Comment

Simple getters/setters, straightforward delegations, and obvious code do not need comments.

### TODO Style

```lua
-- TODO reshift energy restore should consider the head enchant: whether the wolfheart enchant exists
-- TODO Update the texture path if different in your game client
-- TODO 其实bear形态逻辑应该完全从catAtck逻辑中剥离出来，在最上层的宏里面通过当前形态来路由
```

TODOs are written in both English and Chinese. They appear in:
- `SM_Extend_Druid.lua:151, 198, 241`
- `Unit.lua:248`
- `SM_Extend.lua:487, 2402, 2449, 2492`

## Function Design

### Size

Functions range from trivial (3-5 lines) to large monolithic functions:
- `catAtk()`: ~125 lines (lines 117-244 in `SM_Extend_Druid.lua`) -- main combat rotation entry point
- `bearAtk()`: ~64 lines -- structured similarly with modular sub-functions
- Most utility functions: 5-30 lines

### Parameters

**Primary parameter pattern:** A single `clickContext` table is passed to most combat functions containing all computed context for a single button press. This is the "Context Object" pattern:

```lua
function macroTorch.keepRip(clickContext)
function macroTorch.shouldUseShred(clickContext)
function obj.catAtk(rough)
```

Context fields include energy costs, durations, cached player/target state, battle mode flags, and immunity information.

**Builder pattern** for constructing clickContext: Properties are assigned incrementally at the top of `catAtk()`:
```lua
clickContext.CLAW_E = macroTorch.computeClaw_E()
clickContext.SHRED_E = macroTorch.computeShred_E()
clickContext.ooc = player.isOoc
clickContext.isBehind = target.isCanAttack and player.isBehindTarget
```

### Return Values

Functions generally return:
- `nil` or `false` for "not valid" / "failed"
- A computed value (number, string, table, boolean) for successful operations
- No consistent "Result" wrapper or error tuple pattern

### Caching Pattern

**Lazy computation with nil-check caching** is a core performance pattern:
```lua
function macroTorch.isFightStarted(clickContext)
    if clickContext.isFightStarted == nil then
        clickContext.isFightStarted = (not clickContext.prowling and
                (macroTorch.player.isInCombat or ...))
    end
    return clickContext.isFightStarted
end
```

This pattern avoids re-computing expensive checks on every access. The `clickContext` is fresh per button press (single macro execution), so cached values are only valid for one click but save repeated API calls within that execution.

## Module Design

### Exports

Everything is on the `macroTorch` global namespace. No explicit export mechanism. Functions, classes, and constants are all globally accessible once concatenated.

### Barrel Files

Not applicable. There is no module system.

### File Organization Convention

Every Lua source file follows this structure:
1. Apache 2.0 license block comment
2. Class/section separator comment (e.g., `---小德专用start---`)
3. Class constructor with `setmetatable` and `__index` metamethod
4. Instance methods defined inside constructor
5. `FIELD_FUNC_MAP` definition
6. Global singleton instantiation
7. Additional module-level helper functions

### Build System Convention

The concatenation order is: `macro_torch.lua` -> `impl_util.lua` -> `interface_debug.lua` -> `Unit.lua` -> remaining files. Always maintain this ordering when adding new files. The generated `SM_Extend.lua` is NOT committed to version control (in `.gitignore`).

## Git Commit Conventions

**Conventional Commits style with some informal usage:**
```
feat(druid): standardize infinite energy checks in catAtk logic
fix(druid): correct ability priority order in getMinimumAffordableAbilityCost
refactor(druid): restructure bearAtk() with modular combat system
chore(git): add .claude-reference to .gitignore
build: remove deprecated Chinese build functionality
```

**Format:** `type(scope): description` (English) or informal descriptions for minor changes:
```
minor mod
thresholds tweaks
```

**Common types:** `feat`, `fix`, `refactor`, `chore`, `build`

**Common scopes:** `druid`, `player`, `git`

**Descriptions:** English for structured commits. Use imperative mood (`add`, `fix`, `enhance`, `optimize`).

## Abbreviation Conventions

Extensive abbreviations are used for combat mechanics. These are documented in `CLAUDE.md` and must be understood by anyone modifying the code:

| Abbreviation | Meaning |
|-------------|---------|
| cp | Combo Points |
| ff | Faerie Fire |
| ooc | Omen of Clarity (or Out of Combat -- context-dependent) |
| TF | Tiger's Fury |
| erps | Energy Regeneration Per Second |
| KS | Kill Shot / last attack opportunity |
| fero | Feral/Bear form or Idol of Ferocity |
| e | Energy cost (suffix on constants: `CLAW_E`, `SHRED_E`) |

## Language Usage

- **Code comments and git commit messages:** Mixed Chinese and English. English for standard commit messages and parameter docs. Chinese for complex combat logic explanations and design rationale.
- **Code identifiers:** English only (function names, variable names, class names).
- **String literals (UI messages, debug output):** English with occasional Chinese debug messages.

## Best Practices from the Codebase

1. **Single Point of Truth:** Extract shared decision logic to dedicated helper functions (`shouldUseShred`, `shouldCastRip`, `shouldUseBite`). Any logic used in multiple places must be in a shared helper.
2. **Minimize WoW API calls:** Cache expensive API results in `clickContext` or `macroTorch.context`. Lazy compute with nil-check caching.
3. **Consistent module ordering:** Combat modules execute in strict priority order (0-12) defined in `catAtk()`. Maintain this order when adding new modules.
4. **Context per macro execution:** `clickContext` is fresh per button press. `macroTorch.context` persists across combats.
5. **Texture-based buff detection:** Buffs/debuffs are detected by texture strings, not names. Use the texture maps in `texture_map.lua`.

---

*Convention analysis: 2026-06-06*