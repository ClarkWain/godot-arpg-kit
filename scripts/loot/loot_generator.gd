class_name LootGenerator
extends Node
## 掉落生成器
##
## 全局单例服务，负责生成和管理掉落物
## 处理掉落物的生成、放置、特效等

## ========== 信号 ==========
## 掉落物生成
signal loot_spawned(dropped_items: Array)
## 掉落物被拾取
signal loot_picked_up(item: ItemInstance, picker: Node2D)

## ========== 配置 ==========
@export_group("Spawn Settings")
## 掉落物场景预制体
@export var dropped_item_scene: PackedScene
## 金币掉落物场景预制体（可选，不设置则使用通用场景）
@export var gold_drop_scene: PackedScene
## 掉落物生成的父节点路径
@export var spawn_parent_path: NodePath = "/root/Main/Drops"

@export_group("Spawn Behavior")
## 掉落物散开范围
@export var scatter_range: float = 50.0
## 是否使用圆形散开模式
@export var circular_scatter: bool = true
## 最小散开距离
@export var min_scatter_distance: float = 20.0

@export_group("Item Pooling")
## 是否启用对象池（减少实例化开销）
@export var use_pooling: bool = true
## 对象池大小
@export var pool_size: int = 50

## ========== 内部变量 ==========
var _spawn_parent: Node
var _item_pool: Array[DroppedItem] = []
var _pool_index: int = 0


func _ready():
	# 获取掉落物父节点
	if spawn_parent_path:
		_spawn_parent = get_node_or_null(spawn_parent_path)
	
	if not _spawn_parent:
		_spawn_parent = get_tree().current_scene
	
	# 初始化对象池
	if use_pooling:
		_initialize_pool()


## ========== 核心方法 ==========

## 从掉落表生成掉落物
func spawn_loot_from_table(
	loot_table: LootTable,
	spawn_position: Vector2,
	player_level: int = 1,
	luck_value: int = 0,
	context_tags: Array[String] = []
) -> Array[DroppedItem]:
	
	if not loot_table:
		push_warning("LootGenerator: 掉落表为空")
		return []
	
	# 生成掉落物数据
	var loot_data = loot_table.generate_loot(player_level, luck_value, context_tags)
	
	# 生成掉落物实体
	return spawn_loot(loot_data, spawn_position)


## 直接生成掉落物（传入物品数组和金币）
func spawn_loot(loot_data: Dictionary, spawn_position: Vector2) -> Array[DroppedItem]:
	var dropped_items: Array[DroppedItem] = []
	
	var items: Array = loot_data.get("items", [])
	var gold: int = loot_data.get("gold", 0)
	
	# 生成物品掉落物
	for item in items:
		if item is ItemInstance:
			var dropped = _create_dropped_item(item, spawn_position)
			if dropped:
				dropped_items.append(dropped)
	
	# 生成金币掉落物
	if gold > 0:
		var dropped = _create_gold_drop(gold, spawn_position)
		if dropped:
			dropped_items.append(dropped)
	
	# 应用散开效果
	if dropped_items.size() > 1:
		_apply_scatter(dropped_items, spawn_position)
	
	# 发出信号
	if not dropped_items.is_empty():
		loot_spawned.emit(dropped_items)
	
	return dropped_items


## 生成单个物品掉落物
func spawn_item(item: ItemInstance, spawn_position: Vector2) -> DroppedItem:
	if not item:
		return null
	
	return _create_dropped_item(item, spawn_position)


## 生成金币掉落物
func spawn_gold(amount: int, spawn_position: Vector2) -> DroppedItem:
	if amount <= 0:
		return null
	
	return _create_gold_drop(amount, spawn_position)


## ========== 内部方法 ==========

## 创建掉落物实体
func _create_dropped_item(item: ItemInstance, position: Vector2) -> DroppedItem:
	var dropped: DroppedItem
	
	# 从对象池获取或创建新实例
	if use_pooling:
		dropped = _get_from_pool()
	
	if not dropped:
		if not dropped_item_scene:
			push_error("LootGenerator: 未设置 dropped_item_scene")
			return null
		
		dropped = dropped_item_scene.instantiate() as DroppedItem
		if not dropped:
			push_error("LootGenerator: dropped_item_scene 不是 DroppedItem 类型")
			return null
	
	# 设置物品数据
	dropped.setup_item(item)
	dropped.global_position = position
	
	# 连接信号
	if not dropped.item_picked_up.is_connected(_on_item_picked_up):
		dropped.item_picked_up.connect(_on_item_picked_up)
	
	# 添加到场景
	_spawn_parent.add_child(dropped)
	
	return dropped


