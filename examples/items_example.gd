# res://examples/items_example.gd
extends Node2D
## 物品系统使用示例
##
## 展示如何创建、使用和管理物品实例

## ========== 示例场景 ==========

func _ready():
	print("========== 物品系统示例 ==========\n")
	
	# 示例 1: 创建武器实例
	example_create_weapon()
	
	# 示例 2: 创建消耗品实例
	example_create_consumable()
	
	# 示例 3: 物品堆叠
	example_item_stacking()
	
	# 示例 4: 装备物品
	example_equip_item()
	
	# 示例 5: 使用消耗品
	example_use_consumable()
	
	# 示例 6: 序列化与反序列化
	example_serialization()
	
	# 额外示例: 随机属性装备
	example_random_equipment()
	
	# 示例 7: 装备耐久度管理
	example_durability_management()
	
	# 示例 8: 使用增益药水
	example_use_buff_potion()
	
	# 示例 9: 装备等级需求
	example_equip_requirement()
	
	# 示例 10: 任务物品特性
	example_quest_item()
	
	# 示例 11: 物品标签系统
	example_item_tags()


## ========== 示例 1: 创建武器实例 ==========
func example_create_weapon():
	print("========== 示例 1: 创建武器实例 ==========")
	
	# 加载武器数据
	var sword_data = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	
	if sword_data:
		# 创建物品实例
		var sword = ItemInstance.create(sword_data, 1)
		
		print("物品名称: ", sword.item_data.item_name)
		print("物品ID: ", sword.item_data.id)
		print("稀有度: ", sword.item_data.get_rarity_name())
		print("稀有度颜色: ", sword.item_data.get_rarity_color())
		print("伤害: %.0f-%.0f" % [sword_data.min_physical_damage, sword_data.max_physical_damage])
		print("重量: ", sword.get_total_weight())
		print("售价: ", sword.get_sell_price(), " 金币")
		print("实例ID: ", sword.instance_id)
		print()


## ========== 示例 2: 创建消耗品实例 ==========
func example_create_consumable():
	print("========== 示例 2: 创建消耗品实例 ==========")
	
	# 加载药水数据
	var potion_data = load("res://data/items/consumables/health_potion.tres") as ConsumableData
	
	if potion_data:
		# 创建一组药水 (堆叠10个)
		var potions = ItemInstance.create(potion_data, 10)
		
		print("物品名称: ", potions.item_data.item_name)
		print("堆叠数量: ", potions.stack_count)
		print("效果: ", potion_data.get_effect_description())
		print("总重量: ", potions.get_total_weight())
		print("总价值: ", potions.get_total_value(), " 金币")
		print()


## ========== 示例 3: 物品堆叠 ==========
func example_item_stacking():
	print("========== 示例 3: 物品堆叠 ==========")
	
	var potion_data = load("res://data/items/consumables/health_potion.tres") as ConsumableData
	
	if potion_data:
		# 创建两组药水
		var potions1 = ItemInstance.create(potion_data, 30)
		var potions2 = ItemInstance.create(potion_data, 50)
		
		print("药水组1数量: ", potions1.stack_count)
		print("药水组2数量: ", potions2.stack_count)
		
		# 检查是否可以堆叠
		if potions1.can_stack_with(potions2):
			print("可以堆叠!")
			
			# 尝试堆叠
			var stacked_amount = potions1.try_stack(potions2)
			print("堆叠了 ", stacked_amount, " 个")
			print("药水组1数量: ", potions1.stack_count)
			print("药水组2数量: ", potions2.stack_count)
		
		# 分割堆叠
		print("\n分割堆叠...")
		var split_potions = potions1.split_stack(10)
		if split_potions:
			print("原堆叠数量: ", potions1.stack_count)
			print("新堆叠数量: ", split_potions.stack_count)
		
		print()


## ========== 示例 4: 装备物品 ==========
func example_equip_item():
	print("========== 示例 4: 装备物品 ==========")
	
	# 假设我们有一个玩家角色的 StatsComponent
	var player_stats = StatsComponent.new()
	player_stats.base_stats = load("res://data/player_base_stats.tres")
	add_child(player_stats)
	
	# 加载装备
	var sword_data = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	if sword_data:
		var sword = ItemInstance.create(sword_data, 1)
		
		print("装备前力量: ", player_stats.get_stat(StatModifier.StatType.STRENGTH))
		print("装备前物理攻击: ", player_stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE))
		
		# 装备武器 (应用属性修正器)
		equip_weapon(player_stats, sword)
		
		print("装备后力量: ", player_stats.get_stat(StatModifier.StatType.STRENGTH))
		print("装备后物理攻击: ", player_stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE))
		print()


## 装备武器的辅助函数
func equip_weapon(stats: StatsComponent, weapon: ItemInstance):
	if not weapon.item_data is WeaponData:
		print("不是武器!")
		return
	
	var weapon_data = weapon.item_data as WeaponData
	
	# 检查等级需求
	var player_level = stats.get_stat(StatModifier.StatType.LEVEL)
	if not weapon_data.can_equip(player_level):
		print("等级不足! 需要等级: ", weapon_data.required_level)
		return
	
	# 应用所有属性修正器
	for mod in weapon.get_all_modifiers():
		stats.add_modifier(mod)
	
	# 如果装备绑定,标记为已绑定
	if weapon_data.bind_on_equip:
		weapon.is_bound = true
	
	print("装备成功: ", weapon.item_data.item_name)


