# Phase 17: catLeveling FF prowling guard + global spellId 动态更正机制 - Research

**Researched:** 2026-06-29
**Domain:** WoW 1.12.1 addon Lua — spell tracing infrastructure, UNIT_CASTEVENT event handling, SavedVariable persistence
**Confidence:** HIGH

## Summary

Phase 17 delivers two independent but complementary changes to the macro-torch addon. Task 1 adds a single-line guard to the catLeveling Faerie Fire (Feral) release path, preventing the illegal cast while prowling (stealthed). Task 2 replaces the hardcoded spellId-based spell tracing registration with a name-based system backed by a static spellId map with runtime dynamic correction, eliminating a known fragility where different Turtle WoW client builds produce different Global Spell IDs for the same spell.

The spellId mapping system is simple: a flat dual-key table (`{["Pounce"]=9827, ["突袭"]=9827, ...}`) provides O(1) name-to-spellId resolution, statically seeded with known 60-level Druid spell IDs. At runtime, the `UNIT_CASTEVENT` handler captures the actual spellId emitted by the SuperWoW API, compares it against the static baseline, and immediately persists any discovered correction to `SM_EXTEND.spellIdMap[playerCls][spellName]`. On next login, the persisted corrections are loaded and take precedence over static values.

The `_castSpell` bottleneck in `entity/Player.lua` sets `macroTorch.current_casting_spell = spellName` before returning true -- a single insertion point covering all 40+ Druid skill methods. The `UNIT_CASTEVENT` handler clears it after matching the CAST event, ensuring a minimal lifetime with no stale state.

**Primary recommendation:** Implement the spellId mapping infrastructure as a new file `core/spell_id_map.lua` placed before `core/spell_trace_core.lua` in `build_order.txt`, and implement `current_casting_spell` lifecycle with surgical edits to `_castSpell` and `events.lua`. The FF prowling guard is a one-line change in `classes/druid/leveling.lua`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Spell ID static mapping table | Frontend Server (addon init) | — | Pure data table, loaded at addon bootstrap before any spell trace registration. No API calls needed. |
| Spell ID persistence (load) | Frontend Server (addon lifecycle) | — | PLAYER_ENTERING_WORLD event is WoW client-side; SM_EXTEND is a SavedVariable auto-available. Same tier as loadImmuneTable. |
| Spell ID persistence (write) | Frontend Server (event handler) | — | UNIT_CASTEVENT is client-side; writes mutate SM_EXTEND table reference directly. No server round-trip. |
| current_casting_spell set | Frontend Server (addon code) | — | _castSpell executes in-memory before CastSpellByName; pure Lua state mutation. |
| current_casting_spell clear | Frontend Server (event handler) | — | UNIT_CASTEVENT handler runs on client event frame; pure Lua state mutation. |
| SpellTrace:register name-based resolution | Frontend Server (addon registration) | — | Declaration runs at addon load time; resolves spellName to spellId via static map. |
| FF prowling guard | Frontend Server (addon combat logic) | — | catLeveling() executes in-memory per button press; isProwling is a buffed() texture check. |
| UNIT_CASTEVENT spellId correction | Frontend Server (event handler) | — | Compares event spellId with static map; mutates SM_EXTEND.spellIdMap and tracingSpells. All client-side. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WoW 1.12.1 Lua | embedded | Runtime environment | Target platform for Turtle WoW. No `#` operator. No `require()`. |
| SuperWoW API | Turtle WoW bundled | UNIT_CASTEVENT event source | Provides the Global Spell ID in UNIT_CASTEVENT arg4. Non-negotiable dependency for spell tracing. [CITED: core/events.lua:42-44] |
| SM_EXTEND SavedVariable | WoW built-in | Persistence layer | Auto-serialized on logout/reload to WTF/.../SuperMacro.lua. Same pattern as immuneTable and definiteBleedingTable. [CITED: core/spell_trace_immune.lua:66-102] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| macroTorch.SpellTrace:register() | existing | Declarative spell trace registration | Extended with config.spellName in this phase |
| macroTorch.player.isProwling | existing (DRUID_FIELD_FUNC_MAP) | Prowl state detection | Texture-based buff check for Prowl [CITED: classes/druid/Druid.lua:316-318] |
| macroTorch.tableLen() | existing (impl_util.lua:92) | Replace Lua `#` operator | Mandatory for WoW 1.12.1 compatibility. Used for table size checks. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Flat dual-key table `spellNameToId` | Nested table `{[spellName] = {en=id, zh=id}}` | Flat table: O(1) single lookup, simpler iteration. Nested: language separation at cost of extra dereference. CONTEXT D-02 chose flat for alignment with `tracingSpells` pattern. [CITED: 17-CONTEXT.md D-02] |
| SM_EXTEND.spellIdMap[playerCls][spellName] | SM_EXTEND.spellIdMap[spellName] (no class key) | With class key: isolates per-class spellId maps, avoids cross-class collision. Same pattern as immuneTable. [CITED: 17-CONTEXT.md D-03] |
| Batch write on logout | Immediate write on mismatch detection | Immediate write prevents data loss on client crash. In-memory table mutation is idempotent and cheap. [CITED: 17-CONTEXT.md D-05] |

