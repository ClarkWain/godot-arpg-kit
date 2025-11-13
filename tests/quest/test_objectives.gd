## Objective测试
## 测试各种任务目标类型
extends TestFramework

func _init() -> void:
	super._init("Objective测试")

## 运行所有测试
func run_all_tests() -> void:
	test_count_objective_basic()
	test_count_objective_partial()
	test_count_objective_overflow()
	test_count_objective_event_matching()
	test_state_objective_basic()
	test_state_objective_event_matching()
	test_objective_signals()
	test_objective_serialization()
	test_optional_objective()
	test_objective_weight()
	
	print_report()

## 测试: 计数目标基础功能
func test_count_objective_basic() -> void:
	start_test("计数目标基础功能")
	
	var obj = MockObjects.create_count_objective("kill_enemy", "goblin", 5)
	obj.initialize()
	
	var passed = assert_equal(obj.current_count, 0, "初始计数应该是0")
	passed = assert_equal(obj.progress, 0.0, "初始进度应该是0") and passed
	passed = assert_false(obj.is_completed, "初始应该未完成") and passed
	
	# 增加计数
	obj.add_count(3)
	passed = assert_equal(obj.current_count, 3, "计数应该是3") and passed
	passed = assert_almost_equal(obj.progress, 0.6, 0.01, "进度应该是60%") and passed
	passed = assert_false(obj.is_completed, "应该还未完成") and passed
	
	# 完成
	obj.add_count(2)
	passed = assert_equal(obj.current_count, 5, "计数应该是5") and passed
	passed = assert_equal(obj.progress, 1.0, "进度应该是100%") and passed
	passed = assert_true(obj.is_completed, "应该已完成") and passed
	
	end_test(passed)

## 测试: 计数目标部分更新
func test_count_objective_partial() -> void:
	start_test("计数目标部分更新")
	
	var obj = MockObjects.create_count_objective("collect_item", "wood", 10)
	obj.initialize()
	
	# 多次增加
	obj.add_count(3)
	obj.add_count(2)
	obj.add_count(4)
	
	var passed = assert_equal(obj.current_count, 9, "计数应该累加到9")
	passed = assert_almost_equal(obj.progress, 0.9, 0.01, "进度应该是90%") and passed
	
	end_test(passed)

## 测试: 计数目标溢出保护
func test_count_objective_overflow() -> void:
	start_test("计数目标溢出保护")
	
	var obj = MockObjects.create_count_objective("kill_enemy", "slime", 5)
	obj.initialize()
	
	# 超过需要的数量
	obj.add_count(10)
	
	var passed = assert_equal(obj.current_count, 5, "计数不应该超过需求")
	passed = assert_equal(obj.progress, 1.0, "进度应该是100%") and passed
	
	end_test(passed)

## 测试: 计数目标事件匹配
func test_count_objective_event_matching() -> void:
	start_test("计数目标事件匹配")
	
	var obj = MockObjects.create_count_objective("kill_enemy", "goblin", 5)
	obj.initialize()
	
	# 匹配的事件
	obj.update_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 2
	})
	var passed = assert_equal(obj.current_count, 2, "匹配事件应该更新计数")
	
	# 不匹配的类型
	obj.update_progress({
		"type": "collect_item",
		"target_id": "goblin",
		"count": 3
	})
	passed = assert_equal(obj.current_count, 2, "不匹配类型不应该更新") and passed
	
	# 不匹配的目标
	obj.update_progress({
		"type": "kill_enemy",
		"target_id": "orc",
		"count": 3
	})
	passed = assert_equal(obj.current_count, 2, "不匹配目标不应该更新") and passed
	
	end_test(passed)

## 测试: 状态目标基础功能
func test_state_objective_basic() -> void:
	start_test("状态目标基础功能")
	
	var obj = MockObjects.create_state_objective("location", "village")
	obj.initialize()
	
	var passed = assert_equal(obj.current_state, "", "初始状态应该为空")
	passed = assert_false(obj.is_completed, "初始应该未完成") and passed
	
	# 更新到目标状态
	obj.update_progress({
		"type": "location",
		"state": "village"
	})
	
	passed = assert_equal(obj.current_state, "village", "状态应该更新") and passed
	passed = assert_true(obj.is_completed, "应该已完成") and passed
	passed = assert_equal(obj.progress, 1.0, "进度应该是100%") and passed
	
	end_test(passed)

