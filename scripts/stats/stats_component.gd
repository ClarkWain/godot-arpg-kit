class_name StatsComponent
extends Node
## 属性组件
##
## 管理角色的所有属性,包括基础值、修正器、派生属性计算
## 挂载到角色节点上使用

## ========== 信号 ==========
signal stat_changed(stat_type: StatModifier.StatType, old_value: float, new_value: float)
signal health_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal energy_shield_changed(current: float, maximum: float)
signal health_depleted
signal modifiers_changed
signal level_up(new_level: int, stat_points_gained: int)
signal experience_gained(amount: int, new_total: int)


## ========== 导出属性 ==========
@export var base_stats: StatsData  ## 基础属性数据

@export_group("Level System")
@export var exp_curve_multiplier: float = 1.5  ## 经验曲线倍数,用于计算升级所需经验
@export var exp_base_value: int = 100  ## 经验曲线基础值
@export var stat_points_per_level: int = 5  ## 每次升级获得的属性点

@export_group("Stat Point Reset")
@export var initial_strength: int = 10  ## 初始力量值(用于重置)
@export var initial_agility: int = 10  ## 初始敏捷值(用于重置)
@export var initial_intelligence: int = 10  ## 初始智力值(用于重置)
@export var initial_vitality: int = 10  ## 初始体质值(用于重置)
@export var initial_luck: int = 10  ## 初始幸运值(用于重置)


## ========== 运行时数值 ==========
var current_health: float			## 当前生命值
var current_mana: float				## 当前魔力值
var current_stamina: float			## 当前耐力值
var current_energy_shield: float	## 当前能量护盾值

## 回复计时器
var _health_regen_timer: float = 0.0		## 生命回复计时
var _mana_regen_timer: float = 0.0			## 魔力回复计时
var _stamina_regen_timer: float = 0.0		## 耐力回复计时
var _energy_shield_delay_timer: float = 0.0	## 能量护盾延迟计时器


## ========== 内部数据 ==========
var _modifiers: Dictionary[StatModifier.StatType, Array] = {}  		# {StatType: Array[StatModifier]}，存储所有修正器
var _cached_stats: Dictionary[StatModifier.StatType, float] = {}  	# {StatType: float}，缓存计算后的属性值
var _is_dirty: bool = true			 	# 标记是否需要重新计算属性值
var _timed_modifiers: Array[Dictionary] = []  # 临时修正器计时，格式: [{modifier: StatModifier, remaining_time: float}]


func _ready():
	if not base_stats:
		push_error("StatsComponent: base_stats 未设置!")
		return
	
	# 初始化修正器字典
	for stat_type in StatModifier.StatType.values():
		_modifiers[stat_type] = []
	
	# 强制重新计算所有属性
	_mark_dirty()
	_recalculate_all_stats()
	
	# 初始化当前值
	current_health = get_stat(StatModifier.StatType.MAX_HEALTH)
	current_mana = get_stat(StatModifier.StatType.MAX_MANA)
	current_stamina = get_stat(StatModifier.StatType.MAX_STAMINA)
	current_energy_shield = get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD)


func _process(delta: float):
	# 处理临时修正器计时
	_update_timed_modifiers(delta)

	# 处理回复计时器
	_process_regeneration(delta)


## ========== 回复系统 ==========
func _process_regeneration(delta: float) -> void:

	# 生命回复 - 每秒触发一次
	_health_regen_timer += delta
	if _health_regen_timer >= 1.0:
		_health_regen_timer -= 1.0
		var health_regen = get_stat(StatModifier.StatType.HEALTH_REGEN)
		if health_regen > 0:
			if current_health < get_stat(StatModifier.StatType.MAX_HEALTH):
				heal(health_regen)
		elif health_regen < 0:
			_apply_direct_health_reduction(-health_regen) # 针对负回复速率直接扣血，例如：中毒效果
	
	# 魔力回复 - 每秒触发一次
	_mana_regen_timer += delta
	if _mana_regen_timer >= 1.0:
		_mana_regen_timer -= 1.0
		if current_mana < get_stat(StatModifier.StatType.MAX_MANA):
			var mana_regen = get_stat(StatModifier.StatType.MANA_REGEN)
			if mana_regen > 0:
				restore_mana(mana_regen)
	
	# 耐力回复 - 每秒触发一次
	_stamina_regen_timer += delta
	if _stamina_regen_timer >= 1.0:
		_stamina_regen_timer -= 1.0
		if current_stamina < get_stat(StatModifier.StatType.MAX_STAMINA):
			var stamina_regen = get_stat(StatModifier.StatType.STAMINA_REGEN)
			if stamina_regen > 0:
				restore_stamina(stamina_regen)
	
	# 能量护盾延迟回复 - 每帧检查(因为需要平滑回复)
	if current_energy_shield < get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD):
		_energy_shield_delay_timer += delta
		var recharge_delay = get_stat(StatModifier.StatType.ENERGY_SHIELD_RECHARGE_DELAY)
		
		# 延迟时间到达后开始回复
		if _energy_shield_delay_timer >= recharge_delay:
			var regen_amount = get_stat(StatModifier.StatType.ENERGY_SHIELD_REGEN) * delta
			var old_shield = current_energy_shield
			current_energy_shield = min(
				get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD),
				current_energy_shield + regen_amount
			)
			if current_energy_shield != old_shield:
				energy_shield_changed.emit(current_energy_shield, get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD))


## ========== 获取属性值 ==========

## 获取最终属性值 (带缓存)
func get_stat(stat_type: StatModifier.StatType) -> float:
	# 确保修正器字典已初始化
	if _modifiers.is_empty():
		for st in StatModifier.StatType.values():
			_modifiers[st] = []
	
	if _is_dirty:
		_recalculate_all_stats()
	
	return _cached_stats.get(stat_type, 0.0)


## 获取基础属性值(不含修正器)
func get_base_stat(stat_type: StatModifier.StatType) -> float:
	return _get_base_value(stat_type)


## ========== 修正器管理 ==========

