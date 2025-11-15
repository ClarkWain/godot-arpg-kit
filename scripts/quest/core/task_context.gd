## 任务上下文数据
## 强类型的上下文数据,替代 Dictionary
## 用于条件检查和奖励发放
class_name TaskContext
extends RefCounted

## 玩家引用
var player: Node = null

## 任务管理器引用
var task_manager: TaskManager = null

## 玩家等级(缓存)
var player_level: int = 1

## 额外数据(用于扩展)
var extra_data: Dictionary = {}

func _init(p: Node = null, tm: TaskManager = null) -> void:
	player = p
	task_manager = tm
	
	# 缓存玩家等级
	if player and player.has_method("get_level"):
		player_level = player.get_level()

## 获取玩家背包
func get_inventory() -> Node:
	if not player:
		return null
	
	if player.has_node("InventoryManager"):
		return player.get_node("InventoryManager")
	elif player.has_method("get_inventory"):
		return player.get_inventory()
	
	return null

## 转换为字典(向后兼容)
func to_dict() -> Dictionary:
	return {
		"player": player,
		"task_manager": task_manager,
		"player_level": player_level
	}
