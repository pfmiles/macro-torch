---
phase: 01-classmetatable-entity
reviewed: "2026-06-08T02:40:00Z"
depth: deep
files_reviewed: 16
files_reviewed_list:
  - core/class.lua
  - core/periodic.lua
  - entity/Unit.lua
  - entity/Player.lua
  - entity/Target.lua
  - entity/Pet.lua
  - entity/TargetTarget.lua
  - entity/TargetPet.lua
  - entity/PetTarget.lua
  - entity/Group.lua
  - entity/Raid.lua
  - battle_event_queue.lua
  - SM_Extend_Druid.lua
  - build_order.txt
  - build.sh
  - macro_torch.lua
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-06-08T02:40:00Z
**Depth:** deep
**Files Reviewed:** 16
**Status:** issues_found

## Summary

Phase 01 introduces a unified metatable factory (`classMetatable`), a polymorphic player initialization system (`initPlayer`/`registerPlayerClass`), a periodic task scheduling module (`core/periodic.lua`), entity file reorganization into `entity/`, and a declaration-based build system. Overall the implementation is solid and 1:1 equivalent to the original patterns. The `classMetatable` nil-parent handling and field resolution order are correct. The Druid multi-class hack has been properly eliminated. The build system works and produces valid Lua output.

One critical issue was found: `build_order.txt` is missing a trailing newline on its last line, which causes `classes/Warrior.lua` to be silently skipped by the `while read` loop in `build.sh` — a latent bug that will manifest in Phase 4. Three warnings cover a pre-existing `pairs`-during-iteration bug, an inconsistent metatable pattern in `SM_Extend_Druid.lua`, and a missing guard in `build.sh`. Three minor findings cover output formatting and dead references.

---

## Critical Issues

### CR-01: `build_order.txt` last line missing trailing newline — last entry silently skipped by `while read`

**File:** `build_order.txt:45`
**Issue:** The final line `classes/Warrior.lua` has no terminating newline character. Bash's `while IFS= read -r line` only processes lines that end with `\n`. The last line without a newline is silently discarded by the loop. Verified via `od -c build_order.txt | tail -2` — the file ends immediately after `lua` with no newline byte. The `while read` loop in `build.sh` line 11 will never see this entry.

**Impact:** Currently `classes/Warrior.lua` does not exist (Phase 4 future file), so no observable failure. However, when it is created in Phase 4, it will be silently excluded from the build output — a latent bug that would be difficult to diagnose.

**Fix:** Add a trailing newline to `build_order.txt`:
```bash
printf '\n' >> build_order.txt
```

Alternatively, harden `build.sh` to handle the missing-newline case by using a process substitution that appends a newline:
```bash
while IFS= read -r line || [ -n "$line" ]; do
    ...
done < build_order.txt
```
The `|| [ -n "$line" ]` guard handles the last partial line when it lacks a newline.

---

## Warnings

### WR-01: `onPeriodicUpdate` modifies table during `pairs` iteration via `removePeriodicTask`

**File:** `core/periodic.lua:98-109`
**Issue:** When `task.times` reaches 0 (line 105), `macroTorch.removePeriodicTask(name)` is called, which does `macroTorch.periodicTasks[name] = nil` — removing the current key from the table while `pairs` is iterating over it. Lua 5.1's `pairs` (based on `next`) has undefined behavior when keys are removed during traversal. This can cause tasks to be skipped or the same task to be processed multiple times.

**Note:** This is a pre-existing bug carried over from the original `battle_event_queue.lua`. No task in the current codebase sets `times` to a finite value, so the bug is latent. However, `macroTorch.setRepeat()` accepts a `times` parameter, making this code path reachable.

**Fix:** Collect expired task names during iteration, then delete them after:
```lua
function macroTorch.onPeriodicUpdate()
    local expired = {}
    for name, task in pairs(macroTorch.periodicTasks) do
        if GetTime() - frame.lastUpdate >= task.interval then
            if not task.times or task.times > 0 then
                if task.times then
                    task.times = task.times - 1
                end
                task.task()
            else
                expired[#expired + 1] = name
            end
        end
    end
    for _, name in ipairs(expired) do
        macroTorch.removePeriodicTask(name)
    end
end
```

### WR-02: `SM_Extend_Druid.lua` still uses hand-written `setmetatable` template — inconsistent with migrated entity files

