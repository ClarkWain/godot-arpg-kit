# res://examples/loot_system_example.gd
extends Node2D
## 掉落系统使用示例
##
## 演示如何使用掉落表、掉落生成器等组件

## 节点引用
@onready var loot_generator: LootGenerator = $LootGenerator


func _ready():
	print("=== 掉落系统示例 ===\n")
	
	# 示例1: 创建简单掉落表
	example_1_simple_loot_table()
	
	# 示例2: 创建复杂掉落表
	example_2_complex_loot_table()
	
	# 示例3: 使用掉落生成器
	example_3_loot_generator()
	
	# 示例4: 敌人掉落组件
	example_4_enemy_loot()
	
	# 示例5: 条件掉落
	example_5_conditional_drops()
	
	# 示例6: 幸运值影响
	example_6_luck_influence()


## 示例1: 创建简单掉落表
func example_1_simple_loot_table():
	print("--- 示例1: 简单掉落表 ---")
	
	# 创建掉落表
	var loot_table = LootTable.new()
	loot_table.table_name = "史莱姆掉落表"
	loot_table.drop_mode = LootTable.DropMode.ALL
	loot_table.drops_gold = true
	loot_table.min_gold = 5
	loot_table.max_gold = 15
	
	# 创建掉落条目 - 史莱姆凝胶
	var slime_gel_entry = LootEntry.new()
	# slime_gel_entry.item_data = load("res://data/items/materials/slime_gel.tres")
	slime_gel_entry.drop_chance = 0.8  # 80% 概率掉落
	slime_gel_entry.fixed_quantity = 1
	
	# 创建掉落条目 - 生命药水
	var potion_entry = LootEntry.new()
	# potion_entry.item_data = load("res://data/items/consumables/health_potion.tres")
	potion_entry.drop_chance = 0.3  # 30% 概率掉落
	potion_entry.fixed_quantity = 1
	
	loot_table.entries = [slime_gel_entry, potion_entry]
	
	# 生成掉落
	var loot_data = loot_table.generate_loot(1, 0)
	print("掉落金币: %d" % loot_data.gold)
	print("掉落物品数: %d" % loot_data.items.size())
	print()


## 示例2: 创建复杂掉落表
func example_2_complex_loot_table():
	print("--- 示例2: 复杂掉落表（Boss掉落）---")
	
	var boss_loot = LootTable.new()
	boss_loot.table_name = "Boss掉落表"
	boss_loot.drop_mode = LootTable.DropMode.PICK_MULTIPLE
	boss_loot.min_picks = 2
	boss_loot.max_picks = 5
	boss_loot.min_gold = 100
	boss_loot.max_gold = 500
	
	# 传说武器（低概率）
	var legendary_weapon = LootEntry.new()
	# legendary_weapon.item_data = load("res://data/items/weapons/legendary_sword.tres")
	legendary_weapon.drop_chance = 0.05  # 5% 概率
	legendary_weapon.weight = 10
	legendary_weapon.unique = true
	legendary_weapon.luck_affects_chance = true
	
	# 史诗装备（中等概率）
	var epic_armor = LootEntry.new()
	# epic_armor.item_data = load("res://data/items/armors/epic_chest.tres")
	epic_armor.drop_chance = 0.2  # 20% 概率
	epic_armor.weight = 50
	
	# 稀有材料（较高概率）
	var rare_material = LootEntry.new()
	# rare_material.item_data = load("res://data/items/materials/dragon_scale.tres")
	rare_material.drop_chance = 0.6  # 60% 概率
	rare_material.weight = 100
	rare_material.quantity_mode = LootEntry.QuantityMode.RANDOM
	rare_material.min_quantity = 1
	rare_material.max_quantity = 3
	
	boss_loot.entries = [legendary_weapon, epic_armor, rare_material]
	
	# 生成掉落（幸运值100）
	var loot_data = boss_loot.generate_loot(10, 100)
	print("Boss掉落金币: %d" % loot_data.gold)
	print("Boss掉落物品数: %d" % loot_data.items.size())
	print()


## 示例3: 使用掉落生成器
func example_3_loot_generator():
	print("--- 示例3: 掉落生成器 ---")
	
	if not loot_generator:
		print("未找到 LootGenerator 节点")
		return
	
	# 创建简单掉落数据
	var loot_data = {
		"items": [],
		"gold": 50
	}
	
	# 添加一些物品
	# var sword = ItemInstance.create(load("res://data/items/weapons/iron_sword.tres"), 1)
	# loot_data.items.append(sword)
	
	# 生成掉落物到场景
	var spawn_pos = Vector2(400, 300)
	var dropped_items = loot_generator.spawn_loot(loot_data, spawn_pos)
	
	print("已生成 %d 个掉落物" % dropped_items.size())
	print()


