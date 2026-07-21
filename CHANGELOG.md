# Changelog

本文件记录 `godot-arpg-kit` 的所有重要变更。格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

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
