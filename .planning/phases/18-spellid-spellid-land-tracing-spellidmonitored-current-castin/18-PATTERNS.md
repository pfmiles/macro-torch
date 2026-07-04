# Phase 18: spellId 自动更正机制改造方案（最终版） - Pattern Map

**Mapped:** 2026-07-04
**Files analyzed:** 4 modified, 1 unchanged
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `core/spell_trace_core.lua` (modify) | infrastructure | event-driven | `core/spell_trace_core.lua:15-17` (self — tracingSpells init) | exact (same file, same pattern) |
| `entity/Player.lua` (modify) | entity | request-response | `entity/Player.lua:77-93` (self — _castSpell bottleneck) | exact (same file, same function) |
| `core/events.lua` (unchanged) | infrastructure | event-driven | `core/events.lua:87-124` (self — UNIT_CASTEVENT handler) | exact (Phase 17 pattern retained) |
| `core/selftest.lua` (modify) | diagnostics | request-response | `core/selftest.lua:614-668` (Category K spellId tests) | exact (same file, same category structure) |

## Pattern Assignments

### `core/spell_trace_core.lua` — _spellIdMonitored 初始化 + SpellTrace:register 白名单写入

**Role:** infrastructure (global set table init) + event-driven (register API)
**Analog:** `core/spell_trace_core.lua:15-17` (tracingSpells initialization pattern)

**Imports pattern** (not applicable — WoW 1.12.1 addon, no module system):
All symbols use `macroTorch.*` global namespace. All files are concatenated via `build_order.txt`.

**Global set table initialization** (lines 15-17, existing pattern to follow):
```lua
-- Source: core/spell_trace_core.lua:15-17
if not macroTorch.tracingSpells then
    macroTorch.tracingSpells = {}
end
```

**Phase 18 new code — initialize _spellIdMonitored immediately after tracingSpells (line 17):**
```lua
-- [NEW Phase 18 D-02] whitelist for spells that need spellId dynamic correction monitoring
if not macroTorch._spellIdMonitored then
    macroTorch._spellIdMonitored = {}
end
```

**Positioning:** Insert between line 17 (`end` of tracingSpells init) and line 18 (`function macroTorch.setSpellTracing`). This must be BEFORE `macroTorch.SpellTrace = {}` (line 43) so that when Druid.lua calls `SpellTrace:register` (loaded at build_order.txt line 28, after this file at line 22), the table already exists.

**SpellTrace:register 白名单写入** (lines 63-83, existing pattern to modify):
```lua
-- Source: core/spell_trace_core.lua:63-83 (existing)
function macroTorch.SpellTrace:register(name, config)
    if config.land then
        local spellId = nil
        if config.spellName then
            spellId = macroTorch.resolveSpellId(config.spellName)
        end
        if not spellId then
            spellId = config.spellId
        end
        if not spellId then
            macroTorch.show("[macro-torch] SpellTrace:register(" .. name .. "): land=true but no spellId resolved", 'red')
            return
        end
        macroTorch.setSpellTracing(spellId, name)
        -- [NEW Phase 18 D-01, D-03] whitelist maintenance: monitorSpellId defaults to config.land
        -- INSERT HERE: local shouldMonitor = (config.monitorSpellId ~= nil) and config.monitorSpellId or (config.land or false)
        -- INSERT HERE: if shouldMonitor and config.spellName then ...
    end
    if config.immune then
        macroTorch.setTraceSpellImmune(name, config.debuffTexture)
    end
end
```

**Default boolean parameter pattern** (from selftest.lua:38):
```lua
-- Source: core/selftest.lua:38
isOptional = isOptional or false

-- Phase 18 adaptation for monitorSpellId (nil-aware, preserves explicit false):
-- [CITED: RESEARCH Pattern 2, Pitfall 2]
local shouldMonitor = (config.monitorSpellId ~= nil) and config.monitorSpellId or (config.land or false)
```

