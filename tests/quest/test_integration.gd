## 集成测试
## 测试任务系统的完整工作流程
extends TestFramework

var task_manager: TaskManager
var mock_player: MockObjects.MockPlayer

func _init() -> void:
	super._init("集成测试")

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
	test_complete_task_workflow()
	test_task_chain_workflow()
	test_repeatable_task_workflow()
	test_failed_task_workflow()
	test_concurrent_tasks()
	test_save_load_workflow()
	
	print_report()

## 测试: 完整任务流程
func test_complete_task_workflow() -> void:
	setup()
	start_test("完整任务流程")
	
	# 1. 注册任务
	var task = MockObjects.create_test_task_data("workflow_task")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	task.objectives.append(MockObjects.create_count_objective("collect_item", "gold_coin", 10))
	task.rewards.append(MockObjects.create_experience_reward(100))
	task.rewards.append(MockObjects.create_item_reward("health_potion", 3))
	
	var success = task_manager.register_task(task)
	var passed = assert_true(success, "任务注册应该成功")
	
	# 2. 检查可接取
	var can_accept = task_manager.can_accept_task("workflow_task")
	passed = assert_true(can_accept, "应该可以接取任务") and passed
	
	# 3. 接取任务
	success = task_manager.accept_task("workflow_task")
	passed = assert_true(success, "接取任务应该成功") and passed
	
	var instance = task_manager.get_task_instance("workflow_task")
	passed = assert_equal(instance.state, TaskState.State.ACTIVE, "任务应该是活跃状态") and passed
	
	# 4. 更新进度 - 击杀敌人
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 2
	})
	
	var obj1 = instance.objectives[0] as CountObjective
	passed = assert_equal(obj1.current_count, 2, "击杀计数应该是2") and passed
	
	# 5. 继续更新进度
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 3
	})
	
	passed = assert_equal(obj1.current_count, 5, "击杀计数应该是5") and passed
	passed = assert_true(obj1.is_completed, "第一个目标应该完成") and passed
	
	# 6. 完成第二个目标
	task_manager.update_task_progress({
		"type": "collect_item",
		"target_id": "gold_coin",
		"count": 10
	})
	
	passed = assert_equal(instance.state, TaskState.State.COMPLETED, "任务应该自动完成") and passed
	
	# 7. 领取奖励
	var old_exp = mock_player.experience
	success = task_manager.claim_rewards("workflow_task")
	
	passed = assert_true(success, "领取奖励应该成功") and passed
	passed = assert_equal(mock_player.experience, old_exp + 100, "应该获得100经验") and passed
	passed = assert_true(mock_player.inventory.has_item("health_potion", 3), "应该获得3个生命药水") and passed
	passed = assert_equal(instance.state, TaskState.State.CLAIMED, "任务状态应该是已领奖") and passed
	
	end_test(passed)
	teardown()

## 测试: 任务链流程
func test_task_chain_workflow() -> void:
	setup()
	start_test("任务链流程")
	
	# 注册前置任务和后续任务
	var prereq_task = MockObjects.create_test_task_data("chain_prereq")
	prereq_task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	prereq_task.objectives.append(MockObjects.create_count_objective("collect_item", "gold_coin", 10))
	prereq_task.rewards.append(MockObjects.create_experience_reward(100))
	
	var next_task = MockObjects.create_test_task_data("chain_next")
	next_task.prerequisite_tasks.append("chain_prereq")
	next_task.objectives.append(MockObjects.create_count_objective("talk_npc", "elder", 1))
	
	task_manager.register_task(prereq_task)
	task_manager.register_task(next_task)
	
	# 后续任务应该不可接取
	var can_accept = task_manager.can_accept_task("chain_next")
	var passed = assert_false(can_accept, "前置任务未完成时不应该能接取")
	
	# 完成前置任务
	task_manager.accept_task("chain_prereq")
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
	task_manager.claim_rewards("chain_prereq")
	
	# 现在应该可以接取后续任务
	can_accept = task_manager.can_accept_task("chain_next")
	passed = assert_true(can_accept, "前置任务完成后应该能接取") and passed
	
	var success = task_manager.accept_task("chain_next")
	passed = assert_true(success, "接取后续任务应该成功") and passed
	
	end_test(passed)
	teardown()

## 测试: 可重复任务流程
func test_repeatable_task_workflow() -> void:
	setup()
	start_test("可重复任务流程")
	
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
	
	# 尝试立即重新接取（应该失败，冷却中）
	var can_accept = task_manager.can_accept_task("repeatable_task")
	passed = assert_false(can_accept, "冷却期间不应该能重新接取") and passed
	
	end_test(passed)
	teardown()

