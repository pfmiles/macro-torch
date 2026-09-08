---
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
verified: 2026-09-08T14:40:46Z
status: human_needed
score: 13/16 must-haves verified
behavior_unverified: 2
overrides_applied: 0
gaps:
  - truth: "`--json-out <file>` writes a JSON-structured result archive (D-16)"
    status: partial
    reason: "The archive is written and structured, but bucket tables keyed by bleedCount (0..3) are emitted with unquoted numeric keys (encodeValue object branch uses encodeScalar(k), e.g. {\"claw\":{1:{\"n\":0}}}), which is Lua table notation, not strict JSON — Node JSON.parse / python json / jq all reject it (probe-reproduced). The terminal report, decision lines and the entries interop contract are unaffected. runSelftest has no assertion on archive strictness, which is why all 33 assertions stay green despite the deviation."
    artifacts:
      - path: "tools/cpdamage.lua"
        issue: "encodeValue() (lines 569-610) emits numeric object keys unquoted; writeJsonOut (1111-1128) writes the result verbatim"
    missing:
      - "Quote numeric keys in encodeValue's object branch (or encode 0..3-keyed bucket tables as arrays) so the archive parses as strict JSON"
      - "Optionally add a selftest assertion that round-trips the emitted archive through decodeJson or checks the key quotation"
behavior_unverified_items:
  - truth: "After a Training Dummy claw cast lands, exactly one [cpDamage]-prefixed 11-field JSON entry appears in the persisted ring (D-01/D-07 emit loop)"
    test: "In game, run /mt and observe Cat U-06/U-08, or follow HUMAN-UAT.md Phase 28 section 4 (dummy protocol) — cast claw/shred/bite and read back the SV file"
    expected: "One [cpDamage] line per landed cast with crit=false/true accordingly; 11 fields in the spell dmg crit e energyPool bleedCount isOoc isBehind cp t batch order; miss/dodge/parry lines produce nothing and never consume the pending intent (U-07 assertion, including the WR-02 Rake-line scenario)"
    why_human: "The cast→intent→SELF_DAMAGE-gate→pair→emit chain runs against the WoW client API (RAW_COMBATLOG, GetTime, target guid under SuperWoW); all functions are present and wired and pinned by in-game selftests, but no sandbox test can exercise the client event loop"
  - truth: "miss/dodge/parry lines produce no entry and leave the intent pending (D-03); a Rake damage line cannot consume a stale claw/shred/bite intent (WR-02)"
    test: "In game, run /mt and observe Cat U-07 (dodge line + Rake mismatch scenario)"
    expected: "Zero captured [cpDamage] lines; intent stack count remains 1 after both the dodge line and the Rake hits line"
    why_human: "The pattern-drop logic is deterministic string matching and reads correctly statically, but the drop-and-don't-consume invariant is a runtime ordering guarantee pinned only by the in-game U-07 test"
human_verification:
  - test: "Confirm the deployed SuperMacro variant's .toc carries the MACRO_TORCH_LOG SavedVariables declaration (RESEARCH A2); if missing, append it and fully exit the game before retesting"
    expected: "WTF/Account/<account>/SavedVariables/SuperMacro.lua contains a MACRO_TORCH_LOG section after any logged write"
    why_human: "The .toc file lives on the user's game machine and cannot be inspected from the repository"
  - test: "In game, run /mt and check the login banner — the fifth CONFIG_OPTIONS entry macroTorch.cpDamageLog = false is visible; Category U 9 tests pass"
    expected: "Self-test summary has no red failures; all 9 Cat U tests pass (non-U yellows tolerable); banner shows the cpDamageLog entry with default false"
    why_human: "Selftests execute inside the WoW 1.12 client; the verifier's sandbox has no game client"
  - test: "Follow HUMAN-UAT.md Phase 28 section 4: /run macroTorch.cpDamageLog=true, cycle catAtk against a skull-level Training Dummy ~1 minute (supplement with /run macroTorch.player.claw('ready') etc. so all three skills are sampled), leave combat (~5s, batch end), /reload, copy out SuperMacro.lua"
    expected: "At least 30 [cpDamage] entries spanning claw/shred/bite; e values near 42/54/35"
    why_human: "Requires the live game client (Training Dummy, RAW_COMBATLOG, SavedVariables persistence)"
  - test: "Run lua tools/cpdamage.lua <copied SuperMacro.lua> --json-out <file> on the user machine and confirm the two-layer report and the three decision-line families appear with real numbers"
    expected: "Per-batch + aggregate claw/shred tier tables (0/1/2/3), OOC behind-only table, bite regression a/b/n, per-tier builder / OOC / discharge decision lines; bad-line count 0 or minimal"
    why_human: "Real capture data exists only after the in-game capture; note the verifier already ran --selftest on Lua 5.0.3/5.1.5/5.4.7 (see Probe Execution) so this item validates the real-data path only"
