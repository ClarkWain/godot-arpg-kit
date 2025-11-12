## 敌人击杀事件数据
## 强类型的事件数据,替代 Dictionary
class_name EnemyKilledEvent
extends QuestEventData

## 敌人类型
var enemy_type: String = ""

## 敌人ID
var enemy_id: String = ""

## 敌人等级
var enemy_level: int = 1

## 击杀数量
var count: int = 1

func _init(type: String = "", id: String = "", level: int = 1, kill_count: int = 1) -> void:
	event_type = "kill_enemy"
	enemy_type = type
	enemy_id = id
	enemy_level = level
	count = kill_count

## 转换为字典(向后兼容)
func to_dict() -> Dictionary:
	return {
		"type": event_type,
		"target_id": enemy_type,
		"enemy_id": enemy_id,
		"enemy_level": enemy_level,
		"count": count
	}