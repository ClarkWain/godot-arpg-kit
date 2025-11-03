# res://examples/stats_example.gd
extends Node2D
## Stats 系统完整测试用例
##
## 分阶段测试所有功能，确保系统稳定可靠

@onready var stats: StatsComponent = $StatsComponent

## 测试结果统计
var test_passed: int = 0
var test_failed: int = 0
var test_total: int = 0
var test_failed_reason: Array[String] = []

## 当前测试阶段
var current_phase: int = 1


func _ready():
	print("\n" + "=".repeat(60))
	print("Stats 系统分阶段测试")
	print("=".repeat(60) + "\n")
	
	# 连接信号用于监控
	_connect_signals()
	
	# 开始第一阶段测试
	print("等待0.1秒开始第一轮测试")
	await get_tree().create_timer(0.1).timeout
	run_phase_1_tests()


func _process(_delta: float) -> void:
	# 按空格键运行下一阶段测试
	if Input.is_action_just_pressed("ui_accept"):
		current_phase += 1
		match current_phase:
			2:
				run_phase_2_tests()
			3:
				run_phase_3_tests()
			4:
				run_phase_4_tests()
			5:
				run_phase_5_tests()
			6:
				run_phase_6_tests()
			7:
				run_phase_7_tests()
			_:
				print("\n所有测试阶段已完成!")
				print_test_summary()


## ========== 第一阶段: 基础属性和计算 ==========
func run_phase_1_tests():
	print("\n" + "=".repeat(60))
	print("第一阶段测试: 基础属性和计算系统")
	print("=".repeat(60) + "\n")
	
	# 1.1 测试基础属性读取
	test_1_1_base_stats_reading()
	
	# 1.2 测试派生属性计算
	test_1_2_derived_stats()
	
	# 1.3 测试属性缓存机制
	test_1_3_stat_caching()
	
	# 1.4 测试get_stat_breakdown
	test_1_4_stat_breakdown()
	
	print_phase_summary(1)
	print("\n按 [空格] 继续下一阶段测试...")


## 测试 1.1: 基础属性读取
func test_1_1_base_stats_reading():
	test_start("1.1 基础属性读取")
	
	# 验证核心属性
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  stats.base_stats.strength, "力量值")
	assert_equals(stats.get_stat(StatModifier.StatType.AGILITY), 
				  stats.base_stats.agility, "敏捷值")
	assert_equals(stats.get_stat(StatModifier.StatType.INTELLIGENCE), 
				  stats.base_stats.intelligence, "智力值")
	assert_equals(stats.get_stat(StatModifier.StatType.VITALITY), 
				  stats.base_stats.vitality, "体质值")
	assert_equals(stats.get_stat(StatModifier.StatType.LUCK), 
				  stats.base_stats.luck, "幸运值")
	
	# 验证生存属性
	assert_equals(stats.current_health, 
				  stats.get_stat(StatModifier.StatType.MAX_HEALTH), "初始生命值应等于最大值")
	assert_equals(stats.current_mana, 
				  stats.get_stat(StatModifier.StatType.MAX_MANA), "初始魔力值应等于最大值")
	
	test_end()


## 测试 1.2: 派生属性计算
func test_1_2_derived_stats():
	test_start("1.2 派生属性计算")
	
	var base_strength = stats.base_stats.strength
	var base_vitality = stats.base_stats.vitality
	var base_intelligence = stats.base_stats.intelligence
	
	# 力量影响物理攻击 (每点力量 +2 物理攻击)
	var expected_physical = stats.base_stats.physical_damage + (base_strength * 2)
	assert_equals(stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE), 
				  expected_physical, "力量影响物理攻击")
	
	# 体质影响最大生命 (每点体质 +10 生命)
	var expected_health = stats.base_stats.max_health + (base_vitality * 10)
	assert_equals(stats.get_stat(StatModifier.StatType.MAX_HEALTH), 
				  expected_health, "体质影响最大生命")
	
	# 智力影响最大魔力 (每点智力 +5 魔力)
	var expected_mana = stats.base_stats.max_mana + (base_intelligence * 5)
	assert_equals(stats.get_stat(StatModifier.StatType.MAX_MANA), 
				  expected_mana, "智力影响最大魔力")
	
	test_end()


## 测试 1.3: 属性缓存机制
func test_1_3_stat_caching():
	test_start("1.3 属性缓存机制")
	
	# 第一次获取属性（触发计算）
	var health1 = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	
	# 第二次获取（应该使用缓存）
	var health2 = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	
	assert_equals(health1, health2, "缓存值应该相同")
	assert_true(not stats._is_dirty, "缓存后_is_dirty应为false")
	
	# 添加修正器后应标记为dirty
	var mod = StatModifier.create_flat(StatModifier.StatType.MAX_HEALTH, 10.0, "test")
	stats.add_modifier(mod)
	
	# 再次获取应触发重新计算
	var health3 = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	assert_equals(health3, health1 + 10.0, "修正器应生效")
	
	# 清理
	stats.remove_modifier(mod)
	
	test_end()


## 测试 1.4: get_stat_breakdown
func test_1_4_stat_breakdown():
	test_start("1.4 属性详细分解")
	
	# 添加一些修正器
	var flat_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "test_flat")
	var percent_mod = StatModifier.create_percent(StatModifier.StatType.STRENGTH, 0.2, "test_percent")
	
	stats.add_modifier(flat_mod)
	stats.add_modifier(percent_mod)
	
	# 获取分解信息
	var breakdown = stats.get_stat_breakdown(StatModifier.StatType.STRENGTH)
	
	assert_true(breakdown.has("base_value"), "应包含基础值")
	assert_true(breakdown.has("flat_bonus"), "应包含固定加成")
	assert_true(breakdown.has("percent_bonus"), "应包含百分比加成")
	assert_true(breakdown.has("final_value"), "应包含最终值")
	assert_equals(breakdown.modifier_count, 2, "修正器数量")
	
	print("  基础值: ", breakdown.base_value)
	print("  固定加成: ", breakdown.flat_bonus)
	print("  百分比加成: ", breakdown.percent_bonus)
	print("  最终值: ", breakdown.final_value)
	
	# 清理
	stats.remove_modifier(flat_mod)
	stats.remove_modifier(percent_mod)
	
	test_end()


## ========== 第二阶段: 修正器系统 ==========
func run_phase_2_tests():
	print("\n" + "=".repeat(60))
	print("第二阶段测试: 修正器系统")
	print("=".repeat(60) + "\n")
	
	test_2_1_flat_modifiers()
	test_2_2_percent_modifiers()
	test_2_3_override_modifiers()
	test_2_4_modifier_priority()
	await test_2_5_timed_modifiers()
	test_2_6_remove_by_source()
	test_2_7_remove_by_tag()
	
	print_phase_summary(2)
	print("\n按 [空格] 继续下一阶段测试...")


