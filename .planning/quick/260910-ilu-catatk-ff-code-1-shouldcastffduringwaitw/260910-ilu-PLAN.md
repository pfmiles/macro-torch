---
quick_id: 260910-ilu
slug: catatk-ff-code-1-shouldcastffduringwaitw
description: "Execute user-appointed deviations from the catAtk principles cross-check: 1 code fix (Druid.lua shouldCastFFDuringWaitWindow kill-shot exclusion per rule 9) + 9 anchored doc revisions to .planning/catAtk-core-principles.md (A3-A6, B1/B3/B4, essence-listing removal)"
date: 2026-09-10
---

# PLAN: catAtk 原则文档对照裁决执行 + 斩杀期精灵之火门

## 目标

执行用户对照 `catAtk-core-principles.md` 整体分析 catAtk 后裁决的 4 项出入处置（1 项代码 + 3 项文档），其中文档侧含 9 个锚定编辑点（A3/A4/A5/A6/B1/B3/B4 + 两处精华化移除）。本计划不做任何超出裁决清单的变更。

## 锁定约束（必须遵守，违反即失败）

**代码侧：**
1. **只改 `classes/druid/Druid.lua` 的 `shouldCastFFDuringWaitWindow` 一个函数**。不触碰其调用方（`keepFF`）、不触碰 `combo.lua`/`cat.lua`。
2. **新代码注释必须是英文，一句话**；函数内既有中文注释（`-- 基础排除条件` 等）逐字保留不翻译。
3. **Lua 5.0 兼容**：新增行不得含 `#` 长度运算符、`goto`、`::` label 语法。
4. **禁止运行任何构建脚本**（build.sh）；`SM_Extend.lua` 是构建产物（非 git 跟踪），任务结束时代码目录不得出现该文件。
5. LF 行尾（`git diff --check` 必须干净）。
6. 不得触碰 `.planning/samples/p1.txt`。

**文档侧：**
7. **只改 `.planning/catAtk-core-principles.md`**，正文保持中文；只动下列 9 个锚定点，不重写文档风格。
8. **语义常量一字不动**：8.5s / 25s / 2s / 75% / 15% / 2.3s / 9s / 10s / 1s 等值必须与 HEAD 完全一致（附录 B 的「值」列逐字节不变）。
9. 伪代码块数量不变（当前 `grep -c '^```'` = 30，编辑后必须仍为 30）。
10. 提交信息一律英文；分两次原子提交（先代码、后文档）。

## 背景事实（来自本次实地读取，编辑锚点以此为准）

- `isKillShotOrLastChance` 是已存在的全局函数（`Druid.lua:1002`），同文件内已有 `macroTorch.isKillShotOrLastChance(clickContext)` 调用惯例。原则文档规则 9 明文「斩杀跳过精灵之火」，但 `shouldCastFFDuringWaitWindow` 的基础排除块缺此门。
- 当前代码块（`Druid.lua:1061-1067`）：
  - `function macroTorch.shouldCastFFDuringWaitWindow(clickContext)` 之后为 `-- 基础排除条件` 注释，`if clickContext.ooc or macroTorch.target.isImmune('Faerie Fire (Feral)') or macroTorch.shouldDoReshift(clickContext) then return false end`。
- 文档当前状态：附录 B 表（`436-451` 行）含「定义位置」第 4 列；附录 D `### SelfTest 覆盖` 表（`484-495` 行）为测试 ID 清单；规则 2 伪代码（`51-60` 行）无「有效回能净收益」条件；规则 8 伪代码（`229-237` 行）无 `erps > 0` 条件；规则 4 函数表 cp5Bite 行（`106` 行）门条件为「仅在 `isImmuneRip OR isRipPresent` 时」；规则 10 注意段（`302` 行）、规则 12 交换策略两行（`334-335` 行）、规则 14 自动攻强段（`408-409` 行）、规则 7 结尾（`221` 行后）为待改文本。

## 任务

行号基于本次 Read（2026-09-10）的当前文件；编辑一律以**行内容为锚点**（old→new 逐字替换），行号仅作导航参考。

### Task 1: Druid.lua 斩杀期 FF 门（代码）

