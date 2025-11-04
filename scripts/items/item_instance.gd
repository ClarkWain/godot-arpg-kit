# res://scripts/items/item_instance.gd
class_name ItemInstance
extends RefCounted
## 物品实例类
##
## 表示物品的运行时实例,包含堆叠数量、耐久度、随机属性等
## 与 ItemData 分离,实现数据与实例的解耦

## ========== 核心属性 ==========
## 物品数据引用
var item_data: ItemData

## 运行时属性
var stack_count: int = 1                       ## 当前堆叠数量
var current_durability: int = 0                ## 当前耐久度 (仅装备使用)

## 随机属性 (用于装备的随机词缀系统)
var random_modifiers: Array[StatModifier] = []

## 唯一ID (用于追踪特定物品实例,如任务物品、特殊装备等)
var instance_id: String = ""

## 是否已绑定 (绑定后无法交易)
var is_bound: bool = false

## 自定义数据 (用于存储特殊状态)
var custom_data: Dictionary = {}


## ========== 工厂方法 ==========

## 创建物品实例
static func create(data: ItemData, count: int = 1) -> ItemInstance:
	if not data:
		push_error("ItemInstance.create: data 不能为空!")
		return null
	
	var instance = ItemInstance.new()
	instance.item_data = data
	instance.stack_count = clamp(count, 1, data.max_stack)
	instance.instance_id = _generate_uuid()
	
	# 初始化耐久度
	if data is EquipmentData and data.has_durability:
		instance.current_durability = data.max_durability
	
	return instance


## 创建带随机属性的装备实例
static func create_random_equipment(data: EquipmentData, modifier_count: int = 0) -> ItemInstance:
	var instance = create(data, 1)
	if not instance:
		return null
	
	# 生成随机属性修正器
	for i in range(modifier_count):
		var random_mod = _generate_random_modifier()
		if random_mod:
			instance.random_modifiers.append(random_mod)
	
	return instance


## ========== 堆叠管理 ==========

## 是否可以与另一个实例堆叠
func can_stack_with(other: ItemInstance) -> bool:
	if not other:
		return false
	
	# 物品数据必须相同
	if item_data != other.item_data:
		return false
	
	# 不可堆叠的物品
	if item_data.max_stack <= 1:
		return false
	
	# 已绑定的物品不能堆叠
	if is_bound or other.is_bound:
		return false
	
	# 装备有随机属性不能堆叠
	if not random_modifiers.is_empty() or not other.random_modifiers.is_empty():
		return false
	
	# 检查是否超出最大堆叠
	return stack_count + other.stack_count <= item_data.max_stack


## 尝试堆叠另一个实例
func try_stack(other: ItemInstance) -> int:
	if not can_stack_with(other):
		return 0
	
	var space_available = item_data.max_stack - stack_count
	var amount_to_add = min(space_available, other.stack_count)
	
	stack_count += amount_to_add
	other.stack_count -= amount_to_add
	
	return amount_to_add


## 分割堆叠
func split_stack(amount: int) -> ItemInstance:
	if amount <= 0 or amount >= stack_count:
		return null
	
	var new_instance = ItemInstance.new()
	new_instance.item_data = item_data
	new_instance.stack_count = amount
	new_instance.instance_id = _generate_uuid()
	new_instance.is_bound = is_bound
	new_instance.custom_data = custom_data.duplicate()
	
	# 复制随机属性
	for mod in random_modifiers:
		new_instance.random_modifiers.append(mod)
	
	# 复制耐久度
	if item_data is EquipmentData:
		new_instance.current_durability = current_durability
	
	stack_count -= amount
	
	return new_instance


## ========== 属性获取 ==========

## 获取总重量
func get_total_weight() -> float:
	return item_data.weight * stack_count


## 获取总价值
func get_total_value() -> int:
	return item_data.base_value * stack_count


## 获取出售价格
func get_sell_price() -> int:
	if not item_data.can_sell:
		return 0
	return item_data.get_sell_price() * stack_count


## 获取所有属性修正器 (基础 + 随机)
func get_all_modifiers() -> Array[StatModifier]:
	var all_mods: Array[StatModifier] = []
	
	if item_data is EquipmentData:
		all_mods.append_array(item_data.stat_modifiers)
	
	all_mods.append_array(random_modifiers)
	
	return all_mods


## ========== 耐久度管理 ==========

