## 任务事件数据基类
## 使用强类型替代 Dictionary,提供更好的类型安全
class_name QuestEventData
extends RefCounted

## 事件类型
var event_type: String = ""

## 转换为字典(用于兼容旧接口)
func to_dict() -> Dictionary:
	return {
		"type": event_type
	}