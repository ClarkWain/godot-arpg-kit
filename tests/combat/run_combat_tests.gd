## 战斗系统测试运行器
## 运行所有战斗系统测试
extends Node

# 累计失败测试数，用于决定进程退出码（供 CI 使用）
var _total_failed: int = 0
var _total_tests: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("开始运行战斗系统测试")
	print("=".repeat(80) + "\n")
	
	# 运行所有测试
	run_damage_calculator_tests()
	run_combat_component_tests()
	run_status_effect_manager_tests()
	run_skill_manager_tests()
	run_integration_tests()
	run_damage_pipeline_regression_tests()
	run_high_priority_fixes_tests()
	
	# 生成总体报告
	print("\n" + "=".repeat(80))
	print("战斗系统测试完成")
	print("总测试数: %d, 通过: %d, 失败: %d" % [
		_total_tests, _total_tests - _total_failed, _total_failed
	])
	print("=".repeat(80) + "\n")
	
	# 按失败数返回进程退出码（>0 表示 CI 应视为构建失败）
	var exit_code: int = 0 if _total_failed == 0 else 1
	get_tree().quit(exit_code)


## 累加一个测试套件的结果
func _tally(test: TestFramework) -> void:
	_total_tests += test.total_tests
	_total_failed += test.failed_tests


## 运行伤害计算器测试
func run_damage_calculator_tests() -> void:
	print("\n--- 伤害计算器测试 ---")
	var test = preload("res://tests/combat/test_damage_calculator.gd").new()
	test.run_all_tests()
	_tally(test)

## 运行战斗组件测试
func run_combat_component_tests() -> void:
	print("\n--- 战斗组件测试 ---")
	var test = preload("res://tests/combat/test_combat_component.gd").new()
	test.run_all_tests()
	_tally(test)

## 运行状态效果管理器测试
func run_status_effect_manager_tests() -> void:
	print("\n--- 状态效果管理器测试 ---")
	var test = preload("res://tests/combat/test_status_effect_manager.gd").new()
	test.run_all_tests()
	_tally(test)

## 运行技能管理器测试
func run_skill_manager_tests() -> void:
	print("\n--- 技能管理器测试 ---")
	var test = preload("res://tests/combat/test_skill_manager.gd").new()
	test.run_all_tests()
	_tally(test)

## 运行集成测试
func run_integration_tests() -> void:
	print("\n--- 集成测试 ---")
	var test = preload("res://tests/combat/test_integration.gd").new()
	test.run_all_tests()
	_tally(test)

## 运行伤害管线回归测试（防止双重减伤 BUG 复发）
func run_damage_pipeline_regression_tests() -> void:
	print("\n--- 伤害管线回归测试 ---")
	var test = preload("res://tests/combat/test_damage_pipeline_regression.gd").new()
	test.run_all_tests()
	_tally(test)

## 运行高优先级 BUG 回归测试（护甲穿透 / 消耗品使用 / 事件总线 autoload）
func run_high_priority_fixes_tests() -> void:
	print("\n--- 高优先级 BUG 回归测试 ---")
	var test = preload("res://tests/combat/test_high_priority_fixes.gd").new()
	test.run_all_tests()
	_tally(test)
