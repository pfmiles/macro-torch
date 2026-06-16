# Phase 10: Druid Combo Methods - Research

**Researched:** 2026-06-16
**Domain:** World of Warcraft 1.12.1 Lua addon -- Druid one-button macro form-routing layer
**Confidence:** HIGH

## Summary

Phase 10 creates 5 top-level "combo" macro methods (`druidAtk`/`druidAoe`/`druidHeal`/`druidDefend`/`druidControl`) that route to existing form-specific sub-methods using if-elseif chains based on the player's current shapeshift form. This is a thin routing layer, not new combat logic. The phase also extracts the existing bear-routing logic from `catAtk` (lines 380-384 of `Druid.lua`) into `druidAtk`, and deletes unused old utility methods (`druidStun`, `druidDefend`, `druidControl`) from `utility.lua` while absorbing `druidStun` logic into the new `druidControl`.

**Primary recommendation:** Create a single new file `classes/druid/combo.lua` with 5 global functions in `macroTorch.*` namespace. Each function is a thin router: detect form via `player.isInCatForm`/`player.isInBearForm`, branch accordingly, delegate to existing skill methods. The most complex logic is in `druidHeal` (canceling form first, then healing) and `druidControl` (merging `druidStun` logic with `druidControl`).

## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** All 5 combo methods use simple if-elseif chains for form routing. No dispatch tables. Rationale: WoW macros execute synchronously; if-elseif on 3 combat forms is 3-4x faster than table lookup, consistent with the existing bear-routing precedent in `catAtk`.

**D-02:** Auto-form-switching behavior per method:
- `druidAtk`: **Never** auto-switch forms. Switching clears energy/rage and triggers 1.5s GCD.
- `druidHeal`: **Must** auto-switch to humanoid form. Healing spells cannot be cast in beast forms.
- `druidAoe`: **No** auto-switch. Bear and caster each have their own AOE skills.
- `druidDefend`: **Partial** switch. Barkskin works in all forms. Frenzied Regeneration requires bear form.
- `druidControl`: **Auto-switch** to appropriate form. Control skills work in humanoid or bear form.

**D-03:** `druidAtk` routing: Cat Form -> `catAtk(rough)`, Bear Form/Dire Bear Form -> `bearAtk(rough)`, Caster Form -> return (future casterAtk placeholder).

**D-04:** `druidAtk` signature: `macroTorch.druidAtk(rough)`, forwards `rough` parameter to catAtk/bearAtk.

**D-05:** Remove existing bear routing from `catAtk` (Druid.lua lines 380-384: `if clickContext.isInBearForm then bearAtk(rough); return end`).

**D-06:** `druidAoe` routing: Bear Form -> `bearAoe()`, Caster Form -> `hurricane('ready')`, Cat Form -> return (no AOE in Vanilla cat).

**D-07:** Hurricane is a channeled spell, simpler than bearAoe's modular clickContext. Just check form + mana + spell readiness, then cast.

**D-08:** `druidAoe` signature: `macroTorch.druidAoe()`, no parameters.

**D-09:** `druidHeal` single-step + HOT-priority logic. One action per keypress:
1. If in cat/bear form -> cancel form (CancelShapeshiftForm or toggle form skill), return true.
2. If Rejuvenation ready, player health < 50%, no Rejuvenation HOT -> cast `rejuvenation('safe', true)`.
3. If player health < 40% -> cast `healing_touch('safe', true)`.
4. Otherwise do nothing.

**D-10:** V1 self-heal only (`onSelf=true`). Group healing is a future phase.

**D-11:** Need "humanoid form" detection. Current `isInCasterForm` only detects Moonkin. Actual need: `not isInCatForm and not isInBearForm`.

**D-12:** `druidHeal` signature: `macroTorch.druidHeal()`, no parameters.

**D-13:** `druidDefend` is a fresh impl, not dependent on old utility.lua druidDefend (which is deleted).

**D-14:** `druidDefend` module priority: 1. Barkskin (all forms, check ready). 2. Frenzied Regeneration (requires bear form shift).

**D-15:** `druidDefend` signature: `macroTorch.druidDefend()`, no parameters.

**D-16:** `druidControl` merges druidStun logic:
1. Bear form close range -> Bash (stun), far range -> Feral Charge (charge).
2. Humanoid form -> Hibernate (Beast/Dragonkin) or Entangling Roots (others).
3. Non-bear, non-humanoid -> auto-shift to bear or humanoid.

**D-17:** Delete old `druidDefend`/`druidControl`/`druidStun` from `utility.lua`.

**D-18:** `druidControl` signature: `macroTorch.druidControl()`, no parameters.

**D-19:** New file: `classes/druid/combo.lua` with all 5 global functions.

**D-20:** `build_order.txt`: combo.lua after utility.lua, before bear.lua/cat.lua (only depends on druidBuffs in utility.lua).

**D-21:** `druidBuffs` stays in utility.lua unchanged.

### Claude's Discretion

- How to implement "humanoid form" detection (new `isInHumanoidForm` field vs inline `not isInCatForm and not isInBearForm`)
- Bash vs Feral Charge distance threshold logic (reuse existing druidStun pattern)
- Hurricane mana check threshold
- Code organization order and comment style within `combo.lua`
- Specific condition checks for Barkskin and Frenzied Regeneration
- Whether druidHeal should check for existing Rejuvenation HOT to avoid double-casting

