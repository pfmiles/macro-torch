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

## 取证步骤（下一场正常模式 boss 战一次完成，省掉了原 raw 行打印步骤）

1. **数绿色 landed 行 + 三探针（landing 抑制 vs 视图缺失 分离）**
   - 每次亲自施放 Rip 后 0.5s~2s 窗口内，观察是否有绿色 `Rip cast on <mob> landed:` 行；对照 Rake 的绿色行（Rake 走 self-hit 通道不受影响，应稳定出现作基线）。
   - 同一窗口运行探针：
     - `macroTorch.target.listDebuffs()` —— 已有打印方法，直接列出 UnitDebuff 第 1~60 槽的全部 debuff
     - `macroTorch.target.hasBuff('<Rip 贴图名>')` —— 与 `isRipPresent` 同源的门
     - `macroTorch.peekLandEvent('Rip')` —— land 表是否有我的 Rip 落地记录
   - 判定表：
     - 绿色行缺席 + peekLandEvent nil + listDebuffs 可见 Rip → **landing 抑制腿坐实**（客户端行级抑制跨施法者扩展），修复方向"tick 活性/状态替代 land 配对"；
     - 绿色行出现但 hasBuff false → debuff 视图腿坐实，修复方向"tick 活性替代 hasBuff"（事件驱动方向，见 `debug/catatk-premature-rip-recast.md` 的既有设计）；
     - listDebuffs 看得到 Rip 但 hasBuff false 且绿色行有 → 贴图名不匹配（纹理串问题），查 `texture_map.lua`。
2. **开启 cpBuildLog 顺带采样**：采集 5cp 时刻的 cp/能量节奏（与 2026-09-07 quick-260907-0ya 的 cpBuildLog 设施一致，无额外成本）。
3. **tick 活性对照（顺带完成，无需额外操作）**：Rip 跳血期间若步骤 1 判定 hasBuff=false，直接记录该对照即可——tick（SPELL_DMG）在本 boss 稳定下发（es.txt 已证），是替代 hasBuff 的候选信号源。
4. **回报数据**：探针输出 + cpBuildLog 样本拷回，据实定稿修复（预期落在 isRipPresent 的 hasBuff 门替换；修复动作另行走 GSD 阶段流程）。

> 已不需要的旧步骤：原方案中的"RAW 行临时打印"（**服务器事件层**已证健康 17/17，但客户端行级抑制只能靠步骤 1 的绿色行计数判）；"木桩先行实验"（用户确认木桩从未复现——新增解释：木桩上 rip 通常单人独享全场，恰好绕过"他人 rip 已激活"的抑制前置条件，所以木桩正常反而与 landing 抑制腿**相容**，但木桩实验仍无判别力）。