## 计数型目标
## 用于追踪需要达到特定数量的目标(如击杀敌人、收集物品等)
class_name CountObjective
extends TaskObjective

## 目标类型(如 "kill_enemy", "collect_item", "interact")
@export var target_type: StringName = &""

## 目标标识(如敌人ID、物品ID等)
@export var target_id: StringName = &""

## 需要的数量
@export var required_count: int = 1

## 当前数量
var current_count: int = 0

## 创建运行时实例
func instantiate() -> TaskObjective:
	var instance = CountObjective.new()
	instance.objective_id = objective_id
	instance.description = description
	instance.optional = optional
	instance.weight = weight
	instance.target_type = target_type
	instance.target_id = target_id
	instance.required_count = required_count
	instance.initialize()
	return instance

## 获取关心的事件类型
func get_interested_events() -> Array[String]:
	if target_type == &"":
		return []
	return [String(target_type)]

## 初始化
func initialize() -> void:
	super.initialize()
	current_count = 0

## 更新进度
## 支持强类型事件数据(QuestEventData)或Dictionary
func update_progress(event_data) -> void:
	var event: QuestEventData
	
	if event_data is QuestEventData:
		event = event_data
	elif event_data is Dictionary:
		event = QuestEventData.from_dict(event_data)
	else:
		push_warning("CountObjective: Invalid event_data type")
		return
	
	# 检查事件类型是否匹配
	if event.type != target_type:
		return
	
	# 检查目标ID是否匹配(如果指定了)
	if target_id != &"":
		if event.target_id != target_id:
			return
	
	# 增加计数
	add_count(event.count)

## 增加计数
func add_count(amount: int) -> void:
	current_count = min(current_count + amount, required_count)
	set_progress(float(current_count) / float(required_count))

## 设置计数
func set_count(count: int) -> void:
	current_count = clampi(count, 0, required_count)
	set_progress(float(current_count) / float(required_count))

## 检查完成
func check_completion() -> bool:
	return current_count >= required_count

## 获取进度文本
func get_progress_text() -> String:
	return "%d/%d" % [current_count, required_count]

## 序列化
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["current_count"] = current_count
	return data

## 反序列化
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	current_count = data.get("current_count", 0)