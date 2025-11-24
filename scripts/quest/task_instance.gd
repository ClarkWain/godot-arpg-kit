## 任务实例
## 运行时任务实例,存储玩家的任务进度
class_name TaskInstance
extends RefCounted

## 任务数据引用
var task_data: TaskData

## 当前状态
var state: TaskState.State = TaskState.State.LOCKED

## 目标实例列表
var objectives: Array[TaskObjective] = []

## 任务开始时间
var start_time: float = 0.0

## 任务完成时间
var completion_time: float = 0.0

## 完成次数
var completion_count: int = 0

## 上次完成时间(用于冷却计算)
var last_completion_time: float = 0.0

## 自定义进度数据
var progress_data: Dictionary = {}

## 元数据
var metadata: Dictionary = {}

## 信号
signal state_changed(old_state: TaskState.State, new_state: TaskState.State)
signal objective_completed(objective: TaskObjective)
signal progress_updated(progress: float)

## 构造函数
func _init(data: TaskData) -> void:
	task_data = data
	_initialize_objectives()

## 初始化目标
func _initialize_objectives() -> void:
	# 先断开旧的信号连接
	for obj in objectives:
		if obj.objective_completed.is_connected(_on_objective_completed):
			obj.objective_completed.disconnect(_on_objective_completed)
		if obj.objective_progress_changed.is_connected(_on_objective_progress_changed):
			obj.objective_progress_changed.disconnect(_on_objective_progress_changed)
	
	objectives.clear()
	
	# 创建新的目标实例
	for obj_data in task_data.objectives:
		# 使用多态方法创建实例
		var obj = obj_data.instantiate()
		
		# 连接信号
		obj.objective_completed.connect(_on_objective_completed)
		obj.objective_progress_changed.connect(_on_objective_progress_changed)
		objectives.append(obj)

## 设置状态
func set_state(new_state: TaskState.State) -> void:
	if state == new_state:
		return
	
	# 验证状态转换
	if not TaskState.can_transition(state, new_state):
		push_warning("Invalid state transition: %s -> %s" % [
			TaskState.get_state_name(state),
			TaskState.get_state_name(new_state)
		])
		return
	
	var old_state = state
	state = new_state
	# 使用 emit_signal 保证兼容性
	state_changed.emit(old_state, new_state)
	
	# 状态转换时的特殊处理
	match new_state:
		TaskState.State.ACTIVE:
			start_time = Time.get_unix_time_from_system()
		TaskState.State.COMPLETED:
			completion_time = Time.get_unix_time_from_system()
		TaskState.State.CLAIMED:
			completion_count += 1
			last_completion_time = Time.get_unix_time_from_system()

## 更新目标进度
func update_objective_progress(event_data) -> void:
	if state != TaskState.State.ACTIVE:
		return
	
	for obj in objectives:
		if not obj.is_completed:
			obj.update_progress(event_data)

## 检查所有必需目标是否完成
func check_all_required_objectives_completed() -> bool:
	for obj in objectives:
		if not obj.optional and not obj.is_completed:
			return false
	return true

## 获取总体进度(0.0-1.0)
func get_overall_progress() -> float:
	if objectives.is_empty():
		return 0.0
	
	var total_weight: float = 0.0
	var completed_weight: float = 0.0
	
	for obj in objectives:
		if not obj.optional:
			total_weight += obj.weight
			completed_weight += obj.progress * obj.weight
	
	if total_weight == 0.0:
		return 0.0
	
	return completed_weight / total_weight

## 获取剩余时间(秒)
## 返回-1表示无限制，否则返回剩余时间
func get_remaining_time() -> float:
	if task_data.time_limit <= 0.0:
		return -1.0  # 无限制
	
	if state != TaskState.State.ACTIVE:
		return task_data.time_limit
	
	var elapsed = Time.get_unix_time_from_system() - start_time
	return maxf(0.0, task_data.time_limit - elapsed)

## 检查是否超时
func is_expired() -> bool:
	if task_data.time_limit <= 0.0:
		return false
	
	return get_remaining_time() <= 0.0

## 获取该任务关心的所有事件类型
func get_interested_events() -> Array[String]:
	var events: Array[String] = []
	for obj in objectives:
		if obj.is_completed: continue # 已完成的目标不再关心事件
		
		var obj_events = obj.get_interested_events()
		for evt in obj_events:
			if not evt in events:
				events.append(evt)
	return events

## 检查冷却是否结束
func is_cooldown_finished() -> bool:
	if task_data.cooldown <= 0.0:
		return true
	
	if last_completion_time == 0.0:
		return true
	
	var elapsed = Time.get_unix_time_from_system() - last_completion_time
	return elapsed >= task_data.cooldown

## 序列化为字典
func to_dict() -> Dictionary:
	var objectives_data: Array = []
	for obj in objectives:
		objectives_data.append(obj.to_dict())
	
	return {
		"task_id": task_data.task_id,
		"state": state,
		"objectives": objectives_data,
		"start_time": start_time,
		"completion_time": completion_time,
		"completion_count": completion_count,
		"last_completion_time": last_completion_time,
		"progress_data": progress_data,
		"metadata": metadata
	}

## 从字典反序列化
func from_dict(data: Dictionary) -> void:
	state = data.get("state", TaskState.State.LOCKED)
	start_time = data.get("start_time", 0.0)
	completion_time = data.get("completion_time", 0.0)
	completion_count = data.get("completion_count", 0)
	last_completion_time = data.get("last_completion_time", 0.0)
	progress_data = data.get("progress_data", {})
	metadata = data.get("metadata", {})
	
	# 恢复目标进度
	var objectives_data = data.get("objectives", [])
	
	# 建立 ID 到目标的映射
	var obj_map = {}
	for obj in objectives:
		if not obj.objective_id.is_empty():
			obj_map[obj.objective_id] = obj
	
	# 根据 ID 恢复数据
	for obj_data in objectives_data:
		var obj_id = obj_data.get("objective_id", "")
		if obj_id.is_empty():
			continue
			
		if obj_map.has(obj_id):
			obj_map[obj_id].from_dict(obj_data)
		else:
			# 尝试按顺序回退（兼容旧数据或无ID目标）
			# 这里简单处理：如果找不到ID，就不恢复，避免错误匹配
			pass

## 目标完成回调
func _on_objective_completed(objective: TaskObjective) -> void:
	# 转发目标完成信号
	objective_completed.emit(objective)
	
	# 检查是否所有必需目标都完成
	if check_all_required_objectives_completed():
		set_state(TaskState.State.COMPLETED)

## 目标进度变化回调
func _on_objective_progress_changed(objective: TaskObjective, progress: float) -> void:
	# 转发总体进度更新
	progress_updated.emit(get_overall_progress())