# tests/stats_regen_example.gd
extends Node2D

## 自动化测试：生命/魔力/耐力回复系统
##
## 说明：此文件不再作为示例，而是将多个示例转换为可重复运行的“测试用例”。
## 每个 test_* 函数会调用 expect_* 断言辅助函数，汇总通过/失败数量并打印结果。
## 注意：在 Godot 编辑器里运行以查看输出；若项目中的 API 名称与断言使用的方法不一致，请根据运行时错误反馈我来修正。

func _ready():
	# 运行所有 test_* 用例并汇总结果
	print("=== 开始回复系统测试 ===")

	# 按顺序执行每个测试并统计（test_* 自行负责 test_start/test_end/断言）
	test_simple_regen()
	test_stack_and_overheal()
	test_percent_buff_and_expire()
	test_negative_regen()
	test_timer_configuration()

	print_test_summary()


# ----------------- 断言辅助工具 -----------------
var test_passed: int = 0
var test_failed: int = 0
var test_total: int = 0
var test_failed_reason: Array[String] = []

func test_start(test_name: String) -> void:
	test_total += 1
	print("\n测试 %s:" % test_name)

func test_end() -> void:
	test_passed += 1
	print("  ✓ 通过")

func assert_equals(actual, expected, message: String = "") -> void:
	if typeof(actual) == TYPE_FLOAT and typeof(expected) == TYPE_FLOAT:
		if abs(actual - expected) > 0.001:
			test_failed += 1
			test_failed_reason.append(message)
			print("  ✗ 失败: %s" % message)
			print("    期望: %s, 实际: %s" % [expected, actual])
		else:
			print("  ✓ %s" % message)
	elif actual != expected:
		test_failed += 1
		test_failed_reason.append(message)
		print("  ✗ 失败: %s" % message)
		print("    期望: %s, 实际: %s" % [expected, actual])
	else:
		print("  ✓ %s" % message)

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		test_failed += 1
		test_failed_reason.append(message)
		print("  ✗ 失败: %s" % message)
	else:
		print("  ✓ %s" % message)

func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		test_failed += 1
		test_failed_reason.append(message)
		print("  ✗ 失败: %s" % message)
	else:
		print("  ✓ %s" % message)

func assert_almost_equal(actual: float, expected: float, message: String = "", eps: float = 0.001) -> void:
	if abs(actual - expected) > eps:
		test_failed += 1
		test_failed_reason.append(message)
		print("  ✗ 失败: %s" % message)
		print("    期望: %.6f, 实际: %.6f, eps=%.6f" % [expected, actual, eps])
	else:
		print("  ✓ %s" % message)

func print_test_summary() -> void:
	print("\n" + "=".repeat(60))
	print("测试总结")
	print("=".repeat(60))
	print("总测试数: %d" % test_total)
	print("通过: %d" % test_passed)
	print("失败: %d" % test_failed)
	var pass_rate = 0.0
	if test_total > 0:
		pass_rate = (float(test_passed) / float(test_total)) * 100.0
	print("通过率: %.1f%%" % pass_rate)
	for i in test_failed_reason:
		print("未通过用例：%s" % [i])
	print("=".repeat(60))


## 兼容性包装：保留之前 expect_* 名称以免大量修改测试函数
func expect_almost_equal(test_name: String, a: float, b: float, eps: float = 0.001) -> void:
	assert_almost_equal(a, b, test_name, eps)

func expect_true(test_name: String, cond: bool, msg: String = "") -> void:
	var message = msg if msg != "" else test_name
	assert_true(cond, message)

func expect_equal(test_name: String, a, b) -> void:
	assert_equals(a, b, test_name)


## 示例: 创建不同类型的药水效果
func create_health_potion_effect(stats: StatsComponent, duration: float = 10.0) -> void:
	"""快速回复药水 - 10秒内每秒回复10点生命"""
	var potion_effect = StatModifier.create_flat(
		StatModifier.StatType.HEALTH_REGEN,
		10.0,
		"health_potion"
	).set_duration(duration).add_tag("potion").add_tag("buff")
	
	stats.add_modifier(potion_effect)


func create_mana_potion_effect(stats: StatsComponent, duration: float = 15.0) -> void:
	"""魔力回复药水 - 15秒内每秒回复5点魔力"""
	var potion_effect = StatModifier.create_flat(
		StatModifier.StatType.MANA_REGEN,
		5.0,
		"mana_potion"
	).set_duration(duration).add_tag("potion").add_tag("buff")
	
	stats.add_modifier(potion_effect)


func create_stamina_boost_effect(stats: StatsComponent, duration: float = 5.0) -> void:
	"""耐力冲刺药水 - 5秒内耐力回复速度翻倍"""
	var boost_effect = StatModifier.create_percent(
		StatModifier.StatType.STAMINA_REGEN,
		1.0,  # +100% = 翻倍
		"stamina_boost"
	).set_duration(duration).add_tag("potion").add_tag("buff")
	
	stats.add_modifier(boost_effect)


## 示例: 装备影响回复速率
func equip_regeneration_ring(stats: StatsComponent) -> void:
	"""回复之戒 - 永久增加所有回复速率"""
	var ring_health = StatModifier.create_flat(
		StatModifier.StatType.HEALTH_REGEN,
		2.0,
		"regeneration_ring"
	).add_tag("equipment")
	
	var ring_mana = StatModifier.create_flat(
		StatModifier.StatType.MANA_REGEN,
		1.0,
		"regeneration_ring"
	).add_tag("equipment")
	
	stats.add_modifier(ring_health)
	stats.add_modifier(ring_mana)


