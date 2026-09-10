# Druid _castSpell Fix -- Human UAT Checklist

**Phase:** 06 -- Fix Druid _castSpell isSpellReady nil bug (colon/dot syntax mismatch)
**Date:** 2026-06-14
**Prerequisites:**
- WoW 1.12.1 (Turtle WoW) client running
- macro-torch addon loaded with Phase 6 fixes applied
- `./build.sh` completed successfully
- Character: Level 20+ Druid with Cat Form, Bear Form, and healing spells trained
- A target dummy or hostile mob nearby for Type A tests

---

## Pre-Test: Self-Test Verification

- [ ] Run `/mt` in chat
- [ ] Verify summary line shows: `[macro-torch] Self-test: N passed, 0 failed, M warnings`
- [ ] Verify all Category F tests passed (no red "FAIL: F:" messages)
- [ ] If any Category F test failed, stop UAT -- bug fix is incomplete

---

## Type A: Enemy-Target Skills (auto-targets current enemy)

**Setup:** Target a hostile mob or training dummy. Ensure you are in melee range.

### Mode: 'ready' (cooldown check only -- casts if spell is off cooldown)

- [ ] **claw('ready')** -- `/run macroTorch.player.claw('ready')` -- Casts Claw on target if off cooldown
- [ ] **shred('ready')** -- `/run macroTorch.player.shred('ready')` -- Casts Shred on target if off cooldown (requires behind target for full effect, but cast should still fire)
- [ ] **rake('ready')** -- `/run macroTorch.player.rake('ready')` -- Casts Rake on target if off cooldown
- [ ] **rip('ready')** -- `/run macroTorch.player.rip('ready')` -- Casts Rip on target if off cooldown (requires combo points to do anything)
- [ ] **ferocious_bite('ready')** -- `/run macroTorch.player.ferocious_bite('ready')` -- Casts Ferocious Bite on target if off cooldown
- [ ] **faerie_fire_feral('ready')** -- `/run macroTorch.player.faerie_fire_feral('ready')` -- Casts Faerie Fire (Feral) on target if off cooldown

### Mode: 'safe' (range + resource checks before casting)

- [ ] **claw('safe')** -- `/run macroTorch.player.claw('safe')` -- Casts Claw only if in melee range and has enough energy
- [ ] **shred('safe')** -- `/run macroTorch.player.shred('safe')` -- Casts Shred only if in melee range and has enough energy
- [ ] **rip('safe')** -- `/run macroTorch.player.rip('safe')` -- Casts Rip only if in range and has >=30 energy

### Mode: 'raw' (no checks -- always attempts to cast)

- [ ] **claw('raw')** -- `/run macroTorch.player.claw('raw')` -- Always attempts Claw cast (may show "not ready yet" error which is expected if on cooldown)
- [ ] **shred('raw')** -- `/run macroTorch.player.shred('raw')` -- Always attempts Shred cast
- [ ] **rake('raw')** -- `/run macroTorch.player.rake('raw')` -- Always attempts Rake cast
- [ ] **ferocious_bite('raw')** -- `/run macroTorch.player.ferocious_bite('raw')` -- Always attempts Ferocious Bite cast

### Verification Checklist for Type A

- [ ] No Lua errors appear in chat when calling any skill method
- [ ] Skills successfully cast when off cooldown and in range (you see the cast bar or spell animation)
- [ ] 'ready' mode properly checks cooldown (skill not cast when on cooldown)
- [ ] 'safe' mode properly checks range (skill not cast when out of range)
- [ ] 'safe' mode properly checks resource (skill not cast when insufficient energy)

---

## Type B: Self-Target Skills (always casts on player)

**Setup:** Ensure you are out of combat. No target needed.

### Mode: 'ready' (cooldown check only)

- [ ] **cat_form('ready')** -- `/run macroTorch.player.cat_form('ready')` -- Shifts to Cat Form if off cooldown
- [ ] **bear_form('ready')** -- `/run macroTorch.player.bear_form('ready')` -- Shifts to Bear Form if off cooldown (shift out of cat first)
- [ ] **prowl('ready')** -- `/run macroTorch.player.prowl('ready')` -- Activates Prowl (stealth) if in Cat Form and off cooldown
- [ ] **tiger_fury('ready')** -- `/run macroTorch.player.tiger_fury('ready')` -- Activates Tiger's Fury self-buff if off cooldown

