## StatsComponent测试
## 测试属性组件的核心功能
extends TestFramework

var stats_component: StatsComponent
var mock_base_stats: StatsData

func _init() -> void:
	super._init("StatsComponent测试")

## 设置测试环境
func setup() -> void:
	stats_component = StatsComponent.new()
	mock_base_stats = StatsData.new()
	
	# 设置基础属性
	mock_base_stats.level = 1
	mock_base_stats.strength = 10
	mock_base_stats.agility = 10
	mock_base_stats.intelligence = 10
	mock_base_stats.vitality = 10
	mock_base_stats.luck = 10
	mock_base_stats.max_health = 100.0
	mock_base_stats.max_mana = 50.0
	mock_base_stats.max_stamina = 100.0
	mock_base_stats.physical_damage = 10.0
	mock_base_stats.armor = 10.0
	
	stats_component.base_stats = mock_base_stats

## 清理测试环境
func teardown() -> void:
	if stats_component:
		stats_component.queue_free()
	if mock_base_stats:
		mock_base_stats = null

## 运行所有测试
func run_all_tests() -> void:
	test_initialization()
	test_stat_calculation()
	test_modifier_management()
	test_damage_system()
	test_healing_system()
	test_experience_system()
	test_stat_point_allocation()
	test_serialization()
	
	print_report()

## 测试: 初始化
func test_initialization() -> void:
	setup()
	start_test("初始化")
	
	# 手动调用 _ready 来初始化
	stats_component._ready()
	
	# 修正期望值：max_health = 100 + vitality*10 = 100 + 100 = 200
	# max_mana = 50 + intelligence*5 = 50 + 50 = 100
	var passed = assert_not_null(stats_component.base_stats, "基础属性应该设置")
	passed = assert_equal(stats_component.current_health, 200.0, "初始生命值应该是200 (100基础 + 10体质*10)") and passed
	passed = assert_equal(stats_component.current_mana, 100.0, "初始魔力值应该是100 (50基础 + 10智力*5)") and passed
	passed = assert_equal(stats_component.current_stamina, 100.0, "初始耐力值应该是100") and passed
	
	end_test(passed)
	teardown()

## 测试: 属性计算
func test_stat_calculation() -> void:
	setup()
	stats_component._ready()
	start_test("属性计算")
	
	# 测试基础属性获取
	var strength = stats_component.get_stat(StatModifier.StatType.STRENGTH)
	var passed = assert_equal(strength, 10, "力量应该是10")
	
	# 测试派生属性计算 (力量影响物理攻击)
	var phys_damage = stats_component.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)
	passed = assert_equal(phys_damage, 30.0, "物理攻击应该是10(基础) + 10*2(力量加成) = 30") and passed
	
	# 测试智力影响魔力
	var max_mana = stats_component.get_stat(StatModifier.StatType.MAX_MANA)
	passed = assert_equal(max_mana, 100.0, "最大魔力应该是50(基础) + 10*5(智力加成) = 100") and passed
	
	end_test(passed)
	teardown()

## 测试: 修正器管理
func test_modifier_management() -> void:
	setup()
	stats_component._ready()
	start_test("修正器管理")
	
	# 添加固定值修正器
	var strength_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5, "test_buff")
	stats_component.add_modifier(strength_mod)
	
	var strength = stats_component.get_stat(StatModifier.StatType.STRENGTH)
	var passed = assert_equal(strength, 15, "力量应该是10 + 5 = 15")
	
	# 添加百分比修正器
	var damage_mod = StatModifier.create_percent(StatModifier.StatType.PHYSICAL_DAMAGE, 0.5, "damage_boost")
	stats_component.add_modifier(damage_mod)
	
	var phys_damage = stats_component.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)
	passed = assert_equal(phys_damage, 60.0, "物理攻击应该是40 * 1.5 = 60") and passed
	
	# 移除修正器
	stats_component.remove_modifier(strength_mod)
	strength = stats_component.get_stat(StatModifier.StatType.STRENGTH)
	passed = assert_equal(strength, 10, "移除修正器后力量应该恢复到10") and passed
	
	# 按来源移除
	stats_component.remove_modifiers_by_source("damage_boost")
	phys_damage = stats_component.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)
	passed = assert_equal(phys_damage, 30.0, "移除来源后物理攻击应该恢复到30") and passed
	
	end_test(passed)
	teardown()

## 测试: 伤害系统
func test_damage_system() -> void:
	setup()
	stats_component._ready()
	start_test("伤害系统")
	
	# 测试基础伤害 (护甲20, 减伤 = 20/(20+100) = 0.1667, 最终伤害 = 20 * 0.8333 ≈ 16.67)
	var damage_result = stats_component.take_damage(20.0, "physical")
	var passed = assert_almost_equal(damage_result.final_damage, 16.67, 0.01, "护甲20应该将20点伤害减为16.67")
	passed = assert_almost_equal(stats_component.current_health, 183.33, 0.01, "生命值应该减少16.67") and passed
	
	# 测试第二次伤害 (护甲减伤不变)
	damage_result = stats_component.take_damage(20.0, "physical")
	passed = assert_almost_equal(damage_result.final_damage, 16.67, 0.01, "第二次伤害也应该被护甲减伤") and passed
	passed = assert_almost_equal(stats_component.current_health, 166.67, 0.01, "生命值应该再减少16.67") and passed
	
	# 测试治疗
	stats_component.heal(50.0)
	passed = assert_almost_equal(stats_component.current_health, 200.0, 0.01, "治疗应该恢复到最大生命值") and passed
	
	end_test(passed)
	teardown()

