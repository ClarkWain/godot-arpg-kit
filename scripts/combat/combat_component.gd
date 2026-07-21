## 战斗组件
## 附加到任何可战斗实体（玩家、敌人、NPC）
## 管理战斗状态、攻击和受伤逻辑
class_name CombatComponent
extends Node

# 引入战斗事件总线
const CombatEventBus = preload("res://scripts/combat/combat_event_bus.gd")

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

func _process(_delta: float) -> void:
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
	
	if not target:
		return null
	
	# 检查目标是否可以接收伤害
	var can_receive_damage = target.has_method("receive_damage") or target.has_node("CombatComponent")
	if not can_receive_damage:
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
	
	return damage_info

## 接收伤害
##
## 注意：伤害的减免（闪避、格挡、防御、元素抗性、临时护盾等）已由
## DamageCalculator.calculate_damage() 在攻击链上游完成，final_damage
## 就是最终应扣除的血量。这里直接调用 stats_component.lose_health()
## 进行纯扣血，避免与 stats_component.take_damage() 内部的减伤链
## 产生双重结算（旧版本会把防御/闪避/护盾各算两遍）。
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
		
		# 如果伤害被完全吸收/闪避/格挡后归零，则提前结束
		if actual_damage <= 0:
			# 仍然触发信号，让UI可以显示 "吸收/闪避" 字样
			damage_received.emit(damage_info.source, damage_info)
			return
			
		# 触发受伤动画/效果
		set_combat_state(CombatState.State.BEING_HIT)
		
		# 直接扣血（不再走 stats_component.take_damage 的减伤链，
		# 避免与 DamageCalculator 双重结算）。
		if stats_component.has_method("lose_health"):
			stats_component.lose_health(actual_damage)
		else:
			# 兼容旧接口
			stats_component.take_damage(actual_damage)
		
		# 应用状态效果
		if status_effect_manager and not damage_info.status_effects.is_empty():
			for effect_id in damage_info.status_effects:
				status_effect_manager.add_effect(effect_id)
		
		# 应用击退
		# 应用击退：knockback_force 现在是标量(float)，与
		# knockback_direction (Vector2) 相乘得到完整的击退矢量。
		if damage_info.knockback_force > 0.0 and entity.has_method("apply_knockback"):
			entity.apply_knockback(damage_info.knockback_force * damage_info.knockback_direction)
		
		# 触发信号
		damage_received.emit(damage_info.source, damage_info)
		
		# 暴击事件（简化，不调用事件总线）
		if damage_info.is_critical:
			pass  # 仅通过 damaged 信号传递
		
		# 短暂无敌时间（避免连续受伤）
		if invincibility_duration > 0:
			is_invincible = true
			invincibility_end_time = Time.get_ticks_msec() / 1000.0 + invincibility_duration
		
		# 恢复到空闲状态（仅在场景树中时使用计时器）
		if is_inside_tree():
			var tree = get_tree()
			if tree:
				await tree.create_timer(0.3).timeout
				if combat_state == CombatState.State.BEING_HIT:
					set_combat_state(CombatState.State.IDLE)
		else:
			# 如果不在场景树中（如测试环境），直接恢复
			if combat_state == CombatState.State.BEING_HIT:
				set_combat_state(CombatState.State.IDLE)

## 治疗
func heal(amount: float, _source: Node = null) -> float:
	if not stats_component:
		return 0.0
	
	var actual_heal = stats_component.heal(amount)
	
	return actual_heal

## 死亡处理
func die(killer: Node = null) -> void:
	if combat_state == CombatState.State.DEAD:
		return
	
	set_combat_state(CombatState.State.DEAD)
	
	# 触发死亡信号
	died.emit(killer)

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
