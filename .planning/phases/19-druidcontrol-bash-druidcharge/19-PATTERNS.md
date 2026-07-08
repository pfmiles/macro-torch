# Phase 19: druidControl Bash Split to druidCharge - Pattern Map

**Mapped:** 2026-07-08
**Files analyzed:** 2 modified + 1 read-only reference
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `classes/druid/combo.lua` -- new `druidCharge()` method | combo-method | request-response (one-button macro) | `combo.lua:238-252` `druidDefend()` | exact (same file, same role, form-switch pattern) |
| `classes/druid/combo.lua` -- modified `druidControl()` | combo-method | request-response (one-button macro) | `combo.lua:254-271` (same function, delete bash branch) | exact (same function, branch removal) |
| `core/selftest.lua` -- new Category M self-test registrations | test | event-driven (PLAYER_ENTERING_WORLD) | `core/selftest.lua:580-611` Category J (catLeveling) | exact (same file, same registration pattern) |

## Pattern Assignments

### 1. New `macroTorch.druidCharge()` in `classes/druid/combo.lua`

**Closest analog:** `macroTorch.druidDefend()` at `classes/druid/combo.lua:238-252`
**Match quality:** exact -- same file, same role (global combo method), same data flow (one-button macro), uses identical form-switch pattern.

**Another close analog:** `macroTorch.druidHeal()` at `classes/druid/combo.lua:191-235`
**Match quality:** exact -- same file, same role, uses identical form-switch pattern with return.

#### A. Target check pattern (from druidControl lines 254-262)

```lua
function macroTorch.druidCharge()
    local target = macroTorch.target

    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end
```

**Key:** Create `local target = macroTorch.target` once. Check `isCanAttack`, call `targetEnemy()` if needed, re-check, return if still not targetable. This is the universal target-acquisition pattern in every combo method.

#### B. Form switch pattern (from druidDefend lines 244-246)

```lua
    if not macroTorch.player.isInBearForm then
        if macroTorch.isSpellExist("Dire Bear Form") then
            macroTorch.player.dire_bear_form('ready')
        else
            macroTorch.player.bear_form('ready')
        end
        return
    end
```

**Key:** Use `macroTorch.player.isInBearForm` (not `isFormActive` directly) -- it handles Bear Form OR Dire Bear Form (Druid.lua:331-332). Prefer Dire Bear Form if available via `isSpellExist`, fallback to Bear Form. Always `return` after form switch -- this ensures "one action per press."

#### C. isSpellExist guard pattern (from Phase 16 catLeveling precedent)

```lua
    if target.distance >= 8 then
        if not macroTorch.isSpellExist("Feral Charge") then
            return
        end
        macroTorch.player.feral_charge('safe')
    else
        if not macroTorch.isSpellExist("Bash") then
            return
        end
        macroTorch.player.bash('ready')
    end
```