## 添加修正器
func add_modifier(modifier: StatModifier) -> void:
	# 确保修正器字典已初始化
	if _modifiers.is_empty():
		for st in StatModifier.StatType.values():
			_modifiers[st] = []
	
	_modifiers[modifier.stat_type].append(modifier)
	
	# 如果有持续时间,添加到计时列表
	if modifier.duration > 0:
		_timed_modifiers.append({
			"modifier": modifier,
			"remaining_time": modifier.duration
		})
	
	_mark_dirty()
	modifiers_changed.emit()


## 移除特定修正器
func remove_modifier(modifier: StatModifier) -> void:
	var stat_mods = _modifiers[modifier.stat_type]
	var index = stat_mods.find(modifier)
	if index != -1:
		stat_mods.remove_at(index)
		_mark_dirty()
		modifiers_changed.emit()


## 按来源移除所有修正器
func remove_modifiers_by_source(source_id: String) -> void:
	var removed_any = false
	for stat_type in _modifiers.keys():
		var initial_count = _modifiers[stat_type].size()
		_modifiers[stat_type] = _modifiers[stat_type].filter(
			func(mod): return mod.source_id != source_id
		)
		if _modifiers[stat_type].size() < initial_count:
			removed_any = true
	
	# 同时从计时列表移除
	_timed_modifiers = _timed_modifiers.filter(
		func(data): return data.modifier.source_id != source_id
	)
	
	if removed_any:
		_mark_dirty()
		modifiers_changed.emit()


## 按标签移除修正器
func remove_modifiers_by_tag(tag: String) -> void:
	var removed_any = false
	for stat_type in _modifiers.keys():
		var initial_count = _modifiers[stat_type].size()
		_modifiers[stat_type] = _modifiers[stat_type].filter(
			func(mod): return tag not in mod.tags
		)
		if _modifiers[stat_type].size() < initial_count:
			removed_any = true
	
	_timed_modifiers = _timed_modifiers.filter(
		func(data): return tag not in data.modifier.tags
	)
	
	if removed_any:
		_mark_dirty()
		modifiers_changed.emit()


## 获取特定属性的所有修正器
func get_modifiers_for_stat(stat_type: StatModifier.StatType) -> Array:
	return _modifiers[stat_type].duplicate()


## ========== 战斗方法 ==========

## 受到伤害
func take_damage(
	amount: float,						# 伤害数值
	damage_type: String = "physical",	# 伤害类型 ("physical" 或 "magic")
	element: StatModifier.ElementType = StatModifier.ElementType.NONE,	# 元素类型
	can_dodge: bool = true,				# 是否可以闪避
	is_blocking: bool = false			# 是否处于格挡状态
) -> Dictionary:
	"""
	返回字典格式:
	{
		"final_damage": float,		# 最终受到的伤害
		"was_dodged": bool,			# 是否被闪避
		"was_blocked": bool,		# 是否被格挡
		"was_perfect_block": bool,	# 是否触发完美格挡
		"damage_absorbed": float,	# 伤害吸收量
		"damage_reflected": float	# 反射伤害量
	}
	"""
	var result = {
		"final_damage": amount,
		"was_dodged": false,
		"was_blocked": false,
		"was_perfect_block": false,
		"damage_absorbed": 0.0,
		"damage_reflected": 0.0
	}
	
	# 第1步: 闪避检定
	if can_dodge and randf() < get_stat(StatModifier.StatType.DODGE_CHANCE):
		result.was_dodged = true
		result.final_damage = 0.0
		return result
	
	# 第2步: 主动格挡减伤
	if is_blocking:
		result.was_blocked = true
		
		# 判定是否触发完美格挡
		var perfect_block_chance = 0.0
		if damage_type == "physical":
			perfect_block_chance = get_stat(StatModifier.StatType.BLOCK_CHANCE)
		elif damage_type == "magic":
			perfect_block_chance = get_stat(StatModifier.StatType.SPELL_BLOCK_CHANCE)
		
		if randf() < perfect_block_chance:
			result.was_perfect_block = true
			# 完美格挡完全抵消伤害
			result.final_damage = 0.0
			return result
		
		# 普通格挡减伤
		var block_reduction = get_stat(StatModifier.StatType.BLOCK_REDUCTION)
		var block_amount = get_stat(StatModifier.StatType.BLOCK_AMOUNT)
		result.final_damage = max(0, result.final_damage * (1.0 - block_reduction) - block_amount)
	
	# 第3步: 元素抗性
	if element != StatModifier.ElementType.NONE:
		var resistance = _get_element_resistance(element)
		var resist_multiplier = 1.0 - (resistance / 100.0)
		result.final_damage *= resist_multiplier
	
	# 第4步: 护甲/魔抗减伤
	var defense_stat = 0.0
	if damage_type == "physical":
		defense_stat = get_stat(StatModifier.StatType.ARMOR)
	elif damage_type == "magic":
		defense_stat = get_stat(StatModifier.StatType.MAGIC_RESIST)
	
	var damage_reduction = defense_stat / (defense_stat + 100.0)
	result.final_damage *= (1.0 - damage_reduction)
	
	# 第5步: 额外伤害减免
	var extra_reduction = 0.0
	if damage_type == "physical":
		extra_reduction = get_stat(StatModifier.StatType.PHYSICAL_DAMAGE_REDUCTION)
	elif damage_type == "magic":
		extra_reduction = get_stat(StatModifier.StatType.MAGIC_DAMAGE_REDUCTION)
	
	result.final_damage *= (1.0 - extra_reduction)
	
	# 第6步: 能量护盾吸收
	if current_energy_shield > 0:
		var shield_absorb = min(current_energy_shield, result.final_damage)
		current_energy_shield -= shield_absorb
		result.final_damage -= shield_absorb
		result.damage_absorbed += shield_absorb
		
		# 受到伤害时重置能量护盾延迟计时器
		_energy_shield_delay_timer = 0.0
		energy_shield_changed.emit(current_energy_shield, get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD))
	
	# 第7步: 伤害吸收
	var absorb_amount = get_stat(StatModifier.StatType.DAMAGE_ABSORB_AMOUNT)
	var absorb_percent = get_stat(StatModifier.StatType.DAMAGE_ABSORB_PERCENT)
	var total_absorbed = min(result.final_damage, absorb_amount + result.final_damage * absorb_percent)
	result.final_damage -= total_absorbed
	result.damage_absorbed += total_absorbed
	
	# 第8步: 伤害反射
	var reflect_amount = get_stat(StatModifier.StatType.DAMAGE_REFLECT_AMOUNT)
	var reflect_percent = get_stat(StatModifier.StatType.DAMAGE_REFLECT_PERCENT)
	result.damage_reflected = reflect_amount + amount * reflect_percent
	
	# 应用最终伤害
	result.final_damage = max(0, result.final_damage)
	
	var old_health = current_health
	current_health = max(0, current_health - result.final_damage)
	
	# 受到伤害时也重置能量护盾延迟计时器
	if result.final_damage > 0:
		_energy_shield_delay_timer = 0.0
	
	health_changed.emit(current_health, get_stat(StatModifier.StatType.MAX_HEALTH))
	
	if current_health <= 0 and old_health > 0:
		health_depleted.emit()
	
	return result

