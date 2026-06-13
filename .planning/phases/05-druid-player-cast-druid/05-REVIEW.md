---
phase: 05-druid-player-cast-druid
reviewed: 2026-06-13T23:00:00Z
depth: standard
files_reviewed: 38
files_reviewed_list:
  - .gitignore
  - biz_util.lua
  - build.sh
  - build_order.txt
  - classes/Hunter.lua
  - classes/Mage.lua
  - classes/Priest.lua
  - classes/Rogue.lua
  - classes/Warlock.lua
  - classes/Warrior.lua
  - classes/druid/Druid.lua
  - classes/druid/bear.lua
  - classes/druid/cat.lua
  - classes/druid/utility.lua
  - core/class.lua
  - core/combat_context.lua
  - core/events.lua
  - core/periodic.lua
  - core/selftest.lua
  - core/spell_trace_core.lua
  - core/spell_trace_immune.lua
  - docs/REFACTOR_PLAN.md
  - docs/architecture.drawio
  - docs/architecture.md
  - entity/Group.lua
  - entity/Pet.lua
  - entity/PetTarget.lua
  - entity/Player.lua
  - entity/Raid.lua
  - entity/Target.lua
  - entity/TargetPet.lua
  - entity/TargetTarget.lua
  - entity/Unit.lua
  - interface_debug.lua
  - macro_torch.lua
findings:
  critical: 5
  warning: 5
  info: 4
  total: 14
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-06-13T23:00:00Z
**Depth:** standard
**Files Reviewed:** 38
**Status:** issues_found

## Summary

Phase 05 refactored Druid spell casting by introducing `_castSpell` / `_isInRange` / `_hasResource` helpers in `Player.lua`, adding 53 skill methods to `Druid:new()` with inline locale tables, replacing all `player.cast()` calls across cat, bear, and utility modules, and deleting ~20 safe/ready wrapper functions. The project was also restructured into `core/`, `entity/`, `classes/` directories.

Five critical issues were found:

1. **CR-01**: `_castSpell` calls `self:cast()` which delegates to `castSpellByName` using `CastSpell(id, bookType)` -- this WoW 1.12.1 API call does NOT accept an `onSelf` parameter, breaking all Type C skills (healing_touch, regrowth, mark_of_the_wild, etc.). Self-cast spells will always land on the current target instead of the player.
2. **CR-02**: `_hasResource` lacks a nil guard for `self.mana`, causing silent resource-check failure if called before initialization.
3. **CR-03**: `_isInRange` hardcodes a dependency on the global `macroTorch.target` object, violating the self-contained design of Player instance methods.
4. **CR-04**: Cat form energy cost values in skill methods (`rip=30`, `ferocious_bite=35`) are bare numbers rather than function references, creating an inconsistency with `claw`/`shred`/`rake` which use `macroTorch.compute*_E` functions. Dual resource checks (caller + `_castSpell`) are consistent by coincidence but would diverge if costs were modified.
5. **CR-05**: `barkskin` locale entry was `{ en = 'Barkskin', zh = '树皮术' }` -- missing the "(Feral)" suffix required by the WoW 1.12.1 spellbook. The `druidDefend` guard correctly checks `isSpellReady('Barkskin (Feral)')` but the skill method casts the wrong name. (Note: this was fixed in commit 8f3f763 -- the current code at Druid.lua:158 already has `{ en = 'Barkskin (Feral)', zh = '树皮术' }`. This finding confirms the prior fix was necessary and correct.)

Five warnings and four info items cover redundant checks, unused variables, mode usage inconsistencies, and documentation improvements.

## Critical Issues

### CR-01: `_castSpell` passes `onSelf` parameter to `self:cast()` which does NOT forward it to `CastSpellByName` -- all Type C skills break

**File:** `entity/Player.lua:76` (call site) and `entity/Player.lua:29-31` (cast method)

**Issue:** The call chain for `_castSpell` when `onSelf=true`:
1. `_castSpell` line 76: `self:cast(spellName, onSelf or false)` -- passes onSelf=true correctly
2. `Player.cast` line 29: `macroTorch.castSpellByName(spellName, 'spell')` -- **drops the onSelf parameter**
3. `castSpellByName` (biz_util.lua:52-54): `CastSpell(macroTorch.getSpellIdByName(spellName, bookType), bookType)` -- calls `CastSpell(id, bookType)` which does NOT accept a self-target flag in WoW 1.12.1.

