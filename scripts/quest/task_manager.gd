## 任务管理器
## 全局单例,管理所有任务的注册、状态和进度
class_name TaskManager
extends Node

## 单例实例
static var instance: TaskManager = null

## 所有已注册的任务数据 {task_id: TaskData}
var registered_tasks: Dictionary[String, TaskData] = {}

## 玩家的任务实例 {task_id: TaskInstance}
var player_tasks: Dictionary[String, TaskInstance] = {}

## 玩家引用(用于条件检查和奖励发放)
var player: Node = null

## 任务信号连接追踪 {task_id: bool}
var _task_signal_connections: Dictionary[String, bool] = {}

## 信号
signal task_registered(task_id: String)
signal task_accepted(task_id: String)
signal task_updated(task_id: String, progress: float)
signal task_completed(task_id: String)
signal task_failed(task_id: String, reason: String)
signal task_claimed(task_id: String)
signal task_abandoned(task_id: String)

func _ready() -> void:
	if instance == null:
		instance = self
	else:
		push_warning("TaskManager instance already exists!")
		queue_free()
		return

## 注册任务数据
func register_task(task_data: TaskData) -> bool:
	if not task_data.validate():
		return false
	
	if registered_tasks.has(task_data.task_id):
		push_warning("Task %s already registered" % task_data.task_id)
		return false
	
	registered_tasks[task_data.task_id] = task_data
	task_registered.emit(task_data.task_id)
	return true

## 批量注册任务
func register_tasks(tasks: Array[TaskData]) -> void:
	for task in tasks:
		register_task(task)

## 设置玩家引用
func set_player(p: Node) -> void:
	player = p

## 检查任务是否可接取
func can_accept_task(task_id: String) -> bool:
	if not registered_tasks.has(task_id):
		return false
	
	var task_data: TaskData = registered_tasks[task_id]
	
	# 检查是否已接取
	if player_tasks.has(task_id):
		var instance = player_tasks[task_id]
		# 如果是可重复任务且已完成,检查冷却
		if task_data.repeatable and instance.state == TaskState.State.CLAIMED:
			if not instance.is_cooldown_finished():
				return false
			# 检查最大完成次数
			if task_data.max_completions > 0 and instance.completion_count >= task_data.max_completions:
				return false
		else:
			return false
	
	# 检查前置任务
	for prereq_id in task_data.prerequisite_tasks:
		if not is_task_completed(prereq_id):
			return false
	
	# 检查接取条件
	var context = _build_context()
	for condition in task_data.accept_conditions:
		if condition == null:
			push_warning("Null accept condition in task %s" % task_id)
			continue
		if not condition.check(context.to_dict()):
			return false
	
	return true

## 接取任务
func accept_task(task_id: String) -> bool:
	if not can_accept_task(task_id):
		return false
	
	var task_data: TaskData = registered_tasks[task_id]
	
	# 创建或重置任务实例
	var instance: TaskInstance
	if player_tasks.has(task_id):
		instance = player_tasks[task_id]
		instance._initialize_objectives()
	else:
		instance = TaskInstance.new(task_data)
		player_tasks[task_id] = instance
	
	# 连接信号（避免重复连接）
	if not _task_signal_connections.get(task_id, false):
		instance.state_changed.connect(_on_task_state_changed.bind(task_id))
		instance.progress_updated.connect(_on_task_progress_updated.bind(task_id))
		_task_signal_connections[task_id] = true
	
	# 先设置为可接取状态（如果是LOCKED）
	if instance.state == TaskState.State.LOCKED:
		instance.set_state(TaskState.State.AVAILABLE)
	
	# 设置为进行中
	instance.set_state(TaskState.State.ACTIVE)
	task_accepted.emit(task_id)
	
	# 处理互斥任务
	for exclusive_id in task_data.exclusive_tasks:
		if player_tasks.has(exclusive_id):
			var exclusive_instance = player_tasks[exclusive_id]
			if exclusive_instance.state == TaskState.State.AVAILABLE:
				exclusive_instance.set_state(TaskState.State.LOCKED)
	
	return true

## 更新任务进度(通过游戏事件)
func update_task_progress(event_data: Dictionary) -> void:
	for task_id in player_tasks:
		var instance: TaskInstance = player_tasks[task_id]
		if instance.state == TaskState.State.ACTIVE:
			instance.update_objective_progress(event_data)
			
			# 检查超时
			if instance.is_expired():
				fail_task(task_id, "任务超时")

