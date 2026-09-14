---
quick_id: 260914-nth
slug: per-2026-09-14-sample-verdict-ooc-frame-
description: "Per 2026-09-14 sample verdict, OoC-frame cp-builder change: on 3+ bleeds, free frames (OoC / pseudo-infinite energy) now use Shred behind; paid frames stay Claw. Druid.lua shouldUseShred branch 3 rewritten (locked comment citing sample evidence); classes/druid/selftest.lua R6-05 rewritten to assert Shred on free frames with a folded getNextAbilityCost SHRED_E-resolve light pin + companion R6-05b paid-frame Claw pin; .planning/catAtk-core-principles.md Rule-6 table row 3 + pseudocode line 3 revised (untracked working-tree-only, never committed, .gitignore:34). Code commit: exactly the two Lua files."
date: 2026-09-14
phase: quick-260914-nth
plan: 260914-nth
type: execute
wave: 1
depends_on: []
files_modified:
  - classes/druid/Druid.lua                    # committed (code)
  - classes/druid/selftest.lua                 # committed (code)
  - .planning/catAtk-core-principles.md        # WORKING-TREE ONLY, never committed (.gitignore:34)
autonomous: true
requirements: ["R6@quick-260914-nth"]
estimate:
  tokens: 32000
  raw_tokens: 16000
  tasks: 3
  confidence: low
must_haves:
  truths:
    - "Druid.lua shouldUseShred branch 3: paid frames (ooc=false AND isPseudoInfiniteEnergy falsy) with 3+ bleeds still return false (Claw) — behavior byte-identical to before; free frames (ooc OR infiniteEnergy) AND isBehind AND NOT isBehindAttackJustFailed return true (Shred), and-chain literally identical to branch 2 (= count 1→2)"
    - "New R6-05 asserts shouldUseShred == true on a 3-bleed ooc+infinite behind ctx, and the folded light pin asserts getNextAbilityCost resolves ctx.SHRED_E (not CLAW_E) on that same ctx under the CR-01 shadow + isKillShotOrLastChance stub"
    - "New R6-05b asserts shouldUseShred == false on a 3-bleed paid-frame ctx (ooc=false, isPseudoInfiniteEnergy=false) — paid-frame coverage preserved"
    - "Both Lua files compile via loadfile under /tmp/luabuild Lua 5.0.3 / 5.1.5 / 5.4.7, and bbcheck prints BALANCED for both (planning-time baselines: both BALANCED)"
    - "Energy-estimation impact argued and net ~= 0: getNextAbilityCost resolves SHRED_E on such frames, but shouldDoReshift (cat.lua:258) and shouldCastFFDuringWaitWindow (Druid.lua:1167) both short-circuit ooc explicitly and never trigger under infinite energy"
    - "Principles doc: exactly 2 locked edits (Rule-6 table row 3 + pseudocode 3-line block), snapshot diff exactly 2 hunks (-3/+4), wc -l 494→495, footer/author/fences untouched, file stays git-ignored and never added"
  artifacts:
    - "/home/admin/workspace/macro-torch/classes/druid/Druid.lua — branch 3: 8 new lines (1 else + 6 comment + 1 return) replacing old 3 lines; net +5"
    - "/home/admin/workspace/macro-torch/classes/druid/selftest.lua — R6-05 rewritten (free-frame assertion + SHRED_E pin), R6-05b added; old R6-05 block fully removed (3-bleed free assertion replaces the false 'always Claw' assertion)"
    - "/home/admin/workspace/macro-torch/.planning/catAtk-core-principles.md — row 3 and pseudocode line 3 revised, working-tree only"
  key_links:
    - "getNextAbilityCost (Druid.lua:1199) step 5 → shouldUseShred branch 3 is the single behavior-delta path the folded pin guards"
    - "Branch 2 and-chain literal (line 1015) becomes shared with branch 3 — GATE 1 pins the absolute count 2"
    - "R6-05 CR-01 ordering: rawset restore + kill-shot stub restore BEFORE the three asserts"
    - "Doc must remain git-ignored: git check-ignore outputs the path; no git add anywhere touches it"
---

# PLAN: OoC 帧 cp-builder 裁决落地 — 3+ 流血免费帧(背后)改撕碎（260914-nth）

## 目标

按 2026-09-14 样本裁决，落地三文件锁定修订：

