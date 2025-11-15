## StatusEffectManager 测试
## 测试状态效果管理器
extends TestFramework

func _init() -> void:
	super._init("StatusEffectManager测试")

## 运行所有测试
func run_all_tests() -> void:
	test_register_effect()
	test_add_effect()
	test_remove_effect()
	test_effect_stacking()
	test_dot_effect()
	test_hot_effect()
	test_buff_modifiers()
	test_shield_system()
	test_cleanse_debuffs()
	test_element_tracking()
	test_serialization()
	
	print_report()

## 测试: 注册效果
func test_register_effect() -> void:
	start_test("注册效果")
	
	var effect_data = StatusEffectData.new()
	effect_data.effect_id = "test_buff"
	effect_data.effect_name = "测试Buff"
	effect_data.duration = 10.0
	
	var result = StatusEffectManager.register_effect(effect_data)
	
	var passed = assert_true(result, "应成功注册效果")
	passed = assert_true(StatusEffectManager.registered_effects.has("test_buff"), "效果应在注册表中") and passed
	
	end_test(passed)

## 测试: 添加效果
func test_add_effect() -> void:
	start_test("添加效果")
	
	# 注册效果
	var effect_data = StatusEffectData.new()
	effect_data.effect_id = "test_poison"
	effect_data.effect_name = "中毒"
	effect_data.effect_type = StatusEffectData.EffectType.DOT
	effect_data.duration = 5.0
	StatusEffectManager.register_effect(effect_data)
	
	# 创建实体
	var entity = Node.new()
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	# 添加效果
	var instance = manager.add_effect("test_poison")
	
	var passed = assert_not_null(instance, "应返回效果实例")
	passed = assert_true(manager.has_effect("test_poison"), "应有中毒效果") and passed
	passed = assert_almost_equal(instance.remaining_time, 5.0, 0.1, "持续时间应为5秒") and passed
	
	entity.free()
	end_test(passed)

## 测试: 移除效果
func test_remove_effect() -> void:
	start_test("移除效果")
	
	# 注册效果
	var effect_data = StatusEffectData.new()
	effect_data.effect_id = "test_remove"
	effect_data.duration = 10.0
	StatusEffectManager.register_effect(effect_data)
	
	var entity = Node.new()
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	manager.add_effect("test_remove")
	var passed = assert_true(manager.has_effect("test_remove"), "应有效果")
	
	manager.remove_effect("test_remove")
	passed = assert_false(manager.has_effect("test_remove"), "效果应被移除") and passed
	
	entity.free()
	end_test(passed)

## 测试: 效果叠加
func test_effect_stacking() -> void:
	start_test("效果叠加")
	
	# 测试叠加层数
	var stack_effect = StatusEffectData.new()
	stack_effect.effect_id = "test_stack"
	stack_effect.stack_type = StatusEffectData.StackType.STACK_COUNT
	stack_effect.max_stacks = 5
	stack_effect.duration = 10.0
	StatusEffectManager.register_effect(stack_effect)
	
	var entity = Node.new()
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	# 添加多次
	manager.add_effect("test_stack")
	manager.add_effect("test_stack")
	manager.add_effect("test_stack")
	
	var stacks = manager.get_effect_stacks("test_stack")
	var passed = assert_equal(stacks, 3, "应叠加到3层")
	
	# 测试刷新时间
	var refresh_effect = StatusEffectData.new()
	refresh_effect.effect_id = "test_refresh"
	refresh_effect.stack_type = StatusEffectData.StackType.REFRESH
	refresh_effect.duration = 5.0
	StatusEffectManager.register_effect(refresh_effect)
	
	manager.add_effect("test_refresh")
	var instance1 = manager.get_effect_instance("test_refresh")
	var time1 = instance1.remaining_time
	
	# 模拟时间流逝
	instance1.remaining_time = 2.0
	
	# 再次添加，应刷新时间
	manager.add_effect("test_refresh")
	var time2 = instance1.remaining_time
	
	passed = assert_greater(time2, time1, "时间应被刷新") and passed
	
	entity.free()
	end_test(passed)

