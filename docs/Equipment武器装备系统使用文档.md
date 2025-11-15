# Equipment 系统使用文档

## 概述

Equipment 系统是 2D ARPG 游戏的装备管理模块，提供了完整的装备槽位管理、属性加成应用、耐久度消耗、套装系统等功能。系统与 Items 系统和 Stats 系统深度集成，支持装备的穿戴、卸下、修理等操作。

## 核心类结构

### EquipmentManager (装备管理器)
装备系统的核心组件，挂载到角色节点上管理所有装备相关逻辑。

**主要功能：**
- 装备槽位管理
- 装备/卸下操作
- 属性加成应用
- 耐久度消耗
- 套装系统
- 序列化支持

**基本设置：**
```gdscript
# 创建装备管理器
var equipment_manager = EquipmentManager.new()
equipment_manager.stats_component = player_stats  # 连接属性组件
equipment_manager.inventory = player_inventory    # 连接背包组件
add_child(equipment_manager)
```

## 装备操作

### 装备物品
```gdscript
# 从 ItemInstance 装备物品
var sword_instance = ItemInstance.create(sword_data, 1)
if equipment_manager.equip(sword_instance):
    print("装备成功")
else:
    print("装备失败")
```

### 卸下装备
```gdscript
# 卸下指定槽位的装备
if equipment_manager.unequip(EquipmentData.EquipSlot.WEAPON_MAIN):
    print("卸下成功")
else:
    print("卸下失败")
```

### 从背包直接装备
```gdscript
# 从背包第3个槽位装备物品
if equipment_manager.equip_from_inventory(2):  # 索引从0开始
    print("装备成功")
else:
    print("装备失败")
```

### 卸下所有装备
```gdscript
# 卸下所有装备并放入背包
var unequipped_slots = equipment_manager.unequip_all(true)
print("卸下了 %d 件装备" % unequipped_slots.size())
```

## 查询装备状态

### 获取装备信息
```gdscript
# 检查槽位是否有装备
if equipment_manager.is_slot_equipped(EquipmentData.EquipSlot.HELMET):
    print("头盔已装备")

# 获取指定槽位的装备
var weapon = equipment_manager.get_equipped(EquipmentData.EquipSlot.WEAPON_MAIN)
if weapon:
    print("主手武器: ", weapon.item_data.item_name)

# 获取所有已装备物品
var all_equipped = equipment_manager.get_all_equipped()
print("已装备 %d 件物品" % all_equipped.size())
```

## 耐久度系统

### 受击时消耗耐久度
```gdscript
# 在角色受击时调用
equipment_manager.consume_durability_on_hit()
```

### 手动消耗耐久度
```gdscript
# 消耗指定装备的耐久度
equipment_manager.consume_durability(EquipmentData.EquipSlot.ARMOR, 5)
```

### 修理装备
```gdscript
# 完全修理一件装备
var repaired = equipment_manager.repair_equipment(EquipmentData.EquipSlot.WEAPON_MAIN, true)
print("修理了 %d 点耐久度" % repaired)

# 修理一半耐久度
equipment_manager.repair_equipment(EquipmentData.EquipSlot.ARMOR, false)
```

### 修理所有装备
```gdscript
# 修理所有装备，返回总修理费用
var total_cost = equipment_manager.repair_all()
print("修理总费用: %d 金币" % total_cost)
```

## 套装系统

### 查询套装状态
```gdscript
# 获取套装件数
var set_count = equipment_manager.get_set_piece_count("dragon_armor")
print("龙甲套装件数: %d" % set_count)

# 检查套装效果是否激活
if equipment_manager.has_set_bonus("dragon_armor", 4):
    print("4件套龙甲效果已激活")

# 获取所有激活的套装
var active_sets = equipment_manager.get_active_sets()
for set_info in active_sets:
    print("套装 %s: %d 件" % [set_info.set_id, set_info.count])
```

### 监听套装事件
```gdscript
# 连接套装信号
equipment_manager.set_bonus_activated.connect(_on_set_activated)
equipment_manager.set_bonus_deactivated.connect(_on_set_deactivated)

func _on_set_activated(set_id: String, piece_count: int):
    print("套装 %s %d件套效果激活!" % [set_id, piece_count])
    # 应用套装加成
    _apply_set_bonus(set_id, piece_count)

func _on_set_deactivated(set_id: String):
    print("套装 %s 效果失效" % set_id)
    # 移除套装加成
    _remove_set_bonus(set_id)
```

## 属性加成管理

装备系统会自动应用/移除装备的属性加成：

