---
phase: 18-spellid-spellid-land-tracing-spellidmonitored-current-castin
verified: 2026-07-04T12:30:00Z
status: human_needed
score: 7/7 must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 6/7
  gaps_closed:
    - "config.monitorSpellId = true includes a spell in the whitelist even when land=false — whitelist write block moved outside `if config.land then` (commit 122d007)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "在游戏中登录Druid角色，检查 /mt 自检结果中 Category L 全部5项是否通过"
    expected: "Selftest 汇总显示 Category L 全部5项（L1-L5）均应 PASS。Category K 应全部 PASS（无回归）。"
    why_human: "自检框架依赖游戏内运行时环境（WoW API、SavedVariables），无法在没有游戏客户端的 CLI 环境中运行。"
  - test: "在 SuperWow 环境下施放 Pounce/Rake/Rip/Ferocious Bite 后检查 spellId 更正日志"
    expected: "UNIT_CASTEVENT 触发时，若客户端 spellId 与静态映射不一致，聊天框中出现 '[macro-torch] spellId corrected: ...' 黄色日志"
    why_human: "spellId 更正依赖 SUPERWOW 插件的 UNIT_CASTEVENT 事件，只能在游戏内验证。"
  - test: "在游戏中施放 Faerie Fire (Feral)、Healing Touch、Hibernate 等非白名单技能后，检查是否出现 stale warning"
    expected: "这些技能不会设置 current_casting_spell，也不会触发 stale 检测 warning"
    why_human: "运行时行为依赖实际施法序列和事件到达顺序，grepping 代码只能验证静态逻辑存在。"
  - test: "在非 SuperWow 环境下（如官服1.12客户端）施放 whitelist 中的技能（Pounce 等）"
    expected: "每次施放出现 stale warning（yellow 日志）。这是预期的诊断行为——提醒用户 spellId 更正机制因缺少 UNIT_CASTEVENT 而不可用。RESEARCH Pitfall 3 记录了此风险：观察 stale warning 的噪音水平是否可接受。"
    why_human: "需要实际非SuperWow环境验证 stale 检测的噪音水平。"
behavior_unverified_items:
  - truth: "stale 检测在 current_casting_spell 未清除时通过 macroTorch.log 输出 warning"
    test: "制造 stale 场景：先通过某种方式残留 current_casting_spell，再施放白名单技能，观察日志"
    expected: "出现黄色 warning: 'current_casting_spell was not cleared: ... , now overwritten by: ...'"
    why_human: "stale 检测依赖于运行时状态转换链：_castSpell 设置 -> UNIT_CASTEVENT 清除（或未清除）。此链路涉及 events.lua 的事件到达，无法通过 grep 验证。代码存在且正确连接。"
  - truth: "UNIT_CASTEVENT 的 spellId 更正路径仅在 current_casting_spell 被设置后触发——即仅对白名单中的 spells 有效"
    test: "施放白名单技能（如 Rake）确认触发 spellId 更正，施放非白名单技能（如 FF(Feral)）确认不触发"
    expected: "Rake 触发 spellId 比较（staticSpellId vs event spellId），FF(Feral) 不触发"
    why_human: "events.lua 的 UNIT_CASTEVENT 处理逻辑代码上未改动，但其触发条件 current_casting_spell 现在受白名单守卫控制。运行时链路需要游戏内验证。"
---

# Phase 18: spellId 自动更正机制改造方案 Verification Report (Re-verification)

**Phase Goal:** 将 `_castSpell` 中无条件的 `current_casting_spell` 设值改为以 `_spellIdMonitored` 白名单守卫，白名单由 `SpellTrace:register` 自动维护（land=true + spellName 时自动加入），消除非监控 spell 的残留污染和错误更正风险。

**Verified:** 2026-07-04T12:30:00Z
**Status:** human_needed (all 7 truths VERIFIED; 2 truths are behavior-unverified requiring in-game testing)
**Re-verification:** Yes -- after gap closure (commit 122d007)

## Gap Closure Summary

The single gap identified in the previous verification has been resolved:

| Previous Gap | Fix | Status |
|-------------|-----|--------|
| `config.monitorSpellId = true` with `land=false` unreachable — whitelist write inside `if config.land then` | Commit `122d007` moved the whitelist maintenance block (lines 86-99) OUTSIDE the `if config.land then` block (which ends at line 85) | **CLOSED** |