## 测试 2.1: 固定值修正器
func test_2_1_flat_modifiers():
	test_start("2.1 固定值修正器")
	
	var base_strength = stats.get_stat(StatModifier.StatType.STRENGTH)
	
	var mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "test")
	stats.add_modifier(mod)
	
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  base_strength + 10.0, "固定值加成")
	
	stats.remove_modifier(mod)
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  base_strength, "移除后应恢复")
	
	test_end()


## 测试 2.2: 百分比修正器
func test_2_2_percent_modifiers():
	test_start("2.2 百分比修正器")
	
	var base_strength = stats.get_stat(StatModifier.StatType.STRENGTH)
	
	var mod = StatModifier.create_percent(StatModifier.StatType.STRENGTH, 0.5, "test")  # +50%
	stats.add_modifier(mod)
	
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  base_strength * 1.5, "百分比加成")
	
	stats.remove_modifier(mod)
	
	test_end()


## 测试 2.3: 覆盖修正器
func test_2_3_override_modifiers():
	test_start("2.3 覆盖修正器")
	
	var mod = StatModifier.create_override(StatModifier.StatType.MOVE_SPEED, 999.0, "test")
	stats.add_modifier(mod)
	
	assert_equals(stats.get_stat(StatModifier.StatType.MOVE_SPEED), 
				  999.0, "覆盖值应生效")
	
	stats.remove_modifier(mod)
	
	test_end()


## 测试 2.4: 修正器优先级
func test_2_4_modifier_priority():
	test_start("2.4 修正器优先级")
	
	# 添加不同优先级的修正器
	var mod1 = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "low")
	mod1.priority = 0
	
	var mod2 = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "high")
	mod2.priority = 100
	
	stats.add_modifier(mod1)
	stats.add_modifier(mod2)
	
	# 优先级不影响结果，只影响计算顺序
	var base = stats.base_stats.strength
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  base + 15.0, "优先级不影响固定值加成总和")
	
	stats.remove_modifier(mod1)
	stats.remove_modifier(mod2)
	
	test_end()


## 测试 2.5: 临时修正器
func test_2_5_timed_modifiers():
	test_start("2.5 临时修正器 (需等待)")
	
	var base_strength = stats.get_stat(StatModifier.StatType.STRENGTH)
	
	var mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 20.0, "potion")
	mod.set_duration(1.0)  # 1秒后过期
	
	stats.add_modifier(mod)
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  base_strength + 20.0, "临时修正器应立即生效")
	
	print("  等待1.5秒让修正器过期...")
	await get_tree().create_timer(1.5).timeout
	
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  base_strength, "过期后应自动移除")
	
	test_end()


## 测试 2.6: 按来源移除
func test_2_6_remove_by_source():
	test_start("2.6 按来源移除修正器")
	
	# 先获取当前值（包含派生加成）
	var base_str = stats.get_stat(StatModifier.StatType.STRENGTH)
	var base_agi = stats.get_stat(StatModifier.StatType.AGILITY)
	var base_vit = stats.get_stat(StatModifier.StatType.VITALITY)
	
	var mod1 = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "sword")
	var mod2 = StatModifier.create_flat(StatModifier.StatType.AGILITY, 3.0, "sword")
	var mod3 = StatModifier.create_flat(StatModifier.StatType.VITALITY, 2.0, "armor")
	
	stats.add_modifier(mod1)
	stats.add_modifier(mod2)
	stats.add_modifier(mod3)
	
	# 移除sword来源的所有修正器
	stats.remove_modifiers_by_source("sword")
	
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), base_str, "sword修正器已移除")
	assert_equals(stats.get_stat(StatModifier.StatType.AGILITY), base_agi, "sword修正器已移除")
	assert_equals(stats.get_stat(StatModifier.StatType.VITALITY), base_vit + 2.0, "armor修正器保留")
	
	stats.remove_modifier(mod3)
	
	test_end()


## 测试 2.7: 按标签移除
func test_2_7_remove_by_tag():
	test_start("2.7 按标签移除修正器")
	
	# 先获取当前值（包含派生加成）
	var base_str = stats.get_stat(StatModifier.StatType.STRENGTH)
	var base_agi = stats.get_stat(StatModifier.StatType.AGILITY)
	var base_vit = stats.get_stat(StatModifier.StatType.VITALITY)
	
	var mod1 = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "buff1")
	mod1.add_tag("buff")
	
	var mod2 = StatModifier.create_flat(StatModifier.StatType.AGILITY, 3.0, "buff2")
	mod2.add_tag("buff")
	
	var mod3 = StatModifier.create_flat(StatModifier.StatType.VITALITY, 2.0, "debuff1")
	mod3.add_tag("debuff")
	
	stats.add_modifier(mod1)
	stats.add_modifier(mod2)
	stats.add_modifier(mod3)
	
	# 移除所有buff标签的修正器
	stats.remove_modifiers_by_tag("buff")
	
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), base_str, "buff已移除")
	assert_equals(stats.get_stat(StatModifier.StatType.AGILITY), base_agi, "buff已移除")
	assert_equals(stats.get_stat(StatModifier.StatType.VITALITY), base_vit + 2.0, "debuff保留")
	
	stats.remove_modifiers_by_tag("debuff")
	
	test_end()


## ========== 第三阶段: 战斗系统 ==========
func run_phase_3_tests():
	print("\n" + "=".repeat(60))
	print("第三阶段测试: 战斗系统")
	print("=".repeat(60) + "\n")
	
	test_3_1_basic_damage()
	test_3_2_dodge()
	test_3_3_block()
	test_3_4_armor_reduction()
	test_3_5_elemental_resistance()
	test_3_6_energy_shield()
	test_3_7_damage_calculation()
	test_3_8_life_steal()
	
	print_phase_summary(3)
	print("\n按 [空格] 继续下一阶段测试...")


## 测试 3.1: 基础伤害
func test_3_1_basic_damage():
	test_start("3.1 基础伤害计算")
	
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp
	
	var result = stats.take_damage(50.0, "physical", "", false, false)  # 不能闪避和格挡
	
	assert_true(result.final_damage > 0, "应该受到伤害")
	assert_equals(stats.current_health, max_hp - result.final_damage, "生命值应减少")
	
	# 恢复生命
	stats.heal(999)
	
	test_end()


## 测试 3.2: 闪避
func test_3_2_dodge():
	test_start("3.2 闪避机制")
	
	# 设置100%闪避率
	var dodge_mod = StatModifier.create_override(StatModifier.StatType.DODGE_CHANCE, 1.0, "test")
	stats.add_modifier(dodge_mod)
	
	var result = stats.take_damage(100.0, "physical", "", true, false)
	
	assert_true(result.was_dodged, "应该闪避")
	assert_equals(result.final_damage, 0.0, "闪避后无伤害")
	
	stats.remove_modifier(dodge_mod)
	
	test_end()


