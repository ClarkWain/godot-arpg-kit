## 经验奖励
## 给予玩家经验值
class_name ExperienceReward
extends TaskReward

## 经验值
@export var experience: int = 100

## 发放奖励
func grant(context: Dictionary) -> bool:
	var player = context.get("player")
	if not player:
		push_error("ExperienceReward: No player in context")
		return false
	
	# 检查玩家是否有add_experience方法
	if player.has_method("add_experience"):
		player.add_experience(experience)
		return true
	else:
		push_warning("ExperienceReward: Player has no add_experience method")
		return false

## 获取预览文本
func get_preview_text() -> String:
	return "经验值 +%d" % experience

## 序列化
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["experience"] = experience
	return data

## 反序列化
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	experience = data.get("experience", 100)