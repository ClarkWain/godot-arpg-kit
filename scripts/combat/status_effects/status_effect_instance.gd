## 状态效果实例
## 运行时的状态效果实例，管理状态效果的生命周期
class_name StatusEffectInstance
extends RefCounted

## 状态效果数据引用
var effect_data: StatusEffectData

## 应用目标
var target: Node = null

## 效果来源
var source: Node = null

## 当前叠加层数
var stack_count: int = 1

## 剩余时间
var remaining_time: float = 0.0

## 距离上次Tick的时间
var _time_since_last_tick: float = 0.0

## 应用时间
var apply_time: float = 0.0

## 是否已激活
var is_active: bool = true

## 自定义数据
var metadata: Dictionary = {}

## 信号
signal effect_ticked(instance: StatusEffectInstance)
signal effect_expired(instance: StatusEffectInstance)
signal stack_changed(old_count: int, new_count: int)

## 构造函数
func _init(data: StatusEffectData, tgt: Node = null, src: Node = null) -> void:
	effect_data = data
	target = tgt
	source = src
	remaining_time = data.duration
	apply_time = Time.get_ticks_msec() / 1000.0
	_time_since_last_tick = 0.0

## 更新状态效果（每帧调用）
func update(delta: float) -> void:
	if not is_active:
		return
	
	# 永久效果不更新时间
	if effect_data.duration > 0:
		remaining_time -= delta
		
		# 检查是否过期
		if remaining_time <= 0:
			expire()
			return
	
	# 处理Tick效果
	if effect_data.tick_interval > 0:
		_time_since_last_tick += delta
		if _time_since_last_tick >= effect_data.tick_interval:
			tick()
			_time_since_last_tick -= effect_data.tick_interval

## Tick处理
func tick() -> void:
	if not is_active or not target:
		return
	
	# DOT伤害
	if effect_data.effect_type == StatusEffectData.EffectType.DOT:
		var damage = effect_data.tick_value * stack_count
		if target.has_node("CombatComponent"):
			var damage_info = DamageInfo.new(source, target, damage, effect_data.tick_damage_type)
			damage_info.metadata["is_dot"] = true
			damage_info.metadata["effect_id"] = effect_data.effect_id
			
			# 计算最终伤害
			DamageCalculator.calculate_damage(damage_info)
			
			target.get_node("CombatComponent").receive_damage(damage_info)
	
	# HOT治疗
	elif effect_data.effect_type == StatusEffectData.EffectType.HOT:
		var heal = effect_data.tick_value * stack_count
		if target.has_node("CombatComponent"):
			target.get_node("CombatComponent").heal(heal, source)
	
	# 使用统一 emit_signal
	emit_signal("effect_ticked", self)

## 增加叠加层数
func add_stack(count: int = 1) -> void:
	var old_count = stack_count
	# 使用标准 min() 函数
	stack_count = min(stack_count + count, effect_data.max_stacks)
	
	if stack_count != old_count:
		emit_signal("stack_changed", old_count, stack_count)

## 移除叠加层数
func remove_stack(count: int = 1) -> bool:
	var old_count = stack_count
	# 使用标准 max() 函数替换 maxi
	stack_count = max(0, stack_count - count)
	
	if stack_count != old_count:
		emit_signal("stack_changed", old_count, stack_count)
	
	# 如果层数为0，效果失效
	if stack_count <= 0:
		expire()
		return true
	
	return false

## 刷新持续时间
func refresh() -> void:
	remaining_time = effect_data.duration

## 延长持续时间
func extend(additional_time: float) -> void:
	if effect_data.duration > 0:
		remaining_time += additional_time

## 效果过期
func expire() -> void:
	if not is_active:
		return
	
	is_active = false
	emit_signal("effect_expired", self)

## 获取剩余时间百分比
func get_remaining_time_percent() -> float:
	if effect_data.duration <= 0:
		return 1.0
	return remaining_time / effect_data.duration

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"effect_id": effect_data.effect_id,
		"stack_count": stack_count,
		"remaining_time": remaining_time,
		"apply_time": apply_time,
		"is_active": is_active,
		"metadata": metadata
	}

## 从字典反序列化
func from_dict(data: Dictionary) -> void:
	stack_count = data.get("stack_count", 1)
	remaining_time = data.get("remaining_time", effect_data.duration)
	apply_time = data.get("apply_time", 0.0)
	is_active = data.get("is_active", true)
	metadata = data.get("metadata", {})
