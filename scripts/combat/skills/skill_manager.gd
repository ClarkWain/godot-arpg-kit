## 技能管理器
## 组件，管理实体的技能槽位和技能使用
class_name SkillManager
extends Node

# 预加载 CombatEventBus
const CombatEventBus = preload("res://scripts/combat/combat_event_bus.gd")

## 实体引用
@export var entity: Node = null

## CombatComponent 引用
@export var combat_component: Node = null

## StatsComponent 引用
@export var stats_component: Node = null

## 技能槽位 {slot_index: SkillInstance}
var skill_slots: Dictionary = {}

## 最大技能槽位数
@export var max_skill_slots: int = 8

## 所有已注册的技能数据 {skill_id: SkillData}
static var registered_skills: Dictionary[String, SkillData] = {}

## 当前施法中的技能
var current_casting_skill: SkillInstance = null

## 施法计时器
var cast_timer: float = 0.0

## 信号
signal skill_equipped(slot: int, skill_id: String)
signal skill_unequipped(slot: int, skill_id: String)
signal skill_used(skill_id: String)
signal skill_cast_started(skill_id: String)
signal skill_cast_finished(skill_id: String)
signal skill_cast_interrupted(skill_id: String)
signal skill_on_cooldown(skill_id: String, duration: float)

func _ready() -> void:
	# 自动查找组件
	if not entity:
		entity = get_parent()
	
	if not combat_component:
		combat_component = entity.get_node_or_null("CombatComponent")
	
	if not stats_component:
		stats_component = entity.get_node_or_null("StatsComponent")

func _process(delta: float) -> void:
	# 更新所有技能冷却
	for skill_instance in skill_slots.values():
		if skill_instance:
			skill_instance.update(delta)
	
	# 更新施法进度
	if current_casting_skill:
		cast_timer += delta
		current_casting_skill.cast_progress = cast_timer / current_casting_skill.skill_data.cast_time
		
		if cast_timer >= current_casting_skill.skill_data.cast_time:
			_finish_cast()

## 注册技能数据（静态方法）
static func register_skill(skill_data: SkillData) -> bool:
	if not skill_data.validate():
		return false
	
	if registered_skills.has(skill_data.skill_id):
		push_warning("Skill %s already registered" % skill_data.skill_id)
		return false
	
	registered_skills[skill_data.skill_id] = skill_data
	return true

## 批量注册技能
static func register_skills(skills: Array[SkillData]) -> void:
	for skill in skills:
		register_skill(skill)

## 装备技能到槽位
func equip_skill(slot: int, skill_id: String) -> bool:
	if slot < 0 or slot >= max_skill_slots:
		push_warning("Invalid skill slot: %d" % slot)
		return false
	
	if not registered_skills.has(skill_id):
		push_warning("Skill %s not registered" % skill_id)
		return false
	
	# 卸载原有技能
	if skill_slots.has(slot) and skill_slots[slot]:
		unequip_skill(slot)
	
	# 创建技能实例
	var skill_data = registered_skills[skill_id]
	var skill_instance = SkillInstance.new(skill_data)
	
	# 连接信号
	skill_instance.cooldown_started.connect(_on_skill_cooldown_started.bind(skill_id))
	skill_instance.cast_started.connect(_on_skill_cast_started.bind(skill_id))
	skill_instance.cast_finished.connect(_on_skill_cast_finished.bind(skill_id))
	skill_instance.cast_interrupted.connect(_on_skill_cast_interrupted.bind(skill_id))
	
	skill_slots[slot] = skill_instance
	skill_equipped.emit(slot, skill_id)
	return true

## 卸载技能
func unequip_skill(slot: int) -> bool:
	if not skill_slots.has(slot):
		return false
	
	var skill_instance: SkillInstance = skill_slots[slot]
	if skill_instance:
		var skill_id = skill_instance.skill_data.skill_id
		skill_slots.erase(slot)
		skill_unequipped.emit(slot, skill_id)
		return true
	
	return false

