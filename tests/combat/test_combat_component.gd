## CombatComponent 测试
## 测试战斗组件的核心功能
extends TestFramework

func _init() -> void:
	super._init("CombatComponent测试")

## 运行所有测试
func run_all_tests() -> void:
	test_initialization()
	test_attack_target()
	test_receive_damage()
	test_combat_state_transitions()
	test_combo_system()
	test_invincibility()
	test_death_handling()
	test_heal()
	test_signals()
	
	print_report()

## 测试: 初始化
func test_initialization() -> void:
	start_test("初始化")
	
	var entity = Node2D.new()
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	entity.add_child(combat)
	
	var passed = assert_not_null(combat, "CombatComponent应成功创建")
	passed = assert_equal(combat.combat_state, CombatState.State.IDLE, "初始状态应为IDLE") and passed
	passed = assert_equal(combat.combo_count, 0, "初始连击数应为0") and passed
	passed = assert_false(combat.is_invincible, "初始不应无敌") and passed
	
	entity.free()
	end_test(passed)

## 测试: 攻击目标
func test_attack_target() -> void:
	start_test("攻击目标")
	
	# 创建攻击者
	var attacker = Node2D.new()
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	attacker.add_child(attacker_stats)
	var attacker_combat = CombatComponent.new()
	attacker_combat.name = "CombatComponent"
	attacker.add_child(attacker_combat)
	
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
	
	# 执行攻击
	var damage_info = attacker_combat.attack(target, 30.0, DamageInfo.DamageType.PHYSICAL)
	
	var passed = assert_not_null(damage_info, "应返回伤害信息")
	passed = assert_equal(damage_info.source, attacker, "伤害来源应为攻击者") and passed
	passed = assert_equal(damage_info.target, target, "伤害目标应正确") and passed
	passed = assert_greater(damage_info.final_damage, 0.0, "应造成伤害") and passed
	
	attacker.free()
	target.free()
	end_test(passed)

## 测试: 接收伤害
func test_receive_damage() -> void:
	start_test("接收伤害")
	
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
	
	var initial_health = stats.get_stat("health")
	
	# 接收伤害
	var damage_info = DamageInfo.new(null, entity, 30.0, DamageInfo.DamageType.PHYSICAL)
	damage_info.final_damage = 30.0
	combat.receive_damage(damage_info)
	
	var current_health = stats.get_stat("health")
	
	var passed = assert_less(current_health, initial_health, "生命值应减少")
	passed = assert_almost_equal(current_health, initial_health - 30.0, 0.1, "生命值应减少30") and passed
	
	entity.free()
	end_test(passed)

## 测试: 战斗状态转换
func test_combat_state_transitions() -> void:
	start_test("战斗状态转换")
	
	var combat = CombatComponent.new()
	
	var passed = assert_equal(combat.combat_state, CombatState.State.IDLE, "初始状态为IDLE")
	
	# IDLE -> ATTACKING
	combat.set_combat_state(CombatState.State.ATTACKING)
	passed = assert_equal(combat.combat_state, CombatState.State.ATTACKING, "应转换到ATTACKING") and passed
	
	# ATTACKING -> RECOVERING
	combat.set_combat_state(CombatState.State.RECOVERING)
	passed = assert_equal(combat.combat_state, CombatState.State.RECOVERING, "应转换到RECOVERING") and passed
	
	# RECOVERING -> IDLE
	combat.set_combat_state(CombatState.State.IDLE)
	passed = assert_equal(combat.combat_state, CombatState.State.IDLE, "应转换回IDLE") and passed
	
	# 测试非法转换
	combat.set_combat_state(CombatState.State.DEAD)
	passed = assert_equal(combat.combat_state, CombatState.State.DEAD, "应转换到DEAD") and passed
	
	# 死亡状态无法转换
	combat.set_combat_state(CombatState.State.IDLE)
	passed = assert_equal(combat.combat_state, CombatState.State.DEAD, "死亡状态不应转换") and passed
	
	combat.free()
	end_test(passed)