The fix moves the `shouldMonitor` resolution and `_spellIdMonitored[config.spellName] = true` write to after the `end` of the land block, so it executes for ALL registrations regardless of `config.land` value. The `shouldMonitor` resolution at lines 91-96 correctly preserves explicit `false` and defaults to `config.land` when `monitorSpellId` is nil. Selftest L4 (`monitorSpellId=true` with `land=false`) now has a reachable code path.

No regressions detected: all previously-verified truths, artifacts, key links, and anti-pattern checks remain clean.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `macroTorch._spellIdMonitored` is initialized as an empty set table before any SpellTrace:register calls | ✓ VERIFIED | `core/spell_trace_core.lua:21-22`: guarded-init block at module top level (line 21), BEFORE `SpellTrace = {}` (line 49). Same pattern as `tracingSpells` init. `build_order.txt` confirms spell_trace_core.lua loads before Druid.lua. |
| 2 | `SpellTrace:register` automatically adds `config.spellName` to `_spellIdMonitored` when `shouldMonitor=true` (default = land) | ✓ VERIFIED | `core/spell_trace_core.lua:86-99`: whitelist write OUTSIDE land block. `shouldMonitor` resolves via `if config.monitorSpellId ~= nil then ... else ... end` -- explicit false preserved, nil defaults to land. For 4 production Druid spells (Pounce/Rake/Rip/Ferocious Bite), land=true + spellName -> correctly added. |
| 3 | `config.monitorSpellId = false` explicitly excludes from whitelist even when land=true | ✓ VERIFIED | `core/spell_trace_core.lua:92-93`: `if config.monitorSpellId ~= nil then shouldMonitor = config.monitorSpellId` -- explicit `false` is preserved (not swallowed by `or`). Selftest L3 verifies this. |
| 4 | `config.monitorSpellId = true` includes a spell in the whitelist even when land=false | ✓ VERIFIED | `core/spell_trace_core.lua:86-99`: whitelist write is OUTSIDE `if config.land then` (which ends at line 85). When land=false, the land block is skipped but execution continues to lines 91-96 where `config.monitorSpellId=true` is correctly resolved as `shouldMonitor=true`, and lines 97-99 write to the whitelist. FIXED in commit 122d007. Selftest L4 now has a reachable code path. |
| 5 | `config.spellId` legacy registrations (no config.spellName) do NOT enter whitelist | ✓ VERIFIED | `core/spell_trace_core.lua:97`: `if shouldMonitor and config.spellName then` -- nil-safe guard prevents legacy registrations from entering whitelist. Selftest L5 verifies FF(Feral) absence. |
| 6 | `current_casting_spell` is only set when mode != 'ready' AND spell's English name is in `_spellIdMonitored` | ✓ VERIFIED | `entity/Player.lua:85-101`: stale detection (lines 89-93) + whitelist guard (lines 98-100). Nil-safe: `macroTorch._spellIdMonitored and`. Uses correct `localeNames.en` key matching whitelist. |
| 7 | Stale `current_casting_spell` triggers persistent log warning before being overwritten | ✓ VERIFIED | `entity/Player.lua:89-93`: `macroTorch.log("... was not cleared: ...", 'yellow')`. Correct `(a, color)` signature. Runs BEFORE whitelist guard. |

