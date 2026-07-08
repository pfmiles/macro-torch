# Phase 19: druidControl Bash Split to druidCharge - Research

**Researched:** 2026-07-08
**Domain:** Lua (WoW 1.12.1 addon) — druid bear-form ability routing refactoring
**Confidence:** MEDIUM (codebase-verified patterns: HIGH; WoW ability mechanics: LOW)

## Summary

Phase 19 is a pure code refactoring within the existing macro-torch addon. It has two objectives: (1) extract the Bash (猛击) interrupt logic from `druidControl()` into a new standalone `druidCharge()` method with distance-driven Feral Charge/Bash dual-branch, and (2) simplify `druidControl()` to only handle Hibernate/Entangling Roots.

No external packages, no new dependencies, no database migrations. The phase modifies two existing files (`combo.lua` for the logic changes, `selftest.lua` for new self-test registrations) and adds zero new files. The build system (`build_order.txt`) requires no changes since `combo.lua` is already listed.

**Primary recommendation:** Follow the established patterns from `druidDefend()` (form check + auto-switch + return) and catLeveling/isSpellExist guard patterns (silent skip when skill not learned). The druidCharge structure is: target check -> form check (auto-switch to bear) -> isSpellExist guards -> distance branch (>=8: Charge, <8: Bash).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01: 职责范围** — druidCharge 同时包含 Feral Charge 和 Bash，按目标距离分两个 if-else 分支。两者之间不是 combo 关系（不需要 Charge 完再 Bash），而是纯粹的距离判定：远距离用 Charge 接近，近距离用 Bash 打断。**共同逻辑：** 形态检查+自动切熊、isSpellExist guard。
- **D-02: 距离分支（两段）** — `>= 8 码 → Feral Charge`，`< 8 码 → Bash`。超过 Feral Charge 最大范围（25码）属于正常释放失败（技能方法自带 range check），不需要在 druidCharge 中特殊处理。
- **D-03: 形态自动切换** — druidCharge 检测不在熊/巨熊形态时，自动 `bear_form('ready')`（或 `dire_bear_form('ready')`），本次按键 return（等待切形态），下次按键再执行 Charge/Bash。与 druidDefend/druidHeal 的形态切换模式一致。
- **D-04: 练级适配** — 所有技能调用前加 `isSpellExist` guard：Bash 需要 10 级（熊形态），Feral Charge 需要野性天赋 20 点。技能不存在时静默 return，不报错。与 Phase 13/16 模式一致。
- **D-05: 独立方法** — `macroTorch.druidCharge()` 是独立全局一键宏方法，与 `macroTorch.druidControl()` 平级。用户绑定不同按键分别触发。
- **D-06: 删除 Bash 分支** — 从 druidControl 中删除原有的 `< 8 码 → Bash` 完整 if 分支。Bash 相关逻辑全部迁移到 druidCharge。
- **D-07: 仅保留控制技能** — 剩余逻辑：`isBeastOrDragonkin() → Hibernate`，`else → Entangling Roots`。两者都在人形态释放，不需要形态检查/切换。
- **D-08: 不自动切形态** — druidControl 保持当前行为：不检查形态、不自动切换形态。如果玩家在熊/猫形态按控制键，Hibernate/Entangling Roots 会因为形态不符自然失败（WoW 原生行为），由玩家自行取消形态后再按。

### Claude's Discretion

- druidCharge 内部代码结构：形态检查→isSpellExist guard→距离判断→技能释放的具体编排顺序
- Feral Charge 最小距离（8码边界情况）的精确处理（`>= 8` vs `> 8`）
- Bash CD 检查是否加入（当前 druidControl 用 `'ready'` 模式，内部已含 CD 检查）
- 切熊形态时优先 Dire Bear Form（若可用）还是普通 Bear Form
- druidControl 删 Bash 分支后的完整代码结构（是否需要增加 isSpellExist guard 给 Hibernate/Entangling Roots）
- SelfTest 注册：具体用例数量、覆盖 druidCharge 存在性+druidControl Bash 分支已删除的验证

### Deferred Ideas (OUT OF SCOPE)

