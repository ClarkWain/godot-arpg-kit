## WeaponData测试
## 测试武器数据功能
extends "res://tests/items/test_framework.gd"

func _init() -> void:
	super._init("WeaponData测试")

## 运行所有测试
func run_all_tests() -> void:
	test_create_weapon()
	test_damage_system()
	test_weapon_types()

	print_report()

## 测试: 创建武器
func test_create_weapon() -> void:
	start_test("创建武器")

	var weapon_data = WeaponData.new()
	weapon_data.item_name = "测试武器"
	weapon_data.equip_slot = EquipmentData.EquipSlot.WEAPON_MAIN
	weapon_data.weapon_type = WeaponData.WeaponType.SWORD
	weapon_data.min_physical_damage = 8.0
	weapon_data.max_physical_damage = 15.0
	weapon_data.attack_speed = 1.2
	weapon_data.required_level = 3

	var passed = assert_not_null(weapon_data, "应该能够创建武器数据")
	passed = assert_equal(weapon_data.weapon_type, WeaponData.WeaponType.SWORD, "武器类型应该正确") and passed
	passed = assert_almost_equal(weapon_data.min_physical_damage, 8.0, 0.001, "最小伤害应该正确") and passed
	passed = assert_almost_equal(weapon_data.max_physical_damage, 15.0, 0.001, "最大伤害应该正确") and passed
	passed = assert_almost_equal(weapon_data.attack_speed, 1.2, 0.001, "攻击速度应该正确") and passed

	end_test(passed)

## 测试: 伤害系统
func test_damage_system() -> void:
	start_test("伤害系统")

	var weapon_data = create_test_weapon_data("伤害测试武器", EquipmentData.EquipSlot.WEAPON_MAIN, 1, [], 10.0, 20.0, 1.0)

	var passed = assert_almost_equal(weapon_data.min_physical_damage, 10.0, 0.001, "最小伤害应该正确")
	passed = assert_almost_equal(weapon_data.max_physical_damage, 20.0, 0.001, "最大伤害应该正确") and passed

	end_test(passed)

## 测试: 武器类型
func test_weapon_types() -> void:
	start_test("武器类型")

	var weapon_types = [
		WeaponData.WeaponType.SWORD,
		WeaponData.WeaponType.GREATSWORD,
		WeaponData.WeaponType.AXE,
		WeaponData.WeaponType.MACE,
		WeaponData.WeaponType.DAGGER,
		WeaponData.WeaponType.SPEAR,
		WeaponData.WeaponType.BOW,
		WeaponData.WeaponType.CROSSBOW,
		WeaponData.WeaponType.STAFF,
		WeaponData.WeaponType.WAND
	]

	var passed = true
	for weapon_type in weapon_types:
		var weapon_data = create_test_weapon_data("类型测试武器", EquipmentData.EquipSlot.WEAPON_MAIN, 1, [], 10.0, 15.0, 1.0)
		weapon_data.weapon_type = weapon_type
		passed = assert_equal(weapon_data.weapon_type, weapon_type, "武器类型应该正确设置") and passed

	end_test(passed)