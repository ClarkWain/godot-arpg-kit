## 等级条件
## 检查玩家等级是否满足要求
class_name LevelCondition
extends TaskCondition

## 比较类型
enum CompareType {
	EQUAL,              # 等于
	GREATER,            # 大于
	GREATER_OR_EQUAL,   # 大于等于
	LESS,               # 小于
	LESS_OR_EQUAL       # 小于等于
}

## 需要的等级
@export var required_level: int = 1

## 比较类型
@export var compare_type: CompareType = CompareType.GREATER_OR_EQUAL

## 检查条件
func check(context: Dictionary) -> bool:
	var player_level = context.get("player_level", 1)
	
	var result = false
	match compare_type:
		CompareType.EQUAL:
			result = player_level == required_level
		CompareType.GREATER:
			result = player_level > required_level
		CompareType.GREATER_OR_EQUAL:
			result = player_level >= required_level
		CompareType.LESS:
			result = player_level < required_level
		CompareType.LESS_OR_EQUAL:
			result = player_level <= required_level
	
	return result if not negate else not result

## 获取描述
func get_description_text() -> String:
	var op = ""
	match compare_type:
		CompareType.EQUAL: op = "等于"
		CompareType.GREATER: op = "大于"
		CompareType.GREATER_OR_EQUAL: op = "大于等于"
		CompareType.LESS: op = "小于"
		CompareType.LESS_OR_EQUAL: op = "小于等于"
	
	var text = "等级%s %d" % [op, required_level]
	return text if not negate else "不满足: " + text
