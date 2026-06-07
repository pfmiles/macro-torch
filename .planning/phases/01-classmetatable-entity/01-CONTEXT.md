# Phase 1: 基础设施 — classMetatable 工厂 + Entity 层迁移 - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning

<domain>
## Phase Boundary

建立 `core/` 基础设施层（classMetatable 工厂、initPlayer 多态工厂、LRUStack 迁移到 periodic.lua），将 9 个实体文件迁移到 `entity/` 目录并统一 metatable 构造方式，同步建立声明式构建系统（build_order.txt + 新 build.sh）。

覆盖需求: R1 (统一 Metatable), R2 (多态初始化), R6 (entity/ 目录), R7 (构建系统)
</domain>

<decisions>
## Implementation Decisions

### classMetatable API 设计
- **D-01:** 采用最简工厂方案。`macroTorch.classMetatable(cls, fieldMapName)` 仅消除重复的 setmetatable + __index 模板，1:1 映射当前 9 行模式为 1 行调用。
- **D-02:** 不引入 parent 参数、builder 模式或额外抽象层。类继承关系保持隐式（通过 build_order 顺序和现有 `__index` 链保证）。
- **D-03:** fieldMapName 接受字符串（如 `"UNIT_FIELD_FUNC_MAP"`），与现有代码风格一致。

### initPlayer 类注册机制
- **D-04:** 采用惰性注册表（Registry Table）模式。`core/class.lua` 中初始化 `macroTorch.PLAYER_CLASS_REGISTRY = {}`，提供 `macroTorch.registerPlayerClass(className, classTable)` 注册函数。
- **D-05:** 各职业文件通过 `macroTorch.registerPlayerClass("DRUID", macroTorch.Druid)` 自注册。骨架类（未实现的职业）传 nil 或跳过注册，initPlayer() 自动 fallback 到 `macroTorch.Player:new()`。
- **D-06:** `macroTorch.initPlayer()` 逻辑：查 `PLAYER_CLASS_REGISTRY[UnitClass('player')]`，若存在且非 nil 则调用 `:new()`，否则返回 `macroTorch.Player:new()`。
- **D-07:** 删除 `battle_event_queue.lua:76-78` 的 `macroTorch.player = macroTorch.druid` 替换逻辑。在 `PLAYER_ENTERING_WORLD` 中改为调用 `macroTorch.player = macroTorch.initPlayer()`。
- **D-08:** `Player.lua:535` 的 `macroTorch.player = macroTorch.Player:new()` 保留作为默认初始化。

### build_order.txt 维护策略
- **D-09:** 一次性全量文件列表。Phase 1 写出所有 Phase 2-4 的目标文件路径（含 core/events.lua, core/spell_trace.lua, classes/Druid/cat.lua 等）。
- **D-10:** Phase 1 的 build.sh 使用容错模式：`[ -f "$line" ] && cat` 静默跳过不存在的文件。Phase 4 切换严格模式。
- **D-11:** Phase 1 结束后运行验证脚本，确认幽灵条目列表与 ROADMAP 预期一致，消除静默拼写错误风险。

### LRUStack 改造 + Frame 分离
- **D-12:** LRUStack 改用 `classMetatable(nil, "ES_FIELD_FUNC_MAP")`（parent 传 nil）。这验证 classMetatable 工厂在低风险目标上的正确性，同时统一代码库 metatable 模式。
- **D-13:** classMetatable 工厂需处理 nil-parent 情况：加一行 nil-guard，cls 为 nil 时跳过 class method fallback。
- **D-14:** periodic.lua 在 Phase 1 立即拥有独立的 OnUpdate Frame。从 battle_event_queue.lua 中提取 OnUpdate 脚本（~45 行）到 periodic.lua，原文件删除对应代码块。
- **D-15:** OnUpdate 代码块与 OnEvent handler 零耦合，拆分是原子操作——无过渡状态，无双重执行风险。