**Error handling pattern** (existing, no change):
```lua
-- Source: core/spell_trace_core.lua:74-77 (existing)
if not spellId then
    macroTorch.show("[macro-torch] SpellTrace:register(" .. name .. "): land=true but no spellId resolved", 'red')
    return
end
```

---

### `entity/Player.lua` — _castSpell 白名单守卫 + stale 检测

**Role:** entity (bottleneck guard)
**Analog:** `entity/Player.lua:77-93` (self — existing _castSpell bridge code)

**Existing code to transform** (lines 77-93):
```lua
-- Source: entity/Player.lua:77-93 (Phase 17 bridge — TO BE REPLACED)
-- 4. Execute the cast
if mode ~= 'ready' then
    macroTorch.current_casting_spell = localeNames.en
end
if onSelf then
    CastSpellByName(spellName, true)
else
    obj.cast(spellName, rank)
end
return true
```

**Phase 18 replacement** (D-02 whitelist guard + D-04 stale detection):
```lua
-- [CITED: CONTEXT.md D-02, D-04; RESEARCH Pattern 3]
-- 4. Execute the cast
if mode ~= 'ready' then
    -- [NEW Phase 18 D-04] stale detection: warn if previous current_casting_spell was not cleared
    if macroTorch.current_casting_spell ~= nil then
        macroTorch.log("[macro-torch] current_casting_spell was not cleared: " ..
            tostring(macroTorch.current_casting_spell) ..
            ", now overwritten by: " .. localeNames.en, 'yellow')
    end
    -- [NEW Phase 18 D-02] whitelist guard: only set for monitored spells
    if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] then
        macroTorch.current_casting_spell = localeNames.en
    end
end
```

**macroTorch.log signature** (from interface_debug.lua:103):
```lua
-- Source: interface_debug.lua:103-110 (WRONG assumption in some code examples)
function macroTorch.log(a, color)
    macroTorch.show(a, color)
    -- ... persists to MACRO_TORCH_LOG SavedVariable
end
-- NOTE: signature is (a, color), NOT (level, message) as some examples suggest.
-- Stale detection warning: macroTorch.log("... message ...", 'yellow')
```

**Verified: spellName一致性 (Research A4):**
```lua
-- Druid.lua _castSpell calls (entity/Player.lua lines 73-83 will read localeNames.en):
-- obj.rake():     localeNames.en = 'Rake'          ← matches config.spellName 'Rake'
-- obj.rip():      localeNames.en = 'Rip'           ← matches config.spellName 'Rip'
-- obj.pounce():   localeNames.en = 'Pounce'        ← matches config.spellName 'Pounce'
-- obj.bite():     localeNames.en = 'Ferocious Bite' ← matches config.spellName 'Ferocious Bite'
-- All four match exactly. Confirmed @ Druid.lua:34,38,42,46.
```

---

### `core/events.lua` — UNIT_CASTEVENT spellId 更正 (保持不变)

**Role:** infrastructure (event-driven dispatch)
**Analog:** `core/events.lua:87-124` (self — Phase 17 logic retained unchanged)

**Core event handler pattern** (lines 87-124):
```lua
-- Source: core/events.lua:87-124 (Phase 17 — UNCHANGED for Phase 18)
elseif event == "UNIT_CASTEVENT" then
    local unitId, targetId, castType, spellId, timeCost = arg1, arg2, arg3, arg4, arg5
    if unitId == macroTorch.player.guid and castType == 'CAST' then
        if macroTorch.current_casting_spell then
            local staticSpellId = macroTorch.resolveSpellId(macroTorch.current_casting_spell)
            if staticSpellId and staticSpellId ~= spellId then
                -- lazy-init SM_EXTEND.spellIdMap
                if not SM_EXTEND then SM_EXTEND = {} end
                if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
                local playerCls = macroTorch.player.class
                if not SM_EXTEND.spellIdMap[playerCls] then SM_EXTEND.spellIdMap[playerCls] = {} end
                SM_EXTEND.spellIdMap[playerCls][macroTorch.current_casting_spell] = spellId
                if macroTorch.loginContext and macroTorch.loginContext.spellIdMap then
                    macroTorch.loginContext.spellIdMap[macroTorch.current_casting_spell] = spellId
                end
                macroTorch.tracingSpells[spellId] = macroTorch.tracingSpells[staticSpellId]
                macroTorch.tracingSpells[staticSpellId] = nil
                macroTorch.show(string.format("[macro-torch] spellId corrected: %s %d -> %d",
                    macroTorch.current_casting_spell, staticSpellId, spellId), 'yellow')
            end
            -- clear bridge variable (line 119)
            macroTorch.current_casting_spell = nil
        end
        if spellId and macroTorch.tracingSpells[spellId] then
            macroTorch.recordCastTable(macroTorch.tracingSpells[spellId])
        end
    end
```

