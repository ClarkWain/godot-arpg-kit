## 物品奖励
## 给予玩家物品
class_name ItemReward
extends TaskReward

## 物品ID
@export var item_id: String = ""

## 物品数量
@export var quantity: int = 1

## 发放奖励
func grant(context: Dictionary) -> bool:
	var player = context.get("player")
	if not player:
		push_error("ItemReward: No player in context")
		return false
	
	# 检查玩家是否有背包组件
	var inventory = null
	if player.has_node("InventoryComponent"):
		inventory = player.get_node("InventoryComponent")
	elif player.has_method("get_inventory"):
		inventory = player.get_inventory()
	
	if not inventory:
		push_error("ItemReward: Player has no inventory")
		return false
	
	# 添加物品到背包
	if inventory.has_method("add_item"):
		return inventory.add_item(item_id, quantity)
	else:
		push_warning("ItemReward: Inventory has no add_item method")
		return false

## 获取预览文本
func get_preview_text() -> String:
	return "%s x%d" % [item_id, quantity]

## 序列化
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["item_id"] = item_id
	data["quantity"] = quantity
	return data

## 反序列化
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	item_id = data.get("item_id", "")
	quantity = data.get("quantity", 1)