## EquipmentData测试
## 测试装备数据功能
class_name TestEquipmentData
extends ItemTestFramework

func _init() -> void:
	super._init("EquipmentData测试")

## 运行所有测试
func run_all_tests() -> void:
	test_create_equipment()
	test_equipment_slots()
	test_stat_modifiers()
	test_durability()

	print_report()

## 测试: 创建装备
func test_create_equipment() -> void:
	start_test("创建装备")

	# 创建基础装备数据
	var equip_data = EquipmentData.new()
	equip_data.item_name = "测试装备"
	equip_data.equip_slot = EquipmentData.EquipSlot.WEAPON_MAIN
	equip_data.required_level = 5
	equip_data.has_durability = true
	equip_data.max_durability = 100

	var passed = assert_not_null(equip_data, "应该能够创建装备数据")
	passed = assert_equal(equip_data.equip_slot, EquipmentData.EquipSlot.WEAPON_MAIN, "装备槽位应该正确设置") and passed
	passed = assert_equal(equip_data.required_level, 5, "等级要求应该正确设置") and passed
	passed = assert_true(equip_data.has_durability, "耐久度设置应该正确") and passed
	passed = assert_equal(equip_data.max_durability, 100, "最大耐久度应该正确设置") and passed

	end_test(passed)

## 测试: 装备槽位
func test_equipment_slots() -> void:
	start_test("装备槽位")

	var slots = [
		EquipmentData.EquipSlot.HELMET,
		EquipmentData.EquipSlot.CHEST,
		EquipmentData.EquipSlot.LEGS,
		EquipmentData.EquipSlot.BOOTS,
		EquipmentData.EquipSlot.GLOVES,
		EquipmentData.EquipSlot.WEAPON_MAIN,
		EquipmentData.EquipSlot.WEAPON_OFF,
		EquipmentData.EquipSlot.RING_1,
		EquipmentData.EquipSlot.RING_2,
		EquipmentData.EquipSlot.AMULET,
		EquipmentData.EquipSlot.BELT
	]

	var passed = true
	for slot in slots:
		var equip_data = create_test_equipment_data("槽位测试装备", slot, 1, [])
		passed = assert_equal(equip_data.equip_slot, slot, "装备槽位应该正确设置") and passed

	end_test(passed)

## 测试: 统计修正器
func test_stat_modifiers() -> void:
	start_test("统计修正器")

	# 创建带统计修正器的装备
	var mod1 = create_test_stat_modifier(StatModifier.StatType.STRENGTH, StatModifier.ModifierType.FLAT, 10)
	var mod2 = create_test_stat_modifier(StatModifier.StatType.ARMOR, StatModifier.ModifierType.PERCENT, 0.05)
	var modifiers: Array[StatModifier] = [mod1, mod2]

	var equip_data = create_test_equipment_data("力量装备", EquipmentData.EquipSlot.WEAPON_MAIN, 1, modifiers)

	var passed = assert_equal(equip_data.stat_modifiers.size(), 2, "应该有2个统计修正器")
	passed = assert_equal(equip_data.stat_modifiers[0].stat_type, StatModifier.StatType.STRENGTH, "第一个修正器应该是力量") and passed
	passed = assert_equal(equip_data.stat_modifiers[1].stat_type, StatModifier.StatType.ARMOR, "第二个修正器应该是护甲") and passed

	# 测试空修正器装备
	var empty_modifiers: Array[StatModifier] = []
	var empty_equip = create_test_equipment_data("空装备", EquipmentData.EquipSlot.CHEST, 1, empty_modifiers)
	passed = assert_equal(empty_equip.stat_modifiers.size(), 0, "空装备应该没有修正器") and passed

	end_test(passed)

## 测试: 耐久度
func test_durability() -> void:
	start_test("耐久度")

	# 创建有耐久度的装备
	var durable_equip = create_test_equipment_data("耐久装备", EquipmentData.EquipSlot.WEAPON_MAIN, 1, [])
	durable_equip.has_durability = true
	durable_equip.max_durability = 200

	var passed = assert_true(durable_equip.has_durability, "装备应该有耐久度")
	passed = assert_equal(durable_equip.max_durability, 200, "最大耐久度应该正确") and passed

	# 测试无耐久度装备
	var indestructible_equip = create_test_equipment_data("不朽装备", EquipmentData.EquipSlot.CHEST, 1, [])
	passed = assert_false(indestructible_equip.has_durability, "装备不应该有耐久度") and passed

	end_test(passed)