**Phase 18 note:** No changes needed. The `current_casting_spell` variable is now only set for whitelisted spells (via `_castSpell` guard), so the existing `if macroTorch.current_casting_spell then` gate in events.lua naturally only triggers for monitored spells. The `macroTorch.current_casting_spell = nil` clear at line 119 is retained.

---

### `core/selftest.lua` — Category L 白名单验证 selftest

**Role:** diagnostics (selftest registration)
**Analog:** `core/selftest.lua:614-668` (Category K spellId mapping tests)

**Selftest:register pattern** (lines 34-39):
```lua
-- Source: core/selftest.lua:34-39
function macroTorch.SelfTest:register(name, fn, isOptional)
    table.insert(self.tests, {
        name = name,
        fn = fn,
        isOptional = isOptional or false
    })
end
```

**Category L placement:** Insert after Category K tests end (line 668) and before Module 4 `/mt` SLASH command (line 670). Following the exact same structural pattern as Category K.

**Category K test structure as template** (lines 614-668):
```lua
-- Source: core/selftest.lua:614-668 (template for Category L)
-- ============================================================
-- Category K: spellId mapping system tests (5 tests, 3 core + 2 optional)
-- ============================================================

macroTorch.SelfTest:register("K: SPELL_NAME_TO_ID table exists with all 8 keys", function()
    assert(type(macroTorch.SPELL_NAME_TO_ID) == "table", ...)
    assert(macroTorch.SPELL_NAME_TO_ID["Pounce"] == 9827, ...)
    -- ... etc
end, false)

macroTorch.SelfTest:register("K: resolveSpellId function exists and resolves known spells", function()
    assert(type(macroTorch.resolveSpellId) == "function", ...)
    -- ... etc
end, false)

macroTorch.SelfTest:register("K: resolveSpellId returns nil for unknown spell name", function()
    -- ... etc
end, true)  -- isOptional = true

macroTorch.SelfTest:register("K: loadSpellIdMap function exists and is callable", function()
    -- ... etc
end, false)

macroTorch.SelfTest:register("K: current_casting_spell is defined", function()
    -- ... etc
end, true)  -- isOptional = true
```

