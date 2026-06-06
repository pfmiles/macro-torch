# Technology Stack

**Analysis Date:** 2026-06-06

## Languages

**Primary:**
- Lua (WoW 1.12.1 / Turtle WoW addon runtime) - All source code is Lua

**No secondary languages.** The project is pure Lua with a shell build script.

## Runtime

**Environment:**
- World of Warcraft 1.12.1 client (Vanilla / Turtle WoW private server)
- Lua 5.1 as embedded in the WoW 1.12.1 addon engine
- No standalone Lua runtime or third-party VM -- code executes within the WoW client addon sandbox

**Package Manager:**
- None. This is a WoW addon -- there is no dependency manager. All code is hand-written Lua that runs in the WoW addon environment. No `package.json`, `Cargo.toml`, or equivalent.

**Build Tool:**
- `/bin/sh` shell script (`build.sh`) -- concatenates Lua source files in a specific order into a single output file
- No bundler, transpiler, or minifier

**Deployment Target:**
- `SM_Extend.lua` output file is copied (via `build.sh` on Cygwin/Windows) to the SuperMacro addon directory under TurtleWoW's `Interface/AddOns/SuperMacro/`
- Target path: `D:\games\TurtleWoW\Interface\AddOns\SuperMacro\SM_Extend.lua` (Windows/Cygwin only)

## Frameworks

**Core:**
- None. No external frameworks. All abstractions (OOP, event system, LRU stack) are hand-implemented in Lua.

**Object-Oriented Pattern (hand-rolled):**
- Class inheritance via Lua metatables with custom `__index` metamethods
- Each class has a `new()` constructor that returns an object with its own `setmetatable`
- Field resolution chain: `FIELD_FUNC_MAP` -> class methods -> parent class (via metatable chain)
- Example class hierarchy:
  - `macroTorch.Unit` (base) -> `macroTorch.Player`, `macroTorch.Target`, `macroTorch.Pet`
  - `macroTorch.Player` -> `macroTorch.Druid`, `macroTorch.Hunter`
  - `macroTorch.Unit` -> `macroTorch.TargetTarget`, `macroTorch.TargetPet`, `macroTorch.PetTarget`

**Data Structures (hand-rolled):**
- `macroTorch.LRUStack` - Bounded stack with LRU eviction, used for event tracking (`event_stack.lua`)
- `macroTorch.periodicTasks` - Task scheduler running at 0.1s intervals via WoW's `OnUpdate` frame handler (`battle_event_queue.lua`)

## Key Dependencies

**Critical (WoW Client API):**
The addon depends on the WoW 1.12.1 Lua API. Key API categories used:

| API Category | Functions Used | Files |
|--------------|----------------|-------|
| Unit State | `UnitExists`, `UnitHealth`, `UnitMana`, `UnitHealthMax`, `UnitManaMax`, `UnitName`, `UnitLevel`, `UnitClass`, `UnitRace`, `UnitSex`, `UnitIsDead`, `UnitIsPlayer`, `UnitPlayerControlled`, `UnitPowerType`, `UnitClassification`, `UnitCreatureType`, `UnitCreatureFamily`, `UnitFactionGroup`, `UnitCanAttack`, `UnitCanAssist`, `UnitIsEnemy`, `UnitAffectingCombat`, `UnitInRaid`, `UnitXP` | `Unit.lua`, `Target.lua`, `Player.lua` |
| Buff/Debuff | `UnitBuff`, `UnitDebuff`, `GetPlayerBuffTimeLeft` | `Unit.lua`, `Target.lua` |
| Spell/Item | `CastSpell`, `CastSpellByName`, `GetSpellName`, `GetSpellCooldown`, `GetSpellTexture`, `GetSpellAutocast`, `ToggleSpellAutocast`, `SpellReady`, `IsCurrentCast`, `UseContainerItem`, `UseInventoryItem`, `GetInventoryItemCooldown`, `GetContainerItemCooldown`, `GetContainerItemLink`, `GetContainerNumSlots`, `GetContainerItemInfo`, `GetInventoryItemLink`, `GetInventoryItemTexture`, `GetInventorySlotInfo`, `PickupContainerItem`, `EquipCursorItem` | `biz_util.lua`, `Player.lua` |
| Combat | `GetComboPoints`, `IsCurrentAction`, `IsAutoRepeatAction`, `IsAttackAction`, `ActionHasRange`, `IsEquippedAction`, `GetActionTexture`, `GetActionCooldown`, `GetActionText`, `UseAction` | `Player.lua`, `biz_util.lua` |
| Event System | `CreateFrame`, `frame:RegisterEvent`, `frame:SetScript("OnEvent")`, `frame:SetScript("OnUpdate")` | `battle_event_queue.lua` |
| Target/Combat | `TargetNearestEnemy`, `ClearTarget`, `AssistUnit`, `SendChatMessage` | `Player.lua` |
| Pet | `PetAggressiveMode`, `PetDefensiveMode`, `PetPassiveMode`, `PetAttack`, `PetFollow`, `PetWait`, `PetDismiss`, `HasPetUI`, `IsPetAttackActive`, `ToggleSpellAutocast` | `Pet.lua` |
| Stance/Form | `GetShapeshiftFormInfo`, `GetNumShapeshiftForms`, `CastShapeshiftForm` | `Player.lua`, `SM_Extend_Warrior.lua` |
| Talent | `GetNumTalentTabs`, `GetNumTalents`, `GetTalentInfo` | `biz_util.lua` |
| Party/Raid | `GetNumPartyMembers`, `GetNumRaidMembers` | `Player.lua`, `biz_util.lua` |
| UI | `DEFAULT_CHAT_FRAME:AddMessage`, `ChatTypeInfo`, `GetBattlefieldInstanceRunTime` | `interface_debug.lua`, `Player.lua` |
| Range | `CheckInteractDistance` | `Unit.lua`, multiple class files |

