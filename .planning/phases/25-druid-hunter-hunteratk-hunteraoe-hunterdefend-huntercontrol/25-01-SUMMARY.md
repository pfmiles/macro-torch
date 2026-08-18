---
phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol
plan: 01
subsystem: classes
tags: [hunter, class-definition, skill-methods, spell-trace, selftest, wow-addon, lua]

# Dependency graph
requires:
  - phase: 24-unit-spellcast-succeeded
    provides: castTable recording via UNIT_SPELLCAST_SUCCEEDED bridge
  - phase: 17-spellId-dynamic-correction
    provides: SpellTrace:register spellName-driven land tracing + immune detection
  - phase: 08-non-druid-refactor
    provides: existing Hunter.lua framework (classMetatable, singleton, registerPlayerClass)
provides:
  - Hunter.lua with 25 skill methods (10 corrected range params, 15 new), aligned with Druid.lua architecture
  - 2 SpellTrace registrations (Serpent Sting + Scorpid Sting, each with spellName/land/immune/debuffTexture)
  - 28 SelfTest registrations (3 infrastructure + 25 skill method existence), all isOptional=true + UnitClass guard
  - build.sh SM_Extend.lua generation verified (exit 0, 28 Hunter SelfTests in output)
affects:
  - 25-02 hunter-combo-macros (combo.lua depends on Hunter.lua skill methods)
  - 25-03 hunter-macros-build-integration (build_order.txt integration)

# Actuals (#2632)
actuals:
  tokens: 2800
  tasks: 2
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Skill method with _castSpell locale double-table + range parameter (30yd for shots, nil for melee/self, 15yd for Scatter Shot)"
    - "SpellTrace:register with full config {spellName, land, immune, debuffTexture} per Druid pattern"
    - "SelfTest:register with UnitClass guard + isOptional=true, infrastructure before skill methods"

key-files:
  modified:
    - classes/hunter/Hunter.lua

key-decisions:
  - "5 remote shot skill methods (arcane_shot, multi_shot, hunters_mark, serpent_sting, concussive_shot) range parameter corrected from nil to 30"
  - "Scatter Shot range set to 15 (short-range Marksmanship talent ability)"
  - "Call Pet preserved with conditional logic (Dismiss Pet if pet exists, Call Pet otherwise)"
  - "HUNTER_FIELD_FUNC_MAP empty table kept intact — no Hunter-specific computed properties needed yet"
  - "SelfTest ordering follows Druid pattern: 3 infrastructure → 25 skill methods"

patterns-established:
  - "Hunter.lua class architecture mirrors Druid.lua: classMetatable + FIELD_FUNC_MAP + skill methods + SpellTrace + SelfTest"
  - "Type A skills (enemy target, onSelf=false) vs Type B skills (self target, onSelf=true) section-commented"

requirements-completed: [H-01, H-02, H-09, H-10, D-09, D-10, D-11, D-12, D-20]

coverage:
  - id: D1
    description: "Hunter.lua class framework (classMetatable, singleton, registerPlayerClass) Druid-aligned"
    requirement: H-01
    verification:
      - kind: unit
        ref: "classes/hunter/Hunter.lua — SelfTest: singleton hunter exists, registered in PLAYER_CLASS_REGISTRY"
        status: pass
    human_judgment: false
  - id: D2
    description: "25 skill methods with corrected range parameters (5 remote shots range=30)"
    requirement: H-02
    verification:
      - kind: unit
        ref: "classes/hunter/Hunter.lua — 25 SelfTest skill method existence checks"
        status: pass
      - kind: integration
        ref: "./build.sh exit 0; grep -c 'function obj\.' SM_Extend.lua"
        status: pass
    human_judgment: false
  - id: D3
    description: "SpellTrace registrations for Serpent Sting + Scorpid Sting (spellName + land=true)"
    requirement: [H-09, D-11]
    verification:
      - kind: integration
        ref: "grep 'SpellTrace:register.*Serpent Sting\|SpellTrace:register.*Scorpid Sting' SM_Extend.lua"
        status: pass
    human_judgment: false
  - id: D4
    description: "Hunter's Mark NOT in SpellTrace registration"
    requirement: D-12
    verification:
      - kind: integration
        ref: "grep -v '^#' classes/hunter/Hunter.lua | grep -c \"Hunter's Mark\" — returns 1 (only in skill method, not in SpellTrace)"
        status: pass
    human_judgment: false
  - id: D5
    description: "28 SelfTest registrations — 3 infrastructure + 25 skill method existence tests, all isOptional=true + UnitClass guard"
    requirement: [H-10, D-20]
    verification:
      - kind: unit
        ref: "grep -c 'SelfTest:register' classes/hunter/Hunter.lua → 28; grep -c 'end, true)$' → 28; grep -c 'Skill method.*exists' → 25"
        status: pass
    human_judgment: false
  - id: D6
    description: "Build verification — ./build.sh succeeds"
    requirement: null
    verification:
      - kind: integration
        ref: "./build.sh && echo 'BUILD OK' → exit 0"
        status: pass
    human_judgment: false