## 测试: 状态目标事件匹配
func test_state_objective_event_matching() -> void:
	start_test("状态目标事件匹配")
	
	var obj = MockObjects.create_state_objective("equipment", "iron_sword")
	obj.initialize()
	
	# 不匹配的类型
	obj.update_progress({
		"type": "location",
		"state": "iron_sword"
	})
	var passed = assert_false(obj.is_completed, "不匹配类型不应该完成")
	
	# 不匹配的状态
	obj.update_progress({
		"type": "equipment",
		"state": "wooden_sword"
	})
	passed = assert_false(obj.is_completed, "不匹配状态不应该完成") and passed
	
	# 匹配的事件
	obj.update_progress({
		"type": "equipment",
		"state": "iron_sword"
	})
	passed = assert_true(obj.is_completed, "匹配事件应该完成") and passed
	
	end_test(passed)

## 测试: 目标信号
## 注意: 此测试在命令行模式下可能不可靠，建议在场景模式下运行
func test_objective_signals() -> void:
	start_test("目标信号")
	
	var obj = MockObjects.create_count_objective("kill_enemy", "goblin", 5)
	obj.initialize()
	
	var completed_count = 0
	var progress_count = 0
	
	var completed_callback = func(_o): completed_count += 1
	var progress_callback = func(_o, _p): progress_count += 1
	
	obj.objective_completed.connect(completed_callback)
	obj.objective_progress_changed.connect(progress_callback)
	
	# 更新进度应该触发进度信号
	obj.add_count(3)
	
	# 等待信号处理（在命令行模式下可能不工作）
	await Engine.get_main_loop().process_frame
	
	var passed = assert_equal(progress_count, 1, "进度更新应该触发信号")
	passed = assert_equal(completed_count, 0, "未完成不应该触发完成信号") and passed
	
	# 完成应该触发完成信号
	obj.add_count(2)
	
	await Engine.get_main_loop().process_frame
	
	passed = assert_equal(completed_count, 1, "完成应该触发完成信号") and passed
	
	end_test(passed)

## 测试: 目标序列化
func test_objective_serialization() -> void:
	start_test("目标序列化")
	
	var obj = MockObjects.create_count_objective("collect_item", "gold", 100)
	obj.initialize()
	obj.add_count(45)
	
	# 序列化
	var data = obj.to_dict()
	var passed = assert_equal(data["objective_id"], obj.objective_id, "ID应该正确")
	passed = assert_equal(data["is_completed"], false, "完成状态应该正确") and passed
	passed = assert_equal(data["current_count"], 45, "计数应该正确") and passed
	
	# 反序列化
	var new_obj = MockObjects.create_count_objective("collect_item", "gold", 100)
	new_obj.initialize()
	new_obj.from_dict(data)
	
	passed = assert_equal(new_obj.current_count, 45, "计数应该恢复") and passed
	passed = assert_almost_equal(new_obj.progress, 0.45, 0.01, "进度应该恢复") and passed
	
	end_test(passed)

## 测试: 可选目标
func test_optional_objective() -> void:
	start_test("可选目标")
	
	var obj = MockObjects.create_count_objective("bonus_kill", "boss", 1)
	obj.optional = true
	obj.initialize()
	
	var passed = assert_true(obj.optional, "应该是可选目标")
	
	# 可选目标不影响任务完成
	# 这个测试主要验证属性设置
	passed = assert_equal(obj.required_count, 1, "需求数量应该正确") and passed
	
	end_test(passed)

## 测试: 目标权重
func test_objective_weight() -> void:
	start_test("目标权重")
	
	var obj1 = MockObjects.create_count_objective("kill_enemy", "goblin", 10)
	obj1.weight = 2.0
	obj1.initialize()
	
	var obj2 = MockObjects.create_count_objective("collect_item", "gold", 5)
	obj2.weight = 1.0
	obj2.initialize()
	
	var passed = assert_equal(obj1.weight, 2.0, "权重1应该是2.0")
	passed = assert_equal(obj2.weight, 1.0, "权重2应该是1.0") and passed
	
	# 权重用于计算总体进度
	obj1.add_count(5)  # 50% * 2.0 = 1.0
	obj2.add_count(5)  # 100% * 1.0 = 1.0
	
	var total_weight = obj1.weight + obj2.weight  # 3.0
	var completed_weight = obj1.progress * obj1.weight + obj2.progress * obj2.weight  # 0.5*2.0 + 1.0*1.0 = 2.0
	var overall_progress = completed_weight / total_weight  # 2.0 / 3.0 = 0.667
	
	passed = assert_almost_equal(overall_progress, 0.667, 0.01, "加权进度应该正确") and passed
	
	end_test(passed)