- **旋风（Cyclone）集成**: Turtle WoW 新增技能，可考虑未来加入 druidControl
- **熊形态控制技能扩展**: Demoralizing Roar（挫志咆哮）、Challenging Roar（挑战咆哮）、Growl（低吼）等熊形态技能可各自成方法
- **druidCharge 加入 catLeveling 路由**: 练级版 druidAtk 是否在特定场景自动调用 druidCharge
- **Feral Charge + Bash 真 combo 模式**: 如果 Charge 成功接近目标，是否在同一次按键中自动接 Bash（需要突破"一次一个动作"原则，需 OnUpdate 延迟执行）
- **druidControl isSpellExist guard**: 如果练级阶段 druidControl 也需要技能存在性检查（Hibernate 需要 18 级）
</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| druidCharge (bear charge/bash) | API / Backend | — | All logic runs in Lua inside WoW addon; one-button macro pattern — single key press, no client-side state |
| druidControl (CC skills only) | API / Backend | — | Same one-button macro pattern; purely Lua-side branching on target type |
| Form detection (isInBearForm) | API / Backend | — | Reads WoW unit state via `UnitMana`/`isFormActive`; no client rendering |
| Skill existence check (isSpellExist) | API / Backend | — | Pure spellbook index lookup via `GetSpellName` |
| Self-test registration | API / Backend | — | `PLAYER_ENTERING_WORLD` event-driven; runs in Lua |

**Note:** This is a single-tier WoW addon — all logic runs in the Lua VM embedded in the WoW client. There is no browser tier, no database tier, and no server-side component.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WoW 1.12.1 Lua API | N/A (embedded) | Game interaction (UnitClass, CastSpell, etc.) | Only available runtime |
| macroTorch framework | Current (Phase 18) | Metatable OO, spell tracing, self-test | Project's own framework |
| SuperWow addon | N/A | UNIT_CASTEVENT, UnitXP distance API | Required dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SuperMacro addon | N/A | Extended macro length | Required for SM_Extend.lua loading |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `druidCharge` as new method | Keep Bash in druidControl | Loses dedicated charge keybind; less intuitive for players who want separate charge vs. CC keys |
| Form auto-switch via CancelShapeshiftForm | Current druidDefend pattern | CancelShapeshiftForm + recast is less predictable than explicit bear_form() call |

**Installation:** No external packages. All dependencies are WoW addons installed client-side.

**Version verification:** Not applicable — no npm/PyPI/crates packages used.

## Package Legitimacy Audit

Not applicable — this phase installs zero external packages. It modifies existing Lua files within the project.

## Architecture Patterns

### System Architecture Diagram

```
Key Press (druidCharge, user-bound)
    |
    v
[1. Target Check]
    |-- not isCanAttack? -> targetEnemy() -> if still not canAttack? -> return
    |-- isCanAttack? -> continue
    v
[2. Form Check]
    |-- not isInBearForm? -> dire_bear_form('ready') or bear_form('ready') -> RETURN (wait for next press)
    |-- isInBearForm? -> continue
    v
[3. Skill Existence Guard]
    |-- distance >= 8 AND not isSpellExist("Feral Charge")? -> return
    |-- distance < 8 AND not isSpellExist("Bash")? -> return
    |-- relevant skill exists? -> continue
    v
[4. Distance Branch]
    |-- distance >= 8? -> feral_charge('safe')  (range=25, GCD check, energy check)
    |-- distance < 8?  -> bash('ready')           (CD check, rage check, no range check)
    v
RETURN (one action per press)

---

Key Press (druidControl, user-bound)
    |
    v
[1. Target Check]  (same as before)
    |
    v
[2. Target Type Branch]
    |-- isBeastOrDragonkin()? -> hibernate()
    |-- else?                  -> entangling_roots()
    v
RETURN
```

### Recommended Project Structure
```
classes/druid/
├── combo.lua          # MODIFIED: druidControl (Bash branch removed) + new druidCharge
├── Druid.lua          # READ-ONLY: bash(), feral_charge(), bear_form(), dire_bear_form()
└── ...
core/
└── selftest.lua       # MODIFIED: new Category M self-test registrations
```

**No new files created.** druidCharge is added in combo.lua immediately after druidControl.

### Pattern 1: Form Auto-Switch (druidDefend precedent)

