# Items 系统使用文档

## 概述

Items 系统是 2D ARPG 游戏的核心模块之一，提供了完整的物品管理功能。系统采用面向对象设计，支持多种物品类型、属性加成、耐久度系统、随机词缀等高级特性。

## 核心类结构

### ItemData (物品数据基类)
所有物品的基础类，定义了物品的通用属性。

**主要属性：**
- `id`: 物品唯一标识符
- `item_name`: 显示名称
- `description`: 描述文本
- `icon`: 图标纹理
- `item_type`: 物品类型 (CONSUMABLE, EQUIPMENT, MATERIAL, QUEST, CURRENCY)
- `rarity`: 稀有度 (COMMON 到 MYTHIC)
- `max_stack`: 最大堆叠数量
- `weight`: 单个物品重量
- `base_value`: 基础价值
- `tags`: 标签数组，用于分类和过滤

**主要方法：**
- `get_rarity_color()`: 获取稀有度颜色
- `get_rarity_name()`: 获取稀有度名称
- `get_sell_price()`: 获取出售价格
- `get_full_description()`: 获取完整描述

### ConsumableData (消耗品数据)
继承自 ItemData，专门用于可使用的消耗品。

**特有属性：**
- `effect_type`: 效果类型 (INSTANT_HEAL, BUFF, DEBUFF_CURE 等)
- `use_time`: 使用时间
- `cooldown`: 冷却时间
- `effect_value`: 效果数值
- `effect_duration`: 效果持续时间
- `temp_modifiers`: 临时属性修正器

**使用示例：**
```gdscript
# 创建治疗药水
var health_potion = ConsumableData.new()
health_potion.item_name = "生命药水"
health_potion.effect_type = ConsumableData.EffectType.INSTANT_HEAL
health_potion.effect_value = 100.0
health_potion.max_stack = 99
```

### MATERIAL (材料物品)
基础 ItemData 类型，用于合成材料、制作材料等。

**特点：**
- 通常可以大量堆叠
- 主要用于配方系统
- 可能有特殊的合成标签

**使用示例：**
```gdscript
# 创建铁矿石材料
var iron_ore = ItemData.new()
iron_ore.item_name = "铁矿石"
iron_ore.item_type = ItemData.ItemType.MATERIAL
iron_ore.max_stack = 999
iron_ore.base_value = 5
iron_ore.add_tag("ore")
iron_ore.add_tag("metal")
```

### QUEST (任务物品)
基础 ItemData 类型，用于任务专用道具。

**特点：**
- 通常不可堆叠或堆叠数量很少
- 可能绑定到特定任务
- 完成任务后自动移除
- 通常无法出售或交易

**使用示例：**
```gdscript
# 创建任务信件
var quest_letter = ItemData.new()
quest_letter.item_name = "神秘信件"
quest_letter.item_type = ItemData.ItemType.QUEST
quest_letter.max_stack = 1
quest_letter.can_sell = false
quest_letter.can_trade = false
quest_letter.can_drop = false
quest_letter.add_tag("quest_item")
quest_letter.add_tag("letter")
```

### CURRENCY (货币物品)
基础 ItemData 类型，用于金币、宝石等特殊货币。

**特点：**
- 可以大量堆叠
- 特殊的货币价值计算
- 可能有特殊的货币类型标签
- 通常无法出售给商人

**使用示例：**
```gdscript
# 创建金币
var gold_coin = ItemData.new()
gold_coin.item_name = "金币"
gold_coin.item_type = ItemData.ItemType.CURRENCY
gold_coin.max_stack = 9999
gold_coin.base_value = 1
gold_coin.can_sell = false  # 金币本身就是货币
gold_coin.add_tag("currency")
gold_coin.add_tag("gold")

# 创建宝石货币
var ruby = ItemData.new()
ruby.item_name = "红宝石"
ruby.item_type = ItemData.ItemType.CURRENCY
ruby.max_stack = 999
ruby.base_value = 100
ruby.can_sell = false
ruby.add_tag("currency")
ruby.add_tag("gem")
ruby.add_tag("ruby")
```

### EquipmentData (装备数据)
继承自 ItemData，用于所有可装备物品。

**特有属性：**
- `equip_slot`: 装备槽位 (HELMET, WEAPON_MAIN, RING_1 等)
- `required_level`: 需求等级
- `stat_modifiers`: 属性修正器数组
- `has_durability`: 是否有耐久度
- `max_durability`: 最大耐久度
- `set_bonus_id`: 套装ID

**使用示例：**
```gdscript
# 创建力量戒指
var strength_ring = EquipmentData.new()
strength_ring.item_name = "力量戒指"
strength_ring.equip_slot = EquipmentData.EquipSlot.RING_1
strength_ring.required_level = 5

# 添加力量加成
var strength_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "ring")
strength_ring.stat_modifiers.append(strength_mod)
```

