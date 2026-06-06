# External Integrations

**Analysis Date:** 2026-06-06

## APIs & External Services

**No external network services.** This is a client-side WoW addon that executes entirely within the WoW 1.12.1 Lua sandbox. There is no HTTP, no webhooks, no remote API calls, no cloud services. All integrations are with the WoW client API and local addon-to-addon communication via shared global variables.

### WoW 1.12.1 Client API (Primary Integration Boundary)

The WoW client exposes a Lua C API that the addon calls. This is the only "external" interface. Key API functions are organized by functional domain:

**Combat Actions (output -- what the addon tells the game to do):**
- `CastSpell(spellId, bookType)` - Cast a spell by its numeric ID (`biz_util.lua:52-54`)
- `CastSpellByName(spellName)` - Cast a spell by name string (class files, direct usage)
- `UseContainerItem(bagId, slotIndex, onSelf)` - Use an item from a bag slot (`Player.lua:35`)
- `UseInventoryItem(slotIndex)` - Use an equipped item (trinkets, etc.) (`Player.lua:56,66`)
- `UseAction(slotIndex)` - Trigger an action bar button (`Player.lua:134,141,148,155`)
- `PickupContainerItem(bagId, slotIndex)` + `EquipCursorItem(slotIndex)` - Equipment swapping (`biz_util.lua:285-290`)
- `CastShapeshiftForm(index)` - Change stance/form (`SM_Extend_Warrior.lua:120,162`)
- `PetAttack()`, `PetAggressiveMode()`, `PetDefensiveMode()`, etc. - Pet control (`Pet.lua`)
- `ToggleSpellAutocast(spellId, bookType)` - Toggle pet auto-cast (`Pet.lua:96`)
- `SendChatMessage(text)` - Output messages to chat (`Player.lua:462`)

**Unit State Queries (input -- what the addon reads from the game):**
- `UnitExists`, `UnitHealth`, `UnitMana`, `UnitHealthMax`, `UnitManaMax` - Core unit state (`Unit.lua`)
- `UnitName`, `UnitLevel`, `UnitClass`, `UnitRace`, `UnitSex` - Unit identity (`Unit.lua`)
- `UnitBuff(unitId, index)`, `UnitDebuff(unitId, index)` - Buff/debuff scanning (`Unit.lua:28-33`, `Target.lua`)
- `GetComboPoints()` - Combo point tracking (`SM_Extend_Druid.lua:253`)
- `UnitPowerType(unitId)` - Resource type detection (`Unit.lua:161-163`)
- `UnitClassification(unitId)` - Mob classification (elite, worldboss) (`Unit.lua:182-184`)
- `UnitCreatureType`, `UnitCreatureFamily` - Creature metadata (`Unit.lua`)
- `UnitCanAttack`, `UnitCanAssist`, `UnitIsEnemy` - Combat relationships (`Unit.lua`)
- `UnitAffectingCombat` - Combat state (`Unit.lua:239-241`)
- `CheckInteractDistance(unitId, index)` - Range checking (`Unit.lua:225-231`)

**Spell/Item State Queries:**
- `GetSpellName(spellId, bookType)` - Spell name lookup (`biz_util.lua:24`)
- `GetSpellCooldown(spellId, bookType)` - Spell cooldown (`biz_util.lua:129`)
- `GetSpellTexture(spellId, bookType)` - Spell icon texture (`biz_util.lua:139`)
- `SpellReady(spellName)` - Spell availability (`Player.lua:99`)
- `IsCurrentCast(spellId, bookType)` - Currently casting check (`biz_util.lua:179`)
- `GetActionTexture(slot)`, `GetActionCooldown(slot)` - Action bar state (`interface_debug.lua`, `biz_util.lua`)
- `IsAttackAction(slot)`, `ActionHasRange(slot)`, `IsCurrentAction(slot)`, `IsAutoRepeatAction(slot)` - Action classification (`Player.lua`)
- `GetContainerItemLink(bagId, slotId)`, `GetContainerItemCooldown(bagId, slotId)`, `GetContainerNumSlots(bagId)` - Bag inventory (`biz_util.lua`, `Player.lua`)
- `GetInventoryItemLink("player", slot)`, `GetInventoryItemCooldown("player", slot)`, `GetInventoryItemTexture("player", slot)` - Equipment state (`biz_util.lua`, `Player.lua`)
- `GetInventorySlotInfo("RangedSlot")` - Slot mapping (`biz_util.lua:91`)

