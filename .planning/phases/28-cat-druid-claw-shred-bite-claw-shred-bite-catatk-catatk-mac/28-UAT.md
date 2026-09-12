---
status: complete
phase: 28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac
source: [28-VERIFICATION.md]
started: 2026-09-08T14:42:28Z
updated: 2026-09-12T17:58:44Z
---

## Current Test

[testing complete]

## Tests

### 1. SuperMacro SavedVariables declaration check
expected: Deployed SuperMacro.toc declares MACRO_TORCH_LOG in `## SavedVariables:`; WTF SavedVariables contains a MACRO_TORCH_LOG segment after first play session.
result: pass
evidence: user exported .planning/samples/cpDmgLog.txt straight from the SavedVariables messages array — the segment persisted and the 941-entry dump proves the declaration works end to end.

### 2. In-game config surface + Category U selftest
expected: `/mt` shows the 5th CONFIG entry `macroTorch.cpDamageLog = false` (default off); login selftest runs Category U 9/9 (U-01..U-09) all pass, including the WR-02 Rake mismatch scenario in U-07.
result: pass
evidence: user reported "self-test是全部通过的" (2026-09-13). The `/mt` 5th-entry display sub-item was not separately re-confirmed — low risk, statically verified in 28-VERIFICATION.md.

### 3. Cast-to-emit real-behavior loop
expected: HUMAN-UAT.md §4 protocol on a training dummy: `/run macroTorch.cpDamageLog=true`, ~1 min of claw/shred/bite rotation, `[cpDamage] ` entries appear in the log with the fixed 11-field JSON; miss/dodge produces zero emit (D-03); non-dummy targets are rejected (D-05); after fix c94af69 no spell-mislabeled entries (WR-02).
result: pass
evidence: cpDmgLog.txt carries 941 entries over 52.1 min, 4 batches; all 941 are well-formed 11-field JSON (orch full re-parse: 0/941 bad); dmg<=0 count 0 (D-03); spell domain {claw, shred, bite} only (D-05); no mislabeled rows (WR-02). isOoc=Clearcasting confirmed, isBehind=100% throughout the session.

### 4. Real-data analyzer run
expected: repload → run `lua tools/cpdamage.lua <SuperMacro.lua path>` on the user's machine (any 5.x interpreter): two-layer report (per-batch + aggregate), claw/shred tier tables 0..3 with all four D-18 columns, OOC behind-only table, bite regression line, three decision-line families; ≥30 valid entries across claw/shred/bite. (Interpreter-side `--selftest` already proven on 5.0/5.1/5.4 by review+verifier this session.)
result: pass
evidence: cpDmgOut.txt shows 4 batches + aggregate, full tier tables, OOC table, bite regression (aggregate n=211), three decision families; 941 valid entries (claw 486 / shred 244 / bite 211) >> 30. Orchestrator independently recomputed aggregate rows from raw data — exact match (claw b2 467@563.86, shred b2 193@684.95).

### 5. json-out strictness decision
expected: Decide one of: (a) accept the current Lua-flavored numeric-key archive format as-is (override), or (b) request a quoting fix so `--json-out` output is strict JSON parsable by Node/other strict parsers. This is the single recorded verification gap (28-VERIFICATION.md gaps): numeric bucket keys are currently emitted unquoted, e.g. `{"claw":{1:{"n":0}}}`.
result: issue
reported: "拍板 (b)：要求修复 --json-out 输出为严格 JSON（数字键加引号或数组化），screen 报告文本保持不变"
severity: minor

## Summary

total: 5
passed: 4
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-28-5
  truth: "--json-out output must be strict JSON parsable by Node/other strict parsers (numeric bucket keys quoted or array-encoded)"
  status: failed
  reason: "User decided (b) on 2026-09-13: request a quoting fix. Verifier probe: Node JSON.parse rejects the current output at position 57 (bare numeric keys, e.g. {\"claw\":{1:{\"n\":0}}}). Terminal report and decision lines are unaffected."
  severity: minor
  test: 5
  root_cause: "tools/cpdamage.lua JSON emitter writes bucket-tier numeric keys without quotes (Lua-flavored table notation); JSON spec requires string keys"
  artifacts:
    - path: "tools/cpdamage.lua"
      issue: "json encoder emits bare numeric keys in the --json-out archive"
  missing:
    - "Quote numeric keys (or array-encode tier buckets) in the json-out encoder"
    - "Add a selftest assertion covering the strict-JSON output shape (keep 5.0/5.1/5.4 green)"
  debug_session: ""