### Deferred Ideas (OUT OF SCOPE)

- druidHeal group healing (heal tank, smart target selection)
- druidHeal Nature's Swiftness + instant Healing Touch combo
- casterAtk moonkin DPS (placeholder in druidAtk)
- Cat form AOE (not available in WoW 1.12.1)
- druidBuff unification
- druidDefend Frenzied Regeneration rage management (Enrage pre-fetch)

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Form detection | API/Backend (player entity) | -- | `player.isInCatForm` etc. are lazy-computed properties in DRUID_FIELD_FUNC_MAP, resolved through metatable chain |
| Form routing (if-elseif) | Macro entry (combo.lua) | -- | Combo methods are global functions that decide which sub-method to call; this is pure routing logic |
| Combat execution | API/Backend (delegated sub-methods) | -- | catAtk, bearAtk, bearAoe, skill methods all execute in the Druid instance context |
| Form switching | API/Backend (skill method calls) | -- | CancelShapeshiftForm is a WoW native API; cat_form/bear_form are _castSpell-wrapped skill methods |
| Health/mana queries | API/Backend (player entity) | -- | `player.healthPercent`, `player.mana` auto-resolve through Unit.lua UNIT_FIELD_FUNC_MAP |
| Target queries | API/Backend (target entity) | -- | `target.type`, `target.distance`, `target.isCanAttack` resolve through Target class |

## Source Code Findings

### Druid.lua -- Key Observations

**File:** `classes/druid/Druid.lua` (1311 lines)

1. **catAtk structure (lines 299-428):** Instance method `obj.catAtk(rough)` on the Druid prototype. Creates a `local clickContext = {}` for single-click caching. Runs modules in priority order: idol recover, health/mana saver, targetEnemy, keepAutoAttack, burstMod, bear-routing (lines 380-384), openerMod, oocMod, termMod, otMod, tigerFury, debuffMod, regularAttack, reshiftMod. Returns nothing -- modules either act or fall through.

2. **Bear routing code (lines 380-384):** The exact code to remove:
```lua
-- roughly bear form logic branch, TODO 其实bear形态逻辑应该完全从catAtck逻辑中剥离出来，在最上层的宏里面通过当前形态来路由
if clickContext.isInBearForm then
    macroTorch.bearAtk(clickContext.rough)
    return
end
```

3. **DRUID_FIELD_FUNC_MAP (lines 434-467):** Contains 5 form-detection functions:
   - `isInCatForm` -> `self.isFormActive('Cat Form')`
   - `isInBearForm` -> `self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')` (OR logic)
   - `isInTravelForm` -> `self.isFormActive('Travel Form')` (reserved)
   - `isInAquaticForm` -> `self.isFormActive('Aquatic Form')` (reserved)
   - `isInCasterForm` -> `self.isFormActive('Moonkin Form')` (reserved)

4. **No `isInHumanoidForm` exists:** The DRUID_FIELD_FUNC_MAP lacks a "humanoid/normal form" detection. druidHeal needs `not isInCatForm and not isInBearForm`.

5. **Skill method signatures verified:**
   - `bash(mode)`: Type A, enemy target, rage cost 10
   - `feral_charge(mode)`: Type A, enemy target, range=25, no resource cost
   - `hibernate(mode)`: Type A, enemy target, range=30, no resource cost
   - `entangling_roots(mode)`: Type A, enemy target, range=30, no resource cost
   - `hurricane(mode)`: Type B, self-target, no resource cost
   - `rejuvenation(mode, onSelf)`: Type C, flexible target, range=40, no resource cost
   - `healing_touch(mode, onSelf)`: Type C, flexible target, range=40, no resource cost
   - `barkskin(mode)`: Type B, self-target, no resource cost
   - `frenzied_regeneration(mode)`: Type B, self-target, rage cost 10
   - `dire_bear_form(mode)`: Type B, self-target, no resource cost
   - `cat_form(mode)`: Type B, self-target, no resource cost

### cat.lua -- Key Observations

**File:** `classes/druid/cat.lua` (388 lines)

All modules are global functions in `macroTorch.*` namespace (e.g., `macroTorch.burstMod`, `macroTorch.regularAttack`, `macroTorch.oocMod`). They accept `clickContext` as parameter. Each module typically returns early if its conditions aren't met, or executes a skill and returns. The "one action per click" pattern is implicit: each success path either returns (in early-return modules) or the next module runs. The key pattern: `macroTorch.player.catAtk(rough)` is an **instance method** on the Druid prototype, while macroTorch.oocMod etc. are **global functions**.

### bear.lua -- Key Observations

**File:** `classes/druid/bear.lua` (147 lines)

- `bearAoe()`: Global function, no parameters. Creates its own clickContext, checks `player.isInBearForm`, runs `bearDebuffMod` then `swipe('safe')`. Simple and clean.
- `bearAtk(rough)`: Global function, one parameter. Full module pipeline similar to catAtk but simpler.
- Both use `macroTorch.player.mana` for rage (UnitMana auto-returns rage in bear form).

### utility.lua -- State of Methods to Delete