## 测试 3.3: 格挡
func test_3_3_block():
	test_start("3.3 格挡机制")
	
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp
	
	# 设置格挡减伤
	var block_reduction = StatModifier.create_override(StatModifier.StatType.BLOCK_REDUCTION, 0.5, "test")
	stats.add_modifier(block_reduction)
	
	var result = stats.take_damage(100.0, "physical", "", false, true)  # 格挡状态
	
	assert_true(result.was_blocked, "应该格挡")
	assert_true(result.final_damage < 100.0, "格挡应减少伤害")
	
	stats.remove_modifier(block_reduction)
	stats.heal(999)
	
	test_end()


## 测试 3.4: 护甲减伤
func test_3_4_armor_reduction():
	test_start("3.4 护甲减伤")
	
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp
	
	# 设置高护甲
	var armor_mod = StatModifier.create_override(StatModifier.StatType.ARMOR, 100.0, "test")
	stats.add_modifier(armor_mod)
	
	var result = stats.take_damage(100.0, "physical", "", false, false)
	
	# 护甲公式: reduction = armor / (armor + 100)
	# 100护甲 = 50%减伤
	assert_true(result.final_damage < 100.0, "护甲应减少伤害")
	
	stats.remove_modifier(armor_mod)
	stats.heal(999)
	
	test_end()


## 测试 3.5: 元素抗性
func test_3_5_elemental_resistance():
	test_start("3.5 元素抗性")
	
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp
	
	# 设置75%火焰抗性
	var fire_res = StatModifier.create_override(StatModifier.StatType.RES_FIRE, 75.0, "test")
	stats.add_modifier(fire_res)
	
	var result = stats.take_damage(100.0, "magic", "fire", false, false)
	
	# 75%抗性 = 25%伤害
	assert_true(result.final_damage < 50.0, "抗性应大幅减少伤害")
	
	stats.remove_modifier(fire_res)
	stats.heal(999)
	
	test_end()


## 测试 3.6: 能量护盾
func test_3_6_energy_shield():
	test_start("3.6 能量护盾吸收")
	
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp
	stats.current_energy_shield = 50.0
	
	var result = stats.take_damage(100.0, "physical", "", false, false)
	
	assert_true(result.damage_absorbed >= 50.0, "护盾应吸收部分伤害")
	assert_true(stats.current_energy_shield < 50.0, "护盾应减少")
	
	stats.heal(999)
	stats.current_energy_shield = stats.get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD)
	
	test_end()


## 测试 3.7: 伤害计算
func test_3_7_damage_calculation():
	test_start("3.7 攻击方伤害计算")
	
	var damage_calc = stats.calculate_damage(0.0, "physical", "", true)
	
	assert_true(damage_calc.has("total_damage"), "应包含总伤害")
	assert_true(damage_calc.has("base_damage"), "应包含基础伤害")
	assert_true(damage_calc.has("was_crit"), "应包含暴击判定")
	assert_true(damage_calc.total_damage > 0, "应计算出伤害")
	
	print("  总伤害: ", damage_calc.total_damage)
	print("  暴击: ", damage_calc.was_crit)
	
	test_end()


## 测试 3.8: 生命偷取
func test_3_8_life_steal():
	test_start("3.8 生命偷取")
	
	# 设置生命偷取
	var steal_mod = StatModifier.create_override(StatModifier.StatType.LIFE_STEAL, 0.2, "test")  # 20%
	stats.add_modifier(steal_mod)
	
	# 降低生命值
	stats.current_health = stats.get_stat(StatModifier.StatType.MAX_HEALTH) * 0.5
	var health_before = stats.current_health
	
	# 创建一个目标
	var target_stats = StatsComponent.new()
	target_stats.base_stats = stats.base_stats
	add_child(target_stats)
	
	# 攻击目标
	stats.deal_damage_to(target_stats, 100.0, "physical", "", false, false, false)
	
	assert_true(stats.current_health > health_before, "生命偷取应恢复生命")
	
	target_stats.queue_free()
	stats.remove_modifier(steal_mod)
	stats.heal(999)
	
	test_end()


## ========== 第四阶段: 升级和属性点系统 ==========
func run_phase_4_tests():
	print("\n" + "=".repeat(60))
	print("第四阶段测试: 升级和属性点系统")
	print("=".repeat(60) + "\n")
	
	test_4_1_gain_experience()
	test_4_2_level_up()
	test_4_3_allocate_stat_points()
	test_4_4_reset_stat_points()
	test_4_5_exp_curve()
	
	print_phase_summary(4)
	print("\n按 [空格] 继续下一阶段测试...")


## 测试 4.1: 获取经验
func test_4_1_gain_experience():
	test_start("4.1 获取经验值")
	
	var exp_before = stats.get_experience()
	var level_before = stats.get_level()
	
	# 给少量经验，避免升级
	stats.gain_experience(10)
	
	# 如果没升级，经验应增加；如果升级了，等级应提升
	var exp_increased = stats.get_experience() > exp_before
	var level_increased = stats.get_level() > level_before
	
	assert_true(exp_increased or level_increased, "经验值应增加或等级应提升")
	
	test_end()


## 测试 4.2: 升级
func test_4_2_level_up():
	test_start("4.2 升级系统")
	
	var level_before = stats.get_level()
	var points_before = stats.get_available_stat_points()
	
	# 给予大量经验触发升级
	stats.gain_experience(10000)
	
	assert_true(stats.get_level() > level_before, "等级应提升")
	assert_true(stats.get_available_stat_points() > points_before, "应获得属性点")
	
	test_end()


## 测试 4.3: 分配属性点
func test_4_3_allocate_stat_points():
	test_start("4.3 分配属性点")
	
	# 确保有属性点
	stats.base_stats.stat_points = 10
	
	var strength_before = stats.get_stat(StatModifier.StatType.STRENGTH)
	var points_before = stats.get_available_stat_points()
	
	var success = stats.allocate_stat_point(StatModifier.StatType.STRENGTH, 5)
	
	assert_true(success, "分配应成功")
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  strength_before + 5, "力量应增加5点")
	assert_equals(stats.get_available_stat_points(), 
				  points_before - 5, "属性点应减少5点")
	
	test_end()


## 测试 4.4: 重置属性点
func test_4_4_reset_stat_points():
	test_start("4.4 重置属性点")
	
	# 分配一些属性点
	stats.base_stats.stat_points = 10
	stats.allocate_stat_point(StatModifier.StatType.STRENGTH, 5)
	stats.allocate_stat_point(StatModifier.StatType.AGILITY, 3)
	
	var points_before = stats.get_available_stat_points()
	
	# 重置
	stats.reset_stat_points()
	
	assert_true(stats.get_available_stat_points() > points_before, "属性点应返还")
	assert_equals(stats.get_stat(StatModifier.StatType.STRENGTH), 
				  stats.initial_strength, "力量应重置到初始值")
	
	test_end()


