class_name InventoryManager
extends Node
## 背包组件
##
## 管理角色的物品存储，支持格子系统、重量限制、自动堆叠等
## 适用于 2D ARPG 的最佳实践设计

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

@export_group("External References")
## 可选：装备管理器引用。设置后，equip_item() 会走事务化装备流程
## （remove -> equip；失败时把物品放回背包），避免物品在装备失败时丢失。
## 未设置时保持旧行为（仅 remove_item，由调用方负责装备）。
@export var equipment_manager: Node = null

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
			# 部分添加成功：至少有一部分堆叠到已有格子上。
			# 修复历史 BUG：旧实现只 return false 不发信号，UI 拿不到
			# "已入包一部分" 的通知；这里补发 item_added(-1) 与
			# inventory_full，让外部可以准确区分"部分入包"和"完全失败"。
			item.stack_count = remaining_stack
			_update_weight()
			item_added.emit(item, -1)  # -1 表示堆叠到已有格子（无法定位单一 slot）
			inventory_full.emit()
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
##
## 修复历史 BUG：旧实现只发信号 + 减数量，不真正应用 ConsumableData 的
## 效果，导致 "喝药水 = 药水消失但角色不回血"。现在会在 target 上
## 应用消耗品效果（回血/回蓝/回耐/Buff/解 Debuff）。
##
## target 为空时，尝试用 `get_parent()`（例如挂在角色下的 InventoryManager
## 会自动把角色本体当成使用者）。
func use_item(slot_index: int, target: Node = null) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	
	var item = slots[slot_index]
	if not item:
		return false
	
	# 只有消耗品可以使用
	if not item.item_data is ConsumableData:
		return false
	
	var consumable := item.item_data as ConsumableData
	
	# 默认使用者：InventoryManager 的父节点（通常是角色本体）
	if target == null:
		target = get_parent()
	
	# 应用消耗品效果（若 target 缺少必要组件则自动降级为 no-op，
	# 但不会阻止物品消耗——保留旧行为的语义）
	_apply_consumable_effect(consumable, target)
	
	# 通知外部（UI/音效/事件总线）
	item_used.emit(item)
	
	# 减少数量
	item.stack_count -= 1
	if item.stack_count <= 0:
		slots[slot_index] = null
	
	slot_changed.emit(slot_index)
	_update_weight()
	
	return true


## 应用消耗品效果到指定目标。
##
## 分派规则（覆盖 ConsumableData.EffectType 的常见分支）：
##   INSTANT_HEAL     -> stats.heal(effect_value)
##   INSTANT_MANA     -> stats.restore_mana(effect_value)
##   INSTANT_STAMINA  -> stats.restore_stamina(effect_value)
##   BUFF/STAT_BOOST  -> 把 temp_modifiers 加到 stats（BUFF 附带持续时间）
##   HEAL_OVER_TIME / MANA_OVER_TIME -> 挂一个持续时间的 HEALTH_REGEN / MANA_REGEN 修正器
##   DEBUFF_CURE      -> 通过 StatusEffectManager 移除指定 debuff
##
## 若目标缺少对应组件，则跳过（例如无 StatsComponent 的容器也能"使用"物品
## 触发信号，只是没有实际效果）。
func _apply_consumable_effect(consumable: ConsumableData, target: Node) -> void:
	if consumable == null or target == null:
		return
	
	var stats: Node = _find_stats_component(target)
	var status_mgr: Node = _find_status_effect_manager(target)
	
	match consumable.effect_type:
		ConsumableData.EffectType.INSTANT_HEAL:
			if stats and stats.has_method("heal"):
				stats.heal(consumable.effect_value)
		
		ConsumableData.EffectType.INSTANT_MANA:
			if stats and stats.has_method("restore_mana"):
				stats.restore_mana(consumable.effect_value)
		
		ConsumableData.EffectType.INSTANT_STAMINA:
			if stats and stats.has_method("restore_stamina"):
				stats.restore_stamina(consumable.effect_value)
		
		ConsumableData.EffectType.BUFF, ConsumableData.EffectType.STAT_BOOST:
			if stats:
				for template in consumable.temp_modifiers:
					var mod: StatModifier = template.duplicate()
					if consumable.effect_type == ConsumableData.EffectType.BUFF:
						# BUFF 是限时的
						mod.duration = consumable.effect_duration \
							if consumable.effect_duration > 0.0 else mod.duration
					else:
						# STAT_BOOST 是永久的
						mod.duration = -1.0
					stats.add_modifier(mod)
		
		ConsumableData.EffectType.HEAL_OVER_TIME:
			# 用一个限时的 HEALTH_REGEN 修正器实现 HOT
			if stats:
				var mod := StatModifier.new()
				mod.stat_type = StatModifier.StatType.HEALTH_REGEN
				mod.modifier_type = StatModifier.ModifierType.FLAT
				# 若配了 per_second 用它，否则退回 effect_value/effect_duration
				if consumable.effect_per_second > 0.0:
					mod.value = consumable.effect_per_second
				elif consumable.effect_duration > 0.0:
					mod.value = consumable.effect_value / consumable.effect_duration
				else:
					mod.value = consumable.effect_value
				mod.duration = maxf(consumable.effect_duration, 0.001)
				mod.source_id = "consumable_%s" % consumable.id if "id" in consumable else "consumable"
				stats.add_modifier(mod)
		
		ConsumableData.EffectType.MANA_OVER_TIME:
			if stats:
				var mod := StatModifier.new()
				mod.stat_type = StatModifier.StatType.MANA_REGEN
				mod.modifier_type = StatModifier.ModifierType.FLAT
				if consumable.effect_per_second > 0.0:
					mod.value = consumable.effect_per_second
				elif consumable.effect_duration > 0.0:
					mod.value = consumable.effect_value / consumable.effect_duration
				else:
					mod.value = consumable.effect_value
				mod.duration = maxf(consumable.effect_duration, 0.001)
				mod.source_id = "consumable_%s" % consumable.id if "id" in consumable else "consumable"
				stats.add_modifier(mod)
		
		ConsumableData.EffectType.DEBUFF_CURE:
			if status_mgr and status_mgr.has_method("remove_effect"):
				for debuff_id in consumable.cures_debuffs:
					status_mgr.remove_effect(debuff_id, true)
		
		_:
			# TELEPORT / RESURRECT 之类的高级效果目前不在 InventoryManager
			# 的直接职责范围，交给外部监听 `item_used` 信号处理。
			pass