**What:** Check form state, switch form if needed, return to wait for next key press.
**When to use:** Any druid ability method that requires a specific form.
**Example:**
```lua
-- Source: classes/druid/combo.lua:244-246 (druidDefend)
if not macroTorch.player.isInBearForm then
    macroTorch.player.dire_bear_form('ready')
    return
end
```
**Key:**
- `isInBearForm` returns true for both Bear Form AND Dire Bear Form [VERIFIED: codebase — Druid.lua:331-332]
- `dire_bear_form('ready')` checks if the skill is available before casting (mode='ready' = readiness check only)
- `return` ensures "one action per press" — the next key press will execute the business logic

### Pattern 2: isSpellExist Guard (Phase 13/16/17 precedent)

**What:** Guard every skill call with `isSpellExist()` to avoid errors when skill is not yet learned.
**When to use:** Any method that may be used below max level or without required talents.
**Example:**
```lua
-- Source: biz_util.lua:63-65
function macroTorch.isSpellExist(spellName, bookType)
    return macroTorch.toBoolean(macroTorch.getSpellIdByName(spellName, bookType))
end
```
**Usage pattern:**
```lua
-- Source: catLeveling pattern (Phase 16)
if macroTorch.isSpellExist("Bash") then
    -- skill exists, proceed
else
    -- silently skip
end
```
**Key:**
- Uses spellbook index lookup — each character's spellbook is independent
- Returns nil/false when the spell is not in the player's spellbook [VERIFIED: codebase — biz_util.lua:64]
- `bookType` defaults to `'spell'` (omit for standard spells)

### Pattern 3: _castSpell Mode Semantics

**What:** Three modes control what checks _castSpell runs.
**When to use:** Choosing the right mode for each skill call.

| Mode | Spell Ready? | In Range? | Has Resource? | Casts? | Use Case |
|------|-------------|-----------|---------------|--------|----------|
| `'raw'` | No check | No check | No check | Yes | Unconditional cast (track humanoids) |
| `'ready'` | Yes (`isSpellReady`) | No check | No check | Yes | CD/charge availability check only |
| `'safe'` (default, nil) | Yes | Yes (`_isInRange`) | Yes (`_hasResource`) | Yes | Full validation before cast |

**Source:** [VERIFIED: codebase — Player.lua:42-75]
**For druidCharge:**
- `feral_charge('safe')` — range=25 is passed; _castSpell checks both range AND GCD/cooldown
- `bash('ready')` — range=nil (melee); 'ready' mode ensures CD is checked but skips distance check (melee is always in range)

### Pattern 4: Target Check + targetEnemy Fallback

**What:** All combo methods start with the same target acquisition guard.
**When to use:** All global combo macro methods (druidAtk, druidControl, druidDefend, etc.)
**Example:**
```lua
-- Source: classes/druid/combo.lua:254-262 (current druidControl)
local target = macroTorch.target
if not target.isCanAttack then
    macroTorch.player.targetEnemy()
    if not target.isCanAttack then
        return
    end
end
```
**Key:**
- `isCanAttack` is a field function in Unit.lua that checks hostility
- `targetEnemy()` tries: target-of-target friendly assist -> clear+target nearest -> fall through [VERIFIED: codebase — Player.lua:238-247]
- Re-check after targetEnemy because it may fail (no enemies nearby)

### Anti-Patterns to Avoid

