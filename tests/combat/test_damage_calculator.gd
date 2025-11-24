## DamageCalculator 测试
## 测试伤害计算器的各个阶段
extends TestFramework

func _init() -> void:
	super._init("DamageCalculator测试")

## 运行所有测试
func run_all_tests() -> void:
	test_basic_damage_calculation()
	test_attribute_modifiers()
	test_critical_hit()
	test_defense_reduction()
	test_dodge_and_block()
	test_elemental_reactions()
	test_damage_absorption()
	test_armor_penetration()
	test_true_damage()
	
	print_report()

## 测试: 基础伤害计算
func test_basic_damage_calculation() -> void:
	start_test("基础伤害计算")
	
	# 创建测试实体
	var attacker = Node.new()
	var defender = Node.new()
	
	# 创建伤害信息
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.PHYSICAL)
	
	# 计算伤害（无任何加成）
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	var passed = assert_equal(final_damage, 100.0, "无加成时伤害应为100")
	passed = assert_false(damage_info.is_critical, "不应该暴击") and passed
	passed = assert_false(damage_info.is_dodged, "不应该闪避") and passed
	passed = assert_false(damage_info.is_blocked, "不应该格挡") and passed
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 属性加成
func test_attribute_modifiers() -> void:
	start_test("属性加成")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 添加 StatsComponent
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.strength = 0
	base_stats.agility = 0
	base_stats.intelligence = 0
	base_stats.vitality = 0
	base_stats.luck = 0
	base_stats.physical_damage = 50.0  # 基础攻击力50
	base_stats.crit_chance = 0 # 暴击需要为0，否则影响计算
	stats.base_stats = base_stats
	attacker.add_child(stats)
	stats._ready()  # 手动调用初始化
	
	# 创建伤害信息
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.PHYSICAL)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	# 100 * (1 + 50/100) = 150
	var passed = assert_almost_equal(final_damage, 150.0, 0.1, "物理伤害应有50%加成")
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 暴击
func test_critical_hit() -> void:
	start_test("暴击计算")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 添加 StatsComponent with 100% crit
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.strength = 0
	base_stats.agility = 0
	base_stats.intelligence = 0
	base_stats.vitality = 0
	base_stats.luck = 0
	base_stats.crit_damage = 0.0 # 清除基础暴击伤害
	base_stats.physical_damage = 0.0 # 清除基础物理伤害
	stats.base_stats = base_stats
	attacker.add_child(stats)
	stats._ready()  # 手动初始化
	
	# 添加暴击修改器
	var crit_mod = StatModifier.new()
	crit_mod.source_id = "crit_test"
	crit_mod.stat_type = StatModifier.StatType.CRIT_CHANCE
	crit_mod.value = 1.0  # 100%暴击率
	crit_mod.modifier_type = StatModifier.ModifierType.OVERRIDE
	stats.add_modifier(crit_mod)
	
	var crit_dmg_mod = StatModifier.new()
	crit_dmg_mod.source_id = "crit_dmg_test"
	crit_dmg_mod.stat_type = StatModifier.StatType.CRIT_DAMAGE # 暴击伤害倍率
	crit_dmg_mod.value = 2.0  # 200%暴击伤害
	crit_dmg_mod.modifier_type = StatModifier.ModifierType.OVERRIDE
	stats.add_modifier(crit_dmg_mod)
	
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.PHYSICAL)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	var passed = assert_true(damage_info.is_critical, "应该触发暴击")
	passed = assert_almost_equal(final_damage, 200.0, 0.1, "暴击伤害应为200") and passed
	passed = assert_almost_equal(damage_info.critical_multiplier, 2.0, 0.1, "暴击倍率应为2.0") and passed
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 防御削减
func test_defense_reduction() -> void:
	start_test("防御削减")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 攻击者属性 (确保无加成)
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	var attacker_base = StatsData.new()
	attacker_base.strength = 0  # 清除力量加成
	attacker_base.physical_damage = 0.0
	attacker_stats.base_stats = attacker_base
	attacker_stats.base_stats.crit_chance = 0.0 # 清除暴击概率
	attacker_stats.base_stats.crit_damage = 0.0 # 清除基础暴击伤害
	attacker.add_child(attacker_stats)
	attacker_stats._ready()
	
	# 目标有50点防御
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.strength = 0
	base_stats.agility = 0
	base_stats.intelligence = 0
	base_stats.vitality = 0  # 清除体质加成
	base_stats.luck = 0
	base_stats.armor = 50.0
	stats.base_stats = base_stats
	defender.add_child(stats)
	stats._ready()
	
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.PHYSICAL)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	# 防御减伤 = 50 / (50 + 100) = 33.33%
	# 伤害 = 100 * (1 - 0.3333) = 66.67
	var passed = assert_almost_equal(final_damage, 66.67, 1.0, "防御应减少约33%伤害")
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 闪避和格挡
func test_dodge_and_block() -> void:
	start_test("闪避和格挡")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 100%闪避率
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	stats.base_stats = base_stats
	defender.add_child(stats)
	stats._ready()
	
	# 添加闪避修改器
	var dodge_mod = StatModifier.new()
	dodge_mod.source_id = "dodge_test"
	dodge_mod.stat_type = StatModifier.StatType.DODGE_CHANCE
	dodge_mod.value = 1.0  # 100%闪避率
	dodge_mod.modifier_type = StatModifier.ModifierType.OVERRIDE
	stats.add_modifier(dodge_mod)
	
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.PHYSICAL)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	var passed = assert_true(damage_info.is_dodged, "应该触发闪避")
	passed = assert_equal(final_damage, 0.0, "闪避后伤害应为0") and passed
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 元素反应
func test_elemental_reactions() -> void:
	start_test("元素反应")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 添加状态效果管理器
	var status_manager = StatusEffectManager.new()
	status_manager.name = "StatusEffectManager"
	defender.add_child(status_manager)
	
	# 注册冰冻效果
	var ice_effect = StatusEffectData.new()
	ice_effect.effect_id = "test_frozen"
	ice_effect.element = StatModifier.ElementType.ICE
	ice_effect.duration = 5.0
	StatusEffectManager.register_effect(ice_effect)
	status_manager.add_effect("test_frozen")
	
	# 用火焰攻击，触发蒸发反应
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.FIRE)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	var passed = assert_equal(damage_info.elemental_reaction, "蒸发", "应触发蒸发反应")
	passed = assert_almost_equal(final_damage, 200.0, 0.1, "蒸发反应伤害应翻倍") and passed
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 伤害吸收（护盾）
func test_damage_absorption() -> void:
	start_test("伤害吸收（护盾）")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 添加护盾
	var status_manager = StatusEffectManager.new()
	status_manager.name = "StatusEffectManager"
	defender.add_child(status_manager)
	status_manager.add_shield(50.0)
	
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.PHYSICAL)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	var passed = assert_almost_equal(damage_info.absorbed_damage, 50.0, 0.1, "护盾应吸收50点伤害")
	passed = assert_almost_equal(final_damage, 50.0, 0.1, "最终伤害应为50") and passed
	passed = assert_almost_equal(status_manager.get_shield_amount(), 0.0, 0.1, "护盾应被消耗完") and passed
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 护甲穿透
func test_armor_penetration() -> void:
	start_test("护甲穿透")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 攻击者（目前护甲穿透需要通过修改器系统）
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	var attacker_base = StatsData.new()
	attacker_base.crit_chance = 0.0
	attacker_base.crit_damage = 0.0
	attacker_stats.base_stats = attacker_base
	attacker.add_child(attacker_stats)
	
	# 防御者有100点防御
	var defender_stats = StatsComponent.new()
	defender_stats.name = "StatsComponent"
	var defender_base = StatsData.new()
	defender_base.armor = 100.0
	defender_stats.base_stats = defender_base
	defender.add_child(defender_stats)
	
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.PHYSICAL)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	# 有防御时伤害应该减少
	var passed = assert_less(final_damage, 100.0, "有防御时伤害应减少")
	
	attacker.free()
	defender.free()
	end_test(passed)

## 测试: 真实伤害
func test_true_damage() -> void:
	start_test("真实伤害")
	
	var attacker = Node.new()
	var defender = Node.new()
	
	# 防御者有高额防御
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.armor = 1000.0
	stats.base_stats = base_stats
	defender.add_child(stats)
	stats._ready()
	
	# 真实伤害无视防御
	var damage_info = DamageInfo.new(attacker, defender, 100.0, DamageInfo.DamageType.TRUE)
	var final_damage = DamageCalculator.calculate_damage(damage_info)
	
	var passed = assert_equal(final_damage, 100.0, "真实伤害应无视防御")
	
	attacker.free()
	defender.free()
	end_test(passed)