## ========== 示例 5: 使用消耗品 ==========
func example_use_consumable():
	print("========== 示例 5: 使用消耗品 ==========")
	
	# 创建角色
	var player_stats = StatsComponent.new()
	player_stats.base_stats = load("res://data/player_base_stats.tres")
	add_child(player_stats)
	
	# 模拟受伤
	player_stats.current_health = 50.0
	print("当前生命: %.0f / %.0f" % [player_stats.current_health, player_stats.get_stat(StatModifier.StatType.MAX_HEALTH)])
	
	# 使用药水
	var potion_data = load("res://data/items/consumables/health_potion.tres") as ConsumableData
	if potion_data:
		var potion = ItemInstance.create(potion_data, 1)
		
		print("使用: ", potion.item_data.item_name)
		use_healing_potion(player_stats, potion)
		
		print("使用后生命: %.0f / %.0f" % [player_stats.current_health, player_stats.get_stat(StatModifier.StatType.MAX_HEALTH)])
		print()


## 使用治疗药水的辅助函数
func use_healing_potion(stats: StatsComponent, potion: ItemInstance):
	if not potion.item_data is ConsumableData:
		print("不是消耗品!")
		return
	
	var consumable = potion.item_data as ConsumableData
	
	match consumable.effect_type:
		ConsumableData.EffectType.INSTANT_HEAL:
			stats.heal(consumable.effect_value)
			print("恢复了 %.0f 点生命值" % consumable.effect_value)
		
		ConsumableData.EffectType.INSTANT_MANA:
			stats.restore_mana(consumable.effect_value)
			print("恢复了 %.0f 点魔力值" % consumable.effect_value)
		
		ConsumableData.EffectType.BUFF:
			# 应用临时增益
			for mod in consumable.temp_modifiers:
				mod.set_duration(consumable.effect_duration)
				stats.add_modifier(mod)
			print("获得增益效果 %.1f 秒" % consumable.effect_duration)
	
	# 减少堆叠
	potion.stack_count -= 1


## ========== 示例 6: 序列化与反序列化 ==========
func example_serialization():
	print("========== 示例 6: 序列化与反序列化 ==========")
	
	# 创建物品
	var sword_data = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	if sword_data:
		var sword = ItemInstance.create(sword_data, 1)
		sword.current_durability = 75  # 设置耐久度
		
		# 序列化为字典
		var save_data = sword.to_dict()
		print("序列化数据: ", save_data)
		
		# 创建物品数据库 (实际项目中应该是全局的)
		var item_database = {
			"iron_sword": sword_data
		}
		
		# 从字典反序列化
		var loaded_sword = ItemInstance.from_dict(save_data, item_database)
		if loaded_sword:
			print("\n反序列化成功!")
			print("物品名称: ", loaded_sword.item_data.item_name)
			print("实例ID: ", loaded_sword.instance_id)
			print("耐久度: ", loaded_sword.current_durability)
		
		print()


## ========== 额外示例: 随机属性装备 ==========
func example_random_equipment():
	print("========== 额外示例: 随机属性装备 ==========")
	
	var sword_data = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	if sword_data:
		# 创建带3个随机属性的装备
		var magic_sword = ItemInstance.create_random_equipment(sword_data, 3)
		
		print("物品名称: ", magic_sword.item_data.item_name)
		print("随机属性数量: ", magic_sword.random_modifiers.size())
		
		print("\n随机属性:")
		for mod in magic_sword.random_modifiers:
			print("  ", mod.get_description())
		
		print()


## ========== 示例 7: 装备耐久度管理 ==========
func example_durability_management():
	print("========== 示例 7: 装备耐久度管理 ==========")
	
	var sword_data = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	if sword_data and sword_data.has_durability:
		var sword = ItemInstance.create(sword_data, 1)
		
		print("初始耐久度: ", sword.current_durability, " / ", sword_data.max_durability)
		
		# 减少耐久度
		sword.reduce_durability(30)
		print("减少30点耐久后: ", sword.current_durability)
		
		# 检查是否损坏
		print("装备是否损坏: ", sword.is_broken())
		
		# 完全修理
		sword.repair()
		print("完全修理后耐久度: ", sword.current_durability)
		
		# 再次减少耐久度直到损坏
		sword.reduce_durability(sword_data.max_durability)
		print("耐久度耗尽后: ", sword.current_durability)
		print("装备是否损坏: ", sword.is_broken())
		
		print()


