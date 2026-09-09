# Phase 29: 统一 landing 判定重构 - Context

**Gathered:** 2026-09-10
**Status:** Ready for planning

<domain>
## Phase Boundary

重构核心 landing 判定机制（`core/spell_trace_core.lua` 为中心的 spell trace 框架）：

- 去掉 `landSource` 参数——所有 `land = true` 注册技能统一走三证据通道（self-hit / apply / fail）+ 反推兜底的 OR 语义；证据通道按技能自然属性自动在场/缺席。
- 多猫抑制场景下 landing 判定静默失效问题由"双假设均正确"的统一设计解决（不再依赖取证仲裁）。
- 附带修复：immune 路径 2（landed + 纹理检查）因反推恢复 land 供给而重新激活。

范围锚定：仅 landing 判定机制与相关注册点/selftest；不新增技能、不改 catAtk 决策逻辑；`cpDamage` 通道只随默认常量变动行为，不改结构。
</domain>

<decisions>
## Implementation Decisions

### 核心机制（锁定，详见 DESIGN-CONTEXT.md）
- **D-01:** 去掉 `landSource` 参数与 `landSources` 表；证据通道按技能自然属性自动在场/缺席（有直伤则 self-hit 行存在，有 debuff 则 apply 行存在）——**Reversibility:** costly — 撤销需恢复注册字段与两处 dispatch 门
- **D-02:** 去重 = cast 维度谓词（`lastLand >= lastCast` 则后到正推证据丢弃）；同 cast 单条 land；同质量层内保留最早到达（游戏事件同受弹道延迟，最早 = 最准）
- **D-03:** 反推兜底 = cast 后 `intentTtl` 窗口内无 self-hit / 配对 apply / fail → 到期推定 landed（锚 = cast 时刻）；只在全窗口静默时触发，永不与游戏事件竞争
- **D-04:** fail 否决窗口化 = 存在 `cast ≤ failTime ≤ cast + intentTtl` 的 fail 即否决（替代旧 ±0.05s 邻接启发式）
- **D-05:** `intentTtl` 一参三用：配对接收窗、反推裁决上界、fail 否决窗
- **D-06:** fail-wins 保留：同 cast 内 fail 即使后到（窗口内）仍撤销已推 land（`finalizeFail` revoke 语义不变）
- **D-07:** intent 播种时附带 `intent.ttl = config.intentTtl or macroTorch.LAND_INTENT_TTL`；`pairLandIntent` purge/pair 与 `finalizeFail` 窗口判定改读 `intent.ttl`
- **D-08:** FB 续期 push（`recordLandEvent('Rake'/'Rip', fbTime)`）绕过 cast 谓词去重，前置条件（`isRipPresent` 才续）保留

### API 形态
- **D-09:** register 新参数命名 **`intentTtl`**（与 intent.ttl 播种字段同名）
- **D-10:** 全局常量 **`LAND_INTENT_TTL` 保留为默认值来源，值改 0.9**；注释更新为"默认证据接收窗，register 参数可逐技能覆盖"；cpDamage 配对继续引用它、自动跟随 0.9
- **D-11:** 续期豁免用**独立函数 `recordLandEventRenewal(spell, time)`**，内部绕过去重直推新锚；普通三通道只走带去重的 `recordLandEvent`
- **D-12:** 猎人钉刺（Serpent/Scorpid Sting）显式 `intentTtl = 2`（弹道飞行），其余吃默认 0.9

### 反推通告观感
- **D-13:** 文案沿用现有 landed 格式 + `(inferred)` 后缀（`Rip cast on X landed: 2792.5 (inferred)`），实机肉眼可辨"apply 确认"与"反推兜底"
- **D-14:** 颜色**蓝色**（继承旧 computeLandTable 观感，与 green 正推通道可辨）

### 测试与验证范围
- **D-15:** selftest Q-01 重写为**统一 OR 行为断言**（不再断言已删的 landSources 表）
- **D-16:** 新增**全量六组**边界用例：无证据时反推触发 / apply 后到同 cast 被拒 / fail 窗口内否决与窗外不否决 / intentTtl 0.9 与 2 边界 / 续期豁免 / 远程迟到时序（apply 迟到 1s 后可配对）
- **D-17:** cpDamage 伤害配对窗跟随全局默认 0.9（引用同一常量自动生效；claw/shred/bite 全近战，0.9 足够）

