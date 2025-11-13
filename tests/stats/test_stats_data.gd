## StatsData测试
## 测试属性数据资源的核心功能
extends TestFramework

var stats_data: StatsData

func _init() -> void:
	super._init("StatsData测试")

## 设置测试环境
func setup() -> void:
	stats_data = StatsData.new()

## 清理测试环境
func teardown() -> void:
	if stats_data:
		stats_data = null

## 运行所有测试
func run_all_tests() -> void:
	test_create_stats_data()
	test_default_values()
	test_set_properties()
	test_duplicate_stats()
	test_core_attributes()
	test_combat_stats()
	test_defense_stats()
	test_elemental_resistances()
	test_movement_stats()
	test_regeneration_stats()
	test_special_stats()
	test_inventory_stats()
	test_luck_scaling()
	
	print_report()

## 测试: 创建StatsData实例
func test_create_stats_data() -> void:
	setup()
	start_test("创建StatsData实例")
	
	var passed = assert_not_null(stats_data, "StatsData实例应该成功创建")
	passed = assert_true(stats_data is Resource, "StatsData应该是Resource类型") and passed
	
	end_test(passed)
	teardown()

## 测试: 默认值
func test_default_values() -> void:
	setup()
	start_test("默认值")
	
	var passed = assert_equal(stats_data.level, 1, "默认等级应该是1")
	passed = assert_equal(stats_data.experience, 0, "默认经验值应该是0") and passed
	passed = assert_equal(stats_data.strength, 10, "默认力量应该是10") and passed
	passed = assert_equal(stats_data.agility, 10, "默认敏捷应该是10") and passed
	passed = assert_equal(stats_data.intelligence, 10, "默认智力应该是10") and passed
	passed = assert_equal(stats_data.vitality, 10, "默认体质应该是10") and passed
	passed = assert_equal(stats_data.luck, 10, "默认幸运应该是10") and passed
	
	end_test(passed)
	teardown()

## 测试: 设置属性
func test_set_properties() -> void:
	setup()
	start_test("设置属性")
	
	stats_data.level = 5
	stats_data.strength = 15
	stats_data.max_health = 150.0
	stats_data.move_speed = 140.0
	
	var passed = assert_equal(stats_data.level, 5, "等级应该设置为5")
	passed = assert_equal(stats_data.strength, 15, "力量应该设置为15") and passed
	passed = assert_almost_equal(stats_data.max_health, 150.0, 0.0001, "最大生命值应该设置为150") and passed
	passed = assert_almost_equal(stats_data.move_speed, 140.0, 0.0001, "移动速度应该设置为140") and passed
	
	end_test(passed)
	teardown()

## 测试: 深拷贝
func test_duplicate_stats() -> void:
	setup()
	start_test("深拷贝")
	
	# 设置一些值
	stats_data.level = 3
	stats_data.strength = 12
	stats_data.max_health = 120.0
	stats_data.res_fire = 10.0
	
	var copy = stats_data.duplicate_stats()
	
	var passed = assert_not_null(copy, "拷贝应该成功创建")
	passed = assert_true(copy is StatsData, "拷贝应该是StatsData类型") and passed
	passed = assert_equal(copy.level, 3, "拷贝的等级应该相同") and passed
	passed = assert_equal(copy.strength, 12, "拷贝的力量应该相同") and passed
	passed = assert_almost_equal(copy.max_health, 120.0, 0.0001, "拷贝的最大生命值应该相同") and passed
	passed = assert_almost_equal(copy.res_fire, 10.0, 0.0001, "拷贝的火焰抗性应该相同") and passed
	
	# 修改原对象，拷贝应该不受影响
	stats_data.level = 4
	passed = assert_equal(copy.level, 3, "修改原对象后拷贝应该不受影响") and passed
	
	end_test(passed)
	teardown()

