# res://scripts/loot/loot_table.gd
class_name LootTable
extends Resource
## 掉落表
##
## 定义敌人、宝箱等对象的掉落配置
## 支持多种掉落模式和复杂的掉落规则

## 掉落模式
enum DropMode {
	ALL,              ## 所有条目都尝试掉落
	PICK_ONE,         ## 从表中随机选择一个
	PICK_MULTIPLE,    ## 从表中随机选择多个
	WEIGHTED_RANDOM   ## 加权随机选择
}

## ========== 基础配置 ==========
@export_group("Basic Config")
## 掉落表名称
@export var table_name: String = "未命名掉落表"
## 掉落表描述
@export_multiline var description: String = ""
## 掉落模式
@export var drop_mode: DropMode = DropMode.ALL

## ========== 掉落条目 ==========
@export_group("Loot Entries")
## 掉落条目列表
@export var entries: Array[LootEntry] = []

## ========== 数量配置 ==========
@export_group("Quantity Config")
## 最少掉落条目数（仅用于 PICK_MULTIPLE 模式）
@export var min_picks: int = 1
## 最多掉落条目数（仅用于 PICK_MULTIPLE 模式）
@export var max_picks: int = 3
## 是否允许重复掉落同一物品
@export var allow_duplicates: bool = false

## ========== 金币配置 ==========
@export_group("Gold Drop")
## 是否掉落金币
@export var drops_gold: bool = true
## 最小金币数
@export var min_gold: int = 1
## 最大金币数
@export var max_gold: int = 10
## 幸运值是否影响金币数量
@export var luck_affects_gold: bool = true

## ========== 条件配置 ==========
@export_group("Conditions")
## 整个掉落表的标签（用于条件检查）
@export var table_tags: Array[String] = []

## ========== 特殊配置 ==========
@export_group("Special")
## 掉落表权重（用于嵌套掉落表时的选择）
@export var weight: int = 100
## 额外掉落概率（基于幸运值）
@export var extra_drop_enabled: bool = true


## 生成掉落物品
func generate_loot(player_level: int = 1, luck_value: int = 0, context_tags: Array[String] = []) -> Dictionary:
	var result = {
		"items": [],      # Array[ItemInstance]
		"gold": 0         # int
	}
	
	# 合并上下文标签和掉落表标签
	var all_tags = context_tags.duplicate()
	all_tags.append_array(table_tags)
	
	# 生成金币
	if drops_gold:
		result.gold = _generate_gold(luck_value)
	
	# 根据掉落模式生成物品
	match drop_mode:
		DropMode.ALL:
			result.items = _generate_all_drops(player_level, luck_value, all_tags)
		DropMode.PICK_ONE:
			var item = _pick_one_drop(player_level, luck_value, all_tags)
			if item:
				result.items.append(item)
		DropMode.PICK_MULTIPLE:
			result.items = _pick_multiple_drops(player_level, luck_value, all_tags)
		DropMode.WEIGHTED_RANDOM:
			result.items = _weighted_random_drops(player_level, luck_value, all_tags)
	
	# 额外掉落检测（基于幸运值）
	if extra_drop_enabled and luck_value > 0:
		var extra_items = _roll_extra_drops(player_level, luck_value, all_tags)
		result.items.append_array(extra_items)
	
	return result


## 生成所有可能的掉落
func _generate_all_drops(player_level: int, luck_value: int, tags: Array[String]) -> Array:
	var items = []
	var used_groups = {}
	
	for entry in entries:
		if not entry or not entry.item_data:
			continue
		
		# 检查条件
		if not entry.check_conditions(player_level, tags):
			continue
		
		# 检查组限制
		if entry.group_id != "":
			if entry.group_id in used_groups:
				continue
			used_groups[entry.group_id] = true
		
		# 检查是否触发掉落
		if entry.roll_drop(luck_value):
			var item = entry.create_item_instance(luck_value)
			if item:
				items.append(item)
	
	return items