**File:** `SM_Extend_Druid.lua:33-46`
**Issue:** All 9 entity files in `entity/` were migrated to use `macroTorch.classMetatable()`, but `SM_Extend_Druid.lua` (and all other `SM_Extend_*.lua` files) retain the old hand-written 9-line `setmetatable` + `__index` template. The Druid's `new()` method at line 33-46 contains the exact pattern that `classMetatable` was designed to replace. This creates inconsistency — the factory exists but is not used everywhere it could be. The commented-out impl hints at lines 29-31 (`self.__index = self`, `setmetatable(obj, self)`) are vestigial notes from the same legacy pattern.

**Impact:** No runtime bug, but it defeats the purpose of the factory. If `classMetatable`'s semantics are ever improved or extended, the Druid (and other SM_Extend files) will miss the benefit. Any future bug fix to `classMetatable` would not automatically propagate to Druid.

**Fix:** Replace lines 29-46 with:
```lua
setmetatable(obj, macroTorch.classMetatable(self, "DRUID_FIELD_FUNC_MAP"))
```
Remove the 3 commented-out impl hint lines and the 13-line handwritten metatable block.

### WR-03: `build.sh` does not guard against missing `build_order.txt`

**File:** `build.sh:21`
**Issue:** The redirection `< build_order.txt` on line 21 has no preceding existence check. If `build_order.txt` is accidentally deleted or renamed, the script fails with "No such file or directory" and `SM_Extend.lua` may be created as an empty file (because lines 5-7 delete and recreate it) or retain stale content from a previous run (if `rm` was not reached on a re-run).

**Fix:** Add a guard before the while loop:
```bash
if [ ! -f build_order.txt ]; then
    echo "build_order.txt not found" >&2
    exit 1
fi
done < build_order.txt
```

---

## Info

### IN-01: `SM_Extend.lua` output starts with a leading blank newline

**File:** `build.sh:18`
**Issue:** The `printf '\n'` on line 18 runs before concatenating the first file, inserting a blank line at the start of `SM_Extend.lua`. While syntactically valid Lua (verified via `loadfile`), it adds unnecessary whitespace and makes the output file look empty at first glance. The original `build.sh` did not produce this leading newline.

**Fix:** Skip the newline separator for the first file. Track whether any file has been written:
```bash
local first=1
...
if [ -f "$line" ]; then
    if [ "$first" = 1 ]; then
        first=0
    else
        printf '\n' >> "$target"
    fi
    cat "$line" >> "$target"
fi
```
Or more simply, remove the `printf '\n'` and append one after each `cat` (without the leading one):
```bash
cat "$line" >> "$target"
printf '\n' >> "$target"
```
This produces a trailing newline instead of a leading one, which is more conventional.

### IN-02: `onPeriodicUpdate` timing logic uses stale `frame.lastUpdate` from external scope

**File:** `core/periodic.lua:99`
**Issue:** Each task in `onPeriodicUpdate()` is checked against `GetTime() - frame.lastUpdate >= task.interval`. Since `frame.lastUpdate` is only updated after `onPeriodicUpdate` returns (line 133), all tasks use the same timestamp. If multiple tasks with different intervals (e.g., 0.1s and 1.0s) are registered, the 1.0s task will still run every 0.1s because the check is against the last OnUpdate tick time, not per-task timestamps.

**Impact:** Currently all registered tasks use `interval = 0.1`, so no bug manifests. But the API accepts arbitrary intervals, and if a task with `interval = 1.0` is registered, it will run every ~0.1s instead of every 1.0s.

**Fix:** Store per-task `lastRun` timestamps:
```lua
-- In registerPeriodicTask:
task.lastRun = 0
-- In onPeriodicUpdate:
if GetTime() - task.lastRun >= task.interval then
    task.lastRun = GetTime()
    ...
end
```
Remove the global `frame.lastUpdate` check or keep it as an additional rate limiter.

### IN-03: Redundant commented-out code in `battle_event_queue.lua` suggests incomplete cleanup

**File:** `battle_event_queue.lua:47, 58-59, 68, 113, 119, 131-135, 375-394`
**Issue:** Several blocks of commented-out event registrations (`PLAYER_LOGIN`, `PLAYER_DEAD`, `CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS`, `RAW_COMBATLOG`) and event handler logic remain. These are not part of the Phase 01 migration scope but represent technical debt that could interfere with Phase 02's event system split. The commented-out `UI_ERROR_MESSAGE` debug logging (lines 138-139) is particularly noisy.

**Impact:** Code clarity; no runtime impact. Different from the `-- impl hint` comments in Druid which serve as migration markers.

**Fix:** Remove commented-out dead code or tag with explicit `-- Phase 2 will restore` markers for blocks intended to be re-enabled in future phases. The Phase 02 plan should explicitly handle these.

---

_Reviewed: 2026-06-08T02:40:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_