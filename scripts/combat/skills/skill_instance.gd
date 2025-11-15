## 技能实例
## 运行时技能实例，管理技能的冷却和状态
class_name SkillInstance
extends RefCounted

## 技能数据引用
var skill_data: SkillData

## 当前冷却剩余时间
var cooldown_remaining: float = 0.0

## 是否在冷却中
var is_on_cooldown: bool = false

## 当前施法进度（0-1）
var cast_progress: float = 0.0

## 是否正在施法
var is_casting: bool = false

## 是否正在引导
var is_channeling: bool = false

## 技能等级
var skill_level: int = 1

## 额外数据
var metadata: Dictionary = {}

## 信号
signal cooldown_started(duration: float)
signal cooldown_finished()
signal cast_started()
signal cast_finished()
signal cast_interrupted()
signal channeling_started()
signal channeling_tick(tick_count: int)
signal channeling_finished()
signal channeling_interrupted()

## 构造函数
func _init(data: SkillData) -> void:
	skill_data = data

## 更新冷却（每帧调用）
func update(delta: float) -> void:
	if is_on_cooldown:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0:
			cooldown_remaining = 0
			is_on_cooldown = false
			cooldown_finished.emit()

## 开始冷却
func start_cooldown(duration: float = -1.0) -> void:
	if duration < 0:
		duration = skill_data.cooldown
	
	cooldown_remaining = duration
	is_on_cooldown = true
	cooldown_started.emit(duration)

## 检查是否可以使用
func can_use() -> bool:
	return not is_on_cooldown and not is_casting and not is_channeling

## 获取冷却百分比
func get_cooldown_percent() -> float:
	if not is_on_cooldown:
		return 1.0
	return 1.0 - (cooldown_remaining / skill_data.cooldown)

## 重置冷却
func reset_cooldown() -> void:
	cooldown_remaining = 0.0
	is_on_cooldown = false

## 开始施法
func start_cast() -> void:
	is_casting = true
	cast_progress = 0.0
	cast_started.emit()

## 完成施法
func finish_cast() -> void:
	is_casting = false
	cast_progress = 1.0
	cast_finished.emit()

## 打断施法
func interrupt_cast() -> void:
	if is_casting:
		is_casting = false
		cast_progress = 0.0
		cast_interrupted.emit()
	
	if is_channeling:
		is_channeling = false
		channeling_interrupted.emit()

## 序列化
func to_dict() -> Dictionary:
	return {
		"skill_id": skill_data.skill_id,
		"cooldown_remaining": cooldown_remaining,
		"is_on_cooldown": is_on_cooldown,
		"skill_level": skill_level,
		"metadata": metadata
	}

## 反序列化
func from_dict(data: Dictionary) -> void:
	cooldown_remaining = data.get("cooldown_remaining", 0.0)
	is_on_cooldown = data.get("is_on_cooldown", false)
	skill_level = data.get("skill_level", 1)
	metadata = data.get("metadata", {})