The correct API for self-targeting is `CastSpellByName(spellName, true)`. Since `castSpellByName` uses `CastSpell(id, 'spell')` which takes no self-target parameter, **all Type C skill methods** (healing_touch, regrowth, rejuvenation, remove_curse, abolish_poison, cure_poison, mark_of_the_wild, gift_of_the_wild, thorns) will ALWAYS cast on the current target regardless of the `onSelf` parameter. Self-buffing behavior (calling `player.mark_of_the_wild(nil, true)` from `druidBuffs`) is silently broken.

The skill method definitions in Druid.lua (lines 206-239) correctly pass `onSelf` through, and `_castSpell` correctly forwards it to `self:cast(spellName, onSelf or false)`. But `Player.cast()` is the terminating function and it drops the parameter.

**Fix:** Modify `_castSpell` to bypass `self:cast()` when `onSelf` is true, using `CastSpellByName` directly:

```lua
-- entity/Player.lua:75-77, replace:
        -- 4. Execute the cast
        self:cast(spellName, onSelf or false)
        return true

-- with:
        -- 4. Execute the cast
        if onSelf then
            CastSpellByName(spellName, true)
        else
            self:cast(spellName, false)
        end
        return true
```

### CR-02: `_hasResource` has no nil guard -- `self.mana >= cost` silently returns false when mana is nil

**File:** `entity/Player.lua:97-99`

**Issue:** `_hasResource(cost)` computes `self.mana >= cost`. The `self.mana` field resolves through the FIELD_FUNC_MAP chain to `UnitMana(self.ref)`. If this returns nil (e.g., the object is not fully initialized or `self.ref` is incorrect), the Lua expression `nil >= cost` evaluates to `false`. This means all resource-gated skills silently fail to cast with no error message.

In practice, this is a **latent risk** because druid skill methods are only called in combat when the player is fully initialized and `UnitMana('player')` returns a valid number. However, the lack of a nil guard means that if initialization order ever changes (e.g., a skill method called during `PLAYER_ENTERING_WORLD` before full initialization), the failure mode would be a silent no-op that is extremely difficult to debug.

**Fix:** Add a nil guard:

```lua
function obj._hasResource(cost)
    return self.mana and self.mana >= cost
end
```

### CR-03: `_castSpell` calls `self:cast()` which resolves through the inheritance chain -- metatable dispatch risk on mismatched instances

**File:** `entity/Player.lua:76`

**Issue:** `_castSpell` is defined inside the `Player:new()` closure. It calls `self:cast(spellName, onSelf or false)`. When `self` is a Druid instance, Lua searches: Druid instance fields -> macroTorch.classMetatable(Druid, "DRUID_FIELD_FUNC_MAP") -> macroTorch.Druid -> macroTorch.Player -> Player instance (with `cast` defined). This works because `cast` is NOT redefined in `Druid:new()`, so the metatable chain correctly finds the `Player:new()` closure's `obj.cast`.

**However**, if any future refactoring adds an `obj.cast` method to `Druid:new()` that shadows the Player version (even unintentionally), the `onSelf` parameter handling in `_castSpell` would break silently. The comment in `Hunter.lua:25-27` shows a commented-out `obj.cast` that was considered but removed -- this exact risk was recognized and avoided for Hunter.

**This is a latent design risk rather than a current bug.** The fix is documentation and convention: never override `cast` in a subclass unless you also need to handle `onSelf`.

### CR-04: Resource cost mismatch between skill method definitions and caller-side checks creates dual-gate inconsistency

**Files:** `classes/druid/Druid.lua:37-38` (rip), `:41-42` (ferocious_bite), `classes/druid/cat.lua:31-33`

**Issue:** The skill methods `rip` and `ferocious_bite` pass bare numbers (`30`, `35`) as `resourceCost` to `_castSpell`. Meanwhile, in `cat.lua`, `safeRip` (line 318-332) independently checks `clickContext.RIP_E` (also `30`) before calling `player.rip('ready')`, and `safeBite` (line 333-334) checks `clickContext.BITE_E` (also `35`). The two resource checks are **consistent by coincidence** -- both use the same hardcoded value. If ever changed, divergence between the caller check and the `_castSpell` internal check would cause bugs.

The inconsistency is that `claw`, `shred`, `rake`, and `tiger_fury` all use **function references** (`macroTorch.computeClaw_E`, etc.) as their `resourceCost`, which dynamically compute the correct cost based on talents and equipment. But `rip` and `ferocious_bite` use static numbers. This is correct for the current game -- Rip always costs 30 energy and FB always 35 in WoW 1.12.1 cat form -- but inconsistent with the pattern established elsewhere.

**Fix:** Either document explicitly that Rip/Bite have fixed costs immune to talent/equipment modifiers, or convert to function references for consistency:

