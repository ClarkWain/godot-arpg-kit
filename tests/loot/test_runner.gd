## Loot系统测试运行器
## 运行所有Loot系统测试
extends Node

# 累计失败数，用于决定退出码
var _total_failed: int = 0

func _ready() -> void:
	# 固定随机种子（loot 概率抽取默认依赖 randf）
	seed(0)
	print("=== Loot系统测试开始 ===")

	# 运行所有测试
	run_all_loot_tests()

	print("=== Loot系统测试完成 ===")
	
	# 退出场景（按失败数传退出码，供 CI 判断）
	get_tree().quit(1 if _total_failed > 0 else 0)

func run_all_loot_tests() -> void:
	# 创建测试实例
	var test_loot_entry = load("res://tests/loot/test_loot_entry.gd").new()
	var test_loot_table = load("res://tests/loot/test_loot_table.gd").new()

	# 运行测试
	print("\n--- 运行LootEntry测试 ---")
	test_loot_entry.run_all_tests()

	print("\n--- 运行LootTable测试 ---")
	test_loot_table.run_all_tests()

	# 输出汇总报告
	print("\n=== 测试汇总报告 ===")
	print("LootEntry测试: %s" % test_loot_entry.get_test_summary())
	print("LootTable测试: %s" % test_loot_table.get_test_summary())

	# 计算总体统计
	var total_tests = 0
	var total_passed = 0
	var total_failed = 0

	var all_tests = [test_loot_entry, test_loot_table]
	for test in all_tests:
		total_tests += test.total_tests
		total_passed += test.passed_tests
		total_failed += test.failed_tests

	print("\n总体统计:")
	print("总测试数: %d" % total_tests)
	print("通过测试: %d" % total_passed)
	print("失败测试: %d" % total_failed)
	print("成功率: %.1f%%" % (float(total_passed) / float(total_tests) * 100.0 if total_tests > 0 else 0.0))
	print("[RESULT] suite=loot passed=%d failed=%d total=%d" % [total_passed, total_failed, total_tests])
	
	# 传递失败数到成员变量，供 _ready 确定退出码
	_total_failed = total_failed

	if total_failed == 0:
		print("🎉 所有测试通过！Loot系统运行正常。")
	else:
		print("⚠️  有 %d 个测试失败，请检查上述错误信息。" % total_failed)
