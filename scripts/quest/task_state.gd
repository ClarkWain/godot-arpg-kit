## 任务状态枚举
## 定义任务在生命周期中的各种状态
class_name TaskState
extends RefCounted

enum State {
	LOCKED,      # 锁定 - 不满足接取条件
	AVAILABLE,   # 可接取 - 满足条件但未接取
	ACTIVE,      # 进行中 - 已接取正在完成
	COMPLETED,   # 已完成 - 完成所有目标
	CLAIMED,     # 已领奖 - 已领取奖励
	FAILED,      # 失败 - 触发失败条件
	EXPIRED,     # 过期 - 限时任务超时
	ABANDONED    # 放弃 - 玩家主动放弃
}

## 状态转换验证
static func can_transition(from: State, to: State) -> bool:
	match from:
		State.LOCKED:
			return to == State.AVAILABLE
		State.AVAILABLE:
			return to == State.ACTIVE
		State.ACTIVE:
			return to in [State.COMPLETED, State.FAILED, State.EXPIRED, State.ABANDONED]
		State.COMPLETED:
			return to == State.CLAIMED
		_:
			return false

## 获取状态名称
static func get_state_name(state: State) -> String:
	match state:
		State.LOCKED: return "锁定"
		State.AVAILABLE: return "可接取"
		State.ACTIVE: return "进行中"
		State.COMPLETED: return "已完成"
		State.CLAIMED: return "已领奖"
		State.FAILED: return "失败"
		State.EXPIRED: return "过期"
		State.ABANDONED: return "放弃"
		_: return "未知"