- **Mixing 'ready' and 'safe' modes incorrectly:** 'ready' skips resource checks — using it for Feral Charge would skip the 25-yard range check. 'safe' includes both range AND resource checks — using it for Bash (melee, rage) would fail if the target is out of melee range. Use 'safe' for Charge, 'ready' for Bash. [VERIFIED: codebase — Player.lua:42-75]
- **Auto-switching without return:** If you call `bear_form('ready')` without the subsequent `return`, the method falls through to the Charge/Bash call which will fail because you're not in bear form yet. Always pair form switch with return. [VERIFIED: codebase — combo.lua:245-246]
- **Using `#` operator:** WoW 1.12.1 embedded Lua does not support the `#` unary length operator. Use `macroTorch.tableLen(tbl)` or `table.insert(tbl, val)`. [VERIFIED: codebase — CLAUDE.md, impl_util.lua]
- **Form check before target check:** If target check comes after form check, you waste effort checking/switching form when there's no valid target. Always check target first, then form. [VERIFIED: codebase — druidDefend at combo.lua:238 does Barskin first (no target needed), but druidCharge needs target for Charge/Bash]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bear form detection | Manual isFormActive() calls | `macroTorch.player.isInBearForm` | Already handles Bear+Dire Bear OR logic |
| Feral Charge distance check | Manual distance comparison | `feral_charge('safe')` with range=25 | _castSpell('safe') mode handles _isInRange automatically |
| Bash CD/cooldown check | Manual GetSpellCooldown() | `bash('ready')` | 'ready' mode checks isSpellReady internally |
| Skill existence check | Manual spellbook traversal | `macroTorch.isSpellExist(spellName)` | Single call, uses getSpellIdByName |
| Dalayed follow-up action | OnUpdate timer for Charge->Bash | Single action per press | Deferred — out of scope; violates "one action per press" |
| Form switching + cast in one press | CancelShapeshiftForm + CastSpell | form_check -> switch -> return, then cast on next press | Two-press pattern is predictable and matches druidDefend/druidHeal precedent |

**Key insight:** The existing macroTorch framework already solves all the sub-problems in this phase. druidCharge is a composition of existing primitives (isInBearForm, isSpellExist, _castSpell modes, distance field, targetEnemy). Nothing needs to be built from scratch.

## Common Pitfalls

### Pitfall 1: Breaking "one action per press"

**What goes wrong:** Form switch + Charge in the same key press. The form switch initiates a cast (GCD starts), and the Charge call in the same execution frame will fail because you haven't completed the form change yet.
**Why it happens:** Druid form changes take 1.5s GCD. The GCD applies server-side; the addon can issue two CastSpell calls but the second will be ignored.
**How to avoid:** Always `bear_form('ready') + return` pattern. The next key press triggers the method again, `isInBearForm` is now true, and Charge/Bash proceeds.
**Warning signs:** Charge/Bash never fires after form switch — always returns false.

### Pitfall 2: `>= 8` vs `> 8` boundary

**What goes wrong:** Feral Charge has a minimum range of 8 yards in WoW Classic [ASSUMED]. If the target is exactly at 8 yards (boundary case), `>= 8` sends Charge but `> 8` would send Bash. The wrong choice causes unnecessary form-switch-then-Bash or Charge-at-too-close-range.
**Why it happens:** Distance measurements in WoW are floating-point and boundary cases are rare but real.
**How to avoid:** Use `>= 8` for Charge branch, `< 8` for Bash branch (per D-02). This means exactly 8 yards goes to Charge. If Charge fails due to minimum range, the player presses again (now closer) and Bash fires.
**Warning signs:** Feral Charge consistently failing at close range.

### Pitfall 3: isSpellExist guard ordering

**What goes wrong:** Placing the form check AFTER the isSpellExist guard means the code switches to bear form even when the skill doesn't exist (e.g., below level 10, Bash not yet learned) — pointless form switch with no follow-up.
**Why it happens:** Logical order of operations matters. If you check skill existence first, you can short-circuit before any form switch.
**How to avoid:** Form check should precede isSpellExist guards. Reasoning: (a) You need to be in bear form to cast either skill, so the form check is a prerequisite; (b) at level 10+ with both skills available, the form check is always needed; (c) at very low levels (<10), neither skill exists — isSpellExist returns false for both, and the method returns harmlessly. The isSpellExist guard after the form check catches the edge case where one skill exists but the other doesn't.
**Warning signs:** Unnecessary form switches at very low levels.

### Pitfall 4: druidControl deleting the wrong branch

**What goes wrong:** Deleting the wrong `if` block or mis-transforming `elseif` to `if` leaving the control flow broken.
**Why it happens:** The current structure is `if (dist<8) bash elseif (beast) hibernate else roots`. Removing the first branch means `elseif` must become `if`.
**How to avoid:** The resulting structure should be:
```lua
if target.isBeastOrDragonkin() then
    macroTorch.player.hibernate()
else
    macroTorch.player.entangling_roots()
end
```
**Warning signs:** Hibernate never triggers, or both Hibernate AND Roots fire.

