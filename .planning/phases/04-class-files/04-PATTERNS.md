# Phase 04: class-files (职业文件重组 + 构建系统收尾) - Pattern Map

**Mapped:** 2026-06-09
**Files analyzed:** 12 (10 new, 2 modified)
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `classes/druid/Druid.lua` | class-def | class-init | `entity/Player.lua` + `core/class.lua` | exact (same OOP pattern + class registration) |
| `classes/druid/cat.lua` | combat-func | combat-logic | `SM_Extend_Druid.lua` (cat functions subset) | exact (same source file, function subset) |
| `classes/druid/bear.lua` | combat-func | combat-logic | `SM_Extend_Druid.lua` (bear functions subset) | exact (same source file, function subset) |
| `classes/druid/utility.lua` | utility-func | utility | `SM_Extend_Druid.lua` (utility functions subset) | exact (same source file, function subset) |
| `classes/Hunter.lua` | class-file | class-init | `entity/Player.lua` (constructor pattern) | exact (same class pattern, needs TODO) |
| `classes/Mage.lua` | impl-func | standalone | `SM_Extend_Mage.lua` (source itself) | exact (pure rename, no changes) |
| `classes/Priest.lua` | impl-func | standalone | `SM_Extend_Priest.lua` (source itself) | exact (pure rename, no changes) |
| `classes/Rogue.lua` | impl-func | standalone | `SM_Extend_Rogue.lua` (source itself) | exact (pure rename, no changes) |
| `classes/Warlock.lua` | impl-func | standalone | `SM_Extend_Warlock.lua` (source itself) | exact (pure rename, no changes) |
| `classes/Warrior.lua` | impl-func | standalone | `SM_Extend_Warrior.lua` (source itself) | exact (pure rename, no changes) |
| `build_order.txt` | config | build-order | current `build_order.txt` (self-modify) | exact (same file, line edits) |
| `build.sh` | build-script | build-exec | current `build.sh` (self-modify) | exact (same file, 3-line change) |

## Pattern Assignments

### `classes/druid/Druid.lua` (class-def, class-init)

**Analog:** `entity/Player.lua` (constructor pattern + class definition)
**Analog 2:** `core/class.lua` (classMetatable factory usage)
**Analog 3:** `SM_Extend_Druid.lua` lines 1-255 (Apache header + constructor + FIELD_FUNC_MAP)

**Apache 2.0 license header pattern** (`entity/Player.lua` lines 1-15, identical in all source files):
```lua
--[[
   Copyright 2024 pf_miles

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]] --
```

**Class declaration pattern** (`SM_Extend_Druid.lua` line 17, also `entity/Player.lua` line 17):
```lua
macroTorch.Druid = macroTorch.Player:new()
```

**Constructor pattern with classMetatable** (`SM_Extend_Druid.lua` lines 19-230, referencing `core/class.lua` lines 21-34):
```lua
function macroTorch.Druid:new()
    local obj = {}

    setmetatable(obj, macroTorch.classMetatable(self, "DRUID_FIELD_FUNC_MAP"))

    function obj.showEnergyUsageSet()
        -- ... energy constant display ...
    end

    function obj.catAtk(rough)
        -- ... main cat entry point ...
    end

    return obj
end
```
Key pattern: `setmetatable(obj, macroTorch.classMetatable(self, "DRUID_FIELD_FUNC_MAP"))` -- uses the unified factory from `core/class.lua`, not hand-written `__index`.

**FIELD_FUNC_MAP pattern** (`SM_Extend_Druid.lua` lines 232-253):
```lua
macroTorch.DRUID_FIELD_FUNC_MAP = {
    ['comboPoints'] = function(self)
        return GetComboPoints()
    end,
    ['isOoc'] = function(self)
        return self.buffed('Clearcasting', 'Spell_Shadow_ManaBurn')
    end,
    -- ... all other fields ...
}
```

**registerPlayerClass pattern** (`SM_Extend_Druid.lua` lines 254-255, see also `core/class.lua` lines 43-45 for definition):
```lua
macroTorch.druid = macroTorch.Druid:new()
macroTorch.registerPlayerClass("DRUID", macroTorch.Druid)
```

**SpellTrace:register pattern** (`SM_Extend_Druid.lua` lines 484-503):
```lua
macroTorch.SpellTrace:register('Pounce', {
    spellId = 9827, land = true,
    immune = true, debuffTexture = 'Ability_Druid_SupriseAttack'
})
-- ... 4 more registrations ...
```

