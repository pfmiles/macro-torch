---
phase: quick-260907-mhh-rip-landing-rawdiag-forensics-build
plan: 01
status: complete
commit: 953bd50
---

# Quick 260907-mhh: RAWDIAG2 Rip landing forensics instrumentation

## Result

Pure-additive forensics build (113 insertions, 0 modified/deleted lines) across three files:

1. `core/events.lua` — [RAWDIAG2] scout in the RAW_COMBATLOG branch, placed BEFORE the tier-1 channel whitelist so armed windows see every raw line including channels the production handler rejects. Keyword filter (Rip/Rake/Bite/afflicted/fades) + first-20 unconditional samples per arm; 60s / 150-line auto-disarm; nil-safe arg1..arg12 serialization via `table.insert` + counter (Lua 5.0: no length operator).
2. `core/spell_trace_core.lua` — auto-arm hook at the end of `recordCastTable` (spell == 'Rip' + `macroTorch.inCombat` guard; resets counters per cast so every cast anchors a fresh full window); read-only helper `macroTorch.rawdiag2IntentDepth(spell)`; pair ledger in `processRawAuraApply` with exactly four outcome logs: pair-ok / no-pair:no-intent / no-pair:guid-mismatch / no-pair:no-apply-marker, all gated on `local armed`.
3. `classes/druid/cat.lua` — [RAWDIAG2 ctx] one-shot stamp in `safeRip`'s success branch before `macroTorch.player.rip('ready')`: hasBuff / ripLeft / landTop / intentDepth / cp / t.

## Gates (all pass)

- T1/T2/T3 task gates OK; bbcheck BALANCED on all three files.
- ADDITIVE GATE OK (0 removed/modified lines — no decision branch, return value, guard or scheduling touched).
- TOKEN GATE OK (no goto / length-operator / labels / '#' in added lines).
- CPBUILD INDEPENDENCE OK (no reference to the cpBuildLog facility; separate gating).
- `git diff --check` clean (LF preserved); `classes/druid/selftest.lua` and `interface_debug.lua` untouched; SM_Extend.lua NOT rebuilt.

## Selftest safety

Q-02/Q-03 call `recordCastTable('Rip')` out of combat — the arm hook requires `macroTorch.inCombat`, so selftest runs never arm the scout and produce unchanged output. Pair logs require `_rawdiag2Active`, which combat exit wipes and no selftest sets. No selftest calls `safeRip`.

## Deviations from plan (recorded)

- Plan's own comment literals contained a `#` character and the substring `cpBuildLog`, which its own token/independence gates reject. Two comment lines were reworded with identical meaning ("no length operator", "shares no state with any other diagnostic switch"). No code changed.

## user_setup follow-up (on the Windows+Cygwin game machine — cannot run offline)

1. Run `build.sh` on Windows+Cygwin; `/mt` selftests must all pass.
2. R0~R3 sampling protocol from `.planning/todos/pending/druid-rip-land-forensics-next-cd.md` with 1-2 helper ferals on training dummies (>=5s spacing between different casters' casts; no Ferocious Bite during the test).
3. logout/reload; copy back SavedVariables/SuperMacro.lua — MACRO_TORCH_LOG.messages holds all [RAWDIAG2] lines (500-line rotating buffer, oldest windows rotate out first).

## Arbitration contract

- ctx line with `hasBuff=false` → debuff-view leg.
- ctx line `hasBuff=true` + `ripLeft=0` + `landTop=nil` → land-clock leg.
- armed window with NO `pair-ok` line following a ctx line while the keyword dump shows another feral's Rip apply traffic → client-side apply-line suppression confirmed (lands the decisive multi-cat verdict).