1. **代码**：`classes/druid/Druid.lua` `shouldUseShred`（970-1019）第 3 分支从 `else return false -- 3+ bleeding always uses Claw` 改为：付费帧(非 ooc 且非无限能量)保持 Claw；免费帧 `(ooc or infiniteEnergy) and isBehind and not isBehindAttackJustFailed` 用 Shred。英文注释引用样本裁决证据（撕碎非暴击单发 507.3 n=124 vs 3 流血爪击 483.5 n=13，等暴击下约 5% 期望差；爪击每多一流血仅 +57）。
2. **测试**：`classes/druid/selftest.lua` 重写 R6-05（原「3+流血无视 OoC/infinite 永远 Claw」断言与新行为矛盾）：改为断言 3 流血 + ooc + infinite + behind → Shred，并**折入轻量 pin**：同一免费帧 ctx 上 `getNextAbilityCost` 析出 `SHRED_E`（非 `CLAW_E`）；新增伴生测试 R6-05b 断言付费帧(ooc=false/infinite=false)仍 Claw，保住付费帧覆盖。
3. **原则文档**（untracked，工作树-only，永不 commit，`.gitignore:34`）：Rule 6 表格第 3 行与伪代码第 3 行改为体现免费帧例外。页脚已是 `2026-09-14`，零改动。

## 背景事实（2026-09-14 规划时现场核实；编辑锚点以此为准，勿另找）

- 工作树 clean；`classes/druid/Druid.lua` = 1772 行，`classes/druid/selftest.lua` = 2318 行，两文件 CR 字节 0（全 LF）。
- **Druid.lua 锚点**：1016-1018 = else/return/end 三行（4 空格缩进）；计数基线：`        return false -- 3+ bleeding always uses Claw` = 1；`(clickContext.ooc or infiniteEnergy) and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed` = 1（仅 1015 分支 2，改后应为 2）。
- **selftest.lua 锚点**：R6-05 = 484-504（共 21 行，TAB 缩进）；R6-06 起于 506。R 系列无注册计数注释（366 行注释无计数）→ 无计数编辑。`isPouncePresent = true` 全文件仅 491 行一处 → 唯一的 3 流血测试 ctx；其余调用 `getNextAbilityCost` 的测试（175/208/245/621/647/679）ctx 均为 ≤2 流血或无 ooc，零影响。R6-01..03 的 rawget 快照纪律模板已就位（393-399 行）。
- **原则文档**：`wc -l` = 494（末行 `*作者：pf_miles*` 无换行符，不得补换行）；`| 3+ | 始终爪击 | 爪击在原始伤害和 DPE 上均超过撕碎 |` = 1（156 行）；`IF  bleedCount >= 3:` = 1（163 行）；`useClaw` = 2（164/191 行，注意此字面量不能用于消旧门）；`git check-ignore .planning/catAtk-core-principles.md` 输出该路径（已忽略）。
- **工具在位**（规划时实测）：三解释器 `/tmp/luabuild/lua-5.0.3/bin/lua`、`/tmp/luabuild/lua-5.1.5/src/lua`、`/tmp/luabuild/lua-5.4.7/src/lua` 对两文件 loadfile 编译通过；Node `/usr/local/bin/node`；`bbcheck.js` = `.planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js`，两文件基线均为 **BALANCED**（全文件门可用，与 49l 的 core/selftest MISMATCH 情形不同）。
- **消费者盘点**：`getNextAbilityCost` 仅 cat.lua:267（shouldDoReshift）与 Druid.lua:1177（shouldCastFFDuringWaitWindow）两个生产消费者，另有 Druid.lua:1678 与 selftest 六处测试调用。

## 能量估算影响论证（必须先读懂，再动手）

改动后，`getNextAbilityCost` 在 ooc/infinite + bc3 帧上由 CLAW_E 变为 SHRED_E。两个下游消费者均由前置排除门屏蔽，净行为差 ≈ 0：

1. `shouldDoReshift`（cat.lua:252-281）：255 行 RESHIFT_ENERGY==0 与 258 行 `not macroTorch.player.isInCombat or clickContext.prowling or clickContext.ooc or kill-shot` 显式排除 ooc 帧——ooc 免费帧根本到不了成本比较；无限能量(非 ooc)帧上 278 行 `math.ceil(projectedEnergy) < nextAbilityCost` 因 `projectedEnergy >= nextAbilityCost` 恒真而永不触发。SHRED_E 更贵只会让该不等式更不可能触发（愈加固化）→ 差 0。
2. `shouldCastFFDuringWaitWindow`（Druid.lua:1164-1197）：1167 行显式排除 ooc；无限能量帧上 1184 行 `currentEnergy < minAbilityCost` 永不成立 → 差 0。SHRED_E 更贵只会使该条件更不可能成立 → 差 0。
3. 既有测试：唯一 3-bleed ctx 是即将重写的 R6-05（491 行），其余消费点 ctx 无 `isPouncePresent=true` → 改第 3 分支对它们零影响（本计划 GATE 1 有 isPouncePresent=2 的绝对计数钉死）。

