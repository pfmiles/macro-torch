# Phase 7: Druid 形态判断语义化方法 - Research

**Researched:** 2026-06-15
**Domain:** Lua code refactoring -- semantic method extraction in WoW addon metatable-based OOP
**Confidence:** HIGH

## Summary

Phase 7 is a pure refactoring phase: add 5 semantic form-detection methods to `DRUID_FIELD_FUNC_MAP` and replace 7 hardcoded `isFormActive('FormName')` calls in the Druid class files. No external dependencies, no new packages, no environment requirements beyond the existing build chain.

The phase follows an established pattern in this codebase -- lazy computed properties via `DRUID_FIELD_FUNC_MAP` using the metatable `__index` chain. The existing `isOoc`, `isProwling`, `isBerserk`, and `humanFormMana` entries in `DRUID_FIELD_FUNC_MAP` provide the canonical template. Each new method delegates to `self.isFormActive('FormName')` via the metatable inheritance chain (Druid -> Player -> Unit).

The existing SelfTest registrations for `isCatForm` and `isBearForm` (lines 1267-1277 of Druid.lua) are forward-looking stubs that reference method names without the "In" prefix. This research documents the naming discrepancy and recommends resolution.

**Primary recommendation:** Add 5 FIELD_FUNC_MAP entries following the existing `isOoc`/`isProwling`/`isBerserk` pattern, each ~3-5 lines delegating to `self.isFormActive(...)`. Replace 7 hardcoded calls with semantic property access. Align SelfTest naming with the D-01 decision (`isInCatForm` not `isCatForm`).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Form detection logic | Class Layer (DRUID_FIELD_FUNC_MAP) | Entity Layer (Player.isFormActive) | Form detection is Druid-specific semantic API; delegates to generic Player base method for WoW API interaction |
| isFormActive generic method | Entity Layer (Player.lua) | -- | Stays as-is; used by Warrior Stance detection and other non-Druid callers |
| SelfTest registration | Class Layer (Druid.lua) | Core Layer (core/selftest.lua) | Category D Druid tests follow existing pattern |
| Call site replacement | Class Layer (Druid.lua, bear.lua, utility.lua) | -- | Pure mechanical replacement within druid/ directory |

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 5 个语义化方法定义在 `DRUID_FIELD_FUNC_MAP` 中作为懒计算属性，与现有 `isOoc`/`isProwling`/`isBerserk` 模式一致。`isFormActive` 保留在 `entity/Player.lua` 基类不变，作为通用 fallback（Warrior Stance 等场景仍可用）。
- **D-02:** `isInBearForm` 同时检查 `'Bear Form'` 和 `'Dire Bear Form'`（OR 逻辑），覆盖 level 10-39 德鲁伊。两种形态在 WoW 1.12.1 中不会同时存在于形态条上，OR 逻辑无歧义。
- **D-03:** 5 个方法全部实现。`isInTravelForm`/`isInAquaticForm`/`isInCasterForm`（当前零调用）标注 `-- reserved for future expansion` 注释，与 Phase 5 已有的形态技能方法（`travel_form()`/`aquatic_form()` 等）形成对称 API。
- **D-04:** 替换所有 7 处 `isFormActive` 硬编码调用：
  - `classes/druid/Druid.lua:348-349,531` -- 3 处
  - `classes/druid/bear.lua:66,102` -- 2 处
  - `classes/druid/utility.lua:15,39` -- 2 处

### Claude's Discretion

- DRUID_FIELD_FUNC_MAP 中 5 个新属性的精确顺序和位置
- 注释措辞（`-- reserved for future expansion`）
- SelfTest 注册的具体实现（复用现有 Category D Druid 测试模式）

### Deferred Ideas (OUT OF SCOPE)

- Travel/Aquatic/Caster 形态战斗逻辑 -- 属于未来 Phase
- Warrior Stance 语义化方法 -- 若未来需要，可参照 Druid 模式
- DRUID_FIELD_FUNC_MAP 性能优化 -- 无优化需求

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-07-SEMANTIC | 新增 5 个 DRUID_FIELD_FUNC_MAP 语义化形态判断方法 | DRUID_FIELD_FUNC_MAP pattern established; isOoc/isProwling/isBerserk provide canonical template |
| REQ-07-REPLACE | 替换 7 处 isFormActive 硬编码调用 | All 7 call sites mapped; replacement is mechanical property access |
| REQ-07-BEAR-OR | isInBearForm 覆盖 Bear Form + Dire Bear Form | isFormActive already handles single-form check; OR composition is trivial |
| REQ-07-RESERVED | 零调用方法标注 reserved 注释 | Follows existing TODO comment conventions from CONVENTIONS.md |
| REQ-07-SELFTEST | 5 个 SelfTest 注册 | Existing Category D pattern with isOptional=true |

