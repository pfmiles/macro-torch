---
phase: quick-260907-mhh-rip-landing-rawdiag-forensics-build
reviewed: 2026-09-07
fix_commit: fe1f417
findings_fixed:
  - WR-01
  - WR-02
findings_skipped:
  - IN-01
  - IN-02
  - IN-03
status: fixed
---

# Quick 260907-mhh: Code Review Fix Report

`fe1f417 fix(druid): RAWDIAG2 WR-01 cached-gate ctx field + hasBuffLive, WR-02 rawdiag2Enabled master switch (quick 260907-mhh)`

## Fixed

### WR-01 — ctx stamp reported a live hasBuff re-scan instead of the cached decision gate

`classes/druid/cat.lua` (safeRip stamp): the `[RAWDIAG2 ctx]` line now reports
`isRipPresent=` from the **cached arbiter field** `clickContext.isRipPresent`
(freshly computed earlier in the same click by the pre-stamp `show()` line's
`macroTorch.isRipPresent(clickContext)` call), and the live 40-slot UnitDebuff
scan is retained as a separate `hasBuffLive=` field. Cached-vs-live drift is
now visible in the evidence instead of polluting the core adjudicated field.

### WR-02 — no master switch; incidental fights could flush the rotating buffer

- `macro_torch.lua`: new nil-guard default `macroTorch.rawdiag2Enabled = false`
  (same pattern as the cpBuildLog switch; re-arms on every login).
- `core/spell_trace_core.lua` (recordCastTable arm hook): condition now
  requires `macroTorch.rawdiag2Enabled` — scout no longer arms from incidental
  fights.
- `classes/druid/cat.lua` (ctx stamp): wrapped in
  `if macroTorch.rawdiag2Enabled then` — per-cast ctx lines are switch-gated
  too (the pair ledger was already armed-gated transitively).

In-game usage: run `/run macroTorch.rawdiag2Enabled=true` before the R0~R3
dummy session; log out/reload right after the test to flush and re-arm the
default off.

## Skipped (Info, per user scope: Critical+Warning only)

- IN-01: first-20 layout samples consumed by melee auto-attack lines — cosmetic, filtered during offline arbitration.
- IN-02: `'Rip'` substring also matches `Riposte` — rare; filtered offline.
- IN-03: magic numbers 60/150/20/12 — style only.

## Gates after fix (all pass)

- bbcheck BALANCED on core/events.lua, core/spell_trace_core.lua, classes/druid/cat.lua, macro_torch.lua
- WR-01 fragment gate: `isRipPresent=` cached field + `hasBuffLive=` + single non-comment `RAWDIAG2 ctx` statement
- SWITCH DEFAULT OK (macro_torch.lua nil-guard), ARM GATE OK (switch in arm condition), LF OK, TOKEN GATE OK, ADDITIVE-vs-BASE OK (diff vs f2ac754 still purely additive)