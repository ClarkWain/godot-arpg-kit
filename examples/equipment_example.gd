# res://examples/equipment_example.gd
extends Node2D
## 装备管理器使用示例

@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var stats: StatsComponent = $StatsComponent
@onready var inventory: InventoryComponent = $InventoryComponent


func _ready():
	# 连接信号
	equipment_manager.equipment_equipped.connect(_on_equipment_equipped)
	equipment_manager.equipment_unequipped.connect(_on_equipment_unequipped)
	equipment_manager.set_bonus_activated.connect(_on_set_bonus_activated)
	equipment_manager.durability_changed.connect(_on_durability_changed)
	
	print("========== 装备管理器示例 ==========\n")
	
	# 示例 1: 装备武器
	example_equip_weapon()
	
	# 示例 2: 装备护甲
	example_equip_armor()
	
	# 示例 3: 查看装备状态
	example_view_equipment()
	
	# 示例 4: 套装系统
	example_set_bonus()
	
	# 示例 5: 耐久度系统
	example_durability()


## 示例 1: 装备武器
func example_equip_weapon():
	print("========== 示例 1: 装备武器 ==========")
	
	var sword = load("res://data/items/weapons/iron_sword.tres") as WeaponData
	if sword:
		var sword_instance = ItemInstance.create(sword, 1)
		
		print("装备前物理攻击: %.0f" % stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE))
		
		if equipment_manager.equip(sword_instance):
			print("成功装备: %s" % sword.item_name)
			print("装备后物理攻击: %.0f" % stats.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE))
		
		print()


## 示例 2: 装备护甲
func example_equip_armor():
	print("========== 示例 2: 装备护甲 ==========")
	
	# 这里需要先创建护甲数据文件
	# 暂时用代码创建示例护甲
	var helmet = EquipmentData.new()
	helmet.id = "iron_helmet"
	helmet.item_name = "铁头盔"
	helmet.equip_slot = EquipmentData.EquipSlot.HELMET
	helmet.required_level = 1
	helmet.rarity = ItemData.Rarity.COMMON
	
	# 添加属性加成
	var armor_mod = StatModifier.create_flat(StatModifier.StatType.ARMOR, 15.0, "iron_helmet")
	var hp_mod = StatModifier.create_flat(StatModifier.StatType.MAX_HEALTH, 50.0, "iron_helmet")
	helmet.stat_modifiers.clear()
	helmet.stat_modifiers.append(armor_mod)
	helmet.stat_modifiers.append(hp_mod)
	
	var helmet_instance = ItemInstance.create(helmet, 1)
	
	print("装备前护甲: %.0f" % stats.get_stat(StatModifier.StatType.ARMOR))
	print("装备前生命: %.0f" % stats.get_stat(StatModifier.StatType.MAX_HEALTH))
	
	if equipment_manager.equip(helmet_instance):
		print("成功装备: %s" % helmet.item_name)
		print("装备后护甲: %.0f" % stats.get_stat(StatModifier.StatType.ARMOR))
		print("装备后生命: %.0f" % stats.get_stat(StatModifier.StatType.MAX_HEALTH))
	
	print()


## 示例 3: 查看装备状态
func example_view_equipment():
	print("========== 示例 3: 查看装备状态 ==========")
	
	equipment_manager.print_equipment_status()
	
	print("已装备物品数量: %d" % equipment_manager.get_equipped_count())
	print()


## 示例 4: 套装系统
func example_set_bonus():
	print("========== 示例 4: 套装系统 ==========")
	
	# 创建套装装备
	var chest = EquipmentData.new()
	chest.id = "dragon_chest"
	chest.item_name = "龙鳞胸甲"
	chest.equip_slot = EquipmentData.EquipSlot.CHEST
	chest.set_bonus_id = "dragon_set"
	chest.set_bonus_name = "龙鳞套装"
	chest.rarity = ItemData.Rarity.EPIC
	
	var legs = EquipmentData.new()
	legs.id = "dragon_legs"
	legs.item_name = "龙鳞腿甲"
	legs.equip_slot = EquipmentData.EquipSlot.LEGS
	legs.set_bonus_id = "dragon_set"
	legs.set_bonus_name = "龙鳞套装"
	legs.rarity = ItemData.Rarity.EPIC
	
	# 装备第一件
	var chest_instance = ItemInstance.create(chest, 1)
	equipment_manager.equip(chest_instance)
	print("装备第1件套装: %s (%d/6)" % [chest.set_bonus_name, equipment_manager.get_set_piece_count("dragon_set")])
	
	# 装备第二件
	var legs_instance = ItemInstance.create(legs, 1)
	equipment_manager.equip(legs_instance)
	print("装备第2件套装: %s (%d/6)" % [legs.set_bonus_name, equipment_manager.get_set_piece_count("dragon_set")])
	
	print()


## 示例 5: 耐久度系统
func example_durability():
	print("========== 示例 5: 耐久度系统 ==========")
	
	# 模拟受击消耗耐久度
	print("模拟受击 10 次...")
	for i in range(10):
		equipment_manager.consume_durability_on_hit()
	
	# 查看装备状态
	var weapon = equipment_manager.get_equipped(EquipmentData.EquipSlot.WEAPON_MAIN)
	if weapon:
		var weapon_data = weapon.item_data as WeaponData
		if weapon_data.has_durability:
			print("武器耐久度: %d/%d" % [weapon.current_durability, weapon_data.max_durability])
	
	# 修理所有装备
	print("\n修理所有装备...")
	var repair_cost = equipment_manager.repair_all()
	print("修理花费: %d 金币" % repair_cost)
	
	print()


## 信号回调
func _on_equipment_equipped(slot, item):
	var slot_name = EquipmentData.EquipSlot.keys()[slot]
	print("[信号] 装备: %s -> %s" % [slot_name, item.item_data.item_name])


func _on_equipment_unequipped(slot, item):
	var slot_name = EquipmentData.EquipSlot.keys()[slot]
	print("[信号] 卸下: %s -> %s" % [slot_name, item.item_data.item_name])


func _on_set_bonus_activated(set_id, piece_count):
	print("[信号] 套装效果激活: %s (%d件)" % [set_id, piece_count])


func _on_durability_changed(slot, current, maximum):
	var slot_name = EquipmentData.EquipSlot.keys()[slot]
	print("[信号] 耐久度变化: %s [%d/%d]" % [slot_name, current, maximum])
