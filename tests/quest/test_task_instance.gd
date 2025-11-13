## TaskInstance测试
## 测试任务实例的功能
extends TestFramework

func _init() -> void:
	super._init("TaskInstance测试")

## 运行所有测试
func run_all_tests() -> void:
	test_create_instance()
	test_state_transitions()
	test_invalid_state_transition()
	test_objective_initialization()
	test_objective_completion()
	test_overall_progress()
	test_time_limit()
	test_cooldown()
	test_serialization()
	test_signal_emission()
	
	print_report()

## 测试: 创建实例
func test_create_instance() -> void:
	start_test("创建实例")
	
	var task_data = MockObjects.create_test_task_data("test_instance")
	var instance = TaskInstance.new(task_data)
	
	var passed = assert_not_null(instance, "实例应该创建成功")
	passed = assert_equal(instance.task_data, task_data, "任务数据应该正确") and passed
	passed = assert_equal(instance.state, TaskState.State.LOCKED, "初始状态应该是LOCKED") and passed
	
	end_test(passed)

## 测试: 状态转换
func test_state_transitions() -> void:
	start_test("状态转换")
	
	var task_data = MockObjects.create_test_task_data("state_test")
	var instance = TaskInstance.new(task_data)
	
	# LOCKED -> AVAILABLE
	instance.set_state(TaskState.State.AVAILABLE)
	var passed = assert_equal(instance.state, TaskState.State.AVAILABLE, "应该转换到AVAILABLE")
	
	# AVAILABLE -> ACTIVE
	instance.set_state(TaskState.State.ACTIVE)
	passed = assert_equal(instance.state, TaskState.State.ACTIVE, "应该转换到ACTIVE") and passed
	passed = assert_true(instance.start_time > 0, "开始时间应该被记录") and passed
	
	# ACTIVE -> COMPLETED
	instance.set_state(TaskState.State.COMPLETED)
	passed = assert_equal(instance.state, TaskState.State.COMPLETED, "应该转换到COMPLETED") and passed
	passed = assert_true(instance.completion_time > 0, "完成时间应该被记录") and passed
	
	# COMPLETED -> CLAIMED
	instance.set_state(TaskState.State.CLAIMED)
	passed = assert_equal(instance.state, TaskState.State.CLAIMED, "应该转换到CLAIMED") and passed
	passed = assert_equal(instance.completion_count, 1, "完成次数应该增加") and passed
	
	end_test(passed)

## 测试: 无效状态转换
func test_invalid_state_transition() -> void:
	start_test("无效状态转换")
	
	var task_data = MockObjects.create_test_task_data("invalid_state")
	var instance = TaskInstance.new(task_data)
	
	# 尝试从LOCKED直接到ACTIVE（无效）
	instance.set_state(TaskState.State.ACTIVE)
	var passed = assert_equal(instance.state, TaskState.State.LOCKED, "无效转换应该被拒绝")
	
	end_test(passed)

## 测试: 目标初始化
func test_objective_initialization() -> void:
	start_test("目标初始化")
	
	var task_data = MockObjects.create_full_test_task("full_test_task101")
	var instance = TaskInstance.new(task_data)
	
	var passed = assert_equal(instance.objectives.size(), 2, "应该有2个目标")
	
	for obj in instance.objectives:
		passed = assert_false(obj.is_completed, "目标应该未完成") and passed
		passed = assert_equal(obj.progress, 0.0, "进度应该是0") and passed
	
	end_test(passed)

## 测试: 目标完成
func test_objective_completion() -> void:
	start_test("目标完成")
	
	var task_data = MockObjects.create_full_test_task("full_test_task102")
	var instance = TaskInstance.new(task_data)
	instance.set_state(TaskState.State.AVAILABLE)
	instance.set_state(TaskState.State.ACTIVE)
	
	# 完成第一个目标
	instance.update_objective_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 5
	})
	
	var obj1 = instance.objectives[0]
	var passed = assert_true(obj1.is_completed, "第一个目标应该完成")
	passed = assert_equal(instance.state, TaskState.State.ACTIVE, "任务应该还在进行中") and passed
	
	# 完成第二个目标
	instance.update_objective_progress({
		"type": "collect_item",
		"target_id": "gold_coin",
		"count": 10
	})
	
	var obj2 = instance.objectives[1]
	passed = assert_true(obj2.is_completed, "第二个目标应该完成") and passed
	passed = assert_equal(instance.state, TaskState.State.COMPLETED, "所有目标完成后任务应该自动完成") and passed
	
	end_test(passed)

