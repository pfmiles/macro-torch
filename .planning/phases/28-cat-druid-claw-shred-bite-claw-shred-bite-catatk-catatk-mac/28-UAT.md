---
status: testing
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
source: [28-VERIFICATION.md]
started: 2026-09-08T14:42:28Z
updated: 2026-09-08T14:42:28Z
---

## Current Test

number: 1
name: SuperMacro SavedVariables declaration check
expected: |
  In the deployed SuperMacro.toc variant on the user's machine, the
  `## SavedVariables:` line (or equivalent declaration) lists
  MACRO_TORCH_LOG. Without it the macroTorch.log persistence segment is
  MISSING in this ext environment (RESEARCH A2) and cpDamage data cannot
  survive a reload.
awaiting: user response

## Tests

### 1. SuperMacro SavedVariables declaration check
expected: Deployed SuperMacro.toc declares MACRO_TORCH_LOG in `## SavedVariables:`; WTF SavedVariables contains a MACRO_TORCH_LOG segment after first play session.
result: [pending]

### 2. In-game config surface + Category U selftest
expected: `/mt` shows the 5th CONFIG entry `macroTorch.cpDamageLog = false` (default off); login selftest runs Category U 9/9 (U-01..U-09) all pass, including the WR-02 Rake mismatch scenario in U-07.
result: [pending]

### 3. Cast-to-emit real-behavior loop
expected: HUMAN-UAT.md §4 protocol on a training dummy: `/run macroTorch.cpDamageLog=true`, ~1 min of claw/shred/bite rotation, `[cpDamage] ` entries appear in the log with the fixed 11-field JSON; miss/dodge produces zero emit (D-03); non-dummy targets are rejected (D-05); after fix c94af69 no spell-mislabeled entries (WR-02).
result: [pending]

### 4. Real-data analyzer run
expected: repload → run `lua tools/cpdamage.lua <SuperMacro.lua path>` on the user's machine (any 5.x interpreter): two-layer report (per-batch + aggregate), claw/shred tier tables 0..3 with all four D-18 columns, OOC behind-only table, bite regression line, three decision-line families; ≥30 valid entries across claw/shred/bite. (Interpreter-side `--selftest` already proven on 5.0/5.1/5.4 by review+verifier this session.)
result: [pending]

### 5. json-out strictness decision
expected: Decide one of: (a) accept the current Lua-flavored numeric-key archive format as-is (override), or (b) request a quoting fix so `--json-out` output is strict JSON parsable by Node/other strict parsers. This is the single recorded verification gap (28-VERIFICATION.md gaps): numeric bucket keys are currently emitted unquoted, e.g. `{"claw":{1:{"n":0}}}`.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps

- `--json-out` numeric bucket keys unquoted → not strict JSON (verifier probe: Node JSON.parse rejects at position 57). Terminal report/decision lines unaffected. Fix (quote keys or array-encode buckets) vs accept-Lua-notation = UAT item 5.