## 完成任务(手动触发,通常由目标自动完成)
func complete_task(task_id: String) -> bool:
	if not player_tasks.has(task_id):
		return false
	
	var instance: TaskInstance = player_tasks[task_id]
	if instance.state != TaskState.State.ACTIVE:
		return false
	
	# 检查完成条件
	var task_data: TaskData = registered_tasks[task_id]
	var context = _build_context()
	for condition in task_data.complete_conditions:
		if condition == null:
			push_warning("Null complete condition in task %s" % task_id)
			continue
		if not condition.check(context.to_dict()):
			return false
	
	instance.set_state(TaskState.State.COMPLETED)
	return true

## 领取奖励
func claim_rewards(task_id: String, optional_reward_index: int = -1) -> bool:
	if not player_tasks.has(task_id):
		return false
	
	var instance: TaskInstance = player_tasks[task_id]
	if instance.state != TaskState.State.COMPLETED:
		return false
	
	var task_data: TaskData = registered_tasks[task_id]
	var context = _build_context()
	
	# 发放基础奖励
	for reward in task_data.rewards:
		if reward == null:
			push_warning("Null reward in task %s" % task_id)
			continue
		if not reward.grant(context.to_dict()):
			push_warning("Failed to grant reward: %s" % reward.reward_id)
	
	# 发放可选奖励
	if optional_reward_index >= 0 and optional_reward_index < task_data.optional_rewards.size():
		var optional_reward = task_data.optional_rewards[optional_reward_index]
		if optional_reward == null:
			push_warning("Null optional reward at index %d in task %s" % [optional_reward_index, task_id])
		elif not optional_reward.grant(context.to_dict()):
			push_warning("Failed to grant optional reward: %s" % optional_reward.reward_id)
	
	instance.set_state(TaskState.State.CLAIMED)
	task_claimed.emit(task_id)
	return true

## 失败任务
func fail_task(task_id: String, reason: String = "") -> bool:
	if not player_tasks.has(task_id):
		return false
	
	var instance: TaskInstance = player_tasks[task_id]
	if instance.state != TaskState.State.ACTIVE:
		return false
	
	instance.set_state(TaskState.State.FAILED)
	task_failed.emit(task_id, reason)
	return true

## 放弃任务
func abandon_task(task_id: String) -> bool:
	if not player_tasks.has(task_id):
		return false
	
	var instance: TaskInstance = player_tasks[task_id]
	if instance.state != TaskState.State.ACTIVE:
		return false
	
	instance.set_state(TaskState.State.ABANDONED)
	task_abandoned.emit(task_id)
	return true

## 检查任务是否已完成
func is_task_completed(task_id: String) -> bool:
	if not player_tasks.has(task_id):
		return false
	
	var instance: TaskInstance = player_tasks[task_id]
	return instance.state in [TaskState.State.COMPLETED, TaskState.State.CLAIMED]

## 获取任务实例
func get_task_instance(task_id: String) -> TaskInstance:
	return player_tasks.get(task_id)

## 获取所有活跃任务
func get_active_tasks() -> Array[TaskInstance]:
	var active: Array[TaskInstance] = []
	for task_id in player_tasks:
		var instance: TaskInstance = player_tasks[task_id]
		if instance.state == TaskState.State.ACTIVE:
			active.append(instance)
	return active

## 获取所有可接取任务
func get_available_tasks() -> Array[TaskData]:
	var available: Array[TaskData] = []
	for task_id in registered_tasks:
		if can_accept_task(task_id):
			available.append(registered_tasks[task_id])
	return available

## 保存任务数据
func save_data() -> Dictionary:
	var tasks_data: Array = []
	for task_id in player_tasks:
		var instance: TaskInstance = player_tasks[task_id]
		tasks_data.append(instance.to_dict())
	
	return {
		"tasks": tasks_data
	}

## 加载任务数据
func load_data(data: Dictionary) -> void:
	player_tasks.clear()
	
	var tasks_data = data.get("tasks", [])
	for task_dict in tasks_data:
		var task_id = task_dict.get("task_id", "")
		if not registered_tasks.has(task_id):
			push_warning("Task %s not registered, skipping" % task_id)
			continue
		
		var task_data: TaskData = registered_tasks[task_id]
		var instance = TaskInstance.new(task_data)
		instance.from_dict(task_dict)
		
		# 重新连接信号
		instance.state_changed.connect(_on_task_state_changed.bind(task_id))
		instance.progress_updated.connect(_on_task_progress_updated.bind(task_id))
		
		player_tasks[task_id] = instance

## 构建上下文数据
func _build_context() -> TaskContext:
	var context = TaskContext.new(player, self)
	return context

## 任务状态变化回调
func _on_task_state_changed(old_state: TaskState.State, new_state: TaskState.State, task_id: String) -> void:
	match new_state:
		TaskState.State.COMPLETED:
			task_completed.emit(task_id)

## 任务进度更新回调
func _on_task_progress_updated(progress: float, task_id: String) -> void:
	task_updated.emit(task_id, progress)