- **文件**: `classes/druid/Druid.lua`（仅 `shouldCastFFDuringWaitWindow`，`1061-1067` 行）
- **操作**（两处小改，共 2 行新增）:
  1. 在 `-- 基础排除条件` 注释行之后插入一行英文注释（一句话，与规则 9 对齐）：
     `    -- Kill-shot phase pauses all debuff maintenance, including FF fill (rule 9)`
  2. 把条件尾 `or macroTorch.shouldDoReshift(clickContext) then` 扩展为两行：在 `shouldDoReshift` 判断之后追加 `or macroTorch.isKillShotOrLastChance(clickContext)`（放在 `then` 之前）。最终块为：

     ```lua
     function macroTorch.shouldCastFFDuringWaitWindow(clickContext)
         -- 基础排除条件
         -- Kill-shot phase pauses all debuff maintenance, including FF fill (rule 9)
         if clickContext.ooc
                 or macroTorch.target.isImmune('Faerie Fire (Feral)')
                 or macroTorch.shouldDoReshift(clickContext)
                 or macroTorch.isKillShotOrLastChance(clickContext) then
             return false
         end
     ```

  效果：斩杀/最后机会阶段（≤2s 死亡预测或阈值回退触发）精灵之火填充直接短路，与原则文档规则 9 的「斩杀跳过精灵之火」一致；非斩杀路径行为零变化（新条件追加在既有排除链末尾，短路发生在 `computeErps` 之前）。
- **验证**:
  - `git status --porcelain` → 仅 `classes/druid/Druid.lua` 被修改
  - `git diff -- classes/druid/Druid.lua | grep -c '^@@'` 输出 `1`（单一 hunk，且 hunk 头含 `shouldCastFFDuringWaitWindow`）
  - `git diff -U0 -- classes/druid/Druid.lua | grep '^+' | grep -c '#'` 输出 `0`（新增行无 `#`）
  - `grep -nE 'goto|::' classes/druid/Druid.lua` 无输出（全文件 Lua 5.0 基线）
  - `git diff --check` 无输出（LF + 无行尾空白）
  - `sed -n '1062,1070p' classes/druid/Druid.lua` 目视块为上述最终形态（4 条件 OR + then）
  - `test ! -e SM_Extend.lua` 通过（未运行构建脚本，产物不存在）
  - `git status --porcelain -- .planning/samples/` 为空（p1.txt 未动）
- **提交**:
  `git add classes/druid/Druid.lua && git commit -m "fix(catAtk): exclude kill-shot phase from FF wait-window fill"`
- **验证提交**:
  - `git log -1 --format=%s` 输出 `fix(catAtk): exclude kill-shot phase from FF wait-window fill`
  - `git show --stat HEAD` 仅含 `classes/druid/Druid.lua` 且 `2 insertions(+)`（英注释 1 行 + 条件拆分净增 1 行）

### Task 2: 原则文档 9 处锚定修订（文档）

