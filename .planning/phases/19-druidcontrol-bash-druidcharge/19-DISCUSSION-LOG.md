# Phase 19: druidControl 改造 — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-08
**Phase:** 19-druidcontrol-bash-druidcharge
**Areas discussed:** druidCharge 职责范围, 形态切换策略, 练级适配策略, druidControl 职责划分, 距离分支逻辑, druidControl 重构

---

## druidCharge 职责范围

| Option | Description | Selected |
|--------|-------------|----------|
| Charge+Bash combo | druidCharge = Feral Charge 冲锋接近 → Bash 打断，一个方法完成追击+晕眩 | |
| Bash only | druidCharge 只做 Bash 打断，Feral Charge 留给未来 | |
| Charge only | druidCharge 只做 Charge，Bash 留在 druidControl | |
| 智能优先级链 | 完整追击+控制方法 | |
| **Charge+Bash 按距离分支** | Charge 和 Bash 都在 druidCharge，按距离分两个 if-else 分支，无先后 combo 关系 | ✓ |

**User's choice:** Charge 和 Bash 同时包含在 druidCharge 中，作为依据目标距离判断的两个 if-else 分支。两者之间没有先后 combo 关系，而是纯粹按距离使用。公共逻辑：形态检查+自动切熊、isSpellExist guard。

---

## 形态切换策略

| Option | Description | Selected |
|--------|-------------|----------|
| 自动切熊+执行 | druidControl/druidCharge 不在熊形态时自动切熊 | |
| 仅熊形态执行 | 只在已在熊形态时执行，否则什么都不做 | |
| **druidCharge 自动切，druidControl 不切** | druidCharge 作为主动打断方法自动切熊，druidControl 保持不切形态 | ✓ |

**User's choice:** druidCharge 自动切熊形态，druidControl 不自动切形态。

---

## 练级适配策略

| Option | Description | Selected |
|--------|-------------|----------|
| **isSpellExist guard + 静默跳过** | 所有技能前加 isSpellExist 守卫，不存在时静默 return | ✓ |
| 等级分段逻辑 | 显式按等级分段处理不同技能组合 | |
| catLeveling 集成 | druidCharge 仅在 catLeveling 路由中生效 | |

**User's choice:** isSpellExist guard + 静默跳过，与 Phase 13/16 降级策略一致。

---

## druidControl 职责划分

| Option | Description | Selected |
|--------|-------------|----------|
| **平级独立方法** | druidCharge 和 druidControl 是两个独立方法，用户绑定不同按键 | ✓ |
| druidControl 调用 druidCharge | druidControl 内部先尝试 druidCharge 再 fallback | |
| druidCharge 替代 Bash 路径 | druidControl 中 Bash 分支替换为调用 druidCharge() | |

**User's choice:** 平级独立方法。druidCharge 负责熊形态打断/冲锋控制，druidControl 负责人形态控制（Hibernate/缠绕）。

---

## 距离分支逻辑

| Option | Description | Selected |
|--------|-------------|----------|
| 三段距离分支 | <8→Bash, 8-25→Charge, >25→return | |
| Charge 优先 | Charge 优先于 Bash | |
| **两段距离分支** | ≥8 码→Charge, <8 码→Bash | ✓ |
| 5 码近战阈值 | 使用 5 码作为 Bash 阈值 | |

**User's choice:** 两段距离分支。8 码以上走 Charge，8 码以内走 Bash。超过最大范围的属于正常释放失败，不用特殊处理。

---

## druidControl 重构

| Option | Description | Selected |
|--------|-------------|----------|
| **仅保留控制技能** | 删除 Bash 分支，druidControl 只保留 Hibernate + Entangling Roots | ✓ |
| 增加形态取消逻辑 | 在熊形态时自动取消切回人形 | |
| 增加技能存在性守卫 | Hibernate/Entangling Roots 也加 isSpellExist guard | |

**User's choice:** 仅保留控制技能。druidControl 删除 Bash 分支后不做其他改动。

---

## Claude's Discretion

- druidCharge 内部代码结构（形态检查→guard→距离判断→释放的具体编排顺序）
- Feral Charge 最小距离（8码边界）的精确处理
- Bash CD 检查是否加入
- 切熊时 Dire Bear Form vs Bear Form 的优先级
- druidControl 删除 Bash 分支后的完整代码
- SelfTest 注册的具体数量和内容

## Deferred Ideas

- 旋风（Cyclone）集成到 druidControl
- 熊形态其他控制技能（Demoralizing Roar、Challenging Roar、Growl）
- druidCharge 接入 catLeveling 路由
- Feral Charge + Bash 真 combo 模式（同一次按键连续执行）
- druidControl isSpellExist guard 用于练级