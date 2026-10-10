# Changelog

本文件记录 `godot-arpg-kit` 的所有重要变更。格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

---

## [Unreleased]

暂无变更。

---

## [0.2.0] — 2026-10-10

可靠性与集成改进版本，包含接入行为变化。旧项目接入变化见 [升级指南](docs/migration-v0.2.0.md)。

### 修复

- 背包与装备恢复先完整校验后提交，失败保留物品、金币、重量和属性；物品解码拒绝非法堆叠、耐久、词缀与重复身份，存档自定义数据深拷贝。
- 装备恢复重建套装件数和运行时修正器，反复加载不叠加属性，损坏装备不应用加成；属性通知在恢复提交后派发。

- 任务恢复先校验后替换；失败保留运行状态，成功清空旧事件索引并断开旧实例回调。任务元数据与目标自定义数据使用独立存档快照。

- 装备与背包使用统一转移入口；卸装检查实际入包结果，换装失败原位恢复，提交后通知，阻止同步重入。默认卸装缺少背包时保留装备。
- 背包拒绝同一实例重复入包；旧装备返还到其他空格时通知正确的物品与格子，监听器填入原格子不会被误报为换装新增。
- 装备属性使用独立运行时修正器，不修改共享模板。损坏时移除属性，修理恢复一次；已损坏装备不应用加成，耐久通知派发时属性已更新。

- 拾取先提交背包/金币转移；满包、超重或缺少接收方时保留掉落物，部分堆叠保留余量。阻止重复与信号重入拾取。
- InventoryManager 的部分堆叠和堆叠加新格子通知准确报告本次入包总量。
- 掉落对象池正确回收、复位与释放；支持池满临时实例、外部释放后补池、生成器清场隔离、销毁活跃对象、无精灵消失和金币图标复位。

- QuestEventBus 在 TaskManager 晚于 autoload 创建或重建后仍能转发事件；管理器离开场景树时清理单例引用。
- EnemyLootComponent 支持同级 CombatComponent / StatsComponent 的死亡信号，不要求角色脚本额外转发。优先选择单个信号来源。
- 掉落物加入父节点后再设置全局位置，修复关卡父节点存在偏移时的位置错误。
- DOT/HOT 测试释放源角色，消除战斗测试退出时的节点与资源泄漏。

### 兼容性变化

- 背包与装备 `from_dict()` 返回 `bool`，不再部分加载或忽略错槽。新增 `inventory_restored` / `equipment_restored`；装备恢复不触发装备、卸装或套装玩法事件，保留存档绑定状态且不重新检查等级。

- `TaskManager.load_data()` 返回 `bool`；未知任务、重复 ID 或无效字段使整次恢复失败，替代原先跳过未知任务的行为。先注册存档所需任务再恢复。

- `InventoryManager.equip_item()` 连接实际 EquipmentManager 时要求双向背包引用一致；默认卸装不再在没有背包时丢弃装备。手工接管物品使用 `unequip(slot, false)`。

- `loot_picked_up` / `item_picked_up` 现在是转移成功后的通知，携带实际转移数量的快照。在旧信号中入包的接入代码应迁移到同步 `pickup_handler`，或删除并使用默认 `InventoryManager` 接收方，避免重复入包。
- 新增 `gold_picked_up(amount, picker)` 提供准确金额。完整迁移说明见快速入门和掉落系统文档。

### 测试与开发流程

- 新增 5 项物品/背包/装备恢复回归，覆盖损坏数据、JSON 往返、失败保护、重复恢复、派生状态、恢复通知与快照隔离。

- 新增 3 项任务恢复回归，覆盖重复恢复、旧实例隔离、损坏数据回滚、JSON 往返和快照隔离。

- 新增 14 项装备运行时回归，包括失败回滚、资源隔离、通知和耐久生命周期。

- 新增 15 项掉落运行时回归及 1 项物品快照回归。完整攻击掉落任务链路启用对象池。