## 示例4: 敌人掉落组件使用
func example_4_enemy_loot():
	print("--- 示例4: 敌人掉落组件 ---")
	
	# 创建敌人节点
	var enemy = Node2D.new()
	enemy.name = "Goblin"
	add_child(enemy)
	
	# 添加掉落组件
	var loot_comp = EnemyLootComponent.new()
	enemy.add_child(loot_comp)
	
	# 配置掉落
	loot_comp.enemy_level = 5
	loot_comp.enemy_tags = ["goblin", "humanoid"]
	# loot_comp.main_loot_table = load("res://data/loot_tables/goblin_loot.tres")
	loot_comp.loot_generator = loot_generator
	
	# 生成掉落
	var player_level = 5
	var player_luck = 20
	var loot_data = loot_comp.generate_loot_data(player_level, player_luck)
	
	print("哥布林掉落:")
	print("- 金币: %d" % loot_data.gold)
	print("- 物品数: %d" % loot_data.items.size())
	print()
	
	enemy.queue_free()


## 示例5: 条件掉落
func example_5_conditional_drops():
	print("--- 示例5: 条件掉落 ---")
	
	var conditional_table = LootTable.new()
	conditional_table.table_name = "条件掉落示例"
	
	# 低等级玩家掉落
	var beginner_item = LootEntry.new()
	# beginner_item.item_data = load("res://data/items/weapons/wooden_sword.tres")
	beginner_item.min_player_level = 1
	beginner_item.max_player_level = 10
	beginner_item.drop_chance = 1.0
	
	# 高等级玩家掉落
	var advanced_item = LootEntry.new()
	# advanced_item.item_data = load("res://data/items/weapons/steel_sword.tres")
	advanced_item.min_player_level = 10
	advanced_item.drop_chance = 1.0
	
	# 需要特定标签
	var special_item = LootEntry.new()
	# special_item.item_data = load("res://data/items/quest/dragon_egg.tres")
	special_item.required_tags = ["dragon_slayer_quest"]
	special_item.drop_chance = 1.0
	
	conditional_table.entries = [beginner_item, advanced_item, special_item]
	
	# 测试不同等级
	print("玩家等级5的掉落:")
	var loot_lv5 = conditional_table.generate_loot(5, 0, [])
	print("- 物品数: %d" % loot_lv5.items.size())
	
	print("玩家等级15的掉落:")
	var loot_lv15 = conditional_table.generate_loot(15, 0, [])
	print("- 物品数: %d" % loot_lv15.items.size())
	
	print("带有dragon_slayer_quest标签:")
	var loot_quest = conditional_table.generate_loot(10, 0, ["dragon_slayer_quest"])
	print("- 物品数: %d" % loot_quest.items.size())
	print()


## 示例6: 幸运值影响
func example_6_luck_influence():
	print("--- 示例6: 幸运值影响 ---")
	
	var luck_table = LootTable.new()
	luck_table.table_name = "幸运值测试"
	luck_table.min_gold = 10
	luck_table.max_gold = 20
	luck_table.luck_affects_gold = true
	
	# 创建一个受幸运影响的物品
	var lucky_item = LootEntry.new()
	# lucky_item.item_data = load("res://data/items/materials/rare_gem.tres")
	lucky_item.drop_chance = 0.1  # 基础10%概率
	lucky_item.luck_affects_chance = true
	lucky_item.luck_chance_scaling = 0.005  # 每点幸运 +0.5%
	
	luck_table.entries = [lucky_item]
	
	# 测试不同幸运值
	print("幸运值 0:")
	var loot_luck0 = luck_table.generate_loot(10, 0)
	print("- 金币: %d" % loot_luck0.gold)
	
	print("幸运值 50:")
	var loot_luck50 = luck_table.generate_loot(10, 50)
	print("- 金币: %d" % loot_luck50.gold)
	
	print("幸运值 100:")
	var loot_luck100 = luck_table.generate_loot(10, 100)
	print("- 金币: %d" % loot_luck100.gold)
	
	# 测试掉落概率变化
	print("\n幸运值对掉落概率的影响 (1000次测试):")
	var drop_count_0 = 0
	var drop_count_100 = 0
	
	for i in range(1000):
		if lucky_item.roll_drop(0):
			drop_count_0 += 1
		if lucky_item.roll_drop(100):
			drop_count_100 += 1
	
	print("- 幸运0: %.1f%% 掉落率" % (drop_count_0 / 10.0))
	print("- 幸运100: %.1f%% 掉落率" % (drop_count_100 / 10.0))
	print()


## 示例7: 掉落预览（用于UI显示可能掉落的物品）
func show_loot_preview():
	print("--- 示例7: 掉落预览 ---")
	
	# 假设有一个掉落表
	var loot_table = LootTable.new()
	# loot_table = load("res://data/loot_tables/boss_loot.tres")
	
	# 获取所有可能掉落的物品
	var possible_items = loot_table.get_all_possible_items()
	
	print("这个Boss可能掉落以下物品:")
	for item_data in possible_items:
		if item_data:
			print("- %s (%s)" % [item_data.item_name, item_data.get_rarity_name()])
	
	# 计算平均掉落价值
	var avg_value = loot_table.get_average_value(10, 50)
	print("\n平均掉落价值: %d 金币" % int(avg_value))
	print()