class_name EnemyLootComponent
extends Node
## 敌人掉落组件
##
## 挂载到敌人节点上，处理死亡时的掉落逻辑
## 支持多个掉落表、条件掉落、首杀奖励等

## ========== 信号 ==========
## 掉落生成时触发
signal loot_generated(loot_data: Dictionary)
## 掉落物生成到场景时触发
signal loot_spawned(dropped_items: Array)

## ========== 基础配置 ==========
@export_group("Basic Settings")
## 主掉落表
@export var main_loot_table: LootTable
## 额外掉落表（概率性触发）
@export var bonus_loot_tables: Array[LootTable] = []
## 额外掉落表触发概率
@export_range(0.0, 1.0, 0.01) var bonus_table_chance: float = 0.2

## ========== 敌人信息 ==========
@export_group("Enemy Info")
## 敌人等级（用于掉落表条件判断）
@export var enemy_level: int = 1
## 敌人标签（用于掉落表条件判断）
@export var enemy_tags: Array[String] = []
## 是否为精英怪
@export var is_elite: bool = false
## 是否为Boss
@export var is_boss: bool = false

## ========== 掉落修正 ==========
@export_group("Drop Modifiers")
## 掉落率倍数（全局修正）
@export var drop_rate_multiplier: float = 1.0
## 掉落数量倍数
@export var drop_quantity_multiplier: float = 1.0
## 金币倍数
@export var gold_multiplier: float = 1.0
## 稀有度提升概率
@export var rarity_boost_chance: float = 0.0

## ========== 特殊掉落 ==========
@export_group("Special Drops")
## 保证掉落的物品（必定掉落）
@export var guaranteed_drops: Array[ItemData] = []
## 首杀奖励物品
@export var first_kill_drops: Array[ItemData] = []
## 是否已经被击杀过（用于首杀判断）
var _has_been_killed: bool = false

## ========== 条件掉落 ==========
@export_group("Conditional Drops")
## 当玩家等级高于敌人时的掉落惩罚
@export var level_difference_penalty: bool = true
## 等级差惩罚阈值（等级差超过此值开始惩罚）
@export var penalty_threshold: int = 5
## 每级差的掉落率惩罚（百分比）
@export var penalty_per_level: float = 0.1

## ========== 组件引用 ==========
@export_group("Component References")
## 掉落生成器引用（可选，不设置则使用自动查找）
@export var loot_generator: LootGenerator
## 敌人的 StatsComponent（用于获取幸运值影响）
@export var stats_component: NodePath

## ========== 内部变量 ==========
var _stats: StatsComponent = null
var _killer: Node2D = null  # 记录击杀者


func _ready():
	# 获取组件引用
	if stats_component:
		_stats = get_node_or_null(stats_component)
	
	# 自动查找掉落生成器
	if not loot_generator:
		loot_generator = _find_loot_generator()
	
	# 连接死亡信号（假设敌人有一个死亡信号）
	var parent = get_parent()
	if parent.has_signal("died"):
		parent.died.connect(_on_enemy_died)
	elif parent.has_signal("health_depleted"):
		parent.health_depleted.connect(_on_enemy_died)


## ========== 核心方法 ==========

## 生成掉落物（主要入口）
func generate_and_spawn_loot(killer: Node2D = null, spawn_position: Vector2 = Vector2.ZERO):
	_killer = killer
	
	# 使用敌人位置如果没有指定位置
	if spawn_position == Vector2.ZERO:
		spawn_position = get_parent().global_position if get_parent() is Node2D else Vector2.ZERO
	
	# 获取击杀者的幸运值和等级
	var killer_luck = _get_killer_luck(killer)
	var killer_level = _get_killer_level(killer)
	
	# 生成掉落数据
	var loot_data = generate_loot_data(killer_level, killer_luck)
	
	# 发出信号
	loot_generated.emit(loot_data)
	
	# 生成掉落物到场景
	if loot_generator:
		var dropped_items = loot_generator.spawn_loot(loot_data, spawn_position)
		loot_spawned.emit(dropped_items)
	else:
		push_warning("EnemyLootComponent: 未找到 LootGenerator，无法生成掉落物")


## 仅生成掉落数据（不生成到场景）
func generate_loot_data(player_level: int = 1, luck_value: int = 0) -> Dictionary:
	var total_loot = {
		"items": [],
		"gold": 0
	}
	
	# 应用等级差惩罚
	var effective_drop_rate = drop_rate_multiplier
	if level_difference_penalty and player_level > enemy_level:
		var level_diff = player_level - enemy_level
		if level_diff > penalty_threshold:
			var penalty = (level_diff - penalty_threshold) * penalty_per_level
			effective_drop_rate *= max(0.1, 1.0 - penalty)  # 最低保留10%掉落率
	
	# 主掉落表
	if main_loot_table:
		var main_loot = main_loot_table.generate_loot(player_level, luck_value, enemy_tags)
		_merge_loot_data(total_loot, main_loot, effective_drop_rate)
	
	# 额外掉落表
	for bonus_table in bonus_loot_tables:
		if bonus_table and randf() < bonus_table_chance:
			var bonus_loot = bonus_table.generate_loot(player_level, luck_value, enemy_tags)
			_merge_loot_data(total_loot, bonus_loot, effective_drop_rate)
	
	# 保证掉落
	for item_data in guaranteed_drops:
		if item_data:
			var item = ItemInstance.create(item_data, 1)
			total_loot.items.append(item)
	
	# 首杀奖励
	if not _has_been_killed and not first_kill_drops.is_empty():
		for item_data in first_kill_drops:
			if item_data:
				var item = ItemInstance.create(item_data, 1)
				total_loot.items.append(item)
		_has_been_killed = true
	
	# 应用修正
	total_loot.gold = int(total_loot.gold * gold_multiplier)
	
	# 稀有度提升检测
	if rarity_boost_chance > 0:
		_apply_rarity_boost(total_loot.items, luck_value)
	
	# 应用数量倍数
	if drop_quantity_multiplier != 1.0:
		_apply_quantity_multiplier(total_loot.items)
	
	return total_loot


