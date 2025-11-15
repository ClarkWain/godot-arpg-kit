## 战斗状态枚举
## 定义战斗实体在战斗中的各种状态
class_name CombatState
extends RefCounted

enum State {
	IDLE,           # 空闲
	ATTACKING,      # 攻击中
	CASTING,        # 施法中
	RECOVERING,     # 恢复中（后摇）
	BEING_HIT,      # 受击中
	STUNNED,        # 眩晕
	DEAD            # 死亡
}

## 状态转换验证
static func can_transition(from: State, to: State) -> bool:
	# 死亡状态无法转换
	if from == State.DEAD:
		return false
	
	# 任何状态都可以转换为死亡
	if to == State.DEAD:
		return true
	
	# 眩晕状态只能转换为空闲或死亡
	if from == State.STUNNED:
		return to in [State.IDLE, State.DEAD]
	
	# 受击状态可以转换为任意状态（可被打断）
	if from == State.BEING_HIT:
		return true
	
	# 其他状态的正常转换
	match from:
		State.IDLE:
			return to in [State.ATTACKING, State.CASTING, State.BEING_HIT, State.STUNNED]
		State.ATTACKING:
			return to in [State.RECOVERING, State.IDLE, State.BEING_HIT, State.STUNNED]
		State.CASTING:
			return to in [State.IDLE, State.BEING_HIT, State.STUNNED]
		State.RECOVERING:
			return to in [State.IDLE, State.ATTACKING, State.BEING_HIT, State.STUNNED]
		_:
			return false

## 获取状态名称
static func get_state_name(state: State) -> String:
	match state:
		State.IDLE: return "空闲"
		State.ATTACKING: return "攻击中"
		State.CASTING: return "施法中"
		State.RECOVERING: return "恢复中"
		State.BEING_HIT: return "受击中"
		State.STUNNED: return "眩晕"
		State.DEAD: return "死亡"
		_: return "未知"

## 检查状态是否可以被打断
static func can_be_interrupted(state: State) -> bool:
	return state in [State.ATTACKING, State.CASTING, State.RECOVERING]

## 检查状态是否可以移动
static func can_move(state: State) -> bool:
	return state in [State.IDLE]

## 检查状态是否可以攻击
static func can_attack(state: State) -> bool:
	return state in [State.IDLE]
