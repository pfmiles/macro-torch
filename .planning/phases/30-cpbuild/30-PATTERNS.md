# Phase 30: cpBuild 双保判定改造 - Pattern Map

**Mapped:** 2026-09-10
**Files analyzed:** 8 (6 modified/pattern-source + 1 created + 1 created-test-surface)
**Analogs found:** 8 / 8
**Research:** skipped by standing user decision — file list extracted from 30-CONTEXT.md only.

## Line-Number Note

CONTEXT.md canonical_refs carry approximate ranges. This map gives the **actual current line numbers** (verified by direct read on this date); planners must use the numbers here, not the CONTEXT approximations. Druid.lua has grown since the quick-era refs: cpBuildLogSample is now 348-364 (not 344), cpBuildLogEvent 369-371, wrappers 25-58, D-06 note 64-74, comboPoints accessor 441-443.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `classes/druid/Druid.lua` (modify) | model/instrumentation (class impl + cpBuild family) | event-driven sampling (cast wrappers) + periodic polling (new 0.1s DKI task) | itself: wrappers 25-58, cpBuildLogSample/Event 348-371; registration call-site shape from `entity/Target.lua:158` | exact |
| `macro_torch.lua` (pattern source; modification only if a new tunable is surfaced — D-01 keeps the switch unchanged) | config | load-time (nil-guard re-arm) | itself: 22-28, 56-59, 69-98 | exact |
| `core/periodic.lua` (framework, read-only) | framework (periodic task scheduler) | timer-driven periodic | itself: 98-149 + call site `entity/Target.lua:158` | exact |
| `core/events.lua` (modify: insert DKI reset calls into two EXISTING branches; zero new RegisterEvent) | middleware/event router | event-driven | itself: 73-81, 90-93; gated-dispatch precedent 130-140 | exact |
| `interface_debug.lua` (read-only channel) | utility (persistent logging) | write-through dual channel | itself: macroTorch.log 106-124 | exact |
| `classes/druid/cat.lua` (read-only context only; NOT modified per D-06/范围锚定) | model/service (decision tree) | request-response (clickContext decisions) | itself: tryBiteKillShot 214-223, safeBite 441-443, readyBite 444-451 | context-only |
| `classes/druid/selftest.lua` (modify: new Category S-05+ per D-13) | test registration | batch (boot-time suite) | in-file Category S (1326-1421) + `core/selftest.lua` register framework 34-40 | exact |
| `tools/cpbuild.lua` (CREATE) | utility (offline CLI analyzer) | file-I/O + batch transform + CLI | `tools/cpdamage.lua` (entire harness, route-A self-contained copy) | paradigm (copy) |

## Pattern Assignments

### 1. `classes/druid/Druid.lua` (modify — DKI state machine + poll task land here)

The cpBuild family already lives in this file; the DKI (D-04/D-05) is a Druid-only cpBuild addition and belongs beside cpBuildLogSample/cpBuildLogEvent. No new file is implied by CONTEXT.

**Wrapper short-circuit gate shape the DKI must mirror** (lines 25-58; D-01: `cpBuildLog and ... or nil`, zero API calls when off):

```lua
function obj.claw(mode, rank)
    local cpLog = macroTorch.cpBuildLog and macroTorch.cpBuildLogSample() or nil
    local cpDmg = macroTorch.cpDamageLog and macroTorch.cpDamageSample('claw', macroTorch.computeClaw_E()) or nil
    local cast = obj._castSpell({ en = 'Claw', zh = '爪击' }, mode, nil, macroTorch.computeClaw_E, false, rank)
    if cast and cpLog and cpLog.gcdOk then
        macroTorch.cpBuildLogEvent('Claw', cpLog)
    end
    ...
end
```
(identical shape in `obj.shred` 38-49 and `obj.rake` 51-58 — rake has no cpDmg leg)

**D-06 range-lock note + bite wrapper** (lines 64-74 — read-only, this is why the DKI gets its anchor from the cp down-jump instead of a bite line):

