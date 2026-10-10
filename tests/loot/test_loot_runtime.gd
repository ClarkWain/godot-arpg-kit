## 实际场景树中的拾取事务与对象池回归。
extends TestFramework

func _init() -> void:
	super._init("掉落运行时事务与对象池")


func run_all_tests() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	test_full_inventory_retry()
	test_partial_stack_and_notifications()
	test_stacking_and_empty_slot()
	test_weight_rejection()
	test_missing_inventory_and_custom_handler()
	test_gold_and_duplicate_pickup()
	test_reentrant_pickup()
	await test_pool_reuse_and_reset()
	test_item_gold_reuse_visual()
	await test_clear_isolated_and_cancel_timer()
	test_externally_freed_pool_item()
	await test_generator_teardown()
	await test_despawn_without_sprite()
	test_custom_gold_scene()
	await test_physics_pickup()
	print_report()


func _scene(with_visuals: bool = true) -> PackedScene:
	var drop := DroppedItem.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = CircleShape2D.new()
	drop.add_child(shape)
	shape.owner = drop
	if with_visuals:
		for name in ["Sprite2D", "Glow"]:
			var sprite := Sprite2D.new()
			sprite.name = name
			drop.add_child(sprite)
			sprite.owner = drop
	var packed := PackedScene.new()
	packed.pack(drop)
	drop.free()
	return packed


func _fixture(pool_size: int = 1, with_visuals: bool = true) -> Dictionary:
	var world := Node2D.new()
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(world)
	var player := Node2D.new()
	player.add_to_group("player")
	var inventory := InventoryManager.new()
	inventory.name = "InventoryManager"
	inventory.slot_count = 1
	inventory.use_weight_limit = false
	player.add_child(inventory)
	world.add_child(player)
	var generator := _generator(world, pool_size, _scene(with_visuals))
	return {"world": world, "player": player, "inventory": inventory, "generator": generator}


func _generator(world: Node2D, size: int, scene: PackedScene) -> LootGenerator:
	var generator := LootGenerator.new()
	generator.pool_size = size
	generator.spawn_parent_path = world.get_path()
	generator.dropped_item_scene = scene
	world.add_child(generator)
	return generator


func _data(id: String = "runtime_material") -> ItemData:
	var data := ItemData.new()
	data.id = id
	data.max_stack = 10
	data.weight = 1.0
	return data


func test_full_inventory_retry() -> void:
	start_test("背包满时掉落保留，腾出空间后可重试")
	var f := _fixture()
	f.inventory.add_item(ItemInstance.create(_data("blocker"), 10))
	var data := _data()
	var drop: DroppedItem = f.generator.spawn_item(ItemInstance.create(data, 4), Vector2.ZERO)
	var events: Array = []
	f.generator.loot_picked_up.connect(func(item, _picker): events.append(item))
	var passed := assert_false(drop.try_pickup(f.player), "满包不能提交拾取")
	passed = assert_equal(drop.item_instance.stack_count, 4, "地上数量不变") and passed
	passed = assert_equal(events.size(), 0, "拒绝不发成功通知") and passed
	passed = assert_equal(drop.current_state, DroppedItem.State.IDLE, "保留可拾取状态") and passed
	f.inventory.remove_item(0)
	passed = assert_true(drop.try_pickup(f.player), "腾出空间后可拾取") and passed
	passed = assert_equal(f.inventory.get_item_count(data.id), 4, "没有丢失或重复") and passed
	passed = assert_equal(events.size(), 1, "仅通知一次") and passed
	f.world.free()
	end_test(passed)