**Installation:**
No external packages required. All changes use existing Lua/WoW infrastructure.

## Package Legitimacy Audit

No external packages are installed in this phase. All changes are within the existing codebase using WoW 1.12.1 API and existing `macroTorch.*` infrastructure.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Persistence across sessions | Manual file I/O or flush calls | SM_EXTEND SavedVariable + reference binding | WoW handles serialization automatically on logout/reload. Manual flush is unnecessary and fragile. Same pattern as immuneTable/definiteBleedingTable. [CITED: core/spell_trace_immune.lua:66-102] |
| Spell name to ID mapping for CastSpell | Global Spell ID (UNIT_CASTEVENT arg4) | Spellbook Index via `getSpellIdByName()` | Global Spell ID CANNOT be used with `CastSpell()`. Use the existing `getSpellIdByName()` for casting. The new spellId map is only for event matching in `tracingSpells`/UNIT_CASTEVENT. Misusing it for casting would break spells. [CITED: CLAUDE.md "Spell ID: Two Distinct Concepts"] |
| Prowl state detection | Custom state tracking or event listening | `macroTorch.player.isProwling` (buffed('Prowl', 'Ability_Ambush')) | Already implemented in DRUID_FIELD_FUNC_MAP with texture-based buff detection. No need for custom tracking. [CITED: classes/druid/Druid.lua:316-318] |
| Spell cast event detection | Custom event tracking | SuperWoW UNIT_CASTEVENT + _castSpell bottleneck | The `_castSpell` method is the single casting bottleneck for all Druid skill methods (40+). Setting `current_casting_spell` here covers every spell cast through the addon. Direct `CastSpellByName` calls in entity/Pet.lua do not go through `_castSpell` and are Pet-only, irrelevant for Druid spell tracing. [CITED: entity/Player.lua:42-87] |

**Key insight:** The existing SM_EXTEND persistence pattern (immuneTable, definiteBleedingTable) already handles all edge cases: nil guard, table initialization, reference binding, and auto-serialization. The new spellIdMap should follow this pattern identically -- no new persistence code needed beyond the same guard-then-bind structure used in `loadImmuneTable()`.

## Architecture Patterns

### System Architecture Diagram

```
ADDON INIT (build_order.txt sequence):
  1. core/spell_id_map.lua: macroTorch.SPELL_NAME_TO_ID = { ... }   [static baseline]
  2. core/spell_trace_core.lua: SpellTrace:register() reads SPELL_NAME_TO_ID
  3. classes/druid/Druid.lua: SpellTrace:register('Pounce', {spellName='Pounce', ...})

PLAYER_ENTERING_WORLD:
  onPlayerEnteringWorld() 
    -> loadSpellIdMap()   [SM_EXTEND.spellIdMap -> macroTorch.spellIdMap ref bind]
    -> SelfTest:run()

CAST SPELL:
  Druid skill method (e.g. player.pounce())
    -> _castSpell({en='Pounce', zh='突袭'}, mode, range, cost)
       -> resolve locale -> spellName='Pounce'
       -> check ready/range/resource
       -> macroTorch.current_casting_spell = 'Pounce'   [NEW: D-06]
       -> castSpellByName('Pounce', 'spell') -> GetSpellIdByName -> CastSpell(spellbookIndex, 'spell')
       -> return true

UNIT_CASTEVENT:
  SuperWoW fires event: arg1=unitId, arg2=targetId, arg3=castType, arg4=spellId, arg5=timeCost
  
  IF castType == 'CAST' AND unitId == player.guid:
    1. Spell trace matching (existing):
       IF spellId in tracingSpells ->
         recordCastTable(tracingSpells[spellId])
     
    2. Spell ID correction (NEW: D-12):
       IF macroTorch.current_casting_spell != nil:
         resolve static spellId via map resolution chain:
           a. SM_EXTEND.spellIdMap[playerCls][spellName] (runtime correction)
           b. macroTorch.SPELL_NAME_TO_ID[spellName]      (static baseline)
         IF static spellId != event.spellId:
           SM_EXTEND.spellIdMap[playerCls][spellName] = event.spellId  [immediate write]
           move tracingSpells key:  old staticId -> event.spellId
           log correction to chat
         macroTorch.current_casting_spell = nil    [NEW: D-07]
```

