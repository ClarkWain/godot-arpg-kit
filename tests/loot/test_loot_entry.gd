## LootEntry测试
## 测试掉落条目功能
extends TestFramework

func _init() -> void:
	super._init("LootEntry测试")

## ========== 辅助方法 ==========

## 创建测试物品数据
func create_test_item(
	item_name: String = "测试物品",
	item_type: ItemData.ItemType = ItemData.ItemType.MATERIAL,
	rarity: ItemData.Rarity = ItemData.Rarity.COMMON,
	value: int = 10
) -> ItemData:
	var item = ItemData.new()
	item.id = "test_" + item_name.to_lower().replace(" ", "_")
	item.item_name = item_name
	item.item_type = item_type
	item.rarity = rarity
	item.base_value = value
	return item

## 创建测试掉落条目
func create_test_loot_entry(
	item_data: ItemData,
	drop_chance: float = 1.0,
	quantity: int = 1,
	weight: int = 100
) -> LootEntry:
	var entry = LootEntry.new()
	entry.item_data = item_data
	entry.drop_chance = drop_chance
	entry.fixed_quantity = quantity
	entry.weight = weight
	return entry

## 运行所有测试
func run_all_tests() -> void:
	test_create_loot_entry()
	test_drop_chance()
	test_quantity_modes()
	test_conditions()
	test_luck_influence()

	print_report()

## 测试: 创建掉落条目
func test_create_loot_entry() -> void:
	start_test("创建掉落条目")

	var item = create_test_item("测试剑", ItemData.ItemType.EQUIPMENT, ItemData.Rarity.COMMON, 50)
	var entry = LootEntry.new()
	entry.item_data = item
	entry.drop_chance = 0.5
	entry.weight = 100
	entry.fixed_quantity = 1

	var passed = assert_not_null(entry, "应该能够创建掉落条目")
	passed = assert_equal(entry.item_data, item, "物品数据应该正确设置") and passed
	passed = assert_almost_equal(entry.drop_chance, 0.5, 0.001, "掉落概率应该正确设置") and passed
	passed = assert_equal(entry.weight, 100, "权重应该正确设置") and passed

	end_test(passed)

## 测试: 掉落概率
func test_drop_chance() -> void:
	start_test("掉落概率")

	var item = create_test_item("测试物品")
	var entry = create_test_loot_entry(item, 1.0, 1, 100)

	# 测试100%掉落概率
	var passed = assert_almost_equal(entry.get_final_drop_chance(0), 1.0, 0.001, "100%概率应该返回1.0")

	# 测试50%掉落概率
	entry.drop_chance = 0.5
	passed = assert_almost_equal(entry.get_final_drop_chance(0), 0.5, 0.001, "50%概率应该返回0.5") and passed

	# 测试保证掉落
	entry.guaranteed = true
	passed = assert_almost_equal(entry.get_final_drop_chance(0), 1.0, 0.001, "保证掉落应该返回1.0") and passed

	end_test(passed)

## 测试: 数量模式
func test_quantity_modes() -> void:
	start_test("数量模式")

	var item = create_test_item("测试物品")
	var entry = LootEntry.new()
	entry.item_data = item

	# 测试固定数量
	entry.quantity_mode = LootEntry.QuantityMode.FIXED
	entry.fixed_quantity = 5
	var passed = assert_equal(entry.get_drop_quantity(0), 5, "固定数量应该返回5")

	# 测试随机数量
	entry.quantity_mode = LootEntry.QuantityMode.RANDOM
	entry.min_quantity = 1
	entry.max_quantity = 10
	var random_qty = entry.get_drop_quantity(0)
	passed = assert_greater_equal(random_qty, 1, "随机数量不应小于最小值") and passed
	passed = assert_less_equal(random_qty, 10, "随机数量不应大于最大值") and passed

	end_test(passed)

## 测试: 条件检查
func test_conditions() -> void:
	start_test("条件检查")

	var item = create_test_item("测试物品")
	var entry = create_test_loot_entry(item, 1.0, 1, 100)

	# 测试等级要求
	entry.min_player_level = 5
	entry.max_player_level = 10
	var passed = assert_false(entry.check_conditions(3, []), "低于最低等级应该返回false")
	passed = assert_true(entry.check_conditions(7, []), "等级在范围内应该返回true") and passed
	passed = assert_false(entry.check_conditions(15, []), "高于最高等级应该返回false") and passed

	# 测试标签要求
	entry.min_player_level = 1
	entry.max_player_level = 0
	var required: Array[String] = ["boss", "elite"]
	entry.required_tags = required
	passed = assert_false(entry.check_conditions(5, []), "缺少必需标签应该返回false") and passed
	passed = assert_false(entry.check_conditions(5, ["boss"]), "缺少部分必需标签应该返回false") and passed
	passed = assert_true(entry.check_conditions(5, ["boss", "elite"]), "所有必需标签都有应该返回true") and passed

	# 测试排除标签
	var empty_required: Array[String] = []
	entry.required_tags = empty_required
	var excluded: Array[String] = ["no_loot"]
	entry.excluded_tags = excluded
	passed = assert_true(entry.check_conditions(5, ["boss"]), "没有排除标签应该返回true") and passed
	passed = assert_false(entry.check_conditions(5, ["no_loot"]), "有排除标签应该返回false") and passed

	end_test(passed)

## 测试: 幸运值影响
func test_luck_influence() -> void:
	start_test("幸运值影响")

	var item = create_test_item("测试物品")
	var entry = create_test_loot_entry(item, 0.5, 1, 100)

	# 测试幸运值对概率的影响
	entry.luck_affects_chance = true
	entry.luck_chance_scaling = 0.01
	var base_chance = entry.get_final_drop_chance(0)
	var luck_chance = entry.get_final_drop_chance(10)
	var passed = assert_greater(luck_chance, base_chance, "幸运值应该增加掉落概率")

	# 测试幸运值对数量的影响
	entry.luck_affects_quantity = true
	entry.luck_quantity_scaling = 0.01
	entry.quantity_mode = LootEntry.QuantityMode.FIXED
	entry.fixed_quantity = 10
	var base_qty = entry.get_drop_quantity(0)
	var luck_qty = entry.get_drop_quantity(10)
	passed = assert_greater_equal(luck_qty, base_qty, "幸运值应该增加掉落数量") and passed

	end_test(passed)
