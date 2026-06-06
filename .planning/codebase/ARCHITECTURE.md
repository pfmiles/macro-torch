<!-- refreshed: 2026-06-06 -->
# Architecture

**Analysis Date:** 2026-06-06

## System Overview

```
+------------------------------------------------------------------+
|                     SuperMacro Integration                         |
|              (SM_Extend.lua -- generated concatenation)            |
+------------------------------------------------------------------+
|  SM_Extend_Druid  |  SM_Extend_Hunter  |  SM_Extend_Warrior  | ...|
| `SM_Extend_Druid.lua` (72.8K) | `SM_Extend_Hunter.lua` (6.8K) ... |
+-------+--------+------+--------+------+---------+---------+-------+
        |                 |                  |                   |
        v                 v                  v                   v
+------------------------------------------------------------------+
|                     Class Layer                                    |
|  macroTorch.Druid  |  macroTorch.Hunter  |  macroTorch.Warrior  ...|
|   (extends Player) |  (extends Player)    |  (extends Player)      |
+------------------------------------------------------------------+
        |                 |                  |
        v                 v                  v
+------------------------------------------------------------------+
|                     Unit Layer                                      |
|  macroTorch.Player (`Player.lua`)    macroTorch.Target (`Target.lua`|
|  macroTorch.Pet (`Pet.lua`)          macroTorch.TargetTarget...     |
|  All inherit from macroTorch.Unit (`Unit.lua`)                      |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                     Event / Context Layer                           |
|  battle_event_queue.lua (combat events, immunity, land tracking)   |
|  event_stack.lua (LRU data structure)                              |
|  macroTorch.context (per-combat state)                             |
|  macroTorch.loginContext (per-session state)                       |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                     Utility Layer                                   |
|  impl_util.lua (strings, tables, type checks)                      |
|  biz_util.lua (spells, items, talents, equipment)                  |
|  interface_debug.lua (debug output, action bar inspection)         |
|  texture_map.lua (spell/item -> texture name)                      |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                     WoW 1.12.1 Client API                           |
|  UnitDebuff, UnitBuff, UnitHealth, UnitMana, CastSpell, etc.       |
+------------------------------------------------------------------+
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `macroTorch.Unit` | Base class: buff detection, field maps, unit properties | `Unit.lua` |
| `macroTorch.Player` | Spell casting, item usage, trinkets, form/stance, auto-attack, item loading | `Player.lua` |
| `macroTorch.Target` | Immunity tracking, definite bleeding, HRPS prediction, will-die timing | `Target.lua` |
| `macroTorch.Pet` | Pet commands, auto-cast toggle, spell casting | `Pet.lua` |
| `macroTorch.Druid` | Cat form rotation (catAtk), bear form (bearAtk), energy calcs, relic dance | `SM_Extend_Druid.lua` |
| `macroTorch.Hunter` | Melee/ranged rotation, pet management, Serpent Sting tracking | `SM_Extend_Hunter.lua` |
| `macroTorch.Rogue` | Stealth openers, pick-pocketing, vanish | `SM_Extend_Rogue.lua` |
| Combat event system | WoW event dispatch, combat state, spell tracing, immunity detection | `battle_event_queue.lua` |
| `macroTorch.LRUStack` | Bounded stack data structure with query helpers | `event_stack.lua` |
| Build system | File concatenation into deployable `SM_Extend.lua` | `build.sh` |

## Pattern Overview

**Overall:** Object-oriented Lua using metatable-based single inheritance

**Key Characteristics:**
- All code resides in the global `macroTorch` namespace
- Classes use chained `__index` metatables: instance field maps, then class methods, then parent class methods
- Three global singleton objects initialized at load time: `macroTorch.player`, `macroTorch.target`, `macroTorch.pet`
- Event-driven combat tracking uses WoW's native event system via a CreateFrame-based listener
- Module-priority execution model in class-specific rotation functions
- Build-time concatenation merges all `.lua` files in strict order into `SM_Extend.lua`

## OOP Metatable Inheritance

### Inheritance Chain

```
macroTorch.Unit (base class)
  +-- macroTorch.Unit:new(ref) creates instances with UNIT_FIELD_FUNC_MAP
  |
  +-- macroTorch.Player = macroTorch.Unit:new("player")
  |     +-- macroTorch.Player:new() with PLAYER_FIELD_FUNC_MAP
  |     +-- macroTorch.player = macroTorch.Player:new()  [singleton]
  |
  +-- macroTorch.Target = macroTorch.Unit:new("target")
  |     +-- macroTorch.Target:new() with TARGET_FIELD_FUNC_MAP
  |     +-- macroTorch.target = macroTorch.Target:new()  [singleton]
  |
  +-- macroTorch.Pet = macroTorch.Unit:new("pet")
        +-- macroTorch.Pet:new() with PET_FIELD_FUNC_MAP
        +-- macroTorch.pet = macroTorch.Pet:new()  [singleton]