### Recommended Project Structure

No new directories needed. Changes spread across existing files:

```
core/
    spell_id_map.lua          [NEW] — static name->spellId mapping table
    spell_trace_core.lua      [EDIT] — SpellTrace:register spellName support
    spell_trace_immune.lua    [EDIT] — loadSpellIdMap() new function
    events.lua                [EDIT] — UNIT_CASTEVENT spellId correction logic
    combat_context.lua        [EDIT] — onPlayerEnteringWorld add loadSpellIdMap() call
entity/
    Player.lua                [EDIT] — _castSpell sets current_casting_spell
classes/druid/
    Druid.lua                 [EDIT] — SpellTrace:register call signatures change
    leveling.lua               [EDIT] — FF prowling guard addition
```

### Pattern 1: SavedVariable Reference Binding (persistence)

**What:** Bind a macroTorch.context field to a SM_EXTEND sub-table reference, enabling mutation through either path with automatic persistence.

**When to use:** Any data that needs to persist across sessions and is scoped per player class.

**Example:**
```lua
-- Source: core/spell_trace_immune.lua:67-82 (immuneTable pattern — identical structure for spellIdMap)
function macroTorch.loadImmuneTable()
    if not macroTorch.context then return end
    if not SM_EXTEND then SM_EXTEND = {} end
    if not SM_EXTEND.immuneTable then SM_EXTEND.immuneTable = {} end
    local playerCls = macroTorch.player.class
    if not SM_EXTEND.immuneTable[playerCls] then
        SM_EXTEND.immuneTable[playerCls] = {}
    end
    if not macroTorch.context.immuneTable then
        macroTorch.context.immuneTable = SM_EXTEND.immuneTable[playerCls]
    end
end
```

**spellIdMap follows the identical pattern** with `immuneTable` replaced by `spellIdMap`:
```lua
function macroTorch.loadSpellIdMap()
    if not macroTorch.context then return end
    if not SM_EXTEND then SM_EXTEND = {} end
    if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
    local playerCls = macroTorch.player.class
    if not SM_EXTEND.spellIdMap[playerCls] then
        SM_EXTEND.spellIdMap[playerCls] = {}
    end
    if not macroTorch.loginContext.spellIdMap then
        macroTorch.loginContext.spellIdMap = SM_EXTEND.spellIdMap[playerCls]
    end
end
```

Note: spellIdMap binds to `macroTorch.loginContext` (same lifecycle as castTable/landTable/failTable) rather than `macroTorch.context` (combat-scoped, reset on combat exit). This is critical -- spellId corrections must survive combat exit.

### Pattern 2: SpellId Resolution Chain

**What:** Resolve a spellName to a spellId by checking runtime corrections first, then static baseline.

**When to use:** Every time a spellId is needed for UNIT_CASTEVENT matching (setSpellTracing, event handler correction check).

```lua
-- resolve: runtime correction > static baseline
function macroTorch.resolveSpellId(spellName)
    if macroTorch.loginContext and macroTorch.loginContext.spellIdMap then
        local correctedId = macroTorch.loginContext.spellIdMap[spellName]
        if correctedId then
            return correctedId
        end
    end
    return macroTorch.SPELL_NAME_TO_ID[spellName]
end
```

### Pattern 3: current_casting_spell Lifecycle

**What:** Set before cast, clear on UNIT_CASTEVENT match. Minimal lifetime, no stale state.

**When to use:** Connecting the "what spell did we just cast" question between `_castSpell` (synchronous, knows the spell name) and `UNIT_CASTEVENT` (asynchronous, knows the spellId but not the name).

```lua
-- SET: entity/Player.lua _castSpell, before return true (only for actual casts, not mode='ready')
if mode ~= 'ready' then
    macroTorch.current_casting_spell = spellName
end
-- ... castSpellByName(spellName, ...) ...
return true

-- CLEAR: core/events.lua UNIT_CASTEVENT handler, after CAST match processing
if unitId == macroTorch.player.guid and castType == 'CAST' then
    -- ... spellId correction logic ...
    macroTorch.current_casting_spell = nil
end
```

### Anti-Patterns to Avoid

