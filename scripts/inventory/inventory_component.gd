# res://scripts/inventory/inventory_component.gd
class_name InventoryComponent
extends Node
## 背包组件
##
## 管理角色的物品存储，支持格子系统、重量限制、自动堆叠等
## 适用于 2D ARPG 的最佳实践设计

const ItemInstance = preload("res://scripts/items/item_instance.gd")
const ConsumableData = preload("res://scripts/items/consumable_data.gd")
const EquipmentData = preload("res://scripts/items/equipment_data.gd")

## ========== 信号 ==========
signal item_added(item: ItemInstance, slot_index: int)
signal item_removed(item: ItemInstance, slot_index: int)
signal item_used(item: ItemInstance)
signal inventory_full
signal weight_exceeded
signal slot_changed(slot_index: int)
signal gold_changed(new_amount: int)

## ========== 导出属性 ==========
@export_group("Capacity")
## 背包格子数量
@export var slot_count: int = 20
## 是否启用重量限制
@export var use_weight_limit: bool = true
## 最大负重
@export var max_weight: float = 100.0

@export_group("Auto Features")
## 是否自动堆叠
@export var auto_stack: bool = true
## 是否自动整理（拾取时）
@export var auto_sort: bool = false
## 拾取时是否优先填充已有堆叠
@export var prefer_existing_stacks: bool = true

## ========== 内部数据 ==========
var slots: Array[ItemInstance] = []  # 背包格子数组
var gold: int = 0  # 金币数量
var _current_weight: float = 0.0  # 当前总重量


func _ready():
	# 初始化背包格子
	slots.resize(slot_count)
	for i in range(slot_count):
		slots[i] = null
	
	_update_weight()


## ========== 添加物品 ==========

## 尝试添加物品到背包
func add_item(item: ItemInstance, preferred_slot: int = -1) -> bool:
	if not item:
		return false
	
	# 检查重量限制
	if use_weight_limit:
		if _current_weight + item.get_total_weight() > max_weight:
			weight_exceeded.emit()
			return false
	
	var remaining_stack = item.stack_count
	
	# 步骤1: 优先尝试堆叠到已有物品
	if auto_stack and prefer_existing_stacks:
		remaining_stack = _try_stack_with_existing(item)
		if remaining_stack <= 0:
			item_added.emit(item, -1)  # -1 表示堆叠到现有格子
			_update_weight()
			return true
	
	# 步骤2: 查找空格子
	var target_slot = preferred_slot
	if target_slot < 0 or target_slot >= slot_count or slots[target_slot] != null:
		target_slot = _find_empty_slot()
	
	if target_slot < 0:
		# 没有空格子且无法完全堆叠
		if remaining_stack < item.stack_count:
			# 部分添加成功
			item.stack_count = remaining_stack
			_update_weight()
			return false
		else:
			inventory_full.emit()
			return false
	
	# 步骤3: 放入空格子
	if remaining_stack == item.stack_count:
		# 完整放入
		slots[target_slot] = item
	else:
		# 创建新实例放入剩余部分
		var new_item = item.split_stack(remaining_stack)
		if new_item:
			slots[target_slot] = new_item
	
	item_added.emit(item, target_slot)
	slot_changed.emit(target_slot)
	_update_weight()
	
	return true


## 批量添加物品（战利品）
func add_items(items: Array[ItemInstance]) -> Dictionary:
	var result = {
		"added": [],
		"failed": []
	}
	
	for item in items:
		if add_item(item):
			result.added.append(item)
		else:
			result.failed.append(item)
	
	return result


## ========== 移除物品 ==========

## 从指定格子移除物品
func remove_item(slot_index: int, amount: int = -1) -> ItemInstance:
	if not _is_valid_slot(slot_index):
		return null
	
	var item = slots[slot_index]
	if not item:
		return null
	
	var removed_item: ItemInstance = null
	
	if amount < 0 or amount >= item.stack_count:
		# 移除整个堆叠
		removed_item = item
		slots[slot_index] = null
	else:
		# 分割堆叠
		removed_item = item.split_stack(amount)
	
	if removed_item:
		item_removed.emit(removed_item, slot_index)
		slot_changed.emit(slot_index)
		_update_weight()
	
	return removed_item


