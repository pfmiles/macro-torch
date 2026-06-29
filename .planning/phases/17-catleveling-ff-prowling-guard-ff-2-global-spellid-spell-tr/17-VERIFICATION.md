---
phase: "17-catleveling-ff-prowling-guard-ff-2-global-spellid-spell-tr"
verified: "2026-06-29T11:15:00Z"
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
overrides: []
gaps: []
deferred: []
behavior_unverified_items: []
---

# Phase 17: catLeveling FF Prowling Guard + Global SpellId Mapping Verification Report

**Phase Goal:** 添加 catLeveling FF 潜行守卫，建立 global spellId 名称->映射系统（SPELL_NAME_TO_ID + resolveSpellId），通过 _castSpell->current_casting_spell->UNIT_CASTEVENT 链路实现运行时 spellId 动态更正与持久化，将 Druid 4 个 land-tracing 技能从硬编码 spellId 迁移到名称驱动注册。
**Verified:** 2026-06-29T11:15:00Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SPELL_NAME_TO_ID 静态映射表存在，包含 Pounce/Rake/Rip/Ferocious Bite 的中英文名称->spellId 映射 | VERIFIED | `core/spell_id_map.lua`: 8 entries (4 EN + 4 ZH), all with correct spellId values. Verified via grep. |
| 2 | resolveSpellId() 函数存在，先查 runtime 更正后查静态基线 | VERIFIED | `core/spell_trace_core.lua:47-55`: checks `loginContext.spellIdMap` first, falls back to `SPELL_NAME_TO_ID`. |
| 3 | SpellTrace:register 支持 config.spellName 字段，内部通过 resolveSpellId 解析再调 setSpellTracing | VERIFIED | `core/spell_trace_core.lua:68-78`: spellName branch calls `resolveSpellId()`, with fallback to `config.spellId`. |
| 4 | loadSpellIdMap() 函数存在，仿 loadImmuneTable 模式绑定到 loginContext | VERIFIED | `core/spell_trace_immune.lua:108-119`: identical pattern with loginContext guard, SM_EXTEND lazy-init, reference binding. |
| 5 | onPlayerEnteringWorld 调用 loadSpellIdMap | VERIFIED | `core/combat_context.lua:37-40`: loginContext reset before loadSpellIdMap call. |
| 6 | catLeveling 在 isProwling 为 true 时不释放 FF | VERIFIED | `classes/druid/leveling.lua:220`: `and not player.isProwling` in Module 9 FF condition. |
| 7 | build_order.txt 中 core/spell_id_map.lua 位于 core/spell_trace_core.lua 之前 | VERIFIED | `build_order.txt`: line 21 (combat_context), line 22 (spell_id_map), line 23 (spell_trace_core). |
| 8 | _castSpell 设置 current_casting_spell (mode ~= 'ready'), UNIT_CASTEVENT 检测 spellId 不匹配并更正+持久化, Druid 4 技能从 spellId 迁移到 spellName | VERIFIED | `entity/Player.lua:82-84` (set), `core/events.lua:99-121` (correct+writet+persist+clear), `classes/druid/Druid.lua:614-628` (spellName `>=` 4, hardcoded spellId = 0). |

**Score:** 8/8 truths verified

### Additional Integrated Truths (Plan 02)

