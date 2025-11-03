# res://examples/weapon_with_elemental_damage_example.gd
extends Node
## 武器元素伤害使用示例
##
## 展示如何创建带有元素伤害的武器

func _ready():
	# 示例1: 创建一把带火焰伤害的剑
	var flame_sword = create_flame_sword()
	print("=== 火焰之剑 ===")
	print(flame_sword.get_full_description())
	print("\n")
	
	# 示例2: 创建一把带多种元素伤害的法杖
	var elemental_staff = create_elemental_staff()
	print("=== 元素法杖 ===")
	print(elemental_staff.get_full_description())
	print("\n")


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