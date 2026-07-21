## 高优先级 BUG 修复的回归测试
##
## 覆盖：
##   1. 消耗品 use_item 实际应用效果（旧版只发信号 + 减数量，不真回血）
##   2. CombatEventBus / QuestEventBus 已被 autoload，可全局访问
##
## 护甲穿透字段的回归测试已直接加强在 test_damage_calculator.test_armor_penetration()。
extends TestFramework

func _init() -> void:
	super._init("高优先级 BUG 回归测试")


func run_all_tests() -> void:
	test_consumable_instant_heal_applied()
	test_consumable_instant_mana_applied()
	test_consumable_buff_adds_modifier()
	test_use_item_without_stats_still_consumes()
	test_combat_event_bus_autoloaded()
	test_quest_event_bus_autoloaded()
	test_event_buses_receive_and_dispatch()
	# 中优先级修复回归
	test_knockback_force_is_scalar()
	test_knockback_multiplies_direction_correctly()
	test_equip_item_transactional_success()
	test_equip_item_transactional_rollback_on_fail()

	print_report()


# ---------------------------------------------------------------------------
# 辅助：构造一个"角色实体（Node + StatsComponent + InventoryManager）"
# ---------------------------------------------------------------------------
func _build_actor(max_health: float = 100.0, max_mana: float = 50.0) -> Dictionary:
	var actor := Node.new()

	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	var base := StatsData.new()
	base.strength = 0
	base.agility = 0
	base.intelligence = 0
	base.vitality = 0
	base.luck = 0
	base.max_health = max_health
	base.max_mana = max_mana
	base.armor = 0.0
	base.dodge_chance = 0.0
	base.health_regen = 0.0     # 关闭自动回复，避免干扰测试断言
	base.mana_regen = 0.0
	base.stamina_regen = 0.0
	stats.base_stats = base
	actor.add_child(stats)
	stats._ready()

	var inv := InventoryManager.new()
	inv.name = "InventoryManager"
	inv.slot_count = 8
	inv.use_weight_limit = false
	actor.add_child(inv)
	inv._ready()

	return {"actor": actor, "stats": stats, "inv": inv}


## 造一个 INSTANT_HEAL 消耗品的 ItemInstance
func _make_potion(effect_type: int, value: float,
		temp_mods: Array[StatModifier] = [],
		duration: float = 0.0) -> ItemInstance:
	var data := ConsumableData.new()
	data.id = "test_potion_%d" % Time.get_ticks_usec()
	data.item_name = "Test Potion"
	data.effect_type = effect_type
	data.effect_value = value
	data.effect_duration = duration
	data.temp_modifiers = temp_mods
	return ItemInstance.create(data, 1)


# ---------------------------------------------------------------------------
# 1. 消耗品：INSTANT_HEAL
# ---------------------------------------------------------------------------
func test_consumable_instant_heal_applied() -> void:
	start_test("消耗品 INSTANT_HEAL 应真正回血")

	var a = _build_actor(200.0)
	var stats: StatsComponent = a.stats
	var inv: InventoryManager = a.inv

	# 先把血打掉一半
	stats.current_health = 100.0

	var potion := _make_potion(ConsumableData.EffectType.INSTANT_HEAL, 40.0)
	inv.add_item(potion)

	var slot := 0
	# 找到刚放进去的位置
	for i in range(inv.slot_count):
		if inv.get_item(i) != null:
			slot = i
			break

	var ok := inv.use_item(slot)   # 不传 target，走默认（get_parent()）
	var passed := assert_true(ok, "use_item 应返回 true")
	passed = assert_almost_equal(stats.current_health, 140.0, 0.1,
		"喝药后应回血 40（100 -> 140）") and passed
	passed = assert_null(inv.get_item(slot),
		"堆叠 1 的消耗品用完后应被移除") and passed

	a.actor.free()
	end_test(passed)