**External Addon Dependencies (optional):**
- **SuperMacro** -- **Required.** The `SM_Extend.lua` output is loaded by the SuperMacro addon. SuperMacro provides the extended macro execution environment that allows running scripts longer than the standard 255-character WoW macro limit. The project's output is specifically designed to be consumed by SuperMacro.
- **SuperWoW** (`SUPERWOW_STRING` global) -- Optional but used for enhanced functionality. When available, provides:
  - `UnitXP("distanceBetween", ...)` for precise distance measurement (`Unit.lua`, `biz_util.lua`)
  - `UNIT_CASTEVENT` for accurate spell cast tracking (`battle_event_queue.lua`)
  - `UnitXP("behind", ...)` for behind-target detection (`Player.lua`)
  - Extended `UnitExists` returning GUIDs for reliable unit identification (`Unit.lua`)
- **TWT (Threat Meter)** (`macroTorch.TWT`) -- Optional. Integrated for threat percentage readings in `Player.lua` via `PLAYER_FIELD_FUNC_MAP.threatPercent`.

## Build System

**Build script:** `build.sh`

**Concatenation order (critical for dependency resolution):**
1. `macro_torch.lua` -- Global namespace initialization (`macroTorch = {}`)
2. `impl_util.lua` -- Utility functions (string, table, type checking)
3. `interface_debug.lua` -- Debug output and action inspection functions
4. `Unit.lua` -- Base Unit class with `UNIT_FIELD_FUNC_MAP`
5. All remaining `*.lua` files (excluding the output `SM_Extend.lua` and the four explicitly ordered files above)

**Build output:**
- `SM_Extend.lua` (5239 lines, 196KB) -- generated file, git-ignored, never manually edited

**Copy to game directory:** The `build.sh` script copies `SM_Extend.lua` to the SuperMacro addon directory on Cygwin/Windows environments only. The copy step is controlled by OSTYPE detection:
```sh
if [[ "$OSTYPE" == "cygwin" ]]; then
    cp $target /cygdrive/d/games/TurtleWoW/Interface/AddOns/SuperMacro/
fi
```

## Configuration

**Environment:**
- No `.env` files or environment variable configuration
- No configuration files (no JSON/YAML/TOML config)
- All configuration is hardcoded in Lua source files:
  - Texture maps for spell/item buff detection: `texture_map.lua` (`SPELL_TEXTURE_MAP`, `ITEM_TEXTURE_MAP`)
  - Energy costs, durations, constants: embedded in class files (e.g., `macroTorch.CLAW_E`, `macroTorch.RIP_BASE_DURATION` in `SM_Extend_Druid.lua`)
  - Immune tables persisted via `SM_EXTEND.immuneTable` and `SM_EXTEND.definiteBleedingTable` global variables

## Platform Requirements

**Development:**
- Text editor or IDE (project includes `.idea/` directory for JetBrains IDEs)
- Shell environment with `/bin/sh` and standard Unix tools (`find`, `grep`, `xargs`, `cat`)
- No language runtime installation required beyond the WoW client itself
- Git for version control

**Production:**
- Turtle WoW (1.12.1) client with SuperMacro addon installed
- Optional: SuperWoW client mod for enhanced features
- Windows (primary deployment target via Cygwin build step)
- No server-side components -- all execution is client-side

---

*Stack analysis: 2026-06-06*