## ========== 示例 8: 使用增益药水 ==========
func example_use_buff_potion():
	print("========== 示例 8: 使用增益药水 ==========")
	
	# 创建角色
	var player_stats = StatsComponent.new()
	player_stats.base_stats = load("res://data/player_base_stats.tres")
	add_child(player_stats)
	
	# 创建一个临时的力量药水数据
	var strength_potion_data = ConsumableData.new()
	strength_potion_data.id = "temp_strength_potion"
	strength_potion_data.item_name = "力量药水"
	strength_potion_data.effect_type = ConsumableData.EffectType.BUFF
	strength_potion_data.effect_duration = 15.0 # 持续15秒
	
	var strength_mod = StatModifier.new()
	strength_mod.stat_type = StatModifier.StatType.STRENGTH
	strength_mod.modifier_type = StatModifier.ModifierType.FLAT
	strength_mod.value = 5
	strength_potion_data.temp_modifiers.append(strength_mod)
	
	var potion = ItemInstance.create(strength_potion_data, 1)
	
	print("使用前力量: ", player_stats.get_stat(StatModifier.StatType.STRENGTH))
	
	# 使用药水
	print("使用: ", potion.item_data.item_name)
	use_consumable_item(player_stats, potion)
	
	print("使用后力量: ", player_stats.get_stat(StatModifier.StatType.STRENGTH))
	print("增益效果将持续 %.1f 秒" % strength_potion_data.effect_duration)
	
	# 可以在这里添加一个 Timer 来模拟增益效果的消失
	
	print()


## ========== 示例 9: 装备等级需求 ==========
func example_equip_requirement():
	print("========== 示例 9: 装备等级需求 ==========")
	
	# 创建一个1级角色
	var player_stats = StatsComponent.new()
	player_stats.base_stats = load("res://data/player_base_stats.tres") # 假设基础等级为1
	add_child(player_stats)
	
	# 创建一个需要10级的武器
	var high_level_sword_data = WeaponData.new()
	high_level_sword_data.item_name = "高级长剑"
	high_level_sword_data.required_level = 10
	
	var sword = ItemInstance.create(high_level_sword_data, 1)
	
	print("玩家等级: ", player_stats.get_stat(StatModifier.StatType.LEVEL))
	print("武器需求等级: ", high_level_sword_data.required_level)
	
	# 尝试装备
	equip_weapon(player_stats, sword)
	
	print()


## ========== 示例 10: 任务物品特性 ==========
func example_quest_item():
	print("========== 示例 10: 任务物品特性 ==========")
	
	# 创建一个任务物品数据
	var quest_item_data = ItemData.new()
	quest_item_data.id = "quest_letter"
	quest_item_data.item_name = "一封密信"
	quest_item_data.item_type = ItemData.ItemType.QUEST
	quest_item_data.description = "一封来自神秘人的信件，似乎很重要。"
	quest_item_data.can_sell = false
	quest_item_data.can_drop = false
	quest_item_data.can_trade = false
	
	var quest_item = ItemInstance.create(quest_item_data, 1)
	
	print("物品名称: ", quest_item.item_data.item_name)
	print("物品类型: ", ItemData.ItemType.keys()[quest_item.item_data.item_type])
	print("是否可出售: ", quest_item.item_data.can_sell)
	print("是否可丢弃: ", quest_item.item_data.can_drop)
	print("是否可交易: ", quest_item.item_data.can_trade)
	
	print()


## ========== 示例 11: 物品标签系统 ==========
func example_item_tags():
	print("========== 示例 11: 物品标签系统 ==========")
	
	var sword_data = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	if sword_data:
		print("初始标签: ", sword_data.tags)
		
		# 添加标签
		sword_data.add_tag("weapon")
		sword_data.add_tag("one-handed")
		print("添加标签后: ", sword_data.tags)
		
		# 检查标签
		print("是否包含 'weapon' 标签: ", sword_data.has_tag("weapon"))
		print("是否包含 'magic' 标签: ", sword_data.has_tag("magic"))
		
		# 移除标签
		sword_data.remove_tag("one-handed")
		print("移除标签后: ", sword_data.tags)
		
		# 清理，恢复原状
		sword_data.remove_tag("weapon")
		
		print()


## 通用的消耗品使用函数
func use_consumable_item(stats: StatsComponent, consumable_instance: ItemInstance):
	if not consumable_instance or not consumable_instance.item_data is ConsumableData:
		print("不是有效的消耗品实例!")
		return
	
	var consumable = consumable_instance.item_data as ConsumableData
	
	match consumable.effect_type:
		ConsumableData.EffectType.INSTANT_HEAL:
			stats.heal(consumable.effect_value)
			print("恢复了 %.0f 点生命值" % consumable.effect_value)
		
		ConsumableData.EffectType.INSTANT_MANA:
			stats.restore_mana(consumable.effect_value)
			print("恢复了 %.0f 点魔力值" % consumable.effect_value)
		
		ConsumableData.EffectType.BUFF:
			# 应用临时增益
			for mod in consumable.temp_modifiers:
				var temp_mod = mod.duplicate() # 复制以避免修改源资源
				temp_mod.set_duration(consumable.effect_duration)
				stats.add_modifier(temp_mod)
			print("获得增益效果 %.1f 秒" % consumable.effect_duration)
		
		_:
			print("未处理的消耗品效果类型: ", consumable.get_effect_type_name())

	# 减少堆叠
	consumable_instance.stack_count -= 1