**Score:** 7/7 truths verified (2 present, behavior-unverified among them -- stale detection state transition and spellId correction pipeline require in-game testing)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `core/spell_trace_core.lua` | `_spellIdMonitored` init + whitelist write | ✓ VERIFIED | Lines 21-22: guarded-init at module top level (BEFORE SpellTrace namespace at line 49). Lines 86-99: whitelist write OUTSIDE land block (land block ends at line 85). Nil-aware shouldMonitor with explicit false preservation. Lua syntax: PASS. |
| `entity/Player.lua` | `_castSpell` whitelist guard + stale detection | ✓ VERIFIED | Lines 85-101: stale detection (89-93) + whitelist guard (98-100). Old unconditional `current_casting_spell = localeNames.en` replaced -- now inside guard only. Nil-safe whitelist lookup. Lua syntax: PASS. |
| `core/selftest.lua` | Category L whitelist selftests (5 tests) | ✓ VERIFIED | Lines 670-740: 5 SelfTest:register calls (L1-L5), 4 core + 1 optional. All Category K tests preserved. Lua syntax: PASS. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `spell_trace_core.lua` line 21 | `entity/Player.lua` `_castSpell` | `macroTorch._spellIdMonitored[localeNames.en]` | ✓ WIRED | `Player.lua:98` correctly reads global whitelist with nil-safety (`and` guard). |
| `SpellTrace:register` (post-land block) | `macroTorch._spellIdMonitored` | Whitelist write at line 98 | ✓ WIRED | `spell_trace_core.lua:97-98` writes for any registration with shouldMonitor=true + spellName, regardless of land value. Now outside land block. |
| `entity/Player.lua` `_castSpell` | `core/events.lua` UNIT_CASTEVENT | `macroTorch.current_casting_spell` | ✓ WIRED | `Player.lua:99` sets it (only for whitelisted spells); `events.lua:98-119` reads + clears. Phase 17 logic verified unchanged. |
| `core/selftest.lua` Category L | `core/spell_trace_core.lua` SpellTrace:register | Test registrations exercise whitelist | ✓ WIRED | L3/L4 call SpellTrace:register with monitorSpellId flag variations. |
| Druid.lua SpellTrace:register (4 calls) | `_spellIdMonitored` | Auto-population at load time | ✓ WIRED | All 4 have land=true+spellName -> auto-whitelisted. Zero config changes needed. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `entity/Player.lua:_castSpell` | `localeNames.en` | Caller's spell method | Yes -- "Rake", "Rip", "Pounce", "Ferocious Bite" | ✓ FLOWING |
| `core/spell_trace_core.lua:SpellTrace:register` | `config.spellName` | Druid.lua register calls | Yes -- matches localeNames.en exactly | ✓ FLOWING |
| `macroTorch._spellIdMonitored` | `config.spellName` from register | Druid registrations at load | Yes -- 4 entries populated | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `core/spell_trace_core.lua` Lua syntax | `lua loadfile('core/spell_trace_core.lua')` | SYNTAX OK | ✓ PASS |
| `entity/Player.lua` Lua syntax | `lua loadfile('entity/Player.lua')` | SYNTAX OK | ✓ PASS |
| `core/selftest.lua` Lua syntax | `lua loadfile('core/selftest.lua')` | SYNTAX OK | ✓ PASS |
| Build succeeds | `./build.sh` | BUILD OK | ✓ PASS |
| `_spellIdMonitored` count in SM_Extend | `grep -c` | 24 occurrences | ✓ PASS |
| Stale detection in SM_Extend | `grep` | found inline | ✓ PASS |
| Whitelist guard in SM_Extend | `grep 'macroTorch._spellIdMonitored and'` | found: inside guard, nil-safe | ✓ PASS |
| Old unconditional bridge removed | `grep -B5 'current_casting_spell = localeNames.en'` | only 1 occurrence, preceded by whitelist guard `if` | ✓ PASS |
| Category L in SM_Extend | `grep -c` | 2 occurrences | ✓ PASS |
| Category K in SM_Extend | `grep -c` | present (no regression) | ✓ PASS |
| Druid registrations in SM_Extend | `grep` | 5 registrations present | ✓ PASS |
| en locale names match whitelist keys | Code analysis | All 4 match exactly | ✓ PASS |
| Nil-aware boolean logic | Code reading | Uses explicit if/else (preserves false) | ✓ PASS |
| `macroTorch.log` signature correct | Code reading | `(a, color)` -- called as `(msg, 'yellow')` | ✓ PASS |
| events.lua unchanged | `grep` | Phase 17 logic intact | ✓ PASS |
| `_spellIdMonitored` init before SpellTrace | grep -n positions | Line 21 < Line 49 | ✓ PASS |
| Whitelist write OUTSIDE land block | grep -n structure | Line 85: `end` of land block; Lines 86-99: whitelist after `end` | ✓ PASS (gap fixed) |

### Probe Execution

