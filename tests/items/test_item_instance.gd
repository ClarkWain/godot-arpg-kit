## ItemInstance测试
## 测试物品实例的功能
extends "res://tests/items/test_framework.gd"

func _init() -> void:
	super._init("ItemInstance测试")

## 运行所有测试
func run_all_tests() -> void:
	test_create_instance()
	test_stack_management()

	print_report()

## 测试: 创建物品实例
func test_create_instance() -> void:
	start_test("创建物品实例")

	var item_data = create_test_item_data("测试物品", ItemData.ItemType.MATERIAL, ItemData.Rarity.COMMON, 10, 20)

	# 测试正常创建
	var instance = ItemInstance.create(item_data, 5)
	var passed = assert_not_null(instance, "应该能够创建有效的物品实例")
	passed = assert_equal(instance.stack_count, 5, "堆叠数量应该正确设置") and passed
	passed = assert_equal(instance.item_data, item_data, "物品数据应该正确引用") and passed

	# 测试堆叠数量限制
	var max_stack_instance = ItemInstance.create(item_data, 15)
	passed = assert_equal(max_stack_instance.stack_count, 10, "堆叠数量不应该超过最大值") and passed

	# 测试无效数据
	var null_instance = ItemInstance.create(null)
	passed = assert_null(null_instance, "使用null数据应该返回null") and passed

	end_test(passed)

## 测试: 堆叠管理
func test_stack_management() -> void:
	start_test("堆叠管理")

	var item_data = create_test_item_data("可堆叠物品", ItemData.ItemType.CONSUMABLE, ItemData.Rarity.COMMON, 10, 10)

	var instance1 = ItemInstance.create(item_data, 5)
	var instance2 = ItemInstance.create(item_data, 3)

	# 测试可以堆叠
	var passed = assert_can_stack(instance1, instance2, true, "相同物品应该可以堆叠")

	# 测试不可堆叠物品
	var unique_data = create_test_item_data("唯一物品", ItemData.ItemType.EQUIPMENT, ItemData.Rarity.RARE, 1, 100)
	var unique1 = ItemInstance.create(unique_data, 1)
	var unique2 = ItemInstance.create(unique_data, 1)
	passed = assert_can_stack(unique1, unique2, false, "不可堆叠物品不应该可以堆叠") and passed

	end_test(passed)