# ---------------------------------------------------------------------------
# 2. 消耗品：INSTANT_MANA
# ---------------------------------------------------------------------------
func test_consumable_instant_mana_applied() -> void:
	start_test("消耗品 INSTANT_MANA 应真正回蓝")

	var a = _build_actor(100.0, 80.0)
	var stats: StatsComponent = a.stats
	var inv: InventoryManager = a.inv

	stats.current_mana = 10.0

	var potion := _make_potion(ConsumableData.EffectType.INSTANT_MANA, 25.0)
	inv.add_item(potion)

	var passed := assert_true(inv.use_item(0), "use_item 应返回 true")
	passed = assert_almost_equal(stats.current_mana, 35.0, 0.1,
		"喝魔法药水应回蓝 25（10 -> 35）") and passed

	a.actor.free()
	end_test(passed)


# ---------------------------------------------------------------------------
# 3. 消耗品：BUFF 应用临时修正器
# ---------------------------------------------------------------------------
func test_consumable_buff_adds_modifier() -> void:
	start_test("消耗品 BUFF 应把 temp_modifiers 挂到 stats")

	var a = _build_actor()
	var stats: StatsComponent = a.stats
	var inv: InventoryManager = a.inv

	# 打造一个 +30 物理攻击、持续 10 秒的 buff 药
	var mod_template := StatModifier.new()
	mod_template.stat_type = StatModifier.StatType.PHYSICAL_DAMAGE
	mod_template.modifier_type = StatModifier.ModifierType.FLAT
	mod_template.value = 30.0
	mod_template.source_id = "test_buff_potion"
	# duration 由 InventoryManager 在 apply 时基于 effect_duration 覆写

	var mods: Array[StatModifier] = [mod_template]
	var potion := _make_potion(ConsumableData.EffectType.BUFF, 0.0, mods, 10.0)
	inv.add_item(potion)

	var baseline: float = stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)
	var ok := inv.use_item(0)
	var after: float = stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)

	var passed := assert_true(ok, "use_item 应返回 true")
	passed = assert_almost_equal(after - baseline, 30.0, 0.1,
		"buff 应让 PHYSICAL_DAMAGE 增加 30") and passed

	a.actor.free()
	end_test(passed)


# ---------------------------------------------------------------------------
# 4. 缺少 StatsComponent 时 use_item 仍消耗物品（保留旧语义）
# ---------------------------------------------------------------------------
func test_use_item_without_stats_still_consumes() -> void:
	start_test("目标无 StatsComponent 时 use_item 仍应消耗物品")

	var actor := Node.new()
	var inv := InventoryManager.new()
	inv.name = "InventoryManager"
	inv.slot_count = 4
	inv.use_weight_limit = false
	actor.add_child(inv)
	inv._ready()

	var potion := _make_potion(ConsumableData.EffectType.INSTANT_HEAL, 50.0)
	inv.add_item(potion)

	var ok := inv.use_item(0)
	var passed := assert_true(ok, "即使目标没有 StatsComponent，use_item 也应返回 true")
	passed = assert_null(inv.get_item(0),
		"物品应被消耗（这保留了旧行为的语义）") and passed

	actor.free()
	end_test(passed)


# ---------------------------------------------------------------------------
# 5. CombatEventBus 已被 autoload 到 /root/CombatEventBus
# ---------------------------------------------------------------------------
func test_combat_event_bus_autoloaded() -> void:
	start_test("CombatEventBus autoload 已生效")

	var tree = Engine.get_main_loop() as SceneTree
	var passed := assert_not_null(tree, "应能拿到 SceneTree")

	if tree:
		var node = tree.root.get_node_or_null("CombatEventBus")
		passed = assert_not_null(node,
			"/root/CombatEventBus 应存在") and passed
		passed = assert_not_null(CombatEventBusScript.instance,
			"CombatEventBus 的 static instance 应被 _ready() 自动赋值") and passed
		if node and CombatEventBusScript.instance:
			passed = assert_equal(CombatEventBusScript.instance, node,
				"static instance 应等于 autoload 节点自身") and passed
	end_test(passed)


# ---------------------------------------------------------------------------
# 6. QuestEventBus 已被 autoload
# ---------------------------------------------------------------------------
func test_quest_event_bus_autoloaded() -> void:
	start_test("QuestEventBus autoload 已生效")

	var tree = Engine.get_main_loop() as SceneTree
	var passed := assert_not_null(tree, "应能拿到 SceneTree")

	if tree:
		var node = tree.root.get_node_or_null("QuestEventBus")
		passed = assert_not_null(node,
			"/root/QuestEventBus 应存在") and passed
		passed = assert_not_null(QuestEventBusScript.instance,
			"QuestEventBus 的 static instance 应被 _ready() 自动赋值") and passed
	end_test(passed)


# ---------------------------------------------------------------------------
# 7. autoload 后事件总线可以正常派发（不再静默丢事件）
# ---------------------------------------------------------------------------
func test_event_buses_receive_and_dispatch() -> void:
	start_test("事件总线接入 autoload 后可派发事件")

	var tree = Engine.get_main_loop() as SceneTree
	var passed := assert_not_null(tree, "应能拿到 SceneTree")
	if not tree:
		end_test(passed)
		return

	var combat_bus = tree.root.get_node_or_null("CombatEventBus")
	passed = assert_not_null(combat_bus, "CombatEventBus 节点应存在") and passed
	if combat_bus == null:
		end_test(passed)
		return

	# 订阅 damage_dealt 信号
	var received := {"count": 0, "damage": 0.0}
	var handler := func(_src: Node, _tgt: Node, info):
		received.count += 1
		if info:
			received.damage = info.final_damage
	combat_bus.damage_dealt.connect(handler)

	# 直接触发一个 damage_dealt 事件（模拟战斗组件上报）
	var info := DamageInfo.new(null, null, 42.0, DamageInfo.DamageType.PHYSICAL)
	info.final_damage = 42.0
	combat_bus.damage_dealt.emit(null, null, info)

	passed = assert_equal(received.count, 1,
		"connect 到 autoload 的信号应能收到一次") and passed
	passed = assert_almost_equal(received.damage, 42.0, 0.001,
		"事件负载应完整传递") and passed

	combat_bus.damage_dealt.disconnect(handler)
	end_test(passed)


# ---------------------------------------------------------------------------
# 引用 EventBus 脚本类本身（用于访问 static instance）
# 由于 CombatEventBus / QuestEventBus 现在同时是 autoload 名，直接写
# CombatEventBus.instance 也可以（autoload 节点上有 static instance），
# 但显式 preload 更清晰、也避免个别 shadow 场景。
# ---------------------------------------------------------------------------
const CombatEventBusScript = preload("res://scripts/combat/combat_event_bus.gd")
const QuestEventBusScript = preload("res://scripts/quest/quest_event_bus.gd")


# ---------------------------------------------------------------------------
# 8. 击退力度：DamageInfo.knockback_force 现在是标量
# ---------------------------------------------------------------------------
func test_knockback_force_is_scalar() -> void:
	start_test("DamageInfo.knockback_force 应为标量 float")
	var info := DamageInfo.new()
	# 直接赋值 float 不应触发类型错误
	info.knockback_force = 250.0
	var passed := assert_true(typeof(info.knockback_force) == TYPE_FLOAT,
		"knockback_force 类型应为 TYPE_FLOAT")
	passed = assert_almost_equal(info.knockback_force, 250.0, 0.001,
		"knockback_force 应正确保存标量值") and passed
	end_test(passed)


## 一个能捕获 apply_knockback 参数的假实体
class _KnockbackDummy extends Node2D:
	var last_knockback: Vector2 = Vector2.ZERO
	func apply_knockback(vec: Vector2) -> void:
		last_knockback = vec


# ---------------------------------------------------------------------------
# 9. 击退：force × direction 应得到"力度沿方向"的完整向量
#     (而不是旧的 Vector2 分量乘积把方向压到 x 轴)
# ---------------------------------------------------------------------------
func test_knockback_multiplies_direction_correctly() -> void:
	start_test("击退：force × direction 语义正确")
	
	# 造一个 Node2D 目标 + 假 StatsComponent + CombatComponent
	var target := _KnockbackDummy.new()
	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	var base := StatsData.new()
	base.strength = 0
	base.agility = 0
	base.intelligence = 0
	base.vitality = 0
	base.luck = 0
	base.max_health = 200.0
	base.armor = 0.0
	base.dodge_chance = 0.0
	stats.base_stats = base
	target.add_child(stats)
	stats._ready()
	
	var combat := CombatComponent.new()
	combat.name = "CombatComponent"
	combat.entity = target
	combat.stats_component = stats
	target.add_child(combat)
	combat._ready()
	
	# 构造 damage_info：force=100，方向为 45° 单位向量 (0.707, 0.707)
	var info := DamageInfo.new(null, target, 30.0, DamageInfo.DamageType.PHYSICAL)
	info.final_damage = 30.0
	info.knockback_force = 100.0
	info.knockback_direction = Vector2(1, 1).normalized()   # (0.7071, 0.7071)
	
	combat.receive_damage(info)
	
	# 期望：apply_knockback 收到 100 * (0.7071, 0.7071) ≈ (70.71, 70.71)
	var expected := 100.0 * Vector2(1, 1).normalized()
	var passed := assert_almost_equal(target.last_knockback.x, expected.x, 0.1,
		"击退 X 分量应等于 force * direction.x（旧实现会被压到 100.0）")
	passed = assert_almost_equal(target.last_knockback.y, expected.y, 0.1,
		"击退 Y 分量应等于 force * direction.y（旧实现会得到 0，垂直方向失效）") and passed
	
	target.free()
	end_test(passed)


# ---------------------------------------------------------------------------
# 一个最小 EquipmentManager 桩：仅提供 equip(item) 接口
# ---------------------------------------------------------------------------
class _EquipStub extends Node:
	var accept: bool = true
	var equipped: Array = []
	func equip(item) -> bool:
		if not accept:
			return false
		equipped.append(item)
		return true


# ---------------------------------------------------------------------------
# 10. equip_item 事务性：成功路径
# ---------------------------------------------------------------------------
func test_equip_item_transactional_success() -> void:
	start_test("equip_item 事务：装备成功物品应从背包移除")
	
	var inv := InventoryManager.new()
	inv.slot_count = 4
	inv.use_weight_limit = false
	
	var stub := _EquipStub.new()
	stub.accept = true
	inv.equipment_manager = stub
	
	# 放一个假装是装备的物品：只要 item_data 是 EquipmentData
	var equip_data := EquipmentData.new()
	equip_data.id = "test_sword"
	equip_data.item_name = "Test Sword"
	var item := ItemInstance.create(equip_data, 1)
	
	# 添加到场景以便触发 _ready
	var host := Node.new()
	host.add_child(inv)
	host.add_child(stub)
	inv._ready()
	
	inv.add_item(item)
	var slot := 0
	for i in range(inv.slot_count):
		if inv.get_item(i) != null:
			slot = i
			break
	
	var returned = inv.equip_item(slot)
	var passed := assert_not_null(returned, "equip_item 应返回被装备的物品")
	passed = assert_null(inv.get_item(slot),
		"成功装备后原格子应变空") and passed
	passed = assert_equal(stub.equipped.size(), 1,
		"EquipmentManager.equip 应被调用一次") and passed
	
	host.free()
	end_test(passed)


# ---------------------------------------------------------------------------
# 11. equip_item 事务性：失败时物品回滚到背包
# ---------------------------------------------------------------------------
func test_equip_item_transactional_rollback_on_fail() -> void:
	start_test("equip_item 事务：装备失败时物品应归还背包")
	
	var inv := InventoryManager.new()
	inv.slot_count = 4
	inv.use_weight_limit = false
	
	var stub := _EquipStub.new()
	stub.accept = false   # 装备总是失败
	inv.equipment_manager = stub
	
	var equip_data := EquipmentData.new()
	equip_data.id = "test_shield"
	equip_data.item_name = "Test Shield"
	var item := ItemInstance.create(equip_data, 1)
	
	var host := Node.new()
	host.add_child(inv)
	host.add_child(stub)
	inv._ready()
	
	inv.add_item(item)
	var slot := 0
	for i in range(inv.slot_count):
		if inv.get_item(i) != null:
			slot = i
			break
	
	var returned = inv.equip_item(slot)
	var passed := assert_null(returned, "装备失败时 equip_item 应返回 null")
	# 物品应仍在背包（可能在原格子或其他格子）
	var still_in_bag := false
	for i in range(inv.slot_count):
		var it: ItemInstance = inv.get_item(i)
		if it and it.item_data.id == "test_shield":
			still_in_bag = true
			break
	passed = assert_true(still_in_bag,
		"装备失败时物品应回滚到背包（不允许丢失）") and passed
	
	host.free()
	end_test(passed)