## Standard Stack

### Core

This phase requires zero external packages. All changes are within existing Lua source files using the established metatable-based OOP system.

| Thing | Purpose | Why |
|-------|---------|-----|
| Lua metatable `__index` chain | FIELD_FUNC_MAP lazy property resolution | Already the established pattern in the codebase |
| `self.isFormActive(formName)` | Delegates to Player base class WoW API interaction | Already implemented in `entity/Player.lua:158` |
| `macroTorch.SelfTest:register()` | Test registration for form detection methods | Already implemented; Category D pattern established |
| `build.sh` + `build_order.txt` | Build concatenation | No changes needed -- files already in build order |

### Alternatives Considered

None. This is a refactoring phase with locked decisions from CONTEXT.md. No alternative approaches are in scope.

## Package Legitimacy Audit

No external packages are installed in this phase. All changes are within the existing Lua source tree. Audit skipped -- no packages to verify.

## Architecture Patterns

### System Architecture Diagram

This phase operates entirely within the Class Layer. Data flow is unchanged from the existing architecture:

```
DRUID_FIELD_FUNC_MAP (new entries)
    |
    v
metatable __index chain
    |
    v
self.isFormActive(formName)   [inherited from Player]
    |
    v
GetShapeshiftFormInfo(i)      [WoW 1.12.1 API]
    |
    v
returns boolean
```

### Field Resolution for New Methods

```
druidInstance.isInCatForm
  -> DRUID_FIELD_FUNC_MAP["isInCatForm"](self)
     -> self.isFormActive('Cat Form')         [via Player.__index]
        -> iterates GetShapeshiftFormInfo()   [WoW API]
        -> returns boolean
```

### Pattern: FIELD_FUNC_MAP Lazy Computed Property

**What:** Define a function in DRUID_FIELD_FUNC_MAP that computes the value on access. The metatable `__index` resolves field names by checking the map first, then class methods, then parent methods.

**When to use:** Any Druid-specific property that should be accessible as `player.propertyName` and computed on-demand.

**Reference implementation (existing isOoc entry at Druid.lua:440-442):**
```lua
-- Source: classes/druid/Druid.lua:434-452
macroTorch.DRUID_FIELD_FUNC_MAP = {
    ['isOoc'] = function(self)
        return self.buffed('Clearcasting', 'Spell_Shadow_ManaBurn')
    end,
    ['isProwling'] = function(self)
        return self.buffed('Prowl', 'Ability_Ambush')
    end,
    ['isBerserk'] = function(self)
        return self.buffed('Berserk', 'Ability_Druid_Berserk')
    end,
}
```

**Target pattern for new methods (delegates to isFormActive):**
```lua
-- Source: Derived from D-01, D-02 decisions + existing isOoc pattern
['isInCatForm'] = function(self)
    return self.isFormActive('Cat Form')
end,
['isInBearForm'] = function(self)
    return self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')
end,
['isInTravelForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Travel Form')
end,
['isInAquaticForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Aquatic Form')
end,
['isInCasterForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Moonkin Form')
end,
```

**Key insight:** `self.isFormActive` resolves through the metatable chain: DRUID_FIELD_FUNC_MAP -> macroTorch.Druid class -> macroTorch.Player class -> Player instance methods -> `obj.isFormActive` defined in `entity/Player.lua:158`.

### Pattern: SelfTest Registration (Category D Druid)

**Reference (existing isCatForm stub at Druid.lua:1267-1271):**
```lua
-- Source: classes/druid/Druid.lua:1267-1271 (existing forward-looking stub)
macroTorch.SelfTest:register("Druid: isCatForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isCatForm)
    assert(type(val) == "boolean", "isCatForm not boolean: " .. type(val))
end, true)
```

### Call Site Replacement Pattern

**Before:**
```lua
-- Source: classes/druid/Druid.lua:348-349
clickContext.isInBearForm = player.isFormActive('Dire Bear Form')
clickContext.isInCatForm = player.isFormActive('Cat Form')
```