## 测试: DOT效果
func test_dot_effect() -> void:
	start_test("DOT效果")
	
	# 创建DOT效果
	var dot_effect = StatusEffectData.new()
	dot_effect.effect_id = "test_dot"
	dot_effect.effect_type = StatusEffectData.EffectType.DOT
	dot_effect.duration = 5.0
	dot_effect.tick_interval = 1.0
	dot_effect.tick_value = 10.0
	dot_effect.tick_damage_type = DamageInfo.DamageType.POISON
	StatusEffectManager.register_effect(dot_effect)
	
	var entity = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.max_health = 100.0
	stats.base_stats = base_stats
	entity.add_child(stats)
	
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	entity.add_child(combat)
	
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	var initial_health = stats.get_stat("health")
	
	# 添加DOT
	var instance = manager.add_effect("test_dot")
	
	# 手动触发tick
	instance.tick()
	
	var current_health = stats.get_stat("health")
	var passed = assert_less(current_health, initial_health, "应造成持续伤害")
	
	entity.free()
	end_test(passed)

## 测试: HOT效果
func test_hot_effect() -> void:
	start_test("HOT效果")
	
	# 创建HOT效果
	var hot_effect = StatusEffectData.new()
	hot_effect.effect_id = "test_hot"
	hot_effect.effect_type = StatusEffectData.EffectType.HOT
	hot_effect.duration = 5.0
	hot_effect.tick_interval = 1.0
	hot_effect.tick_value = 10.0
	StatusEffectManager.register_effect(hot_effect)
	
	var entity = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.max_health = 100.0
	stats.base_stats = base_stats
	entity.add_child(stats)
	
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	entity.add_child(combat)
	
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	# 先受伤
	stats.take_damage(50.0)
	var damaged_health = stats.get_stat("health")
	
	# 添加HOT
	var instance = manager.add_effect("test_hot")
	
	# 手动触发tick
	instance.tick()
	
	var current_health = stats.get_stat("health")
	var passed = assert_greater(current_health, damaged_health, "应持续治疗")
	
	entity.free()
	end_test(passed)

## 测试: Buff属性修改
func test_buff_modifiers() -> void:
	start_test("Buff属性修改")
	
	# 创建力量Buff
	var strength_buff = StatusEffectData.new()
	strength_buff.effect_id = "test_strength"
	strength_buff.effect_type = StatusEffectData.EffectType.BUFF
	strength_buff.duration = 10.0
	
	var modifier = StatModifier.new()
	modifier.stat_name = "attack"
	modifier.value = 20.0
	modifier.modifier_type = StatModifier.ModifierType.FLAT
	strength_buff.modifiers.append(modifier)
	StatusEffectManager.register_effect(strength_buff)
	
	var entity = Node.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.physical_damage = 10.0
	stats.base_stats = base_stats
	entity.add_child(stats)
	
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	var initial_attack = stats.get_stat("attack")
	
	# 添加Buff
	manager.add_effect("test_strength")
	
	var buffed_attack = stats.get_stat("attack")
	var passed = assert_almost_equal(buffed_attack, initial_attack + 20.0, 0.1, "攻击力应增加20")
	
	# 移除Buff
	manager.remove_effect("test_strength")
	
	var final_attack = stats.get_stat("attack")
	passed = assert_almost_equal(final_attack, initial_attack, 0.1, "移除后攻击力应恢复") and passed
	
	entity.free()
	end_test(passed)