func test_partial_stack_and_notifications() -> void:
	start_test("部分堆叠守恒，背包与掉落事件只报告实际入包数")
	var f := _fixture()
	var data := _data()
	f.inventory.add_item(ItemInstance.create(data, 8))
	var incoming := ItemInstance.create(data, 5)
	incoming.custom_data = {"origin": "enemy", "nested": {"roll": 3}}

	var drop: DroppedItem = f.generator.spawn_item(incoming, Vector2.ZERO)
	var inventory_events: Array = []
	var pickup_events: Array = []
	f.inventory.item_added.connect(func(item, _slot): inventory_events.append(item))
	f.generator.loot_picked_up.connect(func(item, _picker): pickup_events.append(item))
	var passed := assert_false(drop.try_pickup(f.player), "部分入包返回 false")
	passed = assert_equal(f.inventory.get_item_count(data.id), 10, "只入包两个") and passed
	passed = assert_equal(drop.item_instance.stack_count, 3, "三个留在地上") and passed
	passed = assert_equal(inventory_events.size(), 1, "一次入包通知") and passed
	passed = assert_equal(pickup_events.size(), 1, "一次拾取通知") and passed
	if inventory_events.size() == 1 and pickup_events.size() == 1:
		passed = assert_equal(inventory_events[0].stack_count, 2, "入包通知不是余量") and passed
		passed = assert_equal(pickup_events[0].stack_count, 2, "拾取通知只计已转移量") and passed
		passed = assert_equal(pickup_events[0].custom_data, incoming.custom_data, "保留物品元数据") and passed
		passed = assert_not_equal(pickup_events[0], incoming, "通知不与地上余量共用可变实例") and passed
	f.inventory.remove_item(0)
	passed = assert_true(drop.try_pickup(f.player), "剩余部分再次拾取") and passed
	passed = assert_equal(f.inventory.get_item_count(data.id), 3, "只拾取余量") and passed
	if pickup_events.size() == 2:
		passed = assert_equal(pickup_events[0].stack_count + pickup_events[1].stack_count, 5, "通知总量守恒") and passed
		passed = assert_equal(pickup_events[0].stack_count, 2, "历史通知未被重试改变") and passed
	f.world.free()
	end_test(passed)


func test_stacking_and_empty_slot() -> void:
	start_test("堆叠加新格子时事件数量与实际入包一致")
	var f := _fixture()
	# 调整容量无需再次调用 _ready() 清空已有数据。
	f.inventory.slot_count = 2
	f.inventory.slots.resize(2)
	var data := _data()
	f.inventory.add_item(ItemInstance.create(data, 8))
	var counts: Array = []
	f.inventory.item_added.connect(func(item, _slot): counts.append(item.stack_count))
	var drop: DroppedItem = f.generator.spawn_item(ItemInstance.create(data, 5), Vector2.ZERO)
	var passed := assert_true(drop.try_pickup(f.player), "全部接受")
	passed = assert_equal(f.inventory.get_item_count(data.id), 13, "两个格子总数正确") and passed
	passed = assert_equal(counts, [5], "包含两个格子的实际新增总数") and passed
	f.world.free()
	end_test(passed)


func test_weight_rejection() -> void:
	start_test("负重不足拒绝时不转移、不销毁")
	var f := _fixture()
	f.inventory.use_weight_limit = true
	f.inventory.max_weight = 1.0
	var drop: DroppedItem = f.generator.spawn_item(ItemInstance.create(_data(), 2), Vector2.ZERO)
	var passed := assert_false(drop.try_pickup(f.player), "重量超限")
	passed = assert_null(f.inventory.get_item(0), "背包仍为空") and passed
	passed = assert_equal(drop.item_instance.stack_count, 2, "掉落量不变") and passed
	passed = assert_true(drop._release_timer.is_stopped(), "没有启动销毁计时器") and passed
	f.world.free()
	end_test(passed)


func test_missing_inventory_and_custom_handler() -> void:
	start_test("缺少背包保留物品，自定义处理器可显式接受")
	var f := _fixture()
	var other := Node2D.new()
	f.world.add_child(other)
	var drop: DroppedItem = f.generator.spawn_item(ItemInstance.create(_data()), Vector2.ZERO)
	var passed := assert_false(drop.try_pickup(other), "没有接收方不能消失")
	var received: Array = []
	drop.pickup_handler = func(candidate: DroppedItem, picker: Node2D) -> bool:
		received.append([candidate.item_instance.instance_id, picker])
		return true
	passed = assert_true(drop.try_pickup(other), "自定义接收方提交") and passed
	passed = assert_equal(received.size(), 1, "处理器调用一次") and passed
	passed = assert_false(drop.try_pickup(other), "不能重复提交") and passed
	f.world.free()
	end_test(passed)


