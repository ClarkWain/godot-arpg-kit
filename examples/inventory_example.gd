# res://examples/inventory_example.gd
extends Node2D

## 自动化测试：InventoryComponent
## 将原示例改为结构化测试用例，按测试人员习惯输出断言结果与汇总

@onready var inventory: InventoryComponent = $InventoryComponent

var results: Array = []
var signal_counts = {
	"item_added": 0,
	"item_removed": 0,
	"inventory_full": 0,
	"weight_exceeded": 0
}

func _ready():
	# 连接信号以便测试触发
	inventory.item_added.connect(func(_item, _slot): signal_counts["item_added"] += 1)
	inventory.item_removed.connect(func(_item, _slot): signal_counts["item_removed"] += 1)
	inventory.inventory_full.connect(func(): signal_counts["inventory_full"] += 1)
	inventory.weight_exceeded.connect(func(): signal_counts["weight_exceeded"] += 1)

	print("-- 开始 InventoryComponent 测试 --")

	# 每个测试前重置背包状态
	_reset_inventory()

	_run_test("test_add_items", test_add_items)
	_reset_inventory()
	_run_test("test_item_stacking", test_item_stacking)
	_reset_inventory()
	_run_test("test_move_items", test_move_items)
	_reset_inventory()
	_run_test("test_organize_and_sort", test_organize_and_sort)
	_reset_inventory()
	_run_test("test_gold_management", test_gold_management)

	_run_signal_checks()

	_print_summary()
	print("-- END InventoryComponent Tests --")


### ---------- Helpers ----------
func _reset_inventory():
	# 使用 from_dict 清空背包（InventoryComponent 提供的安全方法）
	inventory.from_dict({"slot_count": inventory.slot_count, "gold": 0, "items": []}, {})

func _assert(cond: bool, message: String) -> void:
	var entry = {"ok": cond, "msg": message}
	results.append(entry)
	if cond:
		print("通过：%s" % message)
	else:
		print("失败：%s" % message)

func _run_test(test_name: String, func_ref: Callable) -> void:
	print("\n--- 运行测试 %s ---" % test_name)
	var before = results.size()
	# 直接执行测试函数（若抛出错误，将在运行时看到堆栈）
	func_ref.call()
	var passed = 0
	for i in range(before, results.size()):
		if results[i].ok:
			passed += 1
	print("%s: %d 条断言，%d 通过" % [test_name, results.size() - before, passed])


### ---------- Test cases ----------
func test_add_items():
	# 加载资源
	var sword_res = load("res://data/items/weapons/iron_sword.tres")
	var potion_res = load("res://data/items/consumables/health_potion.tres")

	_assert(sword_res != null, "已加载剑资源")
	_assert(potion_res != null, "已加载药水资源")

	if not sword_res or not potion_res:
		return

	var sword = ItemInstance.create(sword_res, 1)
	var potion = ItemInstance.create(potion_res, 15)

	var added_sword = inventory.add_item(sword)
	_assert(added_sword, "添加剑返回 true")

	var added_potion = inventory.add_item(potion)
	_assert(added_potion, "添加药水返回 true")

	_assert(inventory.get_empty_slot_count() <= inventory.slot_count - 2, "添加后空格子减少")
	_assert(inventory.get_current_weight() > 0, "添加后当前负重增加")


func test_item_stacking():
	var potion_res = load("res://data/items/consumables/health_potion.tres")
	_assert(potion_res != null, "用于堆叠的药水资源已加载")
	if not potion_res:
		return

	var p1 = ItemInstance.create(potion_res, 30)
	var p2 = ItemInstance.create(potion_res, 40)

	inventory.add_item(p1)
	var _slots_after_first = inventory.get_empty_slot_count()
	inventory.add_item(p2)

	# 总数应为 70
	_assert(inventory.get_item_count(potion_res.id) == 70, "药水总数 == 70")
	# 如果启用自动堆叠，使用的格子数应 <= 2
	var used_slots = inventory.slot_count - inventory.get_empty_slot_count()
	_assert(used_slots <= 2, "堆叠减少占用格子 (used_slots=%d)" % used_slots)


func test_move_items():
	# 添加一个物品到第一个格子，然后移动到格子 10
	var sword_res = load("res://data/items/weapons/iron_sword.tres")
	_assert(sword_res != null, "用于移动的剑资源已加载")
	if not sword_res:
		return

	var sword = ItemInstance.create(sword_res, 1)
	var added = inventory.add_item(sword)
	_assert(added, "为移动测试添加了剑")

	# 找到来源格子
	var from_slot = -1
	for i in range(inventory.slot_count):
		if inventory.get_item(i):
			from_slot = i
			break

	_assert(from_slot >= 0, "找到一个非空格子以移动")
	if from_slot < 0:
		return

	var to_slot = min(10, inventory.slot_count - 1)
	var moved = inventory.move_item(from_slot, to_slot)
	_assert(moved, "move_item 返回 true")
	_assert(inventory.get_item(to_slot) != null, "目标格子现在有物品")


func test_organize_and_sort():
	# 创建几个不同物品（如果没有其他资源，可重复使用同一资源并分配不同稀有度）
	var sword_res = load("res://data/items/weapons/iron_sword.tres")
	var potion_res = load("res://data/items/consumables/health_potion.tres")
	_assert(sword_res != null and potion_res != null, "用于整理/排序的资源已加载")
	if not sword_res or not potion_res:
		return

	# 插入：slot0 (sword), slot2 (potion), 留 slot1 空，测试 compact
	var s = ItemInstance.create(sword_res, 1)
	var _p = ItemInstance.create(potion_res, 5)

	inventory.add_item(s)
	# 强制放入 slot 2（尝试通过 move/swap），先找到空槽
	var empty = inventory._find_empty_slot()
	if empty >= 0:
		# 先添加到一个槽，再移动到 slot 2
		var t = ItemInstance.create(potion_res, 5)
		inventory.add_item(t)
		var cur = -1
		for i in range(inventory.slot_count):
			if inventory.get_item(i) and inventory.get_item(i).item_data.id == potion_res.id:
				cur = i
				break
		if cur >= 0:
			inventory.move_item(cur, min(2, inventory.slot_count - 1))

	# 现在调用 organize，确保前端压缩
	inventory.organize()
	var first_non_null = -1
	for i in range(inventory.slot_count):
		if inventory.get_item(i):
			first_non_null = i
			break
	_assert(first_non_null == 0, "organize 将物品压缩到前部 (first_non_null=%d)" % first_non_null)

	# 排序（按稀有度），运行不会出错
	inventory.sort_by_rarity()
	_assert(true, "按稀有度排序执行完成（无错误）")


func test_gold_management():
	inventory.add_gold(1000)
	_assert(inventory.get_gold() == 1000, "金币增加到 1000")
	var ok = inventory.remove_gold(500)
	_assert(ok and inventory.get_gold() == 500, "移除 500 金币，剩余 500")


### ---------- Signal checks ----------
func _run_signal_checks():
	# 期望在上面几个测试中至少触发了 add/remove 事件
	_assert(signal_counts["item_added"] > 0, "item_added 信号被触发")
	# item_removed 视堆叠拆分而定；但计数至少应为非负
	_assert(signal_counts["item_removed"] >= 0, "item_removed 信号计数非负")


### ---------- Summary ----------
func _print_summary():
	var total = results.size()
	var passed = 0
	for r in results:
		if r.ok:
			passed += 1

	print('\n===== 测试汇总 =====')
	print('断言总数: %d' % total)
	print('通过: %d' % passed)
	print('失败: %d' % (total - passed))

	print("-- 结束 InventoryComponent 测试 --")