- **文件**: `.planning/catAtk-core-principles.md`
- **操作**（9 个锚定点逐字替换，均在一份文件内；每处 old 文本在文件中唯一）:

  **A3 — 规则 2 伪代码补「有效回能净收益」条件**（锚点 `AND reshiftEnergy > 0` 行，当前 `57` 行）：
  old 行: `AND reshiftEnergy > 0                            -- 有野性之心天赋或狼心附魔`
  new（在其后插入一行）:
  ```
  AND 有效回能净收益为正（扣除被抹除的猛虎补打）           -- reshift 必须带来正收益
  ```

  **A4 — 规则 8 伪代码补 `erps > 0` 条件**（锚点 `AND currentEnergy < nextAbilityCost              -- 但能量还不够，必须等待` 行，当前 `231` 行）：
  new（在其后插入一行）:
  ```
  AND erps > 0                                     -- 零回能时不存在等待窗
  ```

  **A5 — 规则 4 函数表 cp5Bite 门条件行对齐**（当前 `106` 行）：
  old: `| `cp5Bite` (`cat.lua`) | 门条件：仅在 `isImmuneRip OR isRipPresent` 时进入撕咬路径 |`
  new: `| `cp5Bite` (`cat.lua`) | 门条件：`isImmuneRip OR isRipPresent OR 速战（规则5）` 时进入撕咬路径 |`

  **B4 — 规则 7 结尾补机制注记**（锚点 `- `regularAttack` (`cat.lua`) 在 `catAtk` 主流程中被 `comboPoints < 5` 门控` 行，当前 `221` 行）：
  new（在其后追加一行）:
  ```
  **机制注记：** 猛虎之怒使用独立 GCD 计时，不与攻击 GCD 竞争，其在时序表中的位置无实质影响。
  ```

  **B3 — 规则 10 注意段改写**（当前 `302` 行）：
  old: `**注意：** 仇恨管理仅在组队 + 世界boss场景激活。单人游戏和训练木桩被排除在外。`
  new: `**注意：** 组队/团队场景激活，非世界boss 被目标攻击也会畏缩，世界boss 另有仇恨阈值触发。`

  **B1 — 规则 12 交换策略 worldboss 限定**（当前 `334-335` 行两行）：
  old:
  ```
  割裂前：换上凶猛圣物（仅正常战；快战/PvP 跳过）
  割裂后：recoverNormalRelic() → 换回默认圣物（在空闲 GCD 期间）
  ```
  new:
  ```
  割裂前：换上凶猛圣物（仅正常战且世界boss）
  割裂后：recoverNormalRelic() → 换回默认圣物（仅世界boss场景；普通目标战斗周期短，1.5s 换装 GCD 不划算）
  ```

  **A6 — 规则 14 自动攻强段推广至扫击/割裂**（当前 `408-409` 行两行）：
  old:
  ```
  **高价值目标的自动攻强爆发（扫击时）：**
  除了手动爆发协调外，`keepRake` 在向世界boss或 PvP 目标施放扫击时（且割裂已存在），会自动消费攻强物品。理由：扫击在施放时快照攻击强度，持续整个流血期间；在施放瞬间最大化攻强能产生最高的总流血伤害。此自动消费与 Shift 键爆发序列相互独立，互不干扰。
  ```
  new:
  ```
  **流血施放前的自动攻强爆发（扫击/割裂）：**
  除了手动爆发协调外，扫击与割裂施放前均会自动消费攻强物品——AP 快照通用于两种流血。理由：流血在施放时快照攻击强度，持续整个流血期间；在施放瞬间最大化攻强能产生最高的总流血伤害。扫击侧对世界boss 另要求割裂已存在且非训练木桩。此自动消费与 Shift 键爆发序列相互独立，互不干扰。
  ```

  **精华化移除之一 — 附录 B「定义位置」整列删除**（当前 `438-451` 行整表替换）：
  old（14 行，含表头与分隔行）:
  ```
  | 常量 | 值 | 说明 | 定义位置 |
  |------|-----|------|----------|
  | 能量池上限 | 100 | 猫形态能量最大值 | — |
  | 基础回复 | 20/2s = 10 erps | 默认能量恢复速率 | `catAtk` (`combo.lua`) |
  | 变身 GCD | 1.5s | 形态切换 GCD 时长 | `shouldDoReshift` (`cat.lua`) |
  | 畏缩仇恨阈值 | 75% | 触发畏缩的仇恨百分比 | `COWER_THREAT_THRESHOLD` (`Druid.lua`) |
  | 紧急血量阈值 | 15% | 触发治疗消耗品的血量百分比 | `catAtk` (`combo.lua`) |
  | 快战阈值 | 25s | 预计存活 < 25s → 快战 | `isTrivialBattle` (`Druid.lua`) |
  | 速战阈值 | 8.5s | 预计存活 < 8.5s 且非 PvP → 纯直伤（跳过流血） | `isFastBattleNotPvp` (`Druid.lua`) |
  | 斩杀预测 | 2s | 目标 2s 内死亡 → 斩杀 | `isKillShotOrLastChance` (`Druid.lua`) |
  | 割裂基础时长 | 10s | 每星 +2s（凶猛圣物 × 0.9） | `RIP_BASE_DURATION` (`Druid.lua`) |
  | 扫击时长 | 9s | | `RAKE_DURATION` (`Druid.lua`) |
  | 撕咬割裂刷新保护 | 2.3s | 割裂 ≤ 2.3s 剩余时跳过泄能以保护割裂 | `cp5Bite` (`cat.lua`) |
  | 精灵之火 GCD | 1s | 施放精灵之火所需的最小等待窗口 | `shouldCastFFDuringWaitWindow` (`Druid.lua`) |
  ```
  new（同一 12 个常量行，仅删第 4 列；「值」列逐字节不变）:
  ```
  | 常量 | 值 | 说明 |
  |------|-----|------|
  | 能量池上限 | 100 | 猫形态能量最大值 |
  | 基础回复 | 20/2s = 10 erps | 默认能量恢复速率 |
  | 变身 GCD | 1.5s | 形态切换 GCD 时长 |
  | 畏缩仇恨阈值 | 75% | 触发畏缩的仇恨百分比 |
  | 紧急血量阈值 | 15% | 触发治疗消耗品的血量百分比 |
  | 快战阈值 | 25s | 预计存活 < 25s → 快战 |
  | 速战阈值 | 8.5s | 预计存活 < 8.5s 且非 PvP → 纯直伤（跳过流血） |
  | 斩杀预测 | 2s | 目标 2s 内死亡 → 斩杀 |
  | 割裂基础时长 | 10s | 每星 +2s（凶猛圣物 × 0.9） |
  | 扫击时长 | 9s | |
  | 撕咬割裂刷新保护 | 2.3s | 割裂 ≤ 2.3s 剩余时跳过泄能以保护割裂 |
  | 精灵之火 GCD | 1s | 施放精灵之火所需的最小等待窗口 |
  ```

  **精华化移除之二 — 附录 D SelfTest 覆盖表改为一句话**（当前 `484-495` 行整表替换；`### SelfTest 覆盖` 标题与前后 `---` 分隔保留原样）：
  old（12 行表格）:
  ```
  | 规则 | 测试 ID |
  |------|---------|
  | 1 | R1-01 ~ R1-04 |
  | 2 | R2-01 ~ R2-07 |
  | 4, 5 | R4-01 ~ R4-04, R5-01 ~ R5-04 |
  | 5（速战档） | P-01 ~ P-06 |
  | 6 | R6-01 ~ R6-06 |
  | 7 | R7-01 ~ R7-06 |
  | 8 | R8-01 ~ R8-06 |
  | 9 | R9-01 ~ R9-03 |
  | 3, 12 | R12-01 ~ R12-03 |
  | — | PF-01 ~ PF-07（纯函数测试） |
  ```
  new:
  ```
  行为级测试断言随代码演进，本文档不维护测试 ID 清单。
  ```

  **禁止事项**：不改附录 D 上方的「原则→代码可追溯矩阵」表；不改 `*最后更新：2026-08-23*` 页脚（不在裁决清单内）。