**pin 决策（已读 shouldUseBite 裁定）：加。** 稳定 ctx 构造存在：`isSpellExist` 系真实 API 与既测同类；`fastBattle` 用 `ctx.isFastBattleNotPvp=false` 预置（1054 行 player-controlled 前置读不影响 false 结论）；`shouldUseBite` 的 trivial 臂被 `ctx.isImmuneRip=true` 短路杀死、cp5 臂被 `ctx.comboPoints=1` 杀死，唯 `isKillShotOrLastChance` 是实机状态读——用函数 stub（false）钉死确定性；`isTigerPresent`/三流血/isRipPresent/isRakePresent 全部 ctx 预置；新分支 3 走 accessor shadow=false。故 pin 折入新 R6-05，不与断言脱钩。

## 锁定约束（违反即失败）

1. **代码 commit 只含两个文件**：`classes/druid/Druid.lua` + `classes/druid/selftest.lua`。`SM_Extend.lua`、`build.sh`（禁运行）及仓库其余文件零触碰；commit 内不得夹带任何 `.planning` 文件。
2. **删除面**：Druid.lua 恰 3 删除行（1017 行的旧 return + 其 else/end），selftest.lua 恰 21 删除行（旧 R6-05 整块 484-504），合计 24，逐行内容 = 锁定的旧块。
3. **插入逐字锁定**：Task 1 两次 Edit 的 old/new 块逐字执行（Druid.lua 是 4 空格缩进；selftest 是 TAB 缩进）；任何锚点不匹配即停下报告。`<!-- planner-discipline-allow: LIT -->`：本计划锁定文本中含被 GATE 1 负向 grep 的字面量（如旧注释、旧断言），负向 grep 作用于编辑后的**代码文件**，与计划文本不同域。
4. **Lua 5.0（WoW 1.12）合规**：新增行零 `#`、零 `goto`、零 `::`；新增字符串字面量内无 `--`、无裸双引号；零 CJK；注释与断言文案英文；行尾 LF。
5. **CR-01 纪律**（新 R6-05）：accessor 用 rawget 快照/own-key 影子/rawset 还原；`isKillShotOrLastChance` 函数 stub 用 orig 引用 capture/restore；两者的**还原都在 pcall 之后、所有 assert 之前**。
6. **原则文档零 git**：全程禁止 `git add`/`git commit` 该文件；只改 2 个锚点；禁止 Write 全量重写（用 Edit）；文档验证全部 grep/快照 diff（非 git）。
7. **不变量**：不运行任何构建（build.sh 等）；`SM_Extend.lua`（build 产物）零触碰。

## 任务

### Task 1（原子）: Druid.lua 分支 3 改写 + selftest R6-05 重写/R6-05b + 全电池 + 双文件 commit

**文件**: `classes/druid/Druid.lua` + `classes/druid/selftest.lua`（仅此两个）

**Edit 1 — Druid.lua 分支 3**（锚点 1016-1018，一次 Edit；缩进 4 空格）：

old（从文件逐字复制，三行）:
```
    else
        return false -- 3+ bleeding always uses Claw
    end
```
new（八行）:
```
    else
        -- 3+ bleeds: paid frames keep Claw (DPE still wins when energy is spent). Free frames
        -- (OoC / pseudo-infinite energy) make energy cost irrelevant and the GCD the scarce
        -- resource; per the 2026-09-14 sample verdict, single-cast comparison still favors
        -- Shred even against full 3-bleed-bonus Claw (shred non-crit single-cast 507.3 n=124
        -- vs 3-bleed claw 483.5 n=13, ~5% expected gap at equal crit; claw gains only +57
        -- per extra bleed).
        return (clickContext.ooc or infiniteEnergy) and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed
    end
```

**Edit 2 — selftest.lua R6-05 整块替换**（锚点 484-504 共 21 行，一次 Edit；缩进 TAB，逐字照抄含 tab）：

