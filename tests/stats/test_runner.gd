## 测试运行器
## 运行所有属性系统测试并生成报告
extends Node

## 测试套件列表
var test_suites: Array = []

## 总体统计
var total_suites: int = 0
var total_tests: int = 0
var total_passed: int = 0
var total_failed: int = 0
var total_duration: float = 0.0

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("属性系统测试运行器")
	print("=".repeat(80) + "\n")
	
	run_all_tests()

## 运行所有测试
func run_all_tests() -> void:
	var start_time = Time.get_ticks_msec()
	
	# 创建测试套件
	var stats_data_test = load("res://tests/stats/test_stats_data.gd").new()
	var stat_modifier_test = load("res://tests/stats/test_stat_modifier.gd").new()
	var luck_system_test = load("res://tests/stats/test_luck_system.gd").new()
	var stats_component_test = load("res://tests/stats/test_stats_component.gd").new()
	
	test_suites.append(stats_data_test)
	test_suites.append(stat_modifier_test)
	test_suites.append(luck_system_test)
	test_suites.append(stats_component_test)
	
	# 运行每个测试套件
	for suite in test_suites:
		print("\n正在运行: %s" % suite.suite_name)
		print("-".repeat(80))
		suite.run_all_tests()
		
		# 累计统计
		total_suites += 1
		total_tests += suite.total_tests
		total_passed += suite.passed_tests
		total_failed += suite.failed_tests
	
	total_duration = (Time.get_ticks_msec() - start_time) / 1000.0
	
	# 生成总体报告
	generate_summary_report()
	
	# 保存报告到文件
	save_report_to_file()
	
	# 退出
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## 生成总体报告
func generate_summary_report() -> void:
	print("\n\n" + "=".repeat(80))
	print("测试总结")
	print("=".repeat(80))
	print("测试套件数: %d" % total_suites)
	print("总测试数: %d" % total_tests)
	print("通过: %d (%.1f%%)" % [total_passed, (float(total_passed) / total_tests * 100.0) if total_tests > 0 else 0.0])
	print("失败: %d (%.1f%%)" % [total_failed, (float(total_failed) / total_tests * 100.0) if total_tests > 0 else 0.0])
	print("总耗时: %.3f秒" % total_duration)
	print("=".repeat(80))
	
	# 显示每个套件的结果
	print("\n各测试套件详情:")
	print("-".repeat(80))
	for suite in test_suites:
		var status = "✓" if suite.failed_tests == 0 else "✗"
		var pass_rate = (float(suite.passed_tests) / suite.total_tests * 100.0) if suite.total_tests > 0 else 0.0
		print("[%s] %s: %d/%d 通过 (%.1f%%)" % [
			status,
			suite.suite_name,
			suite.passed_tests,
			suite.total_tests,
			pass_rate
		])
	print("=".repeat(80))
	
	# 最终结果
	if total_failed == 0:
		print("\n✓ 所有测试通过!")
	else:
		print("\n✗ 有 %d 个测试失败" % total_failed)

## 保存报告到文件
func save_report_to_file() -> void:
	var report = ""
	
	# 添加标题
	report += "属性系统测试报告\n"
	report += "生成时间: %s\n" % Time.get_datetime_string_from_system()
	report += "=".repeat(80) + "\n\n"
	
	# 添加总体统计
	report += "总体统计\n"
	report += "-".repeat(80) + "\n"
	report += "测试套件数: %d\n" % total_suites
	report += "总测试数: %d\n" % total_tests
	report += "通过: %d (%.1f%%)\n" % [total_passed, (float(total_passed) / total_tests * 100.0) if total_tests > 0 else 0.0]
	report += "失败: %d (%.1f%%)\n" % [total_failed, (float(total_failed) / total_tests * 100.0) if total_tests > 0 else 0.0]
	report += "总耗时: %.3f秒\n" % total_duration
	report += "\n"
	
	# 添加每个套件的详细报告
	for suite in test_suites:
		report += suite.generate_report()
		report += "\n"
	
	# 保存到文件
	var file = FileAccess.open("res://tests/stats/test_report.txt", FileAccess.WRITE)
	if file:
		file.store_string(report)
		file.close()
		print("\n测试报告已保存到: res://tests/stats/test_report.txt")
	else:
		push_error("无法保存测试报告")