**SelfTest:register pattern** (`SM_Extend_Druid.lua` lines 1752-1870):
```lua
macroTorch.SelfTest:register("Druid: Shred() exists", function()
    assert(macroTorch.isFunctionExist("Shred"), "Shred not found in _G")
end, false)
-- ... ~24 more registrations ...
```

**Energy computation functions pattern** (`SM_Extend_Druid.lua` lines 390-480):
All compute* functions follow the pattern: `function macroTorch.computeXxx_E()` / `function macroTorch.computeXxx_Erps()` / `function macroTorch.computeXxx_Duration()`.

**Shared helper function pattern** (`SM_Extend_Druid.lua` lines 539-1115):
Functions like `shouldUseShred`, `shouldCastRip`, `shouldUseBite`, `shouldCastFFDuringWaitWindow`, `getMinimumAffordableAbilityCost`, `computeErps`, `computeNormalRelic`, `selectFerocityOrEmeraldRot`, `recoverNormalRelic`, `isTrivialBattleOrPvp`, `isTrivialBattle`, `combatUrgentHPRestore`, `isFightStarted`, `isKillShotOrLastChance`, `isNearBy`, `isGcdOk`, `safeFF`, `tigerSelfGCD`.

**Status-check function pattern** (`SM_Extend_Druid.lua` lines 1127-1242):
Functions `isRipPresent`, `ripLeft`, `isRakePresent`, `rakeLeft`, `isFFPresent`, `ffLeft`, `isTigerPresent`, `tigerLeft`, `isPouncePresent`, `pounceLeft`, `isDemoralizingRoarPresent` -- all follow pattern:
```lua
function macroTorch.isXxxPresent(clickContext)
    -- buff/debuff detection via texture strings
end
```

---

### `classes/druid/cat.lua` (combat-func, combat-logic)

**Analog:** `SM_Extend_Druid.lua` (catAtk function body + all cat modules)
No standalone file analog -- the cat functions are a contiguous block within the main Druid file.