## 测试: 失败任务流程
func test_failed_task_workflow() -> void:
	setup()
	start_test("失败任务流程")
	
	var task = MockObjects.create_timed_task()
	task_manager.register_task(task)
	task_manager.accept_task("timed_task")
	
	# 手动失败任务
	var success = task_manager.fail_task("timed_task", "测试失败")
	var passed = assert_true(success, "失败任务应该成功")
	
	var instance = task_manager.get_task_instance("timed_task")
	passed = assert_equal(instance.state, TaskState.State.FAILED, "任务状态应该是失败") and passed
	
	# 失败的任务不能领取奖励
	success = task_manager.claim_rewards("timed_task")
	passed = assert_false(success, "失败的任务不应该能领取奖励") and passed
	
	end_test(passed)
	teardown()

## 测试: 并发任务
func test_concurrent_tasks() -> void:
	setup()
	start_test("并发任务")
	
	# 注册多个任务
	var task1 = MockObjects.create_test_task_data("test_concurrent_1")
	task1.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	
	var task2 = MockObjects.create_test_task_data("test_concurrent_2")
	task2.objectives.append(MockObjects.create_count_objective("collect_item", "wood", 10))
	
	var task3 = MockObjects.create_test_task_data("test_concurrent_3")
	task3.objectives.append(MockObjects.create_count_objective("kill_enemy", "slime", 3))
	
	task_manager.register_task(task1)
	task_manager.register_task(task2)
	task_manager.register_task(task3)
	
	# 同时接取多个任务
	task_manager.accept_task("test_concurrent_1")
	task_manager.accept_task("test_concurrent_2")
	task_manager.accept_task("test_concurrent_3")
	
	var active_tasks = task_manager.get_active_tasks()
	var passed = assert_equal(active_tasks.size(), 3, "应该有3个活跃任务")
	
	# 更新进度应该只影响相关任务
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 2
	})
	
	var instance1 = task_manager.get_task_instance("test_concurrent_1")
	var instance2 = task_manager.get_task_instance("test_concurrent_2")
	var instance3 = task_manager.get_task_instance("test_concurrent_3")
	
	var obj1 = instance1.objectives[0] as CountObjective
	var obj2 = instance2.objectives[0] as CountObjective
	var obj3 = instance3.objectives[0] as CountObjective
	
	passed = assert_equal(obj1.current_count, 2, "任务1应该更新") and passed
	passed = assert_equal(obj2.current_count, 0, "任务2不应该更新") and passed
	passed = assert_equal(obj3.current_count, 0, "任务3不应该更新") and passed
	
	end_test(passed)
	teardown()

## 测试: 保存加载流程
func test_save_load_workflow() -> void:
	setup()
	start_test("保存加载流程")
	
	# 创建并进行一些任务
	var task1 = MockObjects.create_test_task_data("test_save_task_1")
	task1.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 5))
	task1.objectives.append(MockObjects.create_count_objective("collect_item", "gold_coin", 10))
	
	var task2 = MockObjects.create_test_task_data("test_save_task_2")
	task2.objectives.append(MockObjects.create_count_objective("collect_item", "stone", 20))
	
	task_manager.register_task(task1)
	task_manager.register_task(task2)
	
	task_manager.accept_task("test_save_task_1")
	task_manager.accept_task("test_save_task_2")
	
	# 更新一些进度
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 3
	})
	task_manager.update_task_progress({
		"type": "collect_item",
		"target_id": "stone",
		"count": 15
	})
	
	# 保存
	var save_data = task_manager.save_data()
	var passed = assert_true(save_data.has("tasks"), "保存数据应该包含任务")
	passed = assert_equal(save_data["tasks"].size(), 2, "应该保存2个任务") and passed
	
	# 清空并加载
	task_manager.player_tasks.clear()
	task_manager.load_data(save_data)
	
	# 验证恢复
	var instance1 = task_manager.get_task_instance("test_save_task_1")
	var instance2 = task_manager.get_task_instance("test_save_task_2")
	
	passed = assert_not_null(instance1, "任务1应该恢复") and passed
	passed = assert_not_null(instance2, "任务2应该恢复") and passed
	
	var obj1 = instance1.objectives[0] as CountObjective
	var obj2 = instance2.objectives[0] as CountObjective
	
	passed = assert_equal(obj1.current_count, 3, "任务1进度应该恢复") and passed
	passed = assert_equal(obj2.current_count, 15, "任务2进度应该恢复") and passed
	
	end_test(passed)
	teardown()
