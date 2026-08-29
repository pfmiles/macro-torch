---
phase: 27-catatk-event-driven-land-tracing-refactor
reviewed: 2026-08-29T03:56:42Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - classes/druid/cat.lua
  - classes/druid/Druid.lua
  - classes/druid/selftest.lua
  - classes/hunter/Hunter.lua
  - core/events.lua
  - core/periodic.lua
  - core/spell_trace_core.lua
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: issues_found
---

# Phase 27: Code Review Report (second pass)

**Reviewed:** 2026-08-29T03:56:42Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found (1 info; zero critical/warning)

## Summary

Second review pass of phase 27 after the fix commits. Every prior finding was re-verified against the current tree; all critical/warning items are closed, and one new Info-level finding is raised. The event-driven land-tracing machinery — intent state machine, aura-apply pairing, fail-wins revocation, self-hit dispatch, FB bleed renewal — is now correctly wired end to end in the current tree.

### Prior-finding dispositions (re-verified in the current tree)

| Prior finding | Disposition | Current-tree evidence |
|---|---|---|
| CR-01 (critical): FB renewal listener received the spell name instead of landTime | FIXED | `classes/druid/Druid.lua:718` declares `function(spell, landTime)` matching the dispatcher contract `listener(spell, landTime)` at `core/spell_trace_core.lua:217`; both renewal pushes use the second parameter (`recordLandEvent('Rake', landTime)` at line 724, `recordLandEvent('Rip', landTime)` at line 730); explanatory comment at lines 713-717. No remaining call strings are pushed into the numeric land stacks. |
| WR-01 (warning): Category Q never executed the renewal body | FIXED | Q-10 (`classes/druid/selftest.lua:940-971`) drives the real listener through `recordLandEvent('Ferocious Bite', fbNow)` with a `hasBuff = true` target stub after seeding numeric Rake/Rip lands, then asserts `type(rakeTop) == 'number' and rakeTop == fbNow` (and identically for Rip). That assertion genuinely fails on CR-01-broken code (a pushed string has type `'string'`), so the false-green gap is closed. |
| V-01 (verification): Q-10 fails in fresh sessions because `macroTorch.context` is nil pre-combat | FIXED | `selftest.lua:944` snapshots, `:952` stubs `macroTorch.context = {}`, `:968` restores it by raw assignment before any assert — consistent with the CR-01 save/restore discipline. Production-side, the nil-context hazard is unreachable: context is created in `onCombatEnter` (`core/combat_context.lua`), and an FB land event can only occur after combat entry. |
| WR-02 (warning): cross-caster false pairing within the 2s intent window | ACCEPTED + documented | Residual-risk comment now at `core/spell_trace_core.lua:248-252` referencing REVIEW.md WR-02 / SECURITY.md R-04 and the fail-wins mitigation. Per launcher decision this stays a documented design trade-off, not an open bug. |
| IN-01 (info): unescaped pattern metacharacters | CLOSED by documentation | Comment at `core/spell_trace_core.lua:66-68` records the metacharacter-free-name invariant. All four current aura-apply names (Pounce, Rip, Serpent Sting, Scorpid Sting) remain metacharacter-free; latent only. |
| IN-02 (info): `pairs()` iteration over `auraApplySpellPatterns` vs runtime registration | CLOSED unchanged | Registrations remain load-time only (Druid.lua:682-706, Hunter.lua:155-165); no runtime mutation path exists. Risk is nil; behavior unchanged. |
| IN-03 (info): Pounce registration lacked `spellName` | MOOT (prior-review false positive) | `classes/druid/Druid.lua:683` carries `spellName = 'Pounce'` in the current tree; the guard-invariant tripwire does cover Pounce. |

### Fresh-eyes re-verification (not covered by the first review's findings)

- **Tier-1 RAW channel whitelist is correct, not a dead branch.** `core/events.lua:136` compares `arg1` (a string) against quoted channel names. This is only correct if SuperWoW delivers the event-name string, which it does: `docs/superwow_features.md` states "RAW_COMBATLOG ... arg1: original event name, arg2: event text with GUIDs", confirmed by the live-capture evidence at `.planning/debug/catatk-premature-rip-recast.md` ("RAW_COMBATLOG 布局:arg1=CHAT_MSG_* 通道名"). No bug.
- **`hits`/`crits` patterns match the vanilla 1.12 combat-log formats.** The deleted pre-phase code (`git show 83f1a65^:battle_event_queue.lua:379-383`) documents the real formats: `Your Rake hits Heroic Training Dummy for 173.` and `Your Rake crits Apprentice Training Dummy for 597.` — both match `onSelfDamageLine`'s two patterns at `core/spell_trace_core.lua:307-310` ('crits' contains no ' hits ' substring, so the first pattern cannot false-match a crit line). No bug.
- **`macroTorch.target.guid` accessor exists** (`entity/Unit.lua:103-110`, SuperWoW `UnitExists` second return), so the RAW handler's ownership check at `core/events.lua:150` has a real guid producer. Verified.
- **Q-02..Q-07 and Q-10 restore discipline** re-read line by line: every stubbed test restores `loginContext`/`target`/`show`/`context` by raw assignment before the first assert; a failing pcall is always asserted separately, so no test can leave a polluted session.
- **`finalizeFail` revocation** uses exact equality against `intent.landAt` (the identical `now` value recorded at pairing) via `LRUStack:removeMatch`, whose reverse-scan bounds are exact and whose early `return` prevents any re-index hazard; the deliberate negative fail window is now annotated. One bounded residual remains in the fail-attribution family: with two same-spell casts inside the 2s window, a very late fail line consumes the newest eligible intent regardless of which cast it belonged to — but the debug evidence pins fail lines to ms-scale same-batch latency versus a 1.5s GCD minimum, so cross-cast misattribution is not reachable in practice. Noted, not flagged.
- **Phase hygiene:** the RAWDIAG scout, `RAWDIAG_KEYWORDS`, `maintainLandTables`/`computeLandTable`/`consumeDruidBattleEvents` and the 0.1s polling registration are all gone from the current tree (Q-09's nil-guards remain as the planned runtime enforcers); `cat.lua`'s phase diff is 11 pure deletions; Hunter's Serpent/Scorpid Sting registrations land on the same verified aura-apply machinery.

## Info

### IN-01: DEBUG init-trace chat spam remains in core/periodic.lua

**File:** `core/periodic.lua:99`, `:102`, `:145`, `:158`
**Issue:** Four `DEFAULT_CHAT_FRAME:AddMessage("[macro-torch] init step 5a..5d ...")` lines (plus their `-- DEBUG:` comments) unconditionally print four chat messages at every addon load. They originate from a June 11 debugging session (commit 0f3d6235, pre-phase) and were never removed. This phase's own polish bar removed its `[RAWDIAG]`/`[DIAG]` diagnostics and the UAT expects "zero [DIAG]/[RAWDIAG] output anywhere" — these init traces are the same class of leftover debug artifact in a ship-ready file, and they produce user-visible chat noise on every `/reload` (which UAT cycles frequently).
**Fix:** Delete the four AddMessage lines and their comment markers (lines 98-99, 101-102, 144-145, 157-158), or gate them behind a `macroTorch.debugInitTrace` flag defaulting to false.

---

_Reviewed: 2026-08-29T03:56:42Z_
_Reviewer: Claude (gsd-code-reviewer, second pass)_
_Depth: standard_