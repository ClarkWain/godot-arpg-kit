## Items系统测试框架
##
## 提供items系统测试的基础功能和断言方法
## 继承自TestFramework
class_name ItemTestFramework
extends TestFramework

## ========== 物品测试辅助方法 ==========

## 创建测试物品数据
func create_test_item_data(
	item_name: String = "测试物品",
	item_type: ItemData.ItemType = ItemData.ItemType.MATERIAL,
	rarity: ItemData.Rarity = ItemData.Rarity.COMMON,
	max_stack: int = 1,
	base_value: int = 10
) -> ItemData:
	var item_data = ItemData.new()
	item_data.id = "test_" + item_name.to_lower().replace(" ", "_")
	item_data.item_name = item_name
	item_data.item_type = item_type
	item_data.rarity = rarity
	item_data.max_stack = max_stack
	item_data.base_value = base_value
	item_data.description = "用于测试的%s" % item_name
	return item_data


## 创建测试装备数据
func create_test_equipment_data(
	item_name: String = "测试装备",
	slot: EquipmentData.EquipSlot = EquipmentData.EquipSlot.CHEST,
	required_level: int = 1,
	stat_modifiers: Array[StatModifier] = []
) -> EquipmentData:
	var equip_data = EquipmentData.new()
	equip_data.id = "test_equip_" + item_name.to_lower().replace(" ", "_")
	equip_data.item_name = item_name
	equip_data.equip_slot = slot
	equip_data.required_level = required_level
	equip_data.stat_modifiers = stat_modifiers
	equip_data.description = "用于测试的%s装备" % item_name
	return equip_data


## 创建测试消耗品数据
func create_test_consumable_data(
	item_name: String = "测试药水",
	effect_type: ConsumableData.EffectType = ConsumableData.EffectType.INSTANT_HEAL,
	effect_value: float = 50.0
) -> ConsumableData:
	var consumable_data = ConsumableData.new()
	consumable_data.id = "test_consumable_" + item_name.to_lower().replace(" ", "_")
	consumable_data.item_name = item_name
	consumable_data.effect_type = effect_type
	consumable_data.effect_value = effect_value
	consumable_data.description = "用于测试的%s" % item_name
	return consumable_data


## 创建测试武器数据
func create_test_weapon_data(
	item_name: String = "测试武器",
	slot: EquipmentData.EquipSlot = EquipmentData.EquipSlot.WEAPON_MAIN,
	required_level: int = 1,
	stat_modifiers: Array[StatModifier] = [],
	min_damage: float = 10.0,
	max_damage: float = 15.0,
	attack_speed: float = 1.0
) -> WeaponData:
	var weapon_data = WeaponData.new()
	weapon_data.id = "test_weapon_" + item_name.to_lower().replace(" ", "_")
	weapon_data.item_name = item_name
	weapon_data.equip_slot = slot
	weapon_data.required_level = required_level
	weapon_data.stat_modifiers = stat_modifiers
	weapon_data.min_physical_damage = min_damage
	weapon_data.max_physical_damage = max_damage
	weapon_data.attack_speed = attack_speed
	weapon_data.description = "用于测试的%s" % item_name
	return weapon_data


## 创建模拟玩家
func create_mock_player(level: int = 1, strength: int = 10, dexterity: int = 10) -> Dictionary:
	return {
		"level": level,
		"strength": strength,
		"dexterity": dexterity
	}


## 创建测试物品实例
func create_test_item_instance(
	item_data: ItemData,
	stack_count: int = 1
) -> ItemInstance:
	return ItemInstance.create(item_data, stack_count)


## 创建测试属性修正器
func create_test_stat_modifier(
	stat_type: StatModifier.StatType = StatModifier.StatType.STRENGTH,
	modifier_type: StatModifier.ModifierType = StatModifier.ModifierType.FLAT,
	value: float = 5.0,
	source_id: String = "test"
) -> StatModifier:
	return StatModifier.create_flat(stat_type, value, source_id) if modifier_type == StatModifier.ModifierType.FLAT else StatModifier.create_percent(stat_type, value, source_id)


## ========== 物品专用断言 ==========

## 断言物品实例有效
func assert_item_instance_valid(instance: ItemInstance, message: String = "") -> bool:
	var passed = assert_not_null(instance, message)
	if passed:
		passed = assert_not_null(instance.item_data, "物品实例应该有有效的物品数据") and passed
		passed = assert_true(instance.stack_count > 0, "堆叠数量应该大于0") and passed
		passed = assert_not_null(instance.instance_id, "实例ID不应该为null") and passed
	return passed


## 断言物品可以堆叠
func assert_can_stack(instance1: ItemInstance, instance2: ItemInstance, expected: bool, message: String = "") -> bool:
	var can_stack = instance1.can_stack_with(instance2)
	return assert_equal(can_stack, expected, message)


## 断言物品价值正确
func assert_item_value(instance: ItemInstance, expected_value: int, message: String = "") -> bool:
	var actual_value = instance.get_total_value()
	return assert_equal(actual_value, expected_value, message)


## 断言装备需求满足
func assert_can_equip(equip_data: EquipmentData, character_level: int, expected: bool, message: String = "") -> bool:
	var can_equip = equip_data.can_equip(character_level)
	return assert_equal(can_equip, expected, message)


## 断言消耗品效果正确
func assert_consumable_effect(consumable: ConsumableData, expected_type: ConsumableData.EffectType, expected_value: float, message: String = "") -> bool:
	var passed = assert_equal(consumable.effect_type, expected_type, "效果类型应该正确")
	passed = assert_almost_equal(consumable.effect_value, expected_value, 0.001, "效果数值应该正确") and passed
	return passed