## 测试: 治疗系统
func test_healing_system() -> void:
	setup()
	stats_component._ready()
	start_test("治疗系统")
	
	# 先受伤 (魔法伤害会被魔抗减伤: 5/(5+100) ≈ 0.0476, 最终伤害 ≈ 30 * 0.9524 ≈ 28.57)
	var damage_result = stats_component.take_damage(30.0, "magic")  # 魔法伤害会被魔抗减伤
	var passed = assert_almost_equal(stats_component.current_health, 171.43, 0.01, "魔法伤害会被魔抗减伤，30点伤害减为约28.57")
	
	# 治疗
	stats_component.heal(20.0)
	passed = assert_almost_equal(stats_component.current_health, 191.43, 0.01, "治疗20后生命值应该是191.43") and passed
	
	# 超量治疗
	stats_component.heal(50.0)
	passed = assert_almost_equal(stats_component.current_health, 200.0, 0.001, "超量治疗应该限制在最大值200") and passed
	
	# 魔力恢复
	stats_component.consume_mana(20.0)
	passed = assert_almost_equal(stats_component.current_mana, 80.0, 0.001, "消耗魔力后应该是80 (100-20)") and passed
	
	stats_component.restore_mana(15.0)
	passed = assert_almost_equal(stats_component.current_mana, 95.0, 0.001, "恢复魔力后应该是95") and passed
	
	end_test(passed)
	teardown()

## 测试: 经验系统
func test_experience_system() -> void:
	setup()
	stats_component._ready()
	start_test("经验系统")
	
	var initial_level = stats_component.get_level()
	var passed = assert_equal(initial_level, 1, "初始等级应该是1")
	
	# 获得经验
	stats_component.gain_experience(50)
	passed = assert_equal(stats_component.get_experience(), 50, "经验值应该是50") and passed
	
	# 获得足够升级的经验 (假设升级需要100经验)
	stats_component.gain_experience(60)
	passed = assert_equal(stats_component.get_level(), 2, "应该升级到2级") and passed
	passed = assert_equal(stats_component.get_available_stat_points(), 5, "升级应该获得5属性点") and passed
	
	end_test(passed)
	teardown()

## 测试: 属性点分配
func test_stat_point_allocation() -> void:
	setup()
	stats_component._ready()
	
	# 先升级获得属性点
	stats_component.gain_experience(100)
	
	start_test("属性点分配")
	
	var initial_points = stats_component.get_available_stat_points()
	var passed = assert_equal(initial_points, 5, "应该有5属性点")
	
	# 分配力量
	var success = stats_component.allocate_stat_point(StatModifier.StatType.STRENGTH, 2)
	passed = assert_true(success, "分配属性点应该成功") and passed
	passed = assert_equal(stats_component.get_available_stat_points(), 3, "剩余属性点应该是3") and passed
	
	# 验证属性增加
	var strength = stats_component.get_stat(StatModifier.StatType.STRENGTH)
	passed = assert_equal(strength, 12, "力量应该是10 + 2 = 12") and passed
	
	# 分配无效属性点
	success = stats_component.allocate_stat_point(StatModifier.StatType.MAX_HEALTH, 1)
	passed = assert_false(success, "只能分配核心属性点") and passed
	
	end_test(passed)
	teardown()

## 测试: 序列化
func test_serialization() -> void:
	setup()
	stats_component._ready()
	
	# 设置一些状态
	stats_component.take_damage(20.0)
	stats_component.add_modifier(StatModifier.create_flat(StatModifier.StatType.STRENGTH, 3, "test"))
	
	start_test("序列化")
	
	# 序列化
	var save_data = stats_component.to_dict()
	var passed = assert_not_null(save_data, "序列化应该返回有效数据")
	passed = assert_true(save_data.has("current_health"), "应该包含当前生命值") and passed
	
	# 创建新实例并反序列化
	var new_component = StatsComponent.new()
	new_component.base_stats = StatsData.new()
	new_component.from_dict(save_data)
	
	# 验证状态恢复
	passed = assert_almost_equal(new_component.current_health, stats_component.current_health, 0.001, "生命值应该正确恢复") and passed
	
	# 验证修正器恢复
	var strength = new_component.get_stat(StatModifier.StatType.STRENGTH)
	passed = assert_equal(strength, 13, "修正器应该正确恢复") and passed
	
	new_component.queue_free()
	
	end_test(passed)
	teardown()