## 扣除生命（伤害/失血，无视护甲等减伤）
func lose_health(amount: float) -> void:
	if amount <= 0:
		push_error("lose_health 的数值必须为正")
		return

	var old_health = current_health
	current_health = max(0, current_health - amount)
	
	if current_health != old_health:
		health_changed.emit(current_health, get_stat(StatModifier.StatType.MAX_HEALTH))
	
	if current_health <= 0 and old_health > 0:
		health_depleted.emit()


## 恢复生命
func heal(amount: float) -> float:
	if amount <= 0:
		push_error("heal amount must be positive")
		return 0.0

	var old_health = current_health
	var max_hp = get_stat(StatModifier.StatType.MAX_HEALTH)
	current_health = min(max_hp, current_health + amount)
	
	if current_health != old_health:
		health_changed.emit(current_health, max_hp)
	
	return current_health - old_health


## 恢复魔力
func restore_mana(amount: float) -> void:
	var old_mana = current_mana
	var max_mp = get_stat(StatModifier.StatType.MAX_MANA)
	current_mana = min(max_mp, current_mana + amount)
	
	if current_mana != old_mana:
		mana_changed.emit(current_mana, max_mp)


## 消耗魔力，返回是否成功
func consume_mana(amount: float) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, get_stat(StatModifier.StatType.MAX_MANA))
		return true
	return false


## 恢复耐力
func restore_stamina(amount: float) -> void:
	var old_stamina = current_stamina
	var max_stamina = get_stat(StatModifier.StatType.MAX_STAMINA)
	current_stamina = min(max_stamina, current_stamina + amount)
	
	if current_stamina != old_stamina:
		stamina_changed.emit(current_stamina, max_stamina)


## 消耗耐力，返回是否成功
func consume_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, get_stat(StatModifier.StatType.MAX_STAMINA))
		return true
	return false


## ========== 内部方法 ==========

## 标记为需要重新计算
func _mark_dirty() -> void:
	if not _is_dirty:
		_is_dirty = true
		# 延迟到下一帧调用,避免同一帧多次触发
		call_deferred("_on_stats_recalculated")


## 重新计算所有属性
func _recalculate_all_stats() -> void:
	
	var old_stats = _cached_stats.duplicate()
	
	for stat_type in StatModifier.StatType.values():
		_cached_stats[stat_type] = _calculate_stat(stat_type)
	
	_is_dirty = false
	
	# 发送属性变化信号
	for stat_type in StatModifier.StatType.values():
		var old_value = old_stats.get(stat_type, 0.0)
		var new_value = _cached_stats[stat_type]
		if abs(new_value - old_value) > 0.001:  # 浮点数比较容差
			stat_changed.emit(stat_type, old_value, new_value)


## 计算单个属性的最终值
func _calculate_stat(stat_type: StatModifier.StatType) -> float:
	# 确保修正器字典已初始化
	if _modifiers.is_empty():
		for st in StatModifier.StatType.values():
			_modifiers[st] = []
	
	# 获取基础值
	var base_value = _get_base_value(stat_type)
	
	# 应用派生属性加成
	base_value = _apply_derived_bonuses(stat_type, base_value)
	
	# 收集修正器
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	var has_override: bool = false
	var override_value: float = 0.0
	
	# 按优先级排序
	var sorted_modifiers = _modifiers[stat_type].duplicate()
	sorted_modifiers.sort_custom(func(a, b): return a.priority > b.priority)
	
	for modifier in sorted_modifiers:
		match modifier.modifier_type:
			StatModifier.ModifierType.FLAT:
				flat_bonus += modifier.value
			StatModifier.ModifierType.PERCENT:
				percent_bonus += modifier.value
			StatModifier.ModifierType.OVERRIDE:
				has_override = true
				override_value = modifier.value
	
	# 计算最终值
	if has_override:
		return override_value
	
	return (base_value + flat_bonus) * (1.0 + percent_bonus)

## ========== 经验值和升级 ==========

## 获取经验值
func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	
	# 应用经验加成
	var bonus_multiplier = get_stat(StatModifier.StatType.EXPERIENCE_GAIN)
	var final_amount = int(amount * bonus_multiplier)
	
	base_stats.experience += final_amount
	experience_gained.emit(final_amount, base_stats.experience)
	
	# 检查是否升级
	_check_level_up()


