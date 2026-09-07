---
phase: quick-260907-sz4-reload-selftest-macro-torch-lua-config-o
plan: 01
status: complete
commit: 219071a
---

# Quick 260907-sz4: Global config options registry + login-time banner

## Result

Pure-additive change (39 insertions, 0 deletions) in two files:

1. `macro_torch.lua` — after the two existing nil-guard blocks: `macroTorch.CONFIG_OPTIONS` registry (2 entries: cpBuildLog, rawdiag2Enabled — the complete set of user-tunable globals per survey) with name/default/desc/cmd explicit-getter fields, and `macroTorch.printConfigBanner()` which prints the white `=== Global Config Options ===` header, one yellow entry line per option (current value via `pcall(opt.get)` + tostring fallback, default literal, one-line purpose) and a yellow setter line (`/run ...` command), closing with the white `=== End Config Options ===` marker. Read-only: the nil-guards remain the only assignments to the two options.
2. `core/selftest.lua` — one comment + one `macroTorch.printConfigBanner()` call appended to the tail of `SelfTest:run()` right after `printDruidDiag()`, so the banner prints "after the selftest output" on both the deferred login/reload run (`core/events.lua:74`) and the /mt path (`core/selftest.lua:990`); the existing `_selfTestRan` dedupe keeps it once per login.

## Gates

- G1 CONFIG OK (macro_torch.lua: bbcheck BALANCED + all registry/banner fragments + exactly 2 option assignments = the nil-guards + no string-keyed indexing).
- G2 DELTA OK + G2 ADDED-BRACKET-BALANCE OK (2=2) — see deviation below.
- LF OK, ADDITIVE OK, TOKEN GATE OK (no #/goto/:: in added lines), zero deletes.

## Deviation from plan (recorded)

The plan's G2 gate assumed `bbcheck core/selftest.lua` prints BALANCED. In fact the file has a **pre-existing** bbcheck MISMATCH at HEAD (verified via `git show HEAD:core/selftest.lua` → MISMATCH before this change; caused by pre-existing content, most likely long-bracket comment handling). The whole-file bbcheck requirement was replaced with a scoped check: all delta assertions (2 added lines, single call after printDruidDiag) plus a diff-scoped bracket-balance check on the added lines (2=2). Pre-existing mismatch left untouched — out of quick-task scope.

## user_setup follow-up

Rebuild via Windows+Cygwin build.sh and /reload (or login) — the banner prints once after the selftest summary + Druid diagnostics: `=== Global Config Options ===` with the two options' current values, defaults and setter commands.