**Form/Stance Queries:**
- `GetNumShapeshiftForms()`, `GetShapeshiftFormInfo(i)` - Form enumeration (`Player.lua:83-84`)

**Talent Queries:**
- `GetNumTalentTabs()`, `GetNumTalents(tabIndex)`, `GetTalentInfo(tabIndex, talentIndex)` - Talent tree scanning (`biz_util.lua:228-237`)

**Event System:**
- `CreateFrame("Frame")` - Creates a hidden UI frame for event listening (`battle_event_queue.lua:45`)
- `frame:RegisterEvent(eventName)` - Subscribes to WoW game events (`battle_event_queue.lua:48-68`)
- `frame:SetScript("OnEvent", handler)` - Event handler binding (`battle_event_queue.lua:153`)
- `frame:SetScript("OnUpdate", handler)` - Per-frame update handler for periodic tasks (`battle_event_queue.lua:190`)

**Time:**
- `GetTime()` - Used extensively for timing calculations, cooldown tracking, debuff/buff duration computation, and event ordering

**Party/Raid:**
- `GetNumPartyMembers()`, `GetNumRaidMembers()` - Group size queries (`Player.lua`, `biz_util.lua`)

**UI:**
- `DEFAULT_CHAT_FRAME:AddMessage(text, r, g, b, id)` - Debug output to chat (`interface_debug.lua:91`)
- `ChatTypeInfo` - Color lookup for chat messages (`interface_debug.lua:80-89`)

**Other:**
- `GetBattlefieldInstanceRunTime()` - Battleground detection (`Player.lua:111`)

### SuperMacro Addon (Required)

**Category:** Addon runtime dependency

**What it provides:**
- SuperMacro is an addon that extends WoW's macro system, allowing scripts longer than the native 255-character limit
- The entire `SM_Extend.lua` output is loaded by SuperMacro and executed within its macro execution context
- Without SuperMacro installed, the generated code cannot run

**Integration mechanism:**
- File system: `SM_Extend.lua` is placed in SuperMacro's addon directory
- `SM_EXTEND` global variable: the addon reads from / writes to `SM_EXTEND.*` for persistent cross-session data (`battle_event_queue.lua:487-518`)
  - `SM_EXTEND.immuneTable[className]` -- Persistent immune tracking across combat sessions
  - `SM_EXTEND.definiteBleedingTable[className]` -- Persistent definite bleeding tracking

### SuperWoW Client Mod (Optional)

**Category:** Client enhancement -- gracefully degrades when absent

**Detection:** Checks for `SUPERWOW_STRING` global variable (`Unit.lua:117-122`, `battle_event_queue.lua:66-69`)

**Features enabled when present:**
- `UnitXP("distanceBetween", unitA, unitB)` -- Precise distance measurement between any two units (`Unit.lua:149`, `biz_util.lua:187`)
- `UnitXP("behind", "player", "target")` -- Determines if player is behind target (`Player.lua:504-505`)
- `UNIT_CASTEVENT` game event -- Reliable spell cast tracking with unit GUID and spell ID (`battle_event_queue.lua:124-131`)
- Extended `UnitExists(unitId)` returning GUIDs for reliable unit identity tracking (`Unit.lua:117-122`)

