# Solnius 战 Raid 环境下的 Rip 存在性误判 —— 日志证据与双路径排查

> **决策问题：** 2026-09-02 Molten Core（Solnius）战斗中，JadePaw 的 catAtk 在每个 5cp 都重放了 Rip、全程仅 2 个 Ferocious Bite（且都发生在末段快战/斩杀模式），怀疑"判断自己的 Rip 是否仍在目标身上"的逻辑失效——是真的吗？根因落在哪一环？
>
> 日期：2026-09-07 | 上下文：`/gsd-explore` 探索会话（用户报告 + 日志取证） | 关联：`debug/catatk-premature-rip-recast.md`（木桩版同族问题的已解决调查）

---

## 结论摘要

1. **用户体感属实。** 日志（`.planning/samples/es.txt`）证实：Solnius 正常阶段 Jadepaw 的 9 个 5cp 终结技全部打成了 Rip，0 次 5cp bite；每个 re-rip 的上一发 Rip 当时仍在跳血（tick 时间轴证据），提前量 7~11s（本服 5cp Rip ≈ 16.2~18s），每次重放浪费一个 5cp bite 机会，与本服"bite 刷新 Rip"的续杯循环互斥地反复打断。
2. **代码机制确认：** `cp5Bite`（`classes/druid/cat.lua:117`）要求 `isRipPresent` 为 true 才会在 5cp 打 bite；`isRipPresent` = `hasBuff('Ability_GhoulFrenzy')` **且** `ripLeft > 0`。正常阶段该值恒 false，5cp 全部落入 `keepRip` → 重放 Rip。
3. **根因候选两条（可叠加，各自独立成立）：**（2026-09-07 用户新增疑点的代码对照结论：rip/rake 检测链路为 macroTorch 自实现，`entity/Unit.lua:26` hasBuff + `texture_map.lua:40` 本地贴图映射，**SuperMacro 的方法不在链路上**；失败通道只解析 "Your ..." 自身报文无跨猫污染；land 配对目标 GUID 校验在、施法者不可辨只是 WR-02 已接受的 ≤2s 残差——3 猫混杂解释不了 10/10 重放。）
   - **(i) hasBuff 腿在 Solnius 上恒 false（头号嫌疑，2026-09-07 三层对照坐实）：** AURA_CAST（应用行）boss 上 rip=17 条且与 Jadepaw 9 次成功施法 1:1（时差 ≤0.5s）→ 事件流健康；DEBUFF_ADD（debuff 状态表）rip 6 分钟仅 1 条（+110.4s，Sevenstar 的），同流 Rake 9 条；且 rip 施法时刻 boss 行数 8~13，**未达 16/32 槽位上限——"超 32 被挤出"的拥挤机制被否定**。→ 客户端 `UnitDebuff` 扫描在此 boss 上几乎找不到 Rip 图标 → 与门恒 false；缺失原因不是槽位挤满，待下 CD 探针（见 todo）判定"占用不满仍不可见"的本地机制（research Q2 追问：raid boss 特异 aura 同步/排序）。
   - **(ii) ripLeft 腿失效：** Rip 的 land 记录依赖 RAW_COMBATLOG "is afflicted by" 行与 cast intent 配对（landSource='aura-apply'）。research pass 已排除 A2（arg1 确实是 `CHAT_MSG_*` 频道名）、A3/A4（行格式 `0x… is afflicted by Rip.` 与 GUID 比对匹配）、A5（正确频道 `CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE`）；**A1（intent 未种子化 / 配对失败 → apply 行静默丢弃）未能排除**，本份 es.txt 无法直接证实/证伪（es.txt 是解析后格式，非 addon 的 RAW 输入）。
4. **与既有调查的关系：** `.planning/debug/catatk-premature-rip-recast.md` 是木桩场景同族问题（hasBuff=true、ripLeft 窗口丢失），root cause 已定并已实施/在途"事件驱动 land"修复（tick 活性≡我的 rip + fade 事件，绕开 UnitDebuff 槽位与轮询窗口）。**Solnius 新增的价值是 raid/boss 专属的 hasBuff 缺失证据 (i)——事件驱动方案里以 tick 活性替代 hasBuff 的设计恰好覆盖此通道**（Rip 的 SPELL_DMG tick 在本 boss 上照常下发，约 2s 一跳，可作为活性来源）。

---

## 日志取证数据（`.planning/samples/es.txt`，仅 Solnius 片段 行 945563–980700）

| 角色 | Rip | Ferocious Bite | 备注 |
|---|---|---|---|
| Jadepaw（用户） | 10 | 2 | 正常阶段 0 bite；末段 2 个 bite 属快战/斩杀模式 |
| Sevenstar | 4 | 7 | 1 次 premature re-rip |
| Quelld | 4 | 7（FB rank4） | 2 次 premature re-rip |

- **tick 伤害分档证 cp：** 5cp rip tick ≈ 311–351；2cp ≈ 180；1cp ≈ 90（Jadepaw AP 水平）。据此判定：正常阶段所有 Rip 均为 5cp；+133.6s/+144.3s 两个 Rip 为 2cp/1cp（快战模式 `quickKeepRip` 行为，符合设计，不算 bug）。+128.1s 的 Rip 被 MISS（随后 +129.2s 合法补打）。
- **es.txt 字段布局速查：** 分隔符 `|`，行首为毫秒时间戳。SPELL_GO：`ts|SPELL_GO|0|spellId|src|dst|f8|f9`（f8,f9 = 1,0 多数情形；0,1 伴随 MISS）；SPELL_DMG：`ts|SPELL_DMG|dst|src|spellId|amount|…`；AURA_CAST：`ts|AURA_CAST|spellId|src|dst|fl|stacks|intervalMs|…`；DEBUFF_ADD/REM：`ts|DEBUFF_ADD|unit|layer|spellId|…`；MISS：`ts|MISS|src|dst|spellId|code`。
- **技能 ID 速查（本服务器）：** Rip=9896，Rake=9904，Claw=9850，Ferocious Bite=31018(r5)/22829(r4)，Cower=9892，52373=三职业通用近战技（非猫德专属，勿当攒星计）。`SM_EXTEND.lua` 为 build 产物，分析请避开。

---

## 未决项（ledger）

- **[abstain: unverifiable]** SuperWoW `DispatcherRawCombatLog` 内部实现无法核验（闭源，仅 README/LICENSE）；其外部行为（arg1=频道名、arg2=GUID 文本）由官方文档 + 本仓库 dump 样本佐证（admitted）。
- **A1（intent 种子化/配对）** 待实机取证：区分方法见 Todo `druid-rip-land-forensics-next-cd.md`。
- UnitDebuff 与 DEBUFF_ADD 事件流是否严格同源：日志推断（boss 上 Rip 缺失）需游戏内直接确认（hover debuff / listTargetDebuffs 打印）。