### Pitfall 5: `isInBearForm` vs `isFormActive('Bear Form')` 

**What goes wrong:** Using `isFormActive('Bear Form')` directly instead of `isInBearForm` misses Dire Bear Form players.
**Why it happens:** `isInBearForm` was added in Phase 7 specifically to handle the OR logic: `isFormActive('Bear Form') or isFormActive('Dire Bear Form')` [VERIFIED: codebase — Druid.lua:331-332].
**How to avoid:** Always use `macroTorch.player.isInBearForm`, never `isFormActive('Bear Form')` directly.
**Warning signs:** Level 40+ druids in Dire Bear Form always trigger unnecessary form switches.

## Code Examples

Verified patterns from official sources:

### Target Check + Form Check + isSpellExist Guard + Distance Branch (druidCharge)

```lua
-- Source: derived from combo.lua:254-262 (druidControl target check),
--        combo.lua:244-246 (druidDefend form switch),
--        catLeveling isSpellExist guard pattern (Phase 16)
function macroTorch.druidCharge()
    local target = macroTorch.target

    -- 1. Target check (same as druidControl)
    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end

    -- 2. Form check (same as druidDefend)
    if not macroTorch.player.isInBearForm then
        if macroTorch.isSpellExist("Dire Bear Form") then
            macroTorch.player.dire_bear_form('ready')
        else
            macroTorch.player.bear_form('ready')
        end
        return
    end

    -- 3. Distance branch with isSpellExist guards
    if target.distance >= 8 then
        if not macroTorch.isSpellExist("Feral Charge") then
            return
        end
        macroTorch.player.feral_charge('safe')
    else
        if not macroTorch.isSpellExist("Bash") then
            return
        end
        macroTorch.player.bash('ready')
    end
end
```

### druidControl After Bash Branch Removal

```lua
-- Source: derived from combo.lua:254-271 (original druidControl, Bash branch removed)
function macroTorch.druidControl()
    local target = macroTorch.target

    if not target.isCanAttack then
        macroTorch.player.targetEnemy()
        if not target.isCanAttack then
            return
        end
    end

    if target.isBeastOrDragonkin() then
        macroTorch.player.hibernate()
    else
        macroTorch.player.entangling_roots()
    end
end
```

### Self-Test Registration Pattern

