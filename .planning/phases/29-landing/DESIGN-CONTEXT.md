# DESIGN-CONTEXT — 统一 landing 判定重构（锁定设计）

> 2026-09-09 与用户逐轮讨论收敛。本文件是 `/gsd-plan-phase 29` 的输入，其中条款均为锁定决策，planner 不得重新讨论其方向（细节实现方式可以细化）。

## 背景（问题）

- 实测发现 `"is affected by <X>"` 疑似 target 级状态跃迁消息：目标身上已有 X 效果（无论自己或他人释放）保持不断时，后续同技能 cast 不再触发该消息（假设为真，多猫场景已反馈此现象）。
- 当前 `landSource = 'aura-apply'` 的 landing 判定强依赖该事件与 cast intent 的配对，多猫重叠时静默失效（Rip/Pounce/Serpent Sting/Scorpid Sting）。
- RAWDIAG2 取证插桩已全部移除（quick 260909-w3r），多猫仲裁由本方案的"双假设均正确"性质解决。

## 锁定决策

1. **去掉 `landSource` 参数**：`SpellTrace:register` 删除该字段；所有 `land = true` 技能统一走三证据通道 OR 语义。证据通道按技能自然属性自动在场/缺席（有直伤则 self-hit 行存在；有 debuff 则 apply 行存在）。
2. **去重**：cast 维度谓词——最近 cast 已被 land 覆盖（`lastLand >= lastCast`）时，后到的正推证据丢弃；同 cast 单条 land；同质量层内保留最早到达（游戏事件同受弹道延迟，最早 = 最准）。
3. **反推兜底**：cast 后 `intentTtl` 窗口内无 self-hit / 配对 apply / fail → 窗口到期推定 landed，锚 = cast 时刻（远程偏早一个飞行时间，保守接受）。反推只在全窗口静默时触发，永不与游戏事件竞争。
4. **fail 否决窗口化**：存在 `cast ≤ failTime ≤ cast + intentTtl` 的 fail → 本次反推否决（替代旧 ±0.05s 邻接启发式）。
5. **可配 `intentTtl`**：register 新参数，默认 0.9s（< 1s GCD，跨 cast 交叉数学上不可能）；猎人钉刺（Serpent/Scorpid Sting）显式 ~2s（弹道飞行）。一个参数三用：配对接收窗、反推裁决上界、fail 否决窗。全局常量 `macTorch.LAND_INTENT_TTL` 保留为默认值（cpDamage 配对等未注册场景继续使用），其 2s 旧值说明需随重构更新。
6. **fail-wins 保留**：同 cast 内 fail 即使后到（窗口内）仍撤销已推 land（现有 `finalizeFail` revoke 语义不变）。
7. **FB 续期豁免**：FB land 监听器推的续期锚（`recordLandEvent('Rake'/'Rip', fbTime)`）绕过步骤 2 的去重谓词（它就是要写新锚）；现有前置条件（`isRipPresent` 才续）保留。
8. **intent 附带 ttl**：播种时 `intent.ttl = config.intentTtl or macroTorch.LAND_INTENT_TTL`；`pairLandIntent` 的 purge/pair、`finalizeFail` 的窗口判定均改读 `intent.ttl`。

## 附带收益

- 多猫抑制场景：apply 被抑制 → 反推兜底照常交付 land（统一方案对"抑制与否"两种假设均正确）。
- immune 判定路径 2（landed + 纹理检查）因反推恢复 land 供给而重新激活（纯 dot 技能的真实免疫自检通道复活）。

## 落地范围（供 planner 细化）

- `core/spell_trace_core.lua`：register 改签名与守卫（pattern-safe 断言）、删 landSources 表与消费点、`onSelfDamageLine` 去早退门（保留 tracingSpells 门）、复活 `maintainLandTables`/`computeLandTable`（0.1s 周期、blip 窗 = intentTtl、cast 谓词去重、窗口化 fail 否决、常数提为命名常量）、intent.ttl 贯通三处窗口判定、`recordLandEvent` 增加去重层 + 续期豁免入口。
- `core/events.lua`：tier-2 派发已按 pattern 表遍历，自动覆盖新名字（无需改动确认）。
- `classes/druid/Druid.lua`、`classes/hunter/Hunter.lua`：注册点删除 `landSource` 字段；猎人钉刺显式 `intentTtl = 2`；FB 续期监听器改用豁免入口。
- 反推 ledger 通告建议带 `(inferred)` 标记（可辨识性）；rawdiag2 相关的旧注释残留（若有）一并清理。
- selftest：Q-01（landSources 断言）改写为统一行为断言；新增：反推在无证据时触发、窗口化 fail 否决、cast 谓词去重（后到同 cast 证据被拒）、intentTtl 0.9/2 边界、续期豁免。
- Lua 5.0 令牌、bbcheck、LF、英文注释、SM_EXTEND.lua 为 build 产物不触碰（不跑 build）。

## 用户侧实机验证要点（写入 UAT）

- Windows+Cygwin rebuild SM_EXTEND.lua；登录横幅确认 CONFIG_OPTIONS 四项。
- 单人木桩：Rip/Rake/FB 正常落地通告（apply/hit 通道），无（inferred）标记或仅偶发。
- 多猫同一目标（远程网友零实时交流，无强制配合）：你的 Rip 施放后观察 `(inferred)` 兜底通告生效、ripLeft 正常启动（不再每帧重放 Rip）。