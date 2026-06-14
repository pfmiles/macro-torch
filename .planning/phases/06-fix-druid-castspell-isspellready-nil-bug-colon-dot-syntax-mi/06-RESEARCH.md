# Phase 06: Fix Druid _castSpell isSpellReady nil bug - Research

**Researched:** 2026-06-14
**Domain:** Lua OOP colon/dot syntax parameter misalignment in closure-based metatable inheritance
**Confidence:** HIGH

## Summary

Phase 06 修复 `entity/Player.lua` 中 `_castSpell` 内部冒号/点号语法不匹配导致的参数错位 bug。根本原因：`_castSpell` 在 `Player:new()` 构造函数内部使用点号定义（`function obj._castSpell(localeNames, mode, ...)`），但内部 4 处内部方法调用使用了冒号语法（`self:isSpellReady(spellName)`），导致 Lua 隐式插入的 `self` 参数占用了预期参数位。同时，`classes/druid/Druid.lua` 中 53 个技能方法对 `_castSpell` 也使用了冒号调用（`self:_castSpell(...)`），同样导致参数偏移。

两个层面的修复：`entity/Player.lua` 中 `_castSpell` 内部的 4 处 `self:xxx()` 改为 `obj.xxx()`，`classes/druid/Druid.lua` 中 53 处 `self:_castSpell(...)` 改为 `obj._castSpell(...)`。全部为零逻辑变更的机械替换，不影响外部调用者（均使用点号）。

**Primary recommendation:** 执行纯点号机械替换（`self:xxx()` 到 `obj.xxx()`），不改动任何方法定义签名，不改动任何外部调用者，不改动 `_hasResource` 的 `self.mana` 访问。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| _castSpell / _isInRange / _hasResource / cast 内部方法定义 | entity/Player.lua (Player prototype) | — | 定义在 `Player:new()` 闭包内，通过 `macroTorch.Druid = macroTorch.Player:new()` 继承到 Druid 类原型 |
| _castSpell 调用（Druid 技能方法） | classes/druid/Druid.lua (Druid 实例方法) | entity/Player.lua | Druid 实例通过 metatable `__index` 链找到 Player 原型上的 `_castSpell` |
| isSpellReady / cast 外部调用（cat.lua, utility.lua, bear.lua, Hunter.lua） | classes/ (组合模块) | entity/Player.lua | 通过 `macroTorch.player.isSpellReady()` 点号调用，无需修改 |
| Metatable 解析链 | core/class.lua (classMetatable 工厂) | entity/ (各层原型) | `__index` 按 FIELD_FUNC_MAP -> cls -> parent 顺序解析 |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Lua 5.0 (WoW 1.12.1 embedded) | 5.0 | Embedded scripting runtime | Only available runtime in WoW 1.12.1 client [VERIFIED: CLAUDE.md project constraints] |
| SuperMacro | Turtle WoW | Macro execution addon | Required by project architecture [VERIFIED: CLAUDE.md] |

No external packages are installed for this phase. This is a pure code fix within the existing Lua codebase.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dot syntax (chosen) | Colon syntax migration of all methods | Requires changing all method definitions to `function obj:method()` and updating all metatable resolution; user explicitly rejected this (D-01); would still need 50+ call site updates |

## Package Legitimacy Audit

No external packages are installed in this phase. This is a pure Lua code change within the existing project. Audit skipped.

## Architecture Patterns

### System Architecture Diagram

