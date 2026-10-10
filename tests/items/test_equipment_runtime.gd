extends TestFramework

class RefusingInventory extends InventoryManager:
	var reject: bool = false
	func add_item(item: ItemInstance, preferred_slot: int = -1) -> bool:
		return false if reject else super.add_item(item, preferred_slot)


func _init() -> void:
	super._init("装备转移与属性生命周期")


func run_all_tests() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	test_full_inventory_unequip()
	test_actual_add_rejection()
	test_swap_weight_rollback()
	test_level_failure_rollback()
	test_full_slot_swap_and_reentry()
	test_equipment_notification_after_commit()
	test_swap_returns_to_earlier_empty_slot()
	test_removal_observer_does_not_create_false_add()
	test_inventory_entry_and_direct_entry()
	test_missing_inventory()
	test_duplicate_ownership()
	test_shared_modifier_isolation()
	test_break_and_repair()
	test_equipping_broken_item()
	test_item_save_validation()
	test_inventory_restore_failure()
	test_inventory_restore_snapshot()
	test_equipment_restore_failure()
	test_equipment_restore_lifecycle()
	print_report()


func _fixture(refusing: bool = false) -> Dictionary:
	var actor := Node.new()
	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	var base := StatsData.new()
	base.strength = 0
	base.physical_damage = 0.0
	stats.base_stats = base
	actor.add_child(stats)
	var inventory: InventoryManager = RefusingInventory.new() if refusing else InventoryManager.new()
	inventory.slot_count = 1
	inventory.use_weight_limit = false
	actor.add_child(inventory)
	var equipment := EquipmentManager.new()
	equipment.stats_component = stats
	equipment.inventory = inventory
	inventory.equipment_manager = equipment
	actor.add_child(equipment)
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(actor)
	return {"actor": actor, "stats": stats, "inventory": inventory, "equipment": equipment}


func _item(id: String, bonus: float = 5.0, weight: float = 1.0) -> ItemInstance:
	var data := EquipmentData.new()
	data.id = id
	data.equip_slot = EquipmentData.EquipSlot.WEAPON_MAIN
	data.weight = weight
	var modifier := StatModifier.new()
	modifier.stat_type = StatModifier.StatType.PHYSICAL_DAMAGE
	modifier.value = bonus
	modifier.source_id = "template"
	data.stat_modifiers.append(modifier)
	return ItemInstance.create(data)


func _damage(f: Dictionary) -> float:
	return f.stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)


func test_full_inventory_unequip() -> void:
	start_test("满包卸装失败不丢装备、属性和套装计数")
	var f := _fixture()
	var item := _item("equipped")
	item.item_data.set_bonus_id = "set_a"
	f.equipment.equip(item)
	f.inventory.add_item(_item("blocker"))
	var events: Array = []
	f.equipment.equipment_unequipped.connect(func(_slot, _item): events.append(true))
	var passed := assert_false(f.equipment.unequip(item.item_data.equip_slot), "满包拒绝")
	passed = assert_equal(f.equipment.get_equipped(item.item_data.equip_slot), item, "装备仍在原槽") and passed
	passed = assert_equal(_damage(f), 5.0, "属性保留") and passed
	passed = assert_equal(f.equipment.get_set_piece_count("set_a"), 1, "套装数量保留") and passed
	passed = assert_equal(events.size(), 0, "失败不通知卸装") and passed
	f.actor.free()
	end_test(passed)


func test_actual_add_rejection() -> void:
	start_test("预检查有空间但实际入包拒绝时卸装不提交")
	var f := _fixture(true)
	var item := _item("equipped")
	f.equipment.equip(item)
	f.inventory.reject = true
	var passed := assert_true(f.inventory.has_space_for(item), "空间预检查通过")
	passed = assert_false(f.equipment.unequip(item.item_data.equip_slot), "实际拒绝应失败") and passed
	passed = assert_equal(f.equipment.get_equipped(item.item_data.equip_slot), item, "装备未丢失") and passed
	passed = assert_equal(_damage(f), 5.0, "属性未移除") and passed
	passed = assert_null(f.inventory.get_item(0), "未假装入包成功") and passed
	f.actor.free()
	end_test(passed)


