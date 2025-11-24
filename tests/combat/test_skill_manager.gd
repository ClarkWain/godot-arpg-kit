## SkillManager 测试
## 测试技能管理器
extends TestFramework

func _init() -> void:
	super._init("SkillManager测试")

## 运行所有测试
func run_all_tests() -> void:
	test_register_skill()
	test_equip_skill()
	test_unequip_skill()
	test_use_skill()
	test_skill_cooldown()
	test_resource_cost()
	test_cast_time()
	test_skill_range()
	test_interrupt_cast()
	test_serialization()
	
	print_report()

## 测试: 注册技能
func test_register_skill() -> void:
	start_test("注册技能")
	
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_skill"
	skill_data.skill_name = "测试技能"
	skill_data.cooldown = 5.0
	
	var result = SkillManager.register_skill(skill_data)
	
	var passed = assert_true(result, "应成功注册技能")
	passed = assert_true(SkillManager.registered_skills.has("test_skill"), "技能应在注册表中") and passed
	
	end_test(passed)

## 测试: 装备技能
func test_equip_skill() -> void:
	start_test("装备技能")
	
	# 注册技能
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_equip"
	skill_data.skill_name = "测试装备"
	SkillManager.register_skill(skill_data)
	
	var entity = Node.new()
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	entity.add_child(manager)
	
	# 装备到槽位0
	var result = manager.equip_skill(0, "test_equip")
	
	var passed = assert_true(result, "应成功装备技能")
	passed = assert_true(manager.skill_slots.has(0), "槽位0应有技能") and passed
	
	var instance = manager.get_skill_instance(0)
	passed = assert_not_null(instance, "应返回技能实例") and passed
	passed = assert_equal(instance.skill_data.skill_id, "test_equip", "技能ID应正确") and passed
	
	entity.free()
	end_test(passed)

## 测试: 卸载技能
func test_unequip_skill() -> void:
	start_test("卸载技能")
	
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_unequip"
	SkillManager.register_skill(skill_data)
	
	var entity = Node.new()
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	entity.add_child(manager)
	
	# 装备后卸载
	manager.equip_skill(0, "test_unequip")
	var passed = assert_true(manager.skill_slots.has(0), "应有技能")
	
	manager.unequip_skill(0)
	passed = assert_false(manager.skill_slots.has(0), "技能应被卸载") and passed
	
	entity.free()
	end_test(passed)

## 测试: 使用技能
func test_use_skill() -> void:
	start_test("使用技能")
	
	# 创建瞬发技能
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_use"
	skill_data.skill_name = "测试使用"
	skill_data.cooldown = 5.0
	skill_data.cast_time = 0.0  # 瞬发
	skill_data.base_damage = 50.0
	skill_data.target_type = SkillData.TargetType.ENEMY
	SkillManager.register_skill(skill_data)
	
	# 创建施法者
	var caster = Node2D.new()
	var caster_stats = StatsComponent.new()
	caster_stats.name = "StatsComponent"
	caster.add_child(caster_stats)
	var caster_combat = CombatComponent.new()
	caster_combat.name = "CombatComponent"
	caster.add_child(caster_combat)
	var skill_manager = SkillManager.new()
	skill_manager.name = "SkillManager"
	caster.add_child(skill_manager)
	
	# 创建目标
	var target = Node2D.new()
	var target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	var target_base = StatsData.new()
	target_base.max_health = 100.0
	target_stats.base_stats = target_base
	target.add_child(target_stats)
	var target_combat = CombatComponent.new()
	target_combat.name = "CombatComponent"
	target.add_child(target_combat)
	
	# 装备并使用技能
	skill_manager.equip_skill(0, "test_use")
	var result = skill_manager.use_skill(0, target)
	
	var passed = assert_true(result, "应成功使用技能")
	
	var instance = skill_manager.get_skill_instance(0)
	passed = assert_true(instance.is_on_cooldown, "技能应进入冷却") and passed
	
	caster.free()
	target.free()
	end_test(passed)

## 测试: 技能冷却
func test_skill_cooldown() -> void:
	start_test("技能冷却")
	
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_cooldown"
	skill_data.cooldown = 5.0
	skill_data.cast_time = 0.0
	SkillManager.register_skill(skill_data)
	
	var entity = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	entity.add_child(stats)
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	entity.add_child(combat)
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	entity.add_child(manager)
	
	manager.equip_skill(0, "test_cooldown")
	var instance = manager.get_skill_instance(0)
	
	# 开始冷却
	instance.start_cooldown()
	var passed = assert_true(instance.is_on_cooldown, "应在冷却中")
	passed = assert_false(instance.can_use(), "冷却期间不能使用") and passed
	
	# 模拟时间流逝
	instance.update(5.0)
	passed = assert_false(instance.is_on_cooldown, "冷却应结束") and passed
	passed = assert_true(instance.can_use(), "冷却结束后可以使用") and passed
	
	entity.free()
	end_test(passed)

## 测试: 资源消耗
func test_resource_cost() -> void:
	start_test("资源消耗")
	
	# 创建需要魔法的技能
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_mana"
	skill_data.cooldown = 0.0
	skill_data.cast_time = 0.0
	skill_data.mana_cost = 30.0
	skill_data.target_type = SkillData.TargetType.SELF
	SkillManager.register_skill(skill_data)
	
	var caster = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.max_mana = 100.0
	stats.base_stats = base_stats
	stats._ready()
	stats._mark_dirty()
	stats._recalculate_all_stats()
	caster.add_child(stats)
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	caster.add_child(combat)
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	caster.add_child(manager)
	manager._ready()
	
	var initial_mana = stats.get_stat(StatModifier.StatType.MAX_MANA)
	
	# 装备并使用技能
	manager.equip_skill(0, "test_mana")
	var result = manager.use_skill(0)
	
	var current_mana = stats.current_mana
	var passed = assert_true(result, "应成功使用技能")
	passed = assert_almost_equal(current_mana, initial_mana - 30.0, 0.1, "应消耗30点魔法") and passed
	
	# 魔法不足时不能使用
	stats.current_mana = 10.0
	result = manager.use_skill(0)
	passed = assert_false(result, "魔法不足时不应能使用") and passed
	
	caster.free()
	end_test(passed)

