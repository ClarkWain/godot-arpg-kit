## Reward测试
## 测试任务奖励系统
extends TestFramework

var mock_player: MockObjects.MockPlayer
var task_manager: TaskManager

func _init() -> void:
	super._init("Reward测试")

## 设置测试环境
func setup() -> void:
	mock_player = MockObjects.MockPlayer.new()
	task_manager = TaskManager.new()
	task_manager._ready()
	task_manager.set_player(mock_player)

## 清理测试环境
func teardown() -> void:
	if mock_player:
		mock_player.queue_free()
	if task_manager:
		task_manager.queue_free()

## 运行所有测试
func run_all_tests() -> void:
	setup()
	
	test_experience_reward()
	test_item_reward()
	test_multiple_rewards()
	test_optional_rewards()
	test_reward_preview()
	test_reward_serialization()
	
	teardown()
	print_report()

## 测试: 经验奖励
func test_experience_reward() -> void:
	start_test("经验奖励")
	
	var reward = MockObjects.create_experience_reward(100)
	var context = TaskContext.new(mock_player, task_manager)
	
	var old_exp = mock_player.experience
	var success = reward.grant(context.to_dict())
	
	var passed = assert_true(success, "发放经验奖励应该成功")
	passed = assert_equal(mock_player.experience, old_exp + 100, "经验值应该增加100") and passed
	
	end_test(passed)

## 测试: 物品奖励
func test_item_reward() -> void:
	start_test("物品奖励")
	
	var reward = MockObjects.create_item_reward("health_potion", 5)
	var context = TaskContext.new(mock_player, task_manager)
	
	var success = reward.grant(context.to_dict())
	
	var passed = assert_true(success, "发放物品奖励应该成功")
	passed = assert_true(mock_player.inventory.has_item("health_potion", 5), "应该获得5个生命药水") and passed
	passed = assert_equal(mock_player.inventory.get_item_count("health_potion"), 5, "物品数量应该正确") and passed
	
	end_test(passed)

## 测试: 多个奖励
func test_multiple_rewards() -> void:
	start_test("多个奖励")
	
	var task = MockObjects.create_test_task_data("multi_reward_task")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 1))
	task.rewards.append(MockObjects.create_experience_reward(200))
	task.rewards.append(MockObjects.create_item_reward("gold_coin", 50))
	task.rewards.append(MockObjects.create_item_reward("mana_potion", 3))
	
	task_manager.register_task(task)
	task_manager.accept_task("multi_reward_task")
	
	# 完成任务
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 1
	})
	
	var old_exp = mock_player.experience
	var success = task_manager.claim_rewards("multi_reward_task")
	
	var passed = assert_true(success, "领取多个奖励应该成功")
	passed = assert_equal(mock_player.experience, old_exp + 200, "经验值应该增加200") and passed
	passed = assert_true(mock_player.inventory.has_item("gold_coin", 50), "应该获得50个金币") and passed
	passed = assert_true(mock_player.inventory.has_item("mana_potion", 3), "应该获得3个魔法药水") and passed
	
	end_test(passed)

## 测试: 可选奖励
func test_optional_rewards() -> void:
	start_test("可选奖励")
	
	var task = MockObjects.create_test_task_data("optional_reward_task")
	task.objectives.append(MockObjects.create_count_objective("kill_enemy", "goblin", 1))
	task.rewards.append(MockObjects.create_experience_reward(100))
	
	# 添加可选奖励
	var optional1 = MockObjects.create_item_reward("iron_sword", 1)
	optional1.optional = true
	var optional2 = MockObjects.create_item_reward("iron_shield", 1)
	optional2.optional = true
	var optional3 = MockObjects.create_item_reward("iron_helmet", 1)
	optional3.optional = true
	
	task.optional_rewards.append(optional1)
	task.optional_rewards.append(optional2)
	task.optional_rewards.append(optional3)
	
	task_manager.register_task(task)
	task_manager.accept_task("optional_reward_task")
	
	# 完成任务
	task_manager.update_task_progress({
		"type": "kill_enemy",
		"target_id": "goblin",
		"count": 1
	})
	
	# 选择第二个可选奖励（盾牌）
	var success = task_manager.claim_rewards("optional_reward_task", 1)
	
	var passed = assert_true(success, "领取可选奖励应该成功")
	passed = assert_true(mock_player.inventory.has_item("iron_shield", 1), "应该获得铁盾") and passed
	passed = assert_false(mock_player.inventory.has_item("iron_sword"), "不应该获得铁剑") and passed
	passed = assert_false(mock_player.inventory.has_item("iron_helmet"), "不应该获得铁盔") and passed
	
	end_test(passed)

## 测试: 奖励预览
func test_reward_preview() -> void:
	start_test("奖励预览")
	
	var exp_reward = MockObjects.create_experience_reward(150)
	var item_reward = MockObjects.create_item_reward("rare_gem", 1)
	
	var exp_text = exp_reward.get_preview_text()
	var item_text = item_reward.get_preview_text()
	
	var passed = assert_true(exp_text.contains("150"), "经验奖励预览应该包含数值")
	passed = assert_true(item_text.contains("rare_gem"), "物品奖励预览应该包含物品ID") and passed
	
	end_test(passed)

## 测试: 奖励序列化
func test_reward_serialization() -> void:
	start_test("奖励序列化")
	
	var reward = MockObjects.create_experience_reward(250)
	
	# 序列化
	var data = reward.to_dict()
	var passed = assert_equal(data["reward_id"], "exp_reward", "奖励ID应该正确")
	passed = assert_equal(data["experience"], 250, "经验值应该正确") and passed
	
	# 反序列化
	var new_reward = ExperienceReward.new()
	new_reward.from_dict(data)
	
	passed = assert_equal(new_reward.experience, 250, "经验值应该恢复") and passed
	
	end_test(passed)