- **验证**:
  - `git status --porcelain` → 仅 `.planning/catAtk-core-principles.md`（此时 Druid.lua 已在 Task 1 提交，工作树无残留）
  - `git diff --check` 无输出（LF 干净）
  - 附录 B「值」列逐字节不变:
    ```bash
    git show HEAD:.planning/catAtk-core-principles.md | sed -n '/^## 附录 B/,/^---/p' | awk -F'|' '{print $3}' > /tmp/appB-head.txt
    sed -n '/^## 附录 B/,/^---/p' .planning/catAtk-core-principles.md | awk -F'|' '{print $3}' > /tmp/appB-now.txt
    diff /tmp/appB-head.txt /tmp/appB-now.txt
    ```
    输出为空（等于全列不变）。
  - 语义常量全文件计数与 HEAD 一致（对每个 token，两侧 `grep -c` 必须相等）: `8.5s` `25s` `75%` `15%` `2.3s` `9s` `10s` `2s`。示例：
    ```bash
    for t in '8.5s' '25s' '75%' '15%' '2.3s' '9s' '10s' '2s'; do
      a=$(git show HEAD:.planning/catAtk-core-principles.md | grep -c "$t" || true)
      b=$(grep -c "$t" .planning/catAtk-core-principles.md || true)
      [ "$a" = "$b" ] || { echo "CONSTANT DRIFT: $t $a -> $b"; exit 1; }
    done; echo "constants OK"
    ```
  - 伪代码块数不变: `grep -c '^```' .planning/catAtk-core-principles.md` 输出 `30`
  - 9 处新文本全部就位（全部命中才通过）:
    ```bash
    f=.planning/catAtk-core-principles.md
    grep -qF 'AND 有效回能净收益为正（扣除被抹除的猛虎补打）' $f
    grep -qF 'AND erps > 0' $f
    grep -qF 'isImmuneRip OR isRipPresent OR 速战（规则5）' $f
    grep -qF '猛虎之怒使用独立 GCD 计时，不与攻击 GCD 竞争' $f
    grep -qF '组队/团队场景激活，非世界boss 被目标攻击也会畏缩' $f
    grep -qF '割裂前：换上凶猛圣物（仅正常战且世界boss）' $f
    grep -qF '割裂后：recoverNormalRelic() → 换回默认圣物（仅世界boss场景；普通目标战斗周期短，1.5s 换装 GCD 不划算）' $f
    grep -qF 'AP 快照通用于两种流血' $f
    grep -qF '行为级测试断言随代码演进，本文档不维护测试 ID 清单' $f
    ```
  - 移除项确认: `grep -c '定义位置' $f` 输出 `0`；`grep -cE 'R[0-9]+-[0-9]+' $f` 输出 `0`（函数名如 `getKSThreshold` 不匹配，勿担心）；`grep -c 'P-01' $f` 输出 `0`
