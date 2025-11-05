# res://examples/weapon_with_elemental_damage_example.gd
extends Node
## 武器元素伤害使用示例
##
## 展示如何创建带有元素伤害的武器

var results: Array = []

func _ready():
	# 测试运行入口 — 将原示例转为自动化断言测试
	print("-- 开始 Weapon with Elemental Damage 测试 --")

	results.clear()
	_run_test("test_create_flame_sword", test_create_flame_sword)
	_run_test("test_create_elemental_staff", test_create_elemental_staff)
	_run_test("test_calculate_total_damage", test_calculate_total_damage)

	_print_summary()
	print("-- 结束 Weapon 测试 --")


## 创建火焰之剑
func create_flame_sword() -> WeaponData:
	var weapon = WeaponData.new()
	
	# 基础属性
	weapon.id = "flame_sword"
	weapon.item_name = "火焰之剑"
	weapon.description = "被烈焰附魔的长剑，每次挥砍都会释放火焰之力。"
	weapon.rarity = ItemData.Rarity.RARE
	weapon.base_value = 500
	weapon.weight = 4.0
	
	# 武器属性
	weapon.weapon_type = WeaponData.WeaponType.SWORD
	weapon.is_two_handed = false
	weapon.attack_range = 70.0
	weapon.attack_speed = 1.2
	weapon.required_level = 10
	
	# 物理伤害
	weapon.min_physical_damage = 25.0
	weapon.max_physical_damage = 35.0
	
	# 添加火焰伤害修正器
	var fire_mod = StatModifier.create_flat(
		StatModifier.StatType.FIRE_DAMAGE, 
		15.0,  # +15 火焰伤害
		"flame_sword"
	)
	weapon.stat_modifiers.append(fire_mod)
	
	# 添加额外属性: 攻击速度加成
	var speed_mod = StatModifier.create_percent(
		StatModifier.StatType.ATTACK_SPEED,
		0.1,  # +10% 攻击速度
		"flame_sword"
	)
	weapon.stat_modifiers.append(speed_mod)
	
	weapon.special_effect_description = "攻击有几率点燃敌人"
	
	return weapon


## 创建元素法杖
func create_elemental_staff() -> WeaponData:
	var weapon = WeaponData.new()
	
	# 基础属性
	weapon.id = "elemental_staff"
	weapon.item_name = "元素主宰法杖"
	weapon.description = "蕴含多种元素之力的强大法杖。"
	weapon.rarity = ItemData.Rarity.LEGENDARY
	weapon.base_value = 2000
	weapon.weight = 3.0
	
	# 武器属性
	weapon.weapon_type = WeaponData.WeaponType.STAFF
	weapon.is_two_handed = true
	weapon.attack_range = 150.0
	weapon.attack_speed = 0.8
	weapon.required_level = 25
	
	# 魔法伤害
	weapon.min_magic_damage = 40.0
	weapon.max_magic_damage = 60.0
	
	# 添加多种元素伤害
	var fire_mod = StatModifier.create_flat(
		StatModifier.StatType.FIRE_DAMAGE, 
		20.0,
		"elemental_staff"
	)
	weapon.stat_modifiers.append(fire_mod)
	
	var ice_mod = StatModifier.create_flat(
		StatModifier.StatType.ICE_DAMAGE,
		20.0,
		"elemental_staff"
	)
	weapon.stat_modifiers.append(ice_mod)
	
	var lightning_mod = StatModifier.create_flat(
		StatModifier.StatType.LIGHTNING_DAMAGE,
		20.0,
		"elemental_staff"
	)
	weapon.stat_modifiers.append(lightning_mod)
	
	# 添加智力加成
	var int_mod = StatModifier.create_flat(
		StatModifier.StatType.INTELLIGENCE,
		15.0,
		"elemental_staff"
	)
	weapon.stat_modifiers.append(int_mod)
	
	# 添加施法速度加成
	var cast_speed_mod = StatModifier.create_percent(
		StatModifier.StatType.CAST_SPEED,
		0.15,  # +15% 施法速度
		"elemental_staff"
	)
	weapon.stat_modifiers.append(cast_speed_mod)
	
	weapon.special_effect_description = "技能造成的伤害额外触发随机元素爆炸"
	
	return weapon


## 示例: 如何在战斗中计算总伤害(包含元素)
func calculate_total_damage(stats: StatsComponent) -> Dictionary:
	var damage = {
		"physical": stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE),
		"magic": stats.get_stat(StatModifier.StatType.MAGIC_DAMAGE),
		"fire": stats.get_stat(StatModifier.StatType.FIRE_DAMAGE),
		"ice": stats.get_stat(StatModifier.StatType.ICE_DAMAGE),
		"lightning": stats.get_stat(StatModifier.StatType.LIGHTNING_DAMAGE),
		"poison": stats.get_stat(StatModifier.StatType.POISON_DAMAGE),
		"dark": stats.get_stat(StatModifier.StatType.DARK_DAMAGE),
		"holy": stats.get_stat(StatModifier.StatType.HOLY_DAMAGE),
	}
	
	# 计算总伤害
	var total = 0.0
	for dmg_type in damage:
		total += damage[dmg_type]
	damage["total"] = total
	
	return damage


### ---------- 测试框架与用例 ----------

func _assert(cond: bool, message: String) -> void:
	var entry = {"ok": cond, "msg": message}
	results.append(entry)
	if cond:
		print("通过：%s" % message)
	else:
		print("失败：%s" % message)