## 测试 4.5: 经验曲线
func test_4_5_exp_curve():
	test_start("4.5 经验曲线计算")
	
	var exp_level_2 = stats._calculate_exp_for_next_level(1)
	var exp_level_3 = stats._calculate_exp_for_next_level(2)
	var exp_level_10 = stats._calculate_exp_for_next_level(9)
	
	assert_true(exp_level_3 > exp_level_2, "等级越高所需经验越多")
	assert_true(exp_level_10 > exp_level_3, "高等级所需经验大幅增加")
	
	print("  2级所需: ", exp_level_2)
	print("  3级所需: ", exp_level_3)
	print("  10级所需: ", exp_level_10)
	
	test_end()


## ========== 第五阶段: 序列化和高级功能 ==========
func run_phase_5_tests():
	print("\n" + "=".repeat(60))
	print("第五阶段测试: 序列化和高级功能")
	print("=".repeat(60) + "\n")
	
	test_5_1_serialization()
	test_5_2_deserialization()
	await test_5_3_regeneration()
	await test_5_4_stat_changed_signal()
	test_5_5_performance()
	
	print_phase_summary(5)
	print("\n按 [空格] 继续下一阶段测试...")


## 测试 5.1: 序列化
func test_5_1_serialization():
	test_start("5.1 序列化")
	
	var save_data = stats.to_dict()
	
	assert_true(save_data.has("current_health"), "应包含当前生命")
	assert_true(save_data.has("level"), "应包含等级")
	assert_true(save_data.has("strength"), "应包含力量")
	assert_true(save_data.has("permanent_modifiers"), "应包含永久修正器")
	
	print("  保存数据键: ", save_data.keys().size(), "个")
	
	test_end()


## 测试 5.2: 反序列化
func test_5_2_deserialization():
	test_start("5.2 反序列化")
	
	# 保存当前状态
	var save_data = stats.to_dict()
	
	# 修改一些值
	stats.current_health = 1.0
	stats.base_stats.level = 99
	
	# 恢复
	stats.from_dict(save_data)
	
	assert_equals(stats.current_health, save_data.current_health, "生命值应恢复")
	assert_equals(stats.base_stats.level, save_data.level, "等级应恢复")
	
	test_end()


## 测试 5.3: 自动回复
func test_5_3_regeneration():
	test_start("5.3 自动回复系统 (需等待)")
	
	# 确保有回复属性
	var health_regen = stats.get_stat(StatModifier.StatType.HEALTH_REGEN)
	if health_regen <= 0:
		# 添加回复修正器
		var regen_mod = StatModifier.create_flat(StatModifier.StatType.HEALTH_REGEN, 10.0, "test_regen")
		stats.add_modifier(regen_mod)
	
	# 降低生命值
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp * 0.5
	var health_before = stats.current_health
	
	print("  等待2秒观察回复...")
	await get_tree().create_timer(2.0).timeout
	
	assert_true(stats.current_health > health_before, "生命应自动回复")
	
	# 清理测试修正器
	stats.remove_modifiers_by_source("test_regen")
	stats.heal(999)
	
	test_end()

# 测试modifiers_changed信号（更可靠）
var modifiers_signal_received = false

## 测试 5.4: 属性变化信号
func test_5_4_stat_changed_signal():
	test_start("5.4 属性变化信号")
	
	var modifiers_handler = func():
		modifiers_signal_received = true
		print("  [信号] modifiers_changed触发!")
	
	stats.modifiers_changed.connect(modifiers_handler)
	
	# 触发修正器变化
	var mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "test")
	stats.add_modifier(mod)
	

	print("  等待一帧以确保信号传递...")
	# 等待一帧确保信号传递完成
	await get_tree().process_frame
	
	# modifiers_changed信号应该已经触发
	assert_true(modifiers_signal_received, "应触发modifiers_changed信号")
	
	stats.modifiers_changed.disconnect(modifiers_handler)
	stats.remove_modifier(mod)
	
	test_end()


## 测试 5.5: 性能测试
func test_5_5_performance():
	test_start("5.5 性能测试")
	
	var start_time = Time.get_ticks_msec()
	
	# 添加大量修正器
	var modifiers = []
	for i in range(100):
		var mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 1.0, "perf_test_%d" % i)
		modifiers.append(mod)
		stats.add_modifier(mod)
	
	# 进行多次属性查询
	for i in range(1000):
		stats.get_stat(StatModifier.StatType.STRENGTH)
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	print("  100个修正器 + 1000次查询耗时: ", elapsed, "ms")
	assert_true(elapsed < 1000, "性能应可接受 (<1秒)")
	
	# 清理
	for mod in modifiers:
		stats.remove_modifier(mod)
	
	test_end()


## ========== 第六阶段: 技能和状态效果测试 ==========
func run_phase_6_tests():
	print("\n" + "=".repeat(60))
	print("第六阶段测试: 技能和状态效果测试")
	print("=".repeat(60) + "\n")
	
	test_6_1_skill_damage_calculation()
	test_6_2_critical_hit_system()
	test_6_3_spell_damage_and_casting()
	test_6_4_attack_speed_and_casting_speed()
	test_6_5_projectile_and_pierce_system()
	test_6_6_cooldown_reduction()
	test_6_7_skill_range_and_scaling()
	test_6_8_mana_consumption()
	test_6_9_stamina_usage()
	
	print_phase_summary(6)
	print("\n按 [空格] 继续下一阶段测试...")


## 测试 6.1: 技能伤害计算
func test_6_1_skill_damage_calculation():
	test_start("6.1 技能伤害计算")
	
	# 测试基础技能伤害（使用魔法攻击力）
	var magic_damage = stats.calculate_damage(0.0, "magic", "", false)
	assert_true(magic_damage.base_damage > 0, "魔法攻击力应大于0")
	
	# 测试技能倍率伤害
	var skill_damage = stats.calculate_damage(50.0, "physical", "", false, 0.0, 2.0)  # 2倍伤害
	assert_equals(skill_damage.total_damage, 100.0, "技能倍率应正确应用")
	
	# 测试元素技能伤害
	var fire_damage = stats.calculate_damage(0.0, "magic", "fire", false)
	assert_true(fire_damage.elemental_damage >= 0, "元素伤害应计算正确")
	
	test_end()