func test_swap_weight_rollback() -> void:
	start_test("旧装备超重时换装失败，原格子恢复")
	var f := _fixture()
	var old := _item("old", 5.0, 10.0)
	var incoming := _item("new", 9.0, 1.0)
	f.equipment.equip(old)
	f.inventory.use_weight_limit = true
	f.inventory.max_weight = 5.0
	f.inventory.add_item(incoming)
	var events: Array = []
	f.inventory.item_removed.connect(func(_item, _slot): events.append("removed"))
	f.inventory.item_added.connect(func(_item, _slot): events.append("added"))
	var passed := assert_false(f.equipment.equip_from_inventory(0), "不能接收旧重装备")
	passed = assert_equal(f.inventory.get_item(0), incoming, "新装备恢复原格子") and passed
	passed = assert_equal(f.equipment.get_equipped(old.item_data.equip_slot), old, "旧装备未卸下") and passed
	passed = assert_equal(f.inventory.get_current_weight(), 1.0, "负重恢复") and passed
	passed = assert_equal(_damage(f), 5.0, "旧属性保留") and passed
	passed = assert_equal(events.size(), 0, "失败不暴露中间状态") and passed
	f.actor.free()
	end_test(passed)


func test_level_failure_rollback() -> void:
	start_test("等级不足且当前背包超重仍能原位回滚")
	var f := _fixture()
	var item := _item("locked")
	item.item_data.required_level = 999
	item.item_data.bind_on_equip = true
	f.inventory.add_item(item)
	f.inventory.use_weight_limit = true
	f.inventory.max_weight = 0.0
	var events: Array = []
	f.inventory.item_removed.connect(func(_item, _slot): events.append(true))
	var passed := assert_false(f.equipment.equip_from_inventory(0), "等级不足")
	passed = assert_equal(f.inventory.get_item(0), item, "回滚不经过负重检查") and passed
	passed = assert_false(item.is_bound, "失败不绑定") and passed
	passed = assert_equal(f.equipment.get_equipped_count(), 0, "没有新装备") and passed
	passed = assert_equal(events.size(), 0, "无虚假移除通知") and passed
	f.actor.free()
	end_test(passed)


func test_full_slot_swap_and_reentry() -> void:
	start_test("满格换装利用原格子并在提交后通知，阻止重入")
	var f := _fixture()
	var old := _item("old")
	var incoming := _item("new", 9.0)
	f.equipment.equip(old)
	f.inventory.add_item(incoming)
	var observations: Array = []
	var nested: Array = []
	f.inventory.item_removed.connect(func(_item, _slot):
		observations.append(f.equipment.get_equipped(incoming.item_data.equip_slot) == incoming))
	f.inventory.item_added.connect(func(_item, _slot):
		observations.append(f.inventory.get_item(0) == old)
		nested.append(f.equipment.equip_from_inventory(0)))
	var passed := assert_true(f.equipment.equip_from_inventory(0), "原格子容纳旧装备")
	passed = assert_equal(f.inventory.get_item(0), old, "旧装备入包") and passed
	passed = assert_equal(f.equipment.get_equipped(incoming.item_data.equip_slot), incoming, "新装备生效") and passed
	passed = assert_equal(_damage(f), 9.0, "仅保留新属性") and passed
	passed = assert_equal(observations, [true, true], "通知时状态已经提交") and passed
	passed = assert_equal(nested, [false], "重入不改变换装结果") and passed
	f.actor.free()
	end_test(passed)


