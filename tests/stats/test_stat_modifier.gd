## StatModifier测试
## 测试属性修正器的核心功能
extends TestFramework

var stat_modifier: StatModifier

func _init() -> void:
	super._init("StatModifier测试")

## 设置测试环境
func setup() -> void:
	stat_modifier = StatModifier.new()

## 清理测试环境
func teardown() -> void:
	if stat_modifier:
		stat_modifier = null

## 运行所有测试
func run_all_tests() -> void:
	test_create_stat_modifier()
	test_modifier_types()
	test_factory_methods_flat()
	test_factory_methods_percent()
	test_factory_methods_override()
	test_stat_types()
	test_tags_system()
	test_duration_and_priority()
	test_description_generation()
	test_property_access()
	
	print_report()

## 测试: 创建StatModifier实例
func test_create_stat_modifier() -> void:
	setup()
	start_test("创建StatModifier实例")
	
	var passed = assert_not_null(stat_modifier, "StatModifier实例应该成功创建")
	passed = assert_true(stat_modifier is Resource, "StatModifier应该是Resource类型") and passed
	
	end_test(passed)
	teardown()

## 测试: 修正器类型
func test_modifier_types() -> void:
	setup()
	start_test("修正器类型")
	
	stat_modifier.modifier_type = StatModifier.ModifierType.FLAT
	var passed = assert_equal(stat_modifier.modifier_type, StatModifier.ModifierType.FLAT, "应该能设置FLAT类型")
	
	stat_modifier.modifier_type = StatModifier.ModifierType.PERCENT
	passed = assert_equal(stat_modifier.modifier_type, StatModifier.ModifierType.PERCENT, "应该能设置PERCENT类型") and passed
	
	stat_modifier.modifier_type = StatModifier.ModifierType.OVERRIDE
	passed = assert_equal(stat_modifier.modifier_type, StatModifier.ModifierType.OVERRIDE, "应该能设置OVERRIDE类型") and passed
	
	end_test(passed)
	teardown()

## 测试: 工厂方法 - 固定值修正器
func test_factory_methods_flat() -> void:
	setup()
	start_test("工厂方法 - 固定值修正器")
	
	var mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "test_source")
	
	var passed = assert_not_null(mod, "工厂方法应该返回有效对象")
	passed = assert_equal(mod.stat_type, StatModifier.StatType.STRENGTH, "属性类型应该正确设置") and passed
	passed = assert_equal(mod.modifier_type, StatModifier.ModifierType.FLAT, "修正器类型应该是FLAT") and passed
	passed = assert_almost_equal(mod.value, 10.0, 0.0001, "修正值应该正确设置") and passed
	passed = assert_equal(mod.source_id, "test_source", "来源ID应该正确设置") and passed
	
	end_test(passed)
	teardown()

## 测试: 工厂方法 - 百分比修正器
func test_factory_methods_percent() -> void:
	setup()
	start_test("工厂方法 - 百分比修正器")
	
	var mod = StatModifier.create_percent(StatModifier.StatType.MAX_HEALTH, 0.25, "health_boost")
	
	var passed = assert_not_null(mod, "工厂方法应该返回有效对象")
	passed = assert_equal(mod.stat_type, StatModifier.StatType.MAX_HEALTH, "属性类型应该正确设置") and passed
	passed = assert_equal(mod.modifier_type, StatModifier.ModifierType.PERCENT, "修正器类型应该是PERCENT") and passed
	passed = assert_almost_equal(mod.value, 0.25, 0.0001, "修正值应该正确设置") and passed
	passed = assert_equal(mod.source_id, "health_boost", "来源ID应该正确设置") and passed
	
	end_test(passed)
	teardown()

## 测试: 工厂方法 - 覆盖值修正器
func test_factory_methods_override() -> void:
	setup()
	start_test("工厂方法 - 覆盖值修正器")
	
	var mod = StatModifier.create_override(StatModifier.StatType.MOVE_SPEED, 200.0, "speed_override")
	
	var passed = assert_not_null(mod, "工厂方法应该返回有效对象")
	passed = assert_equal(mod.stat_type, StatModifier.StatType.MOVE_SPEED, "属性类型应该正确设置") and passed
	passed = assert_equal(mod.modifier_type, StatModifier.ModifierType.OVERRIDE, "修正器类型应该是OVERRIDE") and passed
	passed = assert_almost_equal(mod.value, 200.0, 0.0001, "修正值应该正确设置") and passed
	passed = assert_equal(mod.source_id, "speed_override", "来源ID应该正确设置") and passed
	
	end_test(passed)
	teardown()