### WeaponData (武器数据)
继承自 EquipmentData，专门用于武器。

**特有属性：**
- `weapon_type`: 武器类型 (SWORD, BOW, STAFF 等)
- `is_two_handed`: 是否双手武器
- `attack_range`: 攻击范围
- `attack_speed`: 攻击速度倍率
- `min_physical_damage/max_physical_damage`: 物理伤害范围
- `min_magic_damage/max_magic_damage`: 魔法伤害范围

**使用示例：**
```gdscript
# 创建铁剑
var iron_sword = WeaponData.new()
iron_sword.item_name = "铁剑"
iron_sword.weapon_type = WeaponData.WeaponType.SWORD
iron_sword.min_physical_damage = 15.0
iron_sword.max_physical_damage = 25.0
iron_sword.attack_speed = 1.2

# 添加火焰伤害
var fire_mod = StatModifier.create_flat(StatModifier.StatType.FIRE_DAMAGE, 8.0, "sword")
iron_sword.stat_modifiers.append(fire_mod)
```

### ItemInstance (物品实例)
运行时物品实例类，包含堆叠、耐久度、随机属性等。

**主要属性：**
- `item_data`: 物品数据引用
- `stack_count`: 当前堆叠数量
- `current_durability`: 当前耐久度
- `random_modifiers`: 随机属性修正器
- `instance_id`: 唯一实例ID
- `is_bound`: 是否绑定

**创建实例：**
```gdscript
# 创建物品实例
var sword_instance = ItemInstance.create(iron_sword_data, 1)

# 创建带随机属性的装备
var random_sword = ItemInstance.create_random_equipment(iron_sword_data, 2)
```

**堆叠管理：**
```gdscript
# 检查是否可以堆叠
if instance1.can_stack_with(instance2):
    var stacked = instance1.try_stack(instance2)
    print("堆叠了 %d 个物品" % stacked)

# 分割堆叠
var split_instance = instance.split_stack(5)
```

## 属性系统集成

Items 系统与 StatModifier 系统深度集成：

```gdscript
# 创建各种类型的属性修正器
var flat_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "sword")
var percent_mod = StatModifier.create_percent(StatModifier.StatType.HEALTH, 0.15, "amulet")
var elemental_mod = StatModifier.create_flat(StatModifier.StatType.FIRE_DAMAGE, 20.0, "ring")

# 添加到装备
equipment.stat_modifiers.append_array([flat_mod, percent_mod, elemental_mod])
```

## 存档与加载

ItemInstance 支持序列化：

```gdscript
# 序列化
var save_data = item_instance.to_dict()

# 反序列化 (需要物品数据库)
var loaded_instance = ItemInstance.from_dict(save_data, item_database)
```

## 耐久度系统

装备支持耐久度管理：

```gdscript
# 减少耐久度
equipment_instance.reduce_durability(10)

# 修理装备
equipment_instance.repair()  # 完全修复
equipment_instance.repair(20)  # 修复20点耐久

# 检查是否损坏
if equipment_instance.is_broken():
    print("装备已损坏")
```

## 标签系统

使用标签进行物品分类和过滤：

```gdscript
# 添加标签
item_data.add_tag("rare")
item_data.add_tag("weapon")

# 检查标签
if item_data.has_tag("consumable"):
    print("这是消耗品")

# 移除标签
item_data.remove_tag("temporary")
```

## 最佳实践

1. **物品数据管理**
   - 在编辑器中创建 .tres 资源文件存储物品数据
   - 使用唯一ID标识每个物品
   - 合理设置堆叠数量和重量

2. **性能优化**
   - 物品实例使用 RefCounted，避免内存泄漏
   - 大量物品时使用对象池
   - 避免在每帧更新中调用 get_full_description()

3. **UI集成**
   - 使用 get_full_description() 生成物品tooltip
   - 根据 rarity 获取对应的颜色和样式
   - 显示耐久度条和堆叠数量

4. **网络同步**
   - 使用 instance_id 同步特定物品实例
   - 物品数据可以通过ID引用，避免传输完整数据

## 扩展建议

1. **自定义物品类型**
   - 继承 ItemData 创建新的物品类型
   - 重写 get_full_description() 提供自定义描述

2. **高级装备系统**
   - 实现装备强化系统
   - 添加宝石插槽系统
   - 实现装备升级机制

3. **物品合成系统**
   - 使用标签系统识别合成材料
   - 创建合成配方数据结构

## 注意事项

- 装备默认不可堆叠 (max_stack = 1)
- 消耗品默认可堆叠99个
- 耐久度只对装备有效
- 装备有随机属性不能堆叠
- 绑定物品无法交易和堆叠