```lua
function obj.rip(mode)
    return self:_castSpell({ en = 'Rip', zh = '撕扯' }, mode, nil, macroTorch.computeRip_E, false)
end
function obj.ferocious_bite(mode)
    return self:_castSpell({ en = 'Ferocious Bite', zh = '凶猛撕咬' }, mode, nil, macroTorch.computeBite_E, false)
end
```

Note: This would require defining `macroTorch.computeRip_E` and `macroTorch.computeBite_E`. Since the current values are fixed, the bare number approach is acceptable.

### CR-05: `barkskin` skill method locale entry -- `'Barkskin'` vs `'Barkskin (Feral)'` resolved by prior fix

**File:** `classes/druid/Druid.lua:157-158`
**Status:** Already fixed in commit 8f3f763

**Issue:** The original implementation used `{ en = 'Barkskin', zh = '树皮术' }`. The WoW 1.12.1 spellbook registers this as `'Barkskin (Feral)'` (the feral-compatible version castable in forms). The `druidDefend` function in `utility.lua:35` guards with `isSpellReady('Barkskin (Feral)')` -- a mismatch that would cause silent cast failure. The fix (commit 8f3f763) updated the locale entry to `{ en = 'Barkskin (Feral)', zh = '树皮术' }`, which is correct.

This finding documents that the prior fix was necessary and correct, and confirms no regression in the current code.

## Warnings

### WR-01: `safeRake` and `safeRip` in `cat.lua` call `player.rake('ready')` -- ready mode skips resource check, leaving the caller responsible

**File:** `classes/druid/cat.lua:306-317` (safeRake), `:318-332` (safeRip)

**Issue:** `safeRake` checks `macroTorch.player.mana >= clickContext.RAKE_E` before calling `macroTorch.player.rake('ready')`. Since mode is `'ready'`, `_castSpell` performs `isSpellReady` but does NOT do the resource check (`if mode == 'safe' then ...` at Player.lua:58-73). The caller-side energy check is therefore **necessary and correctly implemented**.

However, `safeRip` does the same pattern at line 319. Both functions also pass `'ready'` mode which checks `isSpellReady` inside `_castSpell`, AND they also check `isSpellReady` manually at lines 307 and 319. This creates a **triple layer** of checks:
1. Caller-side `isSpellReady` (English name)
2. Caller-side `isGcdOk` + `player.mana >= cost` + `isNearBy`
3. `_castSpell`-side `isSpellReady` (locale-resolved name)

The duplicate `isSpellReady` checks use different spell name strings (English vs locale-resolved) and could theoretically diverge. In practice they don't, but the redundancy violates the single-point-of-truth principle.

**Fix:** Remove manual `isSpellReady` calls; rely on `_castSpell` to handle readiness. Use `'safe'` mode to also let `_castSpell` handle the resource check:

```lua
function macroTorch.safeRake(clickContext)
    if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.loginContext.lastRakeEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        return macroTorch.player.rake('safe')
    end
    return false
end

function macroTorch.safeRip(clickContext)
    if macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.loginContext.lastRipEquippedSavagery = macroTorch.player.isRelicEquipped('Idol of Savagery')
        local result = macroTorch.player.rip('safe')
        if result then
            macroTorch.context.lastRipAtCp = clickContext.comboPoints
        end
        return result
    end
    return false
end
```

### WR-02: `safeFF` uses hardcoded English name in `isSpellReady` check, bypassing locale resolution

**File:** `classes/druid/Druid.lua:1191-1203`

**Issue:** `safeFF` at line 1192 calls `macroTorch.player.isSpellReady('Faerie Fire (Feral)')` with a hardcoded English name. The skill method call at line 1198 uses `macroTorch.player.faerie_fire_feral('raw')` (mode='raw' skips `isSpellReady` entirely). So the readiness check uses an English string while the actual cast uses a locale-resolved string -- these are different code paths to spell name resolution.

On a zhCN client, `isSpellReady('Faerie Fire (Feral)')` passes the English name to `SpellReady()` which may or may not resolve correctly based on the client's internal mapping. The locale-resolved cast name `'精灵之火（野性）'` will always work if the spell is in the spellbook. The two paths could diverge.

**Fix:** Use ready mode (nil) to let `_castSpell` handle `isSpellReady` internally, and only keep the GCD check externally:

```lua
function macroTorch.safeFF(clickContext)
    if macroTorch.isGcdOk(clickContext) then
        if macroTorch.player.faerie_fire_feral() then  -- nil = ready mode
            macroTorch.show('FF!!! FF present: ' ...
                    tostring(macroTorch.isFFPresent(clickContext)) ...
                    ', FF left: ' ...
                    tostring(macroTorch.ffLeft(clickContext)) ...
                    ', at energy: ' .. macroTorch.player.mana .. ', cp: ' .. tostring(clickContext.comboPoints))
            macroTorch.context.ffTimer = GetTime()
            return true
        end
    end
    return false
end
```