func _run_test(test_name: String, func_ref: Callable) -> void:
	print("\n--- 运行测试 %s ---" % test_name)
	var before = results.size()
	func_ref.call()
	var passed = 0
	for i in range(before, results.size()):
		if results[i].ok:
			passed += 1
	print("%s: %d 条断言，%d 通过" % [test_name, results.size() - before, passed])

func _print_summary() -> void:
	var total = results.size()
	var passed = 0
	for r in results:
		if r.ok:
			passed += 1
	print('\n===== 测试汇总 =====')
	print('断言总数: %d' % total)
	print('通过: %d' % passed)
	print('失败: %d' % (total - passed))


class DummyStats extends StatsComponent:
	var stats = {}
	func _init(d = null):
		# 不调用父级 _ready，直接用覆盖的 get_stat 返回值
		if d == null:
			stats = {}
		else:
			stats = d.duplicate()
	func get_stat(stat):
		return stats.get(stat, 0.0)


func test_create_flame_sword():
	var w = create_flame_sword()
	_assert(w != null, "已创建 火焰之剑")
	if not w:
		return
	_assert(w.id == "flame_sword", "id 为 flame_sword")
	_assert(w.item_name == "火焰之剑", "名称为 火焰之剑")
	_assert(w.min_physical_damage > 0 and w.max_physical_damage > w.min_physical_damage, "物理伤害范围合理")

	var has_fire := false
	var has_speed := false
	for mod in w.stat_modifiers:
		if mod.stat_type == StatModifier.StatType.FIRE_DAMAGE and mod.modifier_type == StatModifier.ModifierType.FLAT and abs(mod.value - 15.0) < 0.001:
			has_fire = true
		if mod.stat_type == StatModifier.StatType.ATTACK_SPEED and mod.modifier_type == StatModifier.ModifierType.PERCENT and abs(mod.value - 0.1) < 0.001:
			has_speed = true
	_assert(has_fire, "包含 火焰伤害 +15 的修正器")
	_assert(has_speed, "包含 攻击速度 +10% 的百分比修正器")


func test_create_elemental_staff():
	var w = create_elemental_staff()
	_assert(w != null, "已创建 元素法杖")
	if not w:
		return
	_assert(w.id == "elemental_staff", "id 为 elemental_staff")
	_assert(w.item_name == "元素主宰法杖", "名称为 元素主宰法杖")
	_assert(w.rarity == ItemData.Rarity.LEGENDARY, "稀有度为 LEGENDARY")
	_assert(w.base_value == 2000, "基础售价为 2000")

	var found = {"fire":false, "ice":false, "lightning":false, "int":false, "cast":false}
	for mod in w.stat_modifiers:
		match mod.stat_type:
			StatModifier.StatType.FIRE_DAMAGE:
				if abs(mod.value - 20.0) < 0.001:
					found["fire"] = true
			StatModifier.StatType.ICE_DAMAGE:
				if abs(mod.value - 20.0) < 0.001:
					found["ice"] = true
			StatModifier.StatType.LIGHTNING_DAMAGE:
				if abs(mod.value - 20.0) < 0.001:
					found["lightning"] = true
			StatModifier.StatType.INTELLIGENCE:
				if abs(mod.value - 15.0) < 0.001:
					found["int"] = true
			StatModifier.StatType.CAST_SPEED:
				if mod.modifier_type == StatModifier.ModifierType.PERCENT and abs(mod.value - 0.15) < 0.001:
					found["cast"] = true

	_assert(found["fire"] and found["ice"] and found["lightning"], "包含三种元素伤害各 +20 的修正器")
	_assert(found["int"], "包含 智力 +15 的修正器")
	_assert(found["cast"], "包含 施法速度 +15% 的百分比修正器")


func test_calculate_total_damage():
	# 使用 DummyStats 提供 get_stat
	var vals = {}
	vals[StatModifier.StatType.PHYSICAL_DAMAGE] = 10.0
	vals[StatModifier.StatType.MAGIC_DAMAGE] = 5.0
	vals[StatModifier.StatType.FIRE_DAMAGE] = 20.0
	vals[StatModifier.StatType.ICE_DAMAGE] = 10.0
	vals[StatModifier.StatType.LIGHTNING_DAMAGE] = 5.0
	vals[StatModifier.StatType.POISON_DAMAGE] = 0.0
	vals[StatModifier.StatType.DARK_DAMAGE] = 0.0
	vals[StatModifier.StatType.HOLY_DAMAGE] = 0.0

	var s = DummyStats.new(vals)
	var out = calculate_total_damage(s)
	var expected = 0.0
	expected += vals[StatModifier.StatType.PHYSICAL_DAMAGE]
	expected += vals[StatModifier.StatType.MAGIC_DAMAGE]
	expected += vals[StatModifier.StatType.FIRE_DAMAGE]
	expected += vals[StatModifier.StatType.ICE_DAMAGE]
	expected += vals[StatModifier.StatType.LIGHTNING_DAMAGE]
	expected += vals[StatModifier.StatType.POISON_DAMAGE]
	expected += vals[StatModifier.StatType.DARK_DAMAGE]
	expected += vals[StatModifier.StatType.HOLY_DAMAGE]

	_assert(out.has("total"), "calculate_total_damage 返回包含 total 键")
	if out.has("total"):
		_assert(abs(out["total"] - expected) < 0.001, "计算的总伤害等于各元素与物理/魔法伤害之和")