old（从文件逐字复制）:
```
	macroTorch.SelfTest:register("Principle R6-05: 3+ bleeds always Claw regardless of OoC/infinite", function()
		local ctx = {
			ooc = true,
			isBehind = true,
			isPseudoInfiniteEnergy = true,
			isRakePresent = true,
			isRipPresent = true,
			isPouncePresent = true,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		assert(macroTorch.shouldUseShred(ctx) == false,
			"expected false: 3+ bleeds should always use Claw")
	end, true)
```
new（新 R6-05 + 空行 + R6-05b）:
```
	macroTorch.SelfTest:register("Principle R6-05: 3+ bleeds free frames (OoC/infinite) behind — use Shred", function()
		local ctx = {
			ooc = true,
			isBehind = true,
			isPseudoInfiniteEnergy = true,
			isRakePresent = true,
			isRipPresent = true,
			isPouncePresent = true,
			SHRED_E = 60,
			CLAW_E = 45,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = true,
			isFastBattleNotPvp = false,
			isImmuneRip = true,
			comboPoints = 1,
		}
		-- R6-05 keeps the CR-01 stub discipline (R6-01..R6-03 pattern): snapshot
		-- isBehindAttackJustFailed via rawget, shadow it false, restore BEFORE asserts.
		-- Folded light pin: on this same free-frame ctx getNextAbilityCost must resolve
		-- SHRED_E at step 5 (not CLAW_E). isKillShotOrLastChance is stubbed false so the
		-- shouldUseBite step-1 arm cannot fire on a live kill-shot target.
		local player = macroTorch.player
		local saved = rawget(player, 'isBehindAttackJustFailed')
		player.isBehindAttackJustFailed = false
		local origKillShot = macroTorch.isKillShotOrLastChance
		macroTorch.isKillShotOrLastChance = function(clickContext) return false end
		local ok, res, cost = pcall(function()
			local useShred = macroTorch.shouldUseShred(ctx)
			local nextCost = macroTorch.getNextAbilityCost(ctx)
			return useShred, nextCost
		end)
		rawset(player, 'isBehindAttackJustFailed', saved)
		macroTorch.isKillShotOrLastChance = origKillShot
		assert(ok, "R6-05 errored: " .. tostring(res))
		assert(res, "expected true: 3+ bleeds free frames behind should use Shred")
		assert(cost == ctx.SHRED_E,
			"expected SHRED_E resolve from getNextAbilityCost on free-frame 3-bleed ctx")
	end, true)

	macroTorch.SelfTest:register("Principle R6-05b: 3+ bleeds paid frames — use Claw", function()
		local ctx = {
			ooc = false,
			isBehind = true,
			isPseudoInfiniteEnergy = false,
			isRakePresent = true,
			isRipPresent = true,
			isPouncePresent = true,
			AUTO_TICK_ERPS = 10,
			TIGER_ERPS = 10 / 3,
			RAKE_ERPS = 0,
			RIP_ERPS = 0,
			POUNCE_ERPS = 0,
			BERSERK_ERPS = 10,
			berserk = false,
			hasEssenceOfTheRed = false,
			isTigerPresent = false,
		}
		-- Paid frames: (false or false) short-circuits the and-chain before the
		-- accessor, so no shadow discipline is needed (same shape as R6-04).
		assert(macroTorch.shouldUseShred(ctx) == false,
			"expected false: 3+ bleeds paid frames should use Claw")
	end, true)
```

**执行路径 Trace（已锁定）**：
- 新 R6-05：bc3 → else 支 → `(true or true) and isBehind(true) and not shadowed(false)` → true；pin 链：fastBattle=预置 false → shouldUseBite=false（kill-shot stub false；trivial 臂被 `not isImmuneRip` 杀死；cp=1）→ isTigerPresent=预置 true 跳过 → shouldCastRip=false（isRipPresent=预置 true 短路）→ Rake 在场跳过 → step 5 = true → 返回 `(SHRED_E, 'Shred')`；断言 `cost == ctx.SHRED_E`。
- 新 R6-05b：bc3 → else 支 → `(false or false) and ...` 短路 → false，accessor 永不被读（无需影子，与 R6-04 同构）。
- 旧 R6-05 若保留会红：新分支 3 在 ooc+infinite+behind 上返回 true，旧断言 `== false` 必炸——重写是行为同步，非可选。

**验证电池（顺序执行，任一失败即停并报告）**：

