class_name EquipmentManager
extends Node
## 装备管理器
##
## 管理角色的装备槽位，处理装备/卸下逻辑，应用属性加成
## 支持套装检测、耐久度消耗等功能

## ========== 信号 ==========
signal equipment_restored
signal equipment_changed(slot: EquipmentData.EquipSlot, item: ItemInstance)
signal equipment_equipped(slot: EquipmentData.EquipSlot, item: ItemInstance)
signal equipment_unequipped(slot: EquipmentData.EquipSlot, item: ItemInstance)
signal set_bonus_activated(set_id: String, piece_count: int)
signal set_bonus_deactivated(set_id: String)
signal durability_changed(slot: EquipmentData.EquipSlot, current: int, max: int)
signal equipment_broken(slot: EquipmentData.EquipSlot, item: ItemInstance)

## ========== 导出属性 ==========
@export_group("References")
## 角色属性组件引用
@export var stats_component: StatsComponent
## 背包组件引用（用于装备/卸下时的物品转移）
@export var inventory: InventoryManager

@export_group("Features")
## 是否启用耐久度消耗
@export var enable_durability: bool = true
## 受击时消耗耐久度的概率
@export var durability_loss_on_hit: float = 0.1
## 每次消耗的耐久度
@export var durability_loss_amount: int = 1

## ========== 内部数据 ==========
# 装备槽位字典 {EquipSlot: ItemInstance}
var equipped_items: Dictionary[EquipmentData.EquipSlot, ItemInstance] = {}
# 套装计数 {set_id: count}
var set_pieces: Dictionary = {}
# 应用的修正器追踪 {EquipSlot: Array[StatModifier]}
var applied_modifiers: Dictionary[EquipmentData.EquipSlot, Array] = {}
var _transaction_active: bool = false
var _pending_events: Array = []


func _ready():
	# 初始化所有装备槽位
	for slot in EquipmentData.EquipSlot.values():
		equipped_items[slot] = null
		applied_modifiers[slot] = []


## ========== 装备操作 ==========

## 装备物品
func equip(item: ItemInstance, auto_swap: bool = true) -> bool:
	if _transaction_active or item in get_all_equipped():
		return false
	if inventory:
		var index := inventory.slots.find(item)
		if index >= 0:
			return equip_from_inventory(index, auto_swap)
	_transaction_active = true
	var result := _equip(item, auto_swap)
	_flush_events()
	_transaction_active = false
	return result


func _equip(item: ItemInstance, auto_swap: bool) -> bool:
	if not item or not item.item_data is EquipmentData:
		push_warning("EquipmentManager: 尝试装备非装备物品")
		return false
	
	var equip_data = item.item_data as EquipmentData
	var slot = equip_data.equip_slot
	
	# 检查等级需求
	if stats_component:
		var player_level = stats_component.get_stat(StatModifier.StatType.LEVEL)
		if not equip_data.can_equip(player_level):
			push_warning("EquipmentManager: 等级不足，需要等级 %d" % equip_data.required_level)
			return false
	
	# 检查是否需要卸下当前装备
	var old_item = equipped_items[slot]
	if old_item:
		if not auto_swap:
			push_warning("EquipmentManager: 槽位已有装备")
			return false
		
		# 先卸下旧装备
		if not _unequip(slot, true):
			return false
	
	# 装备新物品
	equipped_items[slot] = item
	
	# 应用属性加成
	if not item.is_broken():
		_apply_item_modifiers(item, slot)
	
	# 更新套装
	_update_set_bonuses(equip_data.set_bonus_id, 1)
	
	# 标记为已绑定
	if equip_data.bind_on_equip:
		item.is_bound = true
	
	_notify(&"equipment_equipped", [slot, item])
	_notify(&"equipment_changed", [slot, item])
	
	return true


## 卸下装备
func unequip(slot: EquipmentData.EquipSlot, to_inventory: bool = true) -> bool:
	if _transaction_active:
		return false
	_transaction_active = true
	var result := _unequip(slot, to_inventory)
	_flush_events()
	_transaction_active = false
	return result