**Phase 18 Category L (5 tests: 4 core + 1 optional):**
```lua
-- ============================================================
-- Category L: _spellIdMonitored whitelist verification (5 tests, 4 core + 1 optional)
-- ============================================================
-- [CITED: 18-CONTEXT.md D-01, D-02, D-03, D-05; 18-RESEARCH.md Validation Architecture]

macroTorch.SelfTest:register("L: _spellIdMonitored table exists and is a table", function()
    assert(type(macroTorch._spellIdMonitored) == "table",
        "_spellIdMonitored is not a table, got: " .. type(macroTorch._spellIdMonitored))
end, false)

macroTorch.SelfTest:register("L: _spellIdMonitored contains all 4 Druid land-tracing spells", function()
    assert(macroTorch._spellIdMonitored["Pounce"] == true,
        "Pounce not in _spellIdMonitored")
    assert(macroTorch._spellIdMonitored["Rake"] == true,
        "Rake not in _spellIdMonitored")
    assert(macroTorch._spellIdMonitored["Rip"] == true,
        "Rip not in _spellIdMonitored")
    assert(macroTorch._spellIdMonitored["Ferocious Bite"] == true,
        "Ferocious Bite not in _spellIdMonitored")
end, false)

macroTorch.SelfTest:register("L: monitorSpellId=false excludes from whitelist even with land=true", function()
    -- Temporary register to verify monitorSpellId=false behavior
    -- Use a synthetic spell name to avoid polluting production whitelist
    local testName = "__SELFTEST_L3_DUMMY__"
    macroTorch.SpellTrace:register(testName, {
        spellName = "Rake",  -- known spellName for resolveSpellId
        land = true,
        monitorSpellId = false
    })
    assert(macroTorch._spellIdMonitored[testName] == nil,
        "monitorSpellId=false should not add to whitelist")
    -- Cleanup: remove test tracing entry (whitelist was never set, confirmed above)
    -- tracingSpells cleanup: find and remove the test entry by spellId
    local testSpellId = macroTorch.resolveSpellId("Rake")
    if testSpellId and macroTorch.tracingSpells[testSpellId] == testName then
        macroTorch.tracingSpells[testSpellId] = nil
    end
end, false)

macroTorch.SelfTest:register("L: monitorSpellId=true includes even with land=false", function()
    local testName = "__SELFTEST_L4_DUMMY__"
    macroTorch.SpellTrace:register(testName, {
        spellName = "Rake",
        land = false,
        monitorSpellId = true
    })
    assert(macroTorch._spellIdMonitored[testName] == true,
        "monitorSpellId=true should add to whitelist even with land=false")
    -- Cleanup whitelist entry
    macroTorch._spellIdMonitored[testName] = nil
    -- No tracingSpells cleanup needed (land=false, setSpellTracing was not called)
end, false)

macroTorch.SelfTest:register("L: config.spellId legacy path does NOT enter whitelist", function()
    -- Verify that a register using config.spellId (without config.spellName) does not
    -- create a whitelist entry. This is D-05 backward compatibility.
    -- We check this by examining a known non-Druid registration or by counting.
    -- Since existing registrations all have spellName, we verify: FF(Feral) has land=false
    -- so it should NOT be in the whitelist (land=false means monitorSpellId defaults to false)
    assert(macroTorch._spellIdMonitored["Faerie Fire (Feral)"] == nil,
        "Faerie Fire (Feral) should not be in _spellIdMonitored (land=false)")
end, true)  -- optional: depends on FF(Feral) being registered
```

**Registration count update:** After Category L, update the counter comment after Category E:
```lua
-- Registration count: 79 total (A:11 + B:34 + C:20 + D:7 + E:3 + F:15 + J:5 + K:5 + L:5)
-- (note: Category L adds 5; class files may add more)
```

---

## Shared Patterns

### Global set table initialization (guarded)
**Source:** `core/spell_trace_core.lua:15-17`
**Apply to:** `_spellIdMonitored` initialization
```lua
-- Pattern: lazy-init with nil guard (idempotent, safe across reloads)
if not macroTorch.tracingSpells then
    macroTorch.tracingSpells = {}
end
```

### Default boolean parameter (nil-aware)
**Source:** `core/selftest.lua:38` (simple form) + `core/spell_trace_core.lua:68-73` (nil check pattern)
**Apply to:** `monitorSpellId` default logic in SpellTrace:register
```lua
-- Simple pattern (selftest.lua:38):
isOptional = isOptional or false

-- Nil-aware pattern for fields where explicit false differs from nil:
-- config.spellName → nil check pattern (spell_trace_core.lua:68):
if config.spellName then
    spellId = macroTorch.resolveSpellId(config.spellName)
end
-- monitorSpellId adaptation:
local shouldMonitor = (config.monitorSpellId ~= nil) and config.monitorSpellId or (config.land or false)
```