**File:** `classes/druid/utility.lua` (57 lines)

- `druidBuffs()` (lines 2-12): **KEEP** -- not in Phase 10 scope. Casts Mark of the Wild, Thorns, Nature's Grasp on self if not buffed.
- `druidStun()` (lines 13-32): **DELETE, logic MERGED into druidControl**. Current logic: shift to bear if not, reshift if rage=0, Bash if near, Feral Charge if far.
- `druidDefend()` (lines 33-48): **DELETE, replaced by fresh druidDefend**. Current logic: Barkskin then Frenzied Regeneration with Enrage pre-fetch.
- `druidControl()` (lines 49-56): **DELETE, merged with druidStun into new druidControl**. Current logic: Hibernate for Beast/Dragonkin, Entangling Roots for others.

All three methods to delete have no callers (verified: grep of entire codebase shows only the function definitions in utility.lua, no external references).

### Player.lua -- Base Class Methods

**File:** `entity/Player.lua` (791 lines)

- `_castSpell(localeNames, mode, range, resourceCost, onSelf)`: Central casting method. Handles locale selection, readiness check (skip if `mode=='raw'`), safe mode distance+resource checks, then executes cast. Returns boolean.
- `_isInRange(range)`: If range <= 0 or nil, always true (melee). Otherwise checks `target.distance <= range`.
- `_hasResource(cost)`: Checks `self.mana >= cost`. UnitMana auto-returns correct resource (energy/rage/mana) per current form.
- `isSpellReady(spellName)`: Wraps `SpellReady` with pcall. Checks both SpellReady and cooldown.
- `isFormActive(formName)`: Iterates `GetNumShapeshiftForms()` + `GetShapeshiftFormInfo()`. Checks active form name match.

### Unit.lua -- Base Entity

**File:** `entity/Unit.lua` (241 lines)

- `mana` property: `UnitMana(self.ref)`. In bear form returns rage, in cat returns energy, in caster returns mana.
- `healthPercent` property: `UnitHealth(self.ref) / UnitHealthMax(self.ref) * 100`.
- `type` property: `UnitCreatureType(self.ref)` -- used by druidControl for Beast/Dragonkin detection.
- `distance` property: `UnitXP("distanceBetween", "player", self.ref)`.
- `hasBuff(spellOrItemName)`: Iterates UnitBuff/UnitDebuff for texture match.

### build_order.txt -- Insertion Point

**File:** `build_order.txt` (52 lines)

Current Druid section (lines 27-30):
```
classes/druid/Druid.lua
classes/druid/cat.lua
classes/druid/bear.lua
classes/druid/utility.lua
```

**Required change:** Insert `classes/druid/combo.lua` after line 30 (after utility.lua). Result:
```
classes/druid/Druid.lua
classes/druid/cat.lua
classes/druid/bear.lua
classes/druid/utility.lua
classes/druid/combo.lua         <-- NEW
```

Rationale: combo.lua only depends on `druidBuffs()` from utility.lua and global functions from cat.lua/bear.lua (bearAtk, bearAoe, and cat module functions). All dependency sources precede combo.lua in order.

### core/class.lua -- No Changes Needed

**File:** `core/class.lua` (59 lines)

- `initPlayer()` works with `PLAYER_CLASS_REGISTRY`, correctly instantiates Druid. Combo methods are global functions, not instance methods, so no class registration changes needed.
- `classMetatable(cls, fieldMapName)`: Standard factory, no changes.

### core/events.lua -- No Changes Needed

**File:** `core/events.lua` (118 lines)

- No wiring needed for combo methods. They are top-level global functions invoked from macros, not from event handlers.
- `initPlayer` is called at PLAYER_ENTERING_WORLD, handled already.

### core/selftest.lua -- Test Patterns to Follow

**File:** `core/selftest.lua` (584 lines)

Existing Druid tests (Category G1/G2, lines 1252-1310) follow this pattern:
- Guard: `if UnitClass('player') ~= 'Druid' then return end`
- Register: `macroTorch.SelfTest:register("Druid: ...", function() ... end, true)` -- `true` = isOptional
- Assert: `assert(type(val) == "boolean", "message")`
- Avoid invocation; test existence/types not game-state-dependent behavior

## Skill Method Contracts

### Methods Called by druidAtk (routing layer)
| Method | Signature | Return | Call Pattern |
|--------|-----------|--------|-------------|
| `catAtk(rough)` | `obj.catAtk(rough)` -- instance method | void (modules act) | `macroTorch.player.catAtk(rough)` [VERIFIED: Druid.lua:299] |
| `bearAtk(rough)` | `macroTorch.bearAtk(rough)` -- global | void (modules act) | `macroTorch.bearAtk(rough)` [VERIFIED: bear.lua:81] |

### Methods Called by druidAoe
| Method | Signature | Return | Call Pattern |
|--------|-----------|--------|-------------|
| `bearAoe()` | `macroTorch.bearAoe()` -- global | void | `macroTorch.bearAoe()` [VERIFIED: bear.lua:64] |
| `hurricane(mode)` | `obj.hurricane(mode)` -- instance (Type B) | boolean | `macroTorch.player.hurricane('ready')` [VERIFIED: Druid.lua:173] |