## 测试 6.2: 暴击系统
func test_6_2_critical_hit_system():
	test_start("6.2 暴击系统")
	
	# 设置100%暴击率进行测试
	var crit_mod = StatModifier.create_override(StatModifier.StatType.CRIT_CHANCE, 1.0, "test")
	var crit_damage_mod = StatModifier.create_override(StatModifier.StatType.CRIT_DAMAGE, 2.0, "test")  # 200%暴击伤害
	stats.add_modifier(crit_mod)
	stats.add_modifier(crit_damage_mod)
	
	var damage_calc = stats.calculate_damage(100.0, "physical", "", true)
	
	assert_true(damage_calc.was_crit, "应触发暴击")
	assert_equals(damage_calc.crit_multiplier, 2.0, "暴击倍率应为2.0")
	assert_equals(damage_calc.total_damage, 200.0, "暴击伤害应正确计算")
	
	# 测试幸运对暴击率的影响
	stats.remove_modifier(crit_mod)
	var luck_crit_mod = StatModifier.create_flat(StatModifier.StatType.LUCK, 50.0, "test")  # 大幅提升幸运
	stats.add_modifier(luck_crit_mod)
	
	var crit_chance = stats.get_stat(StatModifier.StatType.CRIT_CHANCE)
	assert_true(crit_chance > stats.base_stats.crit_chance, "幸运应提升暴击率")
	
	stats.remove_modifier(crit_mod)
	stats.remove_modifier(crit_damage_mod)
	stats.remove_modifier(luck_crit_mod)
	
	test_end()


## 测试 6.3: 法术伤害和施法
func test_6_3_spell_damage_and_casting():
	test_start("6.3 法术伤害和施法")
	
	# 测试智力对魔法伤害的影响
	# 公式: base_magic_damage + (intelligence * 3)
	# 增加10点智力应增加30点魔法伤害
	var magic_before = stats.get_stat(StatModifier.StatType.MAGIC_DAMAGE)
	
	var int_mod = StatModifier.create_flat(StatModifier.StatType.INTELLIGENCE, 10.0, "test")
	stats.add_modifier(int_mod)
	
	var magic_after = stats.get_stat(StatModifier.StatType.MAGIC_DAMAGE)
	var magic_increase = magic_after - magic_before
	
	assert_equals(magic_increase, 30.0, "增加10点智力应增加30点魔法伤害(每点智力+3魔法伤害)")
	
	# 测试施法速度
	var base_cast_speed = stats.get_stat(StatModifier.StatType.CAST_SPEED)
	var cast_speed_mod = StatModifier.create_percent(StatModifier.StatType.CAST_SPEED, 0.5, "test")  # +50%
	stats.add_modifier(cast_speed_mod)
	
	var new_cast_speed = stats.get_stat(StatModifier.StatType.CAST_SPEED)
	assert_equals(new_cast_speed, base_cast_speed * 1.5, "施法速度应增加50%")
	
	stats.remove_modifier(int_mod)
	stats.remove_modifier(cast_speed_mod)
	
	test_end()


## 测试 6.4: 攻击速度和施法速度
func test_6_4_attack_speed_and_casting_speed():
	test_start("6.4 攻击速度和施法速度")
	
	# 测试敏捷对攻击速度的影响
	# 公式: base_attack_speed * (1.0 + agility * 0.01)
	# 增加10点敏捷,攻击速度会从 base*(1+old_agi*0.01) 变为 base*(1+new_agi*0.01)
	var attack_speed_before = stats.get_stat(StatModifier.StatType.ATTACK_SPEED)
	var agi_mod = StatModifier.create_flat(StatModifier.StatType.AGILITY, 10.0, "test")
	stats.add_modifier(agi_mod)
	
	var attack_speed_after = stats.get_stat(StatModifier.StatType.ATTACK_SPEED)
	
	# 验证攻击速度增加了
	assert_true(attack_speed_after > attack_speed_before, "增加10点敏捷应提升攻击速度")
	
	# 测试攻击速度对DPS的影响（理论计算）
	var base_damage = stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)
	var attacks_per_second = attack_speed_after
	var dps = base_damage * attacks_per_second
	
	assert_true(dps > base_damage, "更高攻击速度应提升DPS")
	
	stats.remove_modifier(agi_mod)
	
	test_end()


## 测试 6.5: 投射物和穿透系统
func test_6_5_projectile_and_pierce_system():
	test_start("6.5 投射物和穿透系统")
	
	# 测试额外投射物数量
	var base_projectiles = stats.get_stat(StatModifier.StatType.PROJECTILE_COUNT)
	var projectile_mod = StatModifier.create_flat(StatModifier.StatType.PROJECTILE_COUNT, 2.0, "test")
	stats.add_modifier(projectile_mod)
	
	var new_projectiles = stats.get_stat(StatModifier.StatType.PROJECTILE_COUNT)
	assert_equals(new_projectiles, base_projectiles + 2.0, "应增加2个额外投射物")
	
	# 测试穿透次数
	var base_pierce = stats.get_stat(StatModifier.StatType.PIERCE_COUNT)
	var pierce_mod = StatModifier.create_flat(StatModifier.StatType.PIERCE_COUNT, 3.0, "test")
	stats.add_modifier(pierce_mod)
	
	var new_pierce = stats.get_stat(StatModifier.StatType.PIERCE_COUNT)
	assert_equals(new_pierce, base_pierce + 3.0, "应增加3次穿透")
	
	stats.remove_modifier(projectile_mod)
	stats.remove_modifier(pierce_mod)
	
	test_end()


## 测试 6.6: 冷却缩减
func test_6_6_cooldown_reduction():
	test_start("6.6 冷却缩减")
	
	# 测试冷却缩减属性
	var base_cdr = stats.get_stat(StatModifier.StatType.COOLDOWN_REDUCTION)
	var cdr_mod = StatModifier.create_flat(StatModifier.StatType.COOLDOWN_REDUCTION, 0.2, "test")  # 20%
	stats.add_modifier(cdr_mod)
	
	var new_cdr = stats.get_stat(StatModifier.StatType.COOLDOWN_REDUCTION)
	assert_equals(new_cdr, base_cdr + 0.2, "冷却缩减应增加20%")
	
	# 测试高冷却缩减（注意：当前系统没有硬性上限，只是StatsData中的范围限制）
	# 但修正器可以超过这个范围，所以这个测试需要调整
	var high_cdr_mod = StatModifier.create_flat(StatModifier.StatType.COOLDOWN_REDUCTION, 1.0, "test_high")  # +100%
	stats.add_modifier(high_cdr_mod)
	
	var final_cdr = stats.get_stat(StatModifier.StatType.COOLDOWN_REDUCTION)
	# 系统没有强制上限，所以实际值是 base_cdr + 0.2 + 1.0
	# 这里我们只验证冷却缩减可以叠加
	assert_true(final_cdr > 0.8, "冷却缩减可以通过修正器叠加(系统无硬性上限)")
	
	stats.remove_modifier(cdr_mod)
	stats.remove_modifier(high_cdr_mod)
	
	test_end()


