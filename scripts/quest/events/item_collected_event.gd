## 物品收集事件数据
class_name ItemCollectedEvent
extends QuestEventData

## 物品ID
var item_id: String = ""

## 收集数量
var quantity: int = 1

func _init(id: String = "", qty: int = 1) -> void:
	event_type = "collect_item"
	item_id = id
	quantity = qty

func to_dict() -> Dictionary:
	return {
		"type": event_type,
		"target_id": item_id,
		"count": quantity
	}