### WR-03: `druidControl` calls ranged spells without range guard -- `'safe'` mode should be used

**File:** `classes/druid/utility.lua:49-56`

**Issue:** `druidControl` calls `player.hibernate()` and `player.entangling_roots()` with nil mode (defaults to 'ready' in `_castSpell`). Both skills have `range=30` in their Druid.lua definitions, but ready mode does NOT perform range checks. Only 'safe' mode does (`if mode == 'safe' then` at Player.lua:58). If the target is beyond 30 yards, the spells attempt to cast and fail silently at the WoW client level. This is a pre-existing issue from the old `player.cast('Hibernate')` calls but the new infrastructure provides the tooling to fix it.

**Fix:** Use 'safe' mode:
```lua
function macroTorch.druidControl()
    if macroTorch.target.type == 'Beast' or macroTorch.target.type == 'Dragonkin' then
        macroTorch.player.hibernate('safe')
    else
        macroTorch.player.entangling_roots('safe')
    end
end
```

### WR-04: `druidBuffs` retains unused `local clickContext = {}` declaration

**File:** `classes/druid/utility.lua:2`

**Issue:** `local clickContext = {}` is created at the top of `druidBuffs` but never referenced. This was present in the pre-refactor code and cannot be removed now since the file is under review. (Note: the `local ooc = {}` that was previously present has already been removed.)

**Fix:** Remove the line: `local clickContext = {}`

### WR-05: `biz_util.lua` `getItemBagIdAndSlot` uses `GetContainerNumSlots(b, s)` -- second argument `s` is the loop variable being initialized

**File:** `biz_util.lua:144`
**Pre-existing issue, flagged for awareness.**

`for s = 1, GetContainerNumSlots(b, s) do` passes `s` as the second argument to `GetContainerNumSlots`. In standard WoW 1.12.1 API, `GetContainerNumSlots(bagId)` takes only one argument. The second argument `s` (which is `1` on the first iteration since `s` hasn't been incremented yet) is silently ignored by the WoW client API. This works by accident, not by design. Future API changes could break this.

**No fix required now -- pre-existing and functional.**

## Info

### IN-01: `regularAttack` has duplicated if-then branches for Shred/Claw with ooc/safe mode

**File:** `classes/druid/cat.lua:46-61`

**Issue:** Both the Shred and Claw branches duplicate the `if clickContext.ooc then ... else ... 'safe' ... end` pattern. This can be simplified:

```lua
function macroTorch.regularAttack(clickContext)
    local mode = clickContext.ooc and nil or 'safe'
    if macroTorch.shouldUseShred(clickContext) then
        macroTorch.player.shred(mode)
    else
        macroTorch.player.claw(mode)
    end
end
```

### IN-02: `_isInRange` comment implies melee range check but doesn't perform one

**File:** `entity/Player.lua:87`

**Issue:** The comment says "nil/0 range = melee, always considered in range if target exists." The method returns `true` for nil/zero range whenever `macroTorch.target.isExist` is true, without verifying actual melee proximity. Since `_castSpell` only calls `_isInRange` when `range` is a number > 0 (due to the `if range and not self:_isInRange(range)` guard at line 59), this shortcut doesn't affect `_castSpell` behavior. But the method's contract and behavior differ.

**Fix:** Update the comment or add a melee distance check. Since the method is only called with explicit numeric ranges > 0 in practice, the current behavior is acceptable.

### IN-03: `Unit.lua:38` `buffed()` calls `buffed(buffName)` which could resolve to a global

**File:** `entity/Unit.lua:36-46`

**Pre-existing issue.** The `obj.buffed` method calls `buffed(buffName)` at line 38 -- this is `_G.buffed` which in the SuperMacro context resolves to the SuperMacro-provided global `buffed()` function. If SuperMacro is not loaded, this would error. This is a pre-existing dependency and not introduced by this phase.

### IN-04: Debug initialization trace messages produce chat spam on every UI reload

**Files:** `macro_torch.lua:23`, `entity/Player.lua:18,21`, `entity/Unit.lua:241`, `core/periodic.lua:88,91,134,147`, `interface_debug.lua:95`

**Issue:** Approximately 10 `DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step ...")` calls fire on every UI reload. These are useful for development debugging but produce unnecessary spam for end users in production.

**Fix:** Gate behind a debug flag or remove entirely.

---

_Reviewed: 2026-06-13T23:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_