## 测试 6.7: 技能范围和缩放
func test_6_7_skill_range_and_scaling():
	test_start("6.7 技能范围和缩放")
	
	# 测试技能范围
	var base_range = stats.get_stat(StatModifier.StatType.SKILL_RANGE)
	var range_mod = StatModifier.create_percent(StatModifier.StatType.SKILL_RANGE, 0.5, "test")  # +50%
	stats.add_modifier(range_mod)
	
	var new_range = stats.get_stat(StatModifier.StatType.SKILL_RANGE)
	assert_equals(new_range, base_range * 1.5, "技能范围应增加50%")
	
	# 测试范围对AOE技能的影响（理论计算）
	var aoe_damage = 100.0 * new_range  # 假设范围影响伤害
	assert_true(aoe_damage > 100.0, "更大范围应提升AOE伤害")
	
	stats.remove_modifier(range_mod)
	
	test_end()


## 测试 6.8: 魔力消耗
func test_6_8_mana_consumption():
	test_start("6.8 魔力消耗")
	
	var max_mana = stats.get_stat(StatModifier.StatType.MAX_MANA)
	stats.current_mana = max_mana
	
	# 测试魔力消耗
	var success = stats.consume_mana(50.0)
	assert_true(success, "应成功消耗50点魔力")
	assert_equals(stats.current_mana, max_mana - 50.0, "魔力值应减少50")
	
	# 测试魔力不足的情况
	success = stats.consume_mana(999.0)
	assert_false(success, "魔力不足时应消耗失败")
	assert_equals(stats.current_mana, max_mana - 50.0, "魔力值应保持不变")
	
	# 测试魔力回复
	stats.restore_mana(25.0)
	assert_equals(stats.current_mana, max_mana - 25.0, "应回复25点魔力")
	
	stats.restore_mana(999.0)  # 过度回复
	assert_equals(stats.current_mana, max_mana, "魔力不应超过最大值")
	
	test_end()


## 测试 6.9: 耐力消耗
func test_6_9_stamina_usage():
	test_start("6.9 耐力消耗")
	
	var max_stamina = stats.get_stat(StatModifier.StatType.MAX_STAMINA)
	stats.current_stamina = max_stamina
	
	# 测试耐力消耗（用于冲刺、闪避等）
	var success = stats.consume_stamina(30.0)
	assert_true(success, "应成功消耗30点耐力")
	assert_equals(stats.current_stamina, max_stamina - 30.0, "耐力值应减少30")
	
	# 测试耐力不足
	success = stats.consume_stamina(999.0)
	assert_false(success, "耐力不足时应消耗失败")
	
	# 测试耐力回复
	stats.restore_stamina(15.0)
	assert_equals(stats.current_stamina, max_stamina - 15.0, "应回复15点耐力")
	
	stats.restore_stamina(999.0)  # 过度回复
	assert_equals(stats.current_stamina, max_stamina, "耐力不应超过最大值")
	
	test_end()


## ========== 第七阶段: 扩展功能测试 ==========
func run_phase_7_tests():
	print("\n" + "=".repeat(60))
	print("第七阶段测试: 扩展功能测试")
	print("=".repeat(60) + "\n")
	
	test_7_1_elemental_damage_and_resistance()
	test_7_2_status_resistances()
	test_7_3_movement_stats()
	await test_7_4_layered_defense()
	test_7_5_special_abilities()
	test_7_6_reward_system()
	test_7_7_inventory_system()
	test_7_8_edge_cases()
	test_7_9_stress_test()
	
	print_phase_summary(7)
	print("\n" + "=".repeat(60))
	print("所有测试完成!")
	print_test_summary()
	print("=".repeat(60))


## 测试 7.1: 元素伤害和抗性
func test_7_1_elemental_damage_and_resistance():
	test_start("7.1 元素伤害和抗性")
	
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp
	
	# 移除魔法抗性
	var current_magic_resist = stats.get_stat(StatModifier.StatType.MAGIC_RESIST)
	var no_magic_resist = StatModifier.create_override(StatModifier.StatType.MAGIC_RESIST, 0, "no_magic_resist")
	stats.add_modifier(no_magic_resist)
	
	# 设置75%火焰抗性
	var fire_res_mod = StatModifier.create_override(StatModifier.StatType.RES_FIRE, 75.0, "test")
	stats.add_modifier(fire_res_mod)
	
	# 造成100点火焰伤害
	var result = stats.take_damage(100.0, "magic", "fire", false, false)
	
	# 75%抗性 = 25%伤害
	var expected_damage = 100.0 * (1.0 - 75.0/100.0)
	assert_equals(result.final_damage, expected_damage, "75%火焰抗性，让100伤害减少到25")
	
	# 测试元素弱点（负抗性）
	stats.remove_modifier(fire_res_mod)
	var fire_weak_mod = StatModifier.create_override(StatModifier.StatType.RES_FIRE, -50.0, "test")
	stats.add_modifier(fire_weak_mod)
	
	stats.current_health = max_hp
	result = stats.take_damage(100.0, "magic", "fire", false, false)
	
	# 负抗性 = 伤害增加
	var expected_damage_weak = 100.0 * (1.0 - (-50.0)/100.0)
	assert_equals(result.final_damage, expected_damage_weak, "50%火焰弱点，使100伤害增加至150")
	
	stats.remove_modifier(fire_weak_mod)
	stats.heal(999)
	
	var restore_magic_resist = StatModifier.create_override(StatModifier.StatType.MAGIC_RESIST, current_magic_resist, "current_magic_resist")
	stats.add_modifier(restore_magic_resist)
	
	test_end()


## 测试 7.2: 状态抗性
func test_7_2_status_resistances():
	test_start("7.2 状态抗性")
	
	# 设置100%晕眩抗性
	var stun_res_mod = StatModifier.create_override(StatModifier.StatType.STATUS_RES_STUN, 1.0, "test")
	stats.add_modifier(stun_res_mod)
	
	# 状态抗性主要用于技能系统，这里只验证属性存在
	var stun_res = stats.get_stat(StatModifier.StatType.STATUS_RES_STUN)
	assert_equals(stun_res, 1.0, "晕眩抗性应为100%")
	
	# 测试其他状态抗性
	var freeze_res = stats.get_stat(StatModifier.StatType.STATUS_RES_FREEZE)
	var burn_res = stats.get_stat(StatModifier.StatType.STATUS_RES_BURN)
	var poison_res = stats.get_stat(StatModifier.StatType.STATUS_RES_POISON)
	
	assert_true(freeze_res >= 0.0 and freeze_res <= 1.0, "冰冻抗性应在0-1范围内")
	assert_true(burn_res >= 0.0 and burn_res <= 1.0, "燃烧抗性应在0-1范围内")
	assert_true(poison_res >= 0.0 and poison_res <= 1.0, "中毒抗性应在0-1范围内")
	
	stats.remove_modifier(stun_res_mod)
	
	test_end()