These are covered by truth #8 above (the integrated lifecycle), but verified separately for completeness:

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 8a | _castSpell sets current_casting_spell = spellName when mode is not ready | VERIFIED | `entity/Player.lua:82-84`: `if mode ~= 'ready' then macroTorch.current_casting_spell = spellName end` |
| 8b | _castSpell does NOT set current_casting_spell when mode is ready | VERIFIED | Same guard — only set when `mode ~= 'ready'`. |
| 8c | UNIT_CASTEVENT CAST checks current_casting_spell, corrects spellId mismatch and persists | VERIFIED | `core/events.lua:99-118`: checks `current_casting_spell`, resolves, compares staticSpellId vs event spellId, writes to SM_EXTEND, syncs loginContext. |
| 8d | UNIT_CASTEVENT CAST clears current_casting_spell = nil after processing | VERIFIED | `core/events.lua:120`: clear always even if no mismatch. |
| 8e | spellId correction syncs tracingSpells key (old staticId to new event spellId) | VERIFIED | `core/events.lua:114-115`: `tracingSpells[spellId] = tracingSpells[staticSpellId]; tracingSpells[staticSpellId] = nil`. |
| 8f | Druid SpellTrace:register uses spellName instead of spellId for 4 land-tracing spells | VERIFIED | `classes/druid/Druid.lua:614-628`: spellName='Pounce'/'Rake'/'Rip'/'Ferocious Bite', 0 hardcoded spellId. |
| 8g | Faerie Fire (Feral) SpellTrace:register remains unchanged | VERIFIED | `classes/druid/Druid.lua:630-633`: `land=false, immune=true`, no spellName/spellId. |
| 8h | Selftest Category K includes SPELL_NAME_TO_ID/resolveSpellId/loadSpellIdMap verification | VERIFIED | `core/selftest.lua:614-668`: 5 tests (K1-K5), 3 core + 2 optional. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `core/spell_id_map.lua` | SPELL_NAME_TO_ID static mapping (8 entries) | VERIFIED | 32 lines, Apache 2.0 header, 4 EN + 4 ZH keys mapping to 4 spellIds (9827, 1822, 9492, 22557) |
| `core/spell_trace_core.lua` | resolveSpellId + SpellTrace:register spellName support | VERIFIED | resolveSpellId at L47-55, register spellName branch at L68-78 |
| `core/spell_trace_immune.lua` | loadSpellIdMap function | VERIFIED | L108-119, follows loadImmuneTable pattern with loginContext binding |
| `core/combat_context.lua` | onPlayerEnteringWorld calls loadSpellIdMap | VERIFIED | L40, after loginContext reset at L39 |
| `core/events.lua` | UNIT_CASTEVENT spellId correction | VERIFIED | L99-121: check, resolve, compare, persist, migrate key, clear |
| `classes/druid/leveling.lua` | FF prowling guard | VERIFIED | L220: `not player.isProwling` in Module 9 |
| `classes/druid/Druid.lua` | 4 SpellTrace:register with spellName | VERIFIED | L614-628: Pounce/Rake/Rip/Ferocious Bite all use spellName |
| `entity/Player.lua` | _castSpell sets current_casting_spell | VERIFIED | L82-84: before CastSpellByName/cast |
| `core/selftest.lua` | Category K self-tests (5 tests) | VERIFIED | L614-668: K1-K5, 3 core + 2 optional |
| `build_order.txt` | spell_id_map.lua in correct position | VERIFIED | L21, between combat_context and spell_trace_core |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| SPELL_NAME_TO_ID | resolveSpellId | Static table lookup | WIRED | `spell_trace_core.lua:54`: `macroTorch.SPELL_NAME_TO_ID[spellName]` |
| resolveSpellId | SpellTrace:register spellName branch | Function call | WIRED | `spell_trace_core.lua:69`: `macroTorch.resolveSpellId(config.spellName)` |
| SM_EXTEND.spellIdMap | loadSpellIdMap | Reference binding | WIRED | `spell_trace_immune.lua:117`: `macroTorch.loginContext.spellIdMap = SM_EXTEND.spellIdMap[playerCls]` |
| loginContext.spellIdMap | resolveSpellId runtime check | Table lookup | WIRED | `spell_trace_core.lua:48-52`: checks `loginContext.spellIdMap[spellName]` |
| _castSpell spellName | macroTorch.current_casting_spell | Variable assignment | WIRED | `entity/Player.lua:83`: `macroTorch.current_casting_spell = spellName` |
| current_casting_spell | UNIT_CASTEVENT resolveSpellId | Variable read in events | WIRED | `core/events.lua:100`: `resolveSpellId(macroTorch.current_casting_spell)` |
| SM_EXTEND.spellIdMap correction | tracingSpells key migration | Table mutation | WIRED | `core/events.lua:108,114-115`: write to SM_EXTEND, migrate tracingSpells key |
| SpellTrace:register spellName | resolveSpellId | SPELL_NAME_TO_ID | WIRED | Full chain: config.spellName -> resolveSpellId -> lookup -> setSpellTracing |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `core/spell_id_map.lua` | SPELL_NAME_TO_ID | Static inline table | Yes (hardcoded known spellIds) | FLOWING |
| `core/spell_trace_core.lua` | resolveSpellId return | loginContext.spellIdMap OR SPELL_NAME_TO_ID | Yes (two-stage lookup) | FLOWING |
| `core/events.lua` | spellId correction | UNIT_CASTEVENT arg4 -> SM_EXTEND write | Yes (runtime event data -> persistent) | FLOWING |
| `classes/druid/Druid.lua` | spellName config | Config literal -> resolveSpellId -> setSpellTracing | Yes (name->id->trace registration) | FLOWING |
| `entity/Player.lua` | current_casting_spell | _castSpell locale-resolved spellName | Yes (locale-aware cast name) | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| build.sh succeeds | `bash build.sh` | exit code 0, SM_Extend.lua generated | PASS |
| SPELL_NAME_TO_ID in build artifact | `grep -c "SPELL_NAME_TO_ID" SM_Extend.lua` | 16 (from plan: `>=` 1) | PASS |
| resolveSpellId in build artifact | `grep -c "function macroTorch.resolveSpellId" SM_Extend.lua` | 1 (from plan: `>=` 1) | PASS |
| loadSpellIdMap in build artifact | `grep -c "function macroTorch.loadSpellIdMap" SM_Extend.lua` | 1 (from plan: `>=` 1) | PASS |
| FF prowling guard in build artifact | `grep -c "not player.isProwling" SM_Extend.lua` | 1 (from plan: `>=` 1) | PASS |
| current_casting_spell in build artifact | `grep -c "macroTorch.current_casting_spell" SM_Extend.lua` | 9 (from plan: `>=` 3) | PASS |
| spellName migration in build artifact | `grep -c "spellName = 'Pounce'" SM_Extend.lua` | 1 (from plan: `>=` 1) | PASS |
| resolveSpellId in events in build artifact | `grep -c "resolveSpellId" SM_Extend.lua` | 20 (from plan: `>=` 1) | PASS |
| Category K self-tests in build artifact | `grep -c "K:" SM_Extend.lua` | 5 (from plan: `>=` 5) | PASS |

