# 生命/魔力/耐力回复配置示例
extends Node

## 展示如何灵活配置回复速率和其他参数
##
## 性能优化说明:
## - 回复系统使用每秒计时器触发,而非每帧计算,大幅降低CPU开销
## - 每秒只调用一次 get_stat() 和 heal()/restore_mana() 等函数
## - 能量护盾保持每帧检查以实现平滑的延迟回复效果

func _ready():
	# 示例1: 创建一个快速回复的角色
	var fast_regen_stats = StatsData.new()
	fast_regen_stats.max_health = 100.0
	fast_regen_stats.max_mana = 50.0
	fast_regen_stats.max_stamina = 100.0
	
	# 配置快速回复速率
	fast_regen_stats.health_regen = 5.0  # 每秒回复5点生命
	fast_regen_stats.mana_regen = 3.0    # 每秒回复3点魔力
	fast_regen_stats.stamina_regen = 20.0  # 每秒回复20点耐力
	
	# 示例2: 创建一个普通回复的角色
	var normal_regen_stats = StatsData.new()
	normal_regen_stats.max_health = 100.0
	normal_regen_stats.max_mana = 50.0
	normal_regen_stats.max_stamina = 100.0
	
	# 配置普通回复速率
	normal_regen_stats.health_regen = 1.0  # 每秒回复1点生命
	normal_regen_stats.mana_regen = 2.0    # 每秒回复2点魔力
	normal_regen_stats.stamina_regen = 10.0  # 每秒回复10点耐力
	
	# 示例3: 使用修正器动态改变回复速率
	var stats_component = StatsComponent.new()
	stats_component.base_stats = normal_regen_stats
	add_child(stats_component)
	
	# 添加一个临时的快速回复Buff (持续10秒)
	var regen_buff = StatModifier.create_flat(
		StatModifier.StatType.HEALTH_REGEN,
		5.0,  # 额外增加5点/秒生命回复
		"potion_of_regeneration"
	).set_duration(10.0).add_tag("buff")
	
	stats_component.add_modifier(regen_buff)
	print("应用回复药水后,生命回复速率: ", stats_component.get_stat(StatModifier.StatType.HEALTH_REGEN))
	
	# 示例4: 使用百分比修正器
	var percentage_buff = StatModifier.create_percent(
		StatModifier.StatType.MANA_REGEN,
		0.5,  # 增加50%魔力回复
		"meditation_skill"
	).add_tag("skill")
	
	stats_component.add_modifier(percentage_buff)
	print("施放冥想后,魔力回复速率: ", stats_component.get_stat(StatModifier.StatType.MANA_REGEN))
	
	# 示例5: 配置经验曲线
	var player_stats = StatsComponent.new()
	player_stats.base_stats = StatsData.new()
	
	# 调整经验曲线参数
	player_stats.exp_curve_multiplier = 1.8  # 更陡峭的曲线
	player_stats.exp_base_value = 150  # 更高的基础经验需求
	player_stats.stat_points_per_level = 3  # 每级获得3点属性点
	
	# 配置初始属性值(用于重置)
	player_stats.initial_strength = 5
	player_stats.initial_agility = 5
	player_stats.initial_intelligence = 5
	player_stats.initial_vitality = 5
	player_stats.initial_luck = 5
	
	add_child(player_stats)
	
	print("=== 配置完成 ===")
	print("快速回复角色 - 生命回复: ", fast_regen_stats.health_regen, "/秒")
	print("普通回复角色 - 生命回复: ", normal_regen_stats.health_regen, "/秒")
	print("经验曲线倍数: ", player_stats.exp_curve_multiplier)
	print("经验基础值: ", player_stats.exp_base_value)


## 示例: 创建不同类型的药水效果
func create_health_potion_effect(stats: StatsComponent, duration: float = 10.0) -> void:
	"""快速回复药水 - 10秒内每秒回复10点生命"""
	var potion_effect = StatModifier.create_flat(
		StatModifier.StatType.HEALTH_REGEN,
		10.0,
		"health_potion"
	).set_duration(duration).add_tag("potion").add_tag("buff")
	
	stats.add_modifier(potion_effect)


func create_mana_potion_effect(stats: StatsComponent, duration: float = 15.0) -> void:
	"""魔力回复药水 - 15秒内每秒回复5点魔力"""
	var potion_effect = StatModifier.create_flat(
		StatModifier.StatType.MANA_REGEN,
		5.0,
		"mana_potion"
	).set_duration(duration).add_tag("potion").add_tag("buff")
	
	stats.add_modifier(potion_effect)


func create_stamina_boost_effect(stats: StatsComponent, duration: float = 5.0) -> void:
	"""耐力冲刺药水 - 5秒内耐力回复速度翻倍"""
	var boost_effect = StatModifier.create_percent(
		StatModifier.StatType.STAMINA_REGEN,
		1.0,  # +100% = 翻倍
		"stamina_boost"
	).set_duration(duration).add_tag("potion").add_tag("buff")
	
	stats.add_modifier(boost_effect)


## 示例: 装备影响回复速率
func equip_regeneration_ring(stats: StatsComponent) -> void:
	"""回复之戒 - 永久增加所有回复速率"""
	var ring_health = StatModifier.create_flat(
		StatModifier.StatType.HEALTH_REGEN,
		2.0,
		"regeneration_ring"
	).add_tag("equipment")
	
	var ring_mana = StatModifier.create_flat(
		StatModifier.StatType.MANA_REGEN,
		1.0,
		"regeneration_ring"
	).add_tag("equipment")
	
	stats.add_modifier(ring_health)
	stats.add_modifier(ring_mana)


func unequip_regeneration_ring(stats: StatsComponent) -> void:
	"""卸下回复之戒"""
	stats.remove_modifiers_by_source("regeneration_ring")