## 检查并处理升级
func _check_level_up() -> void:
	while base_stats.experience >= base_stats.experience_to_next_level:
		# 扣除升级所需经验
		base_stats.experience -= base_stats.experience_to_next_level
		
		# 等级提升
		base_stats.level += 1
		
		# 获得属性点
		base_stats.stat_points += stat_points_per_level
		
		# 计算下一级所需经验
		base_stats.experience_to_next_level = _calculate_exp_for_next_level(base_stats.level)
		
		# 升级时完全恢复生命、魔力、耐力
		current_health = get_stat(StatModifier.StatType.MAX_HEALTH)
		current_mana = get_stat(StatModifier.StatType.MAX_MANA)
		current_stamina = get_stat(StatModifier.StatType.MAX_STAMINA)
		current_energy_shield = get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD)
		
		# 发送升级信号
		level_up.emit(base_stats.level, stat_points_per_level)
		
		# 触发相关信号
		health_changed.emit(current_health, get_stat(StatModifier.StatType.MAX_HEALTH))
		mana_changed.emit(current_mana, get_stat(StatModifier.StatType.MAX_MANA))
		stamina_changed.emit(current_stamina, get_stat(StatModifier.StatType.MAX_STAMINA))
		energy_shield_changed.emit(current_energy_shield, get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD))


## 计算升到指定等级所需的经验值
func _calculate_exp_for_next_level(current_level: int) -> int:
	# 使用指数曲线: base_exp * (level ^ multiplier)
	return int(exp_base_value * pow(current_level, exp_curve_multiplier))


## 获取当前等级
func get_level() -> int:
	return base_stats.level


## 获取当前经验值
func get_experience() -> int:
	return base_stats.experience


## 获取升级所需经验值
func get_exp_to_next_level() -> int:
	return base_stats.experience_to_next_level


## 获取升级进度百分比 (0.0 - 1.0)
func get_level_progress() -> float:
	if base_stats.experience_to_next_level <= 0:
		return 0.0
	return float(base_stats.experience) / float(base_stats.experience_to_next_level)

## ========== 属性点分配 ==========

## 分配属性点到指定核心属性
func allocate_stat_point(stat_type: StatModifier.StatType, points: int = 1) -> bool:
	# 检查是否有足够的属性点
	if base_stats.stat_points < points:
		push_warning("属性点不足! 需要 %d 点,当前只有 %d 点" % [points, base_stats.stat_points])
		return false
	
	# 只能分配核心属性
	match stat_type:
		StatModifier.StatType.STRENGTH:
			base_stats.strength += points
		StatModifier.StatType.AGILITY:
			base_stats.agility += points
		StatModifier.StatType.INTELLIGENCE:
			base_stats.intelligence += points
		StatModifier.StatType.VITALITY:
			base_stats.vitality += points
		StatModifier.StatType.LUCK:
			base_stats.luck += points
		_:
			push_warning("只能分配核心属性点 (力量/敏捷/智力/体质/幸运), stat_type=%s" % StatModifier.StatType.keys()[stat_type])
			return false
	
	# 扣除属性点
	base_stats.stat_points -= points
	
	# 标记需要重新计算(因为核心属性影响派生属性)
	_mark_dirty()
	
	return true


## 重置所有属性点 (需要消耗道具或金币,这里只提供基础功能)
func reset_stat_points() -> void:
	# 计算已分配的属性点
	var allocated_points = (base_stats.strength - initial_strength) + \
						   (base_stats.agility - initial_agility) + \
						   (base_stats.intelligence - initial_intelligence) + \
						   (base_stats.vitality - initial_vitality) + \
						   (base_stats.luck - initial_luck)
	
	# 重置核心属性到初始值
	base_stats.strength = initial_strength
	base_stats.agility = initial_agility
	base_stats.intelligence = initial_intelligence
	base_stats.vitality = initial_vitality
	base_stats.luck = initial_luck
	
	# 返还属性点
	base_stats.stat_points += allocated_points
	
	# 标记需要重新计算
	_mark_dirty()


## 获取可用属性点
func get_available_stat_points() -> int:
	return base_stats.stat_points


## ========== 攻击方法 ==========

## 计算造成的伤害 (攻击方调用)
func calculate_damage(
	base_damage: float = 0.0,				# 基础伤害(如果为0则使用物理攻击力)
	damage_type: String = "physical",		# 伤害类型 ("physical" 或 "magic")
	element: StatModifier.ElementType = StatModifier.ElementType.NONE,# 元素类型
	can_crit: bool = true,					# 是否可以暴击
	crit_chance_bonus: float = 0.0,			# 额外暴击率加成
	damage_multiplier: float = 1.0			# 伤害倍率
) -> Dictionary:
	"""
	返回字典格式:
	{
		"total_damage": float,		# 总伤害
		"base_damage": float,		# 基础伤害
		"elemental_damage": float,	# 元素伤害
		"was_crit": bool,			# 是否暴击
		"crit_multiplier": float,	# 暴击倍率
		"life_steal_amount": float,	# 生命偷取量
		"mana_steal_amount": float	# 魔力偷取量
	}
	"""
	var result = {
		"total_damage": 0.0,
		"base_damage": 0.0,
		"elemental_damage": 0.0,
		"was_crit": false,
		"crit_multiplier": 1.0,
		"life_steal_amount": 0.0,
		"mana_steal_amount": 0.0
	}
	
	# 第1步: 确定基础伤害
	if base_damage > 0:
		result.base_damage = base_damage
	else:
		# 使用角色的攻击力
		if damage_type == "physical":
			result.base_damage = get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)
		elif damage_type == "magic":
			result.base_damage = get_stat(StatModifier.StatType.MAGIC_DAMAGE)
	
	# 第2步: 添加元素伤害
	if element != StatModifier.ElementType.NONE:
		match element:
			StatModifier.ElementType.FIRE:
				result.elemental_damage = get_stat(StatModifier.StatType.FIRE_DAMAGE)
			StatModifier.ElementType.ICE:
				result.elemental_damage = get_stat(StatModifier.StatType.ICE_DAMAGE)
			StatModifier.ElementType.LIGHTNING:
				result.elemental_damage = get_stat(StatModifier.StatType.LIGHTNING_DAMAGE)
			StatModifier.ElementType.POISON:
				result.elemental_damage = get_stat(StatModifier.StatType.POISON_DAMAGE)
			StatModifier.ElementType.DARK:
				result.elemental_damage = get_stat(StatModifier.StatType.DARK_DAMAGE)
			StatModifier.ElementType.HOLY:
				result.elemental_damage = get_stat(StatModifier.StatType.HOLY_DAMAGE)
	
	# 第3步: 暴击判定
	if can_crit:
		var total_crit_chance = get_stat(StatModifier.StatType.CRIT_CHANCE) + crit_chance_bonus
		if randf() < total_crit_chance:
			result.was_crit = true
			result.crit_multiplier = get_stat(StatModifier.StatType.CRIT_DAMAGE)
	
	# 第4步: 计算总伤害
	var pre_crit_damage = (result.base_damage + result.elemental_damage) * damage_multiplier
	result.total_damage = pre_crit_damage * result.crit_multiplier
	
	# 第5步: 计算偷取量
	result.life_steal_amount = result.total_damage * get_stat(StatModifier.StatType.LIFE_STEAL)
	result.mana_steal_amount = result.total_damage * get_stat(StatModifier.StatType.MANA_STEAL)
	
	return result