## 测试: 连击系统
func test_combo_system() -> void:
	start_test("连击系统")
	
	var attacker = Node2D.new()
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	attacker.add_child(attacker_stats)
	var attacker_combat = CombatComponent.new()
	attacker_combat.name = "CombatComponent"
	attacker_combat.combo_window = 1.0  # 1秒连击窗口
	attacker.add_child(attacker_combat)
	
	var target = Node2D.new()
	var target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	var target_base = StatsData.new()
	target_base.max_health = 1000.0
	target_stats.base_stats = target_base
	target.add_child(target_stats)
	var target_combat = CombatComponent.new()
	target_combat.name = "CombatComponent"
	target.add_child(target_combat)
	
	# 连续攻击
	attacker_combat.attack(target, 10.0)
	var passed = assert_equal(attacker_combat.combo_count, 1, "第一次攻击，连击数为1")
	
	attacker_combat.attack(target, 10.0)
	passed = assert_equal(attacker_combat.combo_count, 2, "第二次攻击，连击数为2") and passed
	
	attacker_combat.attack(target, 10.0)
	passed = assert_equal(attacker_combat.combo_count, 3, "第三次攻击，连击数为3") and passed
	
	attacker.free()
	target.free()
	end_test(passed)

## 测试: 无敌状态
func test_invincibility() -> void:
	start_test("无敌状态")
	
	var entity = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.max_health = 100.0
	stats.base_stats = base_stats
	entity.add_child(stats)
	
	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	combat.invincibility_duration = 0.5
	entity.add_child(combat)
	
	var initial_health = stats.get_stat("health")
	
	# 第一次受伤
	var damage_info1 = DamageInfo.new(null, entity, 30.0)
	damage_info1.final_damage = 30.0
	combat.receive_damage(damage_info1)
	
	var passed = assert_true(combat.is_invincible, "受伤后应进入无敌状态")
	
	# 无敌期间再次受伤
	var damage_info2 = DamageInfo.new(null, entity, 30.0)
	damage_info2.final_damage = 30.0
	combat.receive_damage(damage_info2)
	
	var current_health = stats.get_stat("health")
	passed = assert_almost_equal(current_health, initial_health - 30.0, 0.1, "无敌期间不应再受伤") and passed
	
	entity.free()
	end_test(passed)

## 测试: 死亡处理
func test_death_handling() -> void:
	start_test("死亡处理")
	
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
	
	# 造成致命伤害
	stats.take_damage(100.0)
	
	var passed = assert_equal(combat.combat_state, CombatState.State.DEAD, "生命值为0应进入死亡状态")
	
	# 死亡后不应再受伤
	var initial_health = stats.get_stat("health")
	var damage_info = DamageInfo.new(null, entity, 30.0)
	damage_info.final_damage = 30.0
	combat.receive_damage(damage_info)
	
	passed = assert_equal(stats.get_stat("health"), initial_health, "死亡后不应再受伤") and passed
	
	entity.free()
	end_test(passed)

## 测试: 治疗
func test_heal() -> void:
	start_test("治疗")
	
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
	
	# 先受伤
	stats.take_damage(50.0)
	var damaged_health = stats.get_stat("health")
	
	# 治疗
	var healed = combat.heal(30.0)
	var current_health = stats.get_stat("health")
	
	var passed = assert_almost_equal(healed, 30.0, 0.1, "应治疗30点生命")
	passed = assert_almost_equal(current_health, damaged_health + 30.0, 0.1, "生命值应增加30") and passed
	
	entity.free()
	end_test(passed)

## 测试: 信号
func test_signals() -> void:
	start_test("信号触发")
	
	var attacker = Node2D.new()
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	attacker.add_child(attacker_stats)
	var attacker_combat = CombatComponent.new()
	attacker_combat.name = "CombatComponent"
	attacker.add_child(attacker_combat)
	
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
	
	var damage_dealt_triggered = false
	var damage_received_triggered = false
	
	attacker_combat.damage_dealt.connect(func(_t, _d): damage_dealt_triggered = true)
	target_combat.damage_received.connect(func(_s, _d): damage_received_triggered = true)
	
	attacker_combat.attack(target, 30.0)
	
	var passed = assert_true(damage_dealt_triggered, "应触发damage_dealt信号")
	passed = assert_true(damage_received_triggered, "应触发damage_received信号") and passed
	
	attacker.free()
	target.free()
	end_test(passed)
