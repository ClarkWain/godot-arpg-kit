## 状态效果管理器
## 组件，管理实体身上的所有状态效果
class_name StatusEffectManager
extends Node

## 目标实体
@export var entity: Node = null

## StatsComponent 引用
@export var stats_component: Node = null

## 当前活跃的状态效果 {effect_id: Array[StatusEffectInstance]}
var active_effects: Dictionary = {}

## 所有已注册的状态效果数据 {effect_id: StatusEffectData}
static var registered_effects: Dictionary[String, StatusEffectData] = {}

## 护盾值
var shield_amount: float = 0.0

## 信号
signal effect_applied(effect_id: String, instance: StatusEffectInstance)
signal effect_removed(effect_id: String, instance: StatusEffectInstance)
signal effect_stacks_changed(effect_id: String, old_count: int, new_count: int)
signal shield_changed(old_amount: float, new_amount: float)

func _ready() -> void:
	# 自动查找组件
	if not entity:
		entity = get_parent()
	
	if not stats_component:
		stats_component = entity.get_node_or_null("StatsComponent")

func _process(delta: float) -> void:
	# 更新所有活跃效果
	for effect_id in active_effects.keys():
		var instances: Array = active_effects[effect_id]
		for i in range(instances.size() - 1, -1, -1):
			var instance: StatusEffectInstance = instances[i]
			instance.update(delta)
			
			# 移除已过期的效果
			if not instance.is_active:
				_remove_effect_instance(effect_id, instance)

## 注册状态效果数据（静态方法）
static func register_effect(effect_data: StatusEffectData) -> bool:
	if not effect_data.validate():
		return false
	
	if registered_effects.has(effect_data.effect_id):
		push_warning("StatusEffect %s already registered" % effect_data.effect_id)
		return false
	
	registered_effects[effect_data.effect_id] = effect_data
	return true

## 批量注册状态效果
static func register_effects(effects: Array[StatusEffectData]) -> void:
	for effect in effects:
		register_effect(effect)

## 添加状态效果
func add_effect(effect_id: String, source: Node = null, custom_duration: float = -1.0) -> StatusEffectInstance:
	if not registered_effects.has(effect_id):
		push_warning("StatusEffect %s not registered" % effect_id)
		return null
	
	var effect_data: StatusEffectData = registered_effects[effect_id]
	
	# 检查叠加类型
	if active_effects.has(effect_id):
		var existing_instances: Array = active_effects[effect_id]
		
		match effect_data.stack_type:
			StatusEffectData.StackType.NONE:
				# 不可叠加，刷新第一个实例
				if not existing_instances.is_empty():
					existing_instances[0].refresh()
					return existing_instances[0]
			
			StatusEffectData.StackType.STACK_COUNT:
				# 叠加层数
				if not existing_instances.is_empty():
					var instance: StatusEffectInstance = existing_instances[0]
					instance.add_stack(1)
					instance.refresh()
					return instance
			
			StatusEffectData.StackType.REFRESH:
				# 刷新时间
				if not existing_instances.is_empty():
					existing_instances[0].refresh()
					return existing_instances[0]
			
			StatusEffectData.StackType.INDEPENDENT:
				# 创建独立实例（在下面处理）
				pass
	
	# 创建新实例
	var instance = StatusEffectInstance.new(effect_data, entity, source)
	
	# 自定义持续时间
	if custom_duration >= 0:
		instance.remaining_time = custom_duration
	
	# 连接信号
	instance.effect_expired.connect(_on_effect_expired.bind(effect_id))
	instance.stack_changed.connect(_on_effect_stacks_changed.bind(effect_id))
	
	# 添加到活跃效果列表
	if not active_effects.has(effect_id):
		active_effects[effect_id] = []
	active_effects[effect_id].append(instance)
	
	# 应用属性修改器
	if stats_component and not effect_data.modifiers.is_empty():
		for modifier in effect_data.modifiers:
			stats_component.add_modifier(modifier)
	
	# 触发应用时效果
	for apply_effect_id in effect_data.on_apply_effects:
		add_effect(apply_effect_id, source)
	
	# 触发信号
	effect_applied.emit(effect_id, instance)
	
	# 触发事件总线
	if CombatEventBus.instance:
		CombatEventBus.instance.status_effect_applied.emit(entity, effect_id)
	
	return instance

## 移除状态效果
func remove_effect(effect_id: String, remove_all: bool = false) -> bool:
	if not active_effects.has(effect_id):
		return false
	
	var instances: Array = active_effects[effect_id]
	if instances.is_empty():
		return false
	
	if remove_all:
		# 移除所有实例
		for instance in instances:
			_remove_effect_instance(effect_id, instance)
		return true
	else:
		# 移除第一个实例
		_remove_effect_instance(effect_id, instances[0])
		return true

