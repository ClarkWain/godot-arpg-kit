## 模拟玩家脚本
## 用于测试任务系统
extends Node

var level: int = 5
var experience: int = 0
var inventory: Dictionary = {}

func _ready() -> void:
	print("[MockPlayer] 初始化 - 等级: %d" % level)

## 获取等级
func get_level() -> int:
	return level

## 添加经验
func add_experience(exp: int) -> void:
	experience += exp
	print("[MockPlayer] 获得经验: +%d (总计: %d)" % [exp, experience])
	
	# 简单的升级逻辑
	while experience >= level * 100:
		experience -= level * 100
		level += 1
		print("[MockPlayer] 升级! 当前等级: %d" % level)

## 获取背包(模拟)
func get_inventory() -> Node:
	return self

## 添加物品到背包
func add_item(item_id: String, quantity: int) -> bool:
	if not inventory.has(item_id):
		inventory[item_id] = 0
	inventory[item_id] += quantity
	print("[MockPlayer] 获得物品: %s x%d" % [item_id, quantity])
	return true

## 获取物品数量
func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

## 移除物品
func remove_item(item_id: String, quantity: int) -> bool:
	if not inventory.has(item_id):
		return false
	
	if inventory[item_id] < quantity:
		return false
	
	inventory[item_id] -= quantity
	print("[MockPlayer] 失去物品: %s x%d" % [item_id, quantity])
	return true