- **提交**:
  `git add .planning/catAtk-core-principles.md && git commit -m "docs(catAtk): sync core principles with adjudicated deviations (A3-A6, B1/B3/B4) and remove essence-listing tables"`
- **验证提交**:
  - `git log -1 --format=%s` 输出 `docs(catAtk): sync core principles with adjudicated deviations (A3-A6, B1/B3/B4) and remove essence-listing tables`
  - `git show --stat HEAD` 仅含 `.planning/catAtk-core-principles.md`

### Task 3: 收尾一致性电池（两文件联合）

- **操作**:
  1. 全树干净: `git status --porcelain` 输出为空（两次提交后无任何残留；`SM_Extend.lua`、`.planning/samples/p1.txt` 均未出现/未改动）。
  2. 双文件范围复核: `git diff HEAD~2 --stat` 仅两行——`classes/druid/Druid.lua` 与 `.planning/catAtk-core-principles.md`。
  3. 提交信息复核: `git log -2 --format='%s'` 两条均为英文、前缀分别为 `fix(catAtk):` 与 `docs(catAtk):`（Task 1/2 的验证已各自断言，此处只做最终呈现）。
  4. 代码 diff 终检: `git show HEAD~1:classes/druid/Druid.lua | sed -n '1061,1071p'` 目视 `shouldCastFFDuringWaitWindow` 基础排除块为 4 条件形态，英文注释一行；`git diff HEAD~2 -- classes/druid/Druid.lua` 仅 `shouldCastFFDuringWaitWindow` 一个 hunk。
  5. 文档 diff 终检: `git diff HEAD~1 -- .planning/catAtk-core-principles.md | grep -c '^@@'` 输出在 `8-10` 之间（9 个编辑点 + 可能的合并 hunk）；新增行全部为中文正文/伪代码条件，无英文完整句子混入正文（含 `AND` 的伪代码行除外）。
- **验证**:
  - `git status --porcelain | wc -l` 输出 `0`
  - `git diff HEAD~2 --stat` 恰好 2 个文件
  - `git log -2 --format='%s'` 人工对照上述两条

## 失败即回退

- Task 1 验证任一失败 → 不提交，修正至通过；若 `git diff` 出现预期外文件 → 立即 `git checkout -- <file>` 撤销并排查。
- Task 2 常量漂移（constants OK 未输出）→ 说明「值」列被误改，`git checkout -- .planning/catAtk-core-principles.md` 整体回退后重做 9 处编辑。
- 全程禁止 `build.sh`；如需语法自证仅允许 grep/目视（环境无本地 Lua，依赖 Lua 5.0 token 负向检查 + 单 hunk 范围检查）。