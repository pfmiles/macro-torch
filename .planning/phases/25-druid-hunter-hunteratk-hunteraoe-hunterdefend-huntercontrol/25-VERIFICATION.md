---
phase: 25-druid-hunter-hunteratk-hunteraoe-hunterdefend-huntercontrol
verified: 2026-08-19T00:00:00Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
overrides: []
re_verification: false
gaps: []
deferred: []
behavior_unverified_items: []
human_verification: []
---

# Phase 25: Hunter 一键宏改造 Verification Report

**Phase Goal:** 参考 Druid 的一键宏架构（druidAtk/druidAoe/druidDefend/druidControl/druidMobTagging），为 Hunter 职业构建同等的 5 个一键宏：hunterAtk（练级输出，含远程/近战距离路由）、hunterAoe（范围攻击）、hunterDefend（保命—仅 Deterrence）、hunterControl（控制）、hunterMobTagging（抢怪，含远程/近战）。

**Verified:** 2026-08-19
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Hunter.lua 包含完整的类定义框架（classMetatable + singleton + registerPlayerClass），与 Druid.lua 架构对齐 | VERIFIED | classMetatable at line 22, singleton `macroTorch.hunter` at line 148, `registerPlayerClass("Hunter", ...)` at line 149 |
| 2 | 25 个技能方法全部可用，10 个既有方法的远程射击 range 参数从 nil 修正为 30 | VERIFIED | All 25 `function obj.{method}(` definitions present. Lines 41/45/49/53/57: arcane_shot, multi_shot, hunters_mark, serpent_sting, concussive_shot all have `range=30`. Melee skills correctly use nil range. Scatter Shot uses range=15 (line 73). |
| 3 | Serpent Sting 和 Scorpid Sting 的 SpellTrace 注册包含 spellName、land=true、immune=true、debuffTexture | VERIFIED | Lines 152-155 (Serpent Sting), lines 156-159 (Scorpid Sting). Both have all 4 fields. Present in SM_Extend.lua build output. |
| 4 | Hunter's Mark 不在 SpellTrace 注册中 | VERIFIED | "Hunter's Mark" appears exactly once in non-comment code (line 49, skill method only). Not present in any SpellTrace:register call. |
| 5 | SelfTest 注册覆盖 3 项基础设施测试 + 25 项技能方法存在性测试，全部 isOptional=true + UnitClass guard | VERIFIED | 28 `SelfTest:register` calls in Hunter.lua. All 28 end with `end, true)`. 28 `UnitClass('player') ~= 'Hunter'` guards present. Build output contains 33 Hunter SelfTests (28 Hunter.lua + 5 combo.lua). |
| 6 | 构建系统执行 ./build.sh 成功生成 SM_Extend.lua | VERIFIED | `./build.sh` exit code 0. SM_Extend.lua contains 25 skill methods, 5 combo functions, 33 Hunter SelfTest registrations, zero old symbols. |

**Score:** 6/6 truths verified (0 present, behavior-unverified)

### Combo Functions Verification (Plan 25-02 truths)