### 边界行为拍板
- **D-18:** 远程反推锚偏早一个弹道飞行时间**接受为最终形态**（保守提前重挂、不留空窗），本 phase 不引入 anchorBias

### Folded Todos
- **`druid-rip-land-forensics-next-cd.md`（2026-09-07 CD 取证协议）已关闭**：其待裁决问题（多猫 apply 行抑制）由本 phase 的统一设计解决（对抑制与否两种假设均正确），RAWDIAG2 取证装置已随 quick 260909-w3r 移除。Todo 文件随本 phase 删除。
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 本 phase 专属
- `.planning/phases/29-landing/DESIGN-CONTEXT.md` — 8 条锁定决策全文 + 落地范围 + 用户侧 UAT 要点（本 phase 的权威设计输入）
- `.planning/ROADMAP.md` — Phase 29 Goal 摘要

### 前序 phase 决策（互动面）
- `.planning/phases/28-cat-druid-claw-shred-bite-claw-shred-bite-catatk-catatk-mac/28-CONTEXT.md` — cpDamage D-01~D-10（D-02 配对窗与 LAND_INTENT_TTL 的引用关系）、打点体系约定
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `pairLandIntent`（spell_trace_core.lua）— purge/pair 双趟骨架直接改造（窗口改读 intent.ttl）
- `computeLandTable`（git 历史 `eb56a257:core/spell_trace_core.lua:150`）— 旧反推算法原文（blip 0.02~0.9、±0.05s 否决），本 phase 按 D-03/D-04 改良复活
- `LRUStack`、`recordLandEvent` 监听框架、`consumeLandEvent/consumeFailEvent` — 结构全部可复用
- `finalizeFail` revoke 机制（land 撤销 + fail-wins）— 保留不改语义
- selftest 既有 fixture 化风格（fakeLoginContext / fakeTarget / pcall 隔离）— 新边界用例沿用

### Established Patterns
- Lua 5.0 语法门（无 `#`/goto/`::`）、bbcheck 括号平衡、LF 行尾、代码注释与提交信息英文
- `SM_EXTEND.lua` 是 build 产物：源码改动不触碰、不跑 build 脚本（构建在用户 Windows+Cygwin 侧）
- 常量模块级定义带英文注释（现 LAND_INTENT_TTL = 2 在 spell_trace_core.lua:15）

### Integration Points
- 注册点：`classes/druid/Druid.lua:802-829`（Pounce/Rake/Rip/FB/FF）、`classes/hunter/Hunter.lua:151-165`（Serpent/Scorpid）
- 事件派发：`core/events.lua` tier-1 双通道白名单 → tier-2 pattern 遍历 → `processRawAuraApply`；self-hit 走 CHAT_MSG_SPELL_SELF_DAMAGE → `onSelfDamageLine`
- 免疫联动：`core/spell_trace_immune.lua` 0.1s 周期任务消费 land/fail 事件
- 续期监听器：`classes/druid/Druid.lua`（`onLandEvent('Ferocious Bite')` → 重写 Rake/Rip 锚）
</code_context>

<specifics>## Specific Ideas

- 反推通告字面格式：`{spell} cast on {mob} landed: {time} (inferred)`，蓝色
- 正推通道现有通告（green）文案与顺序不动；因果序约定（announce 先于 recordLandndEvent）保持
</specifics>

<deferred>
## Deferred Ideas

- **FF 开 land 追踪**：FF 目前 land=false 仅免疫追踪，未来可能想让它走统一通道——属新能力变更，独立决策
- **anchorBias 参数**：若将来要消掉远程兜底锚偏差（cast+期望飞行时间），可给 register 加字段——本 phase 不引入
- **动态 TTL 学习**：按目标/距离自学习 cast→resolve 延迟调整 intentTtl——已否定，防再提
</deferred>

---

*Phase: 29-landing*
*Context gathered: 2026-09-10*