## 测试: 总体进度
func test_overall_progress() -> void:
	start_test("总体进度")
	
	var task_data = MockObjects.create_full_test_task("full_test_task103")
	var instance = TaskInstance.new(task_data)
	instance.set_state(TaskState.State.AVAILABLE)
	instance.set_state(TaskState.State.ACTIVE)
	
	# 初始进度
	var progress = instance.get_overall_progress()
	var passed = assert_equal(progress, 0.0, "初始进度应该是0")
	
	# 完成一半
	instance.update_objective_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 5
	})
	
	progress = instance.get_overall_progress()
	passed = assert_almost_equal(progress, 0.5, 0.01, "完成一个目标后进度应该是50%") and passed
	
	# 完成全部
	instance.update_objective_progress({
		"type": "collect_item",
		"target_id": "gold_coin",
		"count": 10
	})
	
	progress = instance.get_overall_progress()
	passed = assert_equal(progress, 1.0, "完成所有目标后进度应该是100%") and passed
	
	end_test(passed)

## 测试: 时间限制
func test_time_limit() -> void:
	start_test("时间限制")
	
	var task_data = MockObjects.create_timed_task()
	var instance = TaskInstance.new(task_data)
	instance.set_state(TaskState.State.AVAILABLE)
	instance.set_state(TaskState.State.ACTIVE)
	
	# 检查剩余时间
	var remaining = instance.get_remaining_time()
	var passed = assert_true(remaining > 0, "应该有剩余时间")
	passed = assert_true(remaining <= 300.0, "剩余时间应该不超过限制") and passed
	
	# 检查未超时
	passed = assert_false(instance.is_expired(), "任务不应该超时") and passed
	
	end_test(passed)

## 测试: 冷却时间
func test_cooldown() -> void:
	start_test("冷却时间")
	
	var task_data = MockObjects.create_repeatable_task()
	var instance = TaskInstance.new(task_data)
	
	# 初始状态应该没有冷却
	var passed = assert_true(instance.is_cooldown_finished(), "初始应该没有冷却")
	
	# 模拟完成任务
	instance.set_state(TaskState.State.AVAILABLE)
	instance.set_state(TaskState.State.ACTIVE)
	instance.set_state(TaskState.State.COMPLETED)
	instance.set_state(TaskState.State.CLAIMED)
	
	# 现在应该在冷却中
	passed = assert_false(instance.is_cooldown_finished(), "完成后应该在冷却中") and passed
	
	end_test(passed)

## 测试: 序列化
func test_serialization() -> void:
	start_test("序列化")
	
	var task_data = MockObjects.create_full_test_task("full_test_task104")
	var instance = TaskInstance.new(task_data)
	instance.set_state(TaskState.State.AVAILABLE)
	instance.set_state(TaskState.State.ACTIVE)
	
	instance.update_objective_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 3
	})
	
	# 序列化
	var data = instance.to_dict()
	var passed = assert_equal(data["task_id"], "full_test_task104", "任务ID应该正确")
	passed = assert_equal(data["state"], TaskState.State.ACTIVE, "状态应该正确") and passed
	
	# 反序列化
	var new_instance = TaskInstance.new(task_data)
	new_instance.from_dict(data)
	
	passed = assert_equal(new_instance.state, instance.state, "状态应该恢复") and passed
	passed = assert_equal(new_instance.start_time, instance.start_time, "开始时间应该恢复") and passed
	
	var obj = new_instance.objectives[0] as CountObjective
	passed = assert_equal(obj.current_count, 3, "目标进度应该恢复") and passed
	
	end_test(passed)

## 测试: 信号发射
## 注意: 此测试在命令行模式下可能不可靠，建议在场景模式下运行
func test_signal_emission() -> void:
	start_test("信号发射")
	
	var task_data = MockObjects.create_test_task_data("test_signals")
	var instance = TaskInstance.new(task_data)
	
	var state_changed_count = 0
	var progress_updated_count = 0
	
	var state_callback = func(_old, _new): state_changed_count += 1
	var progress_callback = func(_prog): progress_updated_count += 1
	
	instance.state_changed.connect(state_callback)
	instance.progress_updated.connect(progress_callback)
	
	# 改变状态应该触发信号
	instance.set_state(TaskState.State.AVAILABLE)
	
	# 等待信号处理（在命令行模式下可能不工作）
	await Engine.get_main_loop().process_frame
	
	var passed = assert_equal(state_changed_count, 1, "状态改变应该触发信号")
	
	end_test(passed)
