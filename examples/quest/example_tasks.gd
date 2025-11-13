## 示例任务配置
## 展示如何创建各种类型的任务
extends Node

## 创建示例任务1: 击杀史莱姆
static func create_kill_slimes_task() -> TaskData:
	var task = TaskData.new()
	task.task_id = "kill_slimes"
	task.task_name = "清理史莱姆"
	task.description = "村庄附近出现了大量史莱姆,请帮忙清理10只史莱姆。"
	task.category = "支线"
	task.priority = 1
	
	# 创建目标: 击杀10只史莱姆
	var objective = CountObjective.new()
	objective.objective_id = "kill_slimes_obj"
	objective.description = "击杀史莱姆"
	objective.target_type = "kill_enemy"
	objective.target_id = "slime"
	objective.required_count = 10
	task.objectives.append(objective)
	
	# 创建奖励
	var exp_reward = ExperienceReward.new()
	exp_reward.reward_id = "exp_1"
	exp_reward.experience = 100
	task.rewards.append(exp_reward)
	
	var item_reward = ItemReward.new()
	item_reward.reward_id = "gold_1"
	item_reward.item_id = "gold_coin"
	item_reward.quantity = 50
	task.rewards.append(item_reward)
	
	return task

## 创建示例任务2: 收集草药
static func create_collect_herbs_task() -> TaskData:
	var task = TaskData.new()
	task.task_id = "collect_herbs"
	task.task_name = "采集草药"
	task.description = "药剂师需要5株治疗草药来制作药水。"
	task.category = "支线"
	task.priority = 1
	
	# 前置条件: 等级大于等于3
	var level_condition = LevelCondition.new()
	level_condition.condition_id = "level_3"
	level_condition.required_level = 3
	level_condition.compare_type = LevelCondition.CompareType.GREATER_OR_EQUAL
	task.accept_conditions.append(level_condition)
	
	# 创建目标
	var objective = CountObjective.new()
	objective.objective_id = "collect_herbs_obj"
	objective.description = "收集治疗草药"
	objective.target_type = "collect_item"
	objective.target_id = "healing_herb"
	objective.required_count = 5
	task.objectives.append(objective)
	
	# 创建奖励
	var exp_reward = ExperienceReward.new()
	exp_reward.experience = 150
	task.rewards.append(exp_reward)
	
	var potion_reward = ItemReward.new()
	potion_reward.item_id = "health_potion"
	potion_reward.quantity = 3
	task.rewards.append(potion_reward)
	
	return task

## 创建示例任务3: 多目标任务
static func create_multi_objective_task() -> TaskData:
	var task = TaskData.new()
	task.task_id = "village_defense"
	task.task_name = "村庄防御"
	task.description = "怪物正在进攻村庄!击退它们并保护村民。"
	task.category = "主线"
	task.priority = 10
	task.time_limit = 600.0  # 10分钟限时
	
	# 目标1: 击杀哥布林
	var obj1 = CountObjective.new()
	obj1.objective_id = "kill_goblins"
	obj1.description = "击杀哥布林"
	obj1.target_type = "kill_enemy"
	obj1.target_id = "goblin"
	obj1.required_count = 15
	obj1.weight = 2.0
	task.objectives.append(obj1)
	
	# 目标2: 击杀兽人(可选)
	var obj2 = CountObjective.new()
	obj2.objective_id = "kill_orcs"
	obj2.description = "击杀兽人首领"
	obj2.target_type = "kill_enemy"
	obj2.target_id = "orc"
	obj2.required_count = 1
	obj2.optional = true
	obj2.weight = 1.0
	task.objectives.append(obj2)
	
	# 目标3: 保护NPC
	var obj3 = StateObjective.new()
	obj3.objective_id = "protect_npc"
	obj3.description = "确保村长存活"
	obj3.state_type = "npc_alive"
	obj3.target_state = "village_chief"
	obj3.weight = 1.0
	task.objectives.append(obj3)
	
	# 基础奖励
	var exp_reward = ExperienceReward.new()
	exp_reward.experience = 500
	task.rewards.append(exp_reward)
	
	# 可选奖励(完成可选目标后可选择)
	var weapon_reward = ItemReward.new()
	weapon_reward.item_id = "iron_sword"
	weapon_reward.quantity = 1
	task.optional_rewards.append(weapon_reward)
	
	var armor_reward = ItemReward.new()
	armor_reward.item_id = "leather_armor"
	armor_reward.quantity = 1
	task.optional_rewards.append(armor_reward)
	
	return task