# Metrics
duration: ~15min
completed: 2026-08-18
status: complete
---

# Phase 25 Plan 01: Hunter.lua 完整重写 Summary

**Hunter.lua 从过时测试代码（156行，10技能，13 SelfTest）重写为 Druid 对齐架构（303行，25技能方法，2 SpellTrace，28 SelfTest），构建验证通过**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-18
- **Completed:** 2026-08-18
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- 25 个技能方法全部就位：10 个既有（5 个远程射击 range nil→30 修正）+ 15 个新增（aimed_shot, scorpid_sting, viper_sting, scatter_shot, volley, 三种陷阱, deterrence, feign_death, mend_pet, revive_pet, rapid_fire, 两种守护）
- Serpent Sting 和 Scorpid Sting 的 SpellTrace 注册包含 spellName、land=true、immune=true、debuffTexture 完整四字段
- Hunter's Mark 不在 SpellTrace 注册中（D-12 用户明确不需要）
- 28 项 SelfTest 注册完整：3 基础设施（FIELD_FUNC_MAP, singleton, PLAYER_CLASS_REGISTRY）+ 25 技能方法存在性测试，全部 isOptional=true + UnitClass guard
- 构建系统 ./build.sh 生成 SM_Extend.lua 成功（退出码 0，SM_Extend.lua 含 28 项 Hunter SelfTest）

## Task Commits

Each task was committed atomically:

1. **Task 1: Hunter.lua 完全重写（tracer）** — `dce87d9` (feat)
2. **Task 2: SelfTest 完善验证（auto/tdd）** — No code changes needed (pure verification, all criteria already met from Task 1)

## Files Modified
- `classes/hunter/Hunter.lua` — 303 行：类框架 + 25 技能方法 + HUNTER_FIELD_FUNC_MAP + 2 SpellTrace 注册 + 28 SelfTest 注册

## Decisions Made
- 5 个远程射击技能（arcane_shot, multi_shot, hunters_mark, serpent_sting, concussive_shot）的 range 参数从 nil 修正为 30，melee 技能保持 nil
- Scatter Shot range 设为 15（短距离射击，符合 1.12.1 技能设计）
- Call Pet 保留条件逻辑（宠物存在则 Dismiss Pet，否则 Call Pet）
- 所有技能方法的 mode 参数保持 nil（默认 safe 模式：完整 readiness + range 检查）
- SelfTest 顺序遵循 Druid 模式：基础设施测试在前（3 项），技能方法测试在后（25 项）

## Deviations from Plan

### TDD Gate — Task 2 was pure verification

- **Found during:** Task 2
- **Issue:** Plan labeled Task 2 as `tdd="true"` with `<behavior>` block, but all 28 SelfTest registrations were already complete and correct from Task 1. No RED/GREEN cycle was needed — the task reduced to verification-only.
- **Resolution:** All verification criteria were met without code changes. The existing SelfTest registrations already satisfied all 5 behavior tests (count=28, all isOptional=true, all UnitClass guarded, all 25 skills covered, infrastructure before skills).
- **Impact:** Task 2 produced no additional commit beyond Task 1's `dce87d9`.

No other deviations — plan executed as specified for Task 1; Task 2 was verification-only with all criteria passing.

## Issues Encountered
None

## User Setup Required
None — no external service configuration required.

## Known Stubs
None — all skill methods are fully wired to `_castSpell`, no placeholder values, no TODO/FIXME markers.

## Threat Flags
None — no security surface beyond the plan's threat model (T-25-01/T-25-02/T-25-03 all mitigated).

## Next Phase Readiness
- Hunter.lua skill method layer complete, ready for 25-02 (combo.lua — 5 个一键宏实现)
- All 25 skill methods available via `macroTorch.hunter.{method}()` for combo.lua consumption
- SpellTrace land tracing for Serpent Sting + Scorpid Sting operational
- SelfTest coverage ensures all 25 methods validate on Hunter login

---
*Phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol*
*Completed: 2026-08-18*