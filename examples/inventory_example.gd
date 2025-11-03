# res://examples/inventory_example.gd
extends Node2D
## 背包系统使用示例
##
## 展示背包系统的各种功能

@onready var inventory: InventoryComponent = $InventoryComponent


func _ready():
	# 连接信号
	inventory.item_added.connect(_on_item_added)
	inventory.item_removed.connect(_on_item_removed)
	inventory.inventory_full.connect(_on_inventory_full)
	inventory.weight_exceeded.connect(_on_weight_exceeded)
	
	print("========== 背包系统示例 ==========\n")
	
	# 示例 1: 添加物品
	example_add_items()
	
	# 示例 2: 物品堆叠
	example_item_stacking()
	
	# 示例 3: 移动和交换
	example_move_items()
	
	# 示例 4: 整理背包
	example_organize()
	
	# 示例 5: 金币管理
	example_gold_management()


## 示例 1: 添加物品
func example_add_items():
	print("========== 示例 1: 添加物品 ==========")
	
	# 加载物品
	var sword = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	var potion = load("res://data/items/consumables/health_potion.tres") as ConsumableData
	
	if sword and potion:
		# 添加武器
		var sword_instance = ItemInstance.create(sword, 1)
		inventory.add_item(sword_instance)
		
		# 添加药水（堆叠）
		var potion_instance = ItemInstance.create(potion, 15)
		inventory.add_item(potion_instance)
		
		print("背包空格子: %d" % inventory.get_empty_slot_count())
		print("当前重量: %.1f / %.1f\n" % [inventory.get_current_weight(), inventory.max_weight])


## 示例 2: 物品堆叠
func example_item_stacking():
	print("========== 示例 2: 物品堆叠 ==========")
	
	var potion = load("res://data/items/consumables/health_potion.tres") as ConsumableData
	
	if potion:
		# 第一组药水
		var potion1 = ItemInstance.create(potion, 30)
		inventory.add_item(potion1)
		
		# 第二组药水（会自动堆叠）
		var potion2 = ItemInstance.create(potion, 40)
		inventory.add_item(potion2)
		
		print("药水总数: %d" % inventory.get_item_count(potion.id))
		print()


## 示例 3: 移动和交换
func example_move_items():
	print("========== 示例 3: 移动和交换 ==========")
	
	# 查找第一个非空格子
	var from_slot = -1
	for i in range(inventory.slot_count):
		if inventory.get_item(i):
			from_slot = i
			break
	
	if from_slot >= 0:
		var item = inventory.get_item(from_slot)
		print("移动物品: %s (格子 %d -> 格子 10)" % [item.item_data.item_name, from_slot])
		inventory.move_item(from_slot, 10)
		print()


## 示例 4: 整理背包
func example_organize():
	print("========== 示例 4: 整理背包 ==========")
	
	print("整理前空格子: %d" % inventory.get_empty_slot_count())
	inventory.organize()
	print("整理后空格子: %d" % inventory.get_empty_slot_count())
	
	# 按稀有度排序
	inventory.sort_by_rarity()
	print("已按稀有度排序\n")


## 示例 5: 金币管理
func example_gold_management():
	print("========== 示例 5: 金币管理 ==========")
	
	inventory.add_gold(1000)
	print("当前金币: %d" % inventory.get_gold())
	
	if inventory.remove_gold(500):
		print("消费 500 金币")
		print("剩余金币: %d\n" % inventory.get_gold())


## 信号回调
func _on_item_added(item, slot_index):
	print("[信号] 添加物品: %s (格子 %d)" % [item.item_data.item_name, slot_index])


func _on_item_removed(item, slot_index):
	print("[信号] 移除物品: %s (格子 %d)" % [item.item_data.item_name, slot_index])


func _on_inventory_full():
	print("[信号] 背包已满!")


func _on_weight_exceeded():
	print("[信号] 负重超限!")