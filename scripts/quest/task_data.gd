## 任务数据资源
## 可序列化的任务配置,存储在.tres文件中
class_name TaskData
extends Resource

## 任务唯一ID
@export var task_id: String = ""

## 任务名称
@export var task_name: String = ""

## 任务描述
@export var description: String = ""

## 任务类别(主线/支线/日常/成就等)
@export_enum("主线", "支线", "日常", "周常", "成就", "赏金") var category: String = "支线"

## 任务优先级(数值越大优先级越高)
@export var priority: int = 0

## 任务目标列表
@export var objectives: Array[TaskObjective] = []

## 接取条件
@export var accept_conditions: Array[TaskCondition] = []

## 完成条件(额外的完成条件,通常目标完成即可)
@export var complete_conditions: Array[TaskCondition] = []

## 失败条件
@export var fail_conditions: Array[TaskCondition] = []

## 奖励列表
@export var rewards: Array[TaskReward] = []

## 可选奖励(玩家可选择其中之一)
@export var optional_rewards: Array[TaskReward] = []

## 时间限制(秒,0表示无限制)
@export var time_limit: float = 0.0

## 冷却时间(秒,用于可重复任务)
@export var cooldown: float = 0.0

## 是否可重复
@export var repeatable: bool = false

## 最大完成次数(0表示无限制)
@export var max_completions: int = 1

## 前置任务ID列表
@export var prerequisite_tasks: Array[String] = []

## 互斥任务ID列表(接取此任务后,互斥任务将不可接取)
@export var exclusive_tasks: Array[String] = []

## 任务标签(用于分类和筛选)
@export var tags: Array[String] = []

## 自定义数据
@export var custom_data: Dictionary = {}

## 验证任务数据完整性
func validate() -> bool:
	if task_id.is_empty():
		push_error("TaskData: task_id is empty")
		return false
	
	if task_name.is_empty():
		push_warning("TaskData: task_name is empty for task %s" % task_id)
	
	if objectives.is_empty():
		push_warning("TaskData: No objectives defined for task %s" % task_id)
	
	return true

## 获取所有必需目标
func get_required_objectives() -> Array[TaskObjective]:
	var required: Array[TaskObjective] = []
	for obj in objectives:
		if not obj.optional:
			required.append(obj)
	return required

## 获取所有可选目标
func get_optional_objectives() -> Array[TaskObjective]:
	var optional: Array[TaskObjective] = []
	for obj in objectives:
		if obj.optional:
			optional.append(obj)
	return optional