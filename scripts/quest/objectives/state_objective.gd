## 状态型目标
## 用于检查某个状态是否达成(如到达地点、装备物品、等级达到等)
class_name StateObjective
extends TaskObjective

## 状态类型(如 "location", "equipment", "level")
@export var state_type: StringName = &""

## 目标状态值
@export var target_state: StringName = &""

## 当前状态值
var current_state: StringName = &""

## 创建运行时实例
func instantiate() -> TaskObjective:
	var instance = StateObjective.new()
	instance.objective_id = objective_id
	instance.description = description
	instance.optional = optional
	instance.weight = weight
	instance.state_type = state_type
	instance.target_state = target_state
	instance.initialize()
	return instance

## 获取关心的事件类型
func get_interested_events() -> Array[String]:
	if state_type == &"":
		return []
	return [String(state_type)]

## 初始化
func initialize() -> void:
	super.initialize()
	current_state = &""

## 更新进度
## 支持强类型事件数据(QuestEventData)或Dictionary
func update_progress(event_data) -> void:
	var event: QuestEventData
	
	if event_data is QuestEventData:
		event = event_data
	elif event_data is Dictionary:
		event = QuestEventData.from_dict(event_data)
	else:
		push_warning("StateObjective: Invalid event_data type")
		return
	
	# 检查事件类型是否匹配
	if event.type != state_type:
		return
	
	# 更新当前状态
	current_state = event.state
	
	# 检查是否达成目标状态
	if check_completion():
		set_completed(true)

## 检查完成
func check_completion() -> bool:
	return current_state == target_state

## 获取进度文本
func get_progress_text() -> String:
	if is_completed:
		return "已完成"
	else:
		return "未完成"

## 序列化
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["current_state"] = current_state
	return data

## 反序列化
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	current_state = StringName(data.get("current_state", ""))