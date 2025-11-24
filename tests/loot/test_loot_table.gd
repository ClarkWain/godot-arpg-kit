## LootTable测试
## 测试掉落表功能
extends TestFramework

func _init() -> void:
	super._init("LootTable测试")

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

## 创建测试掉落表
func create_test_loot_table(
	entries: Array[LootEntry] = [],
	drop_mode: LootTable.DropMode = LootTable.DropMode.ALL
) -> LootTable:
	var table = LootTable.new()
	table.table_name = "测试掉落表"
	table.drop_mode = drop_mode
	table.entries = entries
	table.drops_gold = true
	table.min_gold = 5
	table.max_gold = 15
	return table

## 断言掉落结果有效
func assert_loot_result_valid(loot_data: Dictionary, message: String = "") -> bool:
	var passed = assert_not_null(loot_data, message)
	passed = assert_true(loot_data.has("items"), "掉落结果应该包含items") and passed
	passed = assert_true(loot_data.has("gold"), "掉落结果应该包含gold") and passed
	return passed

## 断言金币在范围内
func assert_gold_in_range(gold: int, min_gold: int, max_gold: int, message: String = "") -> bool:
	var passed = assert_greater_equal(gold, min_gold, "金币不应该小于最小值")
	passed = assert_less_equal(gold, max_gold, "金币不应该大于最大值") and passed
	return passed

## 运行所有测试
func run_all_tests() -> void:
	test_create_loot_table()
	test_drop_modes()
	test_gold_generation()
	test_loot_generation()
	test_weighted_selection()
	test_tag_filtering()

	print_report()

## 测试: 创建掉落表
func test_create_loot_table() -> void:
	start_test("创建掉落表")

	var table = LootTable.new()
	table.table_name = "测试掉落表"
	table.drop_mode = LootTable.DropMode.ALL
	table.drops_gold = true
	table.min_gold = 10
	table.max_gold = 50

	var passed = assert_not_null(table, "应该能够创建掉落表")
	passed = assert_equal(table.table_name, "测试掉落表", "掉落表名称应该正确设置") and passed
	passed = assert_equal(table.drop_mode, LootTable.DropMode.ALL, "掉落模式应该正确设置") and passed
	passed = assert_true(table.drops_gold, "应该掉落金币") and passed

	end_test(passed)

## 测试: 掉落模式
func test_drop_modes() -> void:
	start_test("掉落模式")

	var item1 = create_test_item("物品1", ItemData.ItemType.MATERIAL, ItemData.Rarity.COMMON, 10)
	var item2 = create_test_item("物品2", ItemData.ItemType.MATERIAL, ItemData.Rarity.UNCOMMON, 20)
	var item3 = create_test_item("物品3", ItemData.ItemType.MATERIAL, ItemData.Rarity.RARE, 50)

	var entry1 = create_test_loot_entry(item1, 1.0, 1, 100)
	var entry2 = create_test_loot_entry(item2, 1.0, 1, 100)
	var entry3 = create_test_loot_entry(item3, 1.0, 1, 100)

	# 测试 ALL 模式 - 所有物品都应该掉落
	var table_all = create_test_loot_table([entry1, entry2, entry3], LootTable.DropMode.ALL)
	table_all.drops_gold = false
	var loot_all = table_all.generate_loot(1, 0, [])
	var passed = assert_loot_result_valid(loot_all, "ALL模式应该返回有效掉落结果")
	passed = assert_equal(loot_all.items.size(), 3, "ALL模式应该掉落所有3个物品") and passed

	# 测试 PICK_ONE 模式 - 只掉落一个物品
	var table_one = create_test_loot_table([entry1, entry2, entry3], LootTable.DropMode.PICK_ONE)
	table_one.drops_gold = false
	var loot_one = table_one.generate_loot(1, 0, [])
	passed = assert_loot_result_valid(loot_one, "PICK_ONE模式应该返回有效掉落结果") and passed
	passed = assert_less_equal(loot_one.items.size(), 1, "PICK_ONE模式应该最多掉落1个物品") and passed

	end_test(passed)

## 测试: 金币生成
func test_gold_generation() -> void:
	start_test("金币生成")

	var table = create_test_loot_table([], LootTable.DropMode.ALL)
	table.drops_gold = true
	table.min_gold = 10
	table.max_gold = 20
	table.luck_affects_gold = false

	# 生成金币
	var loot = table.generate_loot(1, 0, [])
	var passed = assert_loot_result_valid(loot, "应该返回有效掉落结果")
	passed = assert_gold_in_range(loot.gold, 10, 20, "金币应该在10-20范围内") and passed

	# 测试不掉落金币
	table.drops_gold = false
	var loot_no_gold = table.generate_loot(1, 0, [])
	passed = assert_equal(loot_no_gold.gold, 0, "不掉落金币时金币应该是0") and passed

	end_test(passed)