## 按物品ID移除
func remove_item_by_id(item_id: String, amount: int = 1) -> int:
	var removed_count = 0
	
	for i in range(slot_count):
		if slots[i] and slots[i].item_data.id == item_id:
			var to_remove = min(amount - removed_count, slots[i].stack_count)
			var removed = remove_item(i, to_remove)
			if removed:
				removed_count += removed.stack_count
			
			if removed_count >= amount:
				break
	
	return removed_count


## ========== 使用物品 ==========

## 使用指定格子的物品
func use_item(slot_index: int, target: Node = null) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	
	var item = slots[slot_index]
	if not item:
		return false
	
	# 只有消耗品可以使用
	if not item.item_data is ConsumableData:
		return false
	
	var consumable = item.item_data as ConsumableData
	
	# 执行使用逻辑（这里简化处理，实际应该通过事件系统）
	item_used.emit(item)
	
	# 减少数量
	item.stack_count -= 1
	if item.stack_count <= 0:
		slots[slot_index] = null
	
	slot_changed.emit(slot_index)
	_update_weight()
	
	return true


## ========== 装备操作 ==========

## 装备物品（需要配合 EquipmentManager 使用）
func equip_item(slot_index: int) -> ItemInstance:
	if not _is_valid_slot(slot_index):
		return null
	
	var item = slots[slot_index]
	if not item or not item.item_data is EquipmentData:
		return null
	
	# 从背包移除（由 EquipmentManager 管理）
	return remove_item(slot_index)


## ========== 格子操作 ==========

## 交换两个格子的物品
func swap_slots(from_index: int, to_index: int) -> bool:
	if not _is_valid_slot(from_index) or not _is_valid_slot(to_index):
		return false
	
	var temp = slots[from_index]
	slots[from_index] = slots[to_index]
	slots[to_index] = temp
	
	slot_changed.emit(from_index)
	slot_changed.emit(to_index)
	
	return true


## 移动物品到指定格子
func move_item(from_index: int, to_index: int, amount: int = -1) -> bool:
	if not _is_valid_slot(from_index) or not _is_valid_slot(to_index):
		return false
	
	var from_item = slots[from_index]
	if not from_item:
		return false
	
	var to_item = slots[to_index]
	
	# 目标格子为空
	if not to_item:
		if amount < 0 or amount >= from_item.stack_count:
			# 移动整个堆叠
			slots[to_index] = from_item
			slots[from_index] = null
		else:
			# 分割堆叠
			slots[to_index] = from_item.split_stack(amount)
		
		slot_changed.emit(from_index)
		slot_changed.emit(to_index)
		return true
	
	# 目标格子有物品，尝试堆叠
	if from_item.can_stack_with(to_item):
		var stacked = to_item.try_stack(from_item)
		if from_item.stack_count <= 0:
			slots[from_index] = null
		
		slot_changed.emit(from_index)
		slot_changed.emit(to_index)
		return stacked > 0
	else:
		# 不能堆叠，交换位置
		return swap_slots(from_index, to_index)


## ========== 查询方法 ==========

## 获取指定格子的物品
func get_item(slot_index: int) -> ItemInstance:
	if not _is_valid_slot(slot_index):
		return null
	return slots[slot_index]


## 检查是否拥有指定物品
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount


## 获取指定物品的总数量
func get_item_count(item_id: String) -> int:
	var count = 0
	for item in slots:
		if item and item.item_data.id == item_id:
			count += item.stack_count
	return count


## 查找物品的所有位置
func find_item_slots(item_id: String) -> Array[int]:
	var result: Array[int] = []
	for i in range(slot_count):
		if slots[i] and slots[i].item_data.id == item_id:
			result.append(i)
	return result


## 获取空格子数量
func get_empty_slot_count() -> int:
	var count = 0
	for item in slots:
		if item == null:
			count += 1
	return count


## 检查是否有空间容纳物品
func has_space_for(item: ItemInstance) -> bool:
	# 检查重量
	if use_weight_limit:
		if _current_weight + item.get_total_weight() > max_weight:
			return false
	
	# 检查格子
	if auto_stack:
		# 尝试计算堆叠后需要的格子数
		var remaining = item.stack_count
		for slot_item in slots:
			if slot_item and slot_item.can_stack_with(item):
				var space = item.item_data.max_stack - slot_item.stack_count
				remaining -= space
				if remaining <= 0:
					return true
		
		# 还需要空格子
		return get_empty_slot_count() > 0
	else:
		return get_empty_slot_count() > 0