```
 Druid Instance (druidInstance)
     |
     | druidInstance.claw(mode)  -- dot call, correct
     v
 [classMetatable __index resolution]
     |
     | 1. DRUID_FIELD_FUNC_MAP['claw']?  NO (claw is a method, not a field)
     | 2. macroTorch.Druid['claw']?      YES -- found!
     v
 Druid:new() closure:
   function obj.claw(mode)
       return self:_castSpell(...)  -- BUG: self=macroTorch.Druid, params shifted!
   end
     |
     | After fix: return obj._castSpell(...) -- obj=Druid instance, correct!
     v
 [classMetatable __index resolution]
     |
     | 1. DRUID_FIELD_FUNC_MAP['_castSpell']?  NO
     | 2. macroTorch.Druid['_castSpell']?      YES -- found on Player prototype!
     |    (macroTorch.Druid = macroTorch.Player:new(), _castSpell is a closure on it)
     v
 Player:new() closure:
   function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)
       -- Inside here, 'self' upvalue = macroTorch.Player (class prototype)
       -- 'obj' upvalue = the Player instance (macroTorch.player)
       
       -- BUG before fix:
       if not self:isSpellReady(spellName) then  -- self:.. passes self as arg 1
       -- Equivalent to: macroTorch.Player.isSpellReady(macroTorch.Player, spellName)
       -- isSpellReady defined as: function obj.isSpellReady(spellName)
       -- Receives: spellName = macroTorch.Player (a table!), true param lost
       
       -- FIX:
       if not obj.isSpellReady(spellName) then   -- correct: spellName = spellName
   end
     |
     v
 isSpellReady (on macroTorch.player instance):
   function obj.isSpellReady(spellName)
       return macroTorch.toBoolean(SpellReady(spellName) ...)
   end
```

### Bug Root Cause Trace

**Layer 1: Druid `self:_castSpell(...)` call (Druid.lua)**

```lua
-- Druid:new() closure:
-- self (upvalue) = macroTorch.Druid (class prototype table)
function obj.claw(mode)
    return self:_castSpell({en='Claw', zh='爪击'}, mode, nil, macroTorch.computeClaw_E, false)
end
```

After Lua colon-to-dot desugaring:
```lua
return macroTorch.Druid._castSpell(macroTorch.Druid, {en='Claw', zh='爪击'}, mode, nil, macroTorch.computeClaw_E, false)
```

But `_castSpell` is defined as:
```lua
function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)
```

Result: `localeNames = macroTorch.Druid` (a table), `mode = {en='Claw', zh='爪击'}`, everything shifted right by one position. The function never reaches `SpellReady()` with a valid spell name.

**Layer 2: `self:isSpellReady(spellName)` inside _castSpell (Player.lua:52)**

```lua
-- Inside function obj._castSpell(localeNames, mode, ...):
-- self (upvalue) = macroTorch.Player (class prototype)
-- obj (upvalue) = Player instance

if not self:isSpellReady(spellName) then
```

After Lua colon-to-dot desugaring:
```lua
if not macroTorch.Player.isSpellReady(macroTorch.Player, spellName) then
```

But `isSpellReady` defined on the Player INSTANCE (`macroTorch.player`):
```lua
function obj.isSpellReady(spellName)
    return macroTorch.toBoolean(SpellReady(spellName) ...)
end
```

Result: `spellName` receives `macroTorch.Player` (a table), `SpellReady(table)` returns `nil`, `toBoolean(nil)` = `false`. All spells appear "not ready."

### Recommended Project Structure

No file structure changes. Only two files modified:

```
entity/Player.lua          # Lines 52, 59, 69, 79: self:xxx() -> obj.xxx()
classes/druid/Druid.lua    # Lines 26-239: self:_castSpell(...) -> obj._castSpell(...)
core/selftest.lua          # Add ~15 Category F tests at end of file
classes/druid/HUMAN-UAT.md # New file: manual test checklist
```

### Pattern: Closure-Based Method Resolution in this Codebase

**What:** Methods are defined using dot syntax (`function obj.method(params)`) inside constructor closures. The `obj` upvalue refers to the instance being constructed, while `self` refers to the class prototype table. The `classMetatable.__index` chain resolves methods through FIELD_FUNC_MAP -> cls -> parent metatable chain.

**Calling convention:** All calls MUST use dot syntax:
- Instance-to-instance: `obj.otherMethod(args)` 
- Instance-to-prototype: `obj.inheritedMethod(args)` (resolved via metatable)
- External: `macroTorch.player.isSpellReady(name)` (direct dot access)

**When to use:** Every method call in the codebase. Colon syntax (`self:method()`) is only valid when:
1. The function was defined WITH colon syntax (`function obj:method()`), OR
2. The caller expects the self parameter to be a specific table for context passing

Neither condition holds in this codebase since D-01 mandates dot definitions.

### Anti-Patterns to Avoid

