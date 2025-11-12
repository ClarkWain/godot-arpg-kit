## Mock对象
## 用于测试的模拟对象
class_name MockObjects
extends RefCounted

## Mock玩家
class MockPlayer extends Node:
	var level: int = 1
	var experience: int = 0
	var inventory: MockInventory = null
	
	func _init() -> void:
		inventory = MockInventory.new()
		add_child(inventory)
		inventory.name = "InventoryComponent"
	
	func get_level() -> int:
		return level
	
	func set_level(new_level: int) -> void:
		level = new_level
	
	func add_experience(amount: int) -> void:
		experience += amount
	
	func get_inventory() -> MockInventory:
		return inventory

## Mock背包
class MockInventory extends Node:
	var items: Dictionary = {}  # {item_id: quantity}
	
	func add_item(item_id: String, quantity: int = 1) -> bool:
		if items.has(item_id):
			items[item_id] += quantity
		else:
			items[item_id] = quantity
		return true
	
	func remove_item(item_id: String, quantity: int = 1) -> bool:
		if not items.has(item_id):
			return false
		
		items[item_id] -= quantity
		if items[item_id] <= 0:
			items.erase(item_id)
		return true
	
	func has_item(item_id: String, quantity: int = 1) -> bool:
		return items.get(item_id, 0) >= quantity
	
	func get_item_count(item_id: String) -> int:
		return items.get(item_id, 0)
	
	func clear() -> void:
		items.clear()

## 创建测试用的任务数据
static func create_test_task_data(task_id: String = "test_task") -> TaskData:
	var task = TaskData.new()
	task.task_id = task_id
	task.task_name = "测试任务"
	task.description = "这是一个测试任务"
	task.category = "支线"
	return task

## 创建计数目标
static func create_count_objective(target_type: String, target_id: String, count: int) -> CountObjective:
	var obj = CountObjective.new()
	obj.objective_id = "obj_%s_%s" % [target_type, target_id]
	obj.description = "收集 %s x%d" % [target_id, count]
	obj.target_type = target_type
	obj.target_id = target_id
	obj.required_count = count
	obj.optional = false
	obj.weight = 1.0
	return obj

## 创建状态目标
static func create_state_objective(state_type: String, target_state: String) -> StateObjective:
	var obj = StateObjective.new()
	obj.objective_id = "obj_%s_%s" % [state_type, target_state]
	obj.description = "到达状态: %s" % target_state
	obj.state_type = state_type
	obj.target_state = target_state
	obj.optional = false
	obj.weight = 1.0
	return obj

## 创建等级条件
static func create_level_condition(level: int, compare_type: LevelCondition.CompareType = LevelCondition.CompareType.GREATER_OR_EQUAL) -> LevelCondition:
	var condition = LevelCondition.new()
	condition.required_level = level
	condition.compare_type = compare_type
	condition.description = "等级要求: %d" % level
	return condition

## 创建经验奖励
static func create_experience_reward(exp: int) -> ExperienceReward:
	var reward = ExperienceReward.new()
	reward.reward_id = "exp_reward"
	reward.description = "经验值奖励"
	reward.experience = exp
	return reward

## 创建物品奖励
static func create_item_reward(item_id: String, quantity: int) -> ItemReward:
	var reward = ItemReward.new()
	reward.reward_id = "item_reward_%s" % item_id
	reward.description = "物品奖励: %s" % item_id
	reward.item_id = item_id
	reward.quantity = quantity
	return reward

## 创建完整的测试任务
static func create_full_test_task(task_id: String = "full_test_task") -> TaskData:
	var task = create_test_task_data(task_id)
	task.task_name = "完整测试任务"
	task.description = "包含所有功能的测试任务"
	
	# 添加目标
	task.objectives.append(create_count_objective("kill_enemy", "goblin", 5))
	task.objectives.append(create_count_objective("collect_item", "gold_coin", 10))
	
	# 添加接取条件
	task.accept_conditions.append(create_level_condition(1))
	
	# 添加奖励
	task.rewards.append(create_experience_reward(100))
	task.rewards.append(create_item_reward("health_potion", 3))
	
	return task

## 创建可重复任务
static func create_repeatable_task() -> TaskData:
	var task = create_test_task_data("repeatable_task")
	task.task_name = "可重复任务"
	task.repeatable = true
	task.cooldown = 60.0  # 60秒冷却
	task.max_completions = 3  # 最多完成3次
	
	task.objectives.append(create_count_objective("collect_item", "wood", 5))
	task.rewards.append(create_experience_reward(50))
	
	return task

## 创建限时任务
static func create_timed_task() -> TaskData:
	var task = create_test_task_data("timed_task")
	task.task_name = "限时任务"
	task.time_limit = 300.0  # 5分钟限时
	
	task.objectives.append(create_count_objective("kill_enemy", "slime", 10))
	task.rewards.append(create_experience_reward(200))
	
	return task

## 创建带前置任务的任务
static func create_prerequisite_task() -> TaskData:
	var task = create_test_task_data("prerequisite_task")
	task.task_name = "前置任务测试"
	task.prerequisite_tasks.append("full_test_task")
	
	task.objectives.append(create_count_objective("talk_npc", "elder", 1))
	task.rewards.append(create_experience_reward(150))
	
	return task