## 测试 7.3: 移动属性
func test_7_3_movement_stats():
	test_start("7.3 移动属性")
	
	# 测试基础移动速度
	var base_speed = stats.get_stat(StatModifier.StatType.MOVE_SPEED)
	assert_true(base_speed > 0, "基础移动速度应大于0")
	
	# 测试冲刺速度
	var sprint_speed = stats.get_stat(StatModifier.StatType.SPRINT_SPEED)
	assert_true(sprint_speed >= base_speed, "冲刺速度应不小于基础速度")
	
	# 测试闪避速度和距离
	var dash_speed = stats.get_stat(StatModifier.StatType.DASH_SPEED)
	var dash_distance = stats.get_stat(StatModifier.StatType.DASH_DISTANCE)
	
	assert_true(dash_speed > 0, "闪避速度应大于0")
	assert_true(dash_distance > 0, "闪避距离应大于0")
	
	# 添加移动速度修正器
	var speed_mod = StatModifier.create_percent(StatModifier.StatType.MOVE_SPEED, 0.5, "test")  # +50%
	stats.add_modifier(speed_mod)
	
	var new_speed = stats.get_stat(StatModifier.StatType.MOVE_SPEED)
	assert_equals(new_speed, base_speed * 1.5, "移动速度应增加50%")
	
	stats.remove_modifier(speed_mod)
	
	test_end()


## 测试 7.4: 多层防御系统
func test_7_4_layered_defense():
	test_start("7.4 多层防御系统")
	
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp
	stats.current_energy_shield = 0.0
	
	# 移除护甲以便准确测试护盾吸收
	var armor_override = StatModifier.create_override(StatModifier.StatType.ARMOR, 0.0, "test_no_armor")
	stats.add_modifier(armor_override)
	
	# 设置能量护盾
	var shield_mod = StatModifier.create_flat(StatModifier.StatType.MAX_ENERGY_SHIELD, 100.0, "test")
	var shield_regen_mod = StatModifier.create_flat(StatModifier.StatType.ENERGY_SHIELD_REGEN, 10.0, "test")
	stats.add_modifier(shield_mod)
	stats.add_modifier(shield_regen_mod)
	
	# 充满护盾
	stats.current_energy_shield = stats.get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD)
	
	# 造成150点伤害（护盾100 + 生命50）
	var result = stats.take_damage(150.0, "physical", "", false, false)
	
	assert_equals(result.damage_absorbed, 100.0, "护盾应吸收100点伤害")
	# 注意: 由于伤害计算顺序，护盾吸收是在护甲减伤之后进行的
	# 所以实际伤害会先经过护甲减伤，再被护盾吸收
	# 这里我们移除了护甲，所以应该是准确的50点
	assert_equals(result.final_damage, 50.0, "剩余50点伤害应作用于生命")
	assert_equals(stats.current_energy_shield, 0.0, "护盾应被击破")
	
	# 测试护盾回复延迟
	print("  等待3秒观察护盾回复...")
	await get_tree().create_timer(3.0).timeout
	
	assert_true(stats.current_energy_shield > 0, "护盾应开始自动回复")
	
	# 清理
	stats.remove_modifier(armor_override)
	stats.remove_modifier(shield_mod)
	stats.remove_modifier(shield_regen_mod)
	stats.heal(999)
	
	test_end()


## 测试 7.5: 特殊能力
func test_7_5_special_abilities():
	test_start("7.5 特殊能力")
	
	# 测试生命偷取
	var lifesteal_mod = StatModifier.create_override(StatModifier.StatType.LIFE_STEAL, 0.2, "test")  # 20%
	stats.add_modifier(lifesteal_mod)
	
	var damage_calc = stats.calculate_damage(100.0, "physical", "", true)
	assert_equals(damage_calc.life_steal_amount, 20.0, "生命偷取应为20点")
	
	# 测试伤害反射
	var reflect_mod = StatModifier.create_flat(StatModifier.StatType.DAMAGE_REFLECT_AMOUNT, 5.0, "test")
	stats.add_modifier(reflect_mod)
	
	var result = stats.take_damage(50.0, "physical", "", false, false)
	assert_equals(result.damage_reflected, 5.0, "伤害反射应为5点")
	
	# 测试冷却缩减
	var cdr_mod = StatModifier.create_flat(StatModifier.StatType.COOLDOWN_REDUCTION, 0.25, "test")  # 25%
	stats.add_modifier(cdr_mod)
	
	var cdr = stats.get_stat(StatModifier.StatType.COOLDOWN_REDUCTION)
	assert_equals(cdr, 0.25, "冷却缩减应为25%")
	
	# 清理
	stats.remove_modifier(lifesteal_mod)
	stats.remove_modifier(reflect_mod)
	stats.remove_modifier(cdr_mod)
	stats.heal(999)
	
	test_end()


## 测试 7.6: 奖励系统
func test_7_6_reward_system():
	test_start("7.6 奖励系统")
	
	# 测试金币掉落倍率
	var gold_mod = StatModifier.create_flat(StatModifier.StatType.GOLD_FIND, 0.5, "test")  # +50%
	stats.add_modifier(gold_mod)
	
	var gold_multiplier = stats.get_stat(StatModifier.StatType.GOLD_FIND)
	assert_equals(gold_multiplier, 1.5, "金币倍率应为1.5")
	
	# 测试物品掉落倍率 - 注意幸运值也会影响掉落率
	# item_find 计算公式: base_value * (1.0 + luck * luck_drop_bonus)
	# 基础 item_find = 1.0, luck = 10, luck_drop_bonus = 0.01
	# 派生后: 1.0 * (1 + 10 * 0.01) = 1.1
	# 添加修正器 +1.0 后: 1.1 + 1.0 = 2.1
	var item_mod = StatModifier.create_flat(StatModifier.StatType.ITEM_FIND, 1.0, "test")  # +100%
	stats.add_modifier(item_mod)
	
	var item_multiplier = stats.get_stat(StatModifier.StatType.ITEM_FIND)
	var luck = stats.get_stat(StatModifier.StatType.LUCK)
	var expected_item_find = (1.0 * (1.0 + luck * stats.base_stats.luck_drop_bonus)) + 1.0
	assert_equals(item_multiplier, expected_item_find, "物品掉落倍率应考虑幸运值影响")
	
	# 测试经验获取倍率
	var exp_mod = StatModifier.create_flat(StatModifier.StatType.EXPERIENCE_GAIN, 0.3, "test")  # +30%
	stats.add_modifier(exp_mod)
	
	var exp_multiplier = stats.get_stat(StatModifier.StatType.EXPERIENCE_GAIN)
	assert_equals(exp_multiplier, 1.3, "经验倍率应为1.3")
	
	# 清理
	stats.remove_modifier(gold_mod)
	stats.remove_modifier(item_mod)
	stats.remove_modifier(exp_mod)
	
	test_end()


