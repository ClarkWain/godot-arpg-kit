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
signal gold_picked_up(amount: int, picker: Node2D)

## 可选同步事务处理器，签名与 DroppedItem.pickup_handler 相同。
var pickup_handler: Callable

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
var _pool_storage: Node
var _active_drops: Array[DroppedItem] = []


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
	var dropped := _create_drop(dropped_item_scene)
	if not dropped:
		return null
	dropped.setup_item(item)
	_activate_drop(dropped, position)
	return dropped


## 创建金币掉落物（专用金币场景不混用通用物品池）。
func _create_gold_drop(amount: int, position: Vector2) -> DroppedItem:
	var scene := gold_drop_scene if gold_drop_scene else dropped_item_scene
	var dropped := _create_drop(scene)
	if not dropped:
		return null
	dropped.setup_gold(amount)
	_activate_drop(dropped, position)
	return dropped


func _create_drop(scene: PackedScene) -> DroppedItem:
	if not is_instance_valid(_spawn_parent) or not _spawn_parent.is_inside_tree():
		_spawn_parent = get_tree().current_scene if is_inside_tree() else null
	if not is_instance_valid(_spawn_parent):
		push_warning("LootGenerator: 未找到掉落物父节点")
		return null
	if not scene:
		push_error("LootGenerator: 未设置掉落物场景")
		return null
	if use_pooling and scene == dropped_item_scene:
		var pooled := _get_from_pool()
		if pooled:
			return pooled
	var node := scene.instantiate()
	if not node is DroppedItem:
		node.free()
		push_error("LootGenerator: 掉落物场景不是 DroppedItem 类型")
		return null
	return node as DroppedItem


func _activate_drop(dropped: DroppedItem, position: Vector2) -> void:
	dropped.pickup_handler = pickup_handler
	if not dropped.item_picked_up.is_connected(_on_item_picked_up):
		dropped.item_picked_up.connect(_on_item_picked_up)
	if not dropped.gold_picked_up.is_connected(_on_gold_picked_up):
		dropped.gold_picked_up.connect(_on_gold_picked_up)
	var exiting := _forget_active.bind(dropped)
	if not dropped.tree_exiting.is_connected(exiting):
		dropped.tree_exiting.connect(exiting)
	_active_drops.append(dropped)
	_spawn_parent.add_child(dropped)
	dropped.global_position = position


func _forget_active(dropped: DroppedItem) -> void:
	_active_drops.erase(dropped)


func _exit_tree() -> void:
	# 活跃池对象可能在外部关卡节点下；生成器仍负责结束它们。
	for dropped in _active_drops.duplicate():
		if is_instance_valid(dropped):
			dropped.queue_free()
	_active_drops.clear()


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

## 空闲对象由生成器的子节点持有，随生成器销毁，避免孤立节点泄漏。
func _initialize_pool():
	_pool_storage = Node.new()
	_pool_storage.name = "InactiveDrops"
	_pool_storage.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_pool_storage)
	if not dropped_item_scene:
		return
	for i in range(maxi(0, pool_size)):
		_add_pool_item()


func _add_pool_item() -> DroppedItem:
	var node := dropped_item_scene.instantiate()
	if not node is DroppedItem:
		node.free()
		return null
	var item := node as DroppedItem
	item.recycle_handler = _return_to_pool
	_pool_storage.add_child(item)
	_item_pool.append(item)
	_park_drop(item)
	return item


func _park_drop(item: DroppedItem) -> void:
	if is_instance_valid(item._release_timer):
		item._release_timer.stop()
	item.item_instance = null
	item.gold_amount = 0
	item._target_player = null
	item.visible = false
	item.set_process(false)
	item.monitoring = false
	item.monitorable = false


## 池满时返回 null，由调用方创建普通对象；外部已释放的池对象会补齐。
func _get_from_pool() -> DroppedItem:
	if not is_instance_valid(_pool_storage):
		_initialize_pool()
	for i in range(_item_pool.size() - 1, -1, -1):
		if not is_instance_valid(_item_pool[i]) or _item_pool[i].is_queued_for_deletion():
			_item_pool.remove_at(i)
	for i in range(_item_pool.size()):
		_pool_index %= _item_pool.size()
		var item := _item_pool[_pool_index]
		_pool_index = (_pool_index + 1) % _item_pool.size()
		if item.get_parent() == _pool_storage:
			_pool_storage.remove_child(item)
			item.monitoring = true
			item.monitorable = true
			return item
	if _item_pool.size() < maxi(0, pool_size):
		var item := _add_pool_item()
		if item:
			_pool_storage.remove_child(item)
			item.monitoring = true
			item.monitorable = true
			return item
	return null


func _return_to_pool(item: DroppedItem) -> void:
	if not is_instance_valid(item) or item not in _item_pool:
		return
	if not is_instance_valid(_pool_storage) or not is_inside_tree():
		item.queue_free()
		return
	if item.get_parent() != _pool_storage:
		item.reparent(_pool_storage)
	_park_drop(item)


## ========== 信号处理 ==========

func _on_item_picked_up(item: ItemInstance, picker: Node2D):
	loot_picked_up.emit(item, picker)


func _on_gold_picked_up(amount: int, picker: Node2D) -> void:
	gold_picked_up.emit(amount, picker)


## ========== 工具方法 ==========

## 清除场景中的所有掉落物
func clear_all_drops():
	for dropped in _active_drops.duplicate():
		if is_instance_valid(dropped) and not dropped.is_queued_for_deletion():
			dropped._finish_lifetime()


## 只返回本生成器拥有的活跃掉落物，不混入其他生成器或空闲池对象。
func get_all_drops() -> Array[DroppedItem]:
	var drops: Array[DroppedItem] = []
	for dropped in _active_drops:
		if is_instance_valid(dropped) and not dropped.is_queued_for_deletion():
			drops.append(dropped)
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