**After:**
```lua
clickContext.isInBearForm = player.isInBearForm
clickContext.isInCatForm = player.isInCatForm
```

This is purely mechanical -- the semantic equivalent. The `clickContext` cache still stores the boolean result; only the source of that boolean changes from a method call with a string parameter to a property access.

### Recommended FIELD_FUNC_MAP Insertion Point

Insert 5 new entries after the existing `isBerserk` entry (line 448) and before `humanFormMana` (line 449). This groups all boolean conditional properties together:

```lua
['isBerserk'] = function(self)
    return self.buffed('Berserk', 'Ability_Druid_Berserk')
end,
-- NEW ENTRIES HERE (lines 449-470)
['humanFormMana'] = function(self)
    return UnitMana(self.ref) or 0
end,
```

### Anti-Patterns to Avoid

- **Duplicating WoW API calls:** Do not call `GetShapeshiftFormInfo` directly in the new methods. Always delegate to `self.isFormActive(formName)` which already encapsulates the WoW API iteration. This maintains a single point of truth for form detection logic. [VERIFIED: codebase pattern -- `entity/Player.lua:158-169` is the sole implementation of `GetShapeshiftFormInfo` iteration]
- **Adding methods to Player instead of DRUID_FIELD_FUNC_MAP:** CONTEXT.md D-01 locked this decision. The 5 methods must be in DRUID_FIELD_FUNC_MAP on the Druid class, not in `entity/Player.lua`. `isFormActive` stays in Player as the generic fallback. [CITED: .planning/phases/07-druid/07-CONTEXT.md D-01]
- **Introducing colon syntax for FIELD_FUNC_MAP entries:** FIELD_FUNC_MAP functions receive `self` as the first argument (the metatable passes the instance). The function signature is `function(self)` with the parameter, not `function(self:)`. This is the established pattern. [VERIFIED: codebase pattern -- all FIELD_FUNC_MAP entries use `function(self)` not `function(self:)`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form active detection | Custom WoW API iteration | `self.isFormActive(formName)` | Already implemented in Player.lua:158; single point of truth for GetShapeshiftFormInfo iteration |
| Property lookup mechanism | Custom metatable logic | Existing `classMetatable` factory + FIELD_FUNC_MAP | Already implemented in core/class.lua; DRUID_FIELD_FUNC_MAP already registered in Druid:new() constructor |

**Key insight:** This phase adds zero new mechanisms. It only adds new entries to an existing data structure (DRUID_FIELD_FUNC_MAP) and replaces string-based calls with property access. The risk surface is minimal.

## Common Pitfalls

### Pitfall 1: SelfTest naming mismatch

**What goes wrong:** Existing SelfTest registrations at Druid.lua:1267-1271 reference `macroTorch.player.isCatForm` and `isBearForm` (without "In" prefix), but CONTEXT.md D-01 specifies method names `isInCatForm`/`isInBearForm` (with "In" prefix).

**Why it happens:** The SelfTest stubs were added in a previous phase as forward-looking placeholders, likely before the final naming convention was decided in Phase 7 discussion.

**How to avoid:** Update SelfTest names to match D-01: `isInCatForm`, `isInBearForm`, `isInTravelForm`, `isInAquaticForm`, `isInCasterForm`. Also update the test title strings and property access expressions.

**Warning signs:** SelfTest failures after implementation -- if tests reference `isCatForm` but FIELD_FUNC_MAP defines `isInCatForm`, the tests will fail on nil access.

### Pitfall 2: isInCasterForm form name

**What goes wrong:** Using the wrong WoW API form name for caster form. In WoW 1.12.1, the Moonkin form's `GetShapeshiftFormInfo` spell name may differ from "Moonkin Form" depending on client language.

**Why it happens:** The WoW 1.12.1 API returns localized spell names. The English client returns "Moonkin Form" but other locales return translated strings.

**How to avoid:** Verify the English string `'Moonkin Form'` against the client. Since this codebase targets Turtle WoW (English), and `isFormActive` uses `macroTorch.equalsIgnoreCase`, this should work correctly. Document in a comment if verification is needed.

**Warning signs:** `isInCasterForm` always returns false even when in Moonkin form -- indicates wrong spell name string.

### Pitfall 3: Breaking clickContext cache pattern

**What goes wrong:** Replacing `player.isFormActive('Cat Form')` with `player.isInCatForm` changes the evaluation timing -- FIELD_FUNC_MAP access happens on each property read rather than once at cache time.

**Why it happens:** The old pattern caches the boolean result in `clickContext` once. The new pattern still caches in `clickContext` (e.g., `clickContext.isInCatForm = player.isInCatForm`), so the FIELD_FUNC_MAP function only executes once per click. The semantics are identical.

**How to avoid:** Ensure the replacement at call sites preserves the assignment pattern: `clickContext.isInCatForm = player.isInCatForm` (assignment, not bare property access). The 7 call sites in CONTEXT.md all use this assignment pattern already.

**Warning signs:** Performance regression if property is accessed repeatedly without caching -- but this is not the case here since clickContext is the cache layer.

## Code Examples

### New FIELD_FUNC_MAP Entries

```lua
-- Source: Derived from existing DRUID_FIELD_FUNC_MAP pattern (Druid.lua:434-452)
--        D-01, D-02 decisions from 07-CONTEXT.md
-- Add after 'isBerserk' entry, before 'humanFormMana'
['isInCatForm'] = function(self)
    return self.isFormActive('Cat Form')
end,
['isInBearForm'] = function(self)
    return self.isFormActive('Bear Form') or self.isFormActive('Dire Bear Form')
end,
['isInTravelForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Travel Form')
end,
['isInAquaticForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Aquatic Form')
end,
['isInCasterForm'] = function(self)
    -- reserved for future expansion
    return self.isFormActive('Moonkin Form')
end,
```

### Call Site Replacements

```lua
-- Source: 07-CONTEXT.md D-04 call site map

-- Druid.lua:348-349 (catAtk clickContext initialization)
-- OLD: clickContext.isInBearForm = player.isFormActive('Dire Bear Form')
-- OLD: clickContext.isInCatForm = player.isFormActive('Cat Form')
-- NEW:
clickContext.isInBearForm = player.isInBearForm
clickContext.isInCatForm = player.isInCatForm

-- Druid.lua:531 (recoverNormalRelic guard)
-- OLD: if not player.isFormActive('Cat Form') then
-- NEW:
if not player.isInCatForm then

-- bear.lua:66 (bearAoe guard)
-- OLD: if not macroTorch.player.isFormActive('Dire Bear Form') then
-- NEW:
if not macroTorch.player.isInBearForm then

-- bear.lua:102 (bearAtk clickContext + guard)
-- OLD: clickContext.isInBearForm = player.isFormActive('Dire Bear Form')
-- NEW:
clickContext.isInBearForm = player.isInBearForm

-- utility.lua:15 (druidStun guard)
-- OLD: local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
-- NEW:
local inBearForm = macroTorch.player.isInBearForm

-- utility.lua:39 (druidDefend guard)
-- OLD: local inBearForm = macroTorch.player.isFormActive('Dire Bear Form')
-- NEW:
local inBearForm = macroTorch.player.isInBearForm
```

### Updated SelfTest Registrations

```lua
-- Source: Existing pattern at Druid.lua:1267-1277, updated per D-01 naming

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInCatForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInCatForm)
    assert(type(val) == "boolean", "isInCatForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInBearForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInBearForm)
    assert(type(val) == "boolean", "isInBearForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInTravelForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInTravelForm)
    assert(type(val) == "boolean", "isInTravelForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInAquaticForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInAquaticForm)
    assert(type(val) == "boolean", "isInAquaticForm not boolean: " .. type(val))
end, true)

macroTorch.SelfTest:register("Druid: DRUID_FIELD_FUNC_MAP isInCasterForm exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    local val = macroTorch.toBoolean(macroTorch.player.isInCasterForm)
    assert(type(val) == "boolean", "isInCasterForm not boolean: " .. type(val))
end, true)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `player.isFormActive('Dire Bear Form')` | `player.isInBearForm` (OR: Bear + Dire Bear) | Phase 7 | Semantic self-documenting API; covers leveling Druids |
| `player.isFormActive('Cat Form')` | `player.isInCatForm` | Phase 7 | Semantic, no behavior change |
| Hardcoded string `'Cat Form'` in 3 files | Single source of truth in FIELD_FUNC_MAP | Phase 7 | If form name ever needs updating, change one place |

**Deprecated/outdated:**
- Direct `isFormActive('Cat Form')` calls in druid/ files: replaced by semantic methods. `isFormActive` remains available for Warrior Stance and edge cases.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `isInCasterForm` uses `'Moonkin Form'` as the English client form name | Code Examples | Low -- if wrong, method always returns false; fix is a one-string change |
| A2 | `self.isFormActive` resolves correctly through metatable chain from DRUID_FIELD_FUNC_MAP context | Common Pitfalls | Low -- this is the established pattern for all existing FIELD_FUNC_MAP entries; verified by codebase analysis |
| A3 | The existing SelfTest registrations at Druid.lua:1267-1271 (`isCatForm`/`isBearForm`) are forward-looking stubs to be renamed to `isInCatForm`/`isInBearForm` | Common Pitfalls | Medium -- if the planner misinterprets these as already-correct, tests will fail; explicit rename documented in this research |

## Open Questions

1. **Moonkin Form spell name verification**
   - What we know: Assumed `'Moonkin Form'` is the English client form name on Turtle WoW 1.12.1
   - What's unclear: Not verified against actual Turtle WoW client
   - Recommendation: Include a verification comment; low priority since `isInCasterForm` has zero current callers

## Environment Availability

Step 2.6: SKIPPED -- This phase has no external dependencies. All changes are within existing Lua source files using the established build chain (`build.sh` + `build_order.txt`). No new tools, services, runtimes, or packages are introduced.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | In-game SelfTest (macroTorch.SelfTest) |
| Config file | none -- SelfTest is code-registered in Druid.lua |
| Quick run command | In-game: log in as Druid, check chat for `[macro-torch] Self-test:` summary |
| Full suite command | Same as quick run -- SelfTest runs on PLAYER_ENTERING_WORLD |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-07-SEMANTIC | 5 FIELD_FUNC_MAP entries return boolean | SelfTest | In-game login as Druid | Partial -- existing stubs for isCatForm/isInCatForm, isBearForm/isInBearForm need renaming |
| REQ-07-REPLACE | 7 call sites use semantic methods | Manual review | `grep -n "isFormActive" classes/druid/` returns 0 | Wave 0 |
| REQ-07-BEAR-OR | isInBearForm returns true for both Bear Form and Dire Bear Form | SelfTest | In-game: test on level 10-39 Druid (Bear Form only) and level 40+ Druid (Dire Bear Form) | Wave 0 |
| REQ-07-RESERVED | Reserved methods have `-- reserved for future expansion` comment | Manual review | visual inspection of DRUID_FIELD_FUNC_MAP | Wave 0 |
| REQ-07-SELFTEST | 5 SelfTest registrations | SelfTest | In-game login | Partial |

### Sampling Rate

- **Per task commit:** `grep -c "isFormActive" classes/druid/Druid.lua classes/druid/bear.lua classes/druid/utility.lua` -- verify count decreases
- **Per wave merge:** In-game login as Druid, verify SelfTest summary
- **Phase gate:** All 5 SelfTest entries pass; `grep "isFormActive" classes/druid/*.lua` returns only the internal delegations inside FIELD_FUNC_MAP entries (and `getMinimumAffordableAbilityCost` line 381 reference to `clickContext.isInBearForm`, not `isFormActive`)

### Wave 0 Gaps

- [ ] SelfTest for `isInTravelForm` -- new registration needed
- [ ] SelfTest for `isInAquaticForm` -- new registration needed
- [ ] SelfTest for `isInCasterForm` -- new registration needed
- [ ] Rename existing `Druid: isCatForm exists` test to `Druid: DRUID_FIELD_FUNC_MAP isInCatForm exists`
- [ ] Rename existing `Druid: isBearForm exists` test to `Druid: DRUID_FIELD_FUNC_MAP isInBearForm exists`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | N/A -- WoW addon, no auth |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | no | No user input in this phase |
| V6 Cryptography | no | N/A |

### Known Threat Patterns for Lua/WoW Addon

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Global namespace collision | Tampering | All code in `macroTorch` namespace; FIELD_FUNC_MAP entries are additive |
| Nil reference on missing field | Denial of Service | FIELD_FUNC_MAP lazy evaluation handles nil gracefully; `isFormActive` already returns boolean |

## Project Constraints (from CLAUDE.md)

The following directives from CLAUDE.md apply to this phase:

| Constraint | Source | How It Affects This Phase |
|------------|--------|---------------------------|
| All code in `macroTorch` global namespace | CLAUDE.md (no require) | New FIELD_FUNC_MAP entries use `macroTorch.DRUID_FIELD_FUNC_MAP['key']` |
| Lua 1.12.1 -- no `#` unary length operator | CLAUDE.md (Lua Version Limitations) | Not applicable to this phase (no table length operations) |
| Dot syntax for method definitions and calls (Phase 6 D-01) | 06-CONTEXT.md | FIELD_FUNC_MAP entries and SelfTest calls use dot syntax consistently |
| Build concatenation order via build_order.txt | CLAUDE.md (build.sh) | No build order changes needed; files already in correct positions |
| Apache 2.0 license block comment | CONVENTIONS.md | No new files created; existing files already have license headers |
| Chinese comments for complex logic, English for simple | CONVENTIONS.md | `-- reserved for future expansion` comments in English (simple annotation) |
| 4-space indentation | CONVENTIONS.md | Follow existing DRUID_FIELD_FUNC_MAP indentation style |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/07-druid/07-CONTEXT.md` -- Locked decisions D-01 through D-04, scope boundary, call site map, deferred ideas [VERIFIED: project source]
- `entity/Player.lua:158-169` -- `isFormActive` current implementation using `GetShapeshiftFormInfo` API [VERIFIED: codebase]
- `classes/druid/Druid.lua:434-452` -- Existing DRUID_FIELD_FUNC_MAP entries (isOoc, isProwling, isBerserk, humanFormMana) -- canonical FIELD_FUNC_MAP pattern [VERIFIED: codebase]
- `classes/druid/Druid.lua:1267-1277` -- Existing SelfTest stubs for isCatForm/isBearForm [VERIFIED: codebase]
- `.planning/codebase/ARCHITECTURE.md` -- Metatable __index chain, FIELD_FUNC_MAP resolution order, class inheritance structure [VERIFIED: codebase analysis]
- `.planning/codebase/CONVENTIONS.md` -- Naming conventions, FIELD_FUNC_MAP naming pattern (UPPER_SNAKE_CASE), SelfTest registration pattern [VERIFIED: codebase analysis]

### Secondary (MEDIUM confidence)

- `.planning/phases/05-druid-player-cast-druid/05-CONTEXT.md` -- D-04 (skill methods concentrated in Druid constructor), Phase 5 skill method pattern reference [CITED: project source]
- `.planning/phases/06-fix-druid-castspell-isspellready-nil-bug-colon-dot-syntax-mi/06-CONTEXT.md` -- D-01 (pure dot syntax convention) [CITED: project source]
- `build_order.txt` -- Build concatenation order (no changes needed) [CITED: project source]

### Tertiary (LOW confidence)

- Moonkin Form spell name `'Moonkin Form'` -- assumed from WoW 1.12.1 English client knowledge [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new packages or tools; pure code refactoring
- Architecture: HIGH -- FIELD_FUNC_MAP pattern is well-established; metatable chain documented in ARCHITECTURE.md; SelfTest pattern established
- Pitfalls: MEDIUM -- SelfTest naming discrepancy identified; Moonkin Form string needs client verification

**Research date:** 2026-06-15
**Valid until:** 2026-07-15

## Phase Complexity Assessment

**Files to modify:** 4 (Druid.lua, bear.lua, utility.lua) + optional SelfTest registrations
**Lines to add:** ~30 (15 for FIELD_FUNC_MAP entries + 15 for SelfTest)
**Lines to change:** ~14 (7 call sites x ~2 lines each on average)
**New mechanisms:** 0
**Risk level:** LOW -- pure mechanical refactoring, no logic changes, FIELD_FUNC_MAP pattern well-established

## Pre-Existing SelfTest Status

The existing SelfTest registrations at Druid.lua:1267-1271 reference `isCatForm`/`isBearForm` (without "In") and will fail until the FIELD_FUNC_MAP entries are added. These tests were forward-looking stubs. The planner must:

1. Rename test title strings from `"Druid: isCatForm exists"` to `"Druid: DRUID_FIELD_FUNC_MAP isInCatForm exists"` (and same for isBearForm)
2. Update property access from `macroTorch.player.isCatForm` to `macroTorch.player.isInCatForm`
3. Add 3 new SelfTest registrations for `isInTravelForm`, `isInAquaticForm`, `isInCasterForm`
4. Re-categorize all 5 under the `-- Category G2: Form detection` section (currently only isCatForm/isBearForm are there)