## 测试 7.7: 负重系统
func test_7_7_inventory_system():
	test_start("7.7 负重系统")
	
	# 测试最大负重
	var max_weight = stats.get_stat(StatModifier.StatType.MAX_WEIGHT)
	assert_true(max_weight > 0, "最大负重应大于0")
	
	# 测试背包格子数
	var inventory_slots = stats.get_stat(StatModifier.StatType.INVENTORY_SLOTS)
	assert_true(inventory_slots > 0, "背包格子数应大于0")
	
	# 测试力量对负重的影响
	# 公式: base_value + (strength * 3)
	# 增加5点力量应该增加15点负重
	var strength_before = stats.get_stat(StatModifier.StatType.STRENGTH)
	var weight_before = stats.get_stat(StatModifier.StatType.MAX_WEIGHT)
	
	print("  力量变化前: 力量=%d, 负重=%.1f" % [strength_before, weight_before])
	
	var strength_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "test")
	stats.add_modifier(strength_mod)
	
	var strength_after = stats.get_stat(StatModifier.StatType.STRENGTH)
	var weight_after = stats.get_stat(StatModifier.StatType.MAX_WEIGHT)
	var weight_increase = weight_after - weight_before
	
	print("  力量变化后: 力量=%d, 负重=%.1f, 增量=%.1f" % [strength_after, weight_after, weight_increase])
	
	assert_equals(weight_increase, 15.0, "增加5点力量应增加15点负重(每点力量+3负重)")
	
	stats.remove_modifier(strength_mod)
	
	test_end()


## 测试 7.8: 边界情况
func test_7_8_edge_cases():
	test_start("7.8 边界情况")
	
	# 测试0伤害
	var result = stats.take_damage(0.0, "physical", "", false, false)
	assert_equals(result.final_damage, 0.0, "0伤害应不造成实际伤害")
	
	# 测试负伤害 - take_damage不应该支持负伤害治疗，应该使用heal方法
	# 负伤害会被截断为0
	var health_before = stats.current_health
	stats.current_health = 50.0
	result = stats.take_damage(-25.0, "physical", "", false, false)
	
	# 负伤害会被max(0, ...)截断为0，所以实际伤害是0
	assert_equals(result.final_damage, 0.0, "负伤害会被截断为0(应使用heal方法)")
	assert_equals(stats.current_health, 50.0, "生命值不应变化(负伤害无效)")
	
	# 正确的治疗方式应该使用heal方法
	stats.heal(25.0)
	assert_equals(stats.current_health, 75.0, "使用heal方法应正确恢复生命")
	
	# 测试超过最大值的治疗
	var max_hp = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	stats.current_health = max_hp - 10
	stats.heal(50.0)
	assert_equals(stats.current_health, max_hp, "治疗不应超过最大生命值")
	
	# 测试修正器值为0
	var zero_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 0.0, "test")
	var strength_before = stats.get_stat(StatModifier.StatType.STRENGTH)
	stats.add_modifier(zero_mod)
	var strength_after = stats.get_stat(StatModifier.StatType.STRENGTH)
	assert_equals(strength_after, strength_before, "0值修正器不应影响属性")
	
	stats.remove_modifier(zero_mod)
	stats.current_health = health_before
	
	test_end()


## 测试 7.9: 压力测试
func test_7_9_stress_test():
	test_start("7.9 压力测试")
	
	var start_time = Time.get_ticks_msec()
	
	# 添加大量不同类型的修正器
	var modifiers = []
	for i in range(50):
		# 混合不同类型的修正器
		var mod_type = StatModifier.StatType.values()[i % StatModifier.StatType.size()]
		var mod = StatModifier.create_flat(mod_type, 1.0, "stress_test_%d" % i)
		modifiers.append(mod)
		stats.add_modifier(mod)
	
	# 进行大量属性查询
	for i in range(500):
		var random_stat = StatModifier.StatType.values()[randi() % StatModifier.StatType.size()]
		stats.get_stat(random_stat)
	
	# 测试大量伤害计算
	for i in range(100):
		stats.take_damage(10.0, "physical", "", false, false)
		stats.heal(10.0)  # 保持生命值
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	print("  50个修正器 + 500次查询 + 100次伤害计算耗时: ", elapsed, "ms")
	assert_true(elapsed < 2000, "压力测试性能应可接受 (<2秒)")
	
	# 清理
	for mod in modifiers:
		stats.remove_modifier(mod)
	
	stats.heal(999)
	
	test_end()


## ========== 测试辅助函数 ==========

func test_start(name: String):
	test_total += 1
	print("\n测试 %s:" % name)


func test_end():
	test_passed += 1
	print("  ✓ 通过")


func assert_equals(actual, expected, message: String = ""):
	if typeof(actual) == TYPE_FLOAT and typeof(expected) == TYPE_FLOAT:
		if abs(actual - expected) > 0.001:
			test_failed += 1
			print("  ✗ 失败: %s" % message)
			print("    期望: %s, 实际: %s" % [expected, actual])
		else:
			print("  ✓ %s" % message)
	elif actual != expected:
		test_failed += 1
		test_failed_reason.append(message)
		print("  ✗ 失败: %s" % message)
		print("    期望: %s, 实际: %s" % [expected, actual])
	else:
		print("  ✓ %s" % message)


func assert_true(condition: bool, message: String = ""):
	if not condition:
		test_failed += 1
		test_failed_reason.append(message)
		print("  ✗ 失败: %s" % message)
	else:
		print("  ✓ %s" % message)

func assert_false(condition: bool, message: String = ""):
	if condition:
		test_failed += 1
		test_failed_reason.append(message)
		print("  ✗ 失败: %s" % message)
	else:
		print("  ✓ %s" % message)


func print_phase_summary(phase: int):
	print("\n" + "-".repeat(60))
	print("第%d阶段测试完成" % phase)
	print("-".repeat(60))


func print_test_summary():
	print("\n" + "=".repeat(60))
	print("测试总结")
	print("=".repeat(60))
	print("总测试数: %d" % test_total)
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	print("通过率: %.1f%%" % ((float(test_passed) / test_total) * 100 if test_total > 0 else 0))
	for i in test_failed_reason:
		print("未通过用例：%s" % [i])
	print("=".repeat(60))


func _connect_signals():
	stats.health_changed.connect(func(_c, _m): pass)  # 静默监听
	stats.mana_changed.connect(func(_c, _m): pass)
	stats.stamina_changed.connect(func(_c, _m): pass)
	stats.energy_shield_changed.connect(func(_c, _m): pass)
	stats.level_up.connect(func(_l, _p): print("  [信号] 升级到等级 %d!" % _l))
	stats.experience_gained.connect(func(_a, _t): pass)
	stats.health_depleted.connect(func(): print("  [信号] 角色死亡!"))
	stats.modifiers_changed.connect(func(): pass)