## 移除所有状态效果
func remove_all_effects(only_type: StatusEffectData.EffectType = -1) -> void:
	for effect_id in active_effects.keys().duplicate():
		var effect_data = registered_effects.get(effect_id)
		if only_type >= 0 and effect_data and effect_data.effect_type != only_type:
			continue
		remove_effect(effect_id, true)

## 净化负面效果
func cleanse_debuffs(count: int = -1) -> int:
	var cleansed = 0
	
	for effect_id in active_effects.keys().duplicate():
		if count >= 0 and cleansed >= count:
			break
		
		var effect_data = registered_effects.get(effect_id)
		if not effect_data:
			continue
		
		# 只净化可净化的负面效果
		if effect_data.can_be_cleansed and effect_data.effect_type in [
			StatusEffectData.EffectType.DEBUFF,
			StatusEffectData.EffectType.CONTROL,
			StatusEffectData.EffectType.DOT
		]:
			if remove_effect(effect_id):
				cleansed += 1
	
	return cleansed

## 检查是否有某个效果
func has_effect(effect_id: String) -> bool:
	return active_effects.has(effect_id) and not active_effects[effect_id].is_empty()

## 获取效果实例
func get_effect_instance(effect_id: String) -> StatusEffectInstance:
	if not active_effects.has(effect_id):
		return null
	
	var instances: Array = active_effects[effect_id]
	return instances[0] if not instances.is_empty() else null

## 获取效果层数
func get_effect_stacks(effect_id: String) -> int:
	var instance = get_effect_instance(effect_id)
	return instance.stack_count if instance else 0

## 获取所有活跃效果
func get_all_active_effects() -> Array[StatusEffectInstance]:
	var all_effects: Array[StatusEffectInstance] = []
	for instances in active_effects.values():
		all_effects.append_array(instances)
	return all_effects

## 获取当前元素状态（用于元素反应）
func get_active_element() -> String:
	for effect_id in active_effects.keys():
		var effect_data = registered_effects.get(effect_id)
		if effect_data and not effect_data.element.is_empty():
			return effect_data.element
	return ""

## 添加护盾
func add_shield(amount: float) -> void:
	var old_amount = shield_amount
	shield_amount += amount
	shield_changed.emit(old_amount, shield_amount)

## 消耗护盾
func consume_shield(amount: float) -> float:
	var old_amount = shield_amount
	var consumed = minf(amount, shield_amount)
	shield_amount -= consumed
	shield_changed.emit(old_amount, shield_amount)
	return consumed

## 获取护盾值
func get_shield_amount() -> float:
	return shield_amount

## 移除效果实例（内部方法）
func _remove_effect_instance(effect_id: String, instance: StatusEffectInstance) -> void:
	if not active_effects.has(effect_id):
		return
	
	var instances: Array = active_effects[effect_id]
	var index = instances.find(instance)
	if index < 0:
		return
	
	# 移除属性修改器
	var effect_data = registered_effects.get(effect_id)
	if effect_data and stats_component and not effect_data.modifiers.is_empty():
		for modifier in effect_data.modifiers:
			stats_component.remove_modifier(modifier)
	
	# 触发移除时效果
	if effect_data:
		for remove_effect_id in effect_data.on_remove_effects:
			add_effect(remove_effect_id, instance.source)
	
	# 从列表中移除
	instances.remove_at(index)
	if instances.is_empty():
		active_effects.erase(effect_id)
	
	# 触发信号
	effect_removed.emit(effect_id, instance)
	
	# 触发事件总线
	if CombatEventBus.instance:
		CombatEventBus.instance.status_effect_removed.emit(entity, effect_id)

## 效果过期回调
func _on_effect_expired(instance: StatusEffectInstance, effect_id: String) -> void:
	_remove_effect_instance(effect_id, instance)

## 效果层数变化回调
func _on_effect_stacks_changed(old_count: int, new_count: int, effect_id: String) -> void:
	effect_stacks_changed.emit(effect_id, old_count, new_count)

## 序列化
func to_dict() -> Dictionary:
	var effects_data: Array = []
	for effect_id in active_effects:
		for instance in active_effects[effect_id]:
			effects_data.append(instance.to_dict())
	
	return {
		"effects": effects_data,
		"shield_amount": shield_amount
	}

## 反序列化
func from_dict(data: Dictionary) -> void:
	active_effects.clear()
	shield_amount = data.get("shield_amount", 0.0)
	
	var effects_data = data.get("effects", [])
	for effect_dict in effects_data:
		var effect_id = effect_dict.get("effect_id", "")
		if registered_effects.has(effect_id):
			var effect_data = registered_effects[effect_id]
			var instance = StatusEffectInstance.new(effect_data, entity, null)
			instance.from_dict(effect_dict)
			
			if not active_effects.has(effect_id):
				active_effects[effect_id] = []
			active_effects[effect_id].append(instance)
