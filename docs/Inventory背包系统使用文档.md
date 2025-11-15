# Inventory 系统使用文档

## 概述

Inventory 系统是 2D ARPG 游戏的背包管理模块，提供了完整的物品存储、格子管理、重量限制、自动堆叠、整理排序等功能。系统采用组件化设计，支持与 Items 系统和 Equipment 系统的无缝集成。

## 核心类结构

### InventoryManager (背包组件)
背包系统的核心组件，挂载到角色节点上管理所有物品存储逻辑。

**主要功能：**
- 格子系统管理
- 物品添加/移除
- 自动堆叠
- 重量限制
- 整理和排序
- 金币管理
- 序列化支持

**基本设置：**
```gdscript
# 创建背包组件
var inventory = InventoryManager.new()
inventory.slot_count = 30          # 30个格子
inventory.use_weight_limit = true  # 启用重量限制
inventory.max_weight = 150.0       # 最大负重150
add_child(inventory)
```

## 物品操作

### 添加物品
```gdscript
# 添加单个物品
var health_potion = ItemInstance.create(potion_data, 5)
if inventory.add_item(health_potion):
    print("物品添加成功")
else:
    print("背包已满或超重")

# 添加到指定格子
inventory.add_item(sword_instance, 5)  # 添加到第6个格子
```

### 批量添加物品
```gdscript
# 添加战利品列表
var loot_items = [
    ItemInstance.create(gold_coin_data, 50),
    ItemInstance.create(health_potion_data, 3),
    ItemInstance.create(sword_data, 1)
]

var result = inventory.add_items(loot_items)
print("成功添加: %d 件, 失败: %d 件" % [result.added.size(), result.failed.size()])
```

### 移除物品
```gdscript
# 从指定格子移除物品
var removed_item = inventory.remove_item(5)  # 移除第6个格子的物品
if removed_item:
    print("移除了: %s" % removed_item.item_data.item_name)

# 移除部分堆叠
var removed_potions = inventory.remove_item(3, 2)  # 从第4个格子移除2个药水

# 按物品ID移除
var removed_count = inventory.remove_item_by_id("health_potion", 3)
print("移除了 %d 个治疗药水" % removed_count)
```

### 使用物品
```gdscript
# 使用消耗品
if inventory.use_item(2):  # 使用第3个格子的物品
    print("物品使用成功")
else:
    print("无法使用该物品")
```

## 格子操作

### 交换格子
```gdscript
# 交换两个格子的物品
inventory.swap_slots(0, 5)  # 交换第1和第6个格子
```

### 移动物品
```gdscript
# 移动整个堆叠
inventory.move_item(2, 10)  # 将第3个格子的物品移到第11个格子

# 移动部分堆叠
inventory.move_item(1, 8, 3)  # 从第2个格子移动3个物品到第9个格子
```

## 查询和检查

### 获取物品信息
```gdscript
# 获取指定格子的物品
var item = inventory.get_item(5)
if item:
    print("格子6: %s x%d" % [item.item_data.item_name, item.stack_count])

# 检查是否拥有物品
if inventory.has_item("health_potion", 5):
    print("有足够的治疗药水")

# 获取物品总数量
var potion_count = inventory.get_item_count("health_potion")
print("共有 %d 个治疗药水" % potion_count)

# 查找物品位置
var potion_slots = inventory.find_item_slots("health_potion")
print("治疗药水在格子: ", potion_slots)
```

### 背包状态检查
```gdscript
# 获取空格子数量
var empty_slots = inventory.get_empty_slot_count()
print("空格子: %d" % empty_slots)

# 检查是否有空间容纳物品
if inventory.has_space_for(new_sword):
    print("有空间装备新剑")

# 获取当前重量
var current_weight = inventory.get_current_weight()
print("当前负重: %.1f / %.1f" % [current_weight, inventory.max_weight])

# 获取背包总价值
var total_value = inventory.get_total_value()
print("背包总价值: %d 金币" % total_value)
```

## 整理和排序

### 整理背包
```gdscript
# 整理背包（堆叠相同物品并压缩空格子）
inventory.organize()
```

### 压缩空格子
```gdscript
# 只压缩空格子，不改变物品顺序
inventory.compact()
```

### 排序背包
```gdscript
# 按稀有度排序（从高到低）
inventory.sort_by_rarity()

# 按价值排序（从高到低）
inventory.sort_by_value()
```

## 金币管理

### 金币操作
```gdscript
# 添加金币
inventory.add_gold(100)
print("获得100金币")

# 消费金币
if inventory.remove_gold(50):
    print("消费50金币成功")
else:
    print("金币不足")

# 获取金币数量
var current_gold = inventory.get_gold()
print("当前金币: %d" % current_gold)
```

## 信号系统

InventoryManager 提供了丰富的信号用于UI更新：