Step 7c: SKIPPED -- no probes declared in PLAN/SUMMARY, no conventional `scripts/*/tests/probe-*.sh` found. This is a WoW Lua addon; probes run in-game.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| REQ-18-D01 | 18-01-PLAN.md | Whitelist registration timing | ✓ SATISFIED | `spell_trace_core.lua:86-99` -- land=true+spellName -> auto-add (outside land block) |
| REQ-18-D02 | 18-01-PLAN.md | Whitelist data structure | ✓ SATISFIED | `spell_trace_core.lua:21-22` + `Player.lua:98` |
| REQ-18-D03 | 18-01-PLAN.md | `monitorSpellId` optional field | ✓ SATISFIED | Nil-aware resolution (lines 91-96) + whitelist write (lines 97-99) now OUTSIDE land block. `monitorSpellId=true` with `land=false` is reachable (FIXED in commit 122d007). |
| REQ-18-D04 | 18-02-PLAN.md | Stale detection + whitelist guard | ✓ SATISFIED | `Player.lua:89-93` (stale), `Player.lua:98-100` (guard), `events.lua:98-119` (unchanged) |
| REQ-18-D05 | 18-02-PLAN.md | Backward compatibility | ✓ SATISFIED | `spell_trace_core.lua:97` (spellName guard), Selftest L5 |

### Anti-Patterns Found

None. All three modified files clean: no `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers, no empty implementations, no hardcoded empty data paths. The `grep` for "not available" hit a selftest assertion message (not a code marker).

### Human Verification Required

The phase requires in-game validation. 4 items need human testing (2 of which are behavior-unverified truths -- code is present and wired, but state transition/invariant is not exercised by any test):

#### 1. /mt Self-Test Run

**Test:** 登录 Druid，聊天框 `/mt`
**Expected:** Selftest 汇总显示 Category L 全部5项（L1-L5）均应 PASS（包括 L4 -- 之前因 gap 预期会 FAIL）。Category K 全部 PASS（无回归）。
**Why human:** 游戏内运行时环境。

#### 2. SpellId Correction Pipeline

**Test:** SuperWow 环境下施放 Pounce/Rake/Rip/Ferocious Bite
**Expected:** spellId 不一致时出现 corrected 黄色日志
**Why human:** 依赖 SuperWow UNIT_CASTEVENT。

#### 3. Non-Whitelist Pollution Prevention

**Test:** 施放 FF(Feral)、Healing Touch 等非白名单技能
**Expected:** 不设置 current_casting_spell，无 stale warning
**Why human:** 运行时状态转换。

#### 4. (Optional) Non-SuperWow Stale Warning Level

**Test:** 非 SuperWow 客户端施放白名单技能
**Expected:** 每次出现 stale yellow warning
**Why human:** RESEARCH Pitfall 3 -- 确认噪音可接受。

#### 5. Stale Detection State Transition [behavior-unverified truth]

**Test:** 制造 stale 场景：先通过某种方式残留 current_casting_spell，再施放白名单技能，观察日志
**Expected:** 出现黄色 warning: "current_casting_spell was not cleared: ... , now overwritten by: ..."
**Why human:** stale 检测依赖于运行时状态转换链，涉及 events.lua 的事件到达。

#### 6. Whitelist-Gated SpellId Correction [behavior-unverified truth]

**Test:** 施放白名单技能（如 Rake）确认触发 spellId 更正，施放非白名单技能（如 FF(Feral)）确认不触发
**Expected:** Rake 触发 spellId 比较，FF(Feral) 不触发
**Why human:** events.lua 逻辑未改动但触发条件现在受白名单守卫控制，运行时链路需要游戏内验证。

### Re-verification Summary

**Previous state:** 1 gap -- whitelist write nested inside `if config.land then` made `monitorSpellId=true + land=false` unreachable.

**Fix:** Commit `122d007` moved the whitelist maintenance block from inside `if config.land then` to after its closing `end` (line 85). The block now runs for ALL SpellTrace:register calls regardless of `config.land` value. The `shouldMonitor` resolution at lines 91-96 correctly handles nil (defaults to land), explicit true (preserves), and explicit false (preserves).

**Result:** All 7 must-have truths are now VERIFIED. No regressions detected. The phase is complete at the code level.

**Remaining:** 2 behavior-unverified truths and 4 human verification items require in-game testing. The phase status is `human_needed` until these are confirmed in the WoW client.

---

*Verified: 2026-07-04T12:30:00Z (re-verification after gap fix)*
*Verifier: Claude (gsd-verifier)*