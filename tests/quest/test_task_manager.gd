## TaskManager测试
## 测试任务管理器的核心功能
extends QuestTestFramework

var task_manager: TaskManager
var mock_player: MockObjects.MockPlayer

func _init() -> void:
	super._init("TaskManager测试")

## 设置测试环境
func setup() -> void:
	task_manager = TaskManager.new()
	task_manager._ready()
	
	mock_player = MockObjects.MockPlayer.new()
	task_manager.set_player(mock_player)

## 清理测试环境
func teardown() -> void:
	if task_manager:
		task_manager.queue_free()
	if mock_player:
		mock_player.queue_free()

## 运行所有测试
func run_all_tests() -> void:
	test_register_task()
	test_register_duplicate_task()
	test_register_invalid_task()
	test_accept_task()
	test_cannot_accept_locked_task()
	test_cannot_accept_active_task()
	test_update_task_progress()
	test_complete_task()
	test_claim_rewards()
	test_fail_task()
	test_abandon_task()
	test_repeatable_task()
	test_prerequisite_task()
	test_save_and_load()
	test_get_active_tasks()
	test_get_available_tasks()
	
	print_report()

## 测试: 注册任务
func test_register_task() -> void:
	setup()
	start_test("注册任务")
	
	var task = MockObjects.create_test_task_data("test_001")
	var success = task_manager.register_task(task)
	
	var passed = assert_true(success, "任务注册应该成功")
	passed = assert_true(task_manager.registered_tasks.has("test_001"), "任务应该在注册列表中") and passed
	
	end_test(passed)
	teardown()

## 测试: 注册重复任务
func test_register_duplicate_task() -> void:
	setup()
	start_test("注册重复任务")
	
	var task1 = MockObjects.create_test_task_data("test_002")
	var task2 = MockObjects.create_test_task_data("test_002")
	
	task_manager.register_task(task1)
	var success = task_manager.register_task(task2)
	
	var passed = assert_false(success, "重复注册应该失败")
	end_test(passed)
	teardown()

## 测试: 注册无效任务
func test_register_invalid_task() -> void:
	setup()
	start_test("注册无效任务")
	
	var task = TaskData.new()
	task.task_id = ""  # 无效ID
	
	var success = task_manager.register_task(task)
	var passed = assert_false(success, "无效任务注册应该失败")
	
	end_test(passed)
	teardown()

## 测试: 接取任务
func test_accept_task() -> void:
	setup()
	start_test("接取任务")
	
	var task = MockObjects.create_test_task_data("accept_task_test")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	task_manager.register_task(task)
	
	var can_accept = task_manager.can_accept_task("accept_task_test")
	var success = task_manager.accept_task("accept_task_test")
	
	var passed = assert_true(can_accept, "应该可以接取任务")
	passed = assert_true(success, "接取任务应该成功") and passed
	passed = assert_true(task_manager.player_tasks.has("accept_task_test"), "任务应该在玩家任务列表中") and passed
	
	var instance = task_manager.get_task_instance("accept_task_test")
	passed = assert_not_null(instance, "任务实例应该存在") and passed
	passed = assert_equal(instance.state, TaskState.State.ACTIVE, "任务状态应该是ACTIVE") and passed
	
	end_test(passed)
	teardown()

## 测试: 不能接取锁定任务
func test_cannot_accept_locked_task() -> void:
	setup()
	start_test("不能接取锁定任务")
	
	var task = MockObjects.create_test_task_data("locked_task")
	var level_condition = MockObjects.create_level_condition(10)
	task.accept_conditions.append(level_condition)
	task_manager.register_task(task)
	
	mock_player.set_level(5)  # 等级不足
	
	var can_accept = task_manager.can_accept_task("locked_task")
	var passed = assert_false(can_accept, "等级不足时不应该能接取任务")
	
	end_test(passed)
	teardown()

## 测试: 不能重复接取活跃任务
func test_cannot_accept_active_task() -> void:
	setup()
	start_test("不能重复接取活跃任务")
	
	var task = MockObjects.create_test_task_data("active_task")
	task_manager.register_task(task)
	task_manager.accept_task("active_task")
	
	var can_accept = task_manager.can_accept_task("active_task")
	var passed = assert_false(can_accept, "不应该能重复接取活跃任务")
	
	end_test(passed)
	teardown()