func test_inventory_entry_and_direct_entry() -> void:
	start_test("背包与直接装备入口均转移所有权而非复制")
	var f := _fixture()
	var first := _item("first")
	f.inventory.add_item(first)
	var passed := assert_equal(f.inventory.equip_item(0), first, "背包入口")
	passed = assert_null(f.inventory.get_item(0), "从背包移出") and passed
	var second := _item("second", 7.0)
	f.inventory.add_item(second)
	passed = assert_false(f.equipment.equip(second, false), "禁用自动换装时保留原装备") and passed
	passed = assert_equal(f.inventory.get_item(0), second, "失败保留背包实例") and passed
	passed = assert_true(f.equipment.equip(second), "直接传入背包实例也走转移") and passed
	passed = assert_equal(f.inventory.get_item(0), first, "原装备回包") and passed
	passed = assert_equal(f.equipment.get_equipped(second.item_data.equip_slot), second, "新装备不同时留在背包") and passed
	passed = assert_equal(_damage(f), 7.0, "不重复加成") and passed
	f.actor.free()
	end_test(passed)


func test_missing_inventory() -> void:
	start_test("缺少背包默认卸装拒绝，显式脱离由调用者接管")
	var f := _fixture()
	var item := _item("equipped")
	f.equipment.inventory = null
	f.equipment.equip(item)
	var passed := assert_false(f.equipment.unequip(item.item_data.equip_slot), "无接收方不消失")
	passed = assert_equal(f.equipment.get_equipped(item.item_data.equip_slot), item, "仍持有装备") and passed
	passed = assert_true(f.equipment.unequip(item.item_data.equip_slot, false), "调用者显式接管") and passed
	passed = assert_equal(_damage(f), 0.0, "卸装移除加成") and passed
	f.actor.free()
	end_test(passed)


func test_duplicate_ownership() -> void:
	start_test("同一实例不能重复入包或重复装备")
	var f := _fixture()
	var item := _item("unique")
	f.inventory.add_item(item)
	var passed := assert_false(f.inventory.add_item(item), "重复入包拒绝")
	passed = assert_true(f.equipment.equip_from_inventory(0), "首次装备") and passed
	passed = assert_false(f.equipment.equip(item), "重复装备拒绝") and passed
	passed = assert_equal(_damage(f), 5.0, "属性只增加一次") and passed
	f.actor.free()
	end_test(passed)


func test_shared_modifier_isolation() -> void:
	start_test("共享装备资源的角色修正器独立，模板不被修改")
	var a := _fixture()
	var b := _fixture()
	var item := _item("shared")
	var other := ItemInstance.create(item.item_data)
	a.equipment.equip(item)
	b.equipment.equip(other)
	var template: StatModifier = item.item_data.stat_modifiers[0]
	var passed := assert_equal(template.source_id, "template", "未修改资源模板来源")
	passed = assert_not_equal(a.equipment.applied_modifiers[item.item_data.equip_slot][0],
		b.equipment.applied_modifiers[item.item_data.equip_slot][0], "角色运行时实例独立") and passed
	template.value = 99.0
	a.stats._mark_dirty()
	b.stats._mark_dirty()
	passed = assert_equal(_damage(a), 5.0, "运行时属性不受模板后续编辑影响") and passed
	passed = assert_equal(_damage(b), 5.0, "另一个角色仍独立") and passed
	a.equipment.unequip(item.item_data.equip_slot, false)
	passed = assert_equal(_damage(a), 0.0, "自身加成移除") and passed
	passed = assert_equal(_damage(b), 5.0, "另一角色加成保留") and passed
	a.actor.free()
	b.actor.free()
	end_test(passed)