### Methods Called by druidHeal
| Method | Signature | Return | Call Pattern |
|--------|-----------|--------|-------------|
| `rejuvenation(mode, onSelf)` | `obj.rejuvenation(mode, onSelf)` -- Type C | boolean | `macroTorch.player.rejuvenation('safe', true)` [VERIFIED: Druid.lua:214] |
| `healing_touch(mode, onSelf)` | `obj.healing_touch(mode, onSelf)` -- Type C | boolean | `macroTorch.player.healing_touch('safe', true)` [VERIFIED: Druid.lua:206] |

### Methods Called by druidDefend
| Method | Signature | Return | Call Pattern |
|--------|-----------|--------|-------------|
| `barkskin(mode)` | `obj.barkskin(mode)` -- Type B | boolean | `macroTorch.player.barkskin('ready')` [VERIFIED: Druid.lua:157] |
| `frenzied_regeneration(mode)` | `obj.frenzied_regeneration(mode)` -- Type B | boolean | `macroTorch.player.frenzied_regeneration('ready')` [VERIFIED: Druid.lua:185] |
| `dire_bear_form(mode)` | `obj.dire_bear_form(mode)` -- Type B | boolean | `macroTorch.player.dire_bear_form('ready')` [VERIFIED: Druid.lua:128] |

### Methods Called by druidControl
| Method | Signature | Return | Call Pattern |
|--------|-----------|--------|-------------|
| `bash(mode)` | `obj.bash(mode)` -- Type A | boolean | `macroTorch.player.bash('ready')` [VERIFIED: Druid.lua:66] |
| `feral_charge(mode)` | `obj.feral_charge(mode)` -- Type A, range=25 | boolean | `macroTorch.player.feral_charge('ready')` [VERIFIED: Druid.lua:82] |
| `hibernate(mode)` | `obj.hibernate(mode)` -- Type A, range=30 | boolean | `macroTorch.player.hibernate('safe')` [VERIFIED: Druid.lua:107] |
| `entangling_roots(mode)` | `obj.entangling_roots(mode)` -- Type A, range=30 | boolean | `macroTorch.player.entangling_roots('safe')` [VERIFIED: Druid.lua:103] |
| `dire_bear_form(mode)` | `obj.dire_bear_form(mode)` -- Type B | boolean | `macroTorch.player.dire_bear_form('ready')` [VERIFIED: Druid.lua:128] |

**Note on mode parameter:** `'ready'` = cooldown check only; `'safe'` = cooldown + range + resource check; `'raw'` = no checks, always attempts. For combo methods, `'ready'` is used when the form-switch or cooldown is the primary gate; `'safe'` is used for skills that also need range and resource validation.

## Form Detection Matrix

| Form State | Detection Method | Notes |
|------------|-----------------|-------|
| Cat Form | `player.isInCatForm` | `isFormActive('Cat Form')`, no Dire variant exists [VERIFIED: Druid.lua:449-451] |
| Bear Form | `player.isInBearForm` | OR logic: `isFormActive('Bear Form') or isFormActive('Dire Bear Form')` [VERIFIED: Druid.lua:452-454] |
| Dire Bear Form | `player.isInBearForm` | Same detection as Bear Form (OR behavior above) |
| Moonkin Form | `player.isInCasterForm` | `isFormActive('Moonkin Form')` -- reserved for future [VERIFIED: Druid.lua:461-463] |
| Travel Form | `player.isInTravelForm` | `isFormActive('Travel Form')` [VERIFIED: Druid.lua:455-457] |
| Aquatic Form | `player.isInAquaticForm` | `isFormActive('Aquatic Form')` [VERIFIED: Druid.lua:458-460] |
| Humanoid (no form) | `not player.isInCatForm and not player.isInBearForm` | No dedicated field exists. isInCasterForm only detects Moonkin, NOT humanoid. |

**Claude's discretion -- recommendation:** Use inline `not player.isInCatForm and not player.isInBearForm` for druidHeal's humanoid detection rather than adding a new `isInHumanoidForm` field. Rationale: (1) Only druidHeal and druidControl need this check. (2) Adding a new DRUID_FIELD_FUNC_MAP field requires a SelfTest registration and increases the field surface. (3) The inline form is explicit and readable: it unambiguously means "not in cat form and not in bear form". (4) It avoids confusion with `isInCasterForm` (which means Moonkin, not humanoid).

**Form switching mechanism:** WoW 1.12.1 provides `CancelShapeshiftForm()` as a native API to drop any active shapeshift form, returning the player to humanoid form. Alternatively, casting a form skill while already in that form toggles back to humanoid form (e.g., `cat_form()` while in cat form cancels the form). The CONTEXT.md author notes that `CancelShapeshiftForm()` is the preferred approach for druidHeal since reshift (turtle WoW specific) would wastefully shift back to animal form.

## Pattern Catalog

### Pattern 1: Global Function Definition (for combo methods)
```lua
-- Source: bear.lua:81 -- bearAtk
function macroTorch.bearAtk(rough)
    local clickContext = {}
    -- ... logic ...
end
```
All 5 combo methods are global functions in `macroTorch.*`. The planner should follow this style exactly. [VERIFIED: bear.lua:81]