## 使用技能
func use_skill(slot: int, target: Node = null, target_position: Vector2 = Vector2.ZERO) -> bool:
	if not skill_slots.has(slot):
		return false
	
	var skill_instance: SkillInstance = skill_slots[slot]
	if not skill_instance:
		return false
	
	var skill_data = skill_instance.skill_data
	
	# 检查是否可以使用
	if not skill_instance.can_use():
		return false
	
	# 检查资源消耗
	if not _check_resource_cost(skill_data):
		return false
	
	# 检查距离
	if target and entity is Node2D and target is Node2D:
		var distance = entity.global_position.distance_to(target.global_position)
		if distance > skill_data.cast_range:
			return false
	
	# 消耗资源
	_consume_resources(skill_data)
	
	# 开始施法
	if skill_data.cast_time > 0:
		_start_cast(skill_instance, target, target_position)
	else:
		# 瞬发技能直接执行
		_execute_skill(skill_data, target, target_position)
		skill_instance.start_cooldown()
	
	skill_used.emit(skill_data.skill_id)
	
	return true

## 开始施法
func _start_cast(skill_instance: SkillInstance, target: Node, target_position: Vector2) -> void:
	current_casting_skill = skill_instance
	cast_timer = 0.0
	skill_instance.start_cast()
	
	# 存储目标信息
	skill_instance.metadata["target"] = target
	skill_instance.metadata["target_position"] = target_position

## 完成施法
func _finish_cast() -> void:
	if not current_casting_skill:
		return
	
	var skill_data = current_casting_skill.skill_data
	var target = current_casting_skill.metadata.get("target")
	var target_position = current_casting_skill.metadata.get("target_position", Vector2.ZERO)
	
	# 执行技能效果
	_execute_skill(skill_data, target, target_position)
	
	# 开始冷却
	current_casting_skill.finish_cast()
	current_casting_skill.start_cooldown()
	current_casting_skill = null

## 打断施法
func interrupt_cast() -> void:
	if current_casting_skill:
		current_casting_skill.interrupt_cast()
		current_casting_skill = null
		cast_timer = 0.0

## 执行技能效果
func _execute_skill(skill_data: SkillData, target: Node, target_position: Vector2) -> void:
	match skill_data.target_type:
		SkillData.TargetType.SELF:
			_apply_skill_to_target(skill_data, entity)
		
		SkillData.TargetType.ENEMY, SkillData.TargetType.ALLY:
			if target:
				_apply_skill_to_target(skill_data, target)
		
		SkillData.TargetType.GROUND, SkillData.TargetType.DIRECTION:
			_spawn_skill_at_position(skill_data, target_position)
		
		SkillData.TargetType.AREA:
			_spawn_skill_area(skill_data, target_position)
	
	# 播放特效
	if skill_data.vfx_scene:
		_spawn_vfx(skill_data.vfx_scene, target if target else entity)
	
	# 播放音效
	if skill_data.sfx:
		_play_sfx(skill_data.sfx)

## 应用技能到目标
func _apply_skill_to_target(skill_data: SkillData, target: Node) -> void:
	if not target or not target.has_node("CombatComponent"):
		return
	
	# 1. 计算技能的基础伤害
	var damage = skill_data.base_damage
	if stats_component:
		var scaling_stat = StatModifier.StatType.PHYSICAL_DAMAGE
		if skill_data.damage_type in [DamageInfo.DamageType.MAGICAL, DamageInfo.DamageType.FIRE,
									  DamageInfo.DamageType.ICE, DamageInfo.DamageType.LIGHTNING]:
			scaling_stat = StatModifier.StatType.MAGIC_DAMAGE
		
		var stat_value = stats_component.get_stat(scaling_stat)
		damage += stat_value * skill_data.damage_scaling
	
	# 即使0伤害，也可能需要应用状态效果，所以我们继续
	
	# 2. 创建并完整填充 DamageInfo 对象
	var damage_info = DamageInfo.new(entity, target, damage, skill_data.damage_type)
	damage_info.skill_id = skill_data.skill_id
	
	# 3. 在造成伤害前，添加状态效果
	if not skill_data.status_effects.is_empty():
		for effect_id in skill_data.status_effects:
			if randf() < skill_data.status_effect_chance:
				damage_info.status_effects.append(effect_id)
				
	# 4. 添加击退等其他信息
	if skill_data.knockback_force > 0:
		damage_info.knockback_force = Vector2(skill_data.knockback_force, 0)
		if entity is Node2D and target is Node2D:
			damage_info.knockback_direction = (target.global_position - entity.global_position).normalized()
			
	# 5. 调用伤害计算器（伤害发起者的责任）
	DamageCalculator.calculate_damage(damage_info)
	
	# 6. 直接调用目标的 receive_damage
	var target_combat_component = target.get_node("CombatComponent")
	target_combat_component.receive_damage(damage_info)

