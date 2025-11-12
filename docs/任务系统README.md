# Godot 通用任务系统

一个为 Godot 4.x 设计的**高度抽象、可复用、灵活的任务系统**,适用于 RPG、ARPG、冒险游戏等多种类型的项目。

## ✨ 核心特性

- 🎯 **高度抽象** - 核心逻辑与具体游戏完全解耦
- 🔧 **高度灵活** - 组件化设计,易于扩展和定制
- ♻️ **可复用性** - 可直接应用于多个不同项目
- 📊 **数据驱动** - 通过配置文件定义任务,无需硬编码
- 📡 **事件驱动** - 松耦合的事件系统,易于集成
- 💾 **完整功能** - 支持保存/加载、任务链、条件系统等

## 📦 系统组成

### 核心模块

```
scripts/quest/
├── task_state.gd              # 任务状态枚举
├── task_data.gd               # 任务数据资源
├── task_instance.gd           # 任务运行时实例
├── task_manager.gd            # 任务管理器(单例)
├── quest_event_bus.gd         # 事件总线(单例)
├── objectives/                # 目标系统
│   ├── task_objective.gd      # 目标基类
│   ├── count_objective.gd     # 计数型目标
│   └── state_objective.gd     # 状态型目标
├── conditions/                # 条件系统
│   ├── task_condition.gd      # 条件基类
│   └── level_condition.gd     # 等级条件
├── rewards/                   # 奖励系统
│   ├── task_reward.gd         # 奖励基类
│   ├── experience_reward.gd   # 经验奖励
│   └── item_reward.gd         # 物品奖励
└── examples/                  # 示例代码
    ├── example_tasks.gd       # 示例任务配置
    ├── quest_example_scene.gd # 示例场景脚本
    └── mock_player.gd         # 模拟玩家
```

## 🚀 快速开始

### 1. 安装

将 `scripts/quest/` 目录复制到你的项目中。

### 2. 配置自动加载

在 **项目设置 → 自动加载** 中添加:

| 名称 | 路径 |
|------|------|
| TaskManager | res://scripts/quest/task_manager.gd |
| QuestEventBus | res://scripts/quest/quest_event_bus.gd |

### 3. 创建第一个任务

```gdscript
# 创建任务
var task = TaskData.new()
task.task_id = "kill_slimes"
task.task_name = "清理史莱姆"
task.description = "击杀10只史莱姆"

# 添加目标
var objective = CountObjective.new()
objective.target_type = "kill_enemy"
objective.target_id = "slime"
objective.required_count = 10
task.objectives.append(objective)

# 添加奖励
var reward = ExperienceReward.new()
reward.experience = 100
task.rewards.append(reward)

# 注册任务
TaskManager.register_task(task)
TaskManager.set_player($Player)
```

### 4. 使用任务

```gdscript
# 接取任务
TaskManager.accept_task("kill_slimes")

# 触发游戏事件(自动更新任务进度)
QuestEventBus.emit_enemy_killed("slime", "slime_001", 1)

# 领取奖励
TaskManager.claim_rewards("kill_slimes")
```

## 📖 支持的功能

### 任务类型
- ✅ 主线任务
- ✅ 支线任务
- ✅ 日常/周常任务
- ✅ 成就系统
- ✅ 任务链(顺序/分支)
- ✅ 可重复任务

### 目标类型
- ✅ 计数型目标(击杀、收集、交互等)
- ✅ 状态型目标(到达、装备、等级等)
- ✅ 复合目标(多个目标组合)
- ✅ 可选目标

### 条件系统
- ✅ 等级条件
- ✅ 前置任务条件
- ✅ 互斥任务条件
- ✅ 自定义条件(可扩展)

### 奖励系统
- ✅ 经验奖励
- ✅ 物品奖励
- ✅ 可选奖励(玩家选择)
- ✅ 自定义奖励(可扩展)

### 高级功能
- ✅ 时间限制
- ✅ 冷却系统
- ✅ 任务优先级
- ✅ 任务标签
- ✅ 保存/加载
- ✅ 事件驱动更新

## 📚 文档

详细文档请查看:
- [完整使用文档](./任务系统使用文档.md)
- [示例场景](../scene/quest_system_example.tscn)
- [示例代码](../scripts/quest/examples/)

## 🎮 示例项目

运行 `scene/quest_system_example.tscn` 查看完整的交互式示例。

示例包含:
- 任务接取流程
- 进度更新机制
- 奖励发放系统
- UI集成示例

## 🔧 扩展开发

系统设计为高度可扩展,你可以轻松添加:

### 自定义目标类型

```gdscript
class_name MyObjective extends TaskObjective

func update_progress(event_data: Dictionary) -> void:
    # 实现自定义逻辑
    pass
```

### 自定义条件类型

```gdscript
class_name MyCondition extends TaskCondition

func check(context: Dictionary) -> bool:
    # 实现自定义检查
    return true
```

### 自定义奖励类型

```gdscript
class_name MyReward extends TaskReward

func grant(context: Dictionary) -> bool:
    # 实现自定义奖励发放
    return true
```

## 🎯 使用场景

### RPG游戏
- 主线剧情任务
- 支线探索任务
- NPC委托任务

### ARPG游戏
- 赏金任务
- 挑战任务
- 成就系统

### 冒险游戏
- 解谜任务
- 收集任务
- 探索任务

### 其他类型
- 教学任务
- 每日活动
- 限时活动

## 💡 设计理念

### 1. 高度抽象
核心系统不依赖任何具体的游戏逻辑,通过事件和接口与游戏交互。

### 2. 数据驱动
所有任务配置都通过数据定义,支持可视化编辑和热更新。

### 3. 事件驱动
使用事件总线模式,任务系统被动响应游戏事件,不主动查询游戏状态。

### 4. 组件化设计
目标、条件、奖励都是独立的组件,可以自由组合和扩展。

## 🔄 工作流程

```
1. 定义任务数据 (TaskData)
   ↓
2. 注册到管理器 (TaskManager)
   ↓
3. 玩家接取任务
   ↓
4. 游戏触发事件 (QuestEventBus)
   ↓
5. 任务自动更新进度
   ↓
6. 完成后领取奖励
```

## 📊 性能考虑

- ✅ 使用对象池复用实例
- ✅ 事件批量处理
- ✅ 索引优化查询
- ✅ 增量保存
- ✅ 异步加载

## 🤝 贡献

欢迎提交 Issue 和 Pull Request!

## 📄 许可证

MIT License

## 🙏 致谢

感谢 Godot 社区的支持和贡献。

---

**版本:** 1.0.0  
**兼容性:** Godot 4.x  
**最后更新:** 2025-01-12