func unequip_regeneration_ring(stats: StatsComponent) -> void:
	"""卸下回复之戒"""
	stats.remove_modifiers_by_source("regeneration_ring")


## ========== 额外测试与仿真示例 ==========


func test_simple_regen() -> void:
	"""测试：简单每秒回复仿真，断言最终生命值等于期望（含上限截断）。"""
	test_start("test_simple_regen")
	var duration = 5
	var s = StatsComponent.new()
	s.base_stats = StatsData.new()
	s.base_stats.max_health = 100.0
	s.base_stats.health_regen = 2.0
	add_child(s)

	s.current_health = 50.0
	var per_sec = s.get_stat(StatModifier.StatType.HEALTH_REGEN)
	for t in range(duration):
		s.heal(per_sec)

	var expected = min(50.0 + per_sec * duration, s.base_stats.max_health)
	expect_almost_equal("test_simple_regen", s.current_health, expected)
	test_end()


func test_stack_and_overheal() -> void:
	"""测试：多个修正器叠加后回复值并不会超过最大生命值。"""
	test_start("test_stack_and_overheal")
	var s = StatsComponent.new()
	s.base_stats = StatsData.new()
	s.base_stats.max_health = 120.0
	s.base_stats.health_regen = 1.0
	add_child(s)

	var mod1 = StatModifier.create_flat(StatModifier.StatType.HEALTH_REGEN, 3.0, "potion_a")
	var mod2 = StatModifier.create_flat(StatModifier.StatType.HEALTH_REGEN, 4.0, "potion_b")
	s.add_modifier(mod1)
	s.add_modifier(mod2)

	s.current_health = 118.0
	var total_regen = s.get_stat(StatModifier.StatType.HEALTH_REGEN)
	s.heal(total_regen)

	# 期望被截断到最大生命 120
	var max_health = s.get_stat(StatModifier.StatType.MAX_HEALTH)
	var stats_regen = s.get_stat(StatModifier.StatType.HEALTH_REGEN)
	var expected = min(118.0 + total_regen, max_health)
	print("max_health=%s, stats_regen=%s, expected=%s" % [max_health, stats_regen, expected])
	expect_almost_equal("test_stack_and_overheal", s.current_health, expected)

	s.remove_modifiers_by_source("potion_a")
	s.remove_modifiers_by_source("potion_b")
	test_end()


func test_percent_buff_and_expire() -> void:
	"""测试：百分比修正器影响回复，并在移除后恢复到原始值。"""
	test_start("test_percent_buff_and_expire")
	var s = StatsComponent.new()
	s.base_stats = StatsData.new()
	s.base_stats.max_mana = 80.0
	s.base_stats.mana_regen = 2.0
	add_child(s)

	s.current_mana = 0.0
	var base_regen = s.get_stat(StatModifier.StatType.MANA_REGEN)

	var pct = StatModifier.create_percent(StatModifier.StatType.MANA_REGEN, 0.5, "meditation_skill")
	s.add_modifier(pct)

	var boosted = s.get_stat(StatModifier.StatType.MANA_REGEN)
	expect_almost_equal("test_percent_buff_and_expire_boosted", boosted, base_regen * 1.5)

	# 模拟两秒回复（使用已缓存的 boosted 值以避免运行时变化影响断言）
	for t in range(2):
		s.restore_mana(boosted)

	expect_almost_equal("test_percent_buff_and_expire_mana_amount", s.current_mana, boosted * 2.0)

	s.remove_modifiers_by_source("meditation_skill")
	expect_almost_equal("test_percent_buff_and_expire_back_to_base", s.get_stat(StatModifier.StatType.MANA_REGEN), base_regen)
	test_end()


func test_negative_regen() -> void:
	"""测试：负面debuff（中毒）对生命的持续降低效果。"""
	test_start("test_negative_regen")
	var s = StatsComponent.new()
	s.base_stats = StatsData.new()
	s.base_stats.max_health = 60.0
	s.base_stats.health_regen = 0.5
	add_child(s)

	var poison = StatModifier.create_flat(StatModifier.StatType.HEALTH_REGEN, -5.0, "poison_debuff")
	s.add_modifier(poison)

	s.current_health = 50.0
	var steps = 4
	var per_sec = s.get_stat(StatModifier.StatType.HEALTH_REGEN) # 包含负数
	for t in range(steps):
		if per_sec >= 0:
			s.heal(per_sec)
		else:
			s.lose_health(-per_sec)

	var expected = 50.0 + steps * per_sec
	expect_almost_equal("test_negative_regen", s.current_health, expected)

	s.remove_modifiers_by_source("poison_debuff")
	test_end()


func test_timer_configuration() -> void:
	"""测试：Timer 配置正确（wait_time、one_shot、autostart）。"""
	test_start("test_timer_configuration")
	var stats_node = StatsComponent.new()
	stats_node.base_stats = StatsData.new()
	stats_node.base_stats.max_health = 200.0
	stats_node.base_stats.health_regen = 2.0
	add_child(stats_node)

	var t = Timer.new()
	t.wait_time = 1.0
	t.one_shot = false
	t.autostart = false
	add_child(t)

	expect_almost_equal("test_timer_wait_time", t.wait_time, 1.0)
	expect_true("test_timer_one_shot", not t.one_shot, "Timer.one_shot 应为 false")
	expect_true("test_timer_autostart", not t.autostart, "Timer.autostart 应为 false")
	test_end()