- **Pattern: setting current_casting_spell outside _castSpell.** Each Druid skill method (40+) would need its own set call. `_castSpell` is the single bottleneck -- use it. [CITED: 17-CONTEXT.md D-06]
- **Pattern: clearing current_casting_spell on SPELLCAST_FAILED or timeout.** Failed casts (out of range, not enough energy) never produce UNIT_CASTEVENT CAST events. Clearing on failure creates a dangerous gap where a subsequent successful cast in the same frame loses its spellName. The `UNIT_CASTEVENT` CAST handler is the only correct clear point. [CITED: 17-CONTEXT.md D-07]
- **Pattern: using Global Spell ID for CastSpell().** The spellId from UNIT_CASTEVENT (Global Spell ID) and from GetSpellName() (Spellbook Index) are completely different number spaces. CastSpell() requires the Spellbook Index. The new spellId map is ONLY for event matching in `tracingSpells`. [CITED: CLAUDE.md "Spell ID: Two Distinct Concepts"]
- **Pattern: binding spellIdMap to macroTorch.context.** `macroTorch.context` is reset to `{}` on combat exit (`onCombatExit` in combat_context.lua:24). SpellId corrections must persist across combat sessions. Bind to `macroTorch.loginContext` instead (reset only on PLAYER_ENTERING_WORLD). [CITED: core/combat_context.lua:21-40]
- **Pattern: guarding FF with `return` that stops subsequent modules.** The FF prowling guard should skip only the FF module itself, not prevent subsequent modules from executing. In catLeveling's linear priority chain, the FF module is the last module (Module 9), so a `return` at that point is safe -- but the guard should be `return` (skip) not `error()`. [CITED: 17-CONTEXT.md D-01]

## Common Pitfalls

### Pitfall 1: Spellbook Index vs Global Spell ID confusion

**What goes wrong:** Developer uses `getSpellIdByName()` (Spellbook Index) as the key for `tracingSpells`, expecting it to match `UNIT_CASTEVENT` arg4. These are completely different number spaces with zero overlap.

**Why it happens:** Both are called "spellId" in different contexts. The Spellbook Index is a per-character array position; the Global Spell ID is a game-data constant.

**How to avoid:** Never use `getSpellIdByName()` return value for anything related to event matching. The new spellId map (SPELL_NAME_TO_ID) stores Global Spell IDs ONLY. For casting, continue using the existing `getSpellIdByName()` -> `CastSpell()` path unchanged.

**Warning signs:** Unit testing with actual UNIT_CASTEVENT events shows tracingSpells lookup always misses despite spells being cast.

### Pitfall 2: loginContext vs context lifecycle mismatch

**What goes wrong:** Binding spellIdMap reference to `macroTorch.context` causes all runtime corrections to be lost on combat exit, reverting to static baseline on every new combat.

**Why it happens:** `onCombatExit()` sets `macroTorch.context = {}`. If `spellIdMap` was bound to `context`, the binding is lost and re-created on next `loadSpellIdMap()` call, which reads the (now re-initialized) SM_EXTEND.

**How to avoid:** Bind `spellIdMap` to `macroTorch.loginContext`, which is scoped to the login session (set once in `onPlayerEnteringWorld`, never reset during play). Both are valid patterns -- choose the correct one for the data's lifetime. `context` = combat-scoped; `loginContext` = session-scoped.

**Warning signs:** SpellId corrections only work for the first combat after login. After combat exit/re-entry, corrections revert to static baseline.

### Pitfall 3: Stale current_casting_spell from queued or instant casts

**What goes wrong:** Setting `current_casting_spell` but never clearing it causes subsequent UNIT_CASTEVENT events to incorrectly match against a stale spellName.

**Why it happens:** If a cast triggers a UNIT_CASTEVENT START but never a CAST (e.g., interrupted, out of range, target died during cast time), `current_casting_spell` remains set. The next successful cast then both sets a new value (correct) but confusion arises if someone reads it between casts.

**How to avoid:** The design in D-07 ensures `current_casting_spell` is cleared ONLY on CAST event match. This is correct because:
1. _castSpell overwrites `current_casting_spell` on every new cast attempt (self-correcting)
2. UNIT_CASTEVENT CAST is guaranteed to fire for successful casts (SuperWoW guarantee)
3. Minimum lifetime: set -> event -> clear, typically < 100ms
4. No timer-based clearing needed (avoids race conditions)

The alternative (clearing on timer, on SPELLCAST_FAILED, etc.) introduces more bugs than it solves.

### Pitfall 4: Removing old tracingSpells key without preserving the new key

**What goes wrong:** When correcting spellId, the old static spellId key in `tracingSpells` is deleted but the new event spellId key is not added, causing spell tracing to miss all future casts.

**Why it happens:** Focus on the "correction" aspect causes developer to remove the wrong key but forget to create the replacement.

**How to avoid:** The correction must both REMOVE and ADD: `tracingSpells[newSpellId] = tracingSpells[oldSpellId]; tracingSpells[oldSpellId] = nil`. Always update both ends.

## Code Examples

### Static Spell ID Map (new file: core/spell_id_map.lua)

