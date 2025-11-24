# Quest 系统使用文档

## 概述

Quest 系统是一个灵活的任务管理系统，支持多种类型的任务目标、条件和奖励。系统采用事件驱动架构，通过 QuestEventBus 解耦游戏逻辑与任务逻辑。

### 主要特性

- **多种任务类型**: 支持主线、支线、日常、周常、成就等任务类别
- **灵活的目标系统**: 支持计数目标、状态目标等多种目标类型
- **条件系统**: 支持接取条件、完成条件、失败条件
- **奖励系统**: 支持多种奖励类型，可选奖励
- **时间限制**: 支持限时任务和冷却时间
- **可重复任务**: 支持可重复任务和最大完成次数限制
- **事件驱动**: 通过事件总线自动更新任务进度
- **高性能**: 采用事件索引和 StringName 优化，支持大量并发任务
- **强类型**: 使用 QuestEventData 提供类型安全的事件传递

## 主要组件

### 1. QuestEventBus (任务事件总线)

单例节点，负责游戏事件与任务系统的通信。

**位置**: `scripts/quest/quest_event_bus.gd`

**主要功能**:
- 定义各种游戏事件信号
- 自动连接到 TaskManager 更新任务进度
- 提供静态方法触发事件
- 使用 `QuestEventData` 封装事件数据

### 2. TaskData (任务数据)

Resource 类，存储任务的静态配置信息。

**位置**: `scripts/quest/task_data.gd`

**主要属性**:
- `task_id`: 任务唯一标识
- `task_name`: 任务名称
- `description`: 任务描述
- `category`: 任务类别
- `objectives`: 任务目标列表
- `accept_conditions`: 接取条件
- `complete_conditions`: 完成条件
- `fail_conditions`: 失败条件
- `rewards`: 奖励列表
- `time_limit`: 时间限制
- `repeatable`: 是否可重复

### 3. TaskInstance (任务实例)

运行时任务实例，管理任务状态和进度。

**位置**: `scripts/quest/task_instance.gd`

**主要功能**:
- 管理任务状态转换
- 更新目标进度
- 检查完成条件
- 序列化/反序列化
- 维护事件监听索引

### 4. TaskManager (任务管理器)

单例节点，管理所有任务的生命周期。

**位置**: `scripts/quest/task_manager.gd`

**主要功能**:
- 注册任务数据
- 管理任务实例
- 处理任务状态转换
- 保存/加载任务进度
- 维护全局事件索引，优化事件分发性能

### 5. QuestEventData (任务事件数据)

强类型的事件数据类，替代 Dictionary 传递事件信息。

**位置**: `scripts/quest/core/quest_event_data.gd`

**主要属性**:
- `type`: 事件类型 (StringName)
- `target_id`: 目标ID (StringName)
- `state`: 状态值 (StringName)
- `count`: 数量 (int)
- `position`: 位置 (Vector2)
- `custom_data`: 自定义数据 (Dictionary)

## 使用示例

### 1. 基本任务创建

```gdscript
# 创建任务数据
var task_data = TaskData.new()
task_data.task_id = "kill_goblins"
task_data.task_name = "消灭哥布林"
task_data.description = "消灭10只哥布林"
task_data.category = "支线"

# 添加目标
var objective = CountObjective.new()
objective.target_type = &"kill_enemy"
objective.target_id = &"goblin"
objective.required_count = 10
task_data.objectives.append(objective)

# 添加奖励
var reward = ItemReward.new()
reward.item_id = "gold_coin"
reward.quantity = 100
task_data.rewards.append(reward)

# 注册任务
TaskManager.instance.register_task(task_data)
```

### 2. 任务接取和完成

```gdscript
# 检查是否可以接取
if TaskManager.instance.can_accept_task("kill_goblins"):
    # 接取任务
    TaskManager.instance.accept_task("kill_goblins")
    print("任务已接取")

# 当玩家击杀哥布林时，触发事件
# 推荐使用静态辅助方法
QuestEventBus.emit_enemy_killed("goblin", "goblin_001", 1)

# 或者手动构建事件数据
var event = QuestEventData.new()
event.type = &"kill_enemy"
event.target_id = &"goblin"
event.count = 1
TaskManager.instance.update_task_progress(event)

# 任务完成后领取奖励
if TaskManager.instance.claim_rewards("kill_goblins"):
    print("奖励已领取")
```

### 3. 自定义目标类型

要创建自定义目标类型，需要继承 `TaskObjective` 类并实现关键方法：

```gdscript
class_name CustomObjective
extends TaskObjective

# 定义关心的事件类型，用于构建索引
func get_interested_events() -> Array[String]:
    return ["custom_event"]

# 实现多态实例化
func instantiate() -> TaskObjective:
    var instance = CustomObjective.new()
    # 复制属性...
    instance.initialize()
    return instance

# 更新进度
func update_progress(event_data) -> void:
    var event: QuestEventData
    if event_data is QuestEventData:
        event = event_data
    else:
        event = QuestEventData.from_dict(event_data)
        
    if event.type == &"custom_event":
        # 更新逻辑...
        pass
```

## 性能优化

### 1. 事件索引机制

TaskManager 维护了一个 `_event_index` 字典，将事件类型映射到关心的任务列表。当事件发生时，系统只遍历相关的任务，而不是所有活跃任务。这使得事件处理的时间复杂度从 O(N) 降低到 O(K)（K为关心该事件的任务数）。

### 2. StringName 优化

系统内部大量使用 `StringName` 替代 `String` 进行类型和ID的比较。`StringName` 基于唯一ID比较，速度远快于字符串比较。

- 事件类型 (`type`)
- 目标ID (`target_id`)
- 状态值 (`state`)

### 3. 强类型数据

使用 `QuestEventData` 类替代 `Dictionary` 传递事件数据，避免了哈希查找开销，并提供了编译时类型检查。

## 最佳实践

### 1. 任务设计

- **任务ID命名**: 使用清晰的命名规范，如 `quest_kill_goblins_001`
- **目标权重**: 为不同重要性的目标设置合适的权重
- **条件组合**: 合理组合多个条件，避免过于严格的限制

### 2. 事件管理

- **事件命名**: 使用一致的事件类型命名，如 `kill_enemy`, `collect_item`
- **事件数据**: 在事件数据中包含足够的信息用于目标匹配
- **使用 StringName**: 在代码中尽量使用 `&"string"` 语法创建 StringName

### 3. 扩展性

- **模块化**: 将不同类型的目标、条件、奖励分离到独立文件
- **继承**: 利用继承机制复用通用逻辑
- **多态**: 正确实现 `instantiate` 和 `get_interested_events` 方法

### 4. 调试和测试

- **日志记录**: 在关键节点添加日志，便于调试
- **单元测试**: 为核心逻辑编写单元测试
- **边界情况**: 测试各种边界情况，如超时、失败等