func test_break_and_repair() -> void:
	start_test("损坏移除属性，修理恢复且重复修理不叠加")
	var f := _fixture()
	var item := _item("durable")
	item.item_data.has_durability = true
	item.item_data.max_durability = 10
	item.current_durability = 10
	f.equipment.equip(item)
	var observations: Array = []
	var nested: Array = []
	f.equipment.durability_changed.connect(func(_slot, _current, _maximum):
		observations.append(_damage(f))
		nested.append(f.equipment.repair_equipment(item.item_data.equip_slot)))
	f.equipment.consume_durability(item.item_data.equip_slot, 10)
	var passed := assert_equal(_damage(f), 0.0, "损坏后移除属性")
	passed = assert_equal(f.equipment.repair_equipment(item.item_data.equip_slot), 10, "修理数量") and passed
	passed = assert_equal(_damage(f), 5.0, "修理恢复加成") and passed
	f.equipment.repair_equipment(item.item_data.equip_slot)
	passed = assert_equal(_damage(f), 5.0, "重复修理不叠加") and passed
	passed = assert_equal(observations, [0.0, 5.0, 5.0], "耐久通知时属性已提交") and passed
	passed = assert_equal(nested, [0, 0, 0], "耐久通知重入修理被阻止") and passed
	f.equipment.unequip(item.item_data.equip_slot, false)
	passed = assert_equal(_damage(f), 0.0, "最终卸装无残留") and passed
	f.actor.free()
	end_test(passed)


func test_equipping_broken_item() -> void:
	start_test("已损坏装备不应用加成，修理后才生效")
	var f := _fixture()
	var item := _item("broken")
	item.item_data.has_durability = true
	item.current_durability = 0
	var passed := assert_true(f.equipment.equip(item), "允许保留损坏装备")
	passed = assert_equal(_damage(f), 0.0, "损坏属性不生效") and passed
	f.equipment.repair_equipment(item.item_data.equip_slot)
	passed = assert_equal(_damage(f), 5.0, "修好后应用一次") and passed
	f.actor.free()
	end_test(passed)


func test_swap_returns_to_earlier_empty_slot() -> void:
	start_test("旧装备返还较早空格时发出准确通知")
	var f := _fixture()
	f.inventory.slot_count = 2
	f.inventory.slots.resize(2)
	var old := _item("old")
	var incoming := _item("new", 8.0)
	f.equipment.equip(old)
	f.inventory.add_item(incoming, 1)
	var notifications: Array = []
	f.inventory.item_added.connect(func(item, slot): notifications.append([item, slot]))
	var passed := assert_true(f.equipment.equip_from_inventory(1), "换装成功")
	passed = assert_equal(f.inventory.get_item(0), old, "返回较早空格") and passed
	passed = assert_null(f.inventory.get_item(1), "原格子为空") and passed
	passed = assert_equal(notifications, [[old, 0]], "真实目标格通知一次") and passed
	f.actor.free()
	end_test(passed)


func test_removal_observer_does_not_create_false_add() -> void:
	start_test("移除观察者填入原格子时不伪报换装新增物品")
	var f := _fixture()
	var incoming := _item("new")
	var inserted := _item("observer_item")
	f.inventory.add_item(incoming)
	var notifications: Array = []
	f.inventory.item_added.connect(func(item, _slot): notifications.append(item))
	f.inventory.item_removed.connect(func(_item, _slot): f.inventory.add_item(inserted))
	var passed := assert_true(f.equipment.equip_from_inventory(0), "装备成功")
	passed = assert_equal(f.inventory.get_item(0), inserted, "观察者合法填入物品") and passed
	passed = assert_equal(notifications, [inserted], "仅观察者实际添加通知，无第二次伪报") and passed
	f.actor.free()
	end_test(passed)


