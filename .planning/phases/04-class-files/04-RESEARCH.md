# Phase 04: class-files (职业文件重组 + 构建系统收尾) - Research

**Researched:** 2026-06-09
**Domain:** Lua codebase file reorganization, shell build system hardening
**Confidence:** HIGH

## Summary

Phase 4 is a pure code reorganization phase: split a 1870-line Druid class file across 4 files in a new `classes/druid/` directory, move 6 other class files into `classes/`, update the build order manifest, and switch the build shell script from fault-tolerant to strict mode. No logic changes to any function bodies. No external package installations.

All functions are `macroTorch.*` global namespace -- splitting files does not change visibility. Build order in `build_order.txt` guarantees definition before call. The entire operation is an atomic single-commit switch: create all new files, update build artifacts, verify build, delete old files.

**Primary recommendation:** Execute the Druid split by copy-pasting exact line ranges (not manual editing), verify with `./build.sh` after each major step, and use the CONTEXT.md D-01 boundary decisions as the authoritative function-to-file assignment.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Druid class definition + metatable | classes/druid/Druid.lua | -- | Constructor, FIELD_FUNC_MAP, registerPlayerClass |
| Shared Druid helpers (energy calc, combat decision) | classes/druid/Druid.lua | -- | Cross-form functions used by both cat and bear |
| SpellTrace + SelfTest registrations | classes/druid/Druid.lua | -- | Registration calls execute at file load time, must be in first-loaded file |
| Cat form combat rotation (catAtk + 13 modules) | classes/druid/cat.lua | -- | Cat-only execution path |
| Bear form combat rotation (bearAtk + 7 modules) | classes/druid/bear.lua | -- | Bear-only execution path |
| Druid buffs / control / pokemonLoad | classes/druid/utility.lua | -- | Utility functions not directly in combat hot path |
| Non-Druid class files | classes/*.lua (top-level) | -- | Single-file classes, pure rename |
| Build order manifest | build_order.txt | -- | Declarative, controls file concatenation order |
| Build script | build.sh | -- | Shell executor, switches from tolerant to strict |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| R6 | classes/ 目录：Druid 拆 4 文件 + 6 职业迁移到 classes/ | Standard Stack covers directory structure and migration strategy; Architecture Patterns covers split boundaries and build order rules |
| R8 | Druid 猫德逻辑保持：所有函数行为完全不变 | Split strategy is copy-paste by line ranges, no logic edits; verification pattern confirms all 9+ key functions present in output |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash (sh) | 3.2.57 (macOS system) | Build script executor | Already in use; no change for phase 4 |
| git | 2.49.0 | Version control, `git mv` for file moves | Standard; `git mv` preserves file history for non-Druid renames |
| Lua | 5.4.7 (dev machine) | Syntax validation only | Not required for production; dev-time optional check |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| shellcheck | NOT INSTALLED | Shell script static analysis | Optional; would catch build.sh errors but not required |
| wc -l | macOS built-in | Line count verification | Used to verify split file sizes match targets |

**No package installations needed.** This phase is pure code reorganization with zero external dependencies.

## Architecture Patterns

### System Architecture Diagram

```
build_order.txt (manifest)
       │
       ▼
build.sh ──► reads build_order.txt line by line
       │       (strict mode: exits on missing file)
       │
       ▼
────────────────────────────────────────
  Concatenation order (Phase 4 final):
────────────────────────────────────────
  1. macro_torch.lua          ── namespace init
  2. impl_util.lua            ── utilities
  3. biz_util.lua             ── business utils
  4. core/class.lua           ── classMetatable factory
  5. core/periodic.lua        ── periodic task scheduler
  6. entity/Unit.lua          ── base Unit class ─────┐
  7. entity/Player.lua        ── Player class         │ entity/ layer
  8. entity/Target.lua        ── Target class         │ (inheritance chain)
  9. entity/Pet.lua           ── Pet class            │
  10-13. entity/TargetTarget, TargetPet, PetTarget, Group, Raid
 14. texture_map.lua          ── texture mapping
 15. interface_debug.lua      ── debug output
 16. core/combat_context.lua  ── combat enter/exit
 17. core/spell_trace_core.lua
 18. core/spell_trace_immune.lua
 19. core/selftest.lua        ── self-test framework
 20. core/events.lua          ── event frame + self-test trigger
───────────────── CLASSES ─────────────────
 21. classes/druid/Druid.lua  ── Druid: class + shared + registration
 22. classes/druid/cat.lua    ── Druid: cat form (depends on 21)
 23. classes/druid/bear.lua   ── Druid: bear form (depends on 21)
 24. classes/druid/utility.lua── Druid: buff/control/items (depends on 21)
 25. classes/Hunter.lua       ── Hunter class
 26. classes/Mage.lua         ── Mage class
 27. classes/Priest.lua       ── Priest class
 28. classes/Rogue.lua        ── Rogue class
 29. classes/Warlock.lua      ── Warlock class
 30. classes/Warrior.lua      ── Warrior class
────────────────────────────────────────
       │
       ▼
  SM_Extend.lua (generated output, gitignored)
```

### Pattern 1: Copy-Paste Split by Line Ranges

**What:** Druid file split is performed by extracting exact line ranges from `SM_Extend_Druid.lua` into 4 target files. No content editing within functions -- the only cuts happen at function boundaries (between `end` and `function` keywords).

**When to use:** Always for this phase. This is the safest approach since all functions are independent `macroTorch.*` global namespace entries.

**Example:**
```lua
-- Source: SM_Extend_Druid.lua lines 1-1172 (Druid.lua: constructor + shared helpers + registration)
-- Source: SM_Extend_Druid.lua lines 1173-1481 (cat.lua: catAtk + 13 modules)
-- Source: SM_Extend_Druid.lua lines 1482-1650 (bear.lua: bear helpers + modules)
-- Source: SM_Extend_Druid.lua lines 1651-1870 (utility.lua: druidBuffs + control + pokemonLoad)
-- Note: approximate line numbers; see Line Range Audit below for precise boundaries
```

### Pattern 2: Atomic Commit Strategy

**What:** All changes in a single commit with this order:
1. `mkdir -p classes/druid` (create directory structure)
2. Create all 10 target files (4 Druid + 6 non-Druid)
3. Update `build_order.txt` (remove 7 SM_Extend_* lines, add 4 `classes/druid/` lines with snake_case, add 6 `classes/` lines)
4. Update `build.sh` (fault-tolerant -> strict mode)
5. `./build.sh` (verify builds green)
6. `git rm` all 7 `SM_Extend_*.lua` files
7. `./build.sh` (verify builds green again)
8. `git add` + commit as single atomic unit

**Why atomic:** D-02 requirement. No intermediate state where bisect would see half-migrated code.

### Pattern 3: build_order.txt Path Correction

**What:** The current `build_order.txt` has Phase 4 future paths using PascalCase directory (`classes/Druid.lua`, `classes/Druid/cat.lua`). Per D-03, these must be changed to snake_case directory (`classes/druid/Druid.lua`, `classes/druid/cat.lua`).

**Lines to change: 35-38** (future entries with wrong casing)
**Lines to remove: 26-33** (current SM_Extend_* entries and their comment)

### Anti-Patterns to Avoid

- **Don't manually retype functions:** Copy-paste line ranges from the original file. Any manual retyping risks introducing errors that break R8.
- **Don't rearrange functions within files:** D-01 specifies that function-to-file assignment is locked. Don't move a function from cat.lua to Druid.lua or vice versa beyond what's decided.
- **Don't change any function body:** This phase is pure reorganization. No logic edits (except the Hunter TODO comment per D-04).
- **Don't use `git mv` for Druid:** The Druid file is being split (not renamed), so `git mv` doesn't apply. Only the 6 non-Druid files use `git mv`.
- **Don't leave old `SM_Extend_*.lua` files during bisect:** The atomic commit ensures no intermediate commit has duplicate definitions. Two defs of `macroTorch.Druid:new()` would break the build.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File splitting | Manual function-by-function editing | Line range extraction (sed/editor range select) | Eliminates transcription errors |
| File renaming | `mv` + `git add` | `git mv` | Preserves git history for non-Druid files |
| Build order verification | Manual inspection | `grep` line count assertions | Automated verification prevents ordering mistakes |
| Lua syntax validation | Wait for in-game test | `lua -p file.lua` (lint) | Catches syntax errors before build, though doesn't catch runtime errors |

**Key insight:** The biggest risk in this phase is an off-by-one line range error during Druid split that truncates a function or misses an `end`. Using editor line-range operations (not manual copy-paste of text) is the mitigation.

## Druid Line Range Audit

Exact function-to-file assignment based on CONTEXT.md D-01 and source code analysis of `SM_Extend_Druid.lua` (1870 lines). Line numbers verified against current file as of 2026-06-09.

### classes/druid/Druid.lua (~500-550 lines, target)

| Lines | Content | Functions |
|-------|---------|-----------|
| 1-15 | Apache 2.0 license header | -- |
| 16-17 | Comment + class declaration | `macroTorch.Druid = macroTorch.Player:new()` |
| 19-253 | Constructor + DRUID_FIELD_FUNC_MAP | `macroTorch.Druid:new()`, all field functions |
| 254-255 | Instance creation + class registration | `macroTorch.druid = ...`, `registerPlayerClass("DRUID", ...)` |
| 308-372 | Relic selection functions | `computeNormalRelic`, `selectFerocityOrEmeraldRot`, `recoverNormalRelic` |
| 390-480 | Energy computation functions | `computeClaw_E`, `computeShred_E`, `computeRake_E`, `computeRake_Duration`, `computeTiger_E`, `computeTiger_Duration`, `computeRake_Erps`, `computeRip_Erps`, `computePounce_Erps` |
| 482-503 | SpellTrace registrations | 5x `SpellTrace:register()` calls |
| 506-537 | Battle event consumer | `consumeDruidBattleEvents` |
| 539-583 | shouldUseShred | `shouldUseShred` (cross-form: used by both cat and bear logic paths) |
| 599-614 | Battle type detection | `isTrivialBattleOrPvp`, `isTrivialBattle` (used by shared helpers) |
| 616-624 | HP restore check | `combatUrgentHPRestore` |
| 626-637 | Fight start detection | `isFightStarted` |
| 767-830 | Kill shot prediction | `isKillShotOrLastChance` |
| 851-882 | Energy computation | `computeErps` |
| 908-936 | FF during wait window | `shouldCastFFDuringWaitWindow` |
| 938-968 | Minimum ability cost | `getMinimumAffordableAbilityCost` |
| 979-998 | Rip casting decision | `shouldCastRip` |
| 1000-1022 | Bite decision | `shouldUseBite` |
| 1110-1115 | Proximity check | `isNearBy` |
| 1127-1242+ | Buff/debuff status checks | `isTigerPresent`, `tigerLeft`, `isRipPresent`, `ripLeft`, `isRakePresent`, `rakeLeft`, `isFFPresent`, `ffLeft`, `isDemoralizingRoarPresent`, `isPouncePresent`, `pounceLeft` |
| 1339-1344 | GCD check | `isGcdOk` (used by both cat and bear safe functions) |
| 1359-1371 | Cross-form FF cast | `safeFF` |
| 1385-1398 | Tiger GCD tracking | `tigerSelfGCD` (used by both cat and bear) |
| 1752-1870 | SelfTest registrations | 25x `SelfTest:register()` calls |

### classes/druid/cat.lua (~900-1000 lines)

| Lines | Content | Functions |
|-------|---------|-----------|
| 257-307 | burstMod (rush mod) | `burstMod` |
| 586-597 | Regular attack entry | `regularAttack` |
| 639-667 | OT module | `otMod` |
| 669-674 | Term module entry | `termMod` |
| 675-706 | CP5 bite | `cp5Bite` |
| 708-726 | Energy discharge before bite | `energyDischargeBeforeBite` |
| 728-765 | OOC module | `oocMod` |
| 832-841 | Kill shot bite | `tryBiteKillShot` |
| 843-849 | Reshift module entry | `reshiftMod` |
| 884-906 | Reshift decision | `shouldDoReshift` |
| 970-977 | Tiger Fury module | `keepTigerFury` |
| 1024-1035 | Keep Rip (normal) | `keepRip` |
| 1037-1076 | Energy discharge + relic + rip | `dischargeEnergyChangeRelicAndRip` |
| 1078-1096 | Quick keep rip | `quickKeepRip` |
| 1098-1108 | Keep Rake | `keepRake` |
| 1119-1125 | Keep FF entry | `keepFF` |
| 1173-? | catAtk main entry | `catAtk` |
| 1272-1283 | Reshift execution | `readyReshift` |
| 1286-1304 | Shred/Claw safe/ready | `safeShred`, `readyShred`, `safeClaw`, `readyClaw` |
| 1310-1337 | Rake/Rip safe | `safeRake`, `safeRip` |
| 1346-1357 | Bite safe/ready | `safeBite`, `readyBite` |
| 1373-1383 | Tiger Fury safe | `safeTigerFury` |
| 1400-1406 | Pounce safe | `safePounce` |
| 1408-1423 | Cower safe/ready | `readyCower`, `safeCower` |
| 1482-1500 | Attack power burst | `atkPowerBurst` |

### classes/druid/bear.lua (~220-280 lines)

| Lines | Content | Functions |
|-------|---------|-----------|
| 1425-1473 | Bear safe/ready pairs | `safeMaul`, `readyMaul`, `safeSavageBite`, `readySavageBite`, `readyGrowl`, `safeDemoralizingRoar`, `readyDemoralizingRoar`, `safeSwipe`, `readySwipe` |
| 1555-1561 | Bear OOC module | `bearOocMod` |
| 1563-1583 | Bear OT module | `bearOtMod` |
| 1585-1590 | Bear debuff module | `bearDebuffMod` |
| 1592-1600 | Bear FF module | `bearFFMod` |
| 1602-1613 | Bear regular attack | `bearRegularAttack` |
| 1615-1621 | Bear reshift module | `bearReshiftMod` |
| 1633-1649 | Bear AoE | `bearAoe` |
| 1651-1716 | Bear main entry | `bearAtk` |

### classes/druid/utility.lua (~200-220 lines)

| Lines | Content | Functions |
|-------|---------|-----------|
| 1502-1513 | Druid buffs | `druidBuffs` |
| 1515-1534 | Druid stun | `druidStun` |
| 1536-1553 | Druid defend | `druidDefend` |
| 1623-1631 | Druid control | `druidControl` |
| 1718-1750 | Pokemon loading | `pokemonLoad` |

**IMPORTANT NOTE:** The above line ranges are APPROXIMATE. The `catAtk` main function is adjacent to other cat functions between approximately lines 1173-1286. The exact line ranges will be locked during planning when the planner performs a precise boundary audit against the current source file. The key invariant is: every function from the original file appears exactly once across the 4 target files, and every line between one function's `end` and the next function's `function` keyword is preserved (comments, blank lines).

### Non-Druid Migration

| Source | Destination | Method | Line Count | Notes |
|--------|-------------|--------|------------|-------|
| SM_Extend_Hunter.lua | classes/Hunter.lua | `git mv` + TODO comment | 218 | Add `-- TODO(Phase-N): migrate to macroTorch.classMetatable` above hand-written `setmetatable` block (line ~33) |
| SM_Extend_Mage.lua | classes/Mage.lua | `git mv` only | 81 | Standalone functions, no OOP class |
| SM_Extend_Priest.lua | classes/Priest.lua | `git mv` only | 111 | Standalone functions, no OOP class |
| SM_Extend_Rogue.lua | classes/Rogue.lua | `git mv` only | 149 | Standalone functions, no OOP class |
| SM_Extend_Warlock.lua | classes/Warlock.lua | `git mv` only | 92 | Standalone functions, no OOP class |
| SM_Extend_Warrior.lua | classes/Warrior.lua | `git mv` only | 210 | Standalone functions, no OOP class |

## Common Pitfalls

### Pitfall 1: Line Range Off-By-One
**What goes wrong:** A function body is truncated because the `end` keyword is missed, or an extra `end` is captured.
**Why it happens:** Lua files don't have automatic indentation markers. A nested `if...end` block inside a function can be confused with the function-closing `end`.
**How to avoid:** Use `grep -n "^function macroTorch\."` to get exact function start lines, then trace each `end` to its matching pair. For Druid.lua specifically, verify each target file loads without syntax errors using `lua -p file.lua` before running `./build.sh`.
**Warning signs:** `lua -p` reports `'end' expected near '<eof>'` or similar.

### Pitfall 2: build_order.txt Staleness
**What goes wrong:** After creating new files, `build_order.txt` references both old (`SM_Extend_Druid.lua`) and new paths, causing duplicate definitions in the output.
**Why it happens:** The current build_order.txt has both current entries (lines 27-33) and future entries (lines 35-44). Both sets coexist under fault-tolerant mode. Once files are created, the fault-tolerant mode will concatenate BOTH old and new paths.
**How to avoid:** MUST remove old entries (lines 26-33) BEFORE running `./build.sh`. The atomic commit strategy (D-02) handles this: remove old entries, add corrected new entries, then build.
**Warning signs:** `SM_Extend.lua` contains `function macroTorch.Druid:new()` twice.

### Pitfall 3: Directory Casing Inconsistency
**What goes wrong:** `build_order.txt` uses `classes/Druid/` (PascalCase directory) but `mkdir` creates `classes/druid/` (snake_case). Strict mode build fails.
**Why it happens:** The build_order.txt future entries (lines 35-38) were written before D-03 decided on snake_case. They haven't been updated yet.
**How to avoid:** Update build_order.txt lines 35-38: `classes/Druid/` -> `classes/druid/`, `classes/Druid.lua` -> `classes/druid/Druid.lua`.
**Warning signs:** `./build.sh` exits with "ERROR: File not found: classes/Druid.lua".

### Pitfall 4: Hunter metatable TODO Placement
**What goes wrong:** The TODO comment is placed in the wrong location or contains incorrect text.
**Why it happens:** The exact metatable block spans lines 33-47 in current SM_Extend_Hunter.lua. The TODO should be placed right above `setmetatable(obj, {` (current line 33) to be immediately visible.
**How to avoid:** Place exactly: `-- TODO(Phase-N): migrate to macroTorch.classMetatable` on the line above `setmetatable`. Do not modify the metatable code itself.
**Warning signs:** grep for TODO in classes/Hunter.lua returns nothing.

### Pitfall 5: Druid Split - Missing canDoReshift
**What goes wrong:** CONTEXT.md lists `canDoReshift` as a cat.lua function (line 34), but the function `canDoReshift` does not exist as a separate definition in the current source.
**Why it happens:** The function was likely inlined into `shouldDoReshift` or renamed in a previous phase. The `grep -n "^function macroTorch.canDoReshift"` returns empty.
**How to avoid:** Do not create a `canDoReshift` function. The name in CONTEXT.md refers to the reshift capability which is implemented by `readyReshift` + `shouldDoReshift`. The planner should use the ACTUAL function names from the source, not the CONTEXT.md listing verbatim.
**Warning signs:** N/A -- discovered during research, no runtime impact.

## Hunter TODO Pattern

The only code change in any non-Druid file is a single line TODO comment in `classes/Hunter.lua`:

```lua
-- Place before setmetatable(obj, { ... }) block (currently line 33 in SM_Extend_Hunter.lua):
-- TODO(Phase-N): migrate to macroTorch.classMetatable
setmetatable(obj, {
    __index = function(t, k)
        -- ... existing 9-line hand-written metatable ...
    end
})
```

Per CLAUDE.md requirements: all comments in English. The "Phase-N" placeholder is intentionally vague since the exact phase number for Hunter refactoring is not yet scheduled.

## Runtime State Inventory

**SKIPPED** -- This is a greenfield file reorganization and build system hardening phase. No rename/refactor involving string replacement. No stored data, live service config, OS-registered state, secrets, or build artifacts carry old strings that need migration. The phase creates new file paths and deletes old ones; all function names remain identical.

Categories verified:
- **Stored data:** None -- WoW addon has no persistent database
- **Live service config:** None -- no external services configured
- **OS-registered state:** None -- no Task Scheduler, pm2, or launchd entries
- **Secrets/env vars:** None -- no API keys or SOPS-encrypted configs
- **Build artifacts:** SM_Extend.lua is regenerated from scratch by `./build.sh`, not patched

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| git | File operations (`git mv`, atomic commit) | YES | 2.49.0 | -- |
| bash/sh | build.sh execution | YES | 3.2.57 | -- |
| lua | Optional syntax validation | YES | 5.4.7 | Skip validation |
| shellcheck | Optional build.sh linting | NO | -- | Manual review |

**Missing dependencies with no fallback:** None -- all required tools are available.

**Missing dependencies with fallback:**
- `shellcheck`: not installed. Fallback is manual code review of the 3-line `[ -f "$line" ] || { echo "ERROR..."; exit 1; }` change.

## Validation Architecture

> `nyquist_validation` is `false` in config.json. Validation section skipped.

## Security Domain

> No web-facing code, no authentication, no cryptography, no input validation boundaries in this phase. The phase edits a shell script (`build.sh`) and reorganizes Lua source files. The shell script reads a local text file (`build_order.txt`) line by line -- no external input. The only security-relevant concern is the shell script's robustness, which is covered by the strict mode change (fail-fast on missing files rather than silently skipping).

### Shell Script Safety

| Pattern | Risk | Mitigation |
|---------|------|------------|
| `while IFS= read -r line` with `exit 1` on missing file | Low -- local file list, no user input | `set -e` not needed; explicit `exit 1` is sufficient |
| `cat "$line"` inside a loop | Low -- paths come from version-controlled build_order.txt | Strict mode exits before `cat` on nonexistent paths |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `canDoReshift` does not exist in current source despite being listed in CONTEXT.md | Common Pitfalls #5 | LOW -- planner will verify against actual source; no runtime impact |
| A2 | All status-check functions (`isRipPresent`, `ripLeft`, `isRakePresent`, `rakeLeft`, `isFFPresent`, `ffLeft`, `isTigerPresent`, `tigerLeft`, `isPouncePresent`, `pounceLeft`, `isDemoralizingRoarPresent`) belong in Druid.lua because shared helpers call them | Druid Line Range Audit | LOW -- grep confirms cross-references; planner can verify with caller analysis |
| A3 | `isNearBy` belongs in Druid.lua (not cat.lua) because `shouldUseShred`, `shouldCastFFDuringWaitWindow`, and `getMinimumAffordableAbilityCost` call it | Druid Line Range Audit | LOW -- grep confirms callers in shared functions |
| A4 | `isGcdOk` and `tigerSelfGCD` belong in Druid.lua because both cat and bear safe functions use them | Druid Line Range Audit | LOW -- `grep` confirms `isGcdOk` called by `readyClaw` (cat) and `readyMaul` (bear); `tigerSelfGCD` used by `safeTigerFury` (cat) and `bearAtk` (bear) |
| A5 | The current build_order.txt lines 35-38 use PascalCase paths (`classes/Druid/...`) that need correction to snake_case (`classes/druid/...`) | Architecture Patterns #3 | LOW -- visually confirmed in file read |

## Open Questions (RESOLVED)

1. **Exact line range boundaries for Druid split** — RESOLVED
   - Resolution: Planner performed boundary audit against source; plans 04-01 include exact line ranges in read_first/action fields. The Druid split uses a subtractive approach (Task 1 removes cat/bear/utility functions from Druid.lua; Tasks 2-3 extract into target files from original source).

2. **Hunter TODO Phase-N placeholder** — RESOLVED
   - Resolution: Plan 04-02 uses `-- TODO(Phase-N): migrate to macroTorch.classMetatable` as specified in D-04, placed above the hand-written setmetatable block per PATTERNS.md.

## Sources

### Primary (HIGH confidence)
- `.planning/phases/04-class-files/04-CONTEXT.md` -- D-01 through D-04 locked decisions, Claude's discretion areas
- `SM_Extend_Druid.lua` -- current source (1870 lines), function definitions verified via `grep -n`, line ranges mapped
- `SM_Extend_Hunter.lua` -- current source (218 lines), metatable pattern verified at lines 33-47
- `build_order.txt` -- current manifest (44 lines), current vs future entries identified
- `build.sh` -- current script, fault-tolerant mode confirmed
- `.planning/ROADMAP.md` -- Phase 4 task breakdown (T4.1.1-T4.3.2), verification commands
- `.planning/REQUIREMENTS.md` -- R6 (classes/ directory) and R8 (Druid logic preservation) acceptance criteria
- `.planning/codebase/CONVENTIONS.md` -- naming conventions (snake_case dirs, PascalCase class files)
- `.planning/codebase/STRUCTURE.md` -- build concatenation order rules

### Secondary (MEDIUM confidence)
- `.planning/phases/01-classmetatable-entity/01-CONTEXT.md` -- D-09 (build_order.txt full manifest), D-10 (fault-tolerant -> strict mode switch) -- cited from Phase 4 CONTEXT.md canonical refs
- `.planning/phases/02-events-system/02-CONTEXT.md` -- D-03 (direct function call + build_order), D-04 (battle_event_queue complete deletion) -- cited from Phase 4 CONTEXT.md canonical refs
- `.planning/phases/03-spell-trace/03-CONTEXT.md` -- D-06 (SpellTrace:register declarative API), D-09 (Druid self-test coverage boundaries) -- cited from Phase 4 CONTEXT.md canonical refs

### Tertiary (LOW confidence)
- None. All claims are verified against source files or locked decisions in CONTEXT.md.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero external dependencies, all tools verified on system
- Architecture: HIGH -- split boundaries derive from locked D-01 decision, verified against source
- Pitfalls: HIGH -- all 5 pitfalls based on gaps found between CONTEXT.md intent and actual source state

**Research date:** 2026-06-09
**Valid until:** 2026-06-16 (stable -- no external dependency changes; source file is static)