```lua
-- Source: [CITED: 17-CONTEXT.md D-02, D-11] with verified Chinese names from classes/druid/Druid.lua _castSpell locale tables
-- Static baseline: 60-level Druid Global Spell IDs for Turtle WoW client
-- Flat dual-key table: each language name entry -> same spellId
-- Note: Faerie Fire (Feral) is NOT in this map -- it uses immune tracing only (land=false), no spellId needed [CITED: 17-CONTEXT.md D-08]
if not macroTorch.SPELL_NAME_TO_ID then
    macroTorch.SPELL_NAME_TO_ID = {
        -- English names
        ["Pounce"] = 9827,
        ["Rake"] = 1822,
        ["Rip"] = 9492,
        ["Ferocious Bite"] = 22557,
        -- Chinese names (from Druid.lua _castSpell locale tables)
        ["突袭"] = 9827,        -- Pounce
        ["斜掠"] = 1822,        -- Rake
        ["撕扯"] = 9492,        -- Rip
        ["凶猛撕咬"] = 22557,    -- Ferocious Bite
    }
end
```

### Extended SpellTrace:register with spellName support (edit: core/spell_trace_core.lua)

```lua
-- Source: [CITED: 17-CONTEXT.md D-10, D-06]
-- Modifies existing SpellTrace:register() to support config.spellName as alternative to config.spellId
function macroTorch.SpellTrace:register(name, config)
    if config.land then
        local spellId = nil
        -- NEW: resolve via spellName > resolveSpellId() > fallback to config.spellId
        if config.spellName then
            spellId = macroTorch.resolveSpellId(config.spellName)
        end
        if not spellId then
            spellId = config.spellId  -- legacy fallback [CITED: 17-CONTEXT.md D-10]
        end
        if not spellId then
            macroTorch.show("[macro-torch] SpellTrace:register(" .. name .. "): land=true but no spellId resolved", 'red')
            return
        end
        macroTorch.setSpellTracing(spellId, name)
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
```

### Updated Druid SpellTrace registrations (edit: classes/druid/Druid.lua:614-633)

```lua
-- Source: [CITED: 17-CONTEXT.md D-08, D-10]
-- spellName replaces hardcoded spellId for land tracing
-- Pounce: land=true for land tracing, immune=true for immunity detection
macroTorch.SpellTrace:register('Pounce', {
    spellName = 'Pounce',   -- NEW: name-based resolution, replaces spellId=9827
    land = true, immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
macroTorch.SpellTrace:register('Rake', {
    spellName = 'Rake',     -- NEW: replaces spellId=1822
    land = true, immune = true, debuffTexture = 'Ability_Druid_Disembowel'
})
macroTorch.SpellTrace:register('Rip', {
    spellName = 'Rip',      -- NEW: replaces spellId=9492
    land = true, immune = true, debuffTexture = 'Ability_GhoulFrenzy'
})
macroTorch.SpellTrace:register('Ferocious Bite', {
    spellName = 'Ferocious Bite',  -- NEW: replaces spellId=22557
    land = true, immune = false
})
-- Faerie Fire (Feral): unchanged — land=false, immune=true, no spellId/spellName needed [CITED: 17-CONTEXT.md D-08]
macroTorch.SpellTrace:register('Faerie Fire (Feral)', {
    land = false, immune = true, debuffTexture = 'Spell_Nature_FaerieFire'
})
```

### current_casting_spell set in _castSpell (edit: entity/Player.lua:77-87)

```lua
-- Source: [CITED: 17-CONTEXT.md D-06]
-- In _castSpell, after readiness/resource checks, before executing cast:
-- Set current_casting_spell only when mode != 'ready' (not just a readiness check)
if mode ~= 'ready' then
    macroTorch.current_casting_spell = spellName
end
-- ... existing castSpellByName/cast logic ...
return true
```

### UNIT_CASTEVENT spellId correction (edit: core/events.lua:93-96 area)