func test_equipment_notification_after_commit() -> void:
	start_test("装备通知只观察提交状态，监听器入包通知不被屏蔽")
	var f := _fixture()
	f.inventory.slot_count = 3
	f.inventory.slots.resize(3)
	var old := _item("old")
	var incoming := _item("new", 8.0)
	var extra := _item("listener_item")
	f.equipment.equip(old)
	f.inventory.add_item(incoming)
	var observations: Array = []
	var additions: Array = []
	f.inventory.item_added.connect(func(item, _slot): additions.append(item))
	f.equipment.equipment_unequipped.connect(func(_slot, _item):
		observations.append(f.equipment.get_equipped(incoming.item_data.equip_slot) == incoming)
		f.inventory.add_item(extra))
	var passed := assert_true(f.equipment.equip_from_inventory(0), "换装成功")
	passed = assert_equal(observations, [true], "装备监听器看到最终状态") and passed
	passed = assert_equal(additions, [old, extra], "旧装备与监听器新增都正确通知") and passed
	passed = assert_false(f.inventory.is_blocking_signals(), "背包信号已恢复") and passed
	f.actor.free()
	end_test(passed)


func test_item_save_validation() -> void:
	start_test("物品解码校验与 JSON 往返")
	var item := _item("save_item")
	item.item_data.has_durability = true
	item.item_data.max_durability = 100
	item.current_durability = 42
	item.is_bound = true
	item.custom_data = {"nested": {"value": 7}}
	var mod := StatModifier.new()
	mod.stat_type = StatModifier.StatType.ARMOR
	mod.modifier_type = StatModifier.ModifierType.PERCENT
	mod.value = 0.25
	item.random_modifiers.append(mod)
	var database := {"save_item": item.item_data}
	var saved := item.to_dict()
	var json_data: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var restored := ItemInstance.from_dict(json_data, database)
	var passed := assert_not_null(restored, "JSON 存档恢复成功")
	if restored:
		passed = assert_equal(restored.current_durability, 42, "耐久保留") and passed
		passed = assert_equal(restored.instance_id, item.instance_id, "身份保留") and passed
		passed = assert_equal(restored.random_modifiers[0].value, 0.25, "词缀保留") and passed
		passed = assert_true(restored.is_bound, "绑定保留") and passed
	var invalid: Array = []
	for pair in [["item_id", "unknown"], ["stack_count", 0], ["stack_count", 2], ["stack_count", 1.5], ["instance_id", ""], ["is_bound", 1], ["custom_data", []], ["durability", -1], ["durability", 101], ["random_modifiers", {}]]:
		var bad := saved.duplicate(true)
		bad[pair[0]] = pair[1]
		invalid.append(bad)
	for pair in [["stat_type", 999], ["modifier_type", -1], ["value", INF], ["value", "bad"]]:
		var bad := saved.duplicate(true)
		bad.random_modifiers[0][pair[0]] = pair[1]
		invalid.append(bad)
	for bad in invalid:
		passed = assert_null(ItemInstance.from_dict(bad, database), "无效物品不静默修正") and passed
	passed = assert_null(ItemInstance.from_dict(saved, {"save_item": NodePath("bad")}), "数据库资源类型校验") and passed
	saved.custom_data.nested.value = 8
	passed = assert_equal(item.custom_data.nested.value, 7, "保存字典隔离") and passed
	var decoded := ItemInstance.from_dict(saved, database)
	saved.custom_data.nested.value = 9
	passed = assert_equal(decoded.custom_data.nested.value, 8, "恢复字典隔离") and passed
	end_test(passed)