## 测试: 更新任务进度
func test_update_task_progress() -> void:
	setup()
	start_test("更新任务进度")
	
	var task = MockObjects.create_test_task_data("progress_task")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	task_manager.register_task(task)
	task_manager.accept_task("progress_task")
	
	# 模拟击杀敌人事件
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 3
	})
	
	var instance = task_manager.get_task_instance("progress_task")
	var obj = instance.objectives[0] as CountObjective
	
	var passed = assert_equal(obj.current_count, 3, "击杀计数应该是3")
	passed = assert_almost_equal(obj.progress, 0.6, 0.01, "进度应该是60%") and passed
	
	end_test(passed)
	teardown()

## 测试: 完成任务
func test_complete_task() -> void:
	setup()
	start_test("完成任务")
	
	var task = MockObjects.create_test_task_data("complete_task")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	task.objectives.append(MockObjects.create_count_objective("collect_item", "gold_coin", 10))
	task_manager.register_task(task)
	task_manager.accept_task("complete_task")
	
	# 完成所有目标
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 5
	})
	task_manager.update_task_progress({
		"type": "collect_item",
		"target_id": "gold_coin",
		"count": 10
	})
	
	var instance = task_manager.get_task_instance("complete_task")
	var passed = assert_equal(instance.state, TaskState.State.COMPLETED, "任务应该自动完成")
	
	end_test(passed)
	teardown()

## 测试: 领取奖励
func test_claim_rewards() -> void:
	setup()
	start_test("领取奖励")
	
	var task = MockObjects.create_test_task_data("claim_task")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	task.objectives.append(MockObjects.create_count_objective("collect_item", "gold_coin", 10))
	task.rewards.append(MockObjects.create_experience_reward(100))
	task.rewards.append(MockObjects.create_item_reward("health_potion", 3))
	task_manager.register_task(task)
	task_manager.accept_task("claim_task")
	
	# 完成任务
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 5
	})
	task_manager.update_task_progress({
		"type": "collect_item",
		"target_id": "gold_coin",
		"count": 10
	})
	
	var old_exp = mock_player.experience
	var success = task_manager.claim_rewards("claim_task")
	
	var passed = assert_true(success, "领取奖励应该成功")
	passed = assert_equal(mock_player.experience, old_exp + 100, "经验值应该增加100") and passed
	passed = assert_true(mock_player.inventory.has_item("health_potion", 3), "应该获得3个生命药水") and passed
	
	var instance = task_manager.get_task_instance("claim_task")
	passed = assert_equal(instance.state, TaskState.State.CLAIMED, "任务状态应该是CLAIMED") and passed
	
	end_test(passed)
	teardown()

## 测试: 失败任务
func test_fail_task() -> void:
	setup()
	start_test("失败任务")
	
	var task = MockObjects.create_test_task_data("fail_task")
	task_manager.register_task(task)
	task_manager.accept_task("fail_task")
	
	var success = task_manager.fail_task("fail_task", "测试失败")
	var instance = task_manager.get_task_instance("fail_task")
	
	var passed = assert_true(success, "失败任务应该成功")
	passed = assert_equal(instance.state, TaskState.State.FAILED, "任务状态应该是FAILED") and passed
	
	end_test(passed)
	teardown()

## 测试: 放弃任务
func test_abandon_task() -> void:
	setup()
	start_test("放弃任务")
	
	var task = MockObjects.create_test_task_data("abandon_task")
	task_manager.register_task(task)
	task_manager.accept_task("abandon_task")
	
	var success = task_manager.abandon_task("abandon_task")
	var instance = task_manager.get_task_instance("abandon_task")
	
	var passed = assert_true(success, "放弃任务应该成功")
	passed = assert_equal(instance.state, TaskState.State.ABANDONED, "任务状态应该是ABANDONED") and passed
	
	end_test(passed)
	teardown()

