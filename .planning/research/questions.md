# Research Questions

待深入调查的开放问题清单。条目格式：`- [open] 问题描述 — 来源/触发条件`；已解决迁移到 `- [resolved] …` 并注明出处。

---

## 猫德 catAtk / Rip 判定

- [open] SuperWoW `DispatcherRawCombatLog`/`SDispatchRawCombatLog` 内部实现不可核验（闭源）；外部行为结论（arg1=频道名、arg2=GUID 文本）依据官方文档与本地 dump 样本（admitted），内部语义如需进一步确认只能实机验证 — 2026-09-07 探索会话（`notes/solnius-rip-presence-raid-evidence.md` 未决 ledger，[abstain: unverifiable]）
- [open] 为何 Solnius（raid boss）的 Rip debuff 状态视图（DEBUFF_ADD 流）6 分钟仅出现 1 条，而应用行流（AURA_CAST）健康（17 条，与 3 猫施法 1:1）且施法时刻占用仅 8~13 行未达 16/32 上限（2026-09-07 三层对照已证）——候选：raid boss 特异 aura 同步/图标排序行为？与"tick 活性≡我的 Rip"修复设计相关：SPELL_DMG tick 在本 boss 稳定下发（~2s 间隔），是替代 hasBuff 的候选信号源 — 2026-09-07 Solnius 日志取证（AURA_CAST/DEBUFF_ADD 对照修订）
- [open] 木桩已证"同施法者 refresh 时客户端收不到 apply 行"（`debug/catatk-premature-rip-recast.md:115`）；该抑制是否扩展至"目标身上已有**任意人**的 rip"（即使施法者不同）？es.txt 是服务器事件层（17/17 无抑制、含自 refresh），无法观测客户端行级行为——若扩展成立，Jadepaw 从 +8.3s 起每次 cast 的 land 都无法配对（绿行缺席、ripLeft 恒 0），10/10 重放自洽；需下 CD 绿色行计数裁决（todo `druid-rip-land-forensics-next-cd.md` 步骤 1）— 2026-09-07 用户假设（多猫 landing 行去重）验证
- [open] UNIT_CASTEVENT 对瞬时法术（Rip/Rake）的触发时序 vs `_pendingCastSpellName` 桥的赋值时序，是否可能使 intent 从未种子化（A1）——日志侧 AURA_CAST 健康已使此路径降级为次要，仅当下一 CD 探针显示 peekLandEvent 为 nil 且 listDebuffs 可见 Rip 时才需重启此题（见 todos `druid-rip-land-forensics-next-cd.md`）— 2026-09-07 修订