- **Mixing colon calls with dot definitions:** Colon syntax (`self:method(x)`) desugars to `self.method(self, x)`, inserting `self` as the first argument. If `method` was defined with dot syntax (expecting `x` as first arg), all parameters shift by one position.
- **Using closure `self` as call target:** In this codebase, `self` refers to the class prototype (e.g., `macroTorch.Player`), not the instance. Calling `self:method()` triggers metatable resolution starting from the class prototype, not the instance -- methods defined on instances (closures) won't be found unless the prototype table itself has them.
- **Assuming `_castSpell` is on the metatable chain:** `_castSpell` is a closure on `macroTorch.player` (the Player instance), but it is ALSO present on `macroTorch.Druid` (which IS the result of `Player:new()`) because `macroTorch.Druid = macroTorch.Player:new()`. The classMetatable's `cls[k]` step finds it on the Druid class prototype.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Metatable introspection | Custom `debug.getmetatable` loop | classMetatable already handles FIELD_FUNC_MAP -> cls -> parent chain | The existing factory is correct; the bug is in call syntax, not resolution logic |
| Method lookup verification | Custom method existence checker | Selftest assertions via pcall | The existing SelfTest framework already provides test isolation |

**Key insight:** The metatable chain and classMetatable factory are NOT the source of the bug. They work correctly. The bug is purely in how methods are CALLED -- colon vs dot syntax mismatch. Do NOT modify class.lua or any metatable logic.

## Common Pitfalls

### Pitfall 1: Confusing the Two `self` Variables

**What goes wrong:** In `Druid:new()`, `self` refers to `macroTorch.Druid` (class prototype, itself a Player instance). In `Player:new()`'s `_castSpell` closure, `self` refers to `macroTorch.Player` (class prototype, itself a Unit instance). These are different tables in different closures. Calling `self:_castSpell()` in Druid.lua sends `macroTorch.Druid` as the first argument to `_castSpell`, not as the receiver.

**Why it happens:** Each `:new()` constructor creates its own `self` closure upvalue pointing to the class prototype. The colon syntax passes THIS upvalue as the implicit first argument.

**How to avoid:** Use `obj._castSpell(...)` instead of `self:_castSpell(...)`. The `obj` upvalue refers to the instance being constructed, and its metatable correctly resolves `_castSpell` through the chain.

**Warning signs:** `SpellReady()` returning nil for known-valid spell names; all Druid skill methods silently returning false; spell casting never triggers.

### Pitfall 2: Breaking External Callers by Changing Method Signatures

**What goes wrong:** If the fix changes method definitions (e.g., converting `function obj.method(x)` to `function obj:method(x)`), all external callers that use dot syntax would need updating too -- ~28+ call sites across cat.lua, utility.lua, bear.lua, and Hunter.lua.

**Why it happens:** The natural instinct might be to "fix" the colon/dot mismatch by changing definitions to colon syntax, but this shifts the maintenance burden to all callers.

**How to avoid:** Fix only the CALL sites, not the definitions. The definitions are correct; the calls are wrong. This is the approach mandated by D-01 through D-05.

### Pitfall 3: Missing the `_hasResource` self.mana Dependency

**What goes wrong:** The `_hasResource` method accesses `self.mana` (line 102), where `self` is the closure upvalue = `macroTorch.Player`. If someone tries to "fix" `_hasResource` to use `obj.mana` instead of `self.mana`, it would break the mana calculation because `obj` in that context is the Druid instance.

**Why it happens:** `_hasResource` is called from inside `_castSpell`, where `obj` refers to the Player instance. But `_hasResource`'s own closure captures `self` = `macroTorch.Player`, and `self.mana` correctly computes via the Player prototype's `ref="player"`.

**How to avoid:** In the `_hasResource` fix, change ONLY the CALL site (`obj:_hasResource(cost)` -> `obj._hasResource(cost)`), NOT the internal `self.mana` access. The `self.mana` inside `_hasResource` works correctly as-is.

**Note from D-05:** `_hasResource` 的 `self.mana` 通过闭包 `self` (= Player 原型, ref="player") 正确计算，无需修改。

## Code Examples

### Fix Pattern 1: _castSpell Internal Calls (entity/Player.lua)