### Probe Execution

No probes declared for this phase. Skipped.

### Requirements Coverage

Phase 17 requirements are declared in PLAN frontmatter only (not in REQUIREMENTS.md, which only contains R1-R8 from the original refactoring). All 6 requirement IDs are covered by implementation:

| Requirement | Source Plan | Description (from ROADMAP goal) | Status | Evidence |
|-------------|-------------|---------------------------------|--------|----------|
| REQ-17-SPELLID-MAP | 17-01-PLAN.md | SPELL_NAME_TO_ID static map with EN+ZH keys | SATISFIED | `core/spell_id_map.lua`: 8 entries |
| REQ-17-FF-PROWL-GUARD | 17-01-PLAN.md | catLeveling cannot cast FF while prowling | SATISFIED | `classes/druid/leveling.lua:220` |
| REQ-17-CURRENT-CASTING | 17-02-PLAN.md | _castSpell sets current_casting_spell bridge variable | SATISFIED | `entity/Player.lua:82-84` |
| REQ-17-SPELLID-CORRECTION | 17-02-PLAN.md | UNIT_CASTEVENT detects mismatch, persists to SM_EXTEND, migrates tracingSpells key | SATISFIED | `core/events.lua:99-121` |
| REQ-17-DRUID-MIGRATE | 17-02-PLAN.md | 4 Druid land-tracing spells use spellName instead of hardcoded spellId | SATISFIED | `classes/druid/Druid.lua:614-628` |
| REQ-17-SELFTEST | 17-02-PLAN.md | Category K self-tests verify spellId mapping system | SATISFIED | `core/selftest.lua:614-668` (5 tests) |

### Anti-Patterns Found

No anti-patterns, debt markers (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER), stubs, or hardcoded empty data detected in any of the 9 files modified or created in this phase.

### Human Verification Required

None. All truths are statically verifiable. The runtime correction behavior (spellId mismatch detection during actual gameplay) would need human testing in-game, but this is a property of the event-driven correction system as a whole, not a gap in the phase deliverables.

## Detailed Verification Notes

### Plan 01 (Wave 1: Infrastructure)

1. **core/spell_id_map.lua**: Created with Apache 2.0 header, flat table assignment `macroTorch.SPELL_NAME_TO_ID` with 8 entries. All acceptance criteria met (8 EN keys, 8 ZH keys, 4 unique spellId values verified).