```lua
function obj.ferocious_bite(mode, rank)
    -- cpDamage only here: the cpBuild log range stays Claw/Shred/Rake forever
    -- (D-06 range lock), while the 35 is the hardcoded BITE_E threshold
    -- constant (combo.lua:62), passed as a literal with no function reference.
    local cpDmg = macroTorch.cpDamageSample('bite', 35)
    ...
```

**cpBuildLogSample — the pre-cast snapshot** (comment 344-347, function 348-364). Note the warn-once diagnostic idiom and `GetTime()` usage; DKI reuses both shapes (`GetComboPoints()` + warn-once pattern):

```lua
function macroTorch.cpBuildLogSample()
    local gcdOk = macroTorch.player.isActionCooledDown('Ability_Druid_Rake')
    -- WR-01: isActionCooledDown returns nil (not false) when the Rake texture is
    -- absent from all action bars ... Warn once per session ...
    if gcdOk == nil and not macroTorch._cpBuildLogProbeWarned then
        macroTorch._cpBuildLogProbeWarned = true
        macroTorch.show('[cpBuild] GCD probe failed: put the Rake spell on an action bar, otherwise no casts will be logged', 'yellow')
    end
    return {
        t = GetTime(),
        cp = macroTorch.player.comboPoints,
        e = macroTorch.player.mana,
        gcdOk = gcdOk
    }
end
```

**cpBuildLogEvent — the fixed-line emitter** (lines 366-371). The new `[cpBuildT]` emitter is a sibling function with the same shape, gated by D-01 at the call site:

```lua
-- Emit one persisted [cpBuild] line per accepted Claw/Shred/Rake cast.
-- The field order skill t cp e is fixed; offline tooling parses it for the
-- inter-cast interval k and its window distribution (R2 locked).
function macroTorch.cpBuildLogEvent(skillName, s)
    macroTorch.log('[cpBuild] ' .. skillName .. ' t=' .. s.t .. ' cp=' .. s.cp .. ' e=' .. s.e)
end
```

**comboPoints accessor — what the DKI polls** (lines 439-443; D-05 names it `GetComboPoints() or 0`):

```lua
macroTorch.DRUID_FIELD_FUNC_MAP = {
    -- basic props
    ['comboPoints'] = function(self)
        return GetComboPoints() or 0
    end,
```

**Cheap-first gate ordering for the poll tick** — `cpDamageSample` (lines 379-418) is the in-file precedent for "switch off = zero cost, then hard gates" and its comments mandate the gate order; the DKI tick starts with `if not macroTorch.cpBuildLog then return end` (no lines emitted when off, D-01):

```lua
function macroTorch.cpDamageSample(skillToken, energyCost)
    if not macroTorch.cpDamageLog then
        return nil
    end
    if not macroTorch.toBoolean(macroTorch.target.isCanAttack and string.find(macroTorch.target.name, 'Training Dummy')) then
        return nil
    end
    ...
```