## 对目标造成伤害 (攻击方调用此方法)
func deal_damage_to(
	target: StatsComponent,
	base_damage: float = 0.0,
	damage_type: String = "physical",
	element: StatModifier.ElementType = StatModifier.ElementType.NONE,
	can_crit: bool = true,
	can_dodge: bool = true,
	is_blocking: bool = false
) -> Dictionary:
	"""
	完整的伤害流程:攻击方计算伤害 -> 目标承受伤害 -> 攻击方获得偷取
	
	返回完整的战斗结果字典
	"""
	# 第1步: 计算伤害
	var damage_calc = calculate_damage(base_damage, damage_type, element, can_crit)
	
	# 第2步: 目标承受伤害
	var damage_result = target.take_damage(
		damage_calc.total_damage,
		damage_type,
		element,
		can_dodge,
		is_blocking
	)
	
	# 第3步: 处理生命偷取
	if damage_result.final_damage > 0 and damage_calc.life_steal_amount > 0:
		var actual_steal = damage_calc.life_steal_amount * (damage_result.final_damage / damage_calc.total_damage)
		heal(actual_steal)
	
	# 第4步: 处理魔力偷取
	if damage_result.final_damage > 0 and damage_calc.mana_steal_amount > 0:
		var actual_steal = damage_calc.mana_steal_amount * (damage_result.final_damage / damage_calc.total_damage)
		restore_mana(actual_steal)
	
	# 第5步: 处理伤害反射
	if damage_result.damage_reflected > 0:
		# 反射伤害不会再次触发偷取和反射
		take_damage(damage_result.damage_reflected, damage_type, element, false, false)
	
	# 合并结果
	var complete_result = damage_result.duplicate()
	complete_result["was_crit"] = damage_calc.was_crit
	complete_result["crit_multiplier"] = damage_calc.crit_multiplier
	complete_result["life_stolen"] = damage_calc.life_steal_amount
	complete_result["mana_stolen"] = damage_calc.mana_steal_amount
	
	return complete_result

## ========== 序列化/反序列化 ==========

## 导出当前状态为字典 (用于存档)
func to_dict() -> Dictionary:
	return {
		"current_health": current_health,
		"current_mana": current_mana,
		"current_stamina": current_stamina,
		"current_energy_shield": current_energy_shield,
		"level": base_stats.level,
		"experience": base_stats.experience,
		"experience_to_next_level": base_stats.experience_to_next_level,
		"stat_points": base_stats.stat_points,
		"strength": base_stats.strength,
		"agility": base_stats.agility,
		"intelligence": base_stats.intelligence,
		"vitality": base_stats.vitality,
		"luck": base_stats.luck,
		# 可以选择性保存永久修正器
		"permanent_modifiers": _serialize_permanent_modifiers()
	}


## 从字典加载状态 (用于读档)
func from_dict(data: Dictionary) -> void:
	if data.has("current_health"):
		current_health = data.current_health
	if data.has("current_mana"):
		current_mana = data.current_mana
	if data.has("current_stamina"):
		current_stamina = data.current_stamina
	if data.has("current_energy_shield"):
		current_energy_shield = data.current_energy_shield
	
	if data.has("level"):
		base_stats.level = data.level
	if data.has("experience"):
		base_stats.experience = data.experience
	if data.has("experience_to_next_level"):
		base_stats.experience_to_next_level = data.experience_to_next_level
	if data.has("stat_points"):
		base_stats.stat_points = data.stat_points
	
	if data.has("strength"):
		base_stats.strength = data.strength
	if data.has("agility"):
		base_stats.agility = data.agility
	if data.has("intelligence"):
		base_stats.intelligence = data.intelligence
	if data.has("vitality"):
		base_stats.vitality = data.vitality
	if data.has("luck"):
		base_stats.luck = data.luck
	
	# 确保修正器字典已初始化
	if _modifiers.is_empty():
		for stat_type in StatModifier.StatType.values():
			_modifiers[stat_type] = []
	
	# 加载永久修正器
	if data.has("permanent_modifiers"):
		_deserialize_permanent_modifiers(data.permanent_modifiers)
	
	# 重新计算所有属性
	_mark_dirty()
	
	# 触发状态变化信号
	health_changed.emit(current_health, get_stat(StatModifier.StatType.MAX_HEALTH))
	mana_changed.emit(current_mana, get_stat(StatModifier.StatType.MAX_MANA))
	stamina_changed.emit(current_stamina, get_stat(StatModifier.StatType.MAX_STAMINA))
	energy_shield_changed.emit(current_energy_shield, get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD))


## 序列化永久修正器 (duration = -1)
func _serialize_permanent_modifiers() -> Array:
	var result = []
	for stat_type in _modifiers.keys():
		for modifier in _modifiers[stat_type]:
			if modifier.duration < 0:  # 永久修正器
				result.append({
					"stat_type": modifier.stat_type,
					"modifier_type": modifier.modifier_type,
					"value": modifier.value,
					"source_id": modifier.source_id,
					"tags": modifier.tags,
					"priority": modifier.priority
				})
	return result