```

### Field Resolution Order (metatable `__index`)

For every instance method or property access, the metatable `__index` function searches in this exact order:

1. **Instance field function map** (e.g., `DRUID_FIELD_FUNC_MAP[k]`) -- computed/lazy properties
2. **Class methods and fields** (e.g., `self[k]`) -- methods defined in the class constructor
3. **Parent class methods** (inherited via the class chain) -- the Unit base provides the foundational methods

This means class-specific field maps override parent field maps, and class methods override parent methods.

### Object Construction Pattern

Every class (Unit, Player, Druid, etc.) is a **two-tier constructor**:

```lua
-- Tier 1: Class prototype -- called once, returns a "class" table
macroTorch.Druid = macroTorch.Player:new()
-- Tier 2: Instance constructor -- called for each instance
function macroTorch.Druid:new()
    local obj = {}           -- fresh instance
    setmetatable(obj, {
        __index = function(t, k)
            -- 1. DRUID_FIELD_FUNC_MAP
            -- 2. self (class methods)
            -- 3. parent chain (implicit via self's own metatable)
        end
    })
    -- Define instance methods on obj (closures)
    function obj.catAtk(rough) ... end
    return obj
end
-- Singleton instantiation
macroTorch.druid = macroTorch.Druid:new()
```

### Dynamic Fields (Lazy Computed Properties)

All unit properties (health, mana, distance, buff states) are computed lazily via field function maps. They look like properties but execute a function on each access:

```lua
macroTorch.UNIT_FIELD_FUNC_MAP = {
    ['health'] = function(self) return UnitHealth(self.ref) end,
    ['guid'] = function(self) return ... end,
    ['isCanAttack'] = function(self) return ... end,
}
```

Each subclass adds its own field map (e.g., `PLAYER_FIELD_FUNC_MAP`, `DRUID_FIELD_FUNC_MAP`).

## Layers

### Utility Layer
- Purpose: Foundation functions shared across all components
- Location: `impl_util.lua`, `biz_util.lua`, `interface_debug.lua`, `texture_map.lua`
- Contains: String/table utils, spell/item lookups, talent queries, equipment management, debug output
- Depends on: WoW 1.12.1 API only
- Used by: All layers above

### Event / Context Layer
- Purpose: Combat event tracking, spell land/fail detection, immunity tables, periodic tasks
- Location: `battle_event_queue.lua`, `event_stack.lua`
- Contains: `CreateFrame` event listener, cast/land/fail table management, `LRUStack`, periodic task scheduler, `macroTorch.context` and `macroTorch.loginContext`
- Depends on: Utility layer, WoW API events
- Used by: Unit/Class layers (indirectly via `macroTorch.context` and event tables)

### Unit Layer
- Purpose: Object-oriented abstraction over WoW unit IDs ("player", "target", "pet", etc.)
- Location: `Unit.lua`, `Player.lua`, `Target.lua`, `Pet.lua`, `TargetTarget.lua`, `TargetPet.lua`, `PetTarget.lua`
- Contains: Base Unit class with buff detection, field function maps; Player with spell/item actions; Target with immunity and HRPS tracking
- Depends on: Utility layer, Event/Context layer
- Used by: Class layer, global code

### Class Layer
- Purpose: Class-specific combat rotations and game logic
- Location: `SM_Extend_Druid.lua`, `SM_Extend_Hunter.lua`, `SM_Extend_Rogue.lua`, `SM_Extend_Warrior.lua`, `SM_Extend_Mage.lua`, `SM_Extend_Priest.lua`, `SM_Extend_Warlock.lua`
- Contains: One-button macro functions (e.g., `catAtk()`), module-priority execution, energy calculations, relic management, buff/debuff tracking
- Depends on: Unit layer, Event/Context layer
- Used by: SuperMacro end-user macros

## Data Flow

### Primary Request Path (Druid catAtk -- one-button macro)

1. **Macro trigger**: SuperMacro calls `macroTorch.druid.catAtk()` (user presses key)
2. **clickContext creation**: Fresh `clickContext = {}` created as single-click cache (`SM_Extend_Druid.lua:117-118`)
3. **State snapshot**: All relevant player/target state cached into clickContext (energy costs, erps, combo points, buff status, immunities, form state) (`SM_Extend_Druid.lua:159-174`)
4. **Module execution** (priority-ordered):
   - Module 0: `recoverNormalRelic` -- ensure correct relic equipped
   - Module 1: `combatUrgentHPRestore` -- emergency health
   - Module 2: `player.targetEnemy()` -- auto-target
   - Module 3: `player.startAutoAtk()` -- auto-attack
   - Module 4: `burstMod` -- shift-key trinkets/berserk
   - Module 5: Opener -- Pounce or Ravage (if prowling)
   - Module 7: `oocMod` -- Omen of Clarity handling
   - Module 6: `termMod` -- Ferocious Bite (finisher)
   - Module 8: `otMod` -- threat management (Cower)
   - Module 9: `keepTigerFury` -- maintain Tiger's Fury
   - Module 10: Debuff -- Rip/Rake/FF maintenance
   - Module 11: `regularAttack` -- Shred/Claw combo building
   - Module 12: `reshiftMod` -- energy reset when nothing else to do
5. **Action execution**: The first module that can act casts a spell and returns; all other modules are skipped for this click
6. **Context disposal**: clickContext discarded at end of function call

### Energy Regeneration Calculation Flow

1. `macroTorch.computeErps(clickContext)` sums all energy sources (`SM_Extend_Druid.lua:853-882`)
2. Individual source ERPS computed by `computeRake_Erps()`, `computeRip_Erps()`, `computePounce_Erps()` (`SM_Extend_Druid.lua:449-493`)
3. Each bleed ERPS consults `macroTorch.context.last{Rake|Rip}EquippedSavagery` for snapshot mechanics
4. Talent rank (Ancient Brutality) determines tick energy (0/3/5)

### Combat Event Tracking Flow

1. WoW client fires event (e.g., `PLAYER_REGEN_DISABLED` for entering combat)
2. `macroTorch.eventHandle()` dispatched via `frame:SetScript("OnEvent", ...)` (`battle_event_queue.lua:153`)
3. Spell casts tracked via `UNIT_CASTEVENT` (SuperWoW-specific) or chat message parsing
4. `recordCastTable()` pushes timestamp to per-spell/per-mob LRU stack (`battle_event_queue.lua:255-275`)
5. `computeLandTable()` correlates cast vs. fail events to determine successful lands (`battle_event_queue.lua:304-339`)
6. `spellsImmuneTracing()` periodic task checks landed-but-no-debuff for immunity detection (`battle_event_queue.lua:216-252`)
7. Immunity recorded in `SM_EXTEND.immuneTable[playerClass][spellName][mobName]`

### Item Loading Flow (Pokemon System)

1. `loadUseableItemToSlot(orderedTable)` scans ordered keys linearly (`Player.lua:335`)
2. For each key, checks: item in bag? CD <= 30s? No other item already loaded?
3. If all conditions met: equips useable item to target slot, stores swap data in `macroTorch.itemLoadingTable`
4. `castLoadedItem()` fires on next calls: uses item, then swaps original/backup item back (`Player.lua:417-457`)

### State Management

- `macroTorch.context`: Per-combat mutable state. Reset to `{}` on combat exit (`PLAYER_REGEN_ENABLED`). Stores: `immuneTable`, `definiteBleedingTable`, `ffTimer`, `targetHealthVector`, `behindAttackFailedTime`, `lastRakeEquippedSavagery`, `lastRipEquippedSavagery`, `lastRipAtCp`, `burstFlags`
- `macroTorch.loginContext`: Per-session state. Persists across combats. Stores: `castTable`, `failTable`, `landTable`, `tigerTimer`
- `clickContext`: Per-function-call cache. Created fresh in each `catAtk()`/`hunterAtk()`/`bearAtk()`. Stores cached computed values (lazy evaluation pattern)

## Key Abstractions

### field function maps
- Purpose: Lazy computed unit properties that look like direct field access
- Pattern: `FIELD_FUNC_MAP['propertyName'] = function(self) return ... end`
- Examples: `UNIT_FIELD_FUNC_MAP` (Unit.lua:114), `PLAYER_FIELD_FUNC_MAP` (Player.lua:488), `DRUID_FIELD_FUNC_MAP` (SM_Extend_Druid.lua:250), `PET_FIELD_FUNC_MAP` (Pet.lua:120)
- Resolution: Looked up first in the metatable `__index` chain before class methods

### safe/ready dual-pattern for abilities
- Purpose: Separate energy-cost check (safe) from availability check (ready)
- Pattern: `safeXxx()` checks energy/mana before delegating to `readyXxx()`, which checks spell ready and casts
- Examples: `safeShred`/`readyShred`, `safeClaw`/`readyClaw`, `safeBite`/`readyBite`, `safeCower`/`readyCower` (SM_Extend_Druid.lua:1287-1423)
- OOC handling: When Omen of Clarity is active, code calls `readyXxx` directly (bypassing energy check)

### single point of truth decision helpers
- Purpose: Shared boolean decision functions used in both `getMinimumAffordableAbilityCost` and actual casting logic
- Examples: `shouldUseShred(clickContext)` (`SM_Extend_Druid.lua:541-586`), `shouldCastRip(clickContext)` (`SM_Extend_Druid.lua:981-999`), `shouldUseBite(clickContext)` (`SM_Extend_Druid.lua:1002-1023`)

### LRUStack
- Purpose: Bounded stack with query predicates for combat event tracking
- Location: `event_stack.lua`
- Methods: `push()`, `pop()`, `anyMatch(predicate)`, `allMatch(predicate)`, `top`, `size`, `isEmpty`
- Usage: Cast/land/fail event storage per-spell, per-mob

### Periodic Task Scheduler
- Purpose: Register functions to run at fixed intervals managed by the OnUpdate handler
- Location: `battle_event_queue.lua:156-199`
- Usage: `registerPeriodicTask(name, {interval, task[, times]})`
- Registered tasks: `maintainTHV`, `maintainLandTables`, `spellsImmuneTracing`, `consumeDruidBattleEvents`

## Entry Points

### Macro entry points (called by SuperMacro):
- `macroTorch.druid.catAtk(rough)` -- Druid cat form one-button macro (`SM_Extend_Druid.lua:117`)
- `macroTorch.druid.bearAtk(rough)` -- Druid bear form one-button macro (`SM_Extend_Druid.lua:1652`)
- `macroTorch.hunterAtk()` -- Hunter one-button macro (`SM_Extend_Hunter.lua:76`)
- `macroTorch.rogueAtk(startSp)` / `rogueAtkBack(startSp)` -- Rogue macros (`SM_Extend_Rogue.lua:71,103`)

### System entry points:
- `macroTorch.eventHandle()` -- WoW event dispatch (`battle_event_queue.lua:71`)
- `macroTorch.onPeriodicUpdate()` -- OnUpdate periodic task runner (`battle_event_queue.lua:161`)

### Player class switch entry:
- `PLAYER_ENTERING_WORLD` event handler: swaps `macroTorch.player` to `macroTorch.druid` for Druid class (`battle_event_queue.lua:76-78`)

## Architectural Constraints

- **Threading:** Single-threaded WoW Lua environment. All execution is synchronous within the game loop. `OnUpdate` handler runs at ~10Hz (0.1s interval) (`battle_event_queue.lua:157`)
- **Global state:** All code resides in `macroTorch` global table. Mutable state in `macroTorch.context` (per-combat) and `macroTorch.loginContext` (per-session). `SM_EXTEND` used for cross-session persistence (immune tables).
- **Circular imports:** Not applicable -- all files concatenated in linear order by `build.sh`. No runtime module loading.
- **API accuracy:** WoW 1.12.1 buff/debuff duration API is unreliable. The addon implements self-maintained timers (`ripLeft`, `rakeLeft`, `tigerLeft`, `ffLeft`) using recorded cast times and known durations.
- **Buff detection:** Uses texture strings (not spell names) to detect buffs/debuffs. Texture-to-name mapping via `SPELL_TEXTURE_MAP` in `texture_map.lua`.
- **OOC ambiguity:** "ooc" is used for both "Out of Combat" (energy regen state) and "Omen of Clarity" (proc). In code, `clickContext.ooc` always refers to Omen of Clarity.

## Anti-Patterns

### Global mutable tables used as cross-session storage

**What happens:** `SM_EXTEND.immuneTable` and `SM_EXTEND.definiteBleedingTable` are stored directly in the global `SM_EXTEND` table, mutated by `loadImmuneTable()`/`loadDefiniteBleedingTable()`.
**Why it's wrong:** Cross-session persistence via raw global mutation has no schema enforcement, no migration path, and risks data corruption if table structure changes.
**Do this instead:** If persistence requirements grow, consider a versioned data structure with migration support.

### Large single-file class implementations

**What happens:** `SM_Extend_Druid.lua` is 72,798 lines (1752 lines read) containing all Druid logic -- cat rotation, bear rotation, buffs, utility functions, energy calculations, pet summoning -- in one file.
**Why it's wrong:** Makes it difficult to locate specific functions, test in isolation, or understand module boundaries. New contributors must navigate a monolithic file.
**Do this instead:** Split Druid logic into separate modules (e.g., `SM_Extend_Druid_Cat.lua`, `SM_Extend_Druid_Bear.lua`, `SM_Extend_Druid_Energy.lua`), concatenated in order by `build.sh`.

### Bear form logic mixed into catAtk

**What happens:** `catAtk()` contains a bear form routing branch at line 199-201 of `SM_Extend_Druid.lua` that calls `bearAtk()`.
**Why it's wrong:** The routing should happen at the macro level based on current form, not buried inside `catAtk()`. The TODO comment at line 198 acknowledges this.
**Do this instead:** Create a top-level `druidAtk()` dispatcher that checks form and routes to `catAtk()` or `bearAtk()`.

## Error Handling

**Strategy:** Sparse, best-effort. Most functions return boolean success/failure. API calls that might fail (spell not ready, target invalid) are guarded by pre-checks.

**Patterns:**
- `safeXxx()` functions return boolean (true if action was taken)
- Empty guards at top of all module functions return silently if preconditions not met (e.g., `if not target.isCanAttack then return end`)
- `pcall` used in the OnUpdate handler to prevent a single periodic task error from breaking the event loop (`battle_event_queue.lua:193`)
- Lua errors shown in-game via `macroTorch.show()` and `ChatTypeInfo` color coding

## Cross-Cutting Concerns

**Logging:** `macroTorch.show(msg, color)` writes to the default chat frame with color support (white, red, yellow, blue, green) (`interface_debug.lua:79-92`). Used extensively throughout Druid code for real-time combat feedback.

**Validation:** Implicit through guard clauses. Each function checks preconditions at the top and returns silently if not met. Target validity (`isCanAttack`, `isExist`), combat state (`isInCombat`), and form state (`isFormActive`) are the most common preconditions.

**Authentication:** Not applicable -- WoW addon, no external auth.

**Persistence:** Cross-session immune and definite bleeding tables stored in `SM_EXTEND` global. Combat context reset on each combat enter/exit cycle.

---

*Architecture analysis: 2026-06-06*