**Degradation:** When SuperWoW is absent:
- `Unit.guid` returns `nil` (falls back safely)
- `Unit.distance` returns `0` (no distance data available)
- `isBehindTarget` returns `false`
- Spell cast tracking uses `RAW_COMBATLOG` or chat message parsing as fallback

### TWT Threat Meter Addon (Optional)

**Category:** Combat information source

**Detection:** Checks for `macroTorch.TWT` global table existence (`Player.lua:491-496`)

**Features enabled when present:**
- `player.threatPercent` -- Reads threat percentage from TWT's data structure (`Player.lua:490-497`)
  - Access path: `TWT.threats[TWT.name].perc`

**Degradation:** When TWT is absent, `threatPercent` returns `0`

## Data Storage

**Databases:**
- None. No database. The addon runs in-memory within the WoW client Lua VM.

**Persistent Storage (cross-session):**
- `SM_EXTEND` global table -- Persisted by SuperMacro addon across sessions. Used for:
  - `SM_EXTEND.immuneTable` -- Immunity records by class and spell name (`battle_event_queue.lua:485-500`)
  - `SM_EXTEND.definiteBleedingTable` -- Confirmed bleeding targets by class and spell name (`battle_event_queue.lua:502-518`)

**In-Memory State (session only):**
- `macroTorch.context` -- Per-combat mutable context (cleared on combat exit at `battle_event_queue.lua:99-101`)
  - Sub-keys: `immuneTable`, `definiteBleedingTable`, `targetHealthVector`, `ffTimer`, `attackSlot`, `autoShootSlot`, `behindAttackFailedTime`, `landTable`, `castTable`, `failTable`
- `macroTorch.loginContext` -- Per-login-session persistent context (cleared on login/entering world at `battle_event_queue.lua:79`)
  - Sub-keys: `castTable`, `failTable`, `landTable`, `tigerTimer`
- `macroTorch.itemLoadingTable` -- Equipment swap tracking per slot (`Player.lua:272-456`)
- `macroTorch.periodicTasks` -- Registry of interval-based tasks

**File Storage:**
- Local filesystem only (WoW addon directory)
- No cloud storage, no CDN

**Caching:**
- `clickContext` pattern: Per-macro-execution cache of computed values (e.g., `clickContext.SHRED_E`, `clickContext.RAKE_ERPS`) to minimize expensive WoW API calls within a single button press (`SM_Extend_Druid.lua` -- the `catAtk()` entry point)

## Authentication & Identity

**Auth Provider:**
- Not applicable. Runs entirely client-side within the WoW addon sandbox. No authentication required beyond the WoW client login.
- User identity is derived from the WoW client's `UnitName("player")` and `UnitClass("player")` APIs.

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry, no crash reporter)
- Lua errors bubble up to the WoW client's default error handler, which displays to the user
- `pcall` wrapping is used for the periodic update handler to prevent one task from breaking others (`battle_event_queue.lua:193`)

**Logs:**
- Debug output via `macroTorch.show()` -> `DEFAULT_CHAT_FRAME:AddMessage()` (`interface_debug.lua:79-92`)
- Color-coded messages: white (default), red (errors), yellow (warnings), blue (info), green (success)
- No file logging, no log levels, no log rotation

**Debug Utilities:**
- `macroTorch.showAllActions()` -- Dump all action bar slots (`interface_debug.lua:44-58`)
- `macroTorch.showAllActionProps()` -- Dump action properties (`interface_debug.lua:29-41`)
- `obj.listBuffs()` / `obj.listDebuffs()` -- Unit buff/debuff enumeration (`Unit.lua:74-94`)
- `macroTorch.listAllSpells(bookType)` -- Spell book dump (`biz_util.lua:57-67`)
- `macroTorch.listTargetDebuffs(t)` / `macroTorch.listTargetBuffs(t)` -- Target buff/debuff listing (`Target.lua:241-275`)

## CI/CD & Deployment