## 获取当前总重量
func get_current_weight() -> float:
	return _current_weight


## 获取背包价值
func get_total_value() -> int:
	var total = 0
	for item in slots:
		if item:
			total += item.get_total_value()
	return total


## ========== 整理与排序 ==========

## 整理背包（堆叠相同物品）
func organize() -> void:
	# 首先堆叠所有可堆叠物品
	for i in range(slot_count):
		if not slots[i]:
			continue
		
		for j in range(i + 1, slot_count):
			if not slots[j]:
				continue
			
			if slots[i].can_stack_with(slots[j]):
				slots[i].try_stack(slots[j])
				if slots[j].stack_count <= 0:
					slots[j] = null
					slot_changed.emit(j)
	
	# 然后压缩空格子
	compact()


## 压缩背包（将物品移到前面，空格子移到后面）
func compact() -> void:
	var non_empty: Array[ItemInstance] = []
	
	for item in slots:
		if item:
			non_empty.append(item)
	
	slots.clear()
	slots.resize(slot_count)
	
	for i in range(non_empty.size()):
		slots[i] = non_empty[i]
		slot_changed.emit(i)
	
	for i in range(non_empty.size(), slot_count):
		slots[i] = null
		slot_changed.emit(i)


## 按稀有度排序
func sort_by_rarity() -> void:
	var non_empty: Array[ItemInstance] = []
	for item in slots:
		if item:
			non_empty.append(item)
	
	non_empty.sort_custom(func(a, b): 
		return a.item_data.rarity > b.item_data.rarity
	)
	
	_apply_sorted_items(non_empty)


## 按价值排序
func sort_by_value() -> void:
	var non_empty: Array[ItemInstance] = []
	for item in slots:
		if item:
			non_empty.append(item)
	
	non_empty.sort_custom(func(a, b): 
		return a.item_data.base_value > b.item_data.base_value
	)
	
	_apply_sorted_items(non_empty)


## ========== 金币管理 ==========

## 添加金币
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


## 移除金币
func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false


## 获取金币
func get_gold() -> int:
	return gold


## ========== 序列化 ==========

## 序列化为字典
func to_dict() -> Dictionary:
	var items_data = []
	for i in range(slot_count):
		if slots[i]:
			items_data.append({
				"slot": i,
				"item": slots[i].to_dict()
			})
	
	return {
		"slot_count": slot_count,
		"gold": gold,
		"items": items_data
	}


## 从字典加载
func from_dict(data: Dictionary, item_database: Dictionary) -> void:
	slot_count = data.get("slot_count", 20)
	gold = data.get("gold", 0)
	
	# 重新初始化格子
	slots.clear()
	slots.resize(slot_count)
	for i in range(slot_count):
		slots[i] = null
	
	# 加载物品
	var items_data = data.get("items", [])
	for item_data in items_data:
		var slot = item_data.get("slot", -1)
		if slot >= 0 and slot < slot_count:
			var item = ItemInstance.from_dict(item_data.get("item"), item_database)
			if item:
				slots[slot] = item
	
	_update_weight()
	gold_changed.emit(gold)


## ========== 内部方法 ==========

## 尝试与已有物品堆叠
func _try_stack_with_existing(item: ItemInstance) -> int:
	var remaining = item.stack_count
	
	for i in range(slot_count):
		if slots[i] and slots[i].can_stack_with(item):
			var temp_item = ItemInstance.create(item.item_data, remaining)
			var stacked = slots[i].try_stack(temp_item)
			remaining -= stacked
			slot_changed.emit(i)
			
			if remaining <= 0:
				break
	
	return remaining


## 查找空格子
func _find_empty_slot() -> int:
	for i in range(slot_count):
		if slots[i] == null:
			return i
	return -1


## 检查格子索引是否有效
func _is_valid_slot(index: int) -> bool:
	return index >= 0 and index < slot_count


## 更新总重量
func _update_weight() -> void:
	_current_weight = 0.0
	for item in slots:
		if item:
			_current_weight += item.get_total_weight()


## 应用排序后的物品
func _apply_sorted_items(sorted_items: Array[ItemInstance]) -> void:
	slots.clear()
	slots.resize(slot_count)
	
	for i in range(sorted_items.size()):
		slots[i] = sorted_items[i]
		slot_changed.emit(i)
	
	for i in range(sorted_items.size(), slot_count):
		slots[i] = null
		slot_changed.emit(i)