## 反序列化永久修正器
func _deserialize_permanent_modifiers(modifiers_data: Array) -> void:
	# 清除现有的永久修正器
	for stat_type in _modifiers.keys():
		_modifiers[stat_type] = _modifiers[stat_type].filter(
			func(mod): return mod.duration >= 0
		)
	
	# 添加保存的永久修正器
	for mod_data in modifiers_data:
		var modifier = StatModifier.new()
		modifier.stat_type = mod_data.stat_type
		modifier.modifier_type = mod_data.modifier_type
		modifier.value = mod_data.value
		modifier.source_id = mod_data.get("source_id", "")
		modifier.tags = mod_data.get("tags", [])
		modifier.priority = mod_data.get("priority", 0)
		modifier.duration = -1  # 永久
		
		_modifiers[modifier.stat_type].append(modifier)

## ========== 调试和工具 ==========

## 获取所有激活的修正器，返回字典格式，键为属性类型，值为修正器数组
func get_all_active_modifiers() -> Dictionary:
	var result = {}
	for stat_type in _modifiers.keys():
		if _modifiers[stat_type].size() > 0:
			result[StatModifier.StatType.keys()[stat_type]] = _modifiers[stat_type].duplicate()
	return result


## 打印当前属性状态 (调试用)
func debug_print_stats() -> void:
	print("========== StatsComponent 调试信息 ==========")
	print("等级: %d (经验: %d/%d)" % [base_stats.level, base_stats.experience, base_stats.experience_to_next_level])
	print("属性点: %d" % base_stats.stat_points)
	print("")
	print("核心属性:")
	print("  力量: %d" % base_stats.strength)
	print("  敏捷: %d" % base_stats.agility)
	print("  智力: %d" % base_stats.intelligence)
	print("  体质: %d" % base_stats.vitality)
	print("  幸运: %d" % base_stats.luck)
	print("")
	print("生存属性:")
	print("  生命: %.1f/%.1f" % [current_health, get_stat(StatModifier.StatType.MAX_HEALTH)])
	print("  魔力: %.1f/%.1f" % [current_mana, get_stat(StatModifier.StatType.MAX_MANA)])
	print("  耐力: %.1f/%.1f" % [current_stamina, get_stat(StatModifier.StatType.MAX_STAMINA)])
	print("  护盾: %.1f/%.1f" % [current_energy_shield, get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD)])
	print("")
	print("攻击属性:")
	print("  物理攻击: %.1f" % get_stat(StatModifier.StatType.PHYSICAL_DAMAGE))
	print("  魔法攻击: %.1f" % get_stat(StatModifier.StatType.MAGIC_DAMAGE))
	print("  攻击速度: %.2f" % get_stat(StatModifier.StatType.ATTACK_SPEED))
	print("  暴击率: %.1f%%" % (get_stat(StatModifier.StatType.CRIT_CHANCE) * 100))
	print("  暴击伤害: %.1f%%" % (get_stat(StatModifier.StatType.CRIT_DAMAGE) * 100))
	print("")
	print("防御属性:")
	print("  护甲: %.1f" % get_stat(StatModifier.StatType.ARMOR))
	print("  魔抗: %.1f" % get_stat(StatModifier.StatType.MAGIC_RESIST))
	print("  闪避率: %.1f%%" % (get_stat(StatModifier.StatType.DODGE_CHANCE) * 100))
	print("")
	print("激活的修正器数量: %d" % _count_active_modifiers())
	print("=========================================")


## 统计激活的修正器数量
func _count_active_modifiers() -> int:
	var count = 0
	for stat_type in _modifiers.keys():
		count += _modifiers[stat_type].size()
	return count


## 获取属性详细信息 (包含基础值、修正器、最终值)
func get_stat_breakdown(stat_type: StatModifier.StatType) -> Dictionary:
	var base_value = _get_base_value(stat_type)
	var derived_value = _apply_derived_bonuses(stat_type, base_value)
	var final_value = get_stat(stat_type)
	
	var flat_bonus = 0.0
	var percent_bonus = 0.0
	var modifier_count = 0
	
	for modifier in _modifiers[stat_type]:
		modifier_count += 1
		match modifier.modifier_type:
			StatModifier.ModifierType.FLAT:
				flat_bonus += modifier.value
			StatModifier.ModifierType.PERCENT:
				percent_bonus += modifier.value
	
	return {
		"stat_name": StatModifier.StatType.keys()[stat_type],
		"base_value": base_value,
		"derived_bonus": derived_value - base_value,
		"flat_bonus": flat_bonus,
		"percent_bonus": percent_bonus,
		"final_value": final_value,
		"modifier_count": modifier_count
	}


## 优化：仅在需要时启用_process
func set_auto_regeneration(enabled: bool) -> void:
	set_process(enabled)


## 获取所有属性的最终值 (用于UI显示)
func get_all_stats() -> Dictionary:
	var stats = {}
	for stat_type in StatModifier.StatType.values():
		var stat_name = StatModifier.StatType.keys()[stat_type]
		stats[stat_name] = get_stat(stat_type)
	return stats

