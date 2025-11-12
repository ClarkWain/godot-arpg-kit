## 任务条件基类
## 所有任务条件的抽象基类
class_name TaskCondition
extends Resource

## 条件描述
@export var description: String = ""

## 是否取反
@export var negate: bool = false

## 检查条件是否满足（由子类实现）
func check(context: Dictionary) -> bool:
	push_error("TaskCondition.check() must be overridden")
	return false

## 获取描述文本
func get_description_text() -> String:
	return description