```gdscript
# 连接信号
inventory.item_added.connect(_on_item_added)
inventory.item_removed.connect(_on_item_removed)
inventory.item_used.connect(_on_item_used)
inventory.inventory_full.connect(_on_inventory_full)
inventory.weight_exceeded.connect(_on_weight_exceeded)
inventory.slot_changed.connect(_on_slot_changed)
inventory.gold_changed.connect(_on_gold_changed)

func _on_item_added(item: ItemInstance, slot_index: int):
    print("添加物品: %s 到格子 %d" % [item.item_data.item_name, slot_index])

func _on_item_removed(item: ItemInstance, slot_index: int):
    print("移除物品: %s 从格子 %d" % [item.item_data.item_name, slot_index])

func _on_inventory_full():
    print("背包已满!")

func _on_weight_exceeded():
    print("负重超限!")

func _on_gold_changed(new_amount: int):
    print("金币变化: %d" % new_amount)
```

## 装备集成

### 从背包装备物品
```gdscript
# 装备物品（需要配合 EquipmentManager）
var item_to_equip = inventory.equip_item(3)  # 从第4个格子取出装备
if item_to_equip:
    equipment_manager.equip(item_to_equip)
```

### 装备系统集成示例
```gdscript
# 完整的装备流程
func equip_from_inventory(slot_index: int) -> bool:
    var item = inventory.get_item(slot_index)
    if not item or not item.item_data is EquipmentData:
        return false
    
    # 检查装备槽位是否匹配
    var equip_data = item.item_data as EquipmentData
    var current_equipped = equipment_manager.get_equipped(equip_data.equip_slot)
    
    # 如果有已装备物品，先放回背包
    if current_equipped:
        inventory.add_item(current_equipped)
    
    # 从背包移除并装备
    var removed_item = inventory.remove_item(slot_index)
    return equipment_manager.equip(removed_item)
```

## 序列化与存档

### 保存背包状态
```gdscript
# 导出背包状态
var inventory_data = inventory.to_dict()

# 与其他数据合并保存
var save_data = {
    "stats": stats_component.to_dict(),
    "equipment": equipment_manager.to_dict(),
    "inventory": inventory_data
}

# 保存到文件
var file = FileAccess.open("user://player_save.save", FileAccess.WRITE)
file.store_var(save_data)
```

### 加载背包状态
```gdscript
# 从文件加载
var file = FileAccess.open("user://player_save.save", FileAccess.READ)
var save_data = file.get_var()

# 恢复背包状态 (需要物品数据库)
inventory.from_dict(save_data.inventory, item_database)
```

## 高级功能

### 物品过滤和搜索
```gdscript
# 按类型过滤物品
func get_items_by_type(item_type: ItemData.ItemType) -> Array:
    var result = []
    for i in range(inventory.slot_count):
        var item = inventory.get_item(i)
        if item and item.item_data.item_type == item_type:
            result.append({"slot": i, "item": item})
    return result

# 按标签过滤物品
func get_items_by_tag(tag: String) -> Array:
    var result = []
    for i in range(inventory.slot_count):
        var item = inventory.get_item(i)
        if item and item.item_data.has_tag(tag):
            result.append({"slot": i, "item": item})
    return result

# 搜索物品
func search_items(query: String) -> Array:
    var result = []
    var lower_query = query.to_lower()
    for i in range(inventory.slot_count):
        var item = inventory.get_item(i)
        if item:
            var item_name = item.item_data.item_name.to_lower()
            if lower_query in item_name:
                result.append({"slot": i, "item": item})
    return result
```

### 背包统计
```gdscript
# 获取背包统计信息
func get_inventory_stats() -> Dictionary:
    var stats = {
        "total_slots": inventory.slot_count,
        "used_slots": 0,
        "empty_slots": inventory.get_empty_slot_count(),
        "total_weight": inventory.get_current_weight(),
        "max_weight": inventory.max_weight,
        "total_value": inventory.get_total_value(),
        "gold": inventory.get_gold(),
        "item_types": {},
        "rarity_distribution": {}
    }
    
    for i in range(inventory.slot_count):
        var item = inventory.get_item(i)
        if item:
            stats.used_slots += 1
            
            # 统计物品类型
            var item_type = ItemData.ItemType.keys()[item.item_data.item_type]
            if not stats.item_types.has(item_type):
                stats.item_types[item_type] = 0
            stats.item_types[item_type] += item.stack_count
            
            # 统计稀有度
            var rarity = ItemData.Rarity.keys()[item.item_data.rarity]
            if not stats.rarity_distribution.has(rarity):
                stats.rarity_distribution[rarity] = 0
            stats.rarity_distribution[rarity] += item.stack_count
    
    return stats
```