## 测试: 核心属性
func test_core_attributes() -> void:
	setup()
	start_test("核心属性")
	
	stats_data.strength = 20
	stats_data.agility = 18
	stats_data.intelligence = 16
	stats_data.vitality = 22
	stats_data.luck = 12
	
	var passed = assert_equal(stats_data.strength, 20, "力量设置正确")
	passed = assert_equal(stats_data.agility, 18, "敏捷设置正确") and passed
	passed = assert_equal(stats_data.intelligence, 16, "智力设置正确") and passed
	passed = assert_equal(stats_data.vitality, 22, "体质设置正确") and passed
	passed = assert_equal(stats_data.luck, 12, "幸运设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 战斗属性
func test_combat_stats() -> void:
	setup()
	start_test("战斗属性")
	
	stats_data.physical_damage = 25.0
	stats_data.magic_damage = 15.0
	stats_data.fire_damage = 10.0
	stats_data.attack_speed = 1.2
	stats_data.crit_chance = 0.08
	stats_data.crit_damage = 1.6
	stats_data.accuracy = 0.98
	
	var passed = assert_almost_equal(stats_data.physical_damage, 25.0, 0.0001, "物理伤害设置正确")
	passed = assert_almost_equal(stats_data.magic_damage, 15.0, 0.0001, "魔法伤害设置正确") and passed
	passed = assert_almost_equal(stats_data.fire_damage, 10.0, 0.0001, "火焰伤害设置正确") and passed
	passed = assert_almost_equal(stats_data.attack_speed, 1.2, 0.0001, "攻击速度设置正确") and passed
	passed = assert_almost_equal(stats_data.crit_chance, 0.08, 0.0001, "暴击率设置正确") and passed
	passed = assert_almost_equal(stats_data.crit_damage, 1.6, 0.0001, "暴击伤害设置正确") and passed
	passed = assert_almost_equal(stats_data.accuracy, 0.98, 0.0001, "命中率设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 防御属性
func test_defense_stats() -> void:
	setup()
	start_test("防御属性")
	
	stats_data.armor = 15.0
	stats_data.magic_resist = 8.0
	stats_data.dodge_chance = 0.06
	stats_data.block_amount = 5.0
	stats_data.block_reduction = 0.6
	stats_data.physical_damage_reduction = 0.1
	stats_data.magic_damage_reduction = 0.05
	
	var passed = assert_almost_equal(stats_data.armor, 15.0, 0.0001, "护甲设置正确")
	passed = assert_almost_equal(stats_data.magic_resist, 8.0, 0.0001, "魔法抗性设置正确") and passed
	passed = assert_almost_equal(stats_data.dodge_chance, 0.06, 0.0001, "闪避率设置正确") and passed
	passed = assert_almost_equal(stats_data.block_amount, 5.0, 0.0001, "格挡值设置正确") and passed
	passed = assert_almost_equal(stats_data.block_reduction, 0.6, 0.0001, "格挡减伤设置正确") and passed
	passed = assert_almost_equal(stats_data.physical_damage_reduction, 0.1, 0.0001, "物理伤害减免设置正确") and passed
	passed = assert_almost_equal(stats_data.magic_damage_reduction, 0.05, 0.0001, "魔法伤害减免设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 元素抗性
func test_elemental_resistances() -> void:
	setup()
	start_test("元素抗性")
	
	stats_data.res_fire = 15.0
	stats_data.res_ice = -10.0
	stats_data.res_lightning = 5.0
	stats_data.res_poison = 0.0
	stats_data.res_dark = -5.0
	stats_data.res_holy = 20.0
	stats_data.res_all = 3.0
	
	var passed = assert_almost_equal(stats_data.res_fire, 15.0, 0.0001, "火焰抗性设置正确")
	passed = assert_almost_equal(stats_data.res_ice, -10.0, 0.0001, "冰霜抗性设置正确") and passed
	passed = assert_almost_equal(stats_data.res_lightning, 5.0, 0.0001, "雷电抗性设置正确") and passed
	passed = assert_almost_equal(stats_data.res_poison, 0.0, 0.0001, "毒素抗性设置正确") and passed
	passed = assert_almost_equal(stats_data.res_dark, -5.0, 0.0001, "暗影抗性设置正确") and passed
	passed = assert_almost_equal(stats_data.res_holy, 20.0, 0.0001, "神圣抗性设置正确") and passed
	passed = assert_almost_equal(stats_data.res_all, 3.0, 0.0001, "全元素抗性设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 移动属性
func test_movement_stats() -> void:
	setup()
	start_test("移动属性")
	
	stats_data.move_speed = 130.0
	stats_data.sprint_speed = 195.0
	stats_data.dash_speed = 200.0
	stats_data.dash_distance = 120.0
	
	var passed = assert_almost_equal(stats_data.move_speed, 130.0, 0.0001, "移动速度设置正确")
	passed = assert_almost_equal(stats_data.sprint_speed, 195.0, 0.0001, "冲刺速度设置正确") and passed
	passed = assert_almost_equal(stats_data.dash_speed, 200.0, 0.0001, "闪避速度设置正确") and passed
	passed = assert_almost_equal(stats_data.dash_distance, 120.0, 0.0001, "闪避距离设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 回复属性
func test_regeneration_stats() -> void:
	setup()
	start_test("回复属性")
	
	stats_data.health_regen = 1.5
	stats_data.mana_regen = 3.0
	stats_data.stamina_regen = 12.0
	
	var passed = assert_almost_equal(stats_data.health_regen, 1.5, 0.0001, "生命回复设置正确")
	passed = assert_almost_equal(stats_data.mana_regen, 3.0, 0.0001, "魔力回复设置正确") and passed
	passed = assert_almost_equal(stats_data.stamina_regen, 12.0, 0.0001, "耐力回复设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 特殊属性
func test_special_stats() -> void:
	setup()
	start_test("特殊属性")
	
	stats_data.life_steal = 0.08
	stats_data.mana_steal = 0.05
	stats_data.cooldown_reduction = 0.15
	stats_data.skill_range = 1.2
	stats_data.projectile_count = 2
	stats_data.pierce_count = 3
	
	var passed = assert_almost_equal(stats_data.life_steal, 0.08, 0.0001, "生命偷取设置正确")
	passed = assert_almost_equal(stats_data.mana_steal, 0.05, 0.0001, "法力偷取设置正确") and passed
	passed = assert_almost_equal(stats_data.cooldown_reduction, 0.15, 0.0001, "冷却缩减设置正确") and passed
	passed = assert_almost_equal(stats_data.skill_range, 1.2, 0.0001, "技能范围设置正确") and passed
	passed = assert_equal(stats_data.projectile_count, 2, "额外抛射物数量设置正确") and passed
	passed = assert_equal(stats_data.pierce_count, 3, "穿透次数设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 背包属性
func test_inventory_stats() -> void:
	setup()
	start_test("背包属性")
	
	stats_data.max_weight = 120.0
	stats_data.inventory_slots = 25
	
	var passed = assert_almost_equal(stats_data.max_weight, 120.0, 0.0001, "最大负重设置正确")
	passed = assert_equal(stats_data.inventory_slots, 25, "背包格子数设置正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 幸运影响系数
func test_luck_scaling() -> void:
	setup()
	start_test("幸运影响系数")
	
	stats_data.luck_crit_bonus = 0.002
	stats_data.luck_dodge_bonus = 0.0008
	stats_data.luck_drop_bonus = 0.015
	stats_data.luck_quality_bonus = 0.003
	
	var passed = assert_almost_equal(stats_data.luck_crit_bonus, 0.002, 0.0001, "幸运暴击加成设置正确")
	passed = assert_almost_equal(stats_data.luck_dodge_bonus, 0.0008, 0.0001, "幸运闪避加成设置正确") and passed
	passed = assert_almost_equal(stats_data.luck_drop_bonus, 0.015, 0.0001, "幸运掉落加成设置正确") and passed
	passed = assert_almost_equal(stats_data.luck_quality_bonus, 0.003, 0.0001, "幸运品质加成设置正确") and passed
	
	end_test(passed)
	teardown()