```lua
-- Source: [CITED: 17-CONTEXT.md D-12, D-07]
-- Extends existing UNIT_CASTEVENT handler with spellId correction logic
if unitId == macroTorch.player.guid and castType == 'CAST' then
    -- 1. Existing spell trace matching (unchanged)
    if spellId and macroTorch.tracingSpells[spellId] then
        macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
    end
    
    -- 2. NEW: Spell ID correction when current_casting_spell is set
    if macroTorch.current_casting_spell then
        local staticSpellId = macroTorch.resolveSpellId(macroTorch.current_casting_spell)
        if staticSpellId and staticSpellId ~= spellId then
            -- Persist correction immediately [CITED: 17-CONTEXT.md D-05]
            local playerCls = macroTorch.player.class
            if not SM_EXTEND then SM_EXTEND = {} end
            if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
            if not SM_EXTEND.spellIdMap[playerCls] then SM_EXTEND.spellIdMap[playerCls] = {} end
            SM_EXTEND.spellIdMap[playerCls][macroTorch.current_casting_spell] = spellId
            -- Sync to loginContext reference (same table, but ensure)
            if macroTorch.loginContext and not macroTorch.loginContext.spellIdMap then
                macroTorch.loginContext.spellIdMap = SM_EXTEND.spellIdMap[playerCls]
            end
            
            -- Update tracingSpells to use new spellId key
            if macroTorch.tracingSpells[staticSpellId] then
                macroTorch.tracingSpells[spellId] = macroTorch.tracingSpells[staticSpellId]
                macroTorch.tracingSpells[staticSpellId] = nil
            end
            
            macroTorch.show(string.format(
                "[macro-torch] spellId corrected: %s %d -> %d",
                macroTorch.current_casting_spell, staticSpellId, spellId
            ), 'yellow')
        end
        -- Clear current_casting_spell after processing [CITED: 17-CONTEXT.md D-07]
        macroTorch.current_casting_spell = nil
    end
end
```

### FF Prowling Guard (edit: classes/druid/leveling.lua, Module 9)

```lua
-- Source: [CITED: 17-CONTEXT.md D-01]
-- Module 9: 精灵之火(野性) — 见缝插针填充技
-- Added: not player.isProwling guard (cannot cast FF while stealthed)
if macroTorch.isSpellExist('Faerie Fire (Feral)', 'spell')
        and not clickContext.ooc
        and not player.isProwling                         -- NEW: prowling guard
        and not target.isImmune('Faerie Fire (Feral)')
        and player.isSpellReady('Faerie Fire (Feral)')
        and macroTorch.isGcdOk(clickContext) then
    player.faerie_fire_feral('raw')
    return
end
```

## Runtime State Inventory

This is not a rename/refactor/migration phase. No runtime state changes are required.

However, the new `SM_EXTEND.spellIdMap` persistence table should be noted:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — spellIdMap is a NEW SavedVariable, not migrating existing data | Code creates SM_EXTEND.spellIdMap on first use |
| Live service config | None — all changes are in WoW addon code/Lua | — |
| OS-registered state | None | — |
| Secrets/env vars | None | — |
| Build artifacts | None — SM_Extend.lua is a build output, regenerated from source | Standard build.sh run |

**Nothing found in all categories:** This phase adds a new persistence key but does not modify or migrate existing persisted data.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (built-in, WoW Lua) |
| Config file | none — self-test calls registered via SelfTest:register() |
| Quick run command | In-game: `/mt` (triggers SelfTest:run()) |
| Full suite command | In-game: `/mt` (same, all tests run on PLAYER_ENTERING_WORLD + manual trigger) |

### Phase Requirements Test Map

Phase requirement IDs were not yet mapped at research time (marked TBD in the orchestrator context). The following tests are identified by behavior:

| Behavior | Test Type | Automated Command | File Exists? |
|----------|-----------|-------------------|-------------|
| SPELL_NAME_TO_ID table exists with correct keys | core | `SelfTest:register()` in Druid.lua | Wave 0 (new) |
| resolveSpellId() resolves correctly for all 4 spells | core | `SelfTest:register()` in Druid.lua | Wave 0 (new) |
| _castSpell sets current_casting_spell on successful cast | unit | Manual in-game verification | Wave 0 (new) |
| _castSpell does NOT set current_casting_spell on mode='ready' | unit | Manual in-game verification | Wave 0 (new) |
| UNIT_CASTEVENT clears current_casting_spell | integration | Manual in-game verification | Wave 0 (new) |
| SpellId correction persists to SM_EXTEND.spellIdMap | integration | Manual in-game verification (reload UI) | Wave 0 (new) |
| CatLeveling FF does NOT cast while prowling | unit | Manual in-game verification | Wave 0 (new) |
| CatLeveling FF DOES cast when not prowling | unit | Manual in-game verification | Wave 0 (new) |
| Existing spell tracing still works (land table, immune) | regression | `/mt` self-test + in-game combat | existing |
| Existing catAtk unchanged | regression | Compare SM_Extend.lua diff for catAtk code | existing |
| Existing hunter/mage/priest/rogue/warlock/warrior registrations unchanged | regression | Compare source diff | existing |

### Sampling Rate
- **Per task commit:** Manual in-game verification for the specific task
- **Per wave merge:** Full `/mt` self-test + combat spell tracing smoke test
- **Phase gate:** All 4 Druid spell corrections verified with at least one actual UNIT_CASTEVENT mismatch scenario (requires a different client build or relog scenario)

