class_name ConsumableData
extends ItemData
## 消耗品数据类
##
## 定义可使用的消耗品,如药水、食物、卷轴等

## 消耗品效果类型枚举
enum EffectType {
	INSTANT_HEAL,     ## 瞬间治疗生命值
	INSTANT_MANA,     ## 瞬间恢复魔力值
	INSTANT_STAMINA,  ## 瞬间恢复耐力值
	HEAL_OVER_TIME,   ## 持续恢复生命值
	MANA_OVER_TIME,   ## 持续恢复魔力值
	BUFF,             ## 增益效果
	DEBUFF_CURE,      ## 治疗负面效果
	STAT_BOOST,       ## 永久属性提升
	TELEPORT,         ## 传送
	RESURRECT         ## 复活
}

## ========== 消耗品属性 ==========
@export_group("Consumable Properties")
## 效果类型
@export var effect_type: EffectType = EffectType.INSTANT_HEAL
## 使用时间 (秒,0表示瞬间使用)
@export var use_time: float = 0.0
## 使用冷却时间 (秒)
@export var cooldown: float = 0.0
## 是否在战斗中可用
@export var usable_in_combat: bool = true

## ========== 效果数值 ==========
@export_group("Effect Values")
## 效果数值 (具体含义取决于效果类型)
@export var effect_value: float = 50.0
## 效果持续时间 (秒,用于持续恢复和Buff)
@export var effect_duration: float = 0.0
## 每秒效果值 (用于持续效果)
@export var effect_per_second: float = 0.0

## ========== 临时属性加成 ==========
@export_group("Temporary Modifiers")
## 临时属性修正器 (用于增益药水)
@export var temp_modifiers: Array[StatModifier] = []

## ========== 治疗负面效果 ==========
@export_group("Cure Effects")
## 可治疗的负面状态类型
@export var cures_debuffs: Array[String] = []

## ========== 音效 ==========
@export_group("Audio")
## 使用时播放的音效
@export var use_sound: AudioStream


func _init():
	item_type = ItemType.CONSUMABLE
	max_stack = 99  # 消耗品默认可以堆叠99个


## 获取效果类型名称
func get_effect_type_name() -> String:
	match effect_type:
		EffectType.INSTANT_HEAL: return "瞬间恢复生命"
		EffectType.INSTANT_MANA: return "瞬间恢复魔力"
		EffectType.INSTANT_STAMINA: return "瞬间恢复耐力"
		EffectType.HEAL_OVER_TIME: return "持续恢复生命"
		EffectType.MANA_OVER_TIME: return "持续恢复魔力"
		EffectType.BUFF: return "增益效果"
		EffectType.DEBUFF_CURE: return "解除负面状态"
		EffectType.STAT_BOOST: return "永久属性提升"
		EffectType.TELEPORT: return "传送"
		EffectType.RESURRECT: return "复活"
	return "未知效果"


## 获取效果描述
func get_effect_description() -> String:
	var desc = ""
	
	match effect_type:
		EffectType.INSTANT_HEAL:
			desc = "立即恢复 %.0f 点生命值" % effect_value
		
		EffectType.INSTANT_MANA:
			desc = "立即恢复 %.0f 点魔力值" % effect_value
		
		EffectType.INSTANT_STAMINA:
			desc = "立即恢复 %.0f 点耐力值" % effect_value
		
		EffectType.HEAL_OVER_TIME:
			desc = "在 %.1f 秒内恢复 %.0f 点生命值" % [effect_duration, effect_value]
			if effect_per_second > 0:
				desc += " (每秒 %.1f)" % effect_per_second
		
		EffectType.MANA_OVER_TIME:
			desc = "在 %.1f 秒内恢复 %.0f 点魔力值" % [effect_duration, effect_value]
			if effect_per_second > 0:
				desc += " (每秒 %.1f)" % effect_per_second
		
		EffectType.BUFF:
			if not temp_modifiers.is_empty():
				desc = "提供以下增益效果 %.1f 秒:\n" % effect_duration
				for mod in temp_modifiers:
					desc += "  " + mod.get_description() + "\n"
				desc = desc.strip_edges()
		
		EffectType.DEBUFF_CURE:
			if not cures_debuffs.is_empty():
				desc = "解除以下负面状态:\n"
				for debuff in cures_debuffs:
					desc += "  " + debuff + "\n"
				desc = desc.strip_edges()
		
		EffectType.STAT_BOOST:
			desc = "永久提升属性:\n"
			for mod in temp_modifiers:
				desc += "  " + mod.get_description() + "\n"
			desc = desc.strip_edges()
	
	return desc


## 重写完整描述
func get_full_description() -> String:
	var desc = "[b]%s[/b]\n" % item_name
	desc += "[color=#%s]%s[/color]\n" % [get_rarity_color().to_html(), get_rarity_name()]
	desc += "%s\n" % get_effect_type_name()
	
	# 效果描述
	var effect_desc = get_effect_description()
	if effect_desc != "":
		desc += "\n[color=green]%s[/color]\n" % effect_desc
	
	# 使用时间
	if use_time > 0:
		desc += "\n使用时间: %.1f 秒" % use_time
	
	# 冷却时间
	if cooldown > 0:
		desc += "\n冷却时间: %.1f 秒" % cooldown
	
	if not usable_in_combat:
		desc += "\n[color=red]战斗中无法使用[/color]"
	
	# 基础描述
	if description != "":
		desc += "\n\n%s\n" % description
	
	# 堆叠信息
	if max_stack > 1:
		desc += "\n最大堆叠: %d" % max_stack
	
	if weight > 0:
		desc += "\n重量: %.1f" % weight
	
	if can_sell:
		desc += "\n售价: %d 金币" % get_sell_price()
	
	return desc