### Pattern 2: clickContext Single-Click Caching (for druidHeal/druidDefend/druidControl)
```lua
-- Source: Druid.lua:299-301 -- catAtk
local clickContext = {}
clickContext.rough = macroTorch.toBoolean(rough)
```
Create a local table per invocation. Cache expensive API calls (health, mana, buff checks) as lazy fields when needed. [VERIFIED: Druid.lua:299-301]

### Pattern 3: Form-Routing if-elseif Chain
```lua
-- Source: Druid.lua:381-384 -- existing bear routing in catAtk (template)
if clickContext.isInBearForm then
    macroTorch.bearAtk(clickContext.rough)
    return
end
```
The routing pattern: check form, call sub-method, return (early exit from routing function). Each branch either handles the call or falls through. [VERIFIED: Druid.lua:381-384]

### Pattern 4: One Action Per Click (return-after-success)
```lua
-- Source: cat.lua modules -- e.g., macroTorch.safeRake
function macroTorch.safeRake(clickContext)
    if macroTorch.player.isSpellReady('Rake') and ... then
        macroTorch.player.rake('ready')
        return true
    end
    return false
end
```
Modules return true on success, false on skip. The routing layer relies on sub-methods to handle their own success/failure. [VERIFIED: cat.lua:306-317]

### Pattern 5: Instance Method Access via macroTorch.player
```lua
-- Source: bear.lua:91,103 -- rage = player.mana
local player = macroTorch.player
clickContext.rage = player.mana
-- ...
player.targetEnemy()
```
All combo methods access `macroTorch.player` as the global Druid instance. `player.mana` auto-returns correct resource. [VERIFIED: bear.lua:91,103]

### Pattern 6: Target Validation Guard
```lua
-- Source: Druid.lua:371-372 -- catAtk
if not target.isCanAttack then
    player.targetEnemy()
else
    -- proceed
end
```
Before executing combat actions, verify target is valid. druidControl should have a similar guard since it requires a valid target. [VERIFIED: Druid.lua:371-372]

### Anti-Patterns to Avoid

- **Hardcoding `'player'` ref string:** Use `self.ref` or `macroTorch.player` for the Druid instance. The player entity is a singleton global, not a string reference. [VERIFIED: CLAUDE.md ref field inheritance chain]

- **Using `#` unary length operator:** WoW 1.12.1 Lua does not support it. Use `macroTorch.tableLen(tbl)` or `table.insert`. [VERIFIED: CLAUDE.md]

- **Switching forms in druidAtk:** D-02 explicitly forbids it. Energy/rage loss + 1.5s GCD makes auto-switching catastrophic. [VERIFIED: CONTEXT.md D-02]

- **Calling multiple actions per click in druidHeal:** D-09 mandates one action per keypress. Each press of druidHeal does one thing: cancel form OR cast Rejuvenation OR cast Healing Touch. Never two actions in one press. [VERIFIED: CONTEXT.md D-09]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form detection | Custom form-name string matching | `player.isInCatForm` / `player.isInBearForm` | Already implemented in DRUID_FIELD_FUNC_MAP with proper OR logic for Dire Bear [VERIFIED: Druid.lua:449-454] |
| Spell casting | Raw `CastSpellByName` | `player._castSpell()` via skill methods | Handles locale selection, cooldown, range, resource checks [VERIFIED: Player.lua:40-82] |
| Health/mana query | Raw `UnitHealth('player')` | `player.healthPercent` / `player.mana` | Lazy-computed via FIELD_FUNC_MAP, cached per access [VERIFIED: Unit.lua:111-133] |
| Range check | Raw `CheckInteractDistance` | `player._isInRange(range)` or `isNearBy(clickContext)` | Already has target existence guard and distance comparison [VERIFIED: Player.lua:87-95] |
| Target type detection | Raw `UnitCreatureType` | `macroTorch.target.type` | Already in UNIT_FIELD_FUNC_MAP, handles nil/empty to 'Unknown' [VERIFIED: Unit.lua:139-144] |
| Buff/debuff detection | Raw `UnitBuff`/`UnitDebuff` iteration | `player.hasBuff(texture)` or `player.buffed(name, texture)` | Already wraps 40-slot iteration [VERIFIED: Unit.lua:26-45] |

## Integration Change List

### Change 1: New File -- classes/druid/combo.lua
**Action:** Create file containing 5 global functions: `macroTorch.druidAtk`, `macroTorch.druidAoe`, `macroTorch.druidHeal`, `macroTorch.druidDefend`, `macroTorch.druidControl`.

### Change 2: Modify classes/druid/Druid.lua -- Remove Lines 380-384
**Action:** Delete the bear routing code from `catAtk`:
```lua
-- roughly bear form logic branch, TODO 其实bear形态逻辑应该完全从catAtck逻辑中剥离出来，在最上层的宏里面通过当前形态来路由
if clickContext.isInBearForm then
    macroTorch.bearAtk(clickContext.rough)
    return
end
```
**Also remove** `clickContext.isInBearForm` cache (line 348): `clickContext.isInBearForm = player.isInBearForm` -- this was only used for the bear routing check. Keep `clickContext.isInCatForm` (line 349) as it's used by `burstMod` and other modules.