**0.1s task registration call-site shape** — static load-time registration, no dynamic register/unregister (D-05 allows "不注册/空转"; static registration + in-tick gate is the project's existing shape), from `entity/Target.lua:158`:

```lua
macroTorch.registerPeriodicTask('maintainTHV', { interval = 0.1, task = macroTorch.maintainTHV })
```
(second in-tree example: `core/spell_trace_core.lua:389` — `registerPeriodicTask('maintainLandTables', { interval = 0.1, task = macroTorch.maintainLandTables })`)

**In-file selftest registration precedent** (Druid.lua 1449-1459): new Category S-05+ registrations could live here or in `classes/druid/selftest.lua`; Category S already lives in the latter, so follow that home (see assignment 7).

### 2. `macro_torch.lua` (config — pattern source for D-01 gating)

**nil-guard boolean flag pattern** (lines 22-28 — the DKI reads this flag; never re-assign it here):

```lua
-- combo-point building cast log switch (quick 260907-0ya): false by default, set
-- macroTorch.cpBuildLog = true in game (SuperMacro body) to record every accepted
-- Claw/Shred/Rake cast through macroTorch.log for offline interval analysis.
-- The nil-guard re-arms the default on every login; toggling mid-session needs no reload.
if macroTorch.cpBuildLog == nil then
    macroTorch.cpBuildLog = false
end
```

**Per-login re-arm of warn-once flags** (lines 56-63 — if the DKI introduces its own warn-once flag, mirror this block):

```lua
macroTorch._cpBuildLogProbeWarned = nil
...
macroTorch._cpDamageProbeWarned = nil
```

**CONFIG_OPTIONS registry** (lines 69-98; cpBuildLog entry 70-77). D-01 keeps the switch unchanged — a new entry is only needed if the planner surfaces a new tunable (none required by D-01..D-14; the offline 30s link-break threshold in D-08 is a file-header constant of `tools/cpbuild.lua`, NOT a game option):

```lua
macroTorch.CONFIG_OPTIONS = {
    {
        name = 'macroTorch.cpBuildLog',
        default = false,
        desc = 'combo-point build cast log switch (Claw/Shred/Rake interval samples)',
        cmd = '/run macroTorch.cpBuildLog=true',
        get = function() return macroTorch.cpBuildLog end,
    },
    ...
```

### 3. `core/periodic.lua` (framework, read-only — task registration API surface)

**Frame constants incl. leastUpdateInterval** (lines 98-105):

```lua
local frame = CreateFrame("Frame")
frame.lastUpdate = 0
frame.leastUpdateInterval = 0.1
if not macroTorch.periodicTasks then
    macroTorch.periodicTasks = {}
end
```

**Scheduler core** (lines 107-138 — the 0.1s DKI poll is a plain `{ interval = 0.1, task = ... }` entry with no `times` cap, i.e. `times == nil` runs forever):

```lua
function macroTorch.onPeriodicUpdate()
    local expired = {}
    for name, task in pairs(macroTorch.periodicTasks) do
        if GetTime() - frame.lastUpdate >= task.interval then
            if not task.times or task.times > 0 then
                if task.times then
                    task.times = task.times - 1
                end
                task.task()
            else
                table.insert(expired, name)
            end
        end
    end
    ...
end

function macroTorch.registerPeriodicTask(name, task)
    macroTorch.periodicTasks[name] = task
end

function macroTorch.removePeriodicTask(name)
    macroTorch.periodicTasks[name] = nil
end

function macroTorch.setRepeat(name, interval, times, func)
    macroTorch.registerPeriodicTask(name, { interval = interval, times = times, task = func })
end
```

**pcall-guarded OnUpdate driver** (lines 140-149) — error in one task must not kill the frame loop; DKI tick follows the same contract.

### 4. `core/events.lua` (modify — DKI global reset joins EXISTING branches; no new RegisterEvent, per 范围锚定)

**Registration surface stays frozen** (lines 23-40). Do NOT add `RegisterEvent` calls; only the handler body changes.

**PLAYER_TARGET_CHANGED branch — the DKI reset joins here** (lines 73-81). Existing shape: nils context keys when target changes in combat; the DKI reset call is one more line inside the `if macroTorch.player.isInCombat and macroTorch.target.isCanAttack` block (or beside it — planner decides exact placement, but the niling idiom is the pattern):

```lua
elseif event == 'PLAYER_TARGET_CHANGED' then
    -- target changed
    if macroTorch.player.isInCombat and macroTorch.target.isCanAttack then
        if macroTorch.context then
            macroTorch.context.ffTimer = nil
            macroTorch.context.targetHealthVector = nil
        end
        macroTorch.show('Target change in combat!')
    end
```

**PLAYER_REGEN_ENABLED → onCombatExit branch — the second DKI reset hook** (lines 90-93):

```lua
elseif event == 'PLAYER_REGEN_ENABLED' then
    macroTorch.onCombatExit()
elseif event == 'PLAYER_REGEN_DISABLED' then
    macroTorch.onCombatEnter()
```

**Gated-dispatch-inside-existing-handler precedent** (lines 130-140) — the phase-28 cpDamage gate inside `RAW_COMBATLOG` shows exactly the "insert a cheap-first gated dispatch into an existing branch, touch nothing else" technique the DKI resets replicate:

```lua
elseif event == "RAW_COMBATLOG" then
    if macroTorch.cpDamageLog and arg1 == 'CHAT_MSG_SPELL_SELF_DAMAGE' and arg2 then
        macroTorch.onCpDamageLine(arg2, GetTime())
    end
    ...
```

**Supplementary: onCombatExit body** (`core/combat_context.lua` 21-27) — note it replaces `macroTorch.context` with a fresh table (line 24). If the DKI window state lives on `macroTorch.context` it is auto-cleared on combat exit, which matches D-04 旁路 2's "脱战回 WAIT_ANCHOR"; if it lives elsewhere (e.g. a dedicated `macroTorch.cpBuildState`), the events.lua hook must clear it explicitly. Planners must fix the state home before writing the hook.

### 5. `interface_debug.lua` (read-only channel — `[cpBuildT]` lines flow through macroTorch.log)

**macroTorch.log — dual write + trim cap** (lines 106-124):

```lua
function macroTorch.log(a, color)
    -- 防御性守卫：即使 SavedVariables 加载在文件执行之后覆盖了 MACRO_TORCH_LOG，
    -- 也能保证首次调用 log 时重新初始化（与文件顶部的守卫互为双保险）
    if not MACRO_TORCH_LOG then
        MACRO_TORCH_LOG = { messages = {}, maxSize = 500 }
    end
    macroTorch.show(a, color)
    local messages = MACRO_TORCH_LOG.messages
    local n = tonumber(macroTorch.LOG_MAX_SIZE)
    local limit = n and math.max(1, math.floor(n)) or 500
    while macroTorch.tableLen(messages) >= limit do
        table.remove(messages, 1)
    end
    table.insert(messages, tostring(a))
end
```
D-06 output lines (`[cpBuildT] ok t=<sec>` / `[cpBuildT] fail`) call this with no color argument; the offline script sees them as plain message-ring entries.

### 6. `classes/druid/cat.lua` (read-only context — bite semantics feeding the DKI cp down-jump design)

**tryBiteKillShot** (lines 214-223) — the kill-shot path bites at ANY cp > 0, which is exactly the low-cp bite that produces a BUILDING-state cp down-jump (旁路 1):

```lua
function macroTorch.tryBiteKillShot(clickContext)
    if macroTorch.isKillShotOrLastChance(clickContext) then
        if clickContext.comboPoints > 0 then
            macroTorch.player.ferocious_bite('raw')
        else
            -- 如果当前没星的话也只能做普通攻击
            macroTorch.regularAttack(clickContext)
        end
    end
end
```

**safeBite / readyBite** (lines 441-451) — the `'ready'`-mode gate stack the 5cp bite goes through (also the `ok` window terminator the DKI samples on):

```lua
function macroTorch.safeBite(clickContext)
    return macroTorch.player.mana >= clickContext.BITE_E and macroTorch.readyBite(clickContext)
end
function macroTorch.readyBite(clickContext)
    if macroTorch.player.isSpellReady('Ferocious Bite') and macroTorch.isGcdOk(clickContext) and macroTorch.isNearBy(clickContext) then
        macroTorch.player.ferocious_bite('ready')
        macroTorch.show('Bite at energy: ' .. macroTorch.player.mana .. ', ooc: ' .. tostring(clickContext.ooc))
        return true
    end
    return false
end
```

**Also relevant** (context): `cp5Bite` 118-156 (5cp + Rip-present/immune/fast → discharge then bite; the canonical bite-after-full-build path whose T̄ the DKI measures) and `quickKeepRip` 337-349 (cp >= 3 quick-bite — another low-cp bite source). CONTEXT's "safeBite 214-222" reference was approximate; the function lives at 441-443 with tryBiteKillShot at 214-223.

### 7. `classes/druid/selftest.lua` (modify — Category S-05+ per D-13, CR-01 stub discipline)

**Category S header + the CR-01 discipline contract** (lines 1326-1329):

```lua
-- Category S: cpBuildLog combo-point cast logging (quick 260907-0ya, 4 tests)
-- S-03/S-04 follow the CR-01 stub discipline: snapshot via rawget, install
-- own-key shadows, capture into locals, restore via raw assignment BEFORE
-- any assert.
```

**S-03 — the canonical full-discipline shape the S-05+ tests replicate** (lines 1349-1387; restore happens BEFORE the asserts at 1383+):

```lua
macroTorch.SelfTest:register("Cat S-03: claw() logs only when switch on and GCD ready", function()
    local player = macroTorch.player
    local savedSwitch = macroTorch.cpBuildLog
    local savedLog = macroTorch.log
    local savedCast = rawget(player, '_castSpell')
    local savedActionCd = rawget(player, 'isActionCooledDown')
    local captured = {}
    local nOn, nGcd, nOff = 0, 0, 0
    macroTorch.log = function(a)
        table.insert(captured, tostring(a))
    end
    player._castSpell = function()
        return true
    end
    player.isActionCooledDown = function()
        return true
    end
    local pcallRes = pcall(function()
        macroTorch.cpBuildLog = true
        player.claw('ready')
        nOn = macroTorch.tableLen(captured)
        ...
    end)
    rawset(player, '_castSpell', savedCast)
    rawset(player, 'isActionCooledDown', savedActionCd)
    macroTorch.log = savedLog
    macroTorch.cpBuildLog = savedSwitch
    assert(pcallRes, "S-03 pcall failed")
    assert(nOn == 1, ...)
    ...
end, true)
```

D-13 extends this to **globals** `GetComboPoints` / `GetTime` / `macroTorch.log`: the discipline generalizes to `local savedGCP = GetComboPoints; GetComboPoints = function() return X end` … restore `GetComboPoints = savedGCP` before any assert (same snapshot → shadow → restore-before-assert order; no rawget needed for plain globals).

**Registration-count footer discipline** — the file ends each category with a count comment; update on the S-05+ addition (file tail):

```lua
	-- Registration count: Category U adds 9 tests (phase 28-02)
end
```
Sibling precedent mid-file: `-- Registration count: Category S adds 4 tests (quick 260907-0ya + WR-01 fix)` (1423).

**Framework side** (`core/selftest.lua` 34-40): `macroTorch.SelfTest:register(name, fn, isOptional)` with `isOptional = isOptional or false` — S-05+ tests register with trailing `true`, exactly like every Category S entry.

### 8. `tools/cpbuild.lua` (CREATE — route-A self-contained copy of `tools/cpdamage.lua`)

**Paradigm:** `tools/cpdamage.lua` (1364 lines, git-tracked). Route A (D-07) = copy the harness functions verbatim, then swap the recognition/parsing/statistics layers for the cpBuild family. Do not touch cpdamage.lua.

**File header + Lua 5.0 dialect contract** (cpdamage.lua 17-26 — replicate this comment block; D-15/D-10):

```lua
-- offline analyzer for macroTorch [cpDamage] entries (phase 28, plan 03).
-- ...
-- Lua 5.0 dialect (D-15): no length operator, no table-form string.gsub
-- replacement, no %q JSON output, math mod via the % operator, args read
-- straight off the arg table. Self-contained, no external dependencies.
```

**Header constants + flag literal trick** (28-37 — learn the double-hyphen concatenation rule; new script adds `BREAK_THRESHOLD = 30` (D-08 断链阈值, 文件头常量), PREFIXes `[cpBuild] ` / `[cpBuildT] `, MAX_FILE_BYTES / MAX_ENTRIES kept):

```lua
local MAX_FILE_BYTES = 32 * 1024 * 1024
local MAX_ENTRIES = 50000
local PREFIX = '[cpDamage] '

-- flag literals are spelled via concatenation so no string in this file
-- contains an adjacent hyphen pair (the parenthesis gate strips line
-- comments before short strings, so an in-string double hyphen would eat
-- the rest of its line and trip the bracket balance)
local FLAG_SELFTEST = '-' .. '-selftest'
local FLAG_JSON_OUT = '-' .. '-json-out'
```

**Harness functions to replicate verbatim (exact line ranges):**
- `countList` 42-48 (ipairs count; no `#` operator)
- `readAll` 51-65 (io.open, 32MB DoS ceiling)
- `lineNumberOf` 68-80 (error-report helper)
- `extractMacroTorchLog` 95-199 (signature `extractMacroTorchLog(text)` → block or `nil, err`; the four-surface brace-walk state machine with its own comment contract 82-95)
- `loadBlockSandboxed` 207-236 (`load_chunk = loadstring or load` at 205; `setfenv` guard; empty env sandbox)
- `getMessages` 246-269 (returns `{ ok = true, messages = messages }` package or `{ ok = false, reason = }` — friendly empty-log note exits 0)
- `decodeJson` 280-524 — **only needed if the new script emits JSON-out**; D-08 requires `--json-out` so copy it and `encodeScalar` 527-564 / `encodeValue` 566-601 for the archive
- `runSelftest` 1129-1259 (the `check(cond, label)` helper, in-file fixture via `line()` + `DQ = string.char(34)` escaping at 1139/1164-1167, exit-1 on fail / ALL PASSED banner + exit 0)
- `printUsage` 1262-1267, `main(arg)` 1274-1364 (CLI arg-loop: selftest flag, json-out flag with path, single sv path; call `main(arg)` at 1364)

**`[cpBuild]` lines in the cpdamage fixture — the precedent the new parsing builds on** (lines 1177-1181 + checks 1189-1193). cpdamage treats the cpBuild-family line as a non-matching prefix → skipped silently; cpbuild.lua inverts this: `[cpBuild]`/`[cpBuildT]` lines are the PRIMARY input with a new terse space-separated parser (no JSON body), and everything else is skipped:

```lua
    fix = fix .. line(8, '[cpDamage] ' .. body('bite', 445, false, 35, 85, 1, true, true, 5, 121.0, 3000))
    fix = fix .. line(9, '[cpDamage] {"spell":"claw","dmg":210,')
    fix = fix .. line(10, '[cpBuild] Claw t=1.0 cp=2 e=55')
    fix = fix .. '\t},\n}\n'
    ...
    check(pack ~= nil and pack.ok and countList(pack.messages) == 10,
        'fixture message count is 10')
    local pr = parseEntries(pack.messages)
    check(countList(pr.entries) == 8, 'fixture yields 8 valid entries')
    check(pr.badLines == 1, 'fixture yields exactly 1 bad line')
```
The new script's fixture embeds real `[cpBuild]` (`Claw t=... cp=... e=...`) and `[cpBuildT]` (`ok t=...` / `fail`) lines through the same `line(n, raw)` helper. The recognition-chain shape comes from `parseEntries` 675-719 (prefix check via `string.sub(line, 1, prefixLen) == PREFIX`, bad-lines counter, pcall-guarded body decode, entry cap) — the cpBuild version replaces `decodeJson` with a fixed-field tokenizer honoring the field-order contract fixed in Druid.lua 366-370. Dropped lines feed the D-08 `dropped`/badLines statistic.

## Shared Patterns

### 1. cpBuildLog gate (D-01) — applies to: DKI tick + `[cpBuildT]` emitter
**Source:** `classes/druid/Druid.lua` 26/39/52 (`macroTorch.cpBuildLog and macroTorch.cpBuildLogSample() or nil`); cheap-first variant `cpDamageSample` 379-382 (`if not macroTorch.cpBuildLog then return nil end`). Switch definition and nil-guard: `macro_torch.lua` 22-28.

### 2. Persistent output channel (D-06) — applies to: `[cpBuildT]` emitter
**Source:** `interface_debug.lua` 106-124 (`macroTorch.log`), called exactly like `cpBuildLogEvent` at `Druid.lua` 369-371.

### 3. 0.1s periodic task (D-05) — applies to: DKI poll
**Source:** `core/periodic.lua` 127-129 (API), 98-105 (constants), 140-149 (pcall driver); load-time static registration call sites `entity/Target.lua:158` and `core/spell_trace_core.lua:389`.

### 4. Global reset hooks (D-05 旁路 2) — applies to: DKI state reset
**Source:** `core/events.lua` 73-81 (PLAYER_TARGET_CHANGED niling idiom) and 90-93 (PLAYER_REGEN_ENABLED → `macroTorch.onCombatExit()`); hard state clearing via context-table swap in `core/combat_context.lua` 21-27.

### 5. CR-01 stub discipline (D-13) — applies to: all Category S-05+ selftests
**Source:** `classes/druid/selftest.lua` 1349-1387 (rawget snapshot → own-key shadow → capture → rawset/assign restore BEFORE any assert); `macroTorch.log` capture variant 1335-1347; registration via `core/selftest.lua` 34-40 with `isOptional=true`.

### 6. Lua 5.0 discipline (D-10/D-15) — applies to: every touched/new file
**Sources:** `tools/cpdamage.lua` 24-26 (dialect contract) + 39-41 (countList instead of `#`) + 32-37 (flag literal concatenation); project convention per MEMORY note "wow-lua50-syntax" (no `#` length operator, no goto/label; self-verification must run against 5.0 on Windows+Cygwin).

### 7. In-game selftest boot registration — applies to: any in-file Category S-05+ added to Druid.lua instead of druid/selftest.lua
**Source:** `classes/druid/Druid.lua` 1454-1459 (first G1 registration with `isOptional=true`).

## No Analog Found

Files or constructs with no exact in-tree match — planner builds these from CONTEXT.md decisions plus the closest partial analogs listed:

| Construct | Closest Partial Analog | Reason |
|-----------|------------------------|--------|
| `[cpBuild]`/`[cpBuildT]` terse space-separated line parser (D-08) | `tools/cpdamage.lua` parseEntries recognition chain 675-719 | cpdamage parses JSON bodies under a prefix; the cpBuild family uses fixed `skill t= cp= e=` / `ok t=` / `fail` fields — combine the chain shape with a new tokenizer honoring the field-order contract at `Druid.lua` 366-370 |
| DKI three-state cp-down-jump state machine (D-04) | `core/periodic.lua` onPeriodicUpdate 107-125 (per-tick pure-function dispatch); `Druid.lua` cpDamageSample gate order 379-418; `core/events.lua` niling idiom 73-81 | No in-tree state machine with t0/t1 bookkeeping exists; implement as a pure tick function + a small state table, per CONTEXT D-04 |

## Metadata

**Analog search scope:** `classes/druid/`, `core/`, `entity/`, `tools/`, `interface_debug.lua`, `macro_torch.lua` (read-only; only 30-PATTERNS.md was written).
**Files scanned:** 12 (Druid.lua, cat.lua, periodic.lua, events.lua, interface_debug.lua, macro_torch.lua, cpdamage.lua, druid/selftest.lua, core/selftest.lua, Target.lua, combat_context.lua, spell_trace_core.lua)
**Tracked-source gate:** every analog path verified with `git ls-files --` (all tracked; no gitignored mirrors used). Nested submodule check not applicable.
**Pattern extraction date:** 2026-09-10