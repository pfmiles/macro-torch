# Research Questions

待深入调查的开放问题清单。条目格式：`- [open] 问题描述 — 来源/触发条件`；已解决迁移到 `- [resolved] …` 并注明出处。

---

## 猫德 catAtk / Rip 判定

- [open] SuperWoW `DispatcherRawCombatLog`/`SDispatchRawCombatLog` 内部实现不可核验（闭源）；外部行为结论（arg1=频道名、arg2=GUID 文本）依据官方文档与本地 dump 样本（admitted），内部语义如需进一步确认只能实机验证 — 2026-09-07 探索会话（`notes/solnius-rip-presence-raid-evidence.md` 未决 ledger，[abstain: unverifiable]）
- [open] 为何 Solnius（raid boss）的 Rip debuff 从不进入客户端 debuff 事件流（同一客户端在小怪身上正常记录）——服务端 boss aura 同步策略？与"tick 活性≡我的 Rip"修复设计相关：需确认 boss 战里 SPELL_DMG tick 与 fade 行是否稳定可依赖 — 2026-09-07 Solnius 日志取证
- [open] UNIT_CASTEVENT 对瞬时法术（Rip/Rake）的触发时序 vs `_pendingCastSpellName` 桥的赋值时序，是否可能使 intent 从未种子化（A1）——待下 CD 实机打印验证（见 todos `druid-rip-land-forensics-next-cd.md`）— 2026-09-07