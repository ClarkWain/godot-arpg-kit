## Loot系统测试框架
##
## 提供loot系统测试的基础功能和断言方法
## 继承自TestFramework

class_name LootTestFramework
extends TestFramework

## ========== Loot测试辅助方法 ==========

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


## ========== Loot专用断言 ==========

## 断言掉落结果有效
func assert_loot_result_valid(loot_data: Dictionary, message: String = "") -> bool:
	var passed = assert_not_null(loot_data, message)
	passed = assert_true(loot_data.has("items"), "掉落结果应该包含items") and passed
	passed = assert_true(loot_data.has("gold"), "掉落结果应该包含gold") and passed
	return passed


## 断言掉落了特定物品
func assert_dropped_item(loot_items: Array, item_data: ItemData, message: String = "") -> bool:
	for item in loot_items:
		if item is ItemInstance and item.item_data == item_data:
			return true
	
	var msg = message if message != "" else "掉落中应该包含物品: %s" % item_data.item_name
	push_error("[%s] %s: %s" % [suite_name, current_test, msg])
	return false


## 断言掉落数量正确
func assert_loot_count(loot_items: Array, expected_count: int, message: String = "") -> bool:
	return assert_equal(loot_items.size(), expected_count, message)


## 断言金币在范围内
func assert_gold_in_range(gold: int, min_gold: int, max_gold: int, message: String = "") -> bool:
	var passed = assert_greater_equal(gold, min_gold, "金币不应该小于最小值")
	passed = assert_less_equal(gold, max_gold, "金币不应该大于最大值") and passed
	return passed


## 断言掉落条目有效
func assert_loot_entry_valid(entry: LootEntry, message: String = "") -> bool:
	var passed = assert_not_null(entry, message)
	passed = assert_not_null(entry.item_data, "掉落条目应该有物品数据") and passed
	passed = assert_true(entry.drop_chance >= 0.0 and entry.drop_chance <= 1.0, "掉落概率应该在0-1之间") and passed
	return passed
