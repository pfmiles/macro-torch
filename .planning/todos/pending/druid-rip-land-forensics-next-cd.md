# Todo: 下个 CD 实机取证 Rip 存在性误判的剩余判别点

> 日期：2026-09-07 | 优先级：high | 来源：`/gsd-explore`（Solnius Rip re-cast 排查）+ `/gsd-capture` brainstorm 修订（2026-09-07，见 `notes/solnius-rip-presence-raid-evidence.md` 修订版）

## 背景

Solnius 战 Jadepaw 正常阶段 9 个 5cp 全部重放 Rip、0 bite。**2026-09-07 二次日志取证（AURA_CAST vs DEBUFF_ADD 三层对照）后，证据链如下：**

- 应用行流（AURA_CAST，等价于 addon 的 raw "is afflicted by" 输入）**健康**：boss 上 rip 共 17 条，Jadepaw 9 次成功施法 1:1 对应（时差 ≤0.5s）。用户信任的事件机制未被证伪。
- debuff 状态表（DEBUFF_ADD，近似 UnitDebuff 可见视图）**几乎全程缺失 rip**：6 分钟全战仅 1 条（+110.4s，Sevenstar 的），同流 Rake 有 9 条；且 rip 施法时刻 boss 行数仅 8~13，**未达 16/32 槽位上限**——"超 32 被挤出"的拥挤机制被否定。
- **用户新假设（2026-09-07）与裁决：** "多猫同时用 rip 时客户端不为每只猫各出 landing 行"——事件层被 es.txt 否定（AURA_CAST 17/17 成行，含交叉重叠与自 refresh）；但 `debug/catatk-premature-rip-recast.md:115` 记录的"同施法者 refresh 时客户端收不到 apply 行"若扩展至"他人 rip 已激活"场景，则 **Jadepaw 从 +8.3s 起一次 landing 行都收不到 → land 表全程空 → ripLeft 恒 0 → 全程重放完美自洽**，且与"没有绿色 landed 行"的记忆吻合。**landing 腿因此复活为与 hasBuff 腿并列的活体候选**——es.txt 是服务器事件层，看不到客户端行级抑制，须下 CD 实机裁决。
- 代码对照：rip/rake 检测是 macroTorch 自实现（`entity/Unit.lua:26` hasBuff 扫 UnitDebuff 1..40 + `texture_map.lua:40` 本地贴图），**SuperMacro 的方法完全不在此链路上**；失败通道（miss/dodge）只解析 "Your ..." 自身报文，无跨猫污染；land 配对的目标 GUID 校验存在，施法者不可辨（WR-02 已接受 ≤2s 偏移残差）。

**收窄后的疑点（两条并列，须实机区分）：**
1. **landing 抑制腿（复活）**：客户端行级是否抑制"目标身上已有任意人 rip"时的 apply 行——若抑制，Jadepaw 每次 cast 的 land 都无法配对（绿色行缺席、ripLeft 恒 0），全程重放自洽；
2. **debuff 视图腿**：此 boss 上 rip 的 DEBUFF_ADD 状态行 6 分钟仅 1 条（占用 8~13 层不满、非 32 上限挤出）——hasBuff 恒 false 的机制层。

多猫混杂本身解释不了 10/10 重放（WR-02 只是 ≤2s 偏移），但"多猫+服务器同技能容器"是 landing 抑制假设的背景条件。

## 取证步骤（打桩先行 · 简化版协议；boss 战三探针下周仍为备选复核）

> 2026-09-07 按用户要求简化：不要求网友任何复杂配合——网友只需"接到信号后上来打桩，之后正常打"。证据由 RAWDIAG2（quick-260907-mhh 插桩）自动持久化，无需肉眼数绿色行。

**协议原则**：你打你的标准 catAtk 流程，插桩全自动采集；唯一一句话交代给网友：**"等我先打一轮（约 20~30 秒）再上来打，全程盯着同一只桩。"**