## 创建金币掉落物
func _create_gold_drop(amount: int, position: Vector2) -> DroppedItem:
	var dropped: DroppedItem
	
	# 使用专用金币场景或通用场景
	var scene = gold_drop_scene if gold_drop_scene else dropped_item_scene
	
	if not scene:
		push_error("LootGenerator: 未设置掉落物场景")
		return null
	
	dropped = scene.instantiate() as DroppedItem
	if not dropped:
		return null
	
	# 设置金币数据
	dropped.setup_gold(amount)
	dropped.global_position = position
	
	# 连接信号
	if not dropped.item_picked_up.is_connected(_on_item_picked_up):
		dropped.item_picked_up.connect(_on_item_picked_up)
	
	# 添加到场景
	_spawn_parent.add_child(dropped)
	
	return dropped


## 应用散开效果
func _apply_scatter(items: Array[DroppedItem], center: Vector2):
	if items.is_empty():
		return
	
	if circular_scatter:
		# 圆形散开
		var angle_step = TAU / items.size()
		for i in range(items.size()):
			var angle = angle_step * i
			var distance = randf_range(min_scatter_distance, scatter_range)
			var offset = Vector2(cos(angle), sin(angle)) * distance
			items[i].global_position = center + offset
	else:
		# 随机散开
		for item in items:
			var offset = Vector2(
				randf_range(-scatter_range, scatter_range),
				randf_range(-scatter_range, scatter_range)
			)
			# 确保最小距离
			if offset.length() < min_scatter_distance:
				offset = offset.normalized() * min_scatter_distance
			item.global_position = center + offset


## ========== 对象池管理 ==========

## 初始化对象池
func _initialize_pool():
	if not dropped_item_scene:
		return
	
	_item_pool.clear()
	for i in range(pool_size):
		var item = dropped_item_scene.instantiate() as DroppedItem
		if item:
			item.visible = false
			_item_pool.append(item)


## 从对象池获取
func _get_from_pool() -> DroppedItem:
	if _item_pool.is_empty():
		return null
	
	# 寻找未使用的对象
	for i in range(_item_pool.size()):
		var item = _item_pool[_pool_index]
		_pool_index = (_pool_index + 1) % _item_pool.size()
		
		if not item.is_inside_tree():
			item.visible = true
			return item
	
	return null


## 归还到对象池
func _return_to_pool(item: DroppedItem):
	if not use_pooling or item not in _item_pool:
		return
	
	if item.is_inside_tree():
		item.get_parent().remove_child(item)
	
	item.visible = false


## ========== 信号处理 ==========

func _on_item_picked_up(item: ItemInstance, picker: Node2D):
	loot_picked_up.emit(item, picker)


## ========== 工具方法 ==========

## 清除场景中的所有掉落物
func clear_all_drops():
	for child in _spawn_parent.get_children():
		if child is DroppedItem:
			child.queue_free()


## 获取场景中的所有掉落物
func get_all_drops() -> Array[DroppedItem]:
	var drops: Array[DroppedItem] = []
	
	for child in _spawn_parent.get_children():
		if child is DroppedItem:
			drops.append(child)
	
	return drops


## 获取场景中掉落物的总价值
func get_total_loot_value() -> int:
	var total = 0
	
	for drop in get_all_drops():
		if drop.item_instance:
			total += drop.item_instance.get_total_value()
		elif drop.gold_amount > 0:
			total += drop.gold_amount
	
	return total


## 批量生成掉落物（用于测试）
func spawn_random_loot(count: int, spawn_position: Vector2, item_database: Dictionary):
	var items = item_database.values()
	if items.is_empty():
		return
	
	for i in range(count):
		var random_item_data = items[randi() % items.size()]
		if random_item_data is ItemData:
			var item = ItemInstance.create(random_item_data, 1)
			spawn_item(item, spawn_position)