## 尝试在 target 上找到 StatsComponent
func _find_stats_component(target: Node) -> Node:
	if target == null:
		return null
	if target is StatsComponent:
		return target
	var node = target.get_node_or_null("StatsComponent")
	if node:
		return node
	if target.has_method("get_stats_component"):
		return target.get_stats_component()
	return null


## 尝试在 target 上找到 StatusEffectManager
func _find_status_effect_manager(target: Node) -> Node:
	if target == null:
		return null
	var node = target.get_node_or_null("StatusEffectManager")
	if node:
		return node
	if target.has_method("get_status_effect_manager"):
		return target.get_status_effect_manager()
	return null


## ========== 装备操作 ==========

## 装备物品
##
## 若 `equipment_manager` 已配置且暴露 `equip(item)` 方法，则内部完成
## 事务化装备：`remove_item(slot) -> equipment_manager.equip(item)`；
## 装备失败时把物品放回背包，返回 null。**这是推荐路径**。
##
## 若 `equipment_manager` 未配置，则保留旧行为——仅从背包移除物品并
## 返回给调用方，由调用方负责后续装备/归还，否则物品会泄漏。
## 此路径会 push_warning 提醒。
func equip_item(slot_index: int) -> ItemInstance:
	if not _is_valid_slot(slot_index):
		return null
	
	var item = slots[slot_index]
	if not item or not item.item_data is EquipmentData:
		return null
	
	# 事务化装备路径
	if equipment_manager and equipment_manager.has_method("equip"):
		var removed = remove_item(slot_index)
		if not removed:
			return null
		
		var equipped_ok: bool = equipment_manager.equip(removed)
		if equipped_ok:
			return removed
		
		# 装备失败：rollback，物品归还背包
		add_item(removed)
		push_warning("InventoryManager.equip_item: 装备失败，物品已归还背包 [%s]" % removed.item_data.id)
		return null
	
	# 兼容旧调用：仅移除
	push_warning("InventoryManager.equip_item: 未配置 equipment_manager，仅移除物品；" \
		+ "调用方须负责后续装备或调用 add_item 归还，否则物品会丢失。")
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
##
## 修复历史 BUG：旧实现通过 `ItemInstance.try_stack()` 走 `can_stack_with()`，
## 而 `can_stack_with()` 要求 `stack_count + other.stack_count <= max_stack`，
## 一旦相加溢出就完全不堆叠，导致 6 件商品遇到剩余空间 2 时会**一件都不堆**。
## 这里直接手动做部分堆叠：只要 item_data 一致、双方均未 bound、无随机词缀，
## 就把 `min(空间, remaining)` 塞进去。
func _try_stack_with_existing(item: ItemInstance) -> int:
	var remaining := item.stack_count
	if remaining <= 0 or item.item_data == null:
		return remaining
	
	var max_per_slot: int = max(1, item.item_data.max_stack)
	# 不可堆叠的物品直接跳过
	if max_per_slot <= 1:
		return remaining
	
	for i in range(slot_count):
		if remaining <= 0:
			break
		var slot_item: ItemInstance = slots[i]
		if slot_item == null:
			continue
		if slot_item.item_data != item.item_data:
			continue
		if slot_item.is_bound or item.is_bound:
			continue
		if not slot_item.random_modifiers.is_empty():
			continue
		if not item.random_modifiers.is_empty():
			continue
		if slot_item.stack_count >= max_per_slot:
			continue
		
		var space: int = max_per_slot - slot_item.stack_count
		var to_stack: int = min(space, remaining)
		slot_item.stack_count += to_stack
		remaining -= to_stack
		slot_changed.emit(i)
	
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
