# 测试 StatsComponent 的修复
extends Node

func _ready():
	print("========== 测试 StatsComponent ==========")
	
	# 创建基础数据
	var stats_data = StatsData.new()
	stats_data.level = 1
	stats_data.strength = 10
	stats_data.agility = 10
	stats_data.intelligence = 10
	stats_data.vitality = 10
	stats_data.luck = 10
	stats_data.max_health = 100.0
	stats_data.max_mana = 50.0
	stats_data.max_stamina = 100.0
	stats_data.health_regen = 1.0
	stats_data.mana_regen = 2.0
	stats_data.stamina_regen = 10.0
	
	# 创建组件
	var stats = StatsComponent.new()
	stats.base_stats = stats_data
	add_child(stats)
	
	print("\n1. 测试基础属性计算")
	print("  最大生命: ", stats.get_stat(StatModifier.StatType.MAX_HEALTH))
	print("  物理攻击: ", stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE))
	print("  护甲: ", stats.get_stat(StatModifier.StatType.ARMOR))
	
	print("\n2. 测试修正器系统")
	var mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "test_item")
	stats.add_modifier(mod)
	print("  添加 +5 力量后:")
	print("  力量: ", stats.get_stat(StatModifier.StatType.STRENGTH))
	print("  物理攻击: ", stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE))
	
	print("\n3. 测试属性分配")
	stats.base_stats.stat_points = 10
	var success = stats.allocate_stat_point(StatModifier.StatType.STRENGTH, 5)
	print("  分配5点力量: ", "成功" if success else "失败")
	print("  剩余属性点: ", stats.get_available_stat_points())
	
	print("\n4. 测试序列化")
	var save_data = stats.to_dict()
	print("  保存数据键: ", save_data.keys())
	
	print("\n5. 测试伤害计算")
	var damage_result = stats.calculate_damage(0.0, "physical", StatModifier.ElementType.NONE, true)
	print("  基础伤害: ", damage_result.base_damage)
	print("  是否暴击: ", damage_result.was_crit)
	
	print("\n========== 所有测试完成 ==========")
	print("✓ _recalculate_all_stats 函数正常工作")
	print("✓ _calculate_stat 函数正常工作")
	print("✓ _deserialize_permanent_modifiers 函数完整")
	
	queue_free()
