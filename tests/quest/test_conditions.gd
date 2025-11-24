## Condition测试
## 测试任务条件系统
extends QuestTestFramework

var mock_player: MockObjects.MockPlayer
var task_manager: TaskManager

func _init() -> void:
	super._init("Condition测试")

## 设置测试环境
func setup() -> void:
	mock_player = MockObjects.MockPlayer.new()
	task_manager = TaskManager.new()
	task_manager._ready()
	task_manager.set_player(mock_player)

## 清理测试环境
func teardown() -> void:
	if mock_player:
		mock_player.queue_free()
	if task_manager:
		task_manager.queue_free()

## 运行所有测试
func run_all_tests() -> void:
	setup()
	
	test_level_condition_equal()
	test_level_condition_greater()
	test_level_condition_greater_or_equal()
	test_level_condition_less()
	test_level_condition_less_or_equal()
	test_level_condition_negate()
	test_condition_in_task()
	
	teardown()
	print_report()

## 测试: 等级条件 - 等于
func test_level_condition_equal() -> void:
	start_test("等级条件 - 等于")
	
	var condition = MockObjects.create_level_condition(5, LevelCondition.CompareType.EQUAL)
	
	mock_player.set_level(5)
	var context = TaskContext.new(mock_player, task_manager)
	
	var passed = assert_true(condition.check(context.to_dict()), "等级5应该满足等于5的条件")
	
	mock_player.set_level(6)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_false(condition.check(context.to_dict()), "等级6不应该满足等于5的条件") and passed
	
	end_test(passed)

## 测试: 等级条件 - 大于
func test_level_condition_greater() -> void:
	start_test("等级条件 - 大于")
	
	var condition = MockObjects.create_level_condition(5, LevelCondition.CompareType.GREATER)
	
	mock_player.set_level(6)
	var context = TaskContext.new(mock_player, task_manager)
	
	var passed = assert_true(condition.check(context.to_dict()), "等级6应该满足大于5的条件")
	
	mock_player.set_level(5)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_false(condition.check(context.to_dict()), "等级5不应该满足大于5的条件") and passed
	
	end_test(passed)

## 测试: 等级条件 - 大于等于
func test_level_condition_greater_or_equal() -> void:
	start_test("等级条件 - 大于等于")
	
	var condition = MockObjects.create_level_condition(5, LevelCondition.CompareType.GREATER_OR_EQUAL)
	
	mock_player.set_level(5)
	var context = TaskContext.new(mock_player, task_manager)
	
	var passed = assert_true(condition.check(context.to_dict()), "等级5应该满足大于等于5的条件")
	
	mock_player.set_level(6)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_true(condition.check(context.to_dict()), "等级6应该满足大于等于5的条件") and passed
	
	mock_player.set_level(4)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_false(condition.check(context.to_dict()), "等级4不应该满足大于等于5的条件") and passed
	
	end_test(passed)

## 测试: 等级条件 - 小于
func test_level_condition_less() -> void:
	start_test("等级条件 - 小于")
	
	var condition = MockObjects.create_level_condition(5, LevelCondition.CompareType.LESS)
	
	mock_player.set_level(4)
	var context = TaskContext.new(mock_player, task_manager)
	
	var passed = assert_true(condition.check(context.to_dict()), "等级4应该满足小于5的条件")
	
	mock_player.set_level(5)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_false(condition.check(context.to_dict()), "等级5不应该满足小于5的条件") and passed
	
	end_test(passed)

## 测试: 等级条件 - 小于等于
func test_level_condition_less_or_equal() -> void:
	start_test("等级条件 - 小于等于")
	
	var condition = MockObjects.create_level_condition(5, LevelCondition.CompareType.LESS_OR_EQUAL)
	
	mock_player.set_level(5)
	var context = TaskContext.new(mock_player, task_manager)
	
	var passed = assert_true(condition.check(context.to_dict()), "等级5应该满足小于等于5的条件")
	
	mock_player.set_level(4)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_true(condition.check(context.to_dict()), "等级4应该满足小于等于5的条件") and passed
	
	mock_player.set_level(6)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_false(condition.check(context.to_dict()), "等级6不应该满足小于等于5的条件") and passed
	
	end_test(passed)

## 测试: 等级条件 - 取反
func test_level_condition_negate() -> void:
	start_test("等级条件 - 取反")
	
	var condition = MockObjects.create_level_condition(5, LevelCondition.CompareType.GREATER_OR_EQUAL)
	condition.negate = true
	
	mock_player.set_level(3)
	var context = TaskContext.new(mock_player, task_manager)
	
	var passed = assert_true(condition.check(context.to_dict()), "等级3应该满足取反的大于等于5条件")
	
	mock_player.set_level(5)
	context = TaskContext.new(mock_player, task_manager)
	passed = assert_false(condition.check(context.to_dict()), "等级5不应该满足取反的大于等于5条件") and passed
	
	end_test(passed)

## 测试: 条件在任务中的应用
func test_condition_in_task() -> void:
	start_test("条件在任务中的应用")
	
	var task = MockObjects.create_test_task_data("condition_task")
	var level_condition = MockObjects.create_level_condition(10, LevelCondition.CompareType.GREATER_OR_EQUAL)
	task.accept_conditions.append(level_condition)
	
	task_manager.register_task(task)
	
	# 等级不足
	mock_player.set_level(5)
	var can_accept = task_manager.can_accept_task("condition_task")
	var passed = assert_false(can_accept, "等级不足时不应该能接取任务")
	
	# 等级满足
	mock_player.set_level(10)
	can_accept = task_manager.can_accept_task("condition_task")
	passed = assert_true(can_accept, "等级满足时应该能接取任务") and passed
	
	end_test(passed)
