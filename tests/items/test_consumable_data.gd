## ConsumableData测试
## 测试消耗品数据功能
class_name TestConsumableData
extends ItemTestFramework

func _init() -> void:
	super._init("ConsumableData测试")

## 运行所有测试
func run_all_tests() -> void:
	test_create_consumable()
	test_consumable_effects()

	print_report()

## 测试: 创建消耗品
func test_create_consumable() -> void:
	start_test("创建消耗品")

	var consumable_data = ConsumableData.new()
	consumable_data.item_name = "测试药水"
	consumable_data.effect_type = ConsumableData.EffectType.INSTANT_HEAL
	consumable_data.max_stack = 20
	consumable_data.use_time = 1.5
	consumable_data.cooldown = 5.0

	var passed = assert_not_null(consumable_data, "应该能够创建消耗品数据")
	passed = assert_equal(consumable_data.effect_type, ConsumableData.EffectType.INSTANT_HEAL, "消耗品类型应该正确") and passed
	passed = assert_equal(consumable_data.max_stack, 20, "最大堆叠应该正确") and passed
	passed = assert_almost_equal(consumable_data.use_time, 1.5, 0.001, "使用时间应该正确") and passed
	passed = assert_almost_equal(consumable_data.cooldown, 5.0, 0.001, "冷却时间应该正确") and passed

	end_test(passed)

## 测试: 消耗品效果
func test_consumable_effects() -> void:
	start_test("消耗品效果")

	# 创建治疗药水
	var healing_potion = create_test_consumable_data("治疗药水", ConsumableData.EffectType.INSTANT_HEAL, 50.0)

	var passed = assert_equal(healing_potion.effect_type, ConsumableData.EffectType.INSTANT_HEAL, "效果类型应该是治疗")
	passed = assert_almost_equal(healing_potion.effect_value, 50.0, 0.001, "治疗值应该是50") and passed

	# 创建魔力药水
	var mana_potion = create_test_consumable_data("魔力药水", ConsumableData.EffectType.INSTANT_MANA, 30.0)
	passed = assert_equal(mana_potion.effect_type, ConsumableData.EffectType.INSTANT_MANA, "效果类型应该是恢复魔力") and passed
	passed = assert_almost_equal(mana_potion.effect_value, 30.0, 0.001, "魔力恢复值应该是30") and passed

	end_test(passed)