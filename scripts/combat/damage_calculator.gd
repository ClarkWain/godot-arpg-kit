## 伤害计算器
## 纯函数式的伤害计算服务，处理所有伤害计算逻辑
class_name DamageCalculator
extends RefCounted

## 计算最终伤害（主入口）
static func calculate_damage(damage_info: DamageInfo) -> float:
	if not damage_info.source or not damage_info.target:
		return 0.0
	
	# 检查是否闪避
	if _check_dodge(damage_info):
		damage_info.is_dodged = true
		damage_info.final_damage = 0.0
		return 0.0
	
	# 检查是否格挡
	if _check_block(damage_info):
		damage_info.is_blocked = true
		damage_info.final_damage = damage_info.base_damage * 0.5  # 格挡减伤50%
		return damage_info.final_damage
	
	var final_damage = damage_info.base_damage
	
	# 1. 属性加成阶段
	final_damage = _apply_attribute_modifiers(final_damage, damage_info)
	
	# 2. 暴击判定阶段
	final_damage = _apply_critical_hit(final_damage, damage_info)
	
	# 3. 元素反应阶段
	final_damage = _apply_elemental_reaction(final_damage, damage_info)
	
	# 4. 防御削减阶段
	if damage_info.damage_type != DamageInfo.DamageType.TRUE:
		final_damage = _apply_defense_reduction(final_damage, damage_info)
	
	# 5. 伤害吸收阶段（护盾）
	final_damage = _apply_damage_absorption(final_damage, damage_info)
	
	# 确保伤害不为负
	final_damage = maxf(0.0, final_damage)
	
	damage_info.final_damage = final_damage
	return final_damage

## 应用属性加成
static func _apply_attribute_modifiers(damage: float, damage_info: DamageInfo) -> float:
	var source_stats = _get_stats_component(damage_info.source)
	if not source_stats:
		return damage
	
	# 根据伤害类型应用不同的属性加成
	match damage_info.damage_type:
		DamageInfo.DamageType.PHYSICAL:
			var attack = source_stats.get_stat("attack")
			damage *= (1.0 + attack / 100.0)
		DamageInfo.DamageType.MAGICAL, DamageInfo.DamageType.FIRE, \
		DamageInfo.DamageType.ICE, DamageInfo.DamageType.LIGHTNING:
			var magic_power = source_stats.get_stat("magic_power")
			damage *= (1.0 + magic_power / 100.0)
	
	return damage

## 应用暴击
static func _apply_critical_hit(damage: float, damage_info: DamageInfo) -> bool:
	var source_stats = _get_stats_component(damage_info.source)
	if not source_stats:
		return damage
	
	var crit_rate = source_stats.get_stat("critical_rate") / 100.0
	
	# 幸运值影响暴击率
	if source_stats.has_method("get_luck_modified_value"):
		crit_rate = source_stats.get_luck_modified_value(crit_rate, "critical_rate")
	
	# 暴击判定
	if randf() < crit_rate:
		damage_info.is_critical = true
		var crit_damage = source_stats.get_stat("critical_damage") / 100.0
		damage_info.critical_multiplier = crit_damage
		damage *= crit_damage
	
	return damage

## 应用元素反应
static func _apply_elemental_reaction(damage: float, damage_info: DamageInfo) -> float:
	var target_status = _get_status_effect_manager(damage_info.target)
	if not target_status:
		return damage
	
	# 检查目标身上的元素状态
	var target_element = _get_active_element(target_status)
	if target_element.is_empty():
		return damage
	
	# 元素反应表
	var reaction = _check_elemental_reaction(damage_info.damage_type, target_element)
	if not reaction.is_empty():
		damage_info.elemental_reaction = reaction
		
		match reaction:
			"蒸发":  # 火+冰
				damage *= 2.0
			"融化":  # 冰+火
				damage *= 1.5
			"感电":  # 雷+水
				damage *= 1.2
				damage_info.status_effects.append("shocked")
			"超载":  # 火+雷
				damage *= 1.5
				damage_info.status_effects.append("burning")
			"超导":  # 冰+雷
				damage *= 1.3
				damage_info.status_effects.append("frozen")
	
	return damage