### 自动拾取系统
```gdscript
# 智能拾取物品
func smart_pickup(item: ItemInstance) -> bool:
    # 优先级: 金币 > 消耗品 > 装备 > 材料
    
    match item.item_data.item_type:
        ItemData.ItemType.CURRENCY:
            # 金币直接添加到金币系统
            inventory.add_gold(item.stack_count)
            return true
        
        ItemData.ItemType.CONSUMABLE:
            # 消耗品自动堆叠
            return inventory.add_item(item)
        
        ItemData.ItemType.EQUIPMENT:
            # 装备检查是否更好
            if _should_auto_equip(item):
                return _try_auto_equip(item)
            else:
                return inventory.add_item(item)
        
        _:
            # 其他物品正常添加
            return inventory.add_item(item)

func _should_auto_equip(item: ItemInstance) -> bool:
    if not item.item_data is EquipmentData:
        return false
    
    var equip_data = item.item_data as EquipmentData
    var current_equipped = equipment_manager.get_equipped(equip_data.equip_slot)
    
    if not current_equipped:
        return true
    
    # 简单的比较逻辑（可以扩展）
    return item.item_data.base_value > current_equipped.item_data.base_value

func _try_auto_equip(item: ItemInstance) -> bool:
    var equip_data = item.item_data as EquipmentData
    var current_equipped = equipment_manager.get_equipped(equip_data.equip_slot)
    
    # 如果有已装备物品，先放回背包
    if current_equipped:
        if not inventory.add_item(current_equipped):
            return false  # 背包没空间
    
    # 装备新物品
    return equipment_manager.equip(item)
```

## 性能优化

### 批量操作
```gdscript
# 批量移除物品
func remove_multiple_items(removals: Array) -> Array:
    var results = []
    for removal in removals:
        var removed = inventory.remove_item(removal.slot, removal.amount)
        results.append(removed)
    return results

# 批量检查空间
func has_space_for_multiple(items: Array[ItemInstance]) -> bool:
    var total_weight = 0.0
    var required_slots = 0
    
    for item in items:
        total_weight += item.get_total_weight()
        
        if inventory.auto_stack:
            var can_stack = false
            for existing_item in inventory.slots:
                if existing_item and existing_item.can_stack_with(item):
                    can_stack = true
                    break
            if not can_stack:
                required_slots += 1
        else:
            required_slots += 1
    
    return (inventory.get_current_weight() + total_weight <= inventory.max_weight and
            inventory.get_empty_slot_count() >= required_slots)
```

### 延迟更新
```gdscript
# 在大量操作时延迟信号发射
func bulk_operation_disable_signals():
    inventory.disconnect("item_added", Callable(self, "_on_item_added"))
    inventory.disconnect("item_removed", Callable(self, "_on_item_removed"))

func bulk_operation_enable_signals():
    inventory.connect("item_added", Callable(self, "_on_item_added"))
    inventory.connect("item_removed", Callable(self, "_on_item_removed"))
```

## 扩展建议

### 自定义格子类型
```gdscript
# 为不同类型的物品设置专用格子
class SpecializedSlot:
    var allowed_types: Array[ItemData.ItemType]
    var max_stack_override: int = -1

# 扩展背包支持专用格子
@export var specialized_slots: Array[SpecializedSlot]
```

### 物品冷却系统
```gdscript
# 为物品使用添加冷却时间
class ItemCooldown:
    var item_id: String
    var cooldown_time: float
    var remaining_time: float

var item_cooldowns: Dictionary = {}

func use_item_with_cooldown(slot_index: int) -> bool:
    var item = inventory.get_item(slot_index)
    if not item:
        return false
    
    var item_id = item.item_data.id
    if item_cooldowns.has(item_id) and item_cooldowns[item_id] > 0:
        return false  # 冷却中
    
    if inventory.use_item(slot_index):
        item_cooldowns[item_id] = item.item_data.cooldown
        return true
    
    return false

func _process_cooldowns(delta: float):
    for item_id in item_cooldowns.keys():
        if item_cooldowns[item_id] > 0:
            item_cooldowns[item_id] -= delta
```

### 背包扩容系统
```gdscript
# 动态扩容背包
func expand_inventory(additional_slots: int) -> void:
    inventory.slot_count += additional_slots
    inventory.slots.resize(inventory.slot_count)
    
    for i in range(inventory.slots.size() - additional_slots, inventory.slots.size()):
        inventory.slots[i] = null

# 购买背包扩容
func buy_inventory_expansion(cost: int, slots_to_add: int) -> bool:
    if inventory.get_gold() >= cost:
        inventory.remove_gold(cost)
        expand_inventory(slots_to_add)
        return true
    return false
```

## 注意事项

- 自动堆叠功能默认启用，可通过 `auto_stack` 属性控制
- 重量限制是可选的，通过 `use_weight_limit` 控制
- 物品堆叠不会超过 `max_stack` 限制
- 金币系统独立于物品格子，不占用背包空间
- 序列化时需要提供物品数据库进行反序列化
- 装备物品从背包移除后不会自动放回，需要手动管理
- 整理和排序操作会触发大量 `slot_changed` 信号
- 批量操作时注意性能影响，考虑使用延迟更新