## 从表中随机选择一个
func _pick_one_drop(player_level: int, luck_value: int, tags: Array[String]) -> ItemInstance:
	var valid_entries = _get_valid_entries(player_level, tags)
	if valid_entries.is_empty():
		return null
	
	# 加权随机选择
	var total_weight = 0
	for entry in valid_entries:
		total_weight += entry.weight
	
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for entry in valid_entries:
		current_weight += entry.weight
		if roll <= current_weight:
			if entry.roll_drop(luck_value):
				return entry.create_item_instance(luck_value)
			return null
	
	return null


## 从表中随机选择多个
func _pick_multiple_drops(player_level: int, luck_value: int, tags: Array[String]) -> Array:
	var items = []
	var valid_entries = _get_valid_entries(player_level, tags)
	
	if valid_entries.is_empty():
		return items
	
	# 确定掉落数量
	var pick_count = randi_range(min_picks, max_picks)
	var available_entries = valid_entries.duplicate()
	var used_groups = {}
	
	for i in range(pick_count):
		if available_entries.is_empty():
			break
		
		# 加权随机选择
		var entry = _weighted_pick(available_entries)
		if not entry:
			break
		
		# 检查组限制
		if entry.group_id != "":
			if entry.group_id in used_groups:
				available_entries.erase(entry)
				continue
			used_groups[entry.group_id] = true
		
		# 尝试掉落
		if entry.roll_drop(luck_value):
			var item = entry.create_item_instance(luck_value)
			if item:
				items.append(item)
		
		# 处理唯一性和重复性
		if entry.unique or not allow_duplicates:
			available_entries.erase(entry)
	
	return items


## 加权随机掉落
func _weighted_random_drops(player_level: int, luck_value: int, tags: Array[String]) -> Array:
	var items = []
	var valid_entries = _get_valid_entries(player_level, tags)
	
	for entry in valid_entries:
		# 每个条目独立进行加权概率检定
		var adjusted_chance = entry.get_final_drop_chance(luck_value)
		var weighted_chance = adjusted_chance * (entry.weight / 100.0)
		
		if randf() < weighted_chance:
			var item = entry.create_item_instance(luck_value)
			if item:
				items.append(item)
	
	return items


## 额外掉落检测
func _roll_extra_drops(player_level: int, luck_value: int, tags: Array[String]) -> Array:
	var extra_items = []
	var extra_chance = LuckSystem.get_extra_drop_chance(luck_value)
	
	if randf() < extra_chance:
		# 触发额外掉落，随机选择一个物品
		var item = _pick_one_drop(player_level, luck_value, tags)
		if item:
			extra_items.append(item)
	
	return extra_items


## 生成金币
func _generate_gold(luck_value: int) -> int:
	var gold = randi_range(min_gold, max_gold)
	
	if luck_affects_gold and luck_value > 0:
		gold = int(LuckSystem.apply_luck_to_value(gold, luck_value, 0.01))
	
	return gold


## 获取有效的掉落条目
func _get_valid_entries(player_level: int, tags: Array[String]) -> Array[LootEntry]:
	var valid: Array[LootEntry] = []
	
	for entry in entries:
		if entry and entry.item_data and entry.check_conditions(player_level, tags):
			valid.append(entry)
	
	return valid


## 加权随机选择
func _weighted_pick(entry_list: Array) -> LootEntry:
	if entry_list.is_empty():
		return null
	
	var total_weight = 0
	for entry in entry_list:
		total_weight += entry.weight
	
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for entry in entry_list:
		current_weight += entry.weight
		if roll <= current_weight:
			return entry
	
	return entry_list[0]


## 获取表中所有可能掉落的物品预览（用于UI显示）
func get_all_possible_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	
	for entry in entries:
		if entry and entry.item_data and entry.item_data not in items:
			items.append(entry.item_data)
	
	return items


## 获取平均掉落价值（用于平衡性测试）
func get_average_value(player_level: int = 1, luck_value: int = 0) -> float:
	var total_value = 0.0
	var sample_count = 100
	
	for i in range(sample_count):
		var loot = generate_loot(player_level, luck_value, table_tags)
		total_value += loot.gold
		
		for item in loot.items:
			if item is ItemInstance:
				total_value += item.get_total_value()
	
	return total_value / sample_count