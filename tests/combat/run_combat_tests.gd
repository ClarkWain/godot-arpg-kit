## 战斗系统测试运行器
## 运行所有战斗系统测试
extends Node

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
	
	# 生成总体报告
	print("\n" + "=".repeat(80))
	print("战斗系统测试完成")
	print("=".repeat(80) + "\n")
	
	# 退出
	get_tree().quit()

## 运行伤害计算器测试
func run_damage_calculator_tests() -> void:
	print("\n--- 伤害计算器测试 ---")
	var test = preload("res://tests/combat/test_damage_calculator.gd").new()
	test.run_all_tests()

## 运行战斗组件测试
func run_combat_component_tests() -> void:
	print("\n--- 战斗组件测试 ---")
	var test = preload("res://tests/combat/test_combat_component.gd").new()
	test.run_all_tests()

## 运行状态效果管理器测试
func run_status_effect_manager_tests() -> void:
	print("\n--- 状态效果管理器测试 ---")
	var test = preload("res://tests/combat/test_status_effect_manager.gd").new()
	test.run_all_tests()

## 运行技能管理器测试
func run_skill_manager_tests() -> void:
	print("\n--- 技能管理器测试 ---")
	var test = preload("res://tests/combat/test_skill_manager.gd").new()
	test.run_all_tests()

## 运行集成测试
func run_integration_tests() -> void:
	print("\n--- 集成测试 ---")
	var test = preload("res://tests/combat/test_integration.gd").new()
	test.run_all_tests()