- 新增 Python 3 跨平台测试入口；PowerShell 包装器与 CI 使用相同实现。
- 严格检查导入、模块名称、非零测试数量、统计一致性、退出码、意外错误和泄漏。每次运行保存独立日志与 JSON 汇总。
- Quest / Stats 报告改写到 `user://`，测试不再覆盖仓库内的历史报告。
- 用有效断言替换原任务事件占位测试，新增攻击、死亡、掉落、拾取、装备、属性变化和任务完成的完整集成回归。
- CI 验证 Godot 4.5 / 4.6.3，校验官方下载的 SHA-512，并上传当前运行日志。

### 集成边界

- 任务事件由业务层显式桥接；没有 TaskManager 时事件不会缓存。
- 已覆盖背包满、部分拾取与对象池生命周期。已验证 headless 的真实拾取碰撞事件；图形交互、复杂碰撞布局与平台导出仍需专项验证。

---

## [0.1.1] — 2026-07-21

补丁版本，聚焦 CI 稳定性与文档完善。**无生产代码变更**——库使用者可无痛升级。

### ✨ 新增（Added）

- **[docs/getting_started.md](docs/getting_started.md)**：15 分钟集成教程，覆盖 4 种集成方式（fork / 子目录拷贝 / git subtree / addon 展望），6 步集成流程，7 大常见踩坑清单。
- **[docs/tech-notes/godot-arpg-kit-postmortem.md](docs/tech-notes/godot-arpg-kit-postmortem.md)**：v0.1.0 打造 postmortem 长文（389 行），分三节复盘：战斗管线双重结算 BUG 诊断、测试 flake 治理 (`seed(0)`)、Godot 4 CI 实践。

### 🔧 变更（Changed）

- **CI 换掉 `barichello/godot-ci:4.5` docker image，改用官方 Godot binary + `apt install` X 库**：
  - 之前用 `barichello` 时 5 个 matrix job 中 4 个卡在 "Run suite" 步骤 20+ 分钟不返回。该镜像本身为 export 设计，不适合 headless test。
  - 现改成在 `ubuntu-latest` runner 上下载官方 4.5-stable linux binary，加 `timeout-minutes: 10` 兜底。
  - CI 时间从"不可预测"缩到 **2 分钟**。
- **CI 增加 `godot --headless --import` 预热步骤**：
  - 新建项目 CI 首次运行时缺少 `.godot/imported/` 缓存，导致 `load("res://xxx.gd").new()` 失败：`Nonexistent function 'new' in base 'GDScript'`。
  - 现在在跑测试前先做 `--import`，失败时回退到 `--editor --quit`（60s 超时兜底）。

### 🐛 修复（Fixed）

- 无生产代码修复。CI 修复见 Changed 段。

---

## [0.1.0] — 2026-07-21

首个公开发布版本。**189 个测试全部通过**，稳定可用。

### ✨ 新增（Added）

- **完整的 2D ARPG 核心系统**：Combat / Stats / StatusEffects / Skills / Items / Inventory / Equipment / Loot / Quest 共 9 大子系统，均可独立使用或成套集成。
- **Autoload 事件总线**：`CombatEventBus` 与 `QuestEventBus` 提供解耦的跨系统事件通信。
- **CombatEventBus 默认状态效果注册**：`shocked` / `burning` / `frozen` 三种元素反应 debuff 会在 `_ready()` 自动注册，避免元素反应静默失败。
- **护甲穿透 / 法术穿透专用字段**：新增 `StatType.ARMOR_PENETRATION` 与 `MAGIC_PENETRATION`；旧实现错误地把 `PHYSICAL_DAMAGE_REDUCTION`（受伤减免）当成攻击穿透使用，现已修正。
- **消耗品 `use_item` 实际生效**：`InventoryManager.use_item()` 现在会真正应用 `ConsumableData.effect_type`（INSTANT_HEAL / INSTANT_MANA / INSTANT_STAMINA / BUFF / STAT_BOOST / HEAL_OVER_TIME / MANA_OVER_TIME / DEBUFF_CURE）到目标 stats/status 组件。
- **背包装备事务化**：`InventoryManager` 新增可选 `equipment_manager` 引用；配置后 `equip_item` 走 remove → equip 事务，装备失败自动回滚，避免物品丢失。
- **测试套件（189 个）**：
  - Combat: 66（含新增的 6 个伤害管线回归测试 + 13 个高优先级 BUG 回归测试）
  - Items: 18
  - Loot: 11
  - Quest: 55
  - Stats: 39
