## 任务事件数据
## 强类型的事件数据类，用于任务系统的事件传递
class_name QuestEventData
extends RefCounted

## 事件类型
var type: String = ""

## 目标ID
var target_id: String = ""

## 计数值
var count: int = 1

## 状态值
var state: String = ""

## 自定义数据
var custom_data: Dictionary = {}

## 构造函数
func _init(event_type: String = "", tid: String = "", c: int = 1) -> void:
	type = event_type
	target_id = tid
	count = c

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"type": type,
		"target_id": target_id,
		"count": count,
		"state": state,
		"custom_data": custom_data
	}

## 从字典创建
static func from_dict(data: Dictionary) -> QuestEventData:
	var event = QuestEventData.new()
	event.type = data.get("type", "")
	event.target_id = data.get("target_id", "")
	event.count = data.get("count", 1)
	event.state = data.get("state", "")
	event.custom_data = data.get("custom_data", {})
	return event