## 从 StatsData 获取基础值
func _get_base_value(stat_type: StatModifier.StatType) -> float:
	match stat_type:
		StatModifier.StatType.LEVEL: return base_stats.level
		StatModifier.StatType.EXPERIENCE: return base_stats.experience
		StatModifier.StatType.STAT_POINTS: return base_stats.stat_points
		StatModifier.StatType.STRENGTH: return base_stats.strength
		StatModifier.StatType.AGILITY: return base_stats.agility
		StatModifier.StatType.INTELLIGENCE: return base_stats.intelligence
		StatModifier.StatType.VITALITY: return base_stats.vitality
		StatModifier.StatType.LUCK: return base_stats.luck
		StatModifier.StatType.MAX_HEALTH: return base_stats.max_health
		StatModifier.StatType.MAX_MANA: return base_stats.max_mana
		StatModifier.StatType.MAX_STAMINA: return base_stats.max_stamina
		StatModifier.StatType.PHYSICAL_DAMAGE: return base_stats.physical_damage
		StatModifier.StatType.MAGIC_DAMAGE: return base_stats.magic_damage
		StatModifier.StatType.FIRE_DAMAGE: return base_stats.fire_damage
		StatModifier.StatType.ICE_DAMAGE: return base_stats.ice_damage
		StatModifier.StatType.LIGHTNING_DAMAGE: return base_stats.lightning_damage
		StatModifier.StatType.POISON_DAMAGE: return base_stats.poison_damage
		StatModifier.StatType.DARK_DAMAGE: return base_stats.dark_damage
		StatModifier.StatType.HOLY_DAMAGE: return base_stats.holy_damage
		StatModifier.StatType.ATTACK_SPEED: return base_stats.attack_speed
		StatModifier.StatType.CAST_SPEED: return base_stats.cast_speed
		StatModifier.StatType.CRIT_CHANCE: return base_stats.crit_chance
		StatModifier.StatType.CRIT_DAMAGE: return base_stats.crit_damage
		StatModifier.StatType.ACCURACY: return base_stats.accuracy
		StatModifier.StatType.ARMOR: return base_stats.armor
		StatModifier.StatType.DODGE_CHANCE: return base_stats.dodge_chance
		StatModifier.StatType.BLOCK_CHANCE: return base_stats.block_chance
		StatModifier.StatType.BLOCK_AMOUNT: return base_stats.block_amount
		StatModifier.StatType.BLOCK_REDUCTION: return base_stats.block_reduction
		StatModifier.StatType.PHYSICAL_DAMAGE_REDUCTION: return base_stats.physical_damage_reduction
		StatModifier.StatType.MAGIC_RESIST: return base_stats.magic_resist
		StatModifier.StatType.SPELL_BLOCK_CHANCE: return base_stats.spell_block_chance
		StatModifier.StatType.MAGIC_DAMAGE_REDUCTION: return base_stats.magic_damage_reduction
		StatModifier.StatType.RES_FIRE: return base_stats.res_fire
		StatModifier.StatType.RES_ICE: return base_stats.res_ice
		StatModifier.StatType.RES_LIGHTNING: return base_stats.res_lightning
		StatModifier.StatType.RES_POISON: return base_stats.res_poison
		StatModifier.StatType.RES_DARK: return base_stats.res_dark
		StatModifier.StatType.RES_HOLY: return base_stats.res_holy
		StatModifier.StatType.RES_ALL: return base_stats.res_all
		StatModifier.StatType.STATUS_RES_STUN: return base_stats.status_res_stun
		StatModifier.StatType.STATUS_RES_FREEZE: return base_stats.status_res_freeze
		StatModifier.StatType.STATUS_RES_BURN: return base_stats.status_res_burn
		StatModifier.StatType.STATUS_RES_POISON: return base_stats.status_res_poison
		StatModifier.StatType.STATUS_RES_BLEED: return base_stats.status_res_bleed
		StatModifier.StatType.STATUS_RES_SLOW: return base_stats.status_res_slow
		StatModifier.StatType.MOVE_SPEED: return base_stats.move_speed
		StatModifier.StatType.SPRINT_SPEED: return base_stats.sprint_speed
		StatModifier.StatType.DASH_SPEED: return base_stats.dash_speed
		StatModifier.StatType.DASH_DISTANCE: return base_stats.dash_distance
		StatModifier.StatType.MAX_ENERGY_SHIELD: return base_stats.max_energy_shield
		StatModifier.StatType.ENERGY_SHIELD_REGEN: return base_stats.energy_shield_regen
		StatModifier.StatType.ENERGY_SHIELD_RECHARGE_DELAY: return base_stats.energy_shield_recharge_delay
		StatModifier.StatType.DAMAGE_ABSORB_AMOUNT: return base_stats.damage_absorb_amount
		StatModifier.StatType.DAMAGE_ABSORB_PERCENT: return base_stats.damage_absorb_percent
		StatModifier.StatType.DAMAGE_REFLECT_AMOUNT: return base_stats.damage_reflect_amount
		StatModifier.StatType.DAMAGE_REFLECT_PERCENT: return base_stats.damage_reflect_percent
		StatModifier.StatType.HEALTH_REGEN: return base_stats.health_regen
		StatModifier.StatType.MANA_REGEN: return base_stats.mana_regen
		StatModifier.StatType.STAMINA_REGEN: return base_stats.stamina_regen
		StatModifier.StatType.LIFE_STEAL: return base_stats.life_steal
		StatModifier.StatType.MANA_STEAL: return base_stats.mana_steal
		StatModifier.StatType.COOLDOWN_REDUCTION: return base_stats.cooldown_reduction
		StatModifier.StatType.SKILL_RANGE: return base_stats.skill_range
		StatModifier.StatType.PROJECTILE_COUNT: return base_stats.projectile_count
		StatModifier.StatType.PIERCE_COUNT: return base_stats.pierce_count
		StatModifier.StatType.GOLD_FIND: return base_stats.gold_find
		StatModifier.StatType.ITEM_FIND: return base_stats.item_find
		StatModifier.StatType.EXPERIENCE_GAIN: return base_stats.experience_gain
		StatModifier.StatType.ITEM_QUALITY: return base_stats.item_quality
		StatModifier.StatType.MAX_WEIGHT: return base_stats.max_weight
		StatModifier.StatType.INVENTORY_SLOTS: return base_stats.inventory_slots
		StatModifier.StatType.ARMOR_PENETRATION: return base_stats.armor_penetration
		StatModifier.StatType.MAGIC_PENETRATION: return base_stats.magic_penetration
	
	return 0.0


