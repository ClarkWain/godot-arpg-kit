## 战斗组件
## 附加到任何可战斗实体（玩家、敌人、NPC）
## 管理战斗状态、攻击和受伤逻辑
class_name CombatComponent
extends Node

## 战斗实体引用
@export var entity: Node = null

## StatsComponent 引用
@export var stats_component: Node = null

## StatusEffectManager 引用
@export var status_effect_manager: Node = null

## 当前战斗状态
var combat_state: CombatState.State = CombatState.State.IDLE

## 当前连击数
var combo_count: int = 0

## 连击窗口时间（秒）
@export var combo_window: float = 1.5

## 上次攻击时间
var last_attack_time: float = 0.0

## 无敌时间（秒）
@export var invincibility_duration: float = 0.0

## 无敌结束时间
var invincibility_end_time: float = 0.0

## 是否在无敌状态
var is_invincible: bool = false

## 信号
signal state_changed(old_state: CombatState.State, new_state: CombatState.State)
signal damage_dealt(target: Node, damage_info: DamageInfo)
signal damage_received(source: Node, damage_info: DamageInfo)
signal combo_achieved(combo_count: int)
signal died(killer: Node)

func _ready() -> void:
	# 自动查找组件
	if not entity:
		entity = get_parent()
	
	if not stats_component:
		stats_component = entity.get_node_or_null("StatsComponent")
	
	if not status_effect_manager:
		status_effect_manager = entity.get_node_or_null("StatusEffectManager")
	
	# 连接生命值为0的信号
	if stats_component and stats_component.has_signal("health_depleted"):
		stats_component.health_depleted.connect(_on_health_depleted)

func _process(delta: float) -> void:
	# 更新无敌状态
	if is_invincible and Time.get_ticks_msec() / 1000.0 > invincibility_end_time:
		is_invincible = false
	
	# 检查连击超时
	if combo_count > 0:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_attack_time > combo_window:
			_reset_combo()

## 设置战斗状态
func set_combat_state(new_state: CombatState.State) -> void:
	if combat_state == new_state:
		return
	
	if not CombatState.can_transition(combat_state, new_state):
		push_warning("Invalid combat state transition: %s -> %s" % [
			CombatState.get_state_name(combat_state),
			CombatState.get_state_name(new_state)
		])
		return
	
	var old_state = combat_state
	combat_state = new_state
	state_changed.emit(old_state, new_state)

## 攻击目标
func attack(target: Node, base_damage: float, damage_type: DamageInfo.DamageType = DamageInfo.DamageType.PHYSICAL, skill_id: String = "") -> DamageInfo:
	if not CombatState.can_attack(combat_state):
		return null
	
	if not target or not target.has_method("receive_damage"):
		return null
	
	# 创建伤害信息
	var damage_info = DamageInfo.new(entity, target, base_damage, damage_type)
	damage_info.skill_id = skill_id
	
	# 设置击退方向
	if entity is Node2D and target is Node2D:
		damage_info.knockback_direction = (target.global_position - entity.global_position).normalized()
	
	# 计算伤害
	DamageCalculator.calculate_damage(damage_info)
	
	# 应用伤害到目标
	if target.has_node("CombatComponent"):
		target.get_node("CombatComponent").receive_damage(damage_info)
	else:
		target.receive_damage(damage_info)
	
	# 更新连击
	_update_combo()
	
	# 触发信号
	damage_dealt.emit(target, damage_info)
	
	# 触发事件总线
	if QuestEventBus.instance:
		QuestEventBus.instance.damage_dealt.emit(
			target.name if target else "unknown",
			damage_info.final_damage
		)
	
	return damage_info

## 接收伤害
func receive_damage(damage_info: DamageInfo) -> void:
	# 检查无敌状态
	if is_invincible:
		return
	
	# 死亡状态不再接收伤害
	if combat_state == CombatState.State.DEAD:
		return
	
	# 应用伤害到生命值
	if stats_component:
		var actual_damage = damage_info.final_damage
		
		# 触发受伤动画/效果
		set_combat_state(CombatState.State.BEING_HIT)
		
		# 扣除生命值
		stats_component.take_damage(actual_damage)
		
		# 应用状态效果
		if status_effect_manager and not damage_info.status_effects.is_empty():
			for effect_id in damage_info.status_effects:
				status_effect_manager.add_effect(effect_id)
		
		# 应用击退
		if damage_info.knockback_force.length() > 0 and entity.has_method("apply_knockback"):
			entity.apply_knockback(damage_info.knockback_force * damage_info.knockback_direction)
		
		# 触发信号
		damage_received.emit(damage_info.source, damage_info)
		
		# 触发事件总线
		if QuestEventBus.instance:
			QuestEventBus.instance.damage_received.emit(
				damage_info.source.name if damage_info.source else "unknown",
				actual_damage
			)
		
		# 暴击事件
		if damage_info.is_critical and QuestEventBus.instance:
			QuestEventBus.instance.custom_event.emit("critical_hit", {
				"attacker": damage_info.source,
				"target": entity,
				"damage": actual_damage
			})
		
		# 短暂无敌时间（避免连续受伤）
		if invincibility_duration > 0:
			is_invincible = true
			invincibility_end_time = Time.get_ticks_msec() / 1000.0 + invincibility_duration
		
		# 恢复到空闲状态
		await get_tree().create_timer(0.3).timeout
		if combat_state == CombatState.State.BEING_HIT:
			set_combat_state(CombatState.State.IDLE)

## 治疗
func heal(amount: float, source: Node = null) -> float:
	if not stats_component:
		return 0.0
	
	var actual_heal = stats_component.heal(amount)
	
	# 触发事件
	if QuestEventBus.instance:
		QuestEventBus.instance.custom_event.emit("healed", {
			"target": entity,
			"amount": actual_heal,
			"source": source
		})
	
	return actual_heal

## 死亡处理
func die(killer: Node = null) -> void:
	if combat_state == CombatState.State.DEAD:
		return
	
	set_combat_state(CombatState.State.DEAD)
	
	# 触发死亡信号
	died.emit(killer)
	
	# 触发事件总线
	if QuestEventBus.instance and killer:
		# 检查是否是敌人被击杀
		if entity.has_method("get_enemy_type"):
			var enemy_type = entity.get_enemy_type()
			var enemy_level = stats_component.level if stats_component else 1
			QuestEventBus.instance.enemy_killed.emit(enemy_type, entity.name, enemy_level)

## 检查是否可以攻击
func can_attack() -> bool:
	return CombatState.can_attack(combat_state) and not is_invincible

## 检查是否可以移动
func can_move() -> bool:
	return CombatState.can_move(combat_state)

## 更新连击
func _update_combo() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_attack_time <= combo_window:
		combo_count += 1
		combo_achieved.emit(combo_count)
	else:
		combo_count = 1
	
	last_attack_time = current_time

## 重置连击
func _reset_combo() -> void:
	combo_count = 0

## 生命值耗尽回调
func _on_health_depleted() -> void:
	die()

## 获取StatsComponent
func get_stats_component():
	return stats_component

## 获取StatusEffectManager
func get_status_effect_manager():
	return status_effect_manager