```bash
cd /home/admin/workspace/macro-torch

# GATE 0: 三解释器 loadfile 编译两文件（不执行，无 WoW 环境依赖）
for B in /tmp/luabuild/lua-5.0.3/bin/lua /tmp/luabuild/lua-5.1.5/src/lua /tmp/luabuild/lua-5.4.7/src/lua; do
  "$B" -e 'assert(loadfile("/home/admin/workspace/macro-torch/classes/druid/Druid.lua")); assert(loadfile("/home/admin/workspace/macro-torch/classes/druid/selftest.lua"))' || { echo "LOADFILE FAIL: $B"; exit 1; }
  echo "LOADFILE-OK: $B"
done

# GATE 1: 结构 grep（-F 全字面；基数=规划时实测）
test "$(grep -cF '3+ bleeds: paid frames keep Claw' classes/druid/Druid.lua)" = "1" || { echo "FAIL: new branch-3 comment"; exit 1; }
test "$(grep -cF '2026-09-14 sample verdict' classes/druid/Druid.lua)" = "1" || { echo "FAIL: verdict citation"; exit 1; }
test "$(grep -cF '(clickContext.ooc or infiniteEnergy) and clickContext.isBehind and not macroTorch.player.isBehindAttackJustFailed' classes/druid/Druid.lua)" = "2" || { echo "FAIL: and-chain count (baseline 1 + new 1)"; exit 1; }
test "$(grep -cF '3+ bleeding always uses Claw' classes/druid/Druid.lua)" = "0" || { echo "FAIL: old comment still present"; exit 1; }
test "$(grep -cF 'Principle R6-05: 3+ bleeds free frames (OoC/infinite) behind' classes/druid/selftest.lua)" = "1" || { echo "FAIL: new R6-05 name"; exit 1; }
test "$(grep -cF 'Principle R6-05b: 3+ bleeds paid frames' classes/druid/selftest.lua)" = "1" || { echo "FAIL: R6-05b name"; exit 1; }
test "$(grep -cF '3+ bleeds always Claw regardless of OoC/infinite' classes/druid/selftest.lua)" = "0" || { echo "FAIL: old R6-05 name"; exit 1; }
test "$(grep -cF '3+ bleeds should always use Claw' classes/druid/selftest.lua)" = "0" || { echo "FAIL: old R6-05 assert text"; exit 1; }
test "$(grep -cF 'expected true: 3+ bleeds free frames behind should use Shred' classes/druid/selftest.lua)" = "1" || { echo "FAIL: new shred assert"; exit 1; }
test "$(grep -cF 'expected SHRED_E resolve from getNextAbilityCost on free-frame 3-bleed ctx' classes/druid/selftest.lua)" = "1" || { echo "FAIL: pin assert"; exit 1; }
test "$(grep -cF 'local origKillShot = macroTorch.isKillShotOrLastChance' classes/druid/selftest.lua)" = "1" || { echo "FAIL: kill-shot capture"; exit 1; }
test "$(grep -cF 'macroTorch.isKillShotOrLastChance = function(clickContext) return false end' classes/druid/selftest.lua)" = "1" || { echo "FAIL: kill-shot stub"; exit 1; }
test "$(grep -cF 'macroTorch.isKillShotOrLastChance = origKillShot' classes/druid/selftest.lua)" = "1" || { echo "FAIL: kill-shot restore"; exit 1; }
test "$(grep -cF 'player.isBehindAttackJustFailed = false' classes/druid/selftest.lua)" = "4" || { echo "FAIL: shadow count (R6-01..03 3 + new 1)"; exit 1; }
test "$(grep -cF 'rawset(player, '\''isBehindAttackJustFailed'\'', saved)' classes/druid/selftest.lua)" = "4" || { echo "FAIL: rawset count (3 + new 1)"; exit 1; }
test "$(grep -cF 'isPouncePresent = true' classes/druid/selftest.lua)" = "2" || { echo "FAIL: 3-bleed ctx count (old 1 -> 2)"; exit 1; }
echo "GATE 1 OK"

# GATE 2: 删除面——Druid.lua 3 行(旧 else/return/end)、selftest.lua 21 行(旧 R6-05 整块)、合计 24
test "$(git diff -U0 HEAD -- classes/druid/Druid.lua | grep '^-' | grep -v '^---' | wc -l)" = "3" || { echo "FAIL: Druid.lua deletion count"; exit 1; }
test "$(git diff -U0 HEAD -- classes/druid/Druid.lua | grep '^-' | grep -v '^---' | grep -cF '3+ bleeding always uses Claw')" = "1" || { echo "FAIL: deleted line not old return"; exit 1; }
test "$(git diff -U0 HEAD -- classes/druid/selftest.lua | grep '^-' | grep -v '^---' | wc -l)" = "21" || { echo "FAIL: selftest deletion count"; exit 1; }
test "$(git diff -U0 HEAD -- classes/druid/selftest.lua | grep '^-' | grep -v '^---' | grep -cF '3+ bleeds always Claw regardless')" = "1" || { echo "FAIL: deleted block not old R6-05"; exit 1; }

# GATE 3: hunk 范围——Druid.lua @@ 起行∈1010..1025；selftest.lua ∈480..600
test -z "$(git diff -U0 HEAD -- classes/druid/Druid.lua | grep '^@@' | grep -vE '^@@ -(10[1-9][0-9]|102[0-5]),')" || { echo "FAIL: Druid.lua hunk out of range"; exit 1; }
test -z "$(git diff -U0 HEAD -- classes/druid/selftest.lua | grep '^@@' | grep -vE '^@@ -(4[89][0-9]|5[0-9][0-9]|600),')" || { echo "FAIL: selftest hunk out of range"; exit 1; }
echo "GATE 2-3 OK"

# GATE 4: 括号平衡——两文件全文件 bbcheck（规划时基线均为 BALANCED，须保持）+ diff 新增行平衡脚本
node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/Druid.lua | grep -F 'classes/druid/Druid.lua: BALANCED' || { echo "FAIL: Druid.lua bbcheck"; exit 1; }
node .planning/phases/27-catatk-event-driven-land-tracing-refactor/tools/bbcheck.js classes/druid/selftest.lua | grep -F 'classes/druid/selftest.lua: BALANCED' || { echo "FAIL: selftest bbcheck"; exit 1; }
git diff -U0 HEAD -- classes/druid/Druid.lua classes/druid/selftest.lua | node -e 'let out="";process.stdin.on("data",d=>out+=d);process.stdin.on("end",()=>{let s=out.split("\n").filter(l=>l[0]==="+"&&l[1]!=="+").map(l=>l.slice(1)).join("\n");s=s.replace(/--\[\[[\s\S]*?\]\]/g," ").replace(/--[^\n]*/g," ").replace(/\"(?:\\.|[^\"\\])*\"/g," \"s\" ").replace(/\x27(?:\\.|[^\x27\\])*\x27/g," \"s\" ");const st=[];let ok=true;for(const c of s){if(c==="["||c==="("||c==="{"){st.push(c)}else if(c==="]"||c===")"||c==="}"){const p=st.pop();if((c==="]"&&p!=="[")||(c===")"&&p!=="(")||(c==="}"&&p!=="{")){ok=false;break}}}if(!ok||st.length!==0){console.log("GATE4 DIFF BALANCE: MISMATCH");process.exit(1)}console.log("GATE4 DIFF BALANCE: OK")});' || { echo "FAIL: diff balance"; exit 1; }
echo "GATE 4 OK"

# GATE 5: 新增行 token / CJK / 行尾门 + git diff --check
test "$(git diff -U0 HEAD -- classes/druid/Druid.lua classes/druid/selftest.lua | grep '^+' | grep -v '^+++' | grep -cE '#|goto |::' || true)" = "0" || { echo "FAIL: 5.0 token"; exit 1; }
test "$(git diff -U0 HEAD -- classes/druid/Druid.lua classes/druid/selftest.lua | grep '^+' | grep -v '^+++' | grep -c '[一-龥]' || true)" = "0" || { echo "FAIL: CJK"; exit 1; }
test "$(grep -l $'\r' classes/druid/Druid.lua classes/druid/selftest.lua | wc -l)" = "0" || { echo "FAIL: CR bytes"; exit 1; }
git diff --check || { echo "FAIL: diff check"; exit 1; }

# GATE 6: 变更面唯一（原则文档被 ignore，不出现；不得运行任何 build）
test "$(git status --porcelain | grep -v '^ M classes/druid/Druid.lua$' | grep -v '^ M classes/druid/selftest.lua$' | wc -l)" = "0" || { echo "FAIL: unexpected files changed"; git status --porcelain; exit 1; }
test "$(git diff -U0 HEAD --stat | grep -c 'SM_Extend.lua')" = "0" || { echo "FAIL: SM_Extend.lua touched"; exit 1; }
echo "ALL GATES OK"
```