func test_inventory_restore_failure() -> void:
	start_test("背包无效加载保持所有当前状态")
	var f := _fixture()
	var original := _item("original", 5, 3)
	f.inventory.add_item(original)
	f.inventory.gold = 11
	var saved: Dictionary = f.inventory.to_dict()
	var database := {"original": original.item_data}
	var invalid: Array = [{"slot_count": -1}, {"slot_count": 1e100}, {"gold": -1}, {"items": {}}, {"items": [null]}]
	var duplicate_slot := saved.duplicate(true)
	duplicate_slot.items.append(saved.items[0].duplicate(true))
	invalid.append(duplicate_slot)
	var duplicate_id := saved.duplicate(true)
	duplicate_id.slot_count = 2
	duplicate_id.items.append({"slot": 1, "item": original.to_dict()})
	invalid.append(duplicate_id)
	var bad_slot := saved.duplicate(true)
	bad_slot.items[0].slot = 1
	invalid.append(bad_slot)
	var bad_item := saved.duplicate(true)
	bad_item.items.append({"slot": 1, "item": {"item_id": "unknown"}})
	bad_item.slot_count = 2
	invalid.append(bad_item)
	var events: Array = []
	f.inventory.gold_changed.connect(func(_gold): events.append(true))
	f.inventory.inventory_restored.connect(func(): events.append(true))
	var passed := true
	for bad in invalid:
		passed = assert_false(f.inventory.from_dict(bad, database), "无效加载返回失败") and passed
		passed = assert_equal(f.inventory.get_item(0), original, "原物品保留") and passed
		passed = assert_equal(f.inventory.gold, 11, "金币保留") and passed
		passed = assert_equal(f.inventory.slot_count, 1, "容量保留") and passed
		passed = assert_equal(f.inventory.get_current_weight(), 3.0, "负重保留") and passed
	passed = assert_equal(events.size(), 0, "失败不发通知") and passed
	f.actor.free()
	end_test(passed)


func test_inventory_restore_snapshot() -> void:
	start_test("背包恢复保留位置重量与快照且不触发拾取")
	var f := _fixture()
	var item := _item("inventory_save", 5, 3)
	item.custom_data = {"nested": {"value": 1}}
	var saved := {"slot_count": 3, "gold": 42, "items": [{"slot": 2, "item": item.to_dict()}]}
	f.inventory.use_weight_limit = true
	f.inventory.max_weight = 1
	var notifications: Array = []
	var pickups: Array = []
	f.inventory.item_added.connect(func(_item, _slot): pickups.append(true))
	f.inventory.inventory_restored.connect(func(): notifications.append([f.inventory.gold, f.inventory.get_current_weight(), f.inventory.get_item(2).instance_id if f.inventory.get_item(2) else ""]))
	var database := {"inventory_save": item.item_data}
	var reentry: Array = []
	f.inventory.inventory_restored.connect(func(): reentry.append(f.inventory.from_dict(saved, database)))
	var passed := assert_true(f.inventory.from_dict(saved, database), "超重存档仍可恢复")
	passed = assert_true(f.inventory.from_dict(JSON.parse_string(JSON.stringify(saved)), database), "JSON 重复恢复") and passed
	passed = assert_equal(f.inventory.slot_count, 3, "恢复容量") and passed
	passed = assert_null(f.inventory.get_item(0), "保留空格") and passed
	passed = assert_equal(notifications.size(), 2, "每次恢复一次通知") and passed
	passed = assert_equal(notifications[0], [42, 3.0, item.instance_id], "通知看到提交状态") and passed
	passed = assert_equal(reentry, [false, false], "恢复回调拒绝嵌套加载") and passed
	passed = assert_equal(pickups.size(), 0, "恢复不触发拾取事件") and passed
	saved.items[0].item.custom_data.nested.value = 2
	passed = assert_equal(f.inventory.get_item(2).custom_data.nested.value, 1, "调用者数据隔离") and passed
	passed = assert_true(f.inventory.from_dict({"items": [], "slot_count": 3}, database), "空存档恢复") and passed
	passed = assert_equal(f.inventory.get_current_weight(), 0.0, "空存档清理重量") and passed
	f.actor.free()
	end_test(passed)