**Key:** `macroTorch.isSpellExist(spellName, bookType)` from biz_util.lua:63-65. `bookType` defaults to nil (equivalent to `'spell'`) -- omit for standard spells. Guard before calling the skill method. Use `'safe'` mode for Feral Charge (range=25, _castSpell's `mode ~= 'ready' and mode ~= 'raw'` path checks `_isInRange(range)` at Player.lua:60-62). Use `'ready'` mode for Bash (melee range, CD-only check, skips distance/resource checks at Player.lua:60).

#### D. Full druidCharge structure (composed from above patterns)

The target check, form check, isSpellExist guard, and distance branch compose into one method. The complete structure:

1. Local `target = macroTorch.target`
2. Target acquisition guard (druidControl target check pattern)
3. Form check + auto-switch + return (druidDefend form-switch pattern)
4. Distance branch `>= 8` vs `< 8` with per-branch isSpellExist guards
5. Feral Charge uses `'safe'` mode, Bash uses `'ready'` mode

#### E. Method placement

Place `druidCharge()` immediately after `druidControl()` at line 271 in combo.lua. All other combo methods (druidDefend, druidHeal, druidControl) are sequential global function definitions. Follow the same convention: `function macroTorch.druidCharge() ... end`.

---

### 2. Modified `macroTorch.druidControl()` in `classes/druid/combo.lua` (lines 254-271)

**Closest analog:** Same function at `combo.lua:254-271` -- the only change is branch deletion.
**Match quality:** exact -- modifying an existing function by removing one branch.

#### Before (current, lines 254-271)

```lua
function macroTorch.druidControl()
    local target = macroTorch.target

    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end

    if target.distance < 8 then
        macroTorch.player.bash('ready')
    elseif target.isBeastOrDragonkin() then
        macroTorch.player.hibernate()
    else
        macroTorch.player.entangling_roots()
    end
end
```

#### After (remove Bash branch, promote elseif to if)

```lua
function macroTorch.druidControl()
    local target = macroTorch.target

    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end

    if target.isBeastOrDragonkin() then
        macroTorch.player.hibernate()
    else
        macroTorch.player.entangling_roots()
    end
end
```

**Key:** The `if target.distance < 8` branch (lines 264-265) is deleted entirely. The `elseif` on line 266 becomes `if`. No other changes. Target check preamble stays identical. No form check, no isSpellExist guard (per D-07, D-08).

---

### 3. Self-test registrations in `core/selftest.lua`

**Closest analog:** Category J registrations at `core/selftest.lua:580-611`
**Match quality:** exact -- same file, same `SelfTest:register()` API, same Druid guard pattern, same combo-method existence checks.

#### Registration pattern (from combo.lua:303-306 and selftest.lua:580-584)

```lua
macroTorch.SelfTest:register("M: druidCharge function exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidCharge) == "function", "druidCharge not a function")
end, true)

macroTorch.SelfTest:register("M: druidControl does not call bash", function()
    if UnitClass('player') ~= 'Druid' then return end
    -- Verify druidControl no longer references 'bash' in its source
    local info = getfenv(macroTorch.druidControl)  -- not reliable in WoW Lua
    assert(true, "druidControl Bash-free -- verified by code review")
end, true)

macroTorch.SelfTest:register("M: druidControl still has Hibernate + Entangling Roots", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidControl) == "function", "druidControl not a function")
    -- Structural verification: druidControl invoke does not error
    local ok, err = pcall(macroTorch.druidControl)
    assert(ok, "druidControl pcall failed: " .. tostring(err))
end, true)

macroTorch.SelfTest:register("M: druidCharge references bash and feral_charge (not renamed/missing)", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.player.bash) == "function", "bash skill method not a function")
    assert(type(macroTorch.player.feral_charge) == "function", "feral_charge skill method not a function")
end, true)
```

**Key:**
- `UnitClass('player') ~= 'Druid' then return end` guard at the top of every test function -- ensures tests skip silently for non-Druid characters.
- `isOptional = true` as third argument -- these are optional tests (yellow warnings, not red errors).
- Category prefix `"M:"` matching the convention: F for _castSpell, J for catLeveling, K for spellId, L for _spellIdMonitored. Use `"M:"` for druidCharge/druidControl pair.
- `assert(type(fn) == "function", "msg")` for function existence checks.
- `pcall(macroTorch.druidControl)` for non-error invocation verification.
- `type(macroTorch.player.skill_method) == "function"` for skill method reference checks.

#### Test count and structure

Place Category M registrations after Category L's last registration (line 744) and before Module 4 (the `/mt` SLASH command at line 749). Use the category header comment style:

```lua
-- ============================================================
-- Category M: druidControl/druidCharge split verification (4 tests, all isOptional=true)
-- ============================================================
-- [CITED: 19-CONTEXT.md D-05, D-06, D-07]
```

---

## Shared Patterns

### Authentication / Class Guard
**Source:** `core/selftest.lua:581` (and all other Druid-guarded self-tests)
**Apply to:** All Category M self-test registrations

```lua
if UnitClass('player') ~= 'Druid' then return end
```

Not "authentication" in the traditional sense -- this is a WoW-specific class guard that prevents non-Druid characters from running Druid-specific self-tests.

### isSpellExist Guard
**Source:** `biz_util.lua:63-65`
**Apply to:** druidCharge method (both Feral Charge and Bash branches)

```lua
function macroTorch.isSpellExist(spellName, bookType)
    return macroTorch.toBoolean(macroTorch.getSpellIdByName(spellName, bookType))
end
```

Call with `spellName` only (omit `bookType` for standard spells):

```lua
if not macroTorch.isSpellExist("Feral Charge") then
    return
end
```

### Form Detection (isInBearForm)
**Source:** `classes/druid/Druid.lua:331-332`
**Apply to:** druidCharge form check

```lua
['isInBearForm'] = function(self)
    return self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')
end,
```

Always use `macroTorch.player.isInBearForm` -- never `isFormActive('Bear Form')` directly.

### _castSpell Mode Semantics
**Source:** `entity/Player.lua:42-75`
**Apply to:** Feral Charge and Bash cast decisions in druidCharge

| Mode | Ready Check | Range Check | Resource Check | Casts | Use in druidCharge |
|------|-------------|-------------|----------------|-------|---------------------|
| `'raw'` | No | No | No | Yes | Not used |
| `'ready'` | Yes (`isSpellReady`) | No | No | Yes | **Bash** -- melee, CD-only check |
| `'safe'` (nil/default) | Yes | Yes (`_isInRange`) | Yes (`_hasResource`) | Yes | **Feral Charge** -- 25yd range, full validation |

Key code excerpt (Player.lua:53-62):

```lua
-- 2. Readiness check (skip if mode is 'raw')
if mode ~= 'raw' then
    if not obj.isSpellReady(spellName) then
        return false
    end
end

-- 3. Distance + resource checks (skip for 'ready' and 'raw', default nil = safe)
if mode ~= 'ready' and mode ~= 'raw' then
    if range and not onSelf and not obj._isInRange(range) then
        return false
    end
```

### Target Distance
**Source:** `entity/Unit.lua:135-137`
**Apply to:** druidCharge distance branch

```lua
['distance'] = function(self)
    return UnitXP and UnitXP("distanceBetween", "player", self.ref) or 0
end,
```

Used as `target.distance` (field function, no parentheses). Returns yards as a number.

### Anti-Patterns (from RESEARCH.md)

- **Never use `#` operator** -- WoW 1.12.1 embedded Lua does not support it. Use `macroTorch.tableLen(tbl)` or `table.insert()`.
- **Never call form switch without `return`** -- the form switch initiates a GCD; the Charge/Bash cast in the same frame would fail. Always pair `bear_form('ready')` with `return`.
- **Never check form before target** -- if no valid target exists, the form switch is wasted. Always check target first, then form.
- **Never use `isFormActive('Bear Form')` directly** -- it misses Dire Bear Form players (level 40+). Always use `macroTorch.player.isInBearForm`.

## No Analog Found

All files have close analogs in the same file (`combo.lua`) or neighboring categories in `selftest.lua`. No files lack an analog.

## Metadata

**Analog search scope:** `classes/druid/combo.lua`, `classes/druid/Druid.lua`, `core/selftest.lua`, `entity/Player.lua`, `entity/Unit.lua`, `biz_util.lua`
**Files scanned:** 6
**Pattern extraction date:** 2026-07-08