## 测试: 可重复任务
func test_repeatable_task() -> void:
	setup()
	start_test("可重复任务")
	
	var task = MockObjects.create_repeatable_task()
	task_manager.register_task(task)
	
	# 第一次完成
	task_manager.accept_task("repeatable_task")
	task_manager.update_task_progress({
		"type": "collect_item",
		"target_id": "wood",
		"count": 5
	})
	task_manager.claim_rewards("repeatable_task")
	
	var instance = task_manager.get_task_instance("repeatable_task")
	var passed = assert_equal(instance.completion_count, 1, "完成次数应该是1")
	
	# 尝试立即重新接取（应该失败，因为冷却中）
	var can_accept = task_manager.can_accept_task("repeatable_task")
	passed = assert_false(can_accept, "冷却期间不应该能重新接取") and passed
	
	end_test(passed)
	teardown()

## 测试: 前置任务
func test_prerequisite_task() -> void:
	setup()
	start_test("前置任务")
	
	var prereq_task = MockObjects.create_test_task_data("prereq_task_base")
	prereq_task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	prereq_task.objectives.append(MockObjects.create_count_objective("collect_item", "gold_coin", 10))
	prereq_task.rewards.append(MockObjects.create_experience_reward(100))
	
	var main_task = MockObjects.create_test_task_data("prerequisite_task")
	main_task.prerequisite_tasks.append("prereq_task_base")
	main_task.objectives.append(MockObjects.create_count_objective("talk_npc", "elder", 1))
	
	task_manager.register_task(prereq_task)
	task_manager.register_task(main_task)
	
	# 前置任务未完成时不能接取
	var can_accept = task_manager.can_accept_task("prerequisite_task")
	var passed = assert_false(can_accept, "前置任务未完成时不应该能接取")
	
	# 完成前置任务
	task_manager.accept_task("prereq_task_base")
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 5
	})
	task_manager.update_task_progress({
		"type": "collect_item",
		"target_id": "gold_coin",
		"count": 10
	})
	task_manager.claim_rewards("prereq_task_base")
	
	# 现在应该可以接取
	can_accept = task_manager.can_accept_task("prerequisite_task")
	passed = assert_true(can_accept, "前置任务完成后应该能接取") and passed
	
	end_test(passed)
	teardown()

## 测试: 保存和加载
func test_save_and_load() -> void:
	setup()
	start_test("保存和加载")
	
	var task = MockObjects.create_test_task_data("save_load_task")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	task_manager.register_task(task)
	task_manager.accept_task("save_load_task")
	
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 3
	})
	
	# 保存
	var save_data = task_manager.save_data()
	
	# 清空并加载
	task_manager.player_tasks.clear()
	task_manager.load_data(save_data)
	
	var instance = task_manager.get_task_instance("save_load_task")
	var passed = assert_not_null(instance, "加载后任务实例应该存在")
	passed = assert_equal(instance.state, TaskState.State.ACTIVE, "任务状态应该保持") and passed
	
	var obj = instance.objectives[0] as CountObjective
	passed = assert_equal(obj.current_count, 3, "目标进度应该保持") and passed
	
	end_test(passed)
	teardown()

## 测试: 获取活跃任务
func test_get_active_tasks() -> void:
	setup()
	start_test("获取活跃任务")
	
	var task1 = MockObjects.create_test_task_data("get_active_1")
	var task2 = MockObjects.create_test_task_data("get_active_2")
	
	task_manager.register_task(task1)
	task_manager.register_task(task2)
	
	task_manager.accept_task("get_active_1")
	task_manager.accept_task("get_active_2")
	
	var active_tasks = task_manager.get_active_tasks()
	var passed = assert_equal(active_tasks.size(), 2, "应该有2个活跃任务")
	
	end_test(passed)
	teardown()

## 测试: 获取可接取任务
func test_get_available_tasks() -> void:
	setup()
	start_test("获取可接取任务")
	
	var task1 = MockObjects.create_test_task_data("get_available_1")
	var task2 = MockObjects.create_test_task_data("get_available_2")
	var task3 = MockObjects.create_test_task_data("get_locked_task")
	
	var level_condition = MockObjects.create_level_condition(10)
	task3.accept_conditions.append(level_condition)
	
	task_manager.register_task(task1)
	task_manager.register_task(task2)
	task_manager.register_task(task3)
	
	mock_player.set_level(5)
	
	var available = task_manager.get_available_tasks()
	var passed = assert_equal(available.size(), 2, "应该有2个可接取任务")
	
	end_test(passed)
	teardown()
