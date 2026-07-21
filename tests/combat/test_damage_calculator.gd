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
	# 清 dodge_chance：默认 0.05 会有 5% 概率闪避导致本测试 flaky
	base_stats.dodge_chance = 0.0
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
##
## 覆盖修复：旧实现把 PHYSICAL_DAMAGE_REDUCTION（受击方物理受伤减免）错误
## 地当成攻击者的护甲穿透使用。现在改为专用字段 ARMOR_PENETRATION（物理）
## 与 MAGIC_PENETRATION（法术）。
func test_armor_penetration() -> void:
	start_test("护甲穿透")
	
	# --- 场景 A：无穿透，作为 baseline ---
	var atk_a := Node.new()
	var def_a := Node.new()
	var atk_stats_a := StatsComponent.new()
	atk_stats_a.name = "StatsComponent"
	var atk_base_a := StatsData.new()
	atk_base_a.strength = 0
	atk_base_a.agility = 0
	atk_base_a.intelligence = 0
	atk_base_a.vitality = 0
	atk_base_a.luck = 0
	atk_base_a.physical_damage = 0.0
	atk_base_a.crit_chance = 0.0
	atk_base_a.crit_damage = 0.0
	atk_base_a.armor_penetration = 0.0
	atk_stats_a.base_stats = atk_base_a
	atk_a.add_child(atk_stats_a)
	atk_stats_a._ready()
	
	var def_stats_a := StatsComponent.new()
	def_stats_a.name = "StatsComponent"
	var def_base_a := StatsData.new()
	def_base_a.strength = 0
	def_base_a.agility = 0
	def_base_a.intelligence = 0
	def_base_a.vitality = 0
	def_base_a.luck = 0
	def_base_a.armor = 100.0
	def_base_a.dodge_chance = 0.0
	def_stats_a.base_stats = def_base_a
	def_a.add_child(def_stats_a)
	def_stats_a._ready()
	
	var info_a := DamageInfo.new(atk_a, def_a, 100.0, DamageInfo.DamageType.PHYSICAL)
	var dmg_a := DamageCalculator.calculate_damage(info_a)
	# 100 * (1 - 100/(100+100)) = 50
	var passed := assert_almost_equal(dmg_a, 50.0, 1.0,
		"无护甲穿透：100 armor 应减伤 50%")
	
	# --- 场景 B：50% 护甲穿透 ---
	var atk_b := Node.new()
	var def_b := Node.new()
	var atk_stats_b := StatsComponent.new()
	atk_stats_b.name = "StatsComponent"
	var atk_base_b := StatsData.new()
	atk_base_b.strength = 0
	atk_base_b.agility = 0
	atk_base_b.intelligence = 0
	atk_base_b.vitality = 0
	atk_base_b.luck = 0
	atk_base_b.physical_damage = 0.0
	atk_base_b.crit_chance = 0.0
	atk_base_b.crit_damage = 0.0
	atk_base_b.armor_penetration = 0.5     # 50% 护甲穿透
	atk_stats_b.base_stats = atk_base_b
	atk_b.add_child(atk_stats_b)
	atk_stats_b._ready()
	
	var def_stats_b := StatsComponent.new()
	def_stats_b.name = "StatsComponent"
	var def_base_b := StatsData.new()
	def_base_b.strength = 0
	def_base_b.agility = 0
	def_base_b.intelligence = 0
	def_base_b.vitality = 0
	def_base_b.luck = 0
	def_base_b.armor = 100.0
	def_base_b.dodge_chance = 0.0
	def_stats_b.base_stats = def_base_b
	def_b.add_child(def_stats_b)
	def_stats_b._ready()
	
	var info_b := DamageInfo.new(atk_b, def_b, 100.0, DamageInfo.DamageType.PHYSICAL)
	var dmg_b := DamageCalculator.calculate_damage(info_b)
	# effective_defense = 100 * (1 - 0.5) = 50
	# damage_reduction  = 50 / (50 + 100) = 33.33%
	# final             = 100 * (1 - 0.3333) = 66.67
	passed = assert_almost_equal(dmg_b, 66.67, 1.0,
		"50% 护甲穿透：100 armor 应等效为 50 armor，减伤 33%") and passed
	
	# --- 场景 C：受击方的物理减免不应再被误当作攻击者的护甲穿透 ---
	# 攻击者身上有 physical_damage_reduction=1.0（即"受伤 -100%"），若旧实现
	# 会把它当成 100% 护甲穿透，导致伤害等于 100。修复后此字段与
	# armor_penetration 完全解耦。
	var atk_c := Node.new()
	var def_c := Node.new()
	var atk_stats_c := StatsComponent.new()
	atk_stats_c.name = "StatsComponent"
	var atk_base_c := StatsData.new()
	atk_base_c.strength = 0
	atk_base_c.agility = 0
	atk_base_c.intelligence = 0
	atk_base_c.vitality = 0
	atk_base_c.luck = 0
	atk_base_c.physical_damage = 0.0
	atk_base_c.crit_chance = 0.0
	atk_base_c.crit_damage = 0.0
	atk_base_c.armor_penetration = 0.0
	atk_base_c.physical_damage_reduction = 0.9   # 攻击者自己的受伤减免
	atk_stats_c.base_stats = atk_base_c
	atk_c.add_child(atk_stats_c)
	atk_stats_c._ready()
	
	var def_stats_c := StatsComponent.new()
	def_stats_c.name = "StatsComponent"
	var def_base_c := StatsData.new()
	def_base_c.strength = 0
	def_base_c.agility = 0
	def_base_c.intelligence = 0
	def_base_c.vitality = 0
	def_base_c.luck = 0
	def_base_c.armor = 100.0
	def_base_c.dodge_chance = 0.0
	def_stats_c.base_stats = def_base_c
	def_c.add_child(def_stats_c)
	def_stats_c._ready()
	
	var info_c := DamageInfo.new(atk_c, def_c, 100.0, DamageInfo.DamageType.PHYSICAL)
	var dmg_c := DamageCalculator.calculate_damage(info_c)
	# 攻击者的物理减免应对穿透没有影响，最终应仍是 50（同场景 A）
	passed = assert_almost_equal(dmg_c, 50.0, 1.0,
		"攻击者的 physical_damage_reduction 不应再被误用为护甲穿透") and passed
	
	atk_a.free(); def_a.free()
	atk_b.free(); def_b.free()
	atk_c.free(); def_c.free()
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