## ========== 辅助方法 ==========

## 合并掉落数据
func _merge_loot_data(target: Dictionary, source: Dictionary, drop_rate: float):
	# 金币直接累加
	target.gold += int(source.gold * drop_rate)
	
	# 物品按概率添加
	for item in source.items:
		if item is ItemInstance:
			if drop_rate >= 1.0 or randf() < drop_rate:
				target.items.append(item)


## 应用稀有度提升
func _apply_rarity_boost(items: Array, luck_value: int):
	for item in items:
		if not item is ItemInstance:
			continue
		
		# 计算提升概率（幸运值越高概率越高）
		var boost_chance = rarity_boost_chance
		if luck_value > 0:
			boost_chance += luck_value * 0.001  # 每点幸运 +0.1%
		
		if randf() < boost_chance:
			var current_rarity = item.item_data.rarity
			if current_rarity < ItemData.Rarity.MYTHIC:
				# 创建新的物品数据副本并提升稀有度
				# 注意：这里简化处理，实际应该创建新的 ItemData
				push_warning("稀有度提升需要创建新的 ItemData 副本")


## 应用数量倍数
func _apply_quantity_multiplier(items: Array):
	for item in items:
		if item is ItemInstance and drop_quantity_multiplier > 1.0:
			var bonus = int((item.stack_count * drop_quantity_multiplier) - item.stack_count)
			if bonus > 0:
				item.stack_count = min(item.stack_count + bonus, item.item_data.max_stack)


## 获取击杀者幸运值
func _get_killer_luck(killer: Node) -> int:
	if not killer:
		return 0
	
	# 尝试获取玩家的 StatsComponent
	var killer_stats = killer.get_node_or_null("StatsComponent")
	if killer_stats and killer_stats is StatsComponent:
		return int(killer_stats.get_stat(StatModifier.StatType.LUCK))
	
	return 0


## 获取击杀者等级
func _get_killer_level(killer: Node) -> int:
	if not killer:
		return 1
	
	# 尝试获取等级（不同游戏可能有不同的获取方式）
	if killer.has_method("get_level"):
		return killer.get_level()
	
	var killer_stats = killer.get_node_or_null("StatsComponent")
	if killer_stats and "level" in killer_stats:
		return killer_stats.level
	
	return 1


## 查找掉落生成器
func _find_loot_generator() -> LootGenerator:
	# 在场景树中查找 LootGenerator
	var root = get_tree().root
	for child in root.get_children():
		var generator = _find_node_recursive(child, "LootGenerator")
		if generator and generator is LootGenerator:
			return generator
	
	return null


## 递归查找节点
func _find_node_recursive(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, node_name)
		if result:
			return result
	
	return null


## ========== 信号处理 ==========

func _on_enemy_died():
	# 在敌人死亡时自动生成掉落
	generate_and_spawn_loot(_killer)


## ========== 公共接口 ==========

## 手动触发掉落（用于特殊情况）
func trigger_drop(killer: Node2D = null):
	generate_and_spawn_loot(killer)


## 添加额外掉落表
func add_bonus_loot_table(table: LootTable):
	if table and table not in bonus_loot_tables:
		bonus_loot_tables.append(table)


## 移除额外掉落表
func remove_bonus_loot_table(table: LootTable):
	bonus_loot_tables.erase(table)


## 设置精英/Boss状态（可能影响掉落）
func set_elite_status(elite: bool):
	is_elite = elite
	if elite:
		drop_rate_multiplier *= 1.5
		gold_multiplier *= 2.0


func set_boss_status(boss: bool):
	is_boss = boss
	if boss:
		drop_rate_multiplier *= 2.0
		gold_multiplier *= 5.0
		rarity_boost_chance += 0.2


## 重置首杀状态（用于测试）
func reset_first_kill():
	_has_been_killed = false


## 预览掉落（用于调试）
func preview_loot(player_level: int = 1, luck_value: int = 0, sample_count: int = 10) -> Dictionary:
	var preview = {
		"average_gold": 0.0,
		"item_counts": {},  # {item_id: count}
		"total_value": 0.0
	}
	
	for i in range(sample_count):
		var loot = generate_loot_data(player_level, luck_value)
		preview.average_gold += loot.gold
		
		for item in loot.items:
			if item is ItemInstance:
				var item_id = item.item_data.id
				if not preview.item_counts.has(item_id):
					preview.item_counts[item_id] = 0
				preview.item_counts[item_id] += item.stack_count
				preview.total_value += item.get_total_value()
	
	preview.average_gold /= sample_count
	preview.total_value = (preview.total_value + preview.average_gold) / sample_count
	
	return preview