## 应用核心属性的派生加成
func _apply_derived_bonuses(stat_type: StatModifier.StatType, base_value: float) -> float:
	# 获取核心属性的最终值(包括修正器)
	# 注意: 这里不能调用 get_stat() 因为会造成循环依赖
	# 所以需要直接计算核心属性的值
	var strength = _calculate_core_stat(StatModifier.StatType.STRENGTH)
	var agility = _calculate_core_stat(StatModifier.StatType.AGILITY)
	var intelligence = _calculate_core_stat(StatModifier.StatType.INTELLIGENCE)
	var vitality = _calculate_core_stat(StatModifier.StatType.VITALITY)
	var luck = _calculate_core_stat(StatModifier.StatType.LUCK)
	
	match stat_type:
		# 力量影响
		StatModifier.StatType.PHYSICAL_DAMAGE:
			return base_value + (strength * 2)  # 每点力量 +2 物理攻击
		StatModifier.StatType.CRIT_DAMAGE:
			return base_value + (strength * 0.005)  # 每点力量 +0.5% 暴击伤害
		StatModifier.StatType.MAX_WEIGHT:
			return base_value + (strength * 3)  # 每点力量 +3 负重
		
		# 敏捷影响
		StatModifier.StatType.ATTACK_SPEED:
			return base_value * (1.0 + agility * 0.01)  # 每点敏捷 +1% 攻速
		
		# 智力影响
		StatModifier.StatType.MAGIC_DAMAGE:
			return base_value + (intelligence * 3)  # 每点智力 +3 魔法攻击
		StatModifier.StatType.MAX_MANA:
			return base_value + (intelligence * 5)  # 每点智力 +5 最大魔力
		
		# 体质影响
		StatModifier.StatType.MAX_HEALTH:
			return base_value + (vitality * 10)  # 每点体质 +10 最大生命
		StatModifier.StatType.ARMOR:
			return base_value + vitality  # 每点体质 +1 防御
		
		# 暴击率: 敏捷 + 幸运
		StatModifier.StatType.CRIT_CHANCE:
			return base_value + (agility * 0.001) + (luck * base_stats.luck_crit_bonus)
		
		# 闪避率: 敏捷 + 幸运
		StatModifier.StatType.DODGE_CHANCE:
			return base_value + (agility * 0.0005) + (luck * base_stats.luck_dodge_bonus)
		
		# 幸运影响掉落
		StatModifier.StatType.ITEM_FIND:
			return base_value * (1.0 + luck * base_stats.luck_drop_bonus)
		StatModifier.StatType.ITEM_QUALITY:
			return base_value + (luck * base_stats.luck_quality_bonus)
	
	return base_value


## 计算核心属性的最终值(不包括派生加成,避免循环依赖)
func _calculate_core_stat(stat_type: StatModifier.StatType) -> float:
	# 确保修正器字典已初始化
	if _modifiers.is_empty():
		for st in StatModifier.StatType.values():
			_modifiers[st] = []
	
	# 只适用于核心属性: STRENGTH, AGILITY, INTELLIGENCE, VITALITY, LUCK
	var base_value = _get_base_value(stat_type)
	
	# 收集修正器
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	var has_override: bool = false
	var override_value: float = 0.0
	
	for modifier in _modifiers[stat_type]:
		match modifier.modifier_type:
			StatModifier.ModifierType.FLAT:
				flat_bonus += modifier.value
			StatModifier.ModifierType.PERCENT:
				percent_bonus += modifier.value
			StatModifier.ModifierType.OVERRIDE:
				has_override = true
				override_value = modifier.value
	
	# 计算最终值
	if has_override:
		return override_value
	
	return (base_value + flat_bonus) * (1.0 + percent_bonus)


## 获取元素抗性
func _get_element_resistance(element: StatModifier.ElementType) -> float:
	var base_res = 0.0
	match element:
		StatModifier.ElementType.FIRE: base_res = get_stat(StatModifier.StatType.RES_FIRE)
		StatModifier.ElementType.ICE: base_res = get_stat(StatModifier.StatType.RES_ICE)
		StatModifier.ElementType.LIGHTNING: base_res = get_stat(StatModifier.StatType.RES_LIGHTNING)
		StatModifier.ElementType.POISON: base_res = get_stat(StatModifier.StatType.RES_POISON)
		StatModifier.ElementType.DARK: base_res = get_stat(StatModifier.StatType.RES_DARK)
		StatModifier.ElementType.HOLY: base_res = get_stat(StatModifier.StatType.RES_HOLY)
	
	# 加上全抗性加成
	return base_res + get_stat(StatModifier.StatType.RES_ALL)


## 更新临时修正器计时
func _update_timed_modifiers(delta: float) -> void:
	var expired_modifiers = []
	
	for data in _timed_modifiers:
		data.remaining_time -= delta
		if data.remaining_time <= 0:
			expired_modifiers.append(data.modifier)
	
	# 移除过期的修正器
	for modifier in expired_modifiers:
		remove_modifier(modifier)
	
	# 从计时列表移除
	_timed_modifiers = _timed_modifiers.filter(
		func(data): return data.remaining_time > 0
	)


## 属性重新计算后的回调
func _on_stats_recalculated() -> void:
	# 调整当前值以匹配新的最大值
	_adjust_current_values_to_max()


## 调整当前值不超过最大值
func _adjust_current_values_to_max() -> void:
	var max_hp = get_stat(StatModifier.StatType.MAX_HEALTH)
	var max_mp = get_stat(StatModifier.StatType.MAX_MANA)
	var max_stamina = get_stat(StatModifier.StatType.MAX_STAMINA)
	var max_shield = get_stat(StatModifier.StatType.MAX_ENERGY_SHIELD)
	
	# 确保当前值不超过最大值
	if current_health > max_hp:
		current_health = max_hp
		health_changed.emit(current_health, max_hp)
	
	if current_mana > max_mp:
		current_mana = max_mp
		mana_changed.emit(current_mana, max_mp)

	if current_stamina > max_stamina:
		current_stamina = max_stamina
		stamina_changed.emit(current_stamina, max_stamina)
	
	if current_energy_shield > max_shield:
		current_energy_shield = max_shield
	energy_shield_changed.emit(current_energy_shield, max_shield)


## ========== 战斗方法 ==========

func _apply_direct_health_reduction(amount: float) -> void:
	"""直接扣除生命值,不经过伤害计算流程,用于DoT等效果。"""
	if amount <= 0:
		return
	
	var old_health = current_health
	current_health = max(0, current_health - amount)
	
	if current_health != old_health:
		health_changed.emit(current_health, get_stat(StatModifier.StatType.MAX_HEALTH))
	
	if current_health <= 0 and old_health > 0:
		health_depleted.emit()