func test_gold_and_duplicate_pickup() -> void:
	start_test("金币数量在成功通知中准确且不能重复入账")
	var f := _fixture()
	var amounts: Array = []
	f.generator.gold_picked_up.connect(func(amount, _picker): amounts.append(amount))
	var drop: DroppedItem = f.generator.spawn_gold(37, Vector2.ZERO)
	var passed := assert_true(drop.try_pickup(f.player), "金币拾取")
	passed = assert_false(drop.try_pickup(f.player), "重复金币拾取拒绝") and passed
	passed = assert_equal(f.inventory.get_gold(), 37, "金币入账一次") and passed
	passed = assert_equal(amounts, [37], "成功通知携带金额") and passed
	f.world.free()
	end_test(passed)


func test_reentrant_pickup() -> void:
	start_test("入包信号重入时不重复拾取")
	var f := _fixture()
	var drop: DroppedItem = f.generator.spawn_item(ItemInstance.create(_data(), 3), Vector2.ZERO)
	var nested: Array = []
	f.inventory.item_added.connect(func(_item, _slot): nested.append(drop.try_pickup(f.player)))
	var passed := assert_true(drop.try_pickup(f.player), "外层提交成功")
	passed = assert_equal(nested, [false], "重入被阻止") and passed
	passed = assert_equal(f.inventory.get_item_count("runtime_material"), 3, "只转移一次") and passed
	f.world.free()
	end_test(passed)


func test_pool_reuse_and_reset() -> void:
	start_test("拾取后复用相同池对象，状态目标透明度与计时器复位")
	var f := _fixture()
	var drop: DroppedItem = f.generator.spawn_item(ItemInstance.create(_data()), Vector2.ZERO)
	var id := drop.get_instance_id()
	drop._despawn_timer = 20.0
	drop._blink_timer = 3.0
	drop.sprite.modulate.a = 0.2
	drop.set_target_player(f.player)
	var passed := assert_true(drop.try_pickup(f.player), "完成拾取")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	passed = assert_true(is_instance_valid(drop), "归还对象池而非销毁") and passed
	if not is_instance_valid(drop):
		f.world.free()
		end_test(false)
		return
	passed = assert_equal(f.generator.get_all_drops().size(), 0, "空闲对象不计作掉落物") and passed
	passed = assert_null(drop.item_instance, "归还释放旧物品引用") and passed
	var reused: DroppedItem = f.generator.spawn_item(ItemInstance.create(_data("new_item")), Vector2(100, 20))
	passed = assert_equal(reused.get_instance_id(), id, "复用原节点") and passed
	passed = assert_equal(reused.current_state, DroppedItem.State.SPAWNING, "新的生成状态") and passed
	passed = assert_equal(reused._despawn_timer, 0.0, "消失计时复位") and passed
	passed = assert_equal(reused._blink_timer, 0.0, "闪烁计时复位") and passed
	passed = assert_null(reused._target_player, "不保留旧磁吸目标") and passed
	passed = assert_equal(reused.sprite.modulate.a, 1.0, "透明度恢复") and passed
	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	passed = assert_equal(f.generator.get_all_drops().size(), 1, "旧计时器不释放新掉落物") and passed
	f.world.free()
	end_test(passed)


func test_item_gold_reuse_visual() -> void:
	start_test("物品池转为金币不残留图标或物品数据")
	var f := _fixture()
	var data := _data()
	data.icon = GradientTexture2D.new()
	var drop: DroppedItem = f.generator.spawn_item(ItemInstance.create(data), Vector2.ZERO)
	var passed := assert_equal(drop.sprite.texture, data.icon, "先显示物品图标")
	f.generator.clear_all_drops()
	var gold: DroppedItem = f.generator.spawn_gold(15, Vector2.ZERO)
	passed = assert_equal(gold, drop, "同一通用场景池对象") and passed
	passed = assert_null(gold.item_instance, "不保留物品数据") and passed
	passed = assert_null(gold.sprite.texture, "恢复无图标的场景默认值") and passed
	passed = assert_equal(gold.gold_amount, 15, "金币数据正确") and passed
	f.world.free()
	end_test(passed)


