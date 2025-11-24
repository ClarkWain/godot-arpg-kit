## 任务奖励基类
## 所有任务奖励的抽象基类
class_name TaskReward
extends Resource

## 奖励ID
@export var reward_id: String = ""

## 奖励描述
@export var description: String = ""

## 奖励数量/值
@export var amount: int = 1

## 是否可选奖励
@export var optional: bool = false

## 发放奖励(由子类实现)
## 返回是否成功发放
func grant(context: Dictionary) -> bool:
	push_error("TaskReward.grant() must be overridden")
	return false

## 检查是否可以发放奖励
func can_grant(context: Dictionary) -> bool:
	return true

## 获取奖励预览文本
func get_preview_text() -> String:
	return description

## 序列化
func to_dict() -> Dictionary:
	return {
		"reward_id": reward_id,
		"amount": amount
	}

## 反序列化
func from_dict(data: Dictionary) -> void:
	amount = data.get("amount", 1)