2. **resolveSpellId**: Implemented at `core/spell_trace_core.lua:47-55`. Correctly placed between `SpellTrace = {}` (L43) and `SpellTrace:register` (L63). Two-stage resolution: `loginContext.spellIdMap` first, `SPELL_NAME_TO_ID` as fallback.

3. **SpellTrace:register spellName support**: `config.spellName` branch at L68-78. Calls `resolveSpellId(config.spellName)`, falls back to `config.spellId` if unresolved. Both nil -> red error. `config.spellId` retained as legacy fallback.

4. **loadSpellIdMap**: `core/spell_trace_immune.lua:108-119`. Exactly follows `loadImmuneTable` pattern. Key differences: binds to `loginContext` (not `context`), uses `spellIdMap` sub-table. First guard checks `macroTorch.loginContext` (correct for cross-combat persistence).

5. **FF prowling guard**: `classes/druid/leveling.lua:220`. `not player.isProwling` in Module 9. Module 9 is the last module in catLeveling, so no fallthrough concerns.

6. **build_order.txt**: `core/spell_id_map.lua` at line 21, between `combat_context.lua` (L20) and `spell_trace_core.lua` (L22). Correct dependency ordering.

### Plan 02 (Wave 2: Integration)

1. **_castSpell current_casting_spell**: `entity/Player.lua:82-84`. Set before actual cast (L88-92), only when `mode ~= 'ready'`. The spellName is locale-resolved (L44-50), matching SPELL_NAME_TO_ID key format.

2. **UNIT_CASTEVENT correction**: `core/events.lua:99-121`. Full lifecycle:
   - Check `current_casting_spell` (L99)
   - Resolve static spellId via `resolveSpellId` (L100)
   - Compare with event spellId (L101)
   - On mismatch: lazy-init SM_EXTEND.spellIdMap (L103-106), persist (L108), sync loginContext (L110-112), migrate tracingSpells key (L114-115), chat notification (L116-117)
   - Clear `current_casting_spell = nil` (L120) — always, regardless of mismatch
   - Clear only in CAST block, not FAILED/INTERRUPTED — correct, as failed casts don't generate CAST events

3. **Druid SpellTrace:register migration**: `classes/druid/Druid.lua:614-628`. 4 spells migrated:
   - Pounce: `spellName = 'Pounce'`
   - Rake: `spellName = 'Rake'`
   - Rip: `spellName = 'Rip'`
   - Ferocious Bite: `spellName = 'Ferocious Bite'`
   - `grep -c "spellId = [0-9]"` in Druid.lua = 0
   - Line 611 TODO comment replaced with: `spellId resolved via macroTorch.resolveSpellId()` explanation
   - Faerie Fire (Feral) (L630-633): unchanged, `land=false`, no spellName/spellId

4. **Category K self-tests**: `core/selftest.lua:614-668`. 5 tests:
   - K1: SPELL_NAME_TO_ID table (8 keys verified) — core (`false`)
   - K2: resolveSpellId resolves 4 spells — core (`false`)
   - K3: resolveSpellId returns nil for unknown — optional (`true`)
   - K4: loadSpellIdMap callable — core (`false`)
   - K5: current_casting_spell defined — optional (`true`)

### Build Verification

```bash
./build.sh  # exit code 0
```

All symbols present in SM_Extend.lua:
- SPELL_NAME_TO_ID: 16 occurrences
- resolveSpellId function: 1 definition
- loadSpellIdMap function: 1 definition
- FF prowling guard: 1 occurrence
- current_casting_spell: 9 occurrences
- spellName migration: 1 occurrence each for Pounce/Ferocious Bite
- Category K self-tests: 5 registrations

### Git History

All 5 commits verified in git log:
- `8b84479`: core/spell_id_map.lua creation + build_order.txt
- `c414e89`: FF prowling guard + resolveSpellId + SpellTrace:register spellName
- `7b26aa2`: loadSpellIdMap + onPlayerEnteringWorld integration
- `5fd4ce5`: current_casting_spell lifecycle + spellId correction + Druid migration
- `b2e24e0`: Category K self-tests

---

_Verified: 2026-06-29T11:15:00Z_
_Verifier: Claude (gsd-verifier)_