func test_clear_isolated_and_cancel_timer() -> void:
	start_test("清场只清本生成器，池外对象销毁且旧拾取计时器取消")
	var f := _fixture()
	var other := _generator(f.world, 1, _scene())
	var drop: DroppedItem = f.generator.spawn_gold(1, Vector2.ZERO)
	var overflow: DroppedItem = f.generator.spawn_gold(2, Vector2.ZERO)
	var foreign: DroppedItem = other.spawn_gold(3, Vector2.ZERO)
	var passed := assert_equal(f.generator.get_all_drops().size(), 2, "池满后创建临时对象")
	drop.try_pickup(f.player)
	f.generator.clear_all_drops()
	var reused: DroppedItem = f.generator.spawn_gold(4, Vector2.ZERO)
	passed = assert_equal(reused, drop, "清场立即归还池对象") and passed
	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	passed = assert_true(is_instance_valid(reused), "旧回收计时器不误删复用对象") and passed
	passed = assert_false(is_instance_valid(overflow), "临时对象已销毁") and passed
	passed = assert_equal(f.generator.get_all_drops(), [reused], "仅新的自有对象") and passed
	passed = assert_equal(other.get_all_drops(), [foreign], "另一个生成器不受影响") and passed
	f.world.free()
	end_test(passed)


func test_externally_freed_pool_item() -> void:
	start_test("池对象外部释放后可安全补齐")
	var f := _fixture()
	var drop: DroppedItem = f.generator.spawn_gold(5, Vector2.ZERO)
	drop.free()
	var replacement: DroppedItem = f.generator.spawn_gold(6, Vector2.ZERO)
	var passed := assert_not_null(replacement, "池容量补齐")
	passed = assert_equal(f.generator.get_all_drops(), [replacement], "无失效对象引用") and passed
	passed = assert_true(replacement.try_pickup(f.player), "补齐对象可用") and passed
	passed = assert_equal(f.inventory.get_gold(), 6, "数据正确") and passed
	f.world.free()
	end_test(passed)


func test_generator_teardown() -> void:
	start_test("生成器销毁释放空闲池与外部活跃对象")
	var f := _fixture(2)
	var idle: DroppedItem = f.generator._item_pool[1]
	var active: DroppedItem = f.generator.spawn_gold(7, Vector2.ZERO)
	f.generator.free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var passed := assert_false(is_instance_valid(idle), "空闲池节点随父级释放")
	passed = assert_false(is_instance_valid(active), "外部活跃对象也释放") and passed
	f.world.free()
	end_test(passed)


func test_despawn_without_sprite() -> void:
	start_test("无精灵掉落物也能自然消失并回池")
	var f := _fixture(1, false)
	var drop: DroppedItem = f.generator.spawn_gold(8, Vector2.ZERO)
	drop.despawn()
	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	var passed := assert_equal(f.generator.get_all_drops().size(), 0, "结束生命周期")
	passed = assert_true(is_instance_valid(drop), "回收而非销毁") and passed
	passed = assert_equal(f.generator.spawn_gold(9, Vector2.ZERO), drop, "仍可复用") and passed
	f.world.free()
	end_test(passed)


func test_custom_gold_scene() -> void:
	start_test("专用金币场景不混用物品池")
	var f := _fixture()
	var gold_scene := _scene(false)
	f.generator.gold_drop_scene = gold_scene
	var drop: DroppedItem = f.generator.spawn_gold(10, Vector2.ZERO)
	var passed := assert_null(drop.sprite, "来自指定金币场景")
	passed = assert_false(drop in f.generator._item_pool, "专用金币实例不进入通用池") and passed
	passed = assert_true(drop.try_pickup(f.player), "金币可用") and passed
	f.world.free()
	end_test(passed)


func test_physics_pickup() -> void:
	start_test("真实物理碰撞进入拾取范围后提交一次")
	var f := _fixture()
	var body := CharacterBody2D.new()
	body.add_to_group("player")
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	f.world.add_child(body)
	f.inventory.reparent(body)
	body.global_position = Vector2(4000.0, 4000.0)
	var drop: DroppedItem = f.generator.spawn_gold(21, body.global_position)
	drop._velocity = Vector2.ZERO
	drop.spawn_speed = 0.0
	var tree := Engine.get_main_loop() as SceneTree
	for i in range(12):
		await tree.physics_frame
	var passed := assert_equal(f.inventory.get_gold(), 21, "物理碰撞触发金币转移一次")
	passed = assert_equal(drop.current_state, DroppedItem.State.PICKED_UP, "由实际 body_entered 进入拾取状态") and passed
	f.world.free()
	end_test(passed)