```lua
-- Source: combo.lua:303-306 (existing druidControl self-test)
macroTorch.SelfTest:register("Druid: combo methods -- druidCharge exists", function()
    if UnitClass('player') ~= 'Druid' then return end
    assert(type(macroTorch.druidCharge) == "function", "druidCharge not a function")
end, true)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bash in druidControl (one key for CC+interrupt) | Bash in druidCharge (separate key); druidControl = CC only | Phase 19 (now) | Better keybind flexibility; charge has auto-form-switch, CC does not |
| No isSpellExist guards in druidControl | druidCharge has isSpellExist guards (Bash: level 10, Charge: 20 feral talent [ASSUMED]) | Phase 19 (now) | Safe at low levels; silent skip instead of error |
| No auto-form-switch for Bash | druidCharge auto-switches to bear form | Phase 19 (now) | One-press form entry; matches druidDefend UX |
| Hibernate/Entangling Roots no form check | Same — D-08: no auto-form-switch for druidControl | Unchanged | Players manually exit form before CC |

**Deprecated/outdated:**
- Using Bash from druidControl: Players should bind druidCharge for Bash/Feral Charge and druidControl for Hibernate/Entangling Roots only.

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Feral Charge minimum range is 8 yards in WoW 1.12.1 / Turtle WoW | Common Pitfalls, State of the Art | If Turtle WoW changed Feral Charge min range, the `>= 8` vs `< 8` threshold may need adjustment |
| A2 | Feral Charge requires 20 points in Feral talent tree (level ~30 minimum) | State of the Art, Code Examples | If Turtle WoW changed talent requirement, isSpellExist guard may fire at wrong level; non-blocking since guard just skips |
| A3 | Bash is learned at level 10 (same level as Bear Form) | State of the Art, Code Examples | If Turtle WoW changed Bash availability level, isSpellExist guard may fire at wrong level; non-blocking |
| A4 | Turtle WoW has not changed Feral Charge or Bash mechanics (range, cooldown, rage cost) from vanilla 1.12.1 | Common Pitfalls | If Turtle WoW made changes, the 'safe'/'ready' modes may behave unexpectedly for these skills |
| A5 | `Dire Bear Form` is learned at level 40; `bear_form('ready')` is an adequate fallback when Dire Bear is unavailable | Code Examples | Form switch may use less optimal bear form if logic is wrong |

**If this table is empty:** Not applicable — all claims in this research were verified or cited — no user confirmation needed.

## Open Questions (RESOLVED)

1. **Feral Charge minimum range in Turtle WoW**
   - What we know: Vanilla WoW 1.12 has Feral Charge at 8-25 yards. The codebase already uses `< 8` for Bash in druidControl, implying 8 is the melee threshold [VERIFIED: codebase — combo.lua:264]
   - What's unclear: Whether Turtle WoW has modified the minimum range
   - Recommendation: Use `>= 8` for Charge, `< 8` for Bash per D-02. If Turtle WoW changed it, the isSpellExist + _castSpell('safe') range check will catch failures gracefully

2. **Should druidControl get isSpellExist guards for Hibernate (level 18) and Entangling Roots (level 8)?**
   - What we know: Hibernate requires level 18, Entangling Roots requires level 8 [ASSUMED]. D-08 says druidControl stays form-agnostic — but skill existence is a separate concern
   - What's unclear: Whether giving druidControl isSpellExist guards would improve low-level UX without violating any decisions
   - Recommendation: Per Deferred Ideas, this is explicitly deferred. Do NOT add isSpellExist guards to druidControl in this phase

3. **Dire Bear Form priority: exact logic for isSpellExist + form selection**
   - What we know: `isInBearForm` already covers both forms. The switch logic should prefer Dire Bear if available
   - What's unclear: Should the code check `isSpellExist("Dire Bear Form")` first, then fall back to `isSpellExist("Bear Form")`, then `bear_form('ready')`? What if both exist but player is already in regular Bear Form — should it upgrade to Dire Bear?
   - Recommendation: Follow druidDefend precedent: call `dire_bear_form('ready')` first; if it fails (skill unavailable), fall back to `bear_form('ready')`. Don't add upgrade logic (regular Bear -> Dire Bear) — keep it simple

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified). This phase is pure Lua code modifications to existing files. All required APIs (UnitClass, CastSpell, GetSpellName, UnitXP) are provided by the WoW 1.12.1 client and SuperWow addon, which are already assumed available by the project.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | macroTorch.SelfTest (in-game Lua self-test framework) |
| Config file | none — SelfTest registrations are inline in source files |
| Quick run command | Login to WoW, `PLAYER_ENTERING_WORLD` triggers SelfTest:run() |
| Full suite command | Same — all tests run on each login |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-19-01 | druidCharge function exists on macroTorch | unit | `SelfTest:register("Druid: combo methods -- druidCharge exists", ...)` | ❌ Wave 0 |
| REQ-19-02 | druidCharge contains no Bash call at distance < 8 without prior form check | unit | Code review verification (not SelfTest checkable — structure validation) | ❌ Wave 0 (manual review) |
| REQ-19-03 | druidControl no longer contains bash('ready') call | unit | `SelfTest:register("Druid: druidControl Bash-free", ...)` — load source, search for 'bash' | ❌ Wave 0 |
| REQ-19-04 | druidControl still has Hibernate + Entangling Roots branches | unit | `SelfTest:register("Druid: druidControl CC methods present", ...)` | ❌ Wave 0 |
| REQ-19-05 | druidCharge includes isSpellExist guard for Feral Charge | unit | Code structure verification via SelfTest | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** N/A (no offline test runner available; in-game testing required)
- **Per wave merge:** N/A
- **Phase gate:** All SelfTest registrations pass on login (green); visual code review of source confirms Bash removed from druidControl

### Wave 0 Gaps
- [ ] SelfTest for `druidCharge` function existence — register in combo.lua alongside existing checks
- [ ] SelfTest for `druidControl` no longer calling `bash()` — register in combo.lua
- [ ] SelfTest for `druidControl` still containing Hibernate + Entangling Roots logic
- [ ] SelfTest for `druidCharge` referencing correct skill methods (bash, feral_charge)

*(All tests are isOptional=true, UnitClass guard for non-Druid logins, following the pattern established by existing combo method self-tests)*

## Project Constraints (from CLAUDE.md)

The following directives from CLAUDE.md apply to this phase:

| Directive | Source | Implication for Phase 19 |
|-----------|--------|--------------------------|
| Use `macroTorch.tableLen(tbl)` instead of `#tbl` | ./CLAUDE.md | No `#` operator in any new code |
| One-button combat rotations — each press creates fresh context | ./CLAUDE.md | druidCharge follows "one action per press" — form switch returns, next press casts |
| Single Point of Truth — extract shared decision logic | ./CLAUDE.md | druidCharge doesn't need to extract shared logic (using existing primitives) |
| Minimize WoW API calls | ./CLAUDE.md | isInBearForm, isSpellExist, and distance are cached/lazy via field functions |
| Keep subclass constructors consistent | .claude/CLAUDE.md | No `ref` field on subclass instances; all resolve through prototype chain |

