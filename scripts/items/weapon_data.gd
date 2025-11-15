class_name WeaponData
extends EquipmentData
## 武器数据类
##
## 定义武器的特殊属性,如武器类型、伤害范围、攻击速度等

## 武器类型枚举
enum WeaponType {
	SWORD, ## 单手剑
	GREATSWORD, ## 双手剑
	AXE, ## 斧头
	MACE, ## 锤子
	DAGGER, ## 匕首
	SPEAR, ## 长矛
	BOW, ## 弓
	CROSSBOW, ## 弩
	STAFF, ## 法杖
	WAND, ## 魔杖
	SHIELD ## 盾牌
}

## ========== 武器属性 ==========
@export_group("Weapon Properties")
## 武器类型
@export var weapon_type: WeaponType = WeaponType.SWORD
## 是否是双手武器
@export var is_two_handed: bool = false
## 攻击范围 (像素)
@export var attack_range: float = 60.0
## 攻击速度倍率
@export var attack_speed: float = 1.0

## ========== 伤害属性 ==========
@export_group("Damage")
## 最小物理伤害
@export var min_physical_damage: float = 10.0
## 最大物理伤害
@export var max_physical_damage: float = 15.0
## 最小魔法伤害
@export var min_magic_damage: float = 0.0
## 最大魔法伤害
@export var max_magic_damage: float = 0.0

## ========== 元素伤害 (通过 stat_modifiers 设置) ==========
## 注意: 元素伤害现已整合到 stat 系统中
## 使用 stat_modifiers 添加 FIRE_DAMAGE, ICE_DAMAGE 等类型的修正器
##
## 示例:
## var fire_mod = StatModifier.create_flat(StatModifier.StatType.FIRE_DAMAGE, 15.0, "weapon")
## stat_modifiers.append(fire_mod)

## ========== 特殊攻击 ==========
@export_group("Special Attack")
## 特殊攻击技能ID (如果有)
@export var special_attack_id: String = ""
## 特殊攻击描述
@export var special_attack_description: String = ""
## 特殊攻击冷却时间
@export var special_attack_cooldown: float = 10.0


func _init():
	item_type = ItemType.EQUIPMENT
	equip_slot = EquipSlot.WEAPON_MAIN
	max_stack = 1


## 获取武器类型名称
func get_weapon_type_name() -> String:
	match weapon_type:
		WeaponType.SWORD: return "单手剑"
		WeaponType.GREATSWORD: return "双手剑"
		WeaponType.AXE: return "斧头"
		WeaponType.MACE: return "锤子"
		WeaponType.DAGGER: return "匕首"
		WeaponType.SPEAR: return "长矛"
		WeaponType.BOW: return "弓"
		WeaponType.CROSSBOW: return "弩"
		WeaponType.STAFF: return "法杖"
		WeaponType.WAND: return "魔杖"
		WeaponType.SHIELD: return "盾牌"
	return "未知"


## 获取平均物理伤害
func get_average_physical_damage() -> float:
	return (min_physical_damage + max_physical_damage) / 2.0


## 获取平均魔法伤害
func get_average_magic_damage() -> float:
	return (min_magic_damage + max_magic_damage) / 2.0


## 获取伤害范围描述
func get_damage_description() -> String:
	var desc = ""
	
	# 物理伤害
	if max_physical_damage > 0:
		desc += "物理伤害: %.0f-%.0f\n" % [min_physical_damage, max_physical_damage]
	
	# 魔法伤害
	if max_magic_damage > 0:
		desc += "魔法伤害: %.0f-%.0f\n" % [min_magic_damage, max_magic_damage]
	
	# 元素伤害 (从 stat_modifiers 中获取)
	for mod in stat_modifiers:
		match mod.stat_type:
			StatModifier.StatType.FIRE_DAMAGE:
				if mod.value > 0:
					desc += "火焰伤害: +%.0f\n" % mod.value
			StatModifier.StatType.ICE_DAMAGE:
				if mod.value > 0:
					desc += "冰霜伤害: +%.0f\n" % mod.value
			StatModifier.StatType.LIGHTNING_DAMAGE:
				if mod.value > 0:
					desc += "闪电伤害: +%.0f\n" % mod.value
			StatModifier.StatType.POISON_DAMAGE:
				if mod.value > 0:
					desc += "毒素伤害: +%.0f\n" % mod.value
			StatModifier.StatType.DARK_DAMAGE:
				if mod.value > 0:
					desc += "暗影伤害: +%.0f\n" % mod.value
			StatModifier.StatType.HOLY_DAMAGE:
				if mod.value > 0:
					desc += "神圣伤害: +%.0f\n" % mod.value
	
	# 攻击速度
	if attack_speed != 1.0:
		desc += "攻击速度: %.1f\n" % attack_speed
	
	return desc.strip_edges()


## 重写完整描述
func get_full_description() -> String:
	var desc = "[b]%s[/b]\n" % item_name
	desc += "[color=#%s]%s[/color]\n" % [get_rarity_color().to_html(), get_rarity_name()]
	desc += "%s" % get_weapon_type_name()
	
	if is_two_handed:
		desc += " (双手)"
	
	desc += "\n"
	
	if required_level > 1:
		desc += "\n需求等级: %d\n" % required_level
	
	# 伤害信息
	var damage_desc = get_damage_description()
	if damage_desc != "":
		desc += "\n[color=orange]%s[/color]\n" % damage_desc
	
	# 属性加成
	var stats_desc = get_stats_description()
	if stats_desc != "":
		desc += "\n[color=green]%s[/color]\n" % stats_desc
	
	# 特殊攻击
	if special_attack_description != "":
		desc += "\n[color=yellow]特殊攻击: %s[/color]" % special_attack_description
		desc += "\n[color=gray]冷却: %.1fs[/color]\n" % special_attack_cooldown
	
	# 特殊效果
	if special_effect_description != "":
		desc += "\n[color=yellow]%s[/color]\n" % special_effect_description
	
	# 套装信息
	if set_bonus_id != "":
		desc += "\n[color=orange]套装: %s[/color]" % set_bonus_name
		if set_bonus_description != "":
			desc += "\n%s\n" % set_bonus_description
	
	# 基础描述
	if description != "":
		desc += "\n%s\n" % description
	
	# 耐久度
	if has_durability:
		desc += "\n耐久度: %d/%d" % [max_durability, max_durability]
	
	if weight > 0:
		desc += "\n重量: %.1f" % weight
	
	if can_sell:
		desc += "\n售价: %d 金币" % get_sell_price()
	
	return desc