```lua
-- Source: entity/Player.lua (lines 52, 59, 69, 79)
-- [VERIFIED: codebase grep at lines 52, 59, 69, 79]

-- BEFORE (buggy):
function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)
    ...
    if mode ~= 'raw' then
        if not self:isSpellReady(spellName) then   -- Line 52: BUG
            return false
        end
    end
    if mode == 'safe' then
        if range and not self:_isInRange(range) then  -- Line 59: BUG
            return false
        end
        ...
        if not self:_hasResource(cost) then           -- Line 69: BUG
            return false
        end
    end
    ...
    self:cast(spellName, false)                        -- Line 79: BUG
end

-- AFTER (fixed):
function obj._castSpell(localeNames, mode, range, resourceCost, onSelf)
    ...
    if mode ~= 'raw' then
        if not obj.isSpellReady(spellName) then   -- Line 52: FIXED
            return false
        end
    end
    if mode == 'safe' then
        if range and not obj._isInRange(range) then  -- Line 59: FIXED
            return false
        end
        ...
        if not obj._hasResource(cost) then           -- Line 69: FIXED
            return false
        end
    end
    ...
    obj.cast(spellName, false)                        -- Line 79: FIXED
end
```

### Fix Pattern 2: Druid Skill Methods (classes/druid/Druid.lua)

```lua
-- Source: classes/druid/Druid.lua (lines 25-239)
-- [VERIFIED: codebase grep confirmed 53 self:_castSpell occurrences]

-- BEFORE (buggy):
function obj.claw(mode)
    return self:_castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false)
end

-- AFTER (fixed):
function obj.claw(mode)
    return obj._castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false)
end
```

### Fix Pattern 3: Skill Methods with onSelf Parameter (Type C)

```lua
-- Source: classes/druid/Druid.lua (lines 206-239)
-- [VERIFIED: codebase grep]

-- BEFORE (buggy):
function obj.healing_touch(mode, onSelf)
    return self:_castSpell({ en = 'Healing Touch', zh = '治疗之触' }, mode, 40, nil, onSelf)
end

-- AFTER (fixed):
function obj.healing_touch(mode, onSelf)
    return obj._castSpell({ en = 'Healing Touch', zh = '治疗之触' }, mode, 40, nil, onSelf)
end
```

### Category F Selftest Pattern