**提交（仅两个文件，显式路径）**：

```bash
git add classes/druid/Druid.lua classes/druid/selftest.lua && git commit -m "fix(druid): 3+ bleeds free frames (OoC/infinite) behind use Shred; R6-05 rewrite + R6-05b paid-frame pin"
```
- `git log -1 --format=%s` 输出上述消息逐字
- `git show --stat --format= HEAD` 仅含这两个文件

**完成标准**：ALL GATES OK；LOADFILE-OK ×3；bbcheck 双 BALANCED；两个文件入仓，工作树除此零改动。

**precondition**：/tmp/luabuild 三解释器与 /usr/local/bin/node 在位（规划时 2026-09-14 实测编译通过）；若执行时缺失，停下报告 unmet precondition。

### Task 2: 原则文档 2 处锁定修订（工作树-only，永不 commit）

**文件**: `.planning/catAtk-core-principles.md`（仅此一个）

- **步骤 0 — 基线断言 + 快照**（任一失败即停）:
  ```bash
  f=.planning/catAtk-core-principles.md
  test -f "$f" || { echo "doc missing"; exit 1; }
  git check-ignore "$f"      # 必须输出该路径（忽略/untracked 证明）
  test -z "$(git status --porcelain -- "$f")"   # 无跟踪状态
  wc -l < "$f"                                   # 应为 494；末行无换行符，勿补加
  grep -c '^```' "$f"                            # 记录基线 F（规划时 3vh 后为 30）
  for s in '| 3+ | 始终爪击 | 爪击在原始伤害和 DPE 上均超过撕碎 |' 'IF  bleedCount >= 3:'; do
    c=$(grep -cF "$s" "$f" || true)
    [ "$c" = "1" ] || { echo "ANCHOR NOT UNIQUE (c=$c): $s"; exit 1; }
  done; echo ANCHORS-OK
  cp "$f" /tmp/catAtk-core-principles.260914-nth.before.md   # 唯一回退源
  ```

- **编辑 E1 — Rule 6 表格第 3 行**（保持表格列对齐，一行替换一行）:
  old: `| 3+ | 始终爪击 | 爪击在原始伤害和 DPE 上均超过撕碎 |`
  new: `| 3+ | 爪击（付费帧）；撕碎（OoC/无限能量·背后） | 付费帧爪击 DPE 仍最高；免费帧能量成本无关、GCD 稀缺，撕碎单发胜出 |`

- **编辑 E2 — Rule 6 伪代码第 3 行块**（两行块整体替换为三行；缩进与旧块逐字节一致，若文件存在尾随空格按原文保留）:
  old:
  ```
  IF  bleedCount >= 3:
      useClaw
  ```
  new:
  ```
  IF  bleedCount >= 3:
      useShred IF (ooc OR infiniteEnergy) AND isBehind
      ELSE useClaw
  ```

- **验证**（全命中才算完成；任何失败 → `cp /tmp/catAtk-core-principles.260914-nth.before.md .planning/catAtk-core-principles.md` 恢复后重做）:
  ```bash
  f=.planning/catAtk-core-principles.md
  b=/tmp/catAtk-core-principles.260914-nth.before.md
  # (1) 正向断言
  grep -qF '| 3+ | 爪击（付费帧）；撕碎（OoC/无限能量·背后） | 付费帧爪击 DPE 仍最高；免费帧能量成本无关、GCD 稀缺，撕碎单发胜出 |' "$f"
  grep -qF 'useShred IF (ooc OR infiniteEnergy) AND isBehind' "$f"
  grep -qF 'ELSE useClaw' "$f"
  # (2) 旧文本清空
  test "$(grep -cF '始终爪击' "$f" || true)" = "0"
  test "$(grep -cF '爪击在原始伤害和 DPE 上均超过撕碎' "$f" || true)" = "0"
  # (3) ZERO-DELTA 审计——快照 diff（替代 git）
  N=$(wc -l < "$b"); M=$(wc -l < "$f")
  test $((M - N)) = 1 || { echo "LINE DELTA $((M-N)) != 1"; exit 1; }   # 494 -> 495
  diff -u "$b" "$f" > /tmp/catAtk-nth.diff || true
  test "$(grep -c '^@@' /tmp/catAtk-nth.diff)" = "2"     # 恰 2 hunk
  test "$(grep -c '^-[^-]' /tmp/catAtk-nth.diff)" = "3"  # 恰 3 删除行(表行 1 + 伪代码旧 2)
  test "$(grep -c '^+[^+]' /tmp/catAtk-nth.diff)" = "4"  # 恰 4 新增行(表行 1 + 伪代码新 3)
  # 目视 /tmp/catAtk-nth.diff:两个 hunk 恰对应 Rule 6 表格与伪代码块，无其它字节变化
  # (4) 结构不变量
  test "$(grep -c '^```' "$f")" = "$(grep -c '^```' "$b")"   # 围栏数不变
  test "$(grep -cF '*作者：pf_miles*' "$f")" = "1"            # 作者行未动
  tail -1 "$f" | cat -A                                       # 目视：作者行原件、无新增换行符
  # (5) 常量漂移审计
  for t in '8.5s' '25s' '75%' '15%' '2.3s' '1.3s' '10s' '9s' '2s' '1s' '1.5s' 'SHRED_E'; do
    a=$(grep -cF "$t" "$b" || true); c=$(grep -cF "$t" "$f" || true)
    test "$a" = "$c" || { echo "CONSTANT DRIFT: $t $a -> $c"; exit 1; }
  done
  echo ALL-TEXT-GATES-PASS
  ```

- **零 git 复核**:
  ```bash
  git check-ignore .planning/catAtk-core-principles.md   # 仍输出路径
  git status --porcelain -- .planning/catAtk-core-principles.md   # 输出为空
  ```

- **完成标准**：`ALL-TEXT-GATES-PASS`；恰 2 hunk（-3/+4）；wc -l 494→495；文档从未被 add/commit，仍被 ignore。

### Task 3: SUMMARY 输出（零代码变更；.planning 收口留给 quick 流程）

1. 写 `260914-nth-SUMMARY.md` 到本 quick 目录：三文件修订对照（旧→新要点）、GATE 0-6 全绿输出、Task 2 文本门全绿、能量估算影响论证结论（差≈0）、Unrun Verification 备案、Threat Flags、Self-Check。**不得 git add/commit 任何 .planning 文件**——STATE.md 行与 docs commit 由 quick 流程收口（49l/0ql 先例）。
2. **Unrun Verification 备案**（写进 SUMMARY）：本机无 WoW 客户端；用户 Windows+Cygwin 重建 `/mt` 后 R6-05/R6-05b 应绿，旧版 R6-05 断言（always Claw）在实机必红（新分支 3 返回 true）——先红后绿正是本次行为同步的证据。实战观察：3 流血在场时,清晰预兆/红龙精华帧背刺改为撕碎（战斗记录出现 Shred），非免费帧仍爪击。
3. **验证**: `git status --porcelain` 除两个已提交的 Lua 文件外无残留；`git log -1 --format=%s` 为 Task 1 消息；SUMMARY 已落盘。

## 威胁模型（STRIDE 简表）

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260914-nth-01 | Tampering | selftest R6-05 的 accessor 影子 + isKillShotOrLastChance stub 泄漏污染实机会话 | medium | mitigate | CR-01：还原行（rawset + orig 引用）置于 pcall 之后、所有 assert 之前；即使 pcall 抛错还原仍执行；GATE 1 钉死 capture/stub/restore 各计数（4/1/1/1） |
| T-260914-nth-02 | DoS | 分支 3 误伤付费帧行为（3+ 流血付费帧从 Claw 变为 Shred 的 DPS 回退） | medium | mitigate | 付费帧 `(false or false) and ...` 短路 → 返回值与旧 `return false` 逐位相同；R6-05b pin 固化付费帧语义,实机回归直接红名 |
| T-260914-nth-03 | DoS | getNextAbilityCost 析出 SHRED_E 抖动 reshift/FF 时序（能量估算） | low | accept | 两消费者均以 ooc 显式排除 + 无限能量下条件恒不成立屏蔽（论证见上）；SHRED_E 与 CLAW_E 之差仅使不等式更不可能触发 |
| T-260914-nth-04 | DoS | 免费帧非背后（isBehind=false）误发 Shred | low | accept | and-chain 中 isBehind 是硬条件,非背后返回 false 与旧行为一致 |
| T-260914-nth-05 | Escalation | 经 UI 注入的测试名/文案被执行 | low | accept | 测试名与断言为静态字面量,register 仅登记函数,无 eval 路径 |

包管理器安装：本 quick 零 npm/pip/cargo 安装，package legitimacy 门与 T-SC 行不适用。

## 输出

- Task 1 完成后代码原子 commit（恰两 Lua 文件）。
- 任务全程禁止 build.sh、禁止触碰 `SM_Extend.lua`、禁止将原则文档加入 git。
- 执行完成后输出 `260914-nth-SUMMARY.md`；STATE.md Quick Tasks 表行由 quick 流程 docs commit 收口。