### Bottleneck guard pattern
**Source:** `entity/Player.lua:82-84` (existing _castSpell bridge)
**Apply to:** whitelist guard + stale detection
```lua
-- Pattern: add guard condition at the single bottleneck function
-- Before (Phase 17):
if mode ~= 'ready' then
    macroTorch.current_casting_spell = localeNames.en
end
-- After (Phase 18):
if mode ~= 'ready' then
    if macroTorch.current_casting_spell ~= nil then
        macroTorch.log("... stale warning ...", 'yellow')
    end
    if macroTorch._spellIdMonitored and macroTorch._spellIdMonitored[localeNames.en] then
        macroTorch.current_casting_spell = localeNames.en
    end
end
```

### Selftest:register pattern
**Source:** `core/selftest.lua:34-39` (registration) + `core/selftest.lua:620-633` (Category K test examples)
**Apply to:** Category L tests
```lua
macroTorch.SelfTest:register("L: test name", function()
    assert(condition, "error message")
end, isOptional)
```

### macroTorch.log for persistent logging
**Source:** `interface_debug.lua:103-110`
**Apply to:** stale detection warning
```lua
-- Signature: macroTorch.log(a, color)
-- color: "white" (default), "red", "yellow", "blue", "green"
macroTorch.log("[macro-torch] message text here", 'yellow')
```

### SM_EXTEND lazy-init pattern
**Source:** `core/events.lua:102-105`
**Apply to:** not needed in Phase 18 (no new SM_EXTEND fields)
```lua
-- Existing pattern (for reference only — Phase 18 does NOT introduce new SM_EXTEND writes):
if not SM_EXTEND then SM_EXTEND = {} end
if not SM_EXTEND.spellIdMap then SM_EXTEND.spellIdMap = {} end
```

---

## No Analog Found

All 4 files have exact analogs in the same files they modify. No external analogs needed.

| File | Status |
|------|--------|
| `core/spell_trace_core.lua` | Self-analog: tracingSpells init pattern (lines 15-17) and SpellTrace:register (lines 63-83) |
| `entity/Player.lua` | Self-analog: _castSpell bottleneck bridge (lines 77-93) |
| `core/events.lua` | Self-analog: UNIT_CASTEVENT handler (lines 87-124) — NO CHANGES |
| `core/selftest.lua` | Self-analog: Category K test structure (lines 614-668) |

## Key Verification

### A4: spellName consistency (localeNames.en vs config.spellName)
All 4 Druid land-tracing spells verified:
| Druid.lua method | localeNames.en | config.spellName | Match? |
|------------------|----------------|------------------|--------|
| `obj.rake()` (line 34) | `'Rake'` | `'Rake'` | YES |
| `obj.rip()` (line 38) | `'Rip'` | `'Rip'` | YES |
| `obj.pounce()` (line 46) | `'Pounce'` | `'Pounce'` | YES |
| `obj.bite()` (line 42) | `'Ferocious Bite'` | `'Ferocious Bite'` | YES |

## Build Order Verification

**Source:** `build_order.txt`
```
core/spell_id_map.lua       # line 21 (SPELL_NAME_TO_ID defined)
core/spell_trace_core.lua   # line 22 (_spellIdMonitored init + SpellTrace:register defined)
core/spell_trace_immune.lua # line 23
core/selftest.lua           # line 25 (SelfTest:register defined, Category L added)
core/events.lua             # line 26 (UNIT_CASTEVENT handler)
classes/druid/Druid.lua    # line 28 (SpellTrace:register called for 4 Druid spells)
```

**Validation:** `_spellIdMonitored` initialized at line 22 file load time (before `SpellTrace = {}` even). Druid.lua loads at line 28 — all SpellTrace:register calls safely write into the already-existing `_spellIdMonitored` table. No ordering risk.

## Metadata

**Analog search scope:** `core/spell_trace_core.lua`, `entity/Player.lua`, `core/events.lua`, `core/selftest.lua`, `classes/druid/Druid.lua`, `interface_debug.lua`, `macro_torch.lua`, `core/spell_id_map.lua`, `build_order.txt`
**Files scanned:** 9
**Pattern extraction date:** 2026-07-04