### Claude's Discretion
- classMetatable 函数内部实现细节（参数校验、错误信息格式）
- build_order.txt 的具体排序（Phase 1 已知文件精确排位，未来文件按逻辑分组排列）
- periodic.lua 中 Frame 变量命名和 createFrame 位置
- LRUStack 迁移时的代码组织（是否保留 ES_FIELD_FUNC_MAP 名称或重命名）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级文档
- `.planning/ROADMAP.md` — Phase 1 完整实施步骤（1.1-1.5）、文件变更清单、验证命令
- `.planning/REQUIREMENTS.md` — R1/R2/R6/R7 验收标准（本 Phase 覆盖的 4 项需求）
- `.planning/PROJECT.md` — 项目约束（Lua 5.1、无 require、单文件输出、向后兼容）
- `docs/REFACTOR_PLAN.md` — 原始重构计划，Phase 1 的来源依据

### 代码库分析
- `.planning/codebase/ARCHITECTURE.md` — OOP metatable 继承链、Field Resolution Order、对象构造模式
- `.planning/codebase/CONVENTIONS.md` — 命名规范、FIELD_FUNC_MAP 模式、全局对象初始化约定
- `.planning/codebase/STRUCTURE.md` — 当前文件布局、构建拼接顺序、全局单例位置

### API 参考
- `.claude-reference/Functions.md` — WoW 1.12.1 完整 Macro API（UnitClass, CreateFrame, 事件系统等）
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **当前 metatable 模板** (Unit.lua:30-40, Player.lua:510-520, Target.lua:40-50, Pet.lua:50-60, Druid.lua:255-265): classMetatable 工厂的直接替换目标，9 行模式完全相同
- **LRUStack** (event_stack.lua): 75 行有界栈，被 spell trace 系统广泛使用（castTable/failTable/landTable 均为 LRUStack 实例），classMetatable(nil) 的低风险验证目标
- **OnUpdate 代码块** (battle_event_queue.lua:156-200): ~45 行完全自包含，与 OnEvent handler 零耦合，提取到 periodic.lua 无风险
- **registerPeriodicTask / removePeriodicTask** (battle_event_queue.lua): 定时任务调度器，已稳定运行

### Established Patterns
- **Field Resolution Order**: `FIELD_FUNC_MAP → class methods → parent FIELD_FUNC_MAP → ...` — classMetatable 必须保持精确等价
- **全局单例初始化**: 每个文件末尾实例化 `macroTorch.xxx = Xxx:new()` — entity 迁移后路径改变但模式不变
- **构建拼接顺序**: 工具→基类→子类→事件系统→职业类 — build_order.txt 必须保持此依赖序
- **两阶段构造器**: 类原型（`:new()` 无参）→ 实例（`:new()` 有参或闭包定义方法）— 不受此次重构影响

### Integration Points
- **battle_event_queue.lua:76-78**: `macroTorch.player = macroTorch.druid` — 多态 hack 删除点，替换为 initPlayer() 调用
- **battle_event_queue.lua:156-200**: OnUpdate frame + onPeriodicUpdate — 提取到 periodic.lua 的代码源
- **event_stack.lua**: 整个文件 — LRUStack 源文件，迁移后删除
- **Player.lua:535**: `macroTorch.player = macroTorch.Player:new()` — 默认初始化保留
- **build.sh**: 当前使用 grep -v 黑名单 — 完全重写为读取 build_order.txt
- **SM_Extend_Druid.lua:271**: `macroTorch.druid = macroTorch.Druid:new()` — 添加 `registerPlayerClass("DRUID", macroTorch.Druid)` 注册调用
</code_context>

<specifics>
## Specific Ideas

None — 所有决策均基于 ROADMAP 和现有代码模式推导，无外部参考要求。
</specifics>

<deferred>
## Deferred Ideas

None — 讨论保持在 Phase 1 范围内。
</deferred>

---

*Phase: 01-基础设施 — classMetatable 工厂 + Entity 层迁移*
*Context gathered: 2026-06-07*