### Change 3: Modify classes/druid/utility.lua -- Delete 3 Functions
**Action:** Remove functions `druidStun()`, `druidDefend()`, `druidControl()`.
**Keep:** `druidBuffs()` (lines 2-12).
**Result:** utility.lua reduces from 57 lines to ~13 lines (druidBuffs only + copyright header).

### Change 4: Modify build_order.txt -- Add combo.lua
**Action:** Insert `classes/druid/combo.lua` on a new line after line 30 (`classes/druid/utility.lua`).

## Edge Cases and Risk Assessment

### Edge Case 1: druidAtk called with no target or friendly target
**Risk:** `catAtk(rough)` internally calls `targetEnemy()` if no target, then checks `target.isCanAttack` before attacking. `bearAtk(rough)` same pattern. Safe -- sub-methods handle it.
**Mitigation:** None needed; sub-methods already guard.

### Edge Case 2: druidHeal called when already in humanoid form
**Risk:** The form-cancellation step (step 1 of D-09 logic) would attempt CancelShapeshiftForm() when no form is active. WoW API behavior: CancelShapeshiftForm() is a no-op when no form is active (no error).
**Mitigation:** Guard the form cancel with `if player.isInCatForm or player.isInBearForm then CancelShapeshiftForm(); return end`. If already humanoid, fall through to healing logic.