**Hosting:**
- Not applicable (client-side addon). The generated `SM_Extend.lua` is manually placed in the WoW addon directory.
- Distribution: Manual or via addon packager for Turtle WoW players.

**CI Pipeline:**
- None. No CI/CD configuration detected.
- Build is manual: run `./build.sh` locally, then copy to game directory.

**Version Control:**
- Git repository (local only, no remote configured as a standard origin detected)
- `.gitignore` includes: `SM_Extend.lua` (build output), `.idea/` (IDE config), `.claude-reference/`, `CLAUDE.md`, `.codegraph/`

## Environment Configuration

**Required external files (for the addon to function):**
- `SM_Extend.lua` must be present in `Interface/AddOns/SuperMacro/` within the Turtle WoW directory
- SuperMacro addon must be installed and enabled

**No environment variables.** The addon does not use environment variables, `.env` files, or any external configuration mechanism. All settings are hardcoded in the Lua source.

**Secrets location:**
- No secrets. This is a client-side addon with no authentication, no API keys, no credentials.

## Webhooks & Callbacks

**Incoming:**
- None. The addon does not listen for external network events.
- All input comes from WoW game events via `frame:RegisterEvent()`.

**Outgoing:**
- None. The addon does not make network calls.
- Output is limited to in-game actions (spell casts, item usage, chat messages).

## Integration Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        WoW Client Process                        │
│                                                                  │
│  ┌─────────────────────┐    ┌──────────────────────────────┐    │
│  │   SuperMacro Addon   │    │     macro-torch Addon        │    │
│  │  (Macro executor)    │◄───│  SM_Extend.lua (generated)   │    │
│  │                      │    │                              │    │
│  │  Persists:           │    │  macro_torch.lua             │    │
│  │  SM_EXTEND.* tables  │    │  impl_util.lua               │    │
│  └─────────────────────┘    │  interface_debug.lua          │    │
│                              │  Unit.lua                    │    │
│  ┌─────────────────────┐    │  Player.lua / Target.lua     │    │
│  │   SuperWoW (optional)│    │  Pet.lua                     │    │
│  │  UnitXP()            │    │  SM_Extend_Druid.lua         │    │
│  │  UNIT_CASTEVENT      │    │  SM_Extend_Hunter.lua ...    │    │
│  │  Extended UnitExists │    │  battle_event_queue.lua      │    │
│  └─────────────────────┘    │  event_stack.lua              │    │
│                              │  texture_map.lua              │    │
│  ┌─────────────────────┐    │  Group.lua / Raid.lua         │    │
│  │ TWT Addon (optional) │    └──────────┬───────────────────┘    │
│  │  TWT.threats table   │               │                        │
│  └─────────────────────┘               │                        │
│                                         ▼                        │
│                           ┌──────────────────────────┐          │
│                           │   WoW 1.12.1 Lua C API    │          │
│                           │  (Unit*, CastSpell*,      │          │
│                           │   UseAction*, GetTime,    │          │
│                           │   CreateFrame, events)    │          │
│                           └──────────────────────────┘          │
└──────────────────────────────────────────────────────────────────┘
```

**Data Flow Summary:**
1. **Input:** WoW game events (`SPELLCAST_START`, `PLAYER_REGEN_DISABLED`, `CHAT_MSG_COMBAT_SELF_MISSES`, etc.) flow into `macroTorch.eventHandle()` in `battle_event_queue.lua`
2. **State:** Combat state is tracked in `macroTorch.context` (per-combat) and `macroTorch.loginContext` (per-session)
3. **Decision:** Class-specific rotation logic (e.g., `macroTorch.catAtk()` in `SM_Extend_Druid.lua`) reads game state and decides actions
4. **Output:** Actions are dispatched via WoW API calls (`CastSpell`, `CastSpellByName`, `UseContainerItem`, `UseAction`)
5. **Persistence:** Immunity data persists across sessions via `SM_EXTEND.*` global tables managed by SuperMacro

---

*Integration audit: 2026-06-06*