## 测试: 掉落物生成
func test_loot_generation() -> void:
	start_test("掉落物生成")

	var item = create_test_item("测试剑", ItemData.ItemType.EQUIPMENT, ItemData.Rarity.UNCOMMON, 100)
	var entry = create_test_loot_entry(item, 1.0, 1, 100)

	var table = create_test_loot_table([entry], LootTable.DropMode.ALL)
	table.drops_gold = true
	table.min_gold = 5
	table.max_gold = 15

	var loot = table.generate_loot(1, 0, [])
	var passed = assert_loot_result_valid(loot, "应该返回有效掉落结果")
	passed = assert_equal(loot.items.size(), 1, "应该掉落1个物品") and passed
	passed = assert_gold_in_range(loot.gold, 5, 15, "金币应该在5-15范围内") and passed

	# 检查掉落的物品
	if loot.items.size() > 0:
		var dropped_item = loot.items[0]
		passed = assert_not_null(dropped_item, "掉落的物品不应该为null") and passed
		passed = assert_equal(dropped_item.item_data, item, "掉落的物品应该是测试剑") and passed

	end_test(passed)

## 测试: 加权选择
func test_weighted_selection() -> void:
	start_test("加权选择")

	var common_item = create_test_item("普通物品", ItemData.ItemType.MATERIAL, ItemData.Rarity.COMMON, 5)
	var rare_item = create_test_item("稀有物品", ItemData.ItemType.MATERIAL, ItemData.Rarity.RARE, 100)

	# 普通物品权重高，稀有物品权重低
	var common_entry = create_test_loot_entry(common_item, 1.0, 1, 900)
	var rare_entry = create_test_loot_entry(rare_item, 1.0, 1, 100)

	var table = create_test_loot_table([common_entry, rare_entry], LootTable.DropMode.PICK_ONE)
	table.drops_gold = false

	# 多次生成，统计掉落分布
	var common_count = 0
	var rare_count = 0
	var test_runs = 100

	for i in range(test_runs):
		var loot = table.generate_loot(1, 0, [])
		if loot.items.size() > 0:
			var item_data = loot.items[0].item_data
			if item_data == common_item:
				common_count += 1
			elif item_data == rare_item:
				rare_count += 1

	# 由于权重差异，普通物品应该更常掉落
	var passed = assert_greater(common_count, rare_count, "普通物品应该比稀有物品掉落更频繁")

	end_test(passed)

## 测试: 标签过滤
func test_tag_filtering() -> void:
	start_test("标签过滤")

	var normal_item = create_test_item("普通物品", ItemData.ItemType.MATERIAL, ItemData.Rarity.COMMON, 10)
	var boss_item = create_test_item("Boss物品", ItemData.ItemType.MATERIAL, ItemData.Rarity.RARE, 100)

	var normal_entry = create_test_loot_entry(normal_item, 1.0, 1, 100)
	var boss_entry = create_test_loot_entry(boss_item, 1.0, 1, 100)
	boss_entry.required_tags = ["boss"] as Array[String]  # Boss物品需要boss标签

	var table = create_test_loot_table([normal_entry, boss_entry], LootTable.DropMode.ALL)
	table.drops_gold = false

	# 测试无标签：应该只掉落普通物品
	var loot_no_tags = table.generate_loot(1, 0, [])
	var passed = assert_loot_result_valid(loot_no_tags, "无标签应该返回有效掉落结果")
	passed = assert_equal(loot_no_tags.items.size(), 1, "无标签应该只掉落1个物品") and passed
	if loot_no_tags.items.size() > 0:
		passed = assert_equal(loot_no_tags.items[0].item_data, normal_item, "无标签应该掉落普通物品") and passed

	# 测试有boss标签：应该掉落两个物品
	var loot_with_boss = table.generate_loot(1, 0, ["boss"])
	passed = assert_loot_result_valid(loot_with_boss, "有boss标签应该返回有效掉落结果") and passed
	passed = assert_equal(loot_with_boss.items.size(), 2, "有boss标签应该掉落2个物品") and passed
	if loot_with_boss.items.size() == 2:
		var item_names = []
		for item in loot_with_boss.items:
			item_names.append(item.item_data.item_name)
		passed = assert_true("普通物品" in item_names, "应该包含普通物品") and passed
		passed = assert_true("Boss物品" in item_names, "应该包含Boss物品") and passed

	# 测试排除标签：Boss物品有excluded_tags
	boss_entry.excluded_tags = ["no_boss"] as Array[String]
	var loot_excluded = table.generate_loot(1, 0, ["no_boss"])
	passed = assert_loot_result_valid(loot_excluded, "有排除标签应该返回有效掉落结果") and passed
	passed = assert_equal(loot_excluded.items.size(), 1, "有排除标签应该只掉落1个物品") and passed
	if loot_excluded.items.size() > 0:
		passed = assert_equal(loot_excluded.items[0].item_data, normal_item, "排除标签应该只掉落普通物品") and passed

	end_test(passed)