func test_equipment_restore_failure() -> void:
	start_test("装备恢复拒绝错槽与损坏数据并保留属性")
	var f := _fixture()
	var item := _item("equipment_save")
	f.equipment.equip(item)
	var database := {"equipment_save": item.item_data}
	var invalid: Array = [{"equipped": []}, {"equipped": {"UNKNOWN": item.to_dict()}}, {"equipped": {"HELMET": item.to_dict()}}, {"equipped": {"WEAPON_MAIN": null}}, {"equipped": {"WEAPON_MAIN": {"item_id": "missing"}}}]
	var bad: Dictionary = f.equipment.to_dict()
	bad.equipped.HELMET = {"item_id": "missing"}
	invalid.append(bad)
	var events: Array = []
	f.equipment.equipment_restored.connect(func(): events.append(true))
	var passed := true
	for saved in invalid:
		passed = assert_false(f.equipment.from_dict(saved, database), "无效恢复失败") and passed
		passed = assert_equal(f.equipment.get_equipped(item.item_data.equip_slot), item, "旧实例保持") and passed
		passed = assert_equal(_damage(f), 5.0, "属性不变") and passed
	passed = assert_equal(events.size(), 0, "失败没有恢复事件") and passed
	f.actor.free()
	end_test(passed)


func test_equipment_restore_lifecycle() -> void:
	start_test("反复恢复重建属性和套装且通知只看到最终状态")
	var f := _fixture()
	var item := _item("restore", 7)
	item.item_data.set_bonus_id = "real_set"
	item.item_data.required_level = 99
	item.item_data.bind_on_equip = true
	item.item_data.has_durability = true
	item.item_data.max_durability = 100
	item.current_durability = 50
	var extra := StatModifier.new()
	extra.stat_type = StatModifier.StatType.PHYSICAL_DAMAGE
	extra.value = 2
	f.stats.add_modifier(extra)
	var saved := {"equipped": {"WEAPON_MAIN": item.to_dict()}, "set_pieces": {"forged_set": 100}}
	var database := {"restore": item.item_data}
	var gameplay: Array = []
	var observed: Array = []
	var reentry: Array = []
	f.equipment.equipment_equipped.connect(func(_slot, _item): gameplay.append(true))
	f.equipment.equipment_unequipped.connect(func(_slot, _item): gameplay.append(true))
	f.equipment.set_bonus_activated.connect(func(_id, _count): gameplay.append(true))
	f.stats.modifiers_changed.connect(func(): observed.append(_damage(f)))
	f.equipment.equipment_restored.connect(func(): reentry.append(f.equipment.from_dict(saved, database)))
	var passed := assert_true(f.equipment.from_dict(saved, database), "恢复不执行等级检查")
	passed = assert_true(f.equipment.from_dict(JSON.parse_string(JSON.stringify(saved)), database), "重复 JSON 恢复") and passed
	passed = assert_equal(_damage(f), 9.0, "重复恢复属性不叠加且保留其他来源") and passed
	passed = assert_equal(observed, [9.0, 9.0], "属性通知只看到最终加成") and passed
	passed = assert_equal(reentry, [false, false], "恢复通知拒绝重入") and passed
	passed = assert_equal(gameplay.size(), 0, "恢复不触发装备和套装玩法事件") and passed
	passed = assert_equal(f.equipment.get_set_piece_count("real_set"), 1, "重算真实套装") and passed
	passed = assert_equal(f.equipment.get_set_piece_count("forged_set"), 0, "忽略伪造派生计数") and passed
	passed = assert_false(f.equipment.get_equipped(item.item_data.equip_slot).is_bound, "恢复不重新绑定") and passed
	var snapshot: Dictionary = f.equipment.to_dict()
	snapshot.set_pieces.real_set = 100
	passed = assert_equal(f.equipment.get_set_piece_count("real_set"), 1, "套装快照隔离") and passed
	saved.equipped.WEAPON_MAIN.durability = 0
	passed = assert_true(f.equipment.from_dict(saved, database), "损坏装备恢复") and passed
	passed = assert_equal(_damage(f), 2.0, "损坏装备不提供属性") and passed
	passed = assert_true(f.equipment.from_dict({"equipped": {}}, database), "空装备恢复") and passed
	passed = assert_equal(_damage(f), 2.0, "清场保留其他修正器") and passed
	passed = assert_true(f.equipment.set_pieces.is_empty(), "清场移除套装计数") and passed
	f.actor.free()
	end_test(passed)