## 创建示例任务4: 日常任务
static func create_daily_task() -> TaskData:
	var task = TaskData.new()
	task.task_id = "daily_training"
	task.task_name = "每日训练"
	task.description = "完成每日的战斗训练。"
	task.category = "日常"
	task.priority = 5
	task.repeatable = true
	task.cooldown = 86400.0  # 24小时冷却
	task.max_completions = 0  # 无限次
	
	# 目标: 击杀任意敌人
	var objective = CountObjective.new()
	objective.objective_id = "kill_any"
	objective.description = "击杀任意敌人"
	objective.target_type = "kill_enemy"
	objective.target_id = ""  # 空字符串表示任意敌人
	objective.required_count = 20
	task.objectives.append(objective)
	
	# 奖励
	var exp_reward = ExperienceReward.new()
	exp_reward.experience = 200
	task.rewards.append(exp_reward)
	
	return task

## 创建示例任务5: 任务链
static func create_task_chain() -> Array[TaskData]:
	var tasks: Array[TaskData] = []
	
	# 任务1: 寻找线索
	var task1 = TaskData.new()
	task1.task_id = "chain_1_find_clue"
	task1.task_name = "寻找线索"
	task1.description = "在森林中寻找失踪村民的线索。"
	task1.category = "主线"
	
	var obj1 = StateObjective.new()
	obj1.objective_id = "reach_forest"
	obj1.description = "到达森林深处"
	obj1.state_type = "location"
	obj1.target_state = "deep_forest"
	task1.objectives.append(obj1)
	
	var exp1 = ExperienceReward.new()
	exp1.experience = 100
	task1.rewards.append(exp1)
	
	tasks.append(task1)
	
	# 任务2: 击败怪物
	var task2 = TaskData.new()
	task2.task_id = "chain_2_defeat_monster"
	task2.task_name = "击败怪物"
	task2.description = "击败绑架村民的怪物。"
	task2.category = "主线"
	task2.prerequisite_tasks = ["chain_1_find_clue"]  # 需要完成任务1
	
	var obj2 = CountObjective.new()
	obj2.objective_id = "kill_boss"
	obj2.description = "击败森林守卫"
	obj2.target_type = "kill_enemy"
	obj2.target_id = "forest_guardian"
	obj2.required_count = 1
	task2.objectives.append(obj2)
	
	var exp2 = ExperienceReward.new()
	exp2.experience = 300
	task2.rewards.append(exp2)
	
	tasks.append(task2)
	
	# 任务3: 救出村民
	var task3 = TaskData.new()
	task3.task_id = "chain_3_rescue"
	task3.task_name = "救出村民"
	task3.description = "将村民安全带回村庄。"
	task3.category = "主线"
	task3.prerequisite_tasks = ["chain_2_defeat_monster"]
	
	var obj3 = StateObjective.new()
	obj3.objective_id = "return_village"
	obj3.description = "返回村庄"
	obj3.state_type = "location"
	obj3.target_state = "village"
	task3.objectives.append(obj3)
	
	var exp3 = ExperienceReward.new()
	exp3.experience = 500
	task3.rewards.append(exp3)
	
	var reward_item = ItemReward.new()
	reward_item.item_id = "hero_medal"
	reward_item.quantity = 1
	task3.rewards.append(reward_item)
	
	tasks.append(task3)
	
	return tasks

## 注册所有示例任务到任务管理器
static func register_all_examples(task_manager: TaskManager) -> void:
	task_manager.register_task(create_kill_slimes_task())
	task_manager.register_task(create_collect_herbs_task())
	task_manager.register_task(create_multi_objective_task())
	task_manager.register_task(create_daily_task())
	
	# 注册任务链
	var chain = create_task_chain()
	for task in chain:
		task_manager.register_task(task)