func _unequip(slot: EquipmentData.EquipSlot, to_inventory: bool) -> bool:
	var item := get_equipped(slot)
	if not item:
		return false
	var inventory_was_blocked := false
	var target_slot := -1
	if to_inventory:
		if not inventory or not inventory.has_space_for(item):
			return false
		inventory_was_blocked = inventory.is_blocking_signals()
		inventory.set_block_signals(true)
		var accepted := inventory.add_item(item)
		inventory.set_block_signals(inventory_was_blocked)
		if not accepted:
			return false
		target_slot = inventory.slots.find(item)
	# 只有实际入包成功后才移除装备与属性。
	equipped_items[slot] = null
	_remove_item_modifiers(slot)
	var equip_data := item.item_data as EquipmentData
	_update_set_bonuses(equip_data.set_bonus_id, -1)
	if to_inventory and not inventory_was_blocked:
		inventory.item_added.emit(item, target_slot)
		inventory.slot_changed.emit(target_slot)
	_notify(&"equipment_unequipped", [slot, item])
	_notify(&"equipment_changed", [slot, null])
	return true


## 卸下所有装备
func unequip_all(to_inventory: bool = true) -> Array:
	var unequipped = []
	
	for slot in EquipmentData.EquipSlot.values():
		if equipped_items[slot]:
			if unequip(slot, to_inventory):
				unequipped.append(slot)
	
	return unequipped


## 快速装备（从背包直接装备）
func equip_from_inventory(slot_index: int, auto_swap: bool = true) -> bool:
	if _transaction_active or not inventory:
		return false
	var item := inventory.get_item(slot_index)
	if not item or not item.item_data is EquipmentData or item in get_all_equipped():
		return false
	_transaction_active = true
	# 隐藏中间移除通知，防止观察者抢占临时空格子，导致回滚丢失。
	var was_blocked := inventory.is_blocking_signals()
	inventory.set_block_signals(true)
	var previous := get_equipped((item.item_data as EquipmentData).equip_slot)
	var removed := inventory.remove_item(slot_index)
	var succeeded := _equip(removed, auto_swap)
	if not succeeded:
		# 恢复原格子，不经过可能因负重/业务限制失败的 add_item。
		inventory.slots[slot_index] = removed
		inventory._update_weight()
	inventory.set_block_signals(was_blocked)
	if succeeded and not was_blocked:
		var returned_slot := inventory.slots.find(previous) if previous else -1
		inventory.item_removed.emit(removed, slot_index)
		if returned_slot >= 0:
			inventory.item_added.emit(previous, returned_slot)
			if returned_slot != slot_index:
				inventory.slot_changed.emit(returned_slot)
		inventory.slot_changed.emit(slot_index)
	_flush_events()
	_transaction_active = false
	return succeeded


## 转移中的通知排队，背包信号恢复后才派发，避免隐藏监听器的正常操作。
func _notify(signal_name: StringName, args: Array) -> void:
	if _transaction_active:
		_pending_events.append([signal_name, args])
	else:
		callv("emit_signal", [signal_name] + args)


func _flush_events() -> void:
	var events := _pending_events
	_pending_events = []
	for event in events:
		callv("emit_signal", [event[0]] + event[1])


## ========== 查询方法 ==========

## 获取指定槽位的装备
func get_equipped(slot: EquipmentData.EquipSlot) -> ItemInstance:
	return equipped_items.get(slot, null)


## 检查槽位是否有装备
func is_slot_equipped(slot: EquipmentData.EquipSlot) -> bool:
	return equipped_items.get(slot, null) != null


## 获取所有已装备物品
func get_all_equipped() -> Array:
	var result = []
	for item in equipped_items.values():
		if item:
			result.append(item)
	return result


## 获取装备总数
func get_equipped_count() -> int:
	var count = 0
	for item in equipped_items.values():
		if item:
			count += 1
	return count


## 获取套装件数
func get_set_piece_count(set_id: String) -> int:
	return set_pieces.get(set_id, 0)


## 检查是否激活套装效果
func has_set_bonus(set_id: String, required_pieces: int) -> bool:
	return get_set_piece_count(set_id) >= required_pieces


## 获取所有激活的套装
func get_active_sets() -> Array:
	var active = []
	for set_id in set_pieces.keys():
		if set_pieces[set_id] > 0:
			active.append({
				"set_id": set_id,
				"count": set_pieces[set_id]
			})
	return active