### Wave 0 Gaps
- [ ] `core/selftest.lua` — add SPELL_NAME_TO_ID table completeness test
- [ ] `core/selftest.lua` — add resolveSpellId() function existence test
- [ ] `classes/druid/Druid.lua` — add spellName-to-spellId mapping correctness tests for all 4 spells
- [ ] Manual verification scripts needed for _castSpell/UNIT_CASTEVENT lifecycle (cannot be fully automated in self-test)

## Security Domain

No user input, network communication, or external data sources are involved in this phase. All changes are within the WoW addon sandbox using existing Lua infrastructure.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — (no user input processing) |
| V6 Cryptography | no | — |

**No applicable threat patterns** for this phase. All changes are internal to the addon with no external attack surface.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded spellId in SpellTrace:register() | spellName-based resolution with static map + runtime correction | Phase 17 | SpiritId stability across client builds; no more TODO comments about unstable spellIds |
| No connection between _castSpell and UNIT_CASTEVENT | current_casting_spell bridges the gap | Phase 17 | Enables automatic spellId correction; minimal state, no stale data |
| SpellId corrections: manual or not done | Automatic detection + immediate persistence | Phase 17 | Self-healing system; corrections survive crashes and carry across sessions |

**Deprecated/outdated:**
- **Hardcoded spellId in SpellTrace:register:** Replaced by `spellName` field. The `spellId` field is retained as a legacy fallback but should not be used in new registrations.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Static spell IDs (Pounce=9827, Rake=1822, Rip=9492, FB=22557) are correct for the current Turtle WoW client build | Standard Stack / Code Examples | LOW — if wrong, the runtime correction mechanism will auto-detect and fix on first cast. Static baseline only affects new characters, not existing ones with persisted corrections. |
| A2 | Chinese locale names match those used in Turtle WoW Chinese client (从 Druid.lua _castSpell locale tables 验证: 突袭, 斜掠, 撕扯, 凶猛撕咬) | Code Examples | LOW — these names come directly from the existing _castSpell locale tables in Druid.lua (lines 25, 33, 38, 41, 46), which have been in production use. |
| A3 | No other classes use land=true in SpellTrace:register (verified via grep: only druid/Druid.lua has land=true) | Don't Hand-Roll | LOW — grep confirmed across all source files. SM_Extend.lua showed Rogue Rip with land=true but that's the stale build output; Rogue source file has no SpellTrace:register call at all. |
| A4 | _castSpell is the sole casting bottleneck for all Druid land-traceable spells | Code Examples | LOW — verified: all Druid skill methods (claw, shred, rake, rip, ferocious_bite, pounce, cower, faerie_fire_feral, ravage, etc.) go through _castSpell. Direct CastSpellByName calls are only in entity/Pet.lua (pet spells, not relevant). |
| A5 | SM_EXTEND.spellIdMap persistence works identically to SM_EXTEND.immuneTable | Architecture Patterns | LOW — same WoW SavedVariable mechanism, same table nesting pattern, same reference binding approach. Verified against spell_trace_immune.lua which has been in production use. |
| A6 | UNIT_CASTEVENT CAST fires reliably for all successful spell casts (SuperWoW guarantee) | Common Pitfalls | LOW — existing code relies on this for spell tracing. If it stops working, all spell tracing breaks, not just the new correction mechanism. |
| A7 | Prowl state (isProwling) correctly reflects in/out of stealth via buffed('Prowl', 'Ability_Ambush') | Code Examples | LOW — this is the existing DRUID_FIELD_FUNC_MAP implementation used by catAtk opener module. Already production-tested. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WoW 1.12.1 client (Turtle WoW) | All functionality | ✓ | 1.12.1 | — (target platform) |
| SuperMacro addon | Build output destination | ✓ | bundled | — |
| SuperWoW API | UNIT_CASTEVENT events | ✓ | bundled | — (spell tracing requires it) |
| Lua 5.0 (WoW embedded) | All code execution | ✓ | 5.0 (no `#` operator) | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Sources

### Primary (HIGH confidence)
- Project source files (verified via Read tool):
  - `core/spell_trace_core.lua` — tracingSpells, setSpellTracing, SpellTrace:register, castTable/landTable/failTable
  - `core/spell_trace_immune.lua` — loadImmuneTable, loadDefiniteBleedingTable (persistence reference pattern)
  - `core/events.lua:87-97` — UNIT_CASTEVENT event handler, current spellId matching logic
  - `entity/Player.lua:42-87` — _castSpell bottleneck method, mode parameter semantics
  - `classes/druid/Druid.lua:25-59, 314-318, 611-633` — skill method _castSpell calls, isProwling impl, hardcoded spellId registrations
  - `classes/druid/leveling.lua:163-224` — catLeveling Module 9 FF release path
  - `biz_util.lua:21-61` — getSpellIdByName, isSpellExist (Spellbook Index, NOT Global Spell ID)
  - `core/combat_context.lua:37-40` — onPlayerEnteringWorld, loginContext lifecycle
  - `macro_torch.lua` — macroTorch table initialization
