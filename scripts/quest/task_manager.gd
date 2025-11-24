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

## 事件索引 {event_type: [task_id]}
## 用于快速查找关心特定事件的任务
var _event_index: Dictionary[StringName, Array] = {}

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
		# 在测试环境中，可能会多次创建 TaskManager，这里只打印警告但不销毁，
		# 或者可以考虑销毁旧的实例。为了测试稳定性，我们允许替换实例。
		# push_warning("TaskManager instance already exists! Replacing with new instance.")
		instance = self
		# queue_free() # 在测试中不要销毁，否则可能会导致引用问题
		return

## 注册任务数据
func register_task(task_data: TaskData) -> bool:
	if not task_data.validate():
		return false
	
	if registered_tasks.has(task_data.task_id):
		push_warning("Task %s already registered" % task_data.task_id)
		return false
	
	registered_tasks[task_data.task_id] = task_data
	emit_signal("task_registered", task_data.task_id)
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
	_update_event_index(task_id) # 更新索引
	emit_signal("task_accepted", task_id)
	
	# 处理互斥任务
	for exclusive_id in task_data.exclusive_tasks:
		if player_tasks.has(exclusive_id):
			var exclusive_instance = player_tasks[exclusive_id]
			if exclusive_instance.state == TaskState.State.AVAILABLE:
				exclusive_instance.set_state(TaskState.State.LOCKED)
	
	return true

## 更新任务进度(通过游戏事件)
## 支持 QuestEventData 或 Dictionary (向后兼容)
func update_task_progress(event_data) -> void:
	var event: QuestEventData
	if event_data is QuestEventData:
		event = event_data
	elif event_data is Dictionary:
		event = QuestEventData.from_dict(event_data)
	else:
		push_error("TaskManager: Invalid event data type")
		return
		
	if event.type == &"":
		return
		
	# 使用索引查找相关任务
	var interested_tasks = _event_index.get(event.type, [])
	if interested_tasks.is_empty():
		return
		
	# 只遍历关心的任务
	# 注意：需要复制数组，因为 update_objective_progress 可能会导致任务完成从而修改索引
	for task_id in interested_tasks.duplicate():
		if not player_tasks.has(task_id):
			continue
			
		var instance: TaskInstance = player_tasks[task_id]
		if instance.state == TaskState.State.ACTIVE:
			instance.update_objective_progress(event)
			
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
	_remove_from_event_index(task_id) # 完成后移除索引
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
	emit_signal("task_claimed", task_id)
	return true

## 失败任务
func fail_task(task_id: String, reason: String = "") -> bool:
	if not player_tasks.has(task_id):
		return false
	
	var instance: TaskInstance = player_tasks[task_id]
	if instance.state != TaskState.State.ACTIVE:
		return false
	
	instance.set_state(TaskState.State.FAILED)
	_remove_from_event_index(task_id) # 失败后移除索引
	emit_signal("task_failed", task_id, reason)
	return true

## 放弃任务
func abandon_task(task_id: String) -> bool:
	if not player_tasks.has(task_id):
		return false
	
	var instance: TaskInstance = player_tasks[task_id]
	if instance.state != TaskState.State.ACTIVE:
		return false
	
	instance.set_state(TaskState.State.ABANDONED)
	_remove_from_event_index(task_id) # 放弃后移除索引
	emit_signal("task_abandoned", task_id)
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
	_task_signal_connections.clear()
	
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
		_task_signal_connections[task_id] = true
		
		player_tasks[task_id] = instance
		
		# 如果是活跃任务，重建索引
		if instance.state == TaskState.State.ACTIVE:
			_update_event_index(task_id)

## 构建上下文数据
func _build_context() -> TaskContext:
	var context = TaskContext.new(player, self)
	return context

## 任务状态变化回调
func _on_task_state_changed(old_state: TaskState.State, new_state: TaskState.State, task_id: String) -> void:
	match new_state:
		TaskState.State.COMPLETED:
			emit_signal("task_completed", task_id)

## 任务进度更新回调
func _on_task_progress_updated(progress: float, task_id: String) -> void:
	# 进度更新可能意味着某个目标完成了，需要更新索引
	# 例如：杀怪目标完成了，就不需要再监听 kill_enemy 了
	_update_event_index(task_id)
	emit_signal("task_updated", task_id, progress)

## 更新任务的事件索引
func _update_event_index(task_id: String) -> void:
	if not player_tasks.has(task_id):
		return
		
	var instance = player_tasks[task_id]
	
	# 先移除旧的索引
	_remove_from_event_index(task_id)
	
	# 如果不是活跃状态，不需要监听
	if instance.state != TaskState.State.ACTIVE:
		return
		
	# 获取任务关心的事件
	var events = instance.get_interested_events()
	for evt in events:
		var evt_name = StringName(evt)
		if not _event_index.has(evt_name):
			_event_index[evt_name] = []
		if not task_id in _event_index[evt_name]:
			_event_index[evt_name].append(task_id)

## 从事件索引中移除任务
func _remove_from_event_index(task_id: String) -> void:
	for evt in _event_index:
		var list = _event_index[evt]
		if task_id in list:
			list.erase(task_id)