## 测试: 护盾系统
func test_shield_system() -> void:
	start_test("护盾系统")
	
	var entity = Node.new()
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	# 添加护盾
	manager.add_shield(100.0)
	var passed = assert_almost_equal(manager.get_shield_amount(), 100.0, 0.1, "护盾值应为100")
	
	# 消耗护盾
	var consumed = manager.consume_shield(30.0)
	passed = assert_almost_equal(consumed, 30.0, 0.1, "应消耗30点护盾") and passed
	passed = assert_almost_equal(manager.get_shield_amount(), 70.0, 0.1, "剩余护盾应为70") and passed
	
	# 超额消耗
	consumed = manager.consume_shield(100.0)
	passed = assert_almost_equal(consumed, 70.0, 0.1, "应消耗剩余的70点") and passed
	passed = assert_almost_equal(manager.get_shield_amount(), 0.0, 0.1, "护盾应为0") and passed
	
	entity.free()
	end_test(passed)

## 测试: 净化负面效果
func test_cleanse_debuffs() -> void:
	start_test("净化负面效果")
	
	# 注册多个负面效果
	var poison = StatusEffectData.new()
	poison.effect_id = "test_cleanse_poison"
	poison.effect_type = StatusEffectData.EffectType.DOT
	poison.can_be_cleansed = true
	StatusEffectManager.register_effect(poison)
	
	var slow = StatusEffectData.new()
	slow.effect_id = "test_cleanse_slow"
	slow.effect_type = StatusEffectData.EffectType.DEBUFF
	slow.can_be_cleansed = true
	StatusEffectManager.register_effect(slow)
	
	var entity = Node.new()
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	# 添加多个负面效果
	manager.add_effect("test_cleanse_poison")
	manager.add_effect("test_cleanse_slow")
	
	var passed = assert_equal(manager.active_effects.size(), 2, "应有2个负面效果")
	
	# 净化
	var cleansed = manager.cleanse_debuffs()
	
	passed = assert_equal(cleansed, 2, "应净化2个效果") and passed
	passed = assert_equal(manager.active_effects.size(), 0, "所有负面效果应被清除") and passed
	
	entity.free()
	end_test(passed)

## 测试: 元素追踪
func test_element_tracking() -> void:
	start_test("元素追踪")
	
	# 创建带元素的效果
	var fire_effect = StatusEffectData.new()
	fire_effect.effect_id = "test_element_fire"
	fire_effect.element = "fire"
	fire_effect.duration = 5.0
	StatusEffectManager.register_effect(fire_effect)
	
	var entity = Node.new()
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	# 无元素状态
	var passed = assert_equal(manager.get_active_element(), "", "初始无元素")
	
	# 添加火元素
	manager.add_effect("test_element_fire")
	passed = assert_equal(manager.get_active_element(), "fire", "应有火元素") and passed
	
	entity.free()
	end_test(passed)

## 测试: 序列化
func test_serialization() -> void:
	start_test("序列化")
	
	# 注册效果
	var effect_data = StatusEffectData.new()
	effect_data.effect_id = "test_serialize"
	effect_data.duration = 10.0
	StatusEffectManager.register_effect(effect_data)
	
	var entity = Node.new()
	var manager = StatusEffectManager.new()
	manager.name = "StatusEffectManager"
	entity.add_child(manager)
	
	# 添加效果和护盾
	manager.add_effect("test_serialize")
	manager.add_shield(50.0)
	
	# 序列化
	var data = manager.to_dict()
	
	var passed = assert_true(data.has("effects"), "应包含effects")
	passed = assert_true(data.has("shield_amount"), "应包含shield_amount") and passed
	passed = assert_almost_equal(data["shield_amount"], 50.0, 0.1, "护盾值应正确") and passed
	
	# 反序列化
	var manager2 = StatusEffectManager.new()
	manager2.name = "StatusEffectManager"
	entity.add_child(manager2)
	manager2.from_dict(data)
	
	passed = assert_true(manager2.has_effect("test_serialize"), "应恢复效果") and passed
	passed = assert_almost_equal(manager2.get_shield_amount(), 50.0, 0.1, "应恢复护盾") and passed
	
	entity.free()
	end_test(passed)