### Edge Case 3: druidHeal Rejuvenation HOT already active
**Risk:** D-09 says "if no Rejuvenation HOT". Without checking, would repeatedly try to cast Rejuvenation (which has a cooldown timer anyway, so the `'safe'` mode's `isSpellReady` check would block it). But the HOT duration check avoids wasteful cooldown checks.
**Claude's discretion recommendation:** Check for existing Rejuvenation HOT using `player.buffed('Rejuvenation')` or `player.hasBuff('Spell_Nature_Rejuvenation')`. This is consistent with the existing codebase pattern of HOT detection (see `isRipPresent` etc.). The CONTEXT.md decision says "检查是否有人形态HOT避免重复施法" is a Claude discretion item, and implementing it is low-cost and improves efficiency.

### Edge Case 4: Dire Bear Form vs Bear Form in druidAtk routing
**Risk:** `isInBearForm` already handles both with OR logic. No risk.
**Mitigation:** Already correct. `player.isInBearForm` returns true for both Bear Form and Dire Bear Form.

### Edge Case 5: druidAoe Hurricane mana check
**Risk:** Hurricane costs significant mana (~1035 at rank 3). If spammed without mana check, could leave the player OOM.
**Claude's discretion recommendation:** Check `player.mana >= 1000` as a threshold (Hurricane base cost is ~880 at rank 1, scaling up). Use `player.manaPercent > 20` (percentage-based) or a flat mana threshold. Percentage-based is more robust across levels. Since CONTEXT.md explicitly marks mana check as Claude's discretion, recommend a simple `player.mana >= 880` or use the `'safe'` mode which will check resource if a cost is configured. However, Hurricane's skill method signature is `hurricane(mode)` where mode is passed through to `_castSpell` with `resourceCost=nil`, so `'safe'` mode won't check resource. The mana threshold should be an explicit guard in druidAoe before calling `hurricane('ready')`.

### Edge Case 6: druidControl has no valid target
**Risk:** Bash, Feral Charge, Hibernate, and Entangling Roots all require a valid enemy target. If the player presses druidControl with no target or a friendly target, the skill method calls will fail gracefully (return false).
**Mitigation:** Add a `not target.isCanAttack` guard at the top of druidControl. If no valid target, try `player.targetEnemy()`. If still no target, return.

### Edge Case 7: druidControl Bash/Feral Charge distance threshold
**Risk:** Bash is melee range (range=nil in skill method, meaning it always proceeds past range check since `_isInRange(nil)` returns true if target exists). Feral Charge has range=25. The distance threshold determines routing.
**Claude's discretion recommendation:** Use the existing pattern from utility.lua's `druidStun`: check `macroTorch.isNearBy(clickContext)` (which checks `target.distance <= 3`). If near, Bash. If far and has Feral Charge trained, use Feral Charge.

### Edge Case 8: druidDefend Frenzied Regeneration requires bear form but player may be in cat
**Risk:** If player is in cat form, `dire_bear_form('ready')` needs to be called first (as the old druidDefend does in utility.lua:39-41). But switching to bear form takes a GCD.
**Mitigation:** Follow the two-step pattern: (1) Check if Barkskin is ready -- if so, cast it (works in any form). Return. (2) On next press, check Frenzied Regeneration. If not in bear form, shift to bear first. Return. On next press (now in bear form), cast Frenzied Regeneration. This respects the "one action per click" philosophy.

### Edge Case 9: druidControl form-switching during combat
**Risk:** D-16 says "non-bear, non-humanoid -> auto-shift to bear or humanoid". Auto-shifting from cat to bear in combat loses energy and triggers 1.5s GCD. This is acceptable for a control skill (the alternative is being unable to cast control at all).
**Mitigation:** The design intent (D-16) is clear that auto-shifting is appropriate for druidControl. The old `druidStun` already does this (utility.lua:18-20).

### Edge Case 10: Moonkin Form (isInCasterForm) ambiguity
**Risk:** `isInCasterForm` detects Moonkin Form, NOT humanoid form. If a druid is in Moonkin form and presses druidAtk, the current D-03 design says "Caster Form -> return". This is correct -- Moonkin can't use cat or bear abilities.
**Mitigation:** The routing is "Caster Form" in D-03, and `isInCasterForm` correctly detects Moonkin. druidAoe's "Caster Form -> hurricane" branch intentionally covers Moonkin form too (hurricane can be cast in Moonkin). No issue.

## Test Strategy

### Test Pattern to Follow
Use `macroTorch.SelfTest:register()` with the pattern from existing Druid tests (Druid.lua lines 1252-1310):
- Guard: `if UnitClass('player') ~= 'Druid' then return end`
- Register as optional: third parameter `true` (all Druid-specific tests are optional)
- Test function existence, not game-state-dependent behavior

### Recommended Self-Tests for Phase 10
| Test Name | What It Verifies |
|-----------|-----------------|
| "Druid: combo methods -- druidAtk exists" | `type(macroTorch.druidAtk) == "function"` |
| "Druid: combo methods -- druidAoe exists" | `type(macroTorch.druidAoe) == "function"` |
| "Druid: combo methods -- druidHeal exists" | `type(macroTorch.druidHeal) == "function"` |
| "Druid: combo methods -- druidDefend exists" | `type(macroTorch.druidDefend) == "function"` |
| "Druid: combo methods -- druidControl exists" | `type(macroTorch.druidControl) == "function"` |

### Manual Test (HUMAN-UAT.md) Suggestions
1. In cat form: `/run macroTorch.druidAtk(false)` should trigger catAtk (shred/claw rotation)
2. In bear form: `/run macroTorch.druidAtk(false)` should trigger bearAtk (maul rotation)
3. In bear form: `/run macroTorch.druidAoe()` should trigger Swipe
4. In caster form: `/run macroTorch.druidAoe()` should cast Hurricane
5. In cat form: `/run macroTorch.druidHeal()` should CancelShapeshiftForm; second press should check Rejuvenation
6. `/run macroTorch.druidDefend()` should cast Barkskin if available
7. Target a beast: `/run macroTorch.druidControl()` should Hibernate (if humanoid) or Bash (if bear and near)

### Wave 0 Gaps
No existing test files for combo methods (new file). The self-test registrations should be added to `classes/druid/combo.lua` itself or to `Druid.lua` (following the pattern where Druid.lua contains all Druid self-test registrations).

## Implementation Order Recommendation

1. **Create `classes/druid/combo.lua`** -- Write all 5 functions + self-test registrations
2. **Add combo.lua to `build_order.txt`** -- Insert after utility.lua
3. **Modify `classes/druid/Druid.lua`** -- Remove bear routing (lines 380-384) and `clickContext.isInBearForm` cache (line 348)
4. **Modify `classes/druid/utility.lua`** -- Delete druidStun, druidDefend, druidControl
5. **Run `./build.sh`** -- Verify SM_Extend.lua concatenation
6. **Verify with `grep`** -- Confirm removal: `grep "isInBearForm then" classes/druid/Druid.lua` should return 0 for catAtk function
7. **In-game test** -- Use `/run macroTorch.druidAtk(false)` etc.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash (build.sh) | Build concatenation | SKIPPED | -- | -- |
| WoW 1.12.1 client | In-game testing | SKIPPED | -- | Manual testing required |
| SuperMacro addon | Macro execution | SKIPPED | -- | Pre-existing dependency |

**Note:** All dependencies are pre-existing project requirements, not new additions. No new external tools needed.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | SelfTest (custom framework in `core/selftest.lua`) |
| Config file | none -- tests registered at load time via `SelfTest:register()` |
| Quick run command | `/mt` (in-game chat) |
| Full suite command | `/mt` (same -- runs all registered tests) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| D-03 | druidAtk form routing | manual | `/run macroTorch.druidAtk(false)` in cat/bear form | N/A (in-game only) |
| D-06 | druidAoe form routing | manual | `/run macroTorch.druidAoe()` in bear/caster form | N/A |
| D-09 | druidHeal single-step healing | manual | `/run macroTorch.druidHeal()` in cat form | N/A |
| D-14 | druidDefend Barkskin/Frenzied | manual | `/run macroTorch.druidDefend()` | N/A |
| D-16 | druidControl with target | manual | `/run macroTorch.druidControl()` with target | N/A |
| -- | Combo methods exist | self-test | `/mt` (auto-runs on login) | Wave 0: new in combo.lua |

### Sampling Rate
- **Per task commit:** `grep` verification + build check
- **Per wave merge:** `./build.sh` success + in-game smoke test
- **Phase gate:** Full in-game test of all 5 combo methods

### Wave 0 Gaps
- [ ] Self-test registrations for 5 combo method existence checks -- add to combo.lua
- [ ] HUMAN-UAT.md entry for Phase 10 manual test steps

## Security Domain

### Applicable ASVS Categories -- NOT APPLICABLE
This is a WoW addon operating entirely client-side. There is no authentication, session management, access control, input validation (user input goes through WoW client API), or cryptography involved. The addon runs locally within the WoW Lua sandbox. The `security_enforcement` flag in config is not explicitly set to false, but this domain has no security surface to analyze. All code runs inside WoW's protected execution environment.

### Known Threat Patterns for WoW Addon (Lua)
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Infinite loop in macro | Denial of Service | WOW has a built-in script timeout; no user mitigation needed |
| Nil reference error | Information Disclosure (crash) | pcall wrapping in SelfTest; nil-guards in FIELD_FUNC_MAP |

No security-specific code changes needed for this phase.

## Sources

### Primary (HIGH confidence -- codebase analysis)
- `classes/druid/Druid.lua:299-428, 434-467` -- catAtk structure, bear routing, DRUID_FIELD_FUNC_MAP [VERIFIED: codebase grep]
- `classes/druid/cat.lua:1-388` -- All cat module global function signatures [VERIFIED: codebase grep]
- `classes/druid/bear.lua:1-147` -- bearAoe/bearAtk signatures and patterns [VERIFIED: codebase grep]
- `classes/druid/utility.lua:1-57` -- druidBuffs/druidStun/druidDefend/druidControl current state [VERIFIED: codebase grep]
- `entity/Player.lua:40-82, 87-102` -- _castSpell, _isInRange, _hasResource base methods [VERIFIED: codebase grep]
- `entity/Unit.lua:100-238` -- UNIT_FIELD_FUNC_MAP (mana, healthPercent, type, distance) [VERIFIED: codebase grep]
- `core/class.lua:21-59` -- classMetatable, initPlayer, PLAYER_CLASS_REGISTRY [VERIFIED: codebase grep]
- `core/selftest.lua:49-93, 1252-1310` -- SelfTest:run, existing Druid test patterns [VERIFIED: codebase grep]
- `build_order.txt:1-52` -- Current build order [VERIFIED: codebase grep]
- `core/events.lua:1-118` -- Event wiring (confirms no changes needed) [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence -- CONTEXT.md decisions)
- `.planning/phases/10-5-druid-druidatk-druidaoe-druidheal-druiddefend-druidcontrol/10-CONTEXT.md:1-200` -- All locked decisions D-01 through D-21 [CITED: CONTEXT.md]
- `.planning/phases/07-druid/07-CONTEXT.md` -- Phase 7 form detection decisions [CITED: CONTEXT.md canonical refs]
- `.planning/phases/05-druid-player-cast-druid/05-CONTEXT.md` -- _castSpell architecture decisions [CITED: CONTEXT.md canonical refs]

### Tertiary (LOW confidence -- general WoW API knowledge)
- `CancelShapeshiftForm()` behavior (no-op when no form active) [ASSUMED -- WoW 1.12 API knowledge, not verified in this session]
- Hurricane mana cost (~880 at rank 1, scaling) [ASSUMED -- training knowledge, actual values may differ on Turtle WoW]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | CancelShapeshiftForm() is a no-op (no error) when no shapeshift form is active | Edge Cases | LOW -- druidHeal would throw an error on first press when already humanoid. Mitigation: add guard `if isInCatForm or isInBearForm` before calling CancelShapeshiftForm. |
| A2 | Hurricane baseline mana cost is approximately 880 at rank 1 | Edge Cases | LOW -- wrong mana threshold means druidAoe might try to cast Hurricane with insufficient mana, which WoW would reject naturally. Minor UX issue at worst. |
| A3 | Rejuvenation HOT texture is 'Spell_Nature_Rejuvenation' | Edge Cases | MEDIUM -- if texture string is wrong, `hasBuff()` check in druidHeal would always return false, causing repeated Rejuvenation cast attempts. Mitigation: verify texture in-game. |

## Open Questions

1. **Rejuvenation HOT texture string for `hasBuff()` check**
   - What we know: The codebase uses texture-based buff detection (e.g., `Ability_GhoulFrenzy` for Rip, `Ability_Druid_Disembowel` for Rake). Rejuvenation needs its own texture.
   - What's unclear: The exact texture path for Rejuvenation in the WoW 1.12.1 client.
   - Recommendation: Use `player.buffed('Rejuvenation')` instead of texture-based check, since `player.buffed()` already supports name-based lookup. Alternatively, verify the texture in-game with `/run macroTorch.player.listBuffs()`.

2. **CancelShapeshiftForm() vs cat_form('ready') toggle behavior**
   - What we know: Both approaches return to humanoid form. CancelShapeshiftForm is a direct API call. cat_form while in cat form also toggles to humanoid.
   - What's unclear: Which approach has the lowest GCD impact or if both behave identically on Turtle WoW.
   - Recommendation: Use CancelShapeshiftForm() as recommended in CONTEXT.md. It is cleaner (no conditional -- always cancels any form) and the intended WoW API for this purpose.

## Metadata

**Confidence breakdown:**
- Source code analysis: HIGH -- All source files read and cross-referenced. Skill method signatures verified against actual code.
- Architecture: HIGH -- Patterns clearly documented in codebase. Form detection, routing, and delegation patterns are consistent.
- Edge cases: MEDIUM -- API behavior assumptions (CancelShapeshiftForm, Hurricane mana) marked as ASSUMED need in-game verification.
- Integration changes: HIGH -- Exact line numbers and change descriptions documented from code reading.

**Research date:** 2026-06-16
**Valid until:** 2026-07-16 (stable codebase, no external API dependencies that change frequently)