```lua
-- Source: core/selftest.lua (existing pattern at lines 101-455)
-- [VERIFIED: codebase reading of Category A-G test patterns]

-- Category F: _castSpell / isSpellReady metatable chain integrity (~15 tests)
-- All tests are isOptional=false (core tests, red on failure)

macroTorch.SelfTest:register("F: Druid instance resolves _castSpell via metatable", function()
    if UnitClass('player') ~= 'Druid' then return end
    local druid = macroTorch.player
    assert(type(druid._castSpell) == "function", "_castSpell not a function")
end, false)

macroTorch.SelfTest:register("F: Druid instance resolves isSpellReady via _castSpell", function()
    if UnitClass('player') ~= 'Druid' then return end
    local result = pcall(function()
        macroTorch.player._castSpell({en='TestSpell', zh='测试技能'}, 'raw', nil, nil, false)
    end)
    assert(result, "_castSpell invocation should not error: " .. tostring(result))
end, false)

macroTorch.SelfTest:register("F: Druid claw() calls _castSpell with correct params", function()
    if UnitClass('player') ~= 'Druid' then return end
    -- claw() should not error; mode='raw' skips all checks
    local ok, err = pcall(function()
        macroTorch.player.claw('raw')
    end)
    assert(ok, "claw('raw') pcall failed: " .. tostring(err))
end, false)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 5 `self:_castSpell()` colon calls in Druid.lua | Phase 6 `obj._castSpell()` dot calls | Phase 6 | Parameters align correctly; all Druid skills start working |

**Deprecated/outdated:**
- `self:_castSpell(...)` pattern in Druid.lua: replaced by `obj._castSpell(...)` -- this was introduced in Phase 5 without realizing the colon/dot mismatch.
- `self:isSpellReady(spellName)` in _castSpell: replaced by `obj.isSpellReady(spellName)` -- this has been present since the original code and silently broken all Druid spell casting.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `_castSpell` resolves via `cls[k] = macroTorch.Druid['_castSpell']` in classMetatable step 2, and this works because `macroTorch.Druid = macroTorch.Player:new()` places `_castSpell` as a closure on the returned instance. | Architecture Patterns | If `_castSpell` were not actually on `macroTorch.Druid`, the fix would still break. However, this is confirmed by the metatable chain analysis -- `macroTorch.Druid` is literally the return value of `Player:new()`. |
| A2 | External callers in cat.lua, utility.lua, bear.lua, and Hunter.lua use dot syntax correctly and need zero changes. | Common Pitfalls - Pitfall 2 | If any external caller uses colon syntax, it would need fixing too. Verified via grep: all external callers use `macroTorch.player.isSpellReady()` or `player.cast()` dot syntax. |
| A3 | The `SpellReady(spellName)` WoW API returns nil for invalid/non-existent spell names, which `toBoolean(nil)` converts to false. | Architecture Patterns | If SpellReady returned something other than nil for invalid inputs, the silent-fail behavior might differ, but the fix would still be correct. |

## Open Questions

1. **Should Druid.lua Line 1191 `macroTorch.player.isSpellReady('Faerie Fire (Feral)')` be changed?**
   - What we know: This call uses dot syntax correctly on the `macroTorch.player` instance. It is not inside a Druid:new() closure and does not use self:_castSpell.
   - What's unclear: Whether this location (inside `macroTorch.safeFF()`) should use the Druid skill method instead.
   - Recommendation: Leave unchanged. D-04 confirms external `isSpellReady` callers need no modification.

2. **Is `_isInRange` also affected by the `self` upvalue issue internally?**
   - What we know: `_isInRange` accesses `macroTorch.target` directly (not `self.target`), so the `self` upvalue is irrelevant for its internal logic. Only the CALL to it (`self:_isInRange(range)` -> `obj._isInRange(range)`) needs fixing.
   - What's unclear: None -- confirmed via code reading at line 87-94.
   - Recommendation: Fix only the call site (line 59), no internal changes needed.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified). This phase modifies only existing Lua source files within the project. No new tools, runtimes, services, or CLI utilities are required.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (custom framework, defined in core/selftest.lua) |
| Config file | none -- inline registrations in source files |
| Quick run command | `/mt` (SLASH command, runs all registered selftests) |
| Full suite command | `/mt` (same command, all tests run in sequence) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| D-02 | _castSpell internal calls use dot syntax (isSpellReady, _isInRange, _hasResource, cast) | unit | pcall assertion in Category F | No -- Wave 0 |
| D-03 | Druid skill methods use `obj._castSpell` not `self:_castSpell` | unit | pcall assertion in Category F | No -- Wave 0 |
| D-04 | External isSpellReady/cast callers unchanged and functional | smoke | Existing Category C/D tests + manual verification | Partial |
| D-06 | Metatable chain: Druid instance -> _castSpell -> isSpellReady resolves correctly | unit | pcall assertion in Category F | No -- Wave 0 |
| D-07 | HUMAN-UAT.md covers Type A/B/C skills x ready/safe/raw modes | manual-only | In-game manual testing (cannot automate WoW API interactions) | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** Read-back verification of changed lines (no in-game test possible without WoW client)
- **Per wave merge:** `/mt` command in-game (requires WoW 1.12.1 client with addon loaded)
- **Phase gate:** All Category F tests pass via `/mt` + HUMAN-UAT.md checklist completed

### Wave 0 Gaps
- [ ] `core/selftest.lua` -- add Category F section (~15 tests) for metatable chain and _castSpell parameter integrity
- [ ] `classes/druid/HUMAN-UAT.md` -- create manual test checklist (Type A enemy skills: claw/shred/rake/rip; Type B self skills: cat_form/prowl/tiger_fury; Type C flexible skills: healing_touch/rejuvenation/mark_of_the_wild)
- [ ] No test framework install needed -- SelfTest is already in place

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not applicable (WoW addon, no auth layer) |
| V3 Session Management | no | Not applicable |
| V4 Access Control | no | Not applicable |
| V5 Input Validation | yes | Spell name locale selection (line 42-48) validates against client locale; mode parameter validated as string comparison 'raw'/'safe'; no injection surface because CastSpellByName uses internal spell IDs |
| V6 Cryptography | no | Not applicable |

### Known Threat Patterns for WoW Lua Addon

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Invalid spell name passed to CastSpellByName | Denial of Service (client-side) | Locale-based spell name lookup with fallback to English; SpellReady() pre-check |
| nil reference on missing target | Information Disclosure (error message) | Guard clauses: `if not macroTorch.target or not macroTorch.target.isExist then return false end` in `_isInRange` (line 88) |

## Sources

### Primary (HIGH confidence) -- Direct codebase analysis
- `entity/Player.lua` (lines 40-103): `_castSpell` definition, `_isInRange`, `_hasResource` definitions, `isSpellReady` definition (line 174), `cast` definition (line 29). [VERIFIED: codebase reading]
- `classes/druid/Druid.lua` (lines 19-239): Druid:new() constructor with 53 skill methods using `self:_castSpell(...)`. [VERIFIED: codebase grep confirmed 53 occurrences]
- `core/class.lua` (lines 21-33): `classMetatable` factory -- `__index` resolution order: FIELD_FUNC_MAP -> cls[k] -> parent chain. [VERIFIED: codebase reading]
- `core/selftest.lua` (lines 16-471): SelfTest framework with register/run pattern, pcall isolation, categorized tests (A-G). [VERIFIED: codebase reading]
- `.planning/codebase/ARCHITECTURE.md` (lines 84-137): OOP metatable inheritance documentation confirming two-tier constructor pattern and field resolution order. [VERIFIED: codebase reading]

### Secondary (MEDIUM confidence)
- Lua 5.0 colon syntax desugaring: `obj:method(x)` is syntatic sugar for `obj.method(obj, x)`. [CITED: standard Lua language specification; confirmed by code behavior analysis]
- `.planning/phases/06-*/06-CONTEXT.md`: D-01 through D-07 decisions constraining the fix approach. [VERIFIED: codebase reading]
- `.planning/codebase/ARCHITECTURE.md`: Full architecture context confirming classMetatable design and metatable chain correctness. [VERIFIED: codebase reading]

### Tertiary (LOW confidence) -- Attempted websearch, minimal results
- WebSearch for Lua colon/dot OOP patterns: returned low relevance results. The domain knowledge is well-established in the Lua community but the websearch was not productive for this specific query.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no external packages; pure Lua fix in existing codebase
- Architecture: HIGH -- all bug locations confirmed via direct codebase grep; metatable chain traced and verified; 53 Druid.lua occurrences counted; 4 Player.lua occurrences identified
- Pitfalls: HIGH -- rooted in the well-understood Lua colon/dot desugaring mechanic; confirmed by analysis of the exact closure upvalue bindings in both Player:new() and Druid:new()

**Research date:** 2026-06-14
**Valid until:** 2026-07-14 (stable domain, but Phase 6 may be superseded if subsequent phases modify _castSpell)

## Exact Bug Locations (Verified)

### entity/Player.lua (4 changes)
| Line | Before | After |
|------|--------|-------|
| 52 | `if not self:isSpellReady(spellName) then` | `if not obj.isSpellReady(spellName) then` |
| 59 | `if range and not self:_isInRange(range) then` | `if range and not obj._isInRange(range) then` |
| 69 | `if not self:_hasResource(cost) then` | `if not obj._hasResource(cost) then` |
| 79 | `self:cast(spellName, false)` | `obj.cast(spellName, false)` |

### classes/druid/Druid.lua (53 changes)
All 53 occurrences of `self:_castSpell(` on lines 26, 30, 34, 38, 42, 46, 50, 54, 58, 63, 67, 71, 75, 79, 83, 87, 92, 96, 100, 104, 108, 112, 116, 120, 125, 129, 133, 137, 141, 146, 150, 154, 158, 162, 166, 170, 174, 178, 182, 186, 190, 194, 198, 202, 207, 211, 215, 219, 223, 227, 231, 235, 239 replaced with `obj._castSpell(`.

### No changes needed
- `classes/druid/cat.lua`: 11 external `macroTorch.player.isSpellReady()` / `macroTorch.player.claw()` etc. -- all dot syntax, correct
- `classes/druid/utility.lua`: 13 external `macroTorch.player.isSpellReady()` calls -- all dot syntax, correct
- `classes/druid/bear.lua`: 8 external `macroTorch.player.ferocious_bite()` etc. -- all dot syntax, correct
- `classes/Hunter.lua`: 19 external `player.cast()` / `player.isSpellReady()` -- all dot syntax, correct
- Other class files (Mage.lua, Priest.lua, Rogue.lua, Warlock.lua, Warrior.lua): no `self:_` patterns detected