## 测试: 施法时间
func test_cast_time() -> void:
	start_test("施法时间")
	
	# 创建有施法时间的技能
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_cast"
	skill_data.cooldown = 0.0
	skill_data.cast_time = 2.0  # 2秒施法时间
	skill_data.target_type = SkillData.TargetType.SELF
	SkillManager.register_skill(skill_data)
	
	var caster = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	caster.add_child(stats)
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	caster.add_child(combat)
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	caster.add_child(manager)
	
	manager.equip_skill(0, "test_cast")
	manager.use_skill(0)
	
	var passed = assert_not_null(manager.current_casting_skill, "应正在施法")
	
	var instance = manager.get_skill_instance(0)
	passed = assert_true(instance.is_casting, "技能应在施法中") and passed
	passed = assert_false(instance.is_on_cooldown, "施法期间不应进入冷却") and passed
	
	caster.free()
	end_test(passed)

## 测试: 施法距离
func test_skill_range() -> void:
	start_test("施法距离")
	
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_range"
	skill_data.cooldown = 0.0
	skill_data.cast_time = 0.0
	skill_data.cast_range = 100.0  # 100像素范围
	skill_data.target_type = SkillData.TargetType.ENEMY
	SkillManager.register_skill(skill_data)
	
	var caster = Node2D.new()
	caster.position = Vector2(0, 0)
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	stats.base_stats = StatsData.new()
	caster.add_child(stats)
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	caster.add_child(combat)
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	manager.entity = caster
	caster.add_child(manager)
	stats._ready()
	combat._ready()
	manager._ready()
	
	# 近距离目标
	var near_target = Node2D.new()
	near_target.position = Vector2(50, 0)
	var near_stats = StatsComponent.new()
	near_stats.name = "StatsComponent"
	near_stats.base_stats = StatsData.new()
	near_target.add_child(near_stats)
	var near_combat = CombatComponent.new()
	near_combat.name = "CombatComponent"
	near_target.add_child(near_combat)
	near_stats._ready()
	near_combat._ready()
	
	# 远距离目标
	var far_target = Node2D.new()
	far_target.position = Vector2(200, 0)
	var far_stats = StatsComponent.new()
	far_stats.name = "StatsComponent"
	far_stats.base_stats = StatsData.new()
	far_target.add_child(far_stats)
	var far_combat = CombatComponent.new()
	far_combat.name = "CombatComponent"
	far_target.add_child(far_combat)
	far_stats._ready()
	far_combat._ready()
	
	
	manager.equip_skill(0, "test_range")
	
	# 攻击近距离目标应成功
	var result1 = manager.use_skill(0, near_target)
	var passed = assert_true(result1, "近距离应能使用技能")
	
	# 重置冷却
	var instance = manager.get_skill_instance(0)
	instance.reset_cooldown()
	
	# 攻击远距离目标应失败
	var result2 = manager.use_skill(0, far_target)
	passed = assert_false(result2, "超出范围不应能使用技能") and passed
	
	caster.free()
	near_target.free()
	far_target.free()
	end_test(passed)

## 测试: 打断施法
func test_interrupt_cast() -> void:
	start_test("打断施法")
	
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_interrupt"
	skill_data.cast_time = 2.0
	skill_data.cooldown = 0.0
	skill_data.target_type = SkillData.TargetType.SELF
	SkillManager.register_skill(skill_data)
	
	var caster = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	caster.add_child(stats)
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	caster.add_child(combat)
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	caster.add_child(manager)
	
	manager.equip_skill(0, "test_interrupt")
	manager.use_skill(0)
	
	var passed = assert_not_null(manager.current_casting_skill, "应正在施法")
	
	# 打断施法
	manager.interrupt_cast()
	
	passed = assert_null(manager.current_casting_skill, "施法应被打断") and passed
	
	var instance = manager.get_skill_instance(0)
	passed = assert_false(instance.is_casting, "技能不应在施法中") and passed
	
	caster.free()
	end_test(passed)

## 测试: 序列化
func test_serialization() -> void:
	start_test("序列化")
	
	var skill_data = SkillData.new()
	skill_data.skill_id = "test_serialize"
	skill_data.cooldown = 10.0
	SkillManager.register_skill(skill_data)
	
	var entity = Node.new()
	var manager = SkillManager.new()
	manager.name = "SkillManager"
	entity.add_child(manager)
	
	# 装备技能并进入冷却
	manager.equip_skill(0, "test_serialize")
	var instance = manager.get_skill_instance(0)
	instance.start_cooldown()
	
	# 序列化
	var data = manager.to_dict()
	
	var passed = assert_true(data.has("skill_slots"), "应包含skill_slots")
	passed = assert_true(data["skill_slots"].has("0"), "应包含槽位0") and passed
	
	# 反序列化
	var manager2 = SkillManager.new()
	manager2.name = "SkillManager"
	entity.add_child(manager2)
	manager2.from_dict(data)
	
	passed = assert_true(manager2.skill_slots.has(0), "应恢复技能") and passed
	
	var instance2 = manager2.get_skill_instance(0)
	passed = assert_not_null(instance2, "应有技能实例") and passed
	passed = assert_true(instance2.is_on_cooldown, "应恢复冷却状态") and passed
	
	entity.free()
	end_test(passed)