## Sources

### Primary (HIGH confidence — verified against codebase)
- `classes/druid/combo.lua:238-271` — druidDefend form switch pattern + druidControl current code [VERIFIED: codebase]
- `classes/druid/Druid.lua:66-68` — bash() skill method (10 rage, melee) [VERIFIED: codebase]
- `classes/druid/Druid.lua:82-84` — feral_charge() skill method (25 yd range) [VERIFIED: codebase]
- `classes/druid/Druid.lua:123-130` — bear_form() / dire_bear_form() [VERIFIED: codebase]
- `classes/druid/Druid.lua:331-332` — isInBearForm (Bear OR Dire Bear) [VERIFIED: codebase]
- `entity/Player.lua:42-119` — _castSpell mode semantics (raw/ready/safe) [VERIFIED: codebase]
- `entity/Player.lua:127-143` — _isInRange + _hasResource [VERIFIED: codebase]
- `entity/Player.lua:238-247` — targetEnemy() logic [VERIFIED: codebase]
- `entity/Unit.lua:135-137` — distance field function (UnitXP distanceBetween) [VERIFIED: codebase]
- `biz_util.lua:63-65` — isSpellExist() implementation [VERIFIED: codebase]
- `core/selftest.lua:29-34` — SelfTest:register API [VERIFIED: codebase]
- `combo.lua:273-306` — existing combo method SelfTest registration pattern [VERIFIED: codebase]
- `build_order.txt:25,32` — selftest.lua before combo.lua in build order [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- Phase 18 CONTEXT.md — _spellIdMonitored whitelist mechanism (Bash and Feral Charge are NOT in whitelist, so _castSpell will NOT set current_casting_spell for them — correct behavior) [CITED: 18-CONTEXT.md]
- Phase 16 CONTEXT.md — catLeveling isSpellExist guard pattern precedent [CITED: 16-CONTEXT.md]
- Phase 10 CONTEXT.md — druidControl original design, druidDefend form switch pattern [CITED: 10-CONTEXT.md]

### Tertiary (LOW confidence — assumed, not verified this session)
- WebSearch for WoW 1.12.1 Bash/Feral Charge mechanics — no results returned by search tool. Claims about Bash (level 10, 10 rage, 5 sec CD, melee range) and Feral Charge (8-25 yd, 15 sec CD, 20 feral talent points) are from training data [ASSUMED]
- WebSearch for Turtle WoW differences — no results returned. Assumption that Turtle WoW matches vanilla 1.12.1 for these skills [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external packages; all dependencies are project-internal
- Architecture: HIGH — established patterns from druidDefend, druidControl, catLeveling, all verified in codebase
- Pitfalls: MEDIUM — pitfalls identified from codebase patterns are HIGH confidence; WoW ability mechanics are LOW confidence (unverified this session)
- WoW ability details: LOW — Bash level/talent requirements, Feral Charge min range/talent requirements could not be confirmed via authoritative sources this session

**Research date:** 2026-07-08
**Valid until:** 2026-08-07 (30 days — stable codebase patterns, no external dependencies)