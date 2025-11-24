## LuckSystem测试
## 测试幸运系统工具方法的正确性
class_name TestLuckSystem
extends TestFramework

func _init() -> void:
	super._init("LuckSystem测试")

## 运行所有测试
func run_all_tests() -> void:
	test_get_luck_modified_chance()
	test_luck_check()
	test_apply_luck_to_value()
	test_get_luck_rarity_boost()
	test_get_effective_luck()
	test_get_extra_drop_chance()
	test_get_quality_multiplier()
	
	print_report()

## 测试: 幸运加成概率计算
func test_get_luck_modified_chance() -> void:
	start_test("幸运加成概率计算")
	
	# 基础概率 10%, 幸运值 10, 每点幸运 +1%
	var result = LuckSystem.get_luck_modified_chance(0.1, 10, 0.01)
	var passed = assert_almost_equal(result, 0.2, 0.001, "基础10% + 幸运10点*1% = 20%")
	
	# 测试上限
	result = LuckSystem.get_luck_modified_chance(0.5, 100, 0.01, 0.8)
	passed = assert_almost_equal(result, 0.8, 0.001, "应该被上限0.8限制") and passed
	
	# 测试负幸运（虽然通常不会发生）
	result = LuckSystem.get_luck_modified_chance(0.2, -5, 0.01)
	passed = assert_almost_equal(result, 0.15, 0.001, "负幸运应该降低概率") and passed
	
	end_test(passed)

## 测试: 幸运检定
func test_luck_check() -> void:
	start_test("幸运检定")
	
	# 模拟随机种子以获得可预测结果
	seed(12345)
	
	# 100% 成功率
	var result = LuckSystem.luck_check(1.0, 0)
	var passed = assert_true(result, "100%概率应该总是成功")
	
	# 0% 成功率
	result = LuckSystem.luck_check(0.0, 0)
	passed = assert_false(result, "0%概率应该总是失败") and passed
	
	# 50% + 幸运加成
	result = LuckSystem.luck_check(0.5, 10, 0.01)  # 60% 成功率
	# 由于是随机结果，我们只验证函数能正常运行
	passed = assert_true(typeof(result) == TYPE_BOOL, "应该返回布尔值") and passed
	
	end_test(passed)

## 测试: 幸运影响数值
func test_apply_luck_to_value() -> void:
	start_test("幸运影响数值")
	
	# 基础值 100, 幸运 10, 每点幸运 +1%
	var result = LuckSystem.apply_luck_to_value(100.0, 10, 0.01)
	var passed = assert_almost_equal(result, 110.0, 0.001, "100 * (1 + 10*0.01) = 110")
	
	# 测试零幸运
	result = LuckSystem.apply_luck_to_value(50.0, 0, 0.01)
	passed = assert_almost_equal(result, 50.0, 0.001, "零幸运应该不改变值") and passed
	
	# 测试高幸运
	result = LuckSystem.apply_luck_to_value(200.0, 50, 0.005)
	passed = assert_almost_equal(result, 250.0, 0.001, "200 * (1 + 50*0.005) = 250") and passed
	
	end_test(passed)

## 测试: 幸运稀有度提升
func test_get_luck_rarity_boost() -> void:
	start_test("幸运稀有度提升")
	
	# 模拟随机种子
	seed(54321)
	
	# 低幸运值
	var result = LuckSystem.get_luck_rarity_boost(5)
	var passed = assert_true(result >= 0 and result <= 3, "稀有度提升应该在0-3之间")
	
	# 高幸运值
	result = LuckSystem.get_luck_rarity_boost(50)
	passed = assert_true(result >= 0 and result <= 3, "高幸运也应该在合理范围内") and passed
	
	# 零幸运
	result = LuckSystem.get_luck_rarity_boost(0)
	passed = assert_equal(result, 0, "零幸运不应该提升稀有度") and passed
	
	end_test(passed)

## 测试: 幸运软上限
func test_get_effective_luck() -> void:
	start_test("幸运软上限")
	
	# 100以内应该线性
	var result = LuckSystem.get_effective_luck(50)
	var passed = assert_almost_equal(result, 50.0, 0.001, "100以内应该线性")
	
	result = LuckSystem.get_effective_luck(100)
	passed = assert_almost_equal(result, 100.0, 0.001, "100应该不变") and passed
	
	# 超过100应该递减
	result = LuckSystem.get_effective_luck(150)
	var expected = 100.0 + sqrt(150 - 100)  # 100 + sqrt(50) ≈ 107.07
	passed = assert_almost_equal(result, expected, 0.01, "超过100应该递减") and passed
	
	result = LuckSystem.get_effective_luck(200)
	expected = 100.0 + sqrt(200 - 100)  # 100 + sqrt(100) = 110
	passed = assert_almost_equal(result, 110.0, 0.001, "200幸运应该等于110") and passed
	
	end_test(passed)

## 测试: 额外掉落概率
func test_get_extra_drop_chance() -> void:
	start_test("额外掉落概率")
	
	# 幸运值 10: 5% + 10*0.01 = 6%
	var result = LuckSystem.get_extra_drop_chance(10)
	var passed = assert_almost_equal(result, 0.06, 0.001, "幸运10应该有6%额外掉落")
	
	# 幸运值 50: 5% + 50*0.01 = 10%
	result = LuckSystem.get_extra_drop_chance(50)
	passed = assert_almost_equal(result, 0.10, 0.001, "幸运50应该有10%额外掉落") and passed
	
	# 幸运值 0: 5%基础概率
	result = LuckSystem.get_extra_drop_chance(0)
	passed = assert_almost_equal(result, 0.05, 0.001, "零幸运应该有5%基础概率") and passed
	
	end_test(passed)

## 测试: 品质倍率
func test_get_quality_multiplier() -> void:
	start_test("品质倍率")
	
	# 幸运值 10, 基础倍率 0.002: 1.0 + 10*0.002 = 1.02
	var result = LuckSystem.get_quality_multiplier(10, 0.002)
	var passed = assert_almost_equal(result, 1.02, 0.001, "幸运10应该有1.02倍率")
	
	# 幸运值 50, 默认倍率 0.002: 1.0 + 50*0.002 = 1.1
	result = LuckSystem.get_quality_multiplier(50)
	passed = assert_almost_equal(result, 1.1, 0.001, "幸运50应该有1.1倍率") and passed
	
	# 幸运值 0: 1.0
	result = LuckSystem.get_quality_multiplier(0)
	passed = assert_almost_equal(result, 1.0, 0.001, "零幸运应该有1.0倍率") and passed
	
	end_test(passed)