---

# Phase 28: catAtk claw/shred/bite damage instrumentation — Verification Report

**Phase Goal:** opt-in cpDamageLog (macroTorch.cpDamageLog, default false) capturing claw/shred/bite damage into `[cpDamage]` JSON entries in macroTorch.log (persisted SavedVariables), plus a standalone offline analyzer (tools/cpdamage.lua) that answers two tuning decisions: (1) claw vs shred energy-efficiency per bleedCount tier 0/1/2/3 plus OOC single-cast comparison, (2) bite marginal energy conversion (least squares dmg = a + b×(energyPool−35), OOC −0) vs best builder efficiency to decide discharge-before-bite.
**Verified:** 2026-09-08T14:40:46Z
**Status:** human_needed
**Re-verification:** No — initial verification (no prior 28-VERIFICATION.md)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | cpDamageLog defaults to false via nil-guard, CONFIG_OPTIONS carries it as exactly the 5th entry, `_cpDamageProbeWarned` re-arms per login (D-06) | ✓ VERIFIED | macro_torch.lua:61-63 nil-guard; :57-71 five-entry survey comment; :107-112 5th entry with default=false + `/run` cmd; grep `name = ` == 5 |
| 2 | After a landed claw cast, exactly one [cpDamage] 11-field JSON entry reaches the persisted ring (D-01/D-07 emit loop) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Full chain present + wired: cpDamageSample gates (Druid.lua:379-418) → cpDamageCast LRUStack(8) (:425-435) → events.lua:187-191 SELF_DAMAGE gate (pure insertion, tier-1 untouched) → onCpDamageLine/pairCpDamageIntent/cpDamageEvent (spell_trace_core.lua:230-322); pinned by in-game U-06/U-08 only |
| 3 | miss/dodge/parry produce no entry and never consume the intent; a Rake line cannot eat a stale intent (D-03 + WR-02) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | spell whitelist + want-gate read correctly (spell_trace_core.lua:269-299); U-07 extended with the Rake scenario (selftest.lua:1243-1285); runtime pin is in-game only |
| 4 | SM_Extend.lua product contains the five cpDamage functions and preserves Phase 27 land pairing | ✓ VERIFIED | Fresh `bash build.sh` exit 0; `grep -cE 'function macroTorch\.(cpDamageSample\|cpDamageCast\|pairCpDamageIntent\|onCpDamageLine\|cpDamageEvent)'` == 5; `pairLandIntent` == 1 |
| 5 | claw/shred/bite cast hooks are isomorphic with the D-08 token/e triple ('claw', computeClaw_E()) / ('shred', computeShred_E()) / ('bite', 35); bite is cpDamage-only, rake stays cpBuild-only | ✓ VERIFIED | Druid.lua:27/33 (claw), 40/46 (shred), 68/71 (bite, no cpBuild); sample before `_castSpell`; product counts cpDamageSample == 4, cpDamageCast == 4 |
| 6 | Category U selftests U-01..U-09 registered, isOptional=true, inside the Druid guard | ✓ VERIFIED | selftest.lua:1122-1373; `SelfTest:register("Cat U-0` == 9 in source and product; U-01 pins default false; U-03 pins the byte-exact 11-field literal; U-09 pins the Training Dummy gate with a non-dummy rejection path |
| 7 | tools/cpdamage.lua extracts the MACRO_TORCH_LOG block from SV-form text, sandboxes it, filters [cpDamage] entries, decodes and prints them (D-13/D-14) | ✓ VERIFIED | Live probe: crafted SV fixture under all three interpreters (below); nil/empty-table/missing-file/no-args exit semantics correct (0/0/1/1) |
| 8 | Analyzer answers decision (1): claw/shred per-tier efficiency (n/avg dmg/avg dmg÷e/single-cast avg, tiers 0..3) plus OOC behind-only single-cast table (D-17/D-18/D-19) | ✓ VERIFIED | Live probe output shows per-batch + aggregate tier tables with the four columns; OOC tier table excludes the non-behind OOC sample (isBehind filter proven on fixture entry #13) |
| 9 | Analyzer answers decision (2): bite 5cp least squares b with both x formulas, n<3 and zero-denominator guards, discharge-vs-bite decision line against best builder (D-20/D-21) | ✓ VERIFIED | computeBiteRegression (cpdamage.lua:831-879) has OOC x=energyPool−0 / regular −35, single-pass n/sx/sy/sxx/sxy, guards; selftest asserts b≈2/a≈100 ±0.001; live fixture emits "b=1.7397 vs best builder 7.2840 (shred tier 1): discharge before biting" |
| 10 | --selftest passes on a 5.0 and a 5.1+ interpreter with identical behavior (D-15) | ✓ VERIFIED | Verifier ran `lua tools/cpdamage.lua --selftest` on locally compiled Lua 5.0.3, 5.1.5, 5.4.7: "selftest: ALL 33 PASSED" exit 0 on each; full analysis output byte-identical (diff empty) across all three |
| 11 | [cpDamage] recognition deterministic 100%; bad lines skipped + counted without aborting the batch (D-13/T-28-03) | ✓ VERIFIED | parseEntries strict `string.sub(msg,1,11) == '[cpDamage] '` + pcall decode + validateEntry; 50k cap; selftest asserts entries==8/badLines==1/prefix line silently skipped; live fixture printed "warning: 1 malformed lines skipped" |
| 12 | `--json-out <file>` writes a structured result archive; terminal report on stdout (D-16) | ⚠️ PARTIAL (see gap) | Terminal report fully verified live. Archive is written with generatedAt/source/batches/aggregate/decisions/dropped, but bucket tables emit unquoted numeric keys → not strict JSON (probe-reproduced with Node JSON.parse rejection) |
| 13 | HUMAN-UAT.md Phase 28 section complete (prerequisites / pre-test / .toc check / dummy protocol / analyzer run / troubleshooting + T-28-05 same-switch warning) | ✓ VERIFIED | classes/druid/HUMAN-UAT.md:171-237 six sections; anchors --selftest==1, MACRO_TORCH_LOG==3, cpDamageLog=true==1 |
| 14 | Phase-closing battery green: 8-file bbcheck BALANCED, build.sh 0, product counts (fn set 5 / Cat U 9 / sample 4 / cast 4 / pairLandIntent 1 / R8 9), R7 zero-path (tools not in build_order, analyzer symbol not in product, 8-commit window clean), diff --check clean | ✓ VERIFIED | Battery re-run by verifier in own process: every anchor matched; `git diff --check` exit 0 |
| 15 | Phase 27 land semantics untouched: independent intent queue, tier-1 whitelist zero change, events.lua pure insertion | ✓ VERIFIED | `git diff 51e3414~1..HEAD -- core/events.lua` shows additions only; pairLandIntent == 1 in product; cpDamageIntents is a separate LRUStack(8) |
| 16 | Review fixes WR-01 (rawget/rawset restore in R6 selftests) and WR-02 (spell whitelist + want-gate pairing) landed | ✓ VERIFIED | selftest.lua:388-458 snapshot→shadow→pcall→rawset-before-assert; onCpDamageLine whitelist + pairCpDamageIntent(guid, now, want) gate inside the match condition (spell_trace_core.lua:230-252, 269-299); commits 58735b4 / c94af69 in git log |

**Score:** 13/16 truths verified (2 present-behavior-unverified, 1 partial recorded as gap)

### Deferred Items

None — Phase 28 is the last phase in the current ROADMAP; no later phase covers the flagged gap.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `macro_torch.lua` | cpDamageLog nil-guard (false), CONFIG_OPTIONS 5th entry, probe-warned re-arm | ✓ VERIFIED | lines 57-71, 107-112; five-entry survey comment |
| `impl_util.lua` | `macroTorch.jsonEncodeScalar` strict scalar encoder (no %q, no table gsub) | ✓ VERIFIED | line 135; gsub function branch; backslash/quote/control → `\u00XX` |
| `core/combat_context.lua` | `_cpDamageBatch = GetTime()` in onCombatEnter | ✓ VERIFIED | line 39, inside onCombatEnter |
| `classes/druid/Druid.lua` | cpDamageSample / cpDamageCast + three-skill hooks | ✓ VERIFIED | 379-435 (gates: switch→dummy→batch→GCD probe→bleed scan), 27/33/40/46/68/71 |
| `core/spell_trace_core.lua` | pairCpDamageIntent / onCpDamageLine / cpDamageEvent | ✓ VERIFIED | 230-322; TTL reuses LAND_INTENT_TTL; whitelist + want-gate (WR-02) |
| `core/events.lua` | SELF_DAMAGE channel gate between rawdiag2 scout and tier-1 whitelist | ✓ VERIFIED | 187-191; pure insertion, tier-1 strings untouched |
| `tools/cpdamage.lua` | standalone Lua 5.0 analyzer: extract/sandbox/decode/validate/stats/regression/report/decisions/json-out/selftest | ✓ VERIFIED | 1364 lines; probe-tested on 3 interpreters; ban grep (`#`/goto/unpack) == 0 |
| `classes/druid/selftest.lua` | Category U ×9 + WR-01/WR-02 test extensions | ✓ VERIFIED | 1122-1373; CR-01 discipline throughout |
| `classes/druid/HUMAN-UAT.md` | Phase 28 user-machine acceptance section | ✓ VERIFIED | 171-237, 6 sections, all three anchors non-zero |

### Key Link Verification

| From | To | Via | Status |
| --- | --- | --- | --- |
| obj.claw/shred/bite skill methods | cpDamageSample snapshot | called before `_castSpell` (WR-01 probe-before-cast) | ✓ WIRED |
| cpDamageSample (cast side) | cpDamageCast → loginContext.cpDamageIntents | guid-nil guard + lazy LRUStack(8) | ✓ WIRED |
| RAW_COMBATLOG stream | onCpDamageLine | events.lua gate `cpDamageLog and arg1 == SELF_DAMAGE and arg2` at RAW branch | ✓ WIRED |
| onCpDamageLine → pairCpDamageIntent | 2s TTL + case-insensitive guid + spell want-gate | LAND_INTENT_TTL reuse; mismatch consumes nothing | ✓ WIRED |
| cpDamageEvent → persisted ring | `macroTorch.log('[cpDamage] ' .. json)` | interface_debug.lua:106 log → MACRO_TORCH_LOG.messages + LOG_MAX_SIZE trim | ✓ WIRED |
| SV file → analyzer stats | extractMacroTorchLog → loadBlockSandboxed → getMessages → parseEntries → buckets/regression → report | live probe on real SV-form fixture | ✓ WIRED |
| In-game encoder ↔ analyzer decoder | fixed 11-field order contract | U-03 byte-exact literal == probe fixture EXPECT_LINE1 | ✓ WIRED |

### Data-Flow Trace (Level 4)

| Value | Source | Real data | Status |
| --- | --- | --- | --- |
| sample.dmg / crit | parsed from RAW arg2 damage line | real client event text | ✓ FLOWING |
| sample.energyPool / isOoc / isBehind / cp / guid | player.mana, player.isOoc, isBehindTarget, comboPoints, target.guid (WoW APIs at cast time) | live snapshots | ✓ FLOWING |
| bleedCount | three `target.hasBuff(texture)` scans (Disembowel=rake, GhoulFrenzy=rip, SupriseAttack=pounce — matches Druid.lua spell-trace registrations) | live debuff scan | ✓ FLOWING |
| batch | `context._cpDamageBatch` set in onCombatEnter via GetTime() | combat entry time | ✓ FLOWING |
| ring persistence | macroTorch.log → MACRO_TORCH_LOG.messages insert with LOG_MAX_SIZE trim (clamp ≥1, no unbounded loop) | SavedVariables persistence | ✓ FLOWING |
| analyzer report numbers | buildClawShredBuckets/buildOocTiers/computeBiteRegression over parseEntries output | fixture + live probes reproduced every number | ✓ FLOWING |
| --json-out archive | encodeValue(res) → file | written; numeric-key quote deviation recorded as gap | ⚠️ PARTIAL |

No value terminates in a static return, hardcoded render, or mock in the production paths (selftest stubs are confined to tests with rawget/rawset restore).

### Behavioral Spot-Checks (run by verifier, own process)

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| selftest on 3 interpreters | locally compiled `/tmp/luabuild/lua-5.0.3/bin/lua`, `lua-5.1.5/src/lua`, `lua-5.4.7/src/lua` × `tools/cpdamage.lua --selftest` | `selftest: ALL 33 PASSED`, exit 0 ×3 | ✓ PASS |
| Full analysis on crafted SV fixture (13 msg ring, 12 cpDamage [+1 bad JSON, +1 non-prefix, non-behind OOC, OOC bite]) | `lua tools/cpdamage.lua /tmp/test_sv.lua --json-out /tmp/test_out.json` | Two-layer report; tier tables; OOC behind-only; bite regression n=4 a=710.96 b=1.7397 xRange [5..60]; three decision families; "1 malformed line skipped" | ✓ PASS |
| Cross-interpreter output identity | diff of full outputs 5.0.3 vs 5.1.5 vs 5.4.7 | byte-identical | ✓ PASS |
| Edge-case exits | nil / empty-table / missing-file / no-args SV inputs | exit 0 (friendly empty message) / 0 / 1 / 1 with correct messages | ✓ PASS |
| Closing battery | bbcheck 8 files + build.sh + 8 product anchors + R7/R8 git audit + diff --check | every anchor matched, audits 0 | ✓ PASS |
| json-out strict validity | Node `JSON.parse` on emitted archive | ParseError at position 57 (unquoted numeric key) | ✗ FAIL → partial gap |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist for this phase; the declared probe is the analyzer's in-script `--selftest` battery.

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| tools/cpdamage.lua --selftest (Lua 5.0.3) | `/tmp/luabuild/lua-5.0.3/bin/lua tools/cpdamage.lua --selftest` | ALL 33 PASSED, exit 0 | PASS |
| tools/cpdamage.lua --selftest (Lua 5.1.5) | `/tmp/luabuild/lua-5.1.5/src/lua tools/cpdamage.lua --selftest` | ALL 33 PASSED, exit 0 | PASS |
| tools/cpdamage.lua --selftest (Lua 5.4.7) | `/tmp/luabuild/lua-5.4.7/src/lua tools/cpdamage.lua --selftest` | ALL 33 PASSED, exit 0 | PASS |

### Requirements Coverage

Every ID declared across the four plan frontmatters (D-01..D-21, R7, R8) is accounted for — no orphans.

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| D-01 | 28-01 | RAW SELF_DAMAGE channel as damage source; skill whitelist; crit detectable | ✓ SATISFIED | events gate + hits/crits dual patterns + WR-02 whitelist (strictly stronger than the D-01 wording) |
| D-02 | 28-01 | Pairing parallels Phase 27 land architecture on an independent queue | ✓ SATISFIED | cpDamageIntents LRUStack(8), TTL = LAND_INTENT_TTL, pairLandIntent untouched (==1) |
| D-03 | 28-02 | Missing attacks produce no entry | ✓ SATISFIED (runtime pin = Cat U-07, in-game) | pattern non-match drop; U-07 asserts zero emission + intent survives (incl. Rake line) |
| D-04 | 28-01 | bleedCount = cast-time any-source debuff scan of rake/rip/pounce (0-3) | ✓ SATISFIED | three hasBuff texture checks in cpDamageSample; textures match spell-trace registrations |
| D-05 | 28-01, 28-02 | Training Dummy hard gate only | ✓ SATISFIED (runtime pin = Cat U-09, in-game) | verbatim combo.lua isTargetDummy expression; U-09 dummy vs non-dummy paths |
| D-06 | 28-01, 28-02 | cpDamageLog bool default false, login re-arm, CONFIG_OPTIONS 5th entry | ✓ SATISFIED | macro_torch.lua:61-63, 107-112; survey comment updated to five; U-01 |
| D-07 | 28-01, 28-02 | 11-field entry spell dmg crit e energyPool bleedCount isOoc isBehind cp t batch | ✓ SATISFIED | cpDamageEvent fixed order; U-03 byte-exact literal; analyzer fixture EXPECT_LINE1 matches |
| D-08 | 28-02 | e = computeClaw_E() / computeShred_E() / 35 | ✓ SATISFIED | verbatim hook arguments in the three skill methods |
| D-09 | 28-02 | bite records energyPool + isOoc (OOC consumes full pool) | ✓ SATISFIED | unified cpDamageSample snapshot; regression x formulas use them |
| D-10 | 28-01, 28-04 | Reuse MACRO_TORCH_LOG.messages + LOG_MAX_SIZE; no new SV table | ✓ SATISFIED | macroTorch.log write path only; no new SavedVariables declaration in touched files; UAT suggests /run LOG_MAX_SIZE=3000 |
| D-11 | 28-01 | Combat entry auto-batch via GetTime | ✓ SATISFIED | combat_context.lua:39; live probe groups by batch; exit rebuilds context |
| D-12 | 28-01 | `[cpDamage] ` prefix + JSON body via macroTorch.log | ✓ SATISFIED | cpDamageEvent tail `macroTorch.log('[cpDamage] ' .. json)` |
| D-13 | 28-03 | Deterministic prefix → strip → decode recognition | ✓ SATISFIED | parseEntries 11-char exact prefix; probe shows bad-line skip + count + 100% clean recognition |
| D-14 | 28-03, 28-04 | Standalone tools/ script, not in build_order, never in SM_Extend.lua | ✓ SATISFIED | battery: build_order entry == 0, product symbol == 0, 8-commit audit == 0 |
| D-15 | 28-03, 28-04 | Lua 5.0 dialect, 5.1-5.4 runnable, self-contained, syntax self-check covers 5.0 | ✓ SATISFIED | ban grep 0; verifier ran 5.0.3 (self-check!) + 5.1.5 + 5.4.7 all green |
| D-16 | 28-03, 28-04 | Terminal stats table + optional --json-out result file | ⚠️ PARTIAL | terminal fully verified; archive written but numeric keys unquoted (gap) |
| D-17 | 28-03 | Two-layer report: per-batch + aggregate | ✓ SATISFIED | live probe shows both sections with batch grouping |
| D-18 | 28-03 | Tiered n / avg dmg / avg dmg÷e / single-cast avg | ✓ SATISFIED | live probe columns (avgEff = per-sample mean, avgRaw = sumDmg/n); selftest pins hand values |
| D-19 | 28-03 | OOC conclusions tiered, behind-only samples | ✓ SATISFIED | live probe: non-behind OOC shred excluded from OOC table |
| D-20 | 28-03 | bite least squares dmg = a + b×(energyPool−35), OOC −0; n<3 avg-only; zero-denominator guard | ✓ SATISFIED | code + selftest b≈2/a≈100 ±0.001; live n=4 fit |
| D-21 | 28-03 | Direct decision lines: per-tier builder / OOC skill / discharge-before-bite | ✓ SATISFIED | live probe emits all three families incl. best-builder source tier |
| R7 | 28-04 | Declarative build: analyzer never in build manifest, build system untouched | ✓ SATISFIED | battery zero-path audits all 0; build.sh untouched in phase window |
| R8 | 28-02, 28-04 | cat druid decision logic unchanged | ✓ SATISFIED | product grep of the 9 symbols == 9; cat.lua/combo.lua absent from the whole phase commit window |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| tools/cpdamage.lua | 569-610 (encodeValue object branch) | unquoted numeric keys in "JSON" archive emission | ⚠️ Warning | --json-out rejected by strict JSON parsers; recorded as the partial gap |
| tools/cpdamage.lua | ~205 vs 222/226 | `load_chunk` assigned but branch conditions test `loadstring`/`setfenv` directly (IN-02, unchanged from review) | ℹ️ Info | Cosmetic dead-variable risk; behavior proven correct on all three interpreters |
| tools/cpdamage.lua | bucket finalize | avgDmg and avgRaw are the same formula (IN-01, unchanged from review) | ℹ️ Info | Two always-identical report columns; spec-level redundancy locked by 28-RESEARCH D-18 wording; decision layer uses avgEff/OOC avgDmg only |
| core/events.lua:193, classes/druid/Druid.lua:833-834 | `#` chars in pre-existing "decision #N" comments | ℹ️ Info | Pre-date this phase (git blame 3c1e2dbf); the phase-introduced `#` comment tokens were cleaned by the review fix; the D-15 ban grep targets tools/cpdamage.lua which is 0 |

No TODO/FIXME/TBD/placeholder markers in any phase-touched production file; no stubs (the two 28-01 dispatch placeholders were completed by 28-03 and are exercised by probes).

### Human Verification Required

Automated + sandbox checks passed. The following require the user's game machine (merged from the 28-04 plan-deferred human-check and the verifier's own analysis; the workflow routes these into the phase's 28-UAT.md):

1. **SuperMacro .toc SavedVariables declaration** — confirm the deployed variant's .toc lists MACRO_TORCH_LOG; fix + full game exit if missing; expected: the SV file shows a MACRO_TORCH_LOG section after any log write. Why human: game machine file, not in the repo.
2. **In-game /mt + login banner** — banner shows the 5th CONFIG_OPTIONS entry `macroTorch.cpDamageLog = false`; Category U 9/9 pass with no red failures.
3. **Cast→emit loop on the real client (present-but-behavior-unverified truth)** — HUMAN-UAT.md §4 dummy protocol: one [cpDamage] entry per landed claw/shred/bite with correct 11-field order and crit flag; miss/dodge/parry emit nothing and never consume the pending intent (Cat U-06/U-07/U-08 pins, including the WR-02 Rake-mismatch scenario).
4. **Real-data analyzer run** — `lua tools/cpdamage.lua <copied SV> --json-out <file>` yields ≥30 entries across all three skills, two-layer report and three decision-line families with real numbers; bad-line count 0 or minimal.
5. **Decision (informational): json-out strictness** — the archive currently carries Lua-style numeric keys. If the archive is consumed by strict JSON tooling (jq/python/node), accept or fix per the gap entry; if only read by humans or Lua tooling, consider the override suggestion below.

### Gaps Summary

One genuine gap, one judgment item — nothing blocks the phase goal:

1. **--json-out archive is not strict JSON (partial).** The terminal report and decision lines — the goal's actual answers — are fully verified. The optional archive is written and structured but emits bucket tables with unquoted numeric keys (`{"claw":{1:{"n":0}}}`, Lua notation), rejected by standard JSON parsers. Root cause: encodeValue's object branch passes numeric keys through encodeScalar, and runSelftest never asserts archive validity. Fix is small (quote numeric keys or encode 0..3-keyed buckets as arrays + one selftest assertion).

**Override suggestion (if Lua-flavored archives are accepted as the user-facing format):**

```yaml
overrides:
  - must_have: "--json-out writes a strict-JSON result file (D-16)"
    reason: "Archive intentionally follows Lua-table notation readable in the user's Lua ecosystem (WoW addon developer); the terminal report is the primary deliverable and is fully verified"
    accepted_by: "<user>"
    accepted_at: "<ISO timestamp>"
```

All prohibitions held: no catAtk decision-logic change (cat.lua/combo.lua untouched across the entire phase window; R8 == 9 in product), no new SavedVariables table (D-10 reuse), analyzer never in the build manifest and never in the product, Phase 27 land pairing intact (pairLandIntent == 1, tier-1 whitelist zero change, events.lua pure insertion), Lua 5.0 dialect enforced (ban grep 0, self-check literally runs on 5.0.3). Review fixes WR-01/WR-02 verified in code with their pins (rawget/rawset restore before assert; spell whitelist + want-gate). The two INFO findings from code review (IN-01 identical columns, IN-02 dead variable) were declared out of scope and do not affect the goal.

---

_Verified: 2026-09-08T14:40:46Z_
_Verifier: Claude (gsd-verifier)_