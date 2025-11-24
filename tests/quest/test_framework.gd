## 任务系统测试框架基类
## 提供测试断言和报告功能
class_name QuestTestFramework
extends RefCounted

## 测试结果
class TestResult:
	var test_name: String = ""
	var passed: bool = false
	var message: String = ""
	var duration: float = 0.0
	
	func _init(name: String, p: bool, msg: String = "", dur: float = 0.0) -> void:
		test_name = name
		passed = p
		message = msg
		duration = dur

## 测试套件
var suite_name: String = ""
var results: Array[TestResult] = []
var current_test: String = ""
var test_start_time: float = 0.0

## 统计
var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init(name: String = "TestSuite") -> void:
	suite_name = name

## 开始测试
func start_test(test_name: String) -> void:
	current_test = test_name
	test_start_time = Time.get_ticks_msec()
	total_tests += 1

## 结束测试
func end_test(passed: bool, message: String = "") -> void:
	var duration = (Time.get_ticks_msec() - test_start_time) / 1000.0
	var result = TestResult.new(current_test, passed, message, duration)
	results.append(result)
	
	if passed:
		passed_tests += 1
	else:
		failed_tests += 1

## 断言相等
func assert_equal(actual, expected, message: String = "") -> bool:
	if actual == expected:
		return true
	else:
		var msg = message if message != "" else "Expected %s but got %s" % [str(expected), str(actual)]
		var error_msg = "[%s] %s: %s" % [suite_name, current_test, msg]
		push_error(error_msg)
		# 记录到结果中
		if results.size() > 0:
			results[results.size() - 1].message = msg
		return false

## 断言不相等
func assert_not_equal(actual, expected, message: String = "") -> bool:
	if actual != expected:
		return true
	else:
		var msg = message if message != "" else "Expected not equal to %s" % str(expected)
		var error_msg = "[%s] %s: %s" % [suite_name, current_test, msg]
		push_error(error_msg)
		if results.size() > 0:
			results[results.size() - 1].message = msg
		return false

## 断言为真
func assert_true(value: bool, message: String = "") -> bool:
	if value:
		return true
	else:
		var msg = message if message != "" else "Expected true but got false"
		var error_msg = "[%s] %s: %s" % [suite_name, current_test, msg]
		push_error(error_msg)
		if results.size() > 0:
			results[results.size() - 1].message = msg
		return false

## 断言为假
func assert_false(value: bool, message: String = "") -> bool:
	if not value:
		return true
	else:
		var msg = message if message != "" else "Expected false but got true"
		var error_msg = "[%s] %s: %s" % [suite_name, current_test, msg]
		push_error(error_msg)
		if results.size() > 0:
			results[results.size() - 1].message = msg
		return false

## 断言为null
func assert_null(value, message: String = "") -> bool:
	if value == null:
		return true
	else:
		var msg = message if message != "" else "Expected null but got %s" % str(value)
		var error_msg = "[%s] %s: %s" % [suite_name, current_test, msg]
		push_error(error_msg)
		if results.size() > 0:
			results[results.size() - 1].message = msg
		return false

## 断言不为null
func assert_not_null(value, message: String = "") -> bool:
	if value != null:
		return true
	else:
		var msg = message if message != "" else "Expected not null"
		var error_msg = "[%s] %s: %s" % [suite_name, current_test, msg]
		push_error(error_msg)
		if results.size() > 0:
			results[results.size() - 1].message = msg
		return false

## 断言近似相等(浮点数)
func assert_almost_equal(actual: float, expected: float, epsilon: float = 0.0001, message: String = "") -> bool:
	if abs(actual - expected) < epsilon:
		return true
	else:
		var msg = message if message != "" else "Expected %f but got %f (epsilon: %f)" % [expected, actual, epsilon]
		push_error("[%s] %s: %s" % [suite_name, current_test, msg])
		return false

## 断言数组包含
func assert_contains(array: Array, value, message: String = "") -> bool:
	if value in array:
		return true
	else:
		var msg = message if message != "" else "Array does not contain %s" % str(value)
		push_error("[%s] %s: %s" % [suite_name, current_test, msg])
		return false

## 断言数组不包含
func assert_not_contains(array: Array, value, message: String = "") -> bool:
	if not (value in array):
		return true
	else:
		var msg = message if message != "" else "Array contains %s" % str(value)
		push_error("[%s] %s: %s" % [suite_name, current_test, msg])
		return false

## 生成报告
func generate_report() -> String:
	var report = "\n" + "=".repeat(60) + "\n"
	report += "测试套件: %s\n" % suite_name
	report += "=".repeat(60) + "\n"
	report += "总测试数: %d\n" % total_tests
	report += "通过: %d (%.1f%%)\n" % [passed_tests, (float(passed_tests) / total_tests * 100.0) if total_tests > 0 else 0.0]
	report += "失败: %d (%.1f%%)\n" % [failed_tests, (float(failed_tests) / total_tests * 100.0) if total_tests > 0 else 0.0]
	report += "=".repeat(60) + "\n\n"
	
	# 详细结果
	for result in results:
		var status = "✓ PASS" if result.passed else "✗ FAIL"
		report += "[%s] %s (%.3fs)\n" % [status, result.test_name, result.duration]
		if not result.passed and result.message != "":
			report += "  错误: %s\n" % result.message
	
	report += "\n" + "=".repeat(60) + "\n"
	return report

## 打印报告
func print_report() -> void:
	print(generate_report())
