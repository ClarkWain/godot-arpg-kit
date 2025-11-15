class_name EquipmentData
extends ItemData
## 装备数据类
##
## 所有可装备物品的基类,包括武器、防具、饰品等
## 提供属性加成、装备槽位、等级需求等功能

## 装备槽位枚举
enum EquipSlot {
	HELMET,       ## 头盔
	CHEST,        ## 胸甲
	LEGS,         ## 腿甲
	BOOTS,        ## 靴子
	GLOVES,       ## 手套
	WEAPON_MAIN,  ## 主手武器
	WEAPON_OFF,   ## 副手武器/盾牌
	RING_1,       ## 戒指1
	RING_2,       ## 戒指2
	AMULET,       ## 项链
	BELT          ## 腰带
}

## ========== 装备属性 ==========
@export_group("Equipment Properties")
## 装备槽位
@export var equip_slot: EquipSlot = EquipSlot.HELMET
## 需求等级
@export var required_level: int = 1
## 是否绑定 (装备后无法交易)
@export var bind_on_equip: bool = false

## ========== 属性加成 ==========
@export_group("Stats Modifiers")
## 属性修正器列表 (装备时应用到角色)
@export var stat_modifiers: Array[StatModifier] = []

## ========== 耐久度系统 ==========
@export_group("Durability")
## 是否有耐久度
@export var has_durability: bool = false
## 最大耐久度
@export var max_durability: int = 100
## 修理费用系数
@export var repair_cost_multiplier: float = 0.1

## ========== 套装系统 ==========
@export_group("Set Bonus")
## 套装ID (相同ID的装备可以触发套装效果)
@export var set_bonus_id: String = ""
## 套装名称
@export var set_bonus_name: String = ""
## 套装效果描述
@export_multiline var set_bonus_description: String = ""

## ========== 特殊效果 ==========
@export_group("Special Effects")
## 特殊效果标识符列表 (例如: "lifesteal", "thorns", "speed_boost")
@export var special_effects: Array[String] = []
## 特殊效果描述
@export_multiline var special_effect_description: String = ""


func _init():
	item_type = ItemType.EQUIPMENT
	max_stack = 1  # 装备不可堆叠


## 获取装备槽位名称
func get_slot_name() -> String:
	match equip_slot:
		EquipSlot.HELMET: return "头盔"
		EquipSlot.CHEST: return "胸甲"
		EquipSlot.LEGS: return "腿甲"
		EquipSlot.BOOTS: return "靴子"
		EquipSlot.GLOVES: return "手套"
		EquipSlot.WEAPON_MAIN: return "主手"
		EquipSlot.WEAPON_OFF: return "副手"
		EquipSlot.RING_1: return "戒指1"
		EquipSlot.RING_2: return "戒指2"
		EquipSlot.AMULET: return "项链"
		EquipSlot.BELT: return "腰带"
	return "未知"


## 获取属性加成描述
func get_stats_description() -> String:
	if stat_modifiers.is_empty():
		return ""
	
	var desc = ""
	for mod in stat_modifiers:
		desc += mod.get_description() + "\n"
	return desc.strip_edges()


## 检查角色是否满足装备需求
func can_equip(character_level: int) -> bool:
	return character_level >= required_level


## 获取修理费用
func get_repair_cost(current_durability: int) -> int:
	if not has_durability:
		return 0
	
	var damage_percent = 1.0 - (float(current_durability) / float(max_durability))
	return int(base_value * repair_cost_multiplier * damage_percent)


## 重写完整描述
func get_full_description() -> String:
	var desc = "[b]%s[/b]\n" % item_name
	desc += "[color=#%s]%s[/color]\n" % [get_rarity_color().to_html(), get_rarity_name()]
	desc += "%s\n" % get_slot_name()
	
	if required_level > 1:
		desc += "\n需求等级: %d\n" % required_level
	
	# 属性加成
	var stats_desc = get_stats_description()
	if stats_desc != "":
		desc += "\n[color=green]%s[/color]\n" % stats_desc
	
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
