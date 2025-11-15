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

## 主要组件

### 1. QuestEventBus (任务事件总线)

单例节点，负责游戏事件与任务系统的通信。

**位置**: `scripts/quest/quest_event_bus.gd`

**主要功能**:
- 定义各种游戏事件信号
- 自动连接到 TaskManager 更新任务进度
- 提供静态方法触发事件

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

### 4. TaskManager (任务管理器)

单例节点，管理所有任务的生命周期。

**位置**: `scripts/quest/task_manager.gd`

**主要功能**:
- 注册任务数据
- 管理任务实例
- 处理任务状态转换
- 保存/加载任务进度

### 5. TaskState (任务状态)

任务状态枚举和转换逻辑。

**位置**: `scripts/quest/task_state.gd`

**状态列表**:
- `LOCKED`: 锁定 - 不满足接取条件
- `AVAILABLE`: 可接取 - 满足条件但未接取
- `ACTIVE`: 进行中 - 已接取正在完成
- `COMPLETED`: 已完成 - 完成所有目标
- `CLAIMED`: 已领奖 - 已领取奖励
- `FAILED`: 失败 - 触发失败条件
- `EXPIRED`: 过期 - 限时任务超时
- `ABANDONED`: 放弃 - 玩家主动放弃

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
objective.target_type = "kill_enemy"
objective.target_id = "goblin"
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
QuestEventBus.emit_enemy_killed("goblin", "goblin_001", 1)

# 任务完成后领取奖励
if TaskManager.instance.claim_rewards("kill_goblins"):
    print("奖励已领取")
```

### 3. 条件任务

```gdscript
# 创建需要等级5的条件任务
var level_condition = LevelCondition.new()
level_condition.required_level = 5
level_condition.compare_type = LevelCondition.CompareType.GREATER_OR_EQUAL

var task_data = TaskData.new()
task_data.task_id = "advanced_quest"
task_data.task_name = "高级任务"
task_data.accept_conditions.append(level_condition)

TaskManager.instance.register_task(task_data)
```

### 4. 限时任务

```gdscript
var task_data = TaskData.new()
task_data.task_id = "time_limited_quest"
task_data.task_name = "限时任务"
task_data.time_limit = 3600.0  # 1小时

# 添加目标
var objective = LocationObjective.new()
objective.target_location = "dungeon_entrance"
task_data.objectives.append(objective)

TaskManager.instance.register_task(task_data)
```

### 5. 可重复任务

```gdscript
var task_data = TaskData.new()
task_data.task_id = "daily_kill"
task_data.task_name = "每日击杀"
task_data.repeatable = true
task_data.cooldown = 86400.0  # 24小时
task_data.max_completions = 0  # 无限制

# 添加目标
var objective = CountObjective.new()
objective.target_type = "kill_enemy"
objective.target_id = "monster"
objective.required_count = 5
task_data.objectives.append(objective)

TaskManager.instance.register_task(task_data)
```

## API 参考

### QuestEventBus

#### 静态方法

- `emit_enemy_killed(enemy_type: String, enemy_id: String, enemy_level: int)`: 触发敌人击杀事件
- `emit_item_collected(item_id: String, quantity: int)`: 触发物品收集事件
- `emit_location_reached(location_id: String, position: Vector2)`: 触发位置到达事件
- `emit_npc_talked(npc_id: String, dialogue_id: String)`: 触发NPC对话事件
- `emit_custom(event_type: String, event_data: Dictionary)`: 触发自定义事件

#### 信号

- `enemy_killed(enemy_type, enemy_id, enemy_level)`
- `item_collected(item_id, quantity)`
- `location_reached(location_id, position)`
- `npc_talked(npc_id, dialogue_id)`
- `custom_event(event_type, event_data)`

### TaskManager

#### 方法

- `register_task(task_data: TaskData) -> bool`: 注册任务数据
- `can_accept_task(task_id: String) -> bool`: 检查任务是否可接取
- `accept_task(task_id: String) -> bool`: 接取任务
- `complete_task(task_id: String) -> bool`: 完成任务
- `claim_rewards(task_id: String, optional_reward_index: int) -> bool`: 领取奖励
- `fail_task(task_id: String, reason: String) -> bool`: 失败任务
- `abandon_task(task_id: String) -> bool`: 放弃任务
- `is_task_completed(task_id: String) -> bool`: 检查任务是否已完成
- `get_task_instance(task_id: String) -> TaskInstance`: 获取任务实例
- `get_active_tasks() -> Array[TaskInstance]`: 获取所有活跃任务
- `get_available_tasks() -> Array[TaskData]`: 获取所有可接取任务
- `save_data() -> Dictionary`: 保存任务数据
- `load_data(data: Dictionary)`: 加载任务数据

#### 信号

- `task_registered(task_id)`
- `task_accepted(task_id)`
- `task_updated(task_id, progress)`
- `task_completed(task_id)`
- `task_failed(task_id, reason)`
- `task_claimed(task_id)`
- `task_abandoned(task_id)`

### TaskInstance

#### 属性

- `task_data: TaskData`: 任务数据引用
- `state: TaskState.State`: 当前状态
- `objectives: Array[TaskObjective]`: 目标实例列表
- `start_time: float`: 任务开始时间
- `completion_time: float`: 任务完成时间
- `completion_count: int`: 完成次数

#### 方法

- `update_objective_progress(event_data: Dictionary)`: 更新目标进度
- `check_all_required_objectives_completed() -> bool`: 检查所有必需目标是否完成
- `get_overall_progress() -> float`: 获取总体进度 (0.0-1.0)
- `get_remaining_time() -> float`: 获取剩余时间
- `is_expired() -> bool`: 检查是否超时
- `is_cooldown_finished() -> bool`: 检查冷却是否结束
- `to_dict() -> Dictionary`: 序列化为字典
- `from_dict(data: Dictionary)`: 从字典反序列化

#### 信号

- `state_changed(old_state, new_state)`
- `objective_completed(objective)`
- `progress_updated(progress)`

### TaskData

#### 属性

- `task_id: String`: 任务唯一ID
- `task_name: String`: 任务名称
- `description: String`: 任务描述
- `category: String`: 任务类别
- `objectives: Array[TaskObjective]`: 任务目标列表
- `accept_conditions: Array[TaskCondition]`: 接取条件
- `complete_conditions: Array[TaskCondition]`: 完成条件
- `fail_conditions: Array[TaskCondition]`: 失败条件
- `rewards: Array[TaskReward]`: 奖励列表
- `optional_rewards: Array[TaskReward]`: 可选奖励
- `time_limit: float`: 时间限制(秒)
- `cooldown: float`: 冷却时间(秒)
- `repeatable: bool`: 是否可重复
- `max_completions: int`: 最大完成次数
- `prerequisite_tasks: Array[String]`: 前置任务ID列表
- `exclusive_tasks: Array[String]`: 互斥任务ID列表
- `tags: Array[String]`: 任务标签

#### 方法

- `validate() -> bool`: 验证任务数据完整性
- `get_required_objectives() -> Array[TaskObjective]`: 获取所有必需目标
- `get_optional_objectives() -> Array[TaskObjective]`: 获取所有可选目标

## 扩展系统

### 自定义目标类型

要创建自定义目标类型，需要继承 `TaskObjective` 类：

```gdscript
class_name CustomObjective
extends TaskObjective

