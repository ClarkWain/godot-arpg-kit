## 物品系统测试运行器
## 运行所有物品系统测试
extends Node

# 累计失败数，用于决定退出码
var _total_failed: int = 0

func _ready() -> void:
	# 固定随机种子，避免低概率分支导致 flaky
	seed(0)
	print("=== 物品系统测试开始 ===")

	# 运行所有测试
	run_all_item_tests()

	print("=== 物品系统测试完成 ===")
	
	# 退出场景（按失败数传退出码，供 CI 判断）
	get_tree().quit(1 if _total_failed > 0 else 0)

func run_all_item_tests() -> void:
	# 创建测试实例
	var test_item_data = TestItemData.new()
	var test_item_instance = TestItemInstance.new()
	var test_equipment_data = TestEquipmentData.new()
	var test_consumable_data = TestConsumableData.new()
	var test_weapon_data = TestWeaponData.new()

	# 运行测试
	print("\n--- 运行ItemData测试 ---")
	test_item_data.run_all_tests()

	print("\n--- 运行ItemInstance测试 ---")
	test_item_instance.run_all_tests()

	print("\n--- 运行EquipmentData测试 ---")
	test_equipment_data.run_all_tests()

	print("\n--- 运行ConsumableData测试 ---")
	test_consumable_data.run_all_tests()

	print("\n--- 运行WeaponData测试 ---")
	test_weapon_data.run_all_tests()

	# 输出汇总报告
	print("\n=== 测试汇总报告 ===")
	print("ItemData测试: %s" % test_item_data.get_test_summary())
	print("ItemInstance测试: %s" % test_item_instance.get_test_summary())
	print("EquipmentData测试: %s" % test_equipment_data.get_test_summary())
	print("ConsumableData测试: %s" % test_consumable_data.get_test_summary())
	print("WeaponData测试: %s" % test_weapon_data.get_test_summary())

	# 计算总体统计
	var total_tests = 0
	var total_passed = 0
	var total_failed = 0

	var all_tests = [test_item_data, test_item_instance, test_equipment_data, test_consumable_data, test_weapon_data]
	for test in all_tests:
		total_tests += test.total_tests
		total_passed += test.passed_tests
		total_failed += test.failed_tests

	print("\n总体统计:")
	print("总测试数: %d" % total_tests)
	print("通过测试: %d" % total_passed)
	print("失败测试: %d" % total_failed)
	print("成功率: %.1f%%" % (float(total_passed) / float(total_tests) * 100.0 if total_tests > 0 else 0.0))
	print("[RESULT] suite=items passed=%d failed=%d total=%d" % [total_passed, total_failed, total_tests])
	
	# 传递失败数到成员变量，供 _ready 确定退出码
	_total_failed = total_failed

	if total_failed == 0:
		print("🎉 所有测试通过！物品系统运行正常。")
	else:
		print("⚠️  有 %d 个测试失败，请检查上述错误信息。" % total_failed)
