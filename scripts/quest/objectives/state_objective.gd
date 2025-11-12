## 状态型目标
## 用于检查某个状态是否达成(如到达地点、装备物品、等级达到等)
class_name StateObjective
extends TaskObjective

## 状态类型(如 "location", "equipment", "level")
@export var state_type: String = ""

## 目标状态值
@export var target_state: String = ""

## 当前状态值
var current_state: String = ""

## 初始化
func initialize() -> void:
	super.initialize()
	current_state = ""

## 更新进度
## 支持强类型事件数据(QuestEventData)或Dictionary
func update_progress(event_data) -> void:
	var data_dict: Dictionary
	
	# 转换为Dictionary
	if event_data is QuestEventData:
		data_dict = event_data.to_dict()
	elif event_data is Dictionary:
		data_dict = event_data
	else:
		push_warning("StateObjective: Invalid event_data type")
		return
	
	# 检查事件类型是否匹配
	var event_type = data_dict.get("type", "")
	if event_type != state_type:
		return
	
	# 更新当前状态
	current_state = data_dict.get("state", "")
	
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
	current_state = data.get("current_state", "")