func update_progress(event_data: Dictionary) -> void:
    # 实现进度更新逻辑
    if event_data.get("type") == "custom_event":
        current_count += event_data.get("count", 0)
        _check_completion()

func _check_completion() -> void:
    if current_count >= required_count:
        is_completed = true
        objective_completed.emit(self)
```

### 自定义条件类型

要创建自定义条件类型，需要继承 `TaskCondition` 类：

```gdscript
class_name CustomCondition
extends TaskCondition

func check(context: Dictionary) -> bool:
    # 实现条件检查逻辑
    var player = context.get("player")
    if player and player.has_method("has_item"):
        return player.has_item(required_item_id)
    return false
```

### 自定义奖励类型

要创建自定义奖励类型，需要继承 `TaskReward` 类：

```gdscript
class_name CustomReward
extends TaskReward

func grant(context: Dictionary) -> bool:
    # 实现奖励发放逻辑
    var player = context.get("player")
    if player and player.has_method("add_buff"):
        player.add_buff(buff_id, duration)
        return true
    return false
```

## 最佳实践

### 1. 任务设计

- **任务ID命名**: 使用清晰的命名规范，如 `quest_kill_goblins_001`
- **目标权重**: 为不同重要性的目标设置合适的权重
- **条件组合**: 合理组合多个条件，避免过于严格的限制
- **奖励平衡**: 根据任务难度设置合适的奖励

### 2. 事件管理

- **事件命名**: 使用一致的事件类型命名，如 `kill_enemy`, `collect_item`
- **事件数据**: 在事件数据中包含足够的信息用于目标匹配
- **性能考虑**: 避免在事件处理中进行耗时操作

### 3. 状态管理

- **状态转换**: 遵循正确的状态转换流程
- **持久化**: 定期保存任务进度，避免数据丢失
- **清理**: 及时清理已完成的任务实例

### 4. 扩展性

- **模块化**: 将不同类型的目标、条件、奖励分离到独立文件
- **继承**: 利用继承机制复用通用逻辑
- **配置化**: 将任务数据存储在资源文件中，便于编辑

### 5. 调试和测试

- **日志记录**: 在关键节点添加日志，便于调试
- **单元测试**: 为核心逻辑编写单元测试
- **边界情况**: 测试各种边界情况，如超时、失败等

## 常见问题

### Q: 任务进度不更新怎么办？

A: 检查以下几点：
1. 确保 QuestEventBus 已添加到场景中
2. 确认事件类型和数据格式正确
3. 检查目标的 `update_progress` 方法实现
4. 验证任务状态是否为 ACTIVE

### Q: 条件检查失败怎么办？

A: 检查以下几点：
1. 确保 TaskContext 包含所需的数据
2. 验证条件类的 `check` 方法实现
3. 检查条件的配置是否正确
4. 确认玩家对象的接口实现

### Q: 奖励发放失败怎么办？

A: 检查以下几点：
1. 确保奖励类的 `grant` 方法实现正确
2. 验证 TaskContext 包含玩家引用
3. 检查玩家对象的奖励接口实现
4. 确认奖励数据配置正确

### Q: 内存泄漏怎么办？

A: 注意以下几点：
1. 及时断开不再需要的信号连接
2. 清理已完成的任务实例
3. 避免在 Resource 对象中存储 Node 引用
4. 使用弱引用或 ID 而非直接对象引用