## 减少耐久度
func reduce_durability(amount: int) -> void:
	if not item_data is EquipmentData:
		return
	
	var equip_data = item_data as EquipmentData
	if not equip_data.has_durability:
		return
	
	current_durability = max(0, current_durability - amount)


## 修理装备
func repair(amount: int = -1) -> void:
	if not item_data is EquipmentData:
		return
	
	var equip_data = item_data as EquipmentData
	if not equip_data.has_durability:
		return
	
	if amount < 0:
		# 完全修复
		current_durability = equip_data.max_durability
	else:
		current_durability = min(equip_data.max_durability, current_durability + amount)


## 是否已损坏
func is_broken() -> bool:
	if not item_data is EquipmentData:
		return false
	
	var equip_data = item_data as EquipmentData
	if not equip_data.has_durability:
		return false
	
	return current_durability <= 0


## 获取耐久度百分比
func get_durability_percent() -> float:
	if not item_data is EquipmentData:
		return 1.0
	
	var equip_data = item_data as EquipmentData
	if not equip_data.has_durability:
		return 1.0
	
	return float(current_durability) / float(equip_data.max_durability)


## ========== 序列化 ==========

## 序列化为字典 (用于存档)
func to_dict() -> Dictionary:
	var data = {
		"item_id": item_data.id,
		"stack_count": stack_count,
		"instance_id": instance_id,
		"is_bound": is_bound,
		"custom_data": custom_data
	}
	
	# 保存耐久度
	if item_data is EquipmentData and item_data.has_durability:
		data["durability"] = current_durability
	
	# 保存随机属性
	if not random_modifiers.is_empty():
		var mods_data = []
		for mod in random_modifiers:
			mods_data.append({
				"stat_type": mod.stat_type,
				"modifier_type": mod.modifier_type,
				"value": mod.value
			})
		data["random_modifiers"] = mods_data
	
	return data


## 从字典反序列化
static func from_dict(data: Dictionary, item_database: Dictionary) -> ItemInstance:
	var item_id = data.get("item_id", "")
	if not item_database.has(item_id):
		push_error("ItemInstance.from_dict: 找不到物品 ID: " + item_id)
		return null
	
	var tmp_item_data = item_database[item_id]
	var instance = create(tmp_item_data, data.get("stack_count", 1))
	
	instance.instance_id = data.get("instance_id", instance.instance_id)
	instance.is_bound = data.get("is_bound", false)
	instance.custom_data = data.get("custom_data", {})
	
	# 恢复耐久度
	if data.has("durability"):
		instance.current_durability = data["durability"]
	
	# 恢复随机属性
	if data.has("random_modifiers"):
		for mod_data in data["random_modifiers"]:
			var mod = StatModifier.new()
			mod.stat_type = mod_data["stat_type"]
			mod.modifier_type = mod_data["modifier_type"]
			mod.value = mod_data["value"]
			instance.random_modifiers.append(mod)
	
	return instance


## ========== 内部方法 ==========

## 生成唯一ID
static func _generate_uuid() -> String:
	return "%d_%d" % [Time.get_ticks_usec(), randi()]


## 生成随机属性修正器 (示例实现)
static func _generate_random_modifier() -> StatModifier:
	# 随机选择一个属性类型
	var stat_types = [
		StatModifier.StatType.STRENGTH,
		StatModifier.StatType.AGILITY,
		StatModifier.StatType.INTELLIGENCE,
		StatModifier.StatType.VITALITY,
		StatModifier.StatType.PHYSICAL_DAMAGE,
		StatModifier.StatType.MAGIC_DAMAGE,
		StatModifier.StatType.ARMOR,
		StatModifier.StatType.CRIT_CHANCE
	]
	
	var stat_type = stat_types[randi() % stat_types.size()]
	
	# 随机生成数值
	var value = randf_range(1.0, 10.0)
	
	# 随机选择修正器类型
	var modifier_type = StatModifier.ModifierType.FLAT
	if randf() < 0.3:  # 30% 概率是百分比加成
		modifier_type = StatModifier.ModifierType.PERCENT
		value = randf_range(0.05, 0.15)  # 5%-15%
	
	var mod = StatModifier.new()
	mod.stat_type = stat_type
	mod.modifier_type = modifier_type
	mod.value = value
	mod.source_id = "random_affix"
	mod.add_tag("random")
	
	return mod