**Key extract boundary:** Lines 257-1500 (approximately) from `SM_Extend_Druid.lua`, covering:
- `burstMod` (rush mod)
- `regularAttack` (regular attack entry)
- `otMod` (OT module)
- `termMod` + `cp5Bite` + `energyDischargeBeforeBite` (finishers)
- `oocMod` (Omen of Clarity)
- `tryBiteKillShot` + `reshiftMod` + `shouldDoReshift` (reshift)
- `keepTigerFury` (Tiger's Fury)
- `keepRip` + `dischargeEnergyChangeRelicAndRip` + `quickKeepRip` (Rip module)
- `keepRake` (Rake module)
- `keepFF` (FF module)
- `catAtk` (main entry point, lines ~1173-1286)
- All cat safe/ready functions: `safeShred`, `readyShred`, `safeClaw`, `readyClaw`, `safeRake`, `safeRip`, `safeBite`, `readyBite`, `safeCower`, `readyCower`, `safeTigerFury`, `safePounce`, `readyReshift`
- `atkPowerBurst`

**Core safe/ready pattern** (from `SM_Extend_Druid.lua`, used by all cat and bear functions):
```lua
function macroTorch.readyXxx(clickContext)
    local player = macroTorch.player
    if player.isSpellReady('Xxx') then
        player.cast('Xxx')
    end
end

function macroTorch.safeXxx(clickContext)
    local player = macroTorch.player
    if player.mana >= clickContext.XXX_E then
        macroTorch.readyXxx(clickContext)
    end
end
```

**NOTE:** These are copy-paste extracts from source. No line editing within function bodies. The cat.lua file has NO Apache license header (not needed since Druid.lua is the entry file for the druid/ subdirectory and already has the license).

---

### `classes/druid/bear.lua` (combat-func, combat-logic)

**Analog:** `SM_Extend_Druid.lua` (bear functions subset)
No standalone file analog.

**Key extract boundary:** Lines 1425-1716 from `SM_Extend_Druid.lua`, covering:
- Bear safe/ready pairs: `safeMaul`, `readyMaul`, `safeSavageBite`, `readySavageBite`, `readyGrowl`, `safeDemoralizingRoar`, `readyDemoralizingRoar`, `safeSwipe`, `readySwipe`
- Bear modules: `bearOocMod`, `bearOtMod`, `bearDebuffMod`, `bearFFMod`, `bearRegularAttack`, `bearReshiftMod`, `bearAoe`
- `bearAtk` main entry point

**Same safe/ready pattern as cat** -- functions follow identical structure to cat.lua safe/ready pairs but for bear abilities.

---

### `classes/druid/utility.lua` (utility-func, utility)

**Analog:** `SM_Extend_Druid.lua` (utility functions subset)

**Key extract boundary:** Lines 1502-1750 from `SM_Extend_Druid.lua`, covering:
- `druidBuffs` (lines 1502-1513)
- `druidStun` (lines 1515-1534)
- `druidDefend` (lines 1536-1553)
- `druidControl` (lines 1623-1631)
- `pokemonLoad` (lines 1718-1750)

---

### `classes/Hunter.lua` (class-file, class-init)

**Analog:** `SM_Extend_Hunter.lua` (same file, renamed + TODO added)
**Reference for TODO pattern:** `entity/Player.lua` (uses classMetatable -- the target state for Hunter)

**Current hand-written metatable block** (`SM_Extend_Hunter.lua` lines 29-46):
```lua
    -- impl hint: original '__index' & metatable setting:
    -- self.__index = self
    -- setmetatable(obj, self)

    setmetatable(obj, {
        -- k is the key of searching field, and t is the table itself
        __index = function(t, k)
            -- missing instance field search
            if macroTorch.HUNTER_FIELD_FUNC_MAP[k] ~= nil then
                return macroTorch.HUNTER_FIELD_FUNC_MAP[k](t)
            end
            -- class field & method search
            local class_val = self[k]
            if class_val ~= nil then
                return class_val
            end
        end
    })
```

**TODO comment placement:** Insert exactly one line BEFORE `setmetatable(obj, {` (line 33 in current file):
```lua
    -- TODO(Phase-N): migrate to macroTorch.classMetatable
```

**Target pattern** (from `core/class.lua` lines 21-34, and `entity/Player.lua` for usage):
```lua
    setmetatable(obj, macroTorch.classMetatable(self, "HUNTER_FIELD_FUNC_MAP"))
```
This replaces the hand-written 9-line `__index` block -- but NOT done in Phase 4, only noted with TODO.

---

### `classes/Mage.lua` / `classes/Priest.lua` / `classes/Rogue.lua` / `classes/Warlock.lua` / `classes/Warrior.lua`

These 5 files are pure `git mv` operations -- zero content changes.

**Source files and their pattern:**
- `SM_Extend_Mage.lua` (81 lines) -- Apache header + standalone `macroTorch.mageRangedAtk()` / `macroTorch.mageMeleeAtk()` functions
- `SM_Extend_Priest.lua` (111 lines) -- Apache header + standalone `macroTorch.priestRangedAtk()` functions
- `SM_Extend_Rogue.lua` (149 lines) -- Apache header + standalone functions starting `---盗贼专用start---`
- `SM_Extend_Warlock.lua` (92 lines) -- Apache header + standalone `macroTorch.wlkCurses()` functions
- `SM_Extend_Warrior.lua` (210 lines) -- Apache header + standalone `macroTorch.wroRangedAtk()` functions

All share the Apache 2.0 license header (lines 1-15). All use `macroTorch.*` global function naming. No content changes in Phase 4.

---

### `build_order.txt` (config, build-order) -- MODIFIED FILE

**Analog:** Current `build_order.txt` (self-modify)

**Current state** (44 lines):
Lines 26-33: Current `SM_Extend_*.lua` entries (7 class files + 1 comment)
Lines 34-44: Phase 4 future entries (using wrong PascalCase paths)

**Changes to apply:**
1. Remove lines 26-33 (current SM_Extend_*.lua entries and their comment)
2. Replace lines 34-44 with corrected snake_case paths:
```
# classes/ Phase 4 (migrated from SM_Extend_*.lua)
classes/druid/Druid.lua
classes/druid/cat.lua
classes/druid/bear.lua
classes/druid/utility.lua
classes/Hunter.lua
classes/Mage.lua
classes/Priest.lua
classes/Rogue.lua
classes/Warlock.lua
classes/Warrior.lua
```
3. Key correction: `classes/Druid.lua` -> `classes/druid/Druid.lua`, `classes/Druid/cat.lua` -> `classes/druid/cat.lua`, etc.

**Line-by-line diff target** (starting after `core/events.lua` on line 25):
```
# current class files (Phase 4 will move to classes/)
SM_Extend_Druid.lua        <- DELETE
SM_Extend_Hunter.lua       <- DELETE
...                         <- DELETE all 7 SM_Extend files
SM_Extend_Warrior.lua      <- DELETE
# classes/ Phase 4 future files  <- DELETE comment
classes/Druid.lua           <- REPLACE with classes/druid/Druid.lua
classes/Druid/cat.lua       <- REPLACE with classes/druid/cat.lua
...                          <- REPLACE all 4 druid paths with snake_case
```

---

### `build.sh` (build-script, build-exec) -- MODIFIED FILE

**Analog:** Current `build.sh` (self-modify)

**Current fault-tolerant pattern** (lines 20-24):
```sh
    if [ -f "$line" ]; then
        printf '\n' >> "$target"
        cat "$line" >> "$target"
    fi
```

**Target strict-mode pattern:**
```sh
    if [ -f "$line" ]; then
        printf '\n' >> "$target"
        cat "$line" >> "$target"
    else
        echo "ERROR: File not found in build_order.txt: $line" >&2
        exit 1
    fi
```

The `else` branch is the only addition -- everything else in `build.sh` remains unchanged.

---

## Shared Patterns

### Apache 2.0 License Header

**Source:** Every source file in the codebase, lines 1-15

**Apply to:** `classes/druid/Druid.lua` (the entry file for druid/ subdirectory).

**NOT applied to:** `classes/druid/cat.lua`, `classes/druid/bear.lua`, `classes/druid/utility.lua` -- these are satellite files within the same subdirectory and do not need their own license header. The 5 non-Druid class files retain their existing license headers from the original `SM_Extend_*.lua` files.

### Function Naming Convention

**Pattern:** All functions use `macroTorch.` prefix, defined at global namespace scope. File splitting does not change visibility -- all functions remain accessible globally as long as `build_order.txt` loads files in correct order.

**Dependency ordering rule:** `classes/druid/Druid.lua` MUST come before `classes/druid/cat.lua`, `classes/druid/bear.lua`, and `classes/druid/utility.lua` in `build_order.txt` because the subclass files reference functions defined in the parent file (shared helpers, energy constants, etc.).

### Copy-Paste Split Strategy

**Source:** `SM_Extend_Druid.lua` (1870 lines)

**Method:** Extract exact line ranges, not manual retyping. Every function boundary (`end` to next `function`) is preserved as-is, including comments and blank lines between functions.

**Verification:** After extracting each target file, verify with:
```bash
grep -c "^function macroTorch\." classes/druid/Druid.lua
grep -c "^function macroTorch\." classes/druid/cat.lua
grep -c "^function macroTorch\." classes/druid/bear.lua
grep -c "^function macroTorch\." classes/druid/utility.lua
```
The sum of function counts across 4 files must equal the total in `SM_Extend_Druid.lua`.

### git mv for Non-Druid Files

**Pattern:** Use `git mv` (not `mv` + `git add`) to preserve git history for the 6 non-Druid files.

**Example:**
```bash
git mv SM_Extend_Hunter.lua classes/Hunter.lua
```

For Hunter specifically: after `git mv`, add the TODO comment to `classes/Hunter.lua`. For the other 5, no edits after `git mv`.

### Atomic Commit Order

**Pattern (D-02):**
1. Create `classes/druid/` directory + 4 Druid files (write tool)
2. `git mv` 6 SM_Extend_*.lua to classes/ (for non-Druid files)
3. Add TODO comment to `classes/Hunter.lua`
4. Update `build_order.txt` (remove SM_Extend_* lines + correct druid paths)
5. Update `build.sh` (fault-tolerant -> strict mode)
6. `./build.sh` -- verify builds green
7. `git rm` all 7 `SM_Extend_*.lua` files
8. `./build.sh` -- verify builds green again
9. `git add` all changes, single commit

**Key invariant:** No intermediate git state has duplicate definitions of `macroTorch.Druid:new()` or any other function.

## No Analog Found

All 12 files have exact analogs in the existing codebase. Phase 4 is a pure reorganization phase -- no new patterns, no new logic. Every function body is copy-pasted verbatim from its source file.

## Metadata

**Analog search scope:** `/Users/yue.weny/finalanswer/macro-torch/macro-torch/` (root directory)
- `entity/*.lua` -- OOP class patterns (Player.lua, Unit.lua)
- `core/*.lua` -- infrastructure patterns (class.lua, events.lua, selftest.lua)
- `SM_Extend_*.lua` -- 7 class files (sources for reorganization)
- `build_order.txt` -- build manifest
- `build.sh` -- build script

**Files scanned:** 15 (7 SM_Extend_*.lua, entity/Player.lua, core/class.lua, core/events.lua, core/selftest.lua, core/spell_trace_core.lua, build_order.txt, build.sh, core/combat_context.lua)

**Pattern extraction date:** 2026-06-09