## ========== 耐久度管理 ==========

## 减少所有装备耐久度（通常在受击时调用）
func consume_durability_on_hit() -> void:
	if not enable_durability:
		return
	
	# 根据概率决定是否消耗耐久度
	if randf() > durability_loss_on_hit:
		return
	
	# 随机选择一件装备消耗耐久度
	var equipped_slots = []
	for slot in equipped_items.keys():
		if equipped_items[slot]:
			equipped_slots.append(slot)
	
	if equipped_slots.is_empty():
		return
	
	var random_slot = equipped_slots[randi() % equipped_slots.size()]
	consume_durability(random_slot, durability_loss_amount)


## 消耗指定槽位装备的耐久度
func consume_durability(slot: EquipmentData.EquipSlot, amount: int = 1) -> void:
	if _transaction_active:
		return
	var item = equipped_items.get(slot, null)
	if not item:
		return
	
	var equip_data = item.item_data as EquipmentData
	if not equip_data.has_durability:
		return
	
	_transaction_active = true
	var was_broken: bool = item.is_broken()
	item.reduce_durability(amount)
	if not was_broken and item.is_broken():
		_handle_broken_equipment(slot, item)
	_notify(&"durability_changed", [slot, item.current_durability, equip_data.max_durability])
	_flush_events()
	_transaction_active = false


## 修理装备
func repair_equipment(slot: EquipmentData.EquipSlot, full_repair: bool = true) -> int:
	if _transaction_active:
		return 0
	var item = equipped_items.get(slot, null)
	if not item:
		return 0
	
	var equip_data = item.item_data as EquipmentData
	if not equip_data.has_durability:
		return 0
	
	_transaction_active = true
	var was_broken: bool = item.is_broken()
	var old_durability = item.current_durability
	
	if full_repair:
		item.repair()
	else:
		item.repair(equip_data.max_durability / 2)  # 修理一半
	
	if was_broken and not item.is_broken():
		_apply_item_modifiers(item, slot)
	var repaired = item.current_durability - old_durability
	_notify(&"durability_changed", [slot, item.current_durability, equip_data.max_durability])
	_flush_events()
	_transaction_active = false
	return repaired


## 修理所有装备
func repair_all() -> int:
	var total_cost = 0
	
	for slot in equipped_items.keys():
		var item = equipped_items[slot]
		if item and item.item_data is EquipmentData:
			var equip_data = item.item_data as EquipmentData
			if equip_data.has_durability:
				total_cost += equip_data.get_repair_cost(item.current_durability)
				repair_equipment(slot, true)
	
	return total_cost


## ========== 属性管理 ==========

## 应用物品的属性修正器
func _apply_item_modifiers(item: ItemInstance, slot: EquipmentData.EquipSlot) -> void:
	if not stats_component:
		return
	
	var modifiers = item.get_all_modifiers()
	applied_modifiers[slot] = []
	
	for template in modifiers:
		var mod := template.duplicate(true) as StatModifier
		# 每个角色使用独立的修正器，不修改共享装备资源。
		# 设置来源为装备槽位
		mod.source_id = "equipment_%s" % EquipmentData.EquipSlot.keys()[slot]
		stats_component.add_modifier(mod)
		applied_modifiers[slot].append(mod)


## 移除物品的属性修正器
func _remove_item_modifiers(slot: EquipmentData.EquipSlot) -> void:
	if not stats_component:
		return
	
	var modifiers = applied_modifiers.get(slot, [])
	for mod in modifiers:
		stats_component.remove_modifier(mod)
	
	applied_modifiers[slot] = []


## ========== 套装系统 ==========

## 更新套装计数
func _update_set_bonuses(set_id: String, delta: int) -> void:
	if set_id == "":
		return
	
	var old_count = set_pieces.get(set_id, 0)
	var new_count = max(0, old_count + delta)
	set_pieces[set_id] = new_count
	
	# 检查套装效果激活/失效
	if new_count > old_count:
		# 新增套装件
		_check_set_activation(set_id, new_count)
	elif new_count < old_count:
		# 减少套装件
		_check_set_deactivation(set_id, new_count)