```gdscript
# 装备时自动应用属性加成
# 卸下时自动移除属性加成

# 监听属性变化
stats_component.stat_changed.connect(_on_stat_changed)

func _on_stat_changed(stat_type, old_value, new_value):
    if stat_type == StatModifier.StatType.PHYSICAL_DAMAGE:
        print("物理攻击力: %.1f -> %.1f" % [old_value, new_value])
```

## 信号系统

EquipmentManager 提供了丰富的信号用于UI更新和游戏逻辑：

```gdscript
# 装备变化信号
equipment_manager.equipment_changed.connect(_on_equipment_changed)
equipment_manager.equipment_equipped.connect(_on_equipment_equipped)
equipment_manager.equipment_unequipped.connect(_on_equipment_unequipped)

# 耐久度信号
equipment_manager.durability_changed.connect(_on_durability_changed)
equipment_manager.equipment_broken.connect(_on_equipment_broken)

func _on_equipment_changed(slot: EquipmentData.EquipSlot, item: ItemInstance):
    var slot_name = EquipmentData.EquipSlot.keys()[slot]
    if item:
        print("%s 装备了: %s" % [slot_name, item.item_data.item_name])
    else:
        print("%s 卸下了装备" % slot_name)

func _on_durability_changed(slot: EquipmentData.EquipSlot, current: int, max: int):
    var slot_name = EquipmentData.EquipSlot.keys()[slot]
    print("%s 耐久度: %d/%d" % [slot_name, current, max])

func _on_equipment_broken(slot: EquipmentData.EquipSlot, item: ItemInstance):
    print("装备损坏: %s" % item.item_data.item_name)
    # 处理装备损坏逻辑
```

## 装备槽位

系统支持以下装备槽位：

```gdscript
enum EquipSlot {
    HELMET,       ## 头盔
    CHEST,        ## 胸甲
    LEGS,         ## 腿甲
    BOOTS,        ## 靴子
    GLOVES,       ## 手套
    WEAPON_MAIN,  ## 主手武器
    WEAPON_OFF,   ## 副手武器/盾牌
    RING_1,       ## 戒指1
    RING_2,       ## 戒指2
    AMULET,       ## 项链
    BELT          ## 腰带
}
```

## 序列化与存档

### 保存装备状态
```gdscript
# 导出装备状态
var equipment_data = equipment_manager.to_dict()

# 与其他数据合并保存
var save_data = {
    "stats": stats_component.to_dict(),
    "inventory": inventory.to_dict(),
    "equipment": equipment_data
}

# 保存到文件
var file = FileAccess.open("user://player_save.save", FileAccess.WRITE)
file.store_var(save_data)
```

### 加载装备状态
```gdscript
# 从文件加载
var file = FileAccess.open("user://player_save.save", FileAccess.READ)
var save_data = file.get_var()

# 恢复装备状态 (需要物品数据库)
equipment_manager.from_dict(save_data.equipment, item_database)
```

## 装备数据创建

### 创建装备物品
```gdscript
# 创建武器装备数据
var sword_data = WeaponData.new()
sword_data.item_name = "铁剑"
sword_data.item_type = ItemData.ItemType.EQUIPMENT
sword_data.equip_slot = EquipmentData.EquipSlot.WEAPON_MAIN
sword_data.required_level = 1
sword_data.min_physical_damage = 15
sword_data.max_physical_damage = 25
sword_data.attack_speed = 1.2

# 添加力量加成
var strength_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "sword")
sword_data.stat_modifiers.append(strength_mod)

# 设置耐久度
sword_data.has_durability = true
sword_data.max_durability = 100
```

### 创建套装装备
```gdscript
# 创建套装盔甲
var armor_data = EquipmentData.new()
armor_data.item_name = "龙鳞胸甲"
armor_data.equip_slot = EquipmentData.EquipSlot.CHEST
armor_data.set_bonus_id = "dragon_armor"
armor_data.set_bonus_name = "龙之守护"
armor_data.set_bonus_description = "2件: +10% 火焰抗性\n4件: +20 护甲值"

# 添加属性
var armor_mod = StatModifier.create_flat(StatModifier.StatType.ARMOR, 25.0, "dragon_chest")
armor_data.stat_modifiers.append(armor_mod)
```

## 高级功能