- **测试基础设施**：
  - `tests/base/test_framework.gd` 共用断言基类
  - 各模块 `test_runner.gd` 打印 `[RESULT] suite=X passed=Y failed=Z total=T` 机器可读汇总行
  - 所有 runner 开头调 `seed(0)`，flake 完全消除
- **工程化**：
  - `tools/run_tests.ps1` 一键跑所有模块，按 `[RESULT]` 行解析成败（不依赖 Godot 进程退出码）
  - `tools/pre-commit.ps1` Git 预提交钩子模板
  - `.github/workflows/tests.yml` GitHub Actions matrix workflow（5 模块并行）
- **文档**：
  - README.md（架构总览、5 个使用示例、伤害管线时序图、FAQ）
  - docs/getting_started.md（15 分钟集成教程，4 种集成方式，7 大常见踩坑）
  - docs/{Combat,Stats,StatusEffects,Skills,Items,Inventory,Equipment,Loot,Quest}系统使用文档.md

### 🐛 修复（Fixed）

- **【严重】伤害管线双重结算**：`CombatComponent.receive_damage` 之前会调用 `stats_component.take_damage()` 触发完整减伤链，与 `DamageCalculator.calculate_damage()` 已经完成的减伤发生**双重计算**（防御减两次、闪避判定两次、临时护盾消耗两次）。改为直接 `stats_component.lose_health(final_damage)` 纯扣血。
- **护甲穿透字段错误**：见 Added 中 `ARMOR_PENETRATION` 说明。
- **消耗品无效**：见 Added 中 `use_item` 说明。
- **EventBus 未 autoload**：旧版 `project.godot` 缺少 `[autoload]` 段，导致 `CombatEventBus.instance` 永远为 `null`，各模块 emit 的事件全部静默丢失。现已注册。同时去掉 `QuestEventBus` 的 `class_name`（避免与 autoload 名冲突），`static var instance` 改为 `Node` 类型。
- **`DamageInfo.knockback_force` 语义**：从 `Vector2` 改为 `float`。旧实现里 `Vector2 × Vector2` 是**分量乘积**（不是"力 × 方向"），会把击退方向压到单一轴上，垂直方向击退直接失效。
- **背包 `_try_stack_with_existing` 无法部分堆叠**：旧实现依赖 `can_stack_with()` 的总量检查（`slot.count + other.count <= max`），一旦总量溢出就完全不堆叠——目标格剩 2 空间遇到 other=6 时会一件都不堆。改为逐格 `min(空间, remaining)` 手动部分堆叠。
- **`add_item` 部分成功不发信号**：现在部分入包也 `emit item_added(item, -1) + inventory_full`，让 UI 能刷新已堆叠格子并显示"背包已满"提示。
- **测试 flake**：多个测试因 `StatsData` 默认值（`dodge_chance=0.05`、`crit_chance=0.05`、`luck=10` 派生规则）触发低概率 rng 分支导致偶发失败，已通过 `seed(0)` + 显式清零属性一次修复。

### 📝 变更（Changed）

- `combat_state.can_transition` 保留原有语义（`BEING_HIT → any state` 允许被打断）。
- `equip_item` 保留旧 API（未配置 `equipment_manager` 时降级为"仅 remove"并 push warning）。
- README 从简单说明扩展为完整的开源项目文档（含架构图 / 时序图 / 使用示例）。

### 🗑️ 移除（Removed）

- `QuestEventBus` 的 `class_name QuestEventBus` 声明（与 autoload 名冲突）。

### 已知限制

- 3D 场景暂未测试兼容性（除 `LootGenerator` 使用 `Vector2` 散开外，其他系统应可直接用于 3D）。
- 未打包成 Godot 4 addon（`addons/` 目录格式），当前需要手动拷贝子目录。
- 联机 / 多人网络同步未做设计。

---

[0.1.0]: https://github.com/ClarkWain/godot-arpg-kit/releases/tag/v0.1.0
[0.1.1]: https://github.com/ClarkWain/godot-arpg-kit/releases/tag/v0.1.1