## 检查元素反应
static func _check_elemental_reaction(attack_element: DamageInfo.DamageType, target_element: String) -> String:
	match attack_element:
		DamageInfo.DamageType.FIRE:
			if target_element == "ice": return "蒸发"
			if target_element == "lightning": return "超载"
		DamageInfo.DamageType.ICE:
			if target_element == "fire": return "融化"
			if target_element == "lightning": return "超导"
		DamageInfo.DamageType.LIGHTNING:
			if target_element == "water": return "感电"
			if target_element == "fire": return "超载"
			if target_element == "ice": return "超导"
	
	return ""

## 应用防御削减
static func _apply_defense_reduction(damage: float, damage_info: DamageInfo) -> float:
	var target_stats = _get_stats_component(damage_info.target)
	if not target_stats:
		return damage
	
	var defense = target_stats.get_stat("defense")
	
	# 获取护甲穿透
	var source_stats = _get_stats_component(damage_info.source)
	var armor_penetration = 0.0
	if source_stats:
		armor_penetration = source_stats.get_stat("armor_penetration") / 100.0
	
	# 应用护甲穿透
	var effective_defense = defense * (1.0 - armor_penetration)
	
	# 防御减伤公式: damage_reduction = defense / (defense + 100)
	var damage_reduction = effective_defense / (effective_defense + 100.0)
	damage *= (1.0 - damage_reduction)
	
	return damage

## 应用伤害吸收（护盾）
static func _apply_damage_absorption(damage: float, damage_info: DamageInfo) -> float:
	var target_status = _get_status_effect_manager(damage_info.target)
	if not target_status:
		return damage
	
	# 检查是否有护盾效果
	var shield_amount = target_status.get_shield_amount() if target_status.has_method("get_shield_amount") else 0.0
	
	if shield_amount > 0.0:
		if damage <= shield_amount:
			# 护盾完全吸收
			damage_info.is_absorbed = true
			damage_info.absorbed_damage = damage
			target_status.consume_shield(damage)
			return 0.0
		else:
			# 护盾部分吸收
			damage_info.absorbed_damage = shield_amount
			target_status.consume_shield(shield_amount)
			return damage - shield_amount
	
	return damage

## 检查闪避
static func _check_dodge(damage_info: DamageInfo) -> bool:
	var target_stats = _get_stats_component(damage_info.target)
	if not target_stats:
		return false
	
	var dodge_rate = target_stats.get_stat("dodge_rate") / 100.0
	
	# 幸运值影响闪避率
	if target_stats.has_method("get_luck_modified_value"):
		dodge_rate = target_stats.get_luck_modified_value(dodge_rate, "dodge_rate")
	
	return randf() < dodge_rate

## 检查格挡
static func _check_block(damage_info: DamageInfo) -> bool:
	var target_stats = _get_stats_component(damage_info.target)
	if not target_stats:
		return false
	
	var block_rate = target_stats.get_stat("block_rate") / 100.0
	return randf() < block_rate

## 获取目标身上的元素状态
static func _get_active_element(status_manager) -> String:
	if not status_manager or not status_manager.has_method("get_active_element"):
		return ""
	return status_manager.get_active_element()

## 获取 StatsComponent
static func _get_stats_component(entity: Node):
	if not entity:
		return null
	
	if entity.has_node("StatsComponent"):
		return entity.get_node("StatsComponent")
	elif entity.has_method("get_stats_component"):
		return entity.get_stats_component()
	
	return null

## 获取 StatusEffectManager
static func _get_status_effect_manager(entity: Node):
	if not entity:
		return null
	
	if entity.has_node("StatusEffectManager"):
		return entity.get_node("StatusEffectManager")
	elif entity.has_method("get_status_effect_manager"):
		return entity.get_status_effect_manager()
	
	return null