## 测试: 属性类型枚举
func test_stat_types() -> void:
	setup()
	start_test("属性类型枚举")
	
	# 测试一些关键的属性类型
	stat_modifier.stat_type = StatModifier.StatType.STRENGTH
	var passed = assert_equal(stat_modifier.stat_type, StatModifier.StatType.STRENGTH, "应该能设置STRENGTH类型")
	
	stat_modifier.stat_type = StatModifier.StatType.MAX_HEALTH
	passed = assert_equal(stat_modifier.stat_type, StatModifier.StatType.MAX_HEALTH, "应该能设置MAX_HEALTH类型") and passed
	
	stat_modifier.stat_type = StatModifier.StatType.PHYSICAL_DAMAGE
	passed = assert_equal(stat_modifier.stat_type, StatModifier.StatType.PHYSICAL_DAMAGE, "应该能设置PHYSICAL_DAMAGE类型") and passed
	
	stat_modifier.stat_type = StatModifier.StatType.RES_FIRE
	passed = assert_equal(stat_modifier.stat_type, StatModifier.StatType.RES_FIRE, "应该能设置RES_FIRE类型") and passed
	
	end_test(passed)
	teardown()

## 测试: 标签系统
func test_tags_system() -> void:
	setup()
	start_test("标签系统")
	
	# 测试添加标签
	stat_modifier.add_tag("buff")
	stat_modifier.add_tag("temporary")
	stat_modifier.add_tag("equipment")
	
	var passed = assert_contains(stat_modifier.tags, "buff", "应该包含buff标签")
	passed = assert_contains(stat_modifier.tags, "temporary", "应该包含temporary标签") and passed
	passed = assert_contains(stat_modifier.tags, "equipment", "应该包含equipment标签") and passed
	passed = assert_equal(stat_modifier.tags.size(), 3, "应该有3个标签") and passed
	
	# 测试重复添加标签（应该不重复）
	stat_modifier.add_tag("buff")
	passed = assert_equal(stat_modifier.tags.size(), 3, "重复添加标签不应该增加数量") and passed
	
	end_test(passed)
	teardown()

## 测试: 持续时间和优先级
func test_duration_and_priority() -> void:
	setup()
	start_test("持续时间和优先级")
	
	# 测试默认值
	var passed = assert_almost_equal(stat_modifier.duration, -1.0, 0.0001, "默认持续时间应该是-1（永久）")
	passed = assert_equal(stat_modifier.priority, 0, "默认优先级应该是0") and passed
	
	# 测试设置持续时间
	stat_modifier.set_duration(30.0)
	passed = assert_almost_equal(stat_modifier.duration, 30.0, 0.0001, "持续时间应该设置为30秒") and passed
	
	# 测试设置优先级
	stat_modifier.set_priority(5)
	passed = assert_equal(stat_modifier.priority, 5, "优先级应该设置为5") and passed
	
	# 测试链式调用
	var mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0).set_duration(60.0).set_priority(10).add_tag("test")
	passed = assert_almost_equal(mod.duration, 60.0, 0.0001, "链式调用应该设置持续时间") and passed
	passed = assert_equal(mod.priority, 10, "链式调用应该设置优先级") and passed
	passed = assert_contains(mod.tags, "test", "链式调用应该添加标签") and passed
	
	end_test(passed)
	teardown()

## 测试: 描述文本生成
func test_description_generation() -> void:
	setup()
	start_test("描述文本生成")
	
	# 测试固定值修正器
	var flat_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 15.0, "sword")
	var passed = assert_equal(flat_mod.get_description(), "+15.0 STRENGTH", "固定值修正器描述应该正确")
	
	# 测试百分比修正器
	var percent_mod = StatModifier.create_percent(StatModifier.StatType.MAX_HEALTH, 0.2, "potion")
	passed = assert_equal(percent_mod.get_description(), "+20.0% MAX_HEALTH", "百分比修正器描述应该正确") and passed
	
	# 测试覆盖值修正器
	var override_mod = StatModifier.create_override(StatModifier.StatType.MOVE_SPEED, 180.0, "boots")
	passed = assert_equal(override_mod.get_description(), "= 180.0 MOVE_SPEED", "覆盖值修正器描述应该正确") and passed
	
	end_test(passed)
	teardown()

## 测试: 属性访问
func test_property_access() -> void:
	setup()
	start_test("属性访问")
	
	# 测试设置和获取所有属性
	stat_modifier.stat_type = StatModifier.StatType.AGILITY
	stat_modifier.modifier_type = StatModifier.ModifierType.FLAT
	stat_modifier.value = 8.0
	stat_modifier.source_id = "test_source"
	stat_modifier.duration = 45.0
	stat_modifier.priority = 3
	
	var passed = assert_equal(stat_modifier.stat_type, StatModifier.StatType.AGILITY, "stat_type应该正确设置")
	passed = assert_equal(stat_modifier.modifier_type, StatModifier.ModifierType.FLAT, "modifier_type应该正确设置") and passed
	passed = assert_almost_equal(stat_modifier.value, 8.0, 0.0001, "value应该正确设置") and passed
	passed = assert_equal(stat_modifier.source_id, "test_source", "source_id应该正确设置") and passed
	passed = assert_almost_equal(stat_modifier.duration, 45.0, 0.0001, "duration应该正确设置") and passed
	passed = assert_equal(stat_modifier.priority, 3, "priority应该正确设置") and passed
	
	end_test(passed)
	teardown()