## 在位置生成技能效果
func _spawn_skill_at_position(skill_data: SkillData, position: Vector2) -> void:
	# 生成投射物
	if skill_data.projectile_scene:
		for i in range(skill_data.projectile_count):
			var projectile = skill_data.projectile_scene.instantiate()
			get_tree().root.add_child(projectile)
			
			if projectile is Node2D and entity is Node2D:
				projectile.global_position = entity.global_position
				
				# 设置投射物方向
				var direction = (position - entity.global_position).normalized()
				if projectile.has_method("set_direction"):
					projectile.set_direction(direction)
				if projectile.has_method("set_speed"):
					projectile.set_speed(skill_data.projectile_speed)
				if projectile.has_method("set_damage"):
					projectile.set_damage(skill_data.base_damage)

## 生成区域技能
func _spawn_skill_area(skill_data: SkillData, position: Vector2) -> void:
	if skill_data.aoe_scene:
		var aoe = skill_data.aoe_scene.instantiate()
		get_tree().root.add_child(aoe)
		
		if aoe is Node2D:
			aoe.global_position = position
			
			if aoe.has_method("set_radius"):
				aoe.set_radius(skill_data.skill_radius)
			if aoe.has_method("set_damage"):
				aoe.set_damage(skill_data.base_damage)
			if aoe.has_method("set_caster"):
				aoe.set_caster(entity)

## 生成特效
func _spawn_vfx(vfx_scene: PackedScene, target: Node) -> void:
	var vfx = vfx_scene.instantiate()
	if target is Node2D and vfx is Node2D:
		vfx.global_position = target.global_position
	get_tree().root.add_child(vfx)

## 播放音效
func _play_sfx(_sfx: AudioStream) -> void:
	# TODO: 使用音效管理器播放
	pass

## 检查资源消耗
func _check_resource_cost(skill_data: SkillData) -> bool:
	if not stats_component:
		return true
	
	# 检查魔法值
	if skill_data.mana_cost > 0:
		if stats_component.current_mana < skill_data.mana_cost:
			return false
	
	# 检查体力值
	if skill_data.stamina_cost > 0:
		if stats_component.current_stamina < skill_data.stamina_cost:
			return false
	
	return true

## 消耗资源
func _consume_resources(skill_data: SkillData) -> void:
	if not stats_component:
		return
	
	# 消耗魔法值
	if skill_data.mana_cost > 0:
		stats_component.consume_mana(skill_data.mana_cost)
	
	# 消耗体力值
	if skill_data.stamina_cost > 0:
		stats_component.consume_stamina(skill_data.stamina_cost)

## 获取技能实例
func get_skill_instance(slot: int) -> SkillInstance:
	return skill_slots.get(slot)

## 获取技能数据
func get_skill_data(slot: int) -> SkillData:
	var instance = get_skill_instance(slot)
	return instance.skill_data if instance else null

## 信号回调
func _on_skill_cooldown_started(duration: float, skill_id: String) -> void:
	skill_on_cooldown.emit(skill_id, duration)

func _on_skill_cast_started(skill_id: String) -> void:
	skill_cast_started.emit(skill_id)

func _on_skill_cast_finished(skill_id: String) -> void:
	skill_cast_finished.emit(skill_id)

func _on_skill_cast_interrupted(skill_id: String) -> void:
	skill_cast_interrupted.emit(skill_id)

## 序列化
func to_dict() -> Dictionary:
	var slots_data: Dictionary = {}
	for slot in skill_slots:
		var instance: SkillInstance = skill_slots[slot]
		if instance:
			slots_data[str(slot)] = instance.to_dict()
	
	return {
		"skill_slots": slots_data
	}

## 反序列化
func from_dict(data: Dictionary) -> void:
	skill_slots.clear()
	
	var slots_data = data.get("skill_slots", {})
	for slot_str in slots_data:
		var slot = int(slot_str)
		var instance_data = slots_data[slot_str]
		var skill_id = instance_data.get("skill_id", "")
		
		if registered_skills.has(skill_id):
			var skill_data = registered_skills[skill_id]
			var instance = SkillInstance.new(skill_data)
			instance.from_dict(instance_data)
			skill_slots[slot] = instance