0. **开启取证总开关（WR-02 修复后新增）**：开打前游戏内 `/run macroTorch.rawdiag2Enabled=true`（默认关；每次登录/reload 自动复位为关——测试中途勿 reload，测试结束 logout 即复位）。
1. **开局（阳性对照）**：你单人先开打，完成一轮 `挂 Rake → 攒星 → 挂 Rip`（≈20~30s）。你的第一撕落在"桩上无 rip"的干净状态 → 应产出 `pair-ok`（证明插桩链路工作正常）。
2. **网友进场**：网友在同一只桩上挂好 Rake+Rip 并持续正常输出（他们的循环不要求节奏）。此刻桩上已有 rip，后续一切你的撕都变成"重叠撕"——正是待验证场景。
3. **主循环 1~2 分钟**：你继续标准流程：`挂 Rake → 攒星 → 挂 Rip → 攒星 → Bite`。**Bite 照常（允许且建议）**——本服 bite 会刷新 Rip，恰好维持"桩上始终有 rip"的抑制前置条件。每 5cp 一次决策（撕/咬），循环到结束条件为止。
4. **结束条件**：你完成 **≥2 次 Rip 施放**、且每次都做出了后续决策（Bite 或再撕），或满 2 分钟，先到为准。
5. **禁区**：全程勿换目标、勿把桩打死（血量不够就选更高级的桩）；中途勿 `/reload`（flush 会截断窗口）；测试结束 logout 一次即完成 flush。
6. **回报**：拷回 `WTF/Account/<账号>/SavedVariables/SuperMacro.lua` 中 `MACRO_TORCH_LOG.messages`（500 行环形缓冲），离线仲裁。

**证据覆盖对照与判读（拿回日志即可裁决）：**

| 协议环节 | 日志产出 | 判读 |
|---|---|---|
| 你单人第一撕（干净桩） | `[RAWDIAG2 ctx]` + `[RAWDIAG2 pair] Rip pair-ok` | 阳性对照：必现；缺席 → 插桩自身故障 |
| 网友第一撕（桩上仍无 rip）落进你已 arm 的窗口 | raw dump 里 `is afflicted by Rip` 行 + `[pair] no-pair:no-intent` | 证明"干净桩"上 apply 行可送达客户端 |
| 网友后续撕（桩上已有 rip——他自己的或你的） | raw dump 里 apply 行**是否继续出现**（旁证，见下） | 出现 → 抑制**否证**；消失 → 抑制**坐实** |
| 你自己第 2+ 撕（桩上已有网友/自己的 rip） | `[ctx]` + `[pair] Rip pair-ok`（你的 intent 在） | pair-ok → 客户端为我方出线，landing 腿健康；无声 → 抑制坐实 |

> **主裁决独立于网友侧行**：combat log 是见证者日志——你的客户端为"你亲眼盯着的桩"上的任何人的技能生成日志行（RAW 流本就含全频道事件，scout 因此在白名单前采样）。但真正的判据链（你的 `ctx` → 你的 intent → 你的 apply 行 → `pair-ok`）100% 发生在你自己的客户端：网友只是设置"桩上有 rip"这一状态，不做被测量的动作。网友侧 apply 行若出现在你的 raw dump 中是旁证加强，缺席不影响主裁决。
| 任何 ctx 行 | hasBuff / ripLeft / landTop / intentDepth / cp | 木桩上预期 hasBuff=true；意外 false = 视图腿连木桩都坏的额外数据点 |

**替代方案（协调仍困难时）**：按"网友先打、你后进"的原始顺序也可执行——仅损失行 1 的阳性对照；若全程零 `pair-ok` 将无法区分"抑制成立"与"插桩故障"，需下周 boss 战探针复核。网友侧始终无任何复杂动作要求。

> 已不需要的旧步骤：肉眼数绿色行（pair ledger + raw dump 离线重建，无观察负担）；数 Green/`listDebuffs`/`peekLandEvent` 手动探针（ctx 行已含 hasBuff/ripLeft/landTop）；"禁 FB"约束（只对已搁置的 R3 fade 复位轮有效——该轮是次级问题，不影响主裁决）。