- `.planning/phases/17-*/17-CONTEXT.md` — All 12 implementation decisions (D-01 through D-12), Claude's Discretion areas, Deferred Ideas
- `CLAUDE.md` — WoW 1.12.1 constraints (no `#` operator), Spell ID dual-concept documentation, ref field inheritance chain
- `.claude/CLAUDE.md` — Spell ID distinction documentation, ref field inheritance pattern

### Secondary (MEDIUM confidence)
- `.planning/phases/03-spell-trace/03-CONTEXT.md` — SpellTrace:register API original design rationale, self-test framework architecture
- `.planning/phases/16-*/16-CONTEXT.md` — catLeveling architecture decisions, module priority ordering, shared decision function reusability
- `.planning/REQUIREMENTS.md` — R4 (Spell Trace configuration) and R8 (Druid logic preservation)
- `.planning/STATE.md` — Phase history, accumulated context, project decisions
- `.claude-reference/Functions.md` — WoW 1.12.1 API reference (GetSpellName verified)

### Tertiary (LOW confidence)
- [ASSUMED] Web searches for spell ID verification — web search tools returned no actionable results. Static spell IDs (9827, 1822, 9492, 22557) are from existing code and user-confirmed in CONTEXT.md D-11. The runtime correction mechanism makes static baseline errors self-correcting.

## Open Questions (RESOLVED)

1. **Will the UNIT_CASTEVENT spellId for low-rank spells differ from the level-60 baseline?** — RESOLVED: Plan 17-01 Task 1 and Plan 17-02 Task 1 implement the correction mechanism that handles multi-rank correctly. Each rank's spellId is discovered on first use and persisted, with latest-write-wins semantics. Land tracing only needs to know "did this spell land" — the actual rank doesn't matter for the trace logic. This is not a bug but expected behavior.
   - What we know: Each spell rank has a distinct Global Spell ID (e.g., Pounce rank 1=9827, rank 2=9829). The static baseline uses level-60 (max rank) IDs.

2. **Is there a race condition where UNIT_CASTEVENT fires for spell-A but current_casting_spell has been overwritten by spell-B?** — RESOLVED: Plan 17-02 Task 1 implements the current_casting_spell lifecycle (set in _castSpell, clear in UNIT_CASTEVENT). The one-action-per-press design (catLeveling returns after first successful cast) plus human reaction time + GCD between presses provides ample time for event processing. The risk of overlap is negligible.
   - What we know: The WoW 1.12.1 client processes events sequentially. _castSpell returns synchronously after CastSpellByName(). UNIT_CASTEVENT fires on the next event frame tick.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components exist in the codebase; static spell IDs verified against codebase Druid.lua locale tables and CONTEXT.md D-11
- Architecture: HIGH — persistence pattern directly mirrors loadImmuneTable (production-proven); current_casting_spell lifecycle is minimal and well-bounded; _castSpell bottleneck is confirmed through all 40+ Druid skill methods
- Pitfalls: MEDIUM — Spellbook Index vs Global Spell ID confusion is a documented real problem in this codebase (CLAUDE.md + Druid.lua:611 TODO); loginContext vs context lifecycle issue is theoretical based on code structure analysis; stale current_casting_spell risk is mitigated by design but not empirically tested

**Research date:** 2026-06-29
**Valid until:** 2026-07-29 (30 days — this is infrastructure code on a stable platform)

## Project Constraints (from CLAUDE.md)

- **WoW 1.12.1 Lua constraints:** No `#` unary length operator. Use `macroTorch.tableLen(tbl)` for table length. Use `table.insert(tbl, val)` to append to arrays.
- **Global visibility:** All `macroTorch.*` symbols are global. No `require()` support in WoW 1.12.1 Lua. Code ordering is managed by `build_order.txt`.
- **Build system:** `build_order.txt` concatenates Lua files into `SM_Extend.lua`. New files must be inserted at the correct position.
- **Coding conventions:** Comments in English, camelCase naming for functions/fields, UPPER_SNAKE_CASE for module-level constants.
- **No hand-rolled persistence:** Use SM_EXTEND SavedVariable + reference binding (same as immuneTable).
- **One-action-per-press:** All rotation macros return after first successful cast.
- **API accuracy caveat:** WoW client API returns are not always accurate for debuff/buff durations. Custom tracking is implemented for precise timing.