## 检查套装激活
func _check_set_activation(set_id: String, count: int) -> void:
	# 这里可以根据具体的套装效果阈值触发
	# 例如: 2件套、4件套、6件套等
	var thresholds = [2, 4, 6]
	
	if count in thresholds:
		_notify(&"set_bonus_activated", [set_id, count])
		# TODO: 应用套装加成效果


## 检查套装失效
func _check_set_deactivation(set_id: String, count: int) -> void:
	var thresholds = [2, 4, 6]
	
	# 检查是否跌破某个阈值
	if (count + 1) in thresholds and count not in thresholds:
		_notify(&"set_bonus_deactivated", [set_id])
		# TODO: 移除套装加成效果


## ========== 装备损坏处理 ==========

## 处理装备损坏
func _handle_broken_equipment(slot: EquipmentData.EquipSlot, item: ItemInstance) -> void:
	
	# 可选: 自动卸下损坏的装备
	# unequip(slot, true)
	
	# 或者: 保留装备但移除属性加成
	_remove_item_modifiers(slot)
	_notify(&"equipment_broken", [slot, item])


## ========== 序列化 ==========

## 序列化为字典
func to_dict() -> Dictionary:
	var equipped_data = {}
	
	for slot in equipped_items.keys():
		if equipped_items[slot]:
			equipped_data[EquipmentData.EquipSlot.keys()[slot]] = equipped_items[slot].to_dict()
	
	return {
		"equipped": equipped_data,
		"set_pieces": set_pieces.duplicate(true)
	}


## 从字典加载
func from_dict(data: Dictionary, item_database: Dictionary) -> bool:
	if _transaction_active:
		return false
	var entries = data.get("equipped", {})
	if not entries is Dictionary:
		return false
	var restored: Dictionary[EquipmentData.EquipSlot, ItemInstance] = {}
	var counts: Dictionary = {}
	var ids: Dictionary = {}
	for slot in EquipmentData.EquipSlot.values():
		restored[slot] = null
	for slot_name in entries:
		if not slot_name is String or not EquipmentData.EquipSlot.has(slot_name) or not entries[slot_name] is Dictionary:
			return false
		var slot: EquipmentData.EquipSlot = EquipmentData.EquipSlot[slot_name]
		var item = ItemInstance.from_dict(entries[slot_name], item_database)
		if not item or not item.item_data is EquipmentData or item.item_data.equip_slot != slot or ids.has(item.instance_id):
			return false
		ids[item.instance_id] = true
		restored[slot] = item
		var set_id: String = item.item_data.set_bonus_id
		if not set_id.is_empty():
			counts[set_id] = counts.get(set_id, 0) + 1
	# Restore state directly: no transfer, binding, level check or gameplay events.
	_transaction_active = true
	var stats_was_blocked: bool = stats_component.is_blocking_signals() if stats_component else false
	if stats_component:
		stats_component.set_block_signals(true)
	for slot in EquipmentData.EquipSlot.values():
		_remove_item_modifiers(slot)
	equipped_items = restored
	set_pieces = counts
	for slot in equipped_items:
		var item: ItemInstance = equipped_items[slot]
		if item and not item.is_broken():
			_apply_item_modifiers(item, slot)
	if stats_component:
		stats_component.set_block_signals(stats_was_blocked)
		if not stats_was_blocked:
			stats_component.modifiers_changed.emit()
	equipment_restored.emit()
	_transaction_active = false
	return true


## ========== 调试工具 ==========

## 打印当前装备信息
func print_equipment_status() -> void:
	print("========== 装备状态 ==========")
	for slot in EquipmentData.EquipSlot.values():
		var item = equipped_items[slot]
		var slot_name = EquipmentData.EquipSlot.keys()[slot]
		
		if item:
			var equip_data = item.item_data as EquipmentData
			var durability_info = ""
			if equip_data.has_durability:
				durability_info = " [%d/%d]" % [item.current_durability, equip_data.max_durability]
			
			print("%s: %s%s" % [slot_name, item.item_data.item_name, durability_info])
		else:
			print("%s: 空" % slot_name)
	
	if not set_pieces.is_empty():
		print("\n套装:")
		for set_id in set_pieces.keys():
			if set_pieces[set_id] > 0:
				print("  %s: %d 件" % [set_id, set_pieces[set_id]])
	
	print("=============================\n")
