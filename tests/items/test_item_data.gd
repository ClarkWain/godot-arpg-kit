## ItemData测试
## 测试物品基础数据类的功能
class_name TestItemData
extends ItemTestFramework

func _init() -> void:
	super._init("ItemData测试")

## 运行所有测试
func run_all_tests() -> void:
	test_create_item_data()
	test_item_properties()
	test_rarity_system()
	test_value_system()
	test_tag_system()
	test_description_generation()
	test_sell_price_calculation()

	print_report()

## 测试: 创建物品数据
func test_create_item_data() -> void:
	start_test("创建物品数据")

	var item_data = ItemData.new()
	var passed = assert_not_null(item_data, "应该能够创建ItemData实例")

	# 测试默认值
	passed = assert_equal(item_data.item_type, ItemData.ItemType.MATERIAL, "默认类型应该是MATERIAL") and passed
	passed = assert_equal(item_data.rarity, ItemData.Rarity.COMMON, "默认稀有度应该是COMMON") and passed
	passed = assert_equal(item_data.max_stack, 1, "默认最大堆叠应该是1") and passed
	passed = assert_equal(item_data.base_value, 1, "默认基础价值应该是1") and passed

	end_test(passed)

## 测试: 物品属性设置
func test_item_properties() -> void:
	start_test("物品属性设置")

	var item_data = create_test_item_data("测试剑", ItemData.ItemType.EQUIPMENT, ItemData.Rarity.RARE, 1, 100)

	var passed = assert_equal(item_data.item_name, "测试剑", "物品名称应该正确设置")
	passed = assert_equal(item_data.item_type, ItemData.ItemType.EQUIPMENT, "物品类型应该正确设置") and passed
	passed = assert_equal(item_data.rarity, ItemData.Rarity.RARE, "稀有度应该正确设置") and passed
	passed = assert_equal(item_data.max_stack, 1, "最大堆叠应该正确设置") and passed
	passed = assert_equal(item_data.base_value, 100, "基础价值应该正确设置") and passed

	# 测试ID生成
	passed = assert_not_empty(item_data.id, "物品ID应该自动生成") and passed

	end_test(passed)

## 测试: 稀有度系统
func test_rarity_system() -> void:
	start_test("稀有度系统")

	var item_data = ItemData.new()

	# 测试所有稀有度
	var rarities = [
		ItemData.Rarity.COMMON,
		ItemData.Rarity.UNCOMMON,
		ItemData.Rarity.RARE,
		ItemData.Rarity.EPIC,
		ItemData.Rarity.LEGENDARY,
		ItemData.Rarity.MYTHIC
	]

	var rarity_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	var rarity_colors = [
		Color.WHITE,
		Color.GREEN,
		Color.DODGER_BLUE,
		Color.PURPLE,
		Color.ORANGE,
		Color.RED
	]

	var passed = true
	for i in range(rarities.size()):
		item_data.rarity = rarities[i]
		passed = assert_equal(item_data.get_rarity_name(), rarity_names[i], "稀有度名称应该正确") and passed
		passed = assert_equal(item_data.get_rarity_color(), rarity_colors[i], "稀有度颜色应该正确") and passed

	end_test(passed)

## 测试: 价值系统
func test_value_system() -> void:
	start_test("价值系统")

	var item_data = create_test_item_data("测试物品", ItemData.ItemType.MATERIAL, ItemData.Rarity.COMMON, 1, 50)

	var passed = assert_equal(item_data.base_value, 50, "基础价值应该正确")
	passed = assert_equal(item_data.get_sell_price(), 25, "出售价格应该是基础价值的50%") and passed

	# 测试不可出售物品
	item_data.can_sell = false
	passed = assert_equal(item_data.get_sell_price(), 0, "不可出售物品的售价应该是0") and passed

	end_test(passed)

## 测试: 标签系统
func test_tag_system() -> void:
	start_test("标签系统")

	var item_data = ItemData.new()

	# 测试添加标签
	item_data.add_tag("weapon")
	item_data.add_tag("melee")

	var passed = assert_true(item_data.has_tag("weapon"), "应该包含weapon标签")
	passed = assert_true(item_data.has_tag("melee"), "应该包含melee标签") and passed
	passed = assert_false(item_data.has_tag("magic"), "不应该包含不存在的标签") and passed

	# 测试重复添加
	item_data.add_tag("weapon")
	passed = assert_equal(item_data.tags.size(), 2, "重复添加标签不应该增加数量") and passed

	# 测试移除标签
	item_data.remove_tag("weapon")
	passed = assert_false(item_data.has_tag("weapon"), "标签应该被移除") and passed
	passed = assert_true(item_data.has_tag("melee"), "其他标签应该保留") and passed

	end_test(passed)

## 测试: 描述生成
func test_description_generation() -> void:
	start_test("描述生成")

	var item_data = create_test_item_data("魔法剑", ItemData.ItemType.EQUIPMENT, ItemData.Rarity.EPIC, 1, 200)
	item_data.weight = 5.5
	item_data.description = "一把强大的魔法剑"

	var full_desc = item_data.get_full_description()

	var passed = assert_true(full_desc.contains("[b]魔法剑[/b]"), "应该包含物品名称")
	passed = assert_true(full_desc.contains("史诗"), "应该包含稀有度名称") and passed
	passed = assert_true(full_desc.contains("一把强大的魔法剑"), "应该包含物品描述") and passed
	passed = assert_true(full_desc.contains("重量: 5.5"), "应该包含重量信息") and passed
	passed = assert_true(full_desc.contains("售价: 100 金币"), "应该包含出售价格") and passed

	end_test(passed)

## 测试: 出售价格计算
func test_sell_price_calculation() -> void:
	start_test("出售价格计算")

	var test_cases = [
		{"value": 10, "expected": 5},
		{"value": 25, "expected": 12},  # 向下取整
		{"value": 1, "expected": 0},    # 最小为0
		{"value": 100, "expected": 50}
	]

	var passed = true
	for case in test_cases:
		var item_data = create_test_item_data("测试物品", ItemData.ItemType.MATERIAL, ItemData.Rarity.COMMON, 1, case.value)
		var sell_price = item_data.get_sell_price()
		passed = assert_equal(sell_price, case.expected, "出售价格计算应该正确 (价值:%d)" % case.value) and passed

	end_test(passed)