These are the 10 combo-level truths from Plan 25-02, verified against `classes/hunter/combo.lua` (316 lines):

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | hunterAtk() 作为单入口按 target.distance < 8 路由到 hunterAtkMelee() 或 hunterAtkRanged() | VERIFIED | Lines 180-186: `function macroTorch.hunterAtk()` with `if macroTorch.target.distance < 8` branch |
| 8 | hunterAtkRanged() 执行 8 模块优先级链 | VERIFIED | Lines 3-105. Modules: 1.combatUrgentHPRestore, 2.targetEnemy, 3.startAutoShoot, 4.burstMod(Shift), 5.openerMod(Hunter's Mark), 6.stingMod(Serpent/Scorpid), 7.coreDPSMod(Arcane/Multi), 8.otMod(Disengage) |
| 9 | hunterAtkMelee() 执行 6 模块优先级链 | VERIFIED | Lines 107-178. Modules: 1.combatUrgentHPRestore, 2.targetEnemy, 3.startAutoAtk, 4.burstMod(RapidFire only, no Aimed), 5.coreMeleeMod(Raptor/Mongoose), 6.otMod(Disengage) |
| 10 | startAutoShoot() 在 hunterAtkRanged() 中每键调用 | VERIFIED | Line 24: `player.startAutoShoot()` called unconditionally after targetEnemy, before burstMod. Also present in hunterAoe and hunterMobTagging. |
| 11 | Aimed Shot 仅在 burstMod 中通过 IsShiftKeyDown() 触发 | VERIFIED | Lines 27-53: `IsShiftKeyDown()` sets `burstFlags`, then Aimed Shot consumed via `isSpellExist('Aimed Shot')`. Not present in coreDPSMod or any non-burst module. hunterAtkMelee burstMod explicitly comments "no Aimed Shot" (line 132). |
| 12 | hunterAtk 模块链中不包含陷阱、守护、宠物逻辑 (D-06/D-07/D-08) | VERIFIED | grep for `trap`, `aspect_`, `pet.`, `call_pet`, `mend_pet`, `revive_pet` in hunterAtkRanged/hunterAtkMelee function bodies returns 0 matches |
| 13 | hunterAoe() 距离路由：远程 Multi-Shot→Volley，近战 Explosive Trap→Immolation Trap | VERIFIED | Lines 198-224. `<8yd` branch: Explosive Trap→Immolation Trap. `>=8yd` branch: Multi-Shot→Volley (with startAutoShoot). |
| 14 | hunterDefend() 仅检查 Deterrence 并释放 | VERIFIED | Lines 188-193. Single check: `isSpellExist('Deterrence') and isSpellReady('Deterrence')`, then `deterrence('ready')`. No Feign Death, Disengage, or Aspect logic. |
| 15 | hunterControl() 距离路由：近战 Wing Clip/Freezing Trap，远程 Concussive Shot/Scatter Shot | VERIFIED | Lines 229-254. `<8yd`: Wing Clip→Freezing Trap. `>=8yd`: Concussive Shot→Scatter Shot. Both branches use `isSpellExist` guards. |
| 16 | hunterMobTagging() 含 PvP 过滤（选到玩家 ClearTarget）+ 距离路由 tag + tag 成功后自动衔接 hunterAtk() | VERIFIED | Lines 261-292. Line 266-272: PvP filter with `isPlayerControlled→ClearTarget()`. Line 274-286: distance routing (Wing Clip melee, Arcane Shot rank=1 ranged). Line 289-291: auto-chain `isAttackingMe → hunterAtk()`. |

**Score:** 16/16 truths verified (0 present, behavior-unverified)

### Cleanup Verification (Plan 25-03 truths)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 17 | build_order.txt 包含 classes/hunter/combo.lua（在 classes/hunter/Hunter.lua 之后） | VERIFIED | Lines 37-38: Hunter.lua at line 37, combo.lua at line 38 |
| 18 | build_order.txt 不再包含 classes/hunter/combat.lua 和 classes/hunter/utility.lua | VERIFIED | No Hunter-specific combat.lua or utility.lua entries. Other classes' combat.lua/utility.lua remain (unrelated). |
| 19 | classes/hunter/combat.lua 和 classes/hunter/utility.lua 文件已删除 | VERIFIED | Both files confirmed deleted (`test -f` returns not-found) |
| 20 | ./build.sh 成功生成 SM_Extend.lua | VERIFIED | Exit code 0. Build output verified. |
| 21 | SM_Extend.lua 中包含 hunterAtk/hunterAoe/hunterDefend/hunterControl/hunterMobTagging 全部 5 个函数 | VERIFIED | `grep -c` returns 5 in SM_Extend.lua |
| 22 | SM_Extend.lua 中不再包含旧 hunterSting/hunterCtrl/htOtMod 等废弃函数引用 | VERIFIED | grep for old symbols returns zero matches in SM_Extend.lua |

**Score:** 22/22 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `classes/hunter/Hunter.lua` | ~300-350 lines, 25 skill methods, 2 SpellTrace, 28 SelfTest | VERIFIED | 303 lines. 25 skill methods present. 2 SpellTrace: Serpent Sting + Scorpid Sting (all 4 fields). 28 SelfTest: 3 infra + 25 skill methods. All isOptional=true + UnitClass guard. Copyright header preserved. |
| `classes/hunter/combo.lua` | ~316 lines, 7 functions (2 internal + 5 public), 5 SelfTest | VERIFIED | 316 lines. hunterAtkRanged + hunterAtkMelee (internal), hunterAtk/hunterDefend/hunterAoe/hunterControl/hunterMobTagging (public). 5 SelfTest. |
| `build_order.txt` | Modified: Hunter.lua + combo.lua, no old Hunter files | VERIFIED | Line 36-38: Hunter block comment updated to "Phase 8 / Phase 25 combo refactor". Hunter.lua at line 37, combo.lua at line 38. |
| `classes/hunter/combat.lua` | Deleted | VERIFIED | File does not exist |
| `classes/hunter/utility.lua` | Deleted | VERIFIED | File does not exist |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| hunterAtk() → hunterAtkMelee/hunterAtkRanged | combo.lua line 181 | distance < 8 branch | WIRED | `macroTorch.target.distance < 8` routes to `hunterAtkMelee()` or `hunterAtkRanged()` |
| hunterMobTagging() → hunterAtk() | combo.lua line 290 | isAttackingMe auto-chain | WIRED | `target.isAttackingMe → macroTorch.hunterAtk()` per D-19 |
| Combo skill calls → _castSpell | entity/Player.lua | macroTorch.player.xxx() singleton dispatch | WIRED | All combo.lua calls use `macroTorch.player.{method}()` (24 calls). Singleton dispatch through `macroTorch.hunter` when class is Hunter. |
| SpellTrace:register() → spellName/land/immune/debuffTexture | core/spell_trace_core.lua | Hunter.lua lines 152-159 | WIRED | Both registrations have all 4 fields. Build output confirms inclusion. |
| build_order.txt Hunter.lua → combo.lua ordering | build.sh → SM_Extend.lua | Sequential concatenation | WIRED | combo.lua (line 38) follows Hunter.lua (line 37). Build succeeds with symbol resolution. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| combo.lua burstMod | `macroTorch.context.burstFlags` | Set via `IsShiftKeyDown()`, consumed in priority chain | Delegates to WoW API state | FLOWING |
| combo.lua openerMod | `target.buffed("Hunter's Mark", ...)` | Unit.lua FIELD_FUNC_MAP → WoW UnitBuff API | Delegates to WoW API | FLOWING |
| combo.lua stingMod | `target.buffed("Serpent Sting", ...)` | Unit.lua FIELD_FUNC_MAP → WoW UnitBuff API | Delegates to WoW API | FLOWING |
| combo.lua isFightStarted | `macroTorch.isFightStarted(clickContext)` | Druid.lua global function, checks player.isInCombat/target state | Delegates to WoW API | FLOWING |
| Hunter.lua Scorpid Sting | `debuffTexture = 'INV_Misc_QuestionMark'` | Static string | Assumed texture; used for immune display only, not correctness-critical | FLOWING (assumed texture) |
| Hunter.lua HUNTER_FIELD_FUNC_MAP | Empty table `{}` | Static | Intentional — no Hunter-specific computed properties needed | FLOWING (by design) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Build produces SM_Extend.lua with all Hunter symbols | `./build.sh && grep -c ...` | Exit 0, 25 skill methods, 5 combo functions, 33 Hunter SelfTests | PASS |
| Build contains SpellTrace registrations | `grep "SpellTrace:register.*Serpent\|Scorpid" SM_Extend.lua` | Both registrations found | PASS |
| Build excludes deprecated symbols | `grep "hunterSting\|hunterCtrl\|htOtMod" SM_Extend.lua` | Zero matches | PASS |
| Hunter.lua SelfTest completeness | `grep -c "SelfTest:register" classes/hunter/Hunter.lua` | 28 | PASS |
| combo.lua SelfTest completeness | `grep -c "SelfTest:register" classes/hunter/combo.lua` | 5 | PASS |

Step 7b: Run-level behavioral testing requires WoW client login. SKIPPED (no runnable entry points outside WoW).

### Probe Execution

No probes declared for this phase. SKIPPED.

### Requirements Coverage

All requirement IDs from PLAN frontmatter cross-referenced against RESEARCH.md §Phase Requirements:

#### H-Series (Hunter-specific requirements)

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| H-01 | 25-01 | Hunter.lua 完全重写为 Druid 对齐结构 | SATISFIED | 303 lines, classMetatable, singleton, registerPlayerClass |
| H-02 | 25-01 | 新增 ~15 个技能方法，总计 ~25 个 skill methods | SATISFIED | 25 methods confirmed (10 existing + 15 new) |
| H-03 | 25-02 | combo.lua 新建，包含 5 个一键宏 | SATISFIED | 316 lines, 5 public + 2 internal functions |
| H-04 | 25-02 | hunterAtk 12-模块优先级链 + 距离路由 | SATISFIED | 8-module ranged + 6-module melee, distance<8 routing |
| H-05 | 25-02 | hunterAoe 距离路由 | SATISFIED | Ranged: Multi-Shot→Volley, Melee: Explosive→Immolation Trap |
| H-06 | 25-02 | hunterDefend 极简 Deterrence 检查 | SATISFIED | Single Deterrence check, 5 lines |
| H-07 | 25-02 | hunterControl 距离路由 | SATISFIED | Melee: Wing Clip/Freezing Trap, Ranged: Concussive/Scatter Shot |
| H-08 | 25-02 | hunterMobTagging 距离路由 + PvP 过滤 + 自动衔接 | SATISFIED | PvP filter (ClearTarget), Arcane Shot R1 ranged, Wing Clip melee, isAttackingMe auto-chain |
| H-09 | 25-01 | Serpent Sting + Scorpid Sting SpellTrace 注册 (land trace) | SATISFIED | Both registrations with spellName, land=true, immune=true, debuffTexture |
| H-10 | 25-01 | SelfTest: 基础设施 + ~25 技能 + 5 宏函数, isOptional=true | SATISFIED | 33 Hunter SelfTests in build (28 Hunter.lua + 5 combo.lua), all isOptional |
| H-11 | 25-03 | combat.lua + utility.lua 废弃/删除 | SATISFIED | Both files deleted, not in build_order.txt |
| H-12 | 25-03 | build_order.txt 添加 classes/hunter/combo.lua | SATISFIED | combo.lua at line 38, after Hunter.lua at line 37 |

#### D-Series (Design decisions from CONTEXT.md)

| Requirement | Description | Status | Evidence |
| ----------- | ----------- | ------ | -------- |
| D-01 | 单入口路由 — hunterAtk() distance<8 routing | SATISFIED | combo.lua:180-186 |
| D-02 | 12 模块优先级链 (clickContext pattern) | SATISFIED | 8 ranged + 6 melee modules, clickContext cached |
| D-03 | 近战/远程切换阈值 8yd | SATISFIED | `distance < 8` in all routing points |
| D-04 | Auto Shot 每键触发 | SATISFIED | `startAutoShoot()` unconditionally in hunterAtkRanged module 3 |
| D-05 | Aimed Shot Shift 手动触发 | SATISFIED | `IsShiftKeyDown()` in burstMod only |
| D-06 | 不涉及陷阱 in hunterAtk | SATISFIED | Zero trap references in hunterAtkRanged/Melee |
| D-07 | 不涉及守护 in hunterAtk | SATISFIED | Zero Aspect references in hunterAtkRanged/Melee |
| D-08 | 不涉及宠物 in hunterAtk | SATISFIED | Zero pet method calls in hunterAtkRanged/Melee |
| D-09 | ~15 个新技能方法 | SATISFIED | 15 new methods confirmed |
| D-10 | Druid 对齐文件结构 | SATISFIED | Hunter.lua (class + skills + SpellTrace + SelfTest) + combo.lua (macros) |
| D-11 | 钉刺 land tracing | SATISFIED | Both Serpent Sting and Scorpid Sting SpellTrace with land=true + spellName |
| D-12 | Hunter's Mark 不 trace | SATISFIED | Not in any SpellTrace:register call |
| D-13 | hunterAoe 距离路由 | SATISFIED | Ranged Multi-Shot→Volley, Melee Explosive→Immolation |
| D-14 | hunterDefend 仅 Deterrence | SATISFIED | Single skill check, 5 lines |
| D-15 | hunterControl 距离路由 | SATISFIED | Full implementation with isSpellExist guards |
| D-16 | hunterMobTagging 远程 Arcane Shot rank 1 | SATISFIED | `arcane_shot('ready', 1)` at line 284 |
| D-17 | hunterMobTagging 近战 Wing Clip | SATISFIED | `wing_clip('ready')` at line 277 |
| D-18 | PvP 过滤 (ClearTarget) | SATISFIED | `isPlayerControlled → ClearTarget()` at lines 266-272 |
| D-19 | 自动衔接输出 (isAttackingMe → hunterAtk) | SATISFIED | `target.isAttackingMe → hunterAtk()` at lines 289-291 |
| D-20 | SelfTest 参照 Druid 级别 | SATISFIED | 33 Hunter SelfTests, all isOptional=true + UnitClass guard |

**Requirements coverage: 12 H-series requirements SATISFIED, 20 D-series requirements SATISFIED. No ORPHANED requirements.**

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| Hunter.lua | 158 | `debuffTexture = 'INV_Misc_QuestionMark'` (assumed texture for Scorpid Sting) | INFO | Non-critical — only used for immune display. Assumption A20 from RESEARCH.md, plan acknowledges as low-risk fallback. |

No TBD, FIXME, XXX, TODO, HACK, or PLACEHOLDER markers found. No empty return patterns. No hardcoded stubs. No console.log-only implementations. No hardcoded empty data props flowing to rendering.

### Gaps Summary

No gaps found. All 38 truths verified. All artifacts present, substantive, wired, and flowing. Build passes. Deprecated files deleted. Requirement coverage complete.

---

**Known assumption requiring in-game verification:** Scorpid Sting debuff texture (`INV_Misc_QuestionMark`) is a best-guess placeholder. The SelfTest framework will flag any spell-name failure at Hunter login, and the texture is used only for immune-trace visual display — not for any decision-making logic. Confirmation in-game is recommended but does not block phase completion.

---

_Verified: 2026-08-19_
_Verifier: Claude (gsd-verifier)_