### Mode: 'safe' (range + resource checks)

- [ ] **cat_form('safe')** -- `/run macroTorch.player.cat_form('safe')` -- Shifts to Cat Form (self-target has no range restriction; resource check applies if cost > 0)
- [ ] **tiger_fury('safe')** -- `/run macroTorch.player.tiger_fury('safe')` -- Activates Tiger's Fury only if has enough energy for computeTiger_E()

### Mode: 'raw' (no checks -- always attempts)

- [ ] **cat_form('raw')** -- `/run macroTorch.player.cat_form('raw')` -- Always attempts Cat Form shift
- [ ] **tiger_fury('raw')** -- `/run macroTorch.player.tiger_fury('raw')` -- Always attempts Tiger's Fury

### Verification Checklist for Type B

- [ ] No Lua errors appear in chat when calling any self-target skill
- [ ] Form shifts work correctly (character model changes)
- [ ] Self-buffs apply correctly (buff icon appears on player frame)
- [ ] 'safe' mode properly respects resource checks (tiger_fury not cast when insufficient energy)

---

## Type C: Flexible-Target Skills (onSelf parameter controls target)

**Setup:** Target a friendly NPC or no target (self-target mode as fallback).

### Mode: 'ready' -- Self-target (onSelf=true)

- [ ] **healing_touch('ready', true)** -- `/run macroTorch.player.healing_touch('ready', true)` -- Casts Healing Touch on self if off cooldown
- [ ] **rejuvenation('ready', true)** -- `/run macroTorch.player.rejuvenation('ready', true)` -- Casts Rejuvenation on self if off cooldown
- [ ] **mark_of_the_wild('ready', true)** -- `/run macroTorch.player.mark_of_the_wild('ready', true)` -- Casts Mark of the Wild on self if off cooldown

### Mode: 'ready' -- Target a friendly unit (onSelf=false)

- [ ] **healing_touch('ready', false)** -- `/run macroTorch.player.healing_touch('ready', false)` -- Casts Healing Touch on current target if off cooldown
- [ ] **mark_of_the_wild('ready', false)** -- `/run macroTorch.player.mark_of_the_wild('ready', false)` -- Casts Mark of the Wild on current target if off cooldown

### Mode: 'safe' -- Self-target with range check

- [ ] **healing_touch('safe', true)** -- `/run macroTorch.player.healing_touch('safe', true)` -- Casts Healing Touch on self if in range (40yd) and has mana

### Mode: 'raw' -- Self-target no checks

- [ ] **healing_touch('raw', true)** -- `/run macroTorch.player.healing_touch('raw', true)` -- Always attempts Healing Touch on self
- [ ] **mark_of_the_wild('raw', false)** -- `/run macroTorch.player.mark_of_the_wild('raw', false)` -- Always attempts MotW on current target

### Verification Checklist for Type C

- [ ] No Lua errors appear in chat when calling any flexible-target skill
- [ ] onSelf=true correctly casts on the player (heal/buff appears on player frame)
- [ ] onSelf=false correctly casts on current target
- [ ] Range check works in 'safe' mode (40yd for healing spells, 30yd for MotW)

---

## Integration Test: One-Button Macro (catAtk)

**Setup:** Bind catAtk to a key. Target a hostile mob. Enter Cat Form.

- [ ] Press the bound key repeatedly while in combat with a mob
- [ ] Verify: skills fire automatically (claw, shred, rake, rip, ferocious_bite as appropriate)
- [ ] Verify: no Lua errors appear in chat during the entire combat
- [ ] Verify: combo points build up and are consumed correctly
- [ ] Verify: Cat Form skills actually land on target (check damage numbers / debuffs)

---

## Regression Check: Existing Functionality

- [ ] **External isSpellReady call** -- `/run local r = macroTorch.player.isSpellReady('Claw'); macroTorch.show(tostring(r))` -- Shows true or false (not nil, not an error)
- [ ] **External cast call** -- `/run macroTorch.player.cast('Claw', false)` -- Casts Claw on target if available
- [ ] **safeFF function works** -- In cat form, target a hostile mob: `/run macroTorch.safeFF({})` -- Should show FF log message and cast FF if conditions met
- [ ] **Hunter class unaffected** -- If you have a Hunter alt, verify `/run local p = macroTorch.player; p.cast('Auto Shot', false)` works correctly (dot syntax unchanged)

---

## Results Summary

| Category | Pass/Fail | Notes |
|----------|-----------|-------|
| Pre-test /mt | [ ] | |
| Type A: ready | [ ] | |
| Type A: safe | [ ] | |
| Type A: raw | [ ] | |
| Type B: ready | [ ] | |
| Type B: safe | [ ] | |
| Type B: raw | [ ] | |
| Type C: ready | [ ] | |
| Type C: safe | [ ] | |
| Type C: raw | [ ] | |
| Integration (catAtk) | [ ] | |
| Regression | [ ] | |

---

## Sign-Off

- [ ] All categories pass: ALL boxes checked
- [ ] No Lua errors during any test
- [ ] UAT completed by: _______________
- [ ] Date: _______________

---

## Phase 28: catAtk claw/shred/bite 伤害打桩 -- 实机 UAT 闭环

**Phase:** 28 -- catAtk claw/shred/bite damage instrumentation（打点开关 + 离线分析器）
**Date:** 2026-09-08
**目标:** 在游戏机完成一次完整闭环：开开关 → 打骷髅木桩约 1 分钟 → 脱战 → ReloadUI → 拷回 SuperMacro.lua → `tools/cpdamage.lua` 出两层统计报表与决策建议行。

### 1. Prerequisites（前提）

- [ ] WoW 1.12.1（Turtle WoW）+ SuperWoW 客户端（RAW_COMBATLOG 采集依赖 SuperWoW）
- [ ] `./build.sh` 构建成功（SM_Extend.lua 重建无报错）
- [ ] 至少一个可运行的 lua 解释器（理想：Lua 5.0 一个 + 5.1 以上一个，Cygwin 环境即有）
- [ ] 可攻击的 Training Dummy（骷髅级即可）
- [ ] 建议游戏内先执行 `/run macroTorch.LOG_MAX_SIZE=3000`（本次记录量增大，防止 500 条默认环被顶掉，D-10）

### 2. Pre-Test（自测预检）

- [ ] 在两个解释器上各跑一次 `lua tools/cpdamage.lua --selftest`，期望末行 `selftest: ALL N PASSED`（无任何 FAIL 行）
- [ ] 游戏内 `/mt`：期望自检汇总无红色 FAIL；Category U 9 条全过（非 U 条目的黄色 warnings 可容忍）
- [ ] 登录横幅含第 5 项 `macroTorch.cpDamageLog = false`（D-06 开关可见性确认）

### 3. SavedVariables 声明确认（RESEARCH A2）

游戏机端实际部署的 SuperMacro 变体 .toc 必须含 `MACRO_TORCH_LOG` 声明，否则打点静默零持久化：

- [ ] 打开 `WTF/Account/<账号>/SavedVariables/SuperMacro.lua`，确认存在 `MACRO_TORCH_LOG` 段
- [ ] 缺失的修复：在该变体 SuperMacro.toc 的 `## SavedVariables:` 行末补一个空格加 `MACRO_TORCH_LOG`，然后**完全退出游戏**重进（仅 /reload 不够），再回到本清单第 4 节重测

### 4. 打桩协议（实机采集）

1. `/run macroTorch.cpDamageLog=true`
2. 用 catAtk 正常循环打骷髅级 Training Dummy 约 1 分钟（claw/shred/bite 都会自然出现）
3. 可补手动命令确保三技能都有样本：`/run macroTorch.player.claw('ready')` / `/run macroTorch.player.shred('ready')` / `/run macroTorch.player.ferocious_bite('ready')`
4. 停手等待脱战（木桩场景约 5s 自动脱战 = 批次结束，D-11）
5. `/reload`
6. 从 `WTF/Account/<账号>/SavedVariables/SuperMacro.lua` 拷出文件

### 5. 分析运行

`lua tools/cpdamage.lua <拷出的 SuperMacro.lua 路径> --json-out <归档 json 路径>`

- [ ] 每批次（batch）节 + 聚合（aggregate）节出现 claw/shred 四档表（bleedCount 0/1/2/3）
- [ ] OOC 背位分档表（isOoc 且 isBehind 样本）
- [ ] bite 回归节（a / b / n 三值）
- [ ] 三类决策建议行：每档 builder 选择 / OOC 技能选择 / bite 泄能与否
- [ ] 条目 ≥ 30 且 claw/shred/bite 三技能齐；坏行计数 0（或极小）

### 6. Expected Outcomes / Troubleshooting（期望结果与排查）

- [ ] 条目 11 字段数值合理：dmg 为正值；e 约在 42/54/35 附近（claw = 45 − Idol of Ferocity − Ferocity 天赋；shred = 60 − Improved Shred×6；bite = 门槛常量 35）
- [ ] 无 `[cpDamage]` 行时按序排查：① 先查 .toc 声明（第 3 节）② 查开关在 /reload 前是否仍为 true（每次 login/reload 复位默认 false，D-06）③ 查 GCD probe 黄色警告（Rake 法术必须在动作条上，否则不采集）
- [ ] crit 全 false 或缺 crit 时：记录客户端语言环境（非英文客户端 hits/crits 句式不同，A3 假设）

**完成信号:** 四项闭环全部达成（或按 Troubleshooting 修复后达成）；将第一张真实统计表的批量打印（或 --json-out 归档路径）回复给 verifier，由 verifier 汇入阶段末 28-UAT.md。

---

## Phase 29: 统一 landing 判定重构 -- 实机 UAT 闭环

**Phase:** 29 -- 统一 landing 判定重构（三通道 OR 证据 + 反推兜底 + cast 谓词去重 + 可配 intentTtl）
**Date:** 2026-09-10
**目标:** 在游戏机完成重建与实机观察闭环：确认统一 landing 通道在单人木桩与（选做）多猫场景的落地通告行为，验证 fail-wins 否决、猎人钉刺弹道窗与反推兜底观感。

### 1. Prerequisites（前提）

- [ ] WoW 1.12.1（Turtle WoW）+ SuperWoW 客户端
- [ ] Windows+Cygwin 下 `./build.sh` 成功重建 SM_EXTEND.lua（产物落盘后版控外生效）
- [ ] 无需新增 SavedVariables 声明（沿用现有 SM 变体 .toc）
- [ ] `macroTorch.LOG_MAX_SIZE` 若上次调过则保持一致即可

### 2. Pre-Test（自测预检）

- [ ] 游戏内 `/mt`：全部自检无红色 FAIL（Category Q 16 条全过：Q-01..Q-16；非 Q 可选项的黄色 warning 可容忍）
- [ ] 登录横幅仍为 CONFIG_OPTIONS 4 项（本 phase 未增删配置项）

### 3. 单人木桩

- [ ] catAtk 循环打骷髅 1 分钟观察：Rake / Ferocious Bite 恒绿『landed』
- [ ] Pounce / Rip 出现绿色『landed』或偶发蓝色『landed ... (inferred)』均可接受
- [ ] 无『failed on』红行
- [ ] 无 Rip 持续重放（ripLeft 正常启动即为通过）

### 4. 多猫同目标（远程网友合作且对方零配置要求时选做）

- [ ] 我方 Rip 后观察 ~1 秒内出现蓝色 `(inferred)` 兜底通告（apply 行被抑制时此通道仍交付落地）
- [ ] ripLeft 启动且不再每帧重放 Rip
- [ ] 对方技能行不触发我方任何通告（guid 归属检查）

### 5. 猎人钉刺（hunter 角色）

- [ ] Serpent / Scorpid Sting 落地仍可见（绿色配对或蓝色推断）
- [ ] 远程位钉刺在 ~2 秒窗内正常落地

### 6. Expected Outcomes / Troubleshooting（期望结果与排查）

- [ ] a) Rip 全绿无蓝：apply 未被抑制，正常（抑制仅多猫场景）
- [ ] b) 蓝色推断后紧跟红色『was cancelled by ...』：windowed fail 否决在生效，属 fail-wins 预期
- [ ] c) 无任何 land 通告：查 tracingSpells 注册与 SuperWoW RAW 通道、查 `/mt` Q 段
- [ ] 注记（D-17）：cpDamage 伤害配对零结构改动，其配对窗随全局默认 `macroTorch.LAND_INTENT_TTL = 0.9` 自动生效（claw/shred/bite 全近战，0.9 足够）
- [ ] 注记（D-18 锁定）：远程钉刺的蓝色推断锚偏早于真实 apply 约一个飞行时间（保守提前重挂、不留空窗），本版本接受为最终形态、不做 anchorBias

**完成信号:** 六节清单全部勾选（多猫节无合作条件时视为通过）；将观察结果（/mt 汇总行、木桩与钉刺的通告样例）回复给 verifier，由 verifier 汇入阶段末 29-UAT.md。