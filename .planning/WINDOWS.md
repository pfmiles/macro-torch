---
schema_version: 1
open_count: 5
waived_count: 0
fixed_count: 2
total_count: 7
last_updated: 2026-09-10T18:59:57.868Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 21 | stub | classes/druid/cat.lua |  | No stubs introduced — pure comment addition only | open |  | 2026-07-29T14:37:47.097Z |  |
| 2 | 22 | stub | classes/druid/selftest.lua | 108 | Batch 2 end marker: placeholder for plan 22-02 expansion tests | open |  | 2026-07-30T15:31:25.495Z |  |
| 3 | 28 | stub | tools/cpdamage.lua | 542 | selftest branch placeholder prints placeholder text; full selftest lands in 28-03 | fixed |  | 2026-09-08T12:37:50.223Z | 2026-09-08T13:49:44.744Z |
| 4 | 28 | stub | tools/cpdamage.lua | 546 | json-out branch placeholder prints placeholder text; result-file output lands in 28-03 | fixed |  | 2026-09-08T12:37:50.446Z | 2026-09-08T13:49:44.997Z |
| 5 | 29 | deviation | classes/druid/Druid.lua |  | Task-2 token-gate grep prints 2: pre-existing '#' comment glyphs ('decision #3'/'decision #4') preserved verbatim per plan instruction; no Lua 5.0 code token introduced | open |  | 2026-09-10T02:39:33.873Z |  |
| 6 | 30 | unrun-verify | classes/druid/selftest.lua |  | S-05..S-12 stubbed DKI pins: in-game /mt battery not runnable on this host (D-14) - execute on Windows+Cygwin per HUMAN-UAT.md Phase 30 protocol | open |  | 2026-09-10T15:09:51.784Z |  |
| 7 | 29 | unrun-verify | classes/druid/selftest.lua |  | T-02 render-hue behavior asserts execute only in-game via /mt on the user's Windows+Cygwin client (no local Lua interpreter on this host); static battery is the executor-certifiable subset, live run backfills 29-UAT.md via verify-work | open |  | 2026-09-10T18:59:57.868Z |  |

````json
[
  {
    "id": 1,
    "kind": "stub",
    "phase": "21",
    "file": "classes/druid/cat.lua",
    "line": null,
    "description": "No stubs introduced — pure comment addition only",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-29T14:37:47.097Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "stub",
    "phase": "22",
    "file": "classes/druid/selftest.lua",
    "line": 108,
    "description": "Batch 2 end marker: placeholder for plan 22-02 expansion tests",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-30T15:31:25.495Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "stub",
    "phase": "28",
    "file": "tools/cpdamage.lua",
    "line": 542,
    "description": "selftest branch placeholder prints placeholder text; full selftest lands in 28-03",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-08T12:37:50.223Z",
    "resolved_at": "2026-09-08T13:49:44.744Z"
  },
  {
    "id": 4,
    "kind": "stub",
    "phase": "28",
    "file": "tools/cpdamage.lua",
    "line": 546,
    "description": "json-out branch placeholder prints placeholder text; result-file output lands in 28-03",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-08T12:37:50.446Z",
    "resolved_at": "2026-09-08T13:49:44.997Z"
  },
  {
    "id": 5,
    "kind": "deviation",
    "phase": "29",
    "file": "classes/druid/Druid.lua",
    "line": null,
    "description": "Task-2 token-gate grep prints 2: pre-existing '#' comment glyphs ('decision #3'/'decision #4') preserved verbatim per plan instruction; no Lua 5.0 code token introduced",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-10T02:39:33.873Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "unrun-verify",
    "phase": "30",
    "file": "classes/druid/selftest.lua",
    "line": null,
    "description": "S-05..S-12 stubbed DKI pins: in-game /mt battery not runnable on this host (D-14) - execute on Windows+Cygwin per HUMAN-UAT.md Phase 30 protocol",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-10T15:09:51.784Z",
    "resolved_at": null
  },
  {
    "id": 7,
    "kind": "unrun-verify",
    "phase": "29",
    "file": "classes/druid/selftest.lua",
    "line": null,
    "description": "T-02 render-hue behavior asserts execute only in-game via /mt on the user's Windows+Cygwin client (no local Lua interpreter on this host); static battery is the executor-certifiable subset, live run backfills 29-UAT.md via verify-work",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-10T18:59:57.868Z",
    "resolved_at": null
  }
]
````
