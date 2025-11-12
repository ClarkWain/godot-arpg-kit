## 任务目标基类
## 所有任务目标的抽象基类
class_name TaskObjective
extends Resource

## 目标唯一ID
@export var objective_id: String = ""

## 目标描述
@export var description: String = ""

## 是否可选目标
@export var optional: bool = false

## 目标权重(用于计算总进度)
@export var weight: float = 1.0

## 是否已完成
var is_completed: bool = false

## 当前进度(0.0-1.0)
var progress: float = 0.0

## 自定义数据
var custom_data: Dictionary = {}

## 完成信号
signal objective_completed(objective: TaskObjective)
signal objective_progress_changed(objective: TaskObjective, progress: float)

## 初始化目标
func initialize() -> void:
	is_completed = false
	progress = 0.0
	custom_data.clear()

## 更新目标进度(由子类实现)
## 支持强类型事件数据或Dictionary(向后兼容)
func update_progress(event_data) -> void:
	push_error("TaskObjective.update_progress() must be overridden")

## 检查是否完成(由子类实现)
func check_completion() -> bool:
	push_error("TaskObjective.check_completion() must be overridden")
	return false

## 设置完成状态
func set_completed(completed: bool) -> void:
	if is_completed != completed:
		is_completed = completed
		if completed:
			progress = 1.0
			objective_completed.emit(self)
		else:
			progress = 0.0

## 设置进度
func set_progress(value: float) -> void:
	var old_progress = progress
	progress = clampf(value, 0.0, 1.0)
	
	if not is_equal_approx(old_progress, progress):
		objective_progress_changed.emit(self, progress)
	
	# 检查是否完成
	if progress >= 1.0 and not is_completed:
		set_completed(true)

## 获取进度描述
func get_progress_text() -> String:
	return "%.0f%%" % (progress * 100.0)

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"objective_id": objective_id,
		"is_completed": is_completed,
		"progress": progress,
		"custom_data": custom_data
	}

## 从字典反序列化
func from_dict(data: Dictionary) -> void:
	is_completed = data.get("is_completed", false)
	progress = data.get("progress", 0.0)
	custom_data = data.get("custom_data", {})