### 装备比较
```gdscript
# 比较两件装备的属性差异
func compare_equipment(equip1: ItemInstance, equip2: ItemInstance) -> Dictionary:
    var comparison = {}
    
    # 比较主要属性
    var stats_to_compare = [
        StatModifier.StatType.PHYSICAL_DAMAGE,
        StatModifier.StatType.ARMOR,
        StatModifier.StatType.CRIT_CHANCE
    ]
    
    for stat in stats_to_compare:
        var val1 = _get_equipment_stat(equip1, stat)
        var val2 = _get_equipment_stat(equip2, stat)
        comparison[StatModifier.StatType.keys()[stat]] = val2 - val1
    
    return comparison

func _get_equipment_stat(equip: ItemInstance, stat_type: StatModifier.StatType) -> float:
    if not equip or not equip.item_data is EquipmentData:
        return 0.0
    
    for mod in equip.get_all_modifiers():
        if mod.stat_type == stat_type:
            return mod.value
    
    return 0.0
```

### 装备推荐系统
```gdscript
# 根据角色职业推荐装备
func get_recommended_equipment(character_class: String) -> Array:
    var recommendations = []
    
    match character_class:
        "warrior":
            recommendations = [
                EquipmentData.EquipSlot.WEAPON_MAIN,  # 双手武器
                EquipmentData.EquipSlot.CHEST,        # 重甲
                EquipmentData.EquipSlot.HELMET        # 头盔
            ]
        "mage":
            recommendations = [
                EquipmentData.EquipSlot.WEAPON_MAIN,  # 法杖
                EquipmentData.EquipSlot.AMULET,       # 项链
                EquipmentData.EquipSlot.RING_1        # 戒指
            ]
    
    return recommendations
```

## 调试工具

### 打印装备状态
```gdscript
# 打印当前所有装备信息
equipment_manager.print_equipment_status()
```

### 装备统计
```gdscript
# 获取装备统计信息
func get_equipment_stats() -> Dictionary:
    var stats = {
        "total_equipped": equipment_manager.get_equipped_count(),
        "total_durability": 0,
        "total_max_durability": 0,
        "broken_items": 0
    }
    
    for item in equipment_manager.get_all_equipped():
        if item.item_data is EquipmentData:
            var equip_data = item.item_data as EquipmentData
            if equip_data.has_durability:
                stats.total_durability += item.current_durability
                stats.total_max_durability += equip_data.max_durability
                
                if item.is_broken():
                    stats.broken_items += 1
    
    return stats
```

## 性能优化

### 批量操作
```gdscript
# 批量装备多件物品
func equip_multiple(items: Array) -> Array:
    var results = []
    for item in items:
        var success = equipment_manager.equip(item, false)  # 不自动交换
        results.append(success)
    return results
```

### 延迟属性更新
```gdscript
# 在大量装备变化时延迟属性更新
stats_component.set_auto_regeneration(false)

# 执行批量操作
# ...

# 恢复自动更新
stats_component.set_auto_regeneration(true)
stats_component._mark_dirty()  # 强制重新计算
```

## 扩展建议

### 自定义装备槽位
```gdscript
# 在 EquipmentData 中添加新的槽位
enum EquipSlot {
    # ... 现有槽位
    CAPE = 100,      # 披风
    TATTOO = 101,    # 纹身
    IMPLANT = 102    # 植入物
}
```

### 装备强化系统
```gdscript
# 添加装备强化功能
func upgrade_equipment(slot: EquipmentData.EquipSlot, upgrade_level: int) -> bool:
    var item = equipment_manager.get_equipped(slot)
    if not item:
        return false
    
    # 移除当前属性
    equipment_manager._remove_item_modifiers(slot)
    
    # 应用强化加成
    var upgrade_mod = StatModifier.create_percent(
        StatModifier.StatType.PHYSICAL_DAMAGE, 
        upgrade_level * 0.1,
        "upgrade"
    )
    item.get_all_modifiers().append(upgrade_mod)
    
    # 重新应用属性
    equipment_manager._apply_item_modifiers(item, slot)
    
    return true
```

### 装备外观系统
```gdscript
# 为装备添加外观变体
class EquipmentAppearance:
    var material: String  # "iron", "steel", "mithril"
    var color: Color
    var effects: Array[String]  # ["glowing", "enchanted"]

# 在装备数据中添加外观信息
@export var appearance: EquipmentAppearance
```

## 注意事项

- 装备时会自动检查等级需求
- 绑定装备 (bind_on_equip) 装备后无法交易
- 耐久度消耗有概率触发，可配置
- 套装系统需要手动实现具体的加成效果
- 装备损坏不会自动卸下，可选择保留或移除
- 序列化时需要提供物品数据库进行反序列化
- 属性加成会自动应用到 StatsComponent，无需手动管理