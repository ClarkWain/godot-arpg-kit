# Loot 系统使用文档

## 概述

Loot 系统是 2D ARPG 游戏的战利品掉落模块，提供了完整的掉落物生成、管理和拾取功能。系统采用组件化设计，支持复杂的掉落规则、多种掉落模式、幸运值影响、磁吸拾取等高级特性。

## 核心类结构

### LootEntry (掉落条目)
定义单个掉落条目的配置和规则。

**主要属性：**
- `item_data`: 掉落的物品数据
- `drop_chance`: 基础掉落概率 (0-1)
- `quantity_mode`: 数量模式 (FIXED, RANDOM, WEIGHTED)
- `min_quantity/max_quantity`: 数量范围
- `weight`: 加权随机权重
- `required_tags/excluded_tags`: 条件标签
- `luck_affects_chance/quantity`: 幸运值影响

**创建示例：**
```gdscript
# 创建治疗药水掉落条目
var health_potion_entry = LootEntry.new()
health_potion_entry.item_data = health_potion_data
health_potion_entry.drop_chance = 0.3  # 30% 掉落概率
health_potion_entry.quantity_mode = LootEntry.QuantityMode.RANDOM
health_potion_entry.min_quantity = 1
health_potion_entry.max_quantity = 3
health_potion_entry.luck_affects_quantity = true
```

### LootTable (掉落表)
完整的掉落表配置，支持多种掉落模式。

**掉落模式：**
- `ALL`: 所有条目都尝试掉落
- `PICK_ONE`: 从表中随机选择一个
- `PICK_MULTIPLE`: 从表中随机选择多个
- `WEIGHTED_RANDOM`: 加权随机选择

**主要属性：**
- `entries`: 掉落条目数组
- `drop_mode`: 掉落模式
- `min_picks/max_picks`: 选择数量范围
- `drops_gold`: 是否掉落金币
- `min_gold/max_gold`: 金币范围

**创建示例：**
```gdscript
# 创建怪物掉落表
var goblin_loot = LootTable.new()
goblin_loot.table_name = "哥布林掉落"
goblin_loot.drop_mode = LootTable.DropMode.ALL
goblin_loot.drops_gold = true
goblin_loot.min_gold = 5
goblin_loot.max_gold = 15

# 添加掉落条目
goblin_loot.entries.append(health_potion_entry)
goblin_loot.entries.append(copper_sword_entry)
```

### LootGenerator (掉落生成器)
全局单例服务，负责生成和管理掉落物实体。

**主要功能：**
- 从掉落表生成掉落物
- 管理对象池减少实例化开销
- 处理散开效果
- 提供拾取信号

**基本设置：**
```gdscript
# 创建掉落生成器（通常作为自动加载单例）
var loot_generator = LootGenerator.new()
loot_generator.dropped_item_scene = preload("res://scenes/dropped_item.tscn")
loot_generator.scatter_range = 60.0
loot_generator.use_pooling = true
loot_generator.pool_size = 100
```

### DroppedItem (掉落物实体)
场景中的掉落物品实体，支持磁吸和视觉效果。

**主要功能：**
- 抛出动画和物理效果
- 磁吸拾取
- 自动消失
- 稀有度视觉效果

**配置选项：**
```gdscript
# 在场景中配置 DroppedItem
dropped_item.enable_magnetism = true
dropped_item.magnet_radius = 150.0
dropped_item.magnet_speed = 250.0
dropped_item.auto_despawn = true
dropped_item.despawn_time = 45.0
```

### EnemyLootComponent (敌人掉落组件)
挂载到敌人节点上的组件，处理死亡掉落。

**主要功能：**
- 自动检测敌人死亡
- 支持多个掉落表
- 等级差惩罚
- 首杀奖励
- 精英/Boss 掉落加成

**配置示例：**
```gdscript
# 在敌人场景中添加 EnemyLootComponent
var loot_component = EnemyLootComponent.new()
loot_component.main_loot_table = goblin_loot
loot_component.enemy_level = 3
loot_component.enemy_tags = ["goblin", "forest"]
loot_component.drop_rate_multiplier = 1.2
```

## 掉落表配置

### 基础掉落表
```gdscript
# 创建基础怪物掉落表
var basic_loot = LootTable.new()
basic_loot.drop_mode = LootTable.DropMode.ALL
basic_loot.drops_gold = true
basic_loot.min_gold = 1
basic_loot.max_gold = 10

# 添加常见掉落
var coin_entry = LootEntry.new()
coin_entry.item_data = copper_coin_data
coin_entry.drop_chance = 0.8
coin_entry.quantity_mode = LootEntry.QuantityMode.RANDOM
coin_entry.min_quantity = 1
coin_entry.max_quantity = 5

basic_loot.entries.append(coin_entry)
```

### 精英怪物掉落表
```gdscript
# 精英怪物掉落表
var elite_loot = LootTable.new()
elite_loot.drop_mode = LootTable.DropMode.PICK_MULTIPLE
elite_loot.min_picks = 2
elite_loot.max_picks = 4
elite_loot.drops_gold = true
elite_loot.min_gold = 20
elite_loot.max_gold = 50

# 添加稀有物品
var rare_weapon_entry = LootEntry.new()
rare_weapon_entry.item_data = rare_sword_data
rare_weapon_entry.drop_chance = 0.15
rare_weapon_entry.weight = 50

elite_loot.entries.append(rare_weapon_entry)
```

### Boss掉落表
```gdscript
# Boss掉落表
var boss_loot = LootTable.new()
boss_loot.drop_mode = LootTable.DropMode.WEIGHTED_RANDOM
boss_loot.drops_gold = true
boss_loot.min_gold = 100
boss_loot.max_gold = 500

# 保证掉落稀有装备
var legendary_entry = LootEntry.new()
legendary_entry.item_data = legendary_armor_data
legendary_entry.guaranteed = true
legendary_entry.weight = 100

boss_loot.entries.append(legendary_entry)
```

## 掉落生成

### 从掉落表生成
```gdscript
# 生成掉落物到指定位置
var loot_data = loot_table.generate_loot(player_level, player_luck, ["forest", "daytime"])
var dropped_items = loot_generator.spawn_loot_from_table(loot_table, enemy_position, player_level, player_luck)
```

### 直接生成物品
```gdscript
# 生成单个物品掉落
var sword_instance = ItemInstance.create(sword_data, 1)
loot_generator.spawn_item(sword_instance, drop_position)

# 生成金币掉落
loot_generator.spawn_gold(25, drop_position)
```

### 敌人死亡自动掉落
```gdscript
# EnemyLootComponent 会自动处理
# 当敌人死亡时会调用 generate_and_spawn_loot()

# 或者手动触发
enemy_loot_component.trigger_drop(player_node)
```

## 幸运值影响

### 基础幸运影响
```gdscript
# 幸运值影响掉落概率和数量
var loot_data = loot_table.generate_loot(player_level, player_luck, context_tags)

# 幸运值越高：
# - 掉落概率增加
# - 掉落数量增加
# - 金币数量增加
# - 可能触发额外掉落
```

### 自定义幸运影响
```gdscript
# 在 LootEntry 中自定义幸运影响
var custom_entry = LootEntry.new()
custom_entry.luck_affects_chance = true
custom_entry.luck_chance_scaling = 0.01  # 每点幸运 +1% 概率
custom_entry.luck_affects_quantity = true
custom_entry.luck_quantity_scaling = 0.02  # 每点幸运 +2% 数量
```

## 条件掉落

### 标签条件
```gdscript
# 基于上下文标签的条件掉落
var loot_data = loot_table.generate_loot(player_level, luck_value, ["boss_fight", "night_time", "full_moon"])

# LootEntry 配置
entry.required_tags = ["night_time"]  # 只有夜晚才会掉落
entry.excluded_tags = ["easy_mode"]   # 简单模式不会掉落
```

### 等级条件
```gdscript
# 基于玩家等级的条件
entry.min_player_level = 5   # 玩家等级 >= 5
entry.max_player_level = 20  # 玩家等级 <= 20
```

### 组限制
```gdscript
# 同组只能掉落一个
entry1.group_id = "weapon"
entry2.group_id = "weapon"
entry3.group_id = "armor"

# 这样同一组中只有一个条目会掉落
```

## 拾取系统

### 磁吸拾取
```gdscript
# DroppedItem 会自动检测玩家并启动磁吸
# 配置磁吸参数
dropped_item.enable_magnetism = true
dropped_item.magnet_radius = 120.0
dropped_item.magnet_speed = 300.0
```

### 拾取信号处理
```gdscript
# 连接拾取信号
loot_generator.loot_picked_up.connect(_on_loot_picked_up)

func _on_loot_picked_up(item: ItemInstance, picker: Node2D):
    if item:
        # 物品拾取
        inventory.add_item(item)
        print("拾取了: ", item.item_data.item_name)
    else:
        # 金币拾取（特殊处理）
        var gold_amount = dropped_item.gold_amount
        inventory.add_gold(gold_amount)
        print("拾取了 ", gold_amount, " 金币")
```

### 自动拾取系统
```gdscript
# 扩展 InventoryManager 添加自动拾取
func setup_auto_pickup():
    loot_generator.loot_picked_up.connect(_on_auto_pickup)

func _on_auto_pickup(item: ItemInstance, picker: Node2D):
    if picker == player_node:  # 只处理玩家拾取
        if item:
            var success = add_item(item)
            if not success:
                # 背包满，创建新的掉落物
                loot_generator.spawn_item(item, picker.global_position)
        else:
            # 金币特殊处理
            add_gold(dropped_item.gold_amount)
```

## 高级功能

### 掉落预览
```gdscript
# 预览掉落表内容（用于UI显示）
var possible_items = loot_table.get_all_possible_items()
for item_data in possible_items:
    print("可能掉落: ", item_data.item_name)

# 计算平均掉落价值
var average_value = loot_table.get_average_value(player_level, player_luck)
print("平均掉落价值: ", average_value)
```

### 敌人掉落预览
```gdscript
# 预览敌人掉落（用于调试）
var preview = enemy_loot_component.preview_loot(player_level, player_luck, 100)
print("平均金币: ", preview.average_gold)
print("物品统计: ", preview.item_counts)
print("平均总价值: ", preview.total_value)
```

### 动态掉落表
```gdscript
# 根据游戏进度动态修改掉落表
func update_loot_for_season(season: String):
    match season:
        "winter":
            loot_table.min_gold *= 1.5
            # 添加冬季特有物品
        "halloween":
            # 添加万圣节物品
            var pumpkin_entry = LootEntry.new()
            pumpkin_entry.item_data = pumpkin_data
            pumpkin_entry.drop_chance = 0.1
            loot_table.entries.append(pumpkin_entry)
```

### 稀有度提升系统
```gdscript
# 在 EnemyLootComponent 中配置稀有度提升
enemy_loot_component.rarity_boost_chance = 0.05  # 5% 概率提升稀有度

# 或者在 LootTable 中添加稀有版本
var rare_version = LootEntry.new()
rare_version.item_data = rare_sword_data
rare_version.drop_chance = 0.01  # 1% 概率掉落稀有版本
loot_table.entries.append(rare_version)
```

## 性能优化

### 对象池
```gdscript
# 启用对象池减少实例化开销
loot_generator.use_pooling = true
loot_generator.pool_size = 200  # 根据游戏规模调整

# 定期清理池中对象
func _on_timer_timeout():
    loot_generator.clear_all_drops()
```

### 批量生成
```gdscript
# 批量生成多个掉落物
var loot_positions = [pos1, pos2, pos3]
for pos in loot_positions:
    loot_generator.spawn_loot_from_table(loot_table, pos, player_level, player_luck)
```

### 延迟生成
```gdscript
# 在Boss战结束时延迟生成掉落，避免卡顿
func spawn_boss_loot_delayed():
    await get_tree().create_timer(2.0).timeout  # 等待战斗结束动画
    loot_generator.spawn_loot_from_table(boss_loot_table, boss_position, player_level, player_luck)
```

## 调试工具

### 掉落统计
```gdscript
# 统计掉落情况
var drop_stats = {
    "total_drops": 0,
    "gold_dropped": 0,
    "items_dropped": {},
    "rare_drops": 0
}

func track_loot_spawn(dropped_items: Array):
    for item in dropped_items:
        if item is DroppedItem:
            drop_stats.total_drops += 1
            
            if item.gold_amount > 0:
                drop_stats.gold_dropped += item.gold_amount
            elif item.item_instance:
                var item_id = item.item_instance.item_data.id
                if not drop_stats.items_dropped.has(item_id):
                    drop_stats.items_dropped[item_id] = 0
                drop_stats.items_dropped[item_id] += 1
                
                if item.item_instance.item_data.rarity >= ItemData.Rarity.RARE:
                    drop_stats.rare_drops += 1

loot_generator.loot_spawned.connect(track_loot_spawn)
```

### 掉落表测试
```gdscript
# 测试掉落表平衡性
func test_loot_balance(table: LootTable, test_runs: int = 1000):
    var results = {
        "average_gold": 0.0,
        "drop_rates": {},  # 实际掉落率
        "quantity_distribution": {}
    }
    
    for i in range(test_runs):
        var loot = table.generate_loot(1, 0, [])
        results.average_gold += loot.gold
        
        for item in loot.items:
            var item_id = item.item_data.id
            if not results.drop_rates.has(item_id):
                results.drop_rates[item_id] = 0
            results.drop_rates[item_id] += 1
            
            if not results.quantity_distribution.has(item_id):
                results.quantity_distribution[item_id] = []
            results.quantity_distribution[item_id].append(item.stack_count)
    
    results.average_gold /= test_runs
    
    # 计算实际掉落率
    for item_id in results.drop_rates:
        results.drop_rates[item_id] = float(results.drop_rates[item_id]) / test_runs
    
    return results
```

## 扩展建议

### 自定义掉落条件
```gdscript
# 扩展 LootEntry 添加自定义条件
class CustomLootEntry extends LootEntry:
    var custom_condition: Callable  # 自定义条件函数
    
    func check_conditions(player_level: int, context_tags: Array[String]) -> bool:
        if not super.check_conditions(player_level, context_tags):
            return false
        
        if custom_condition:
            return custom_condition.call(player_level, context_tags)
        
        return true

# 使用示例
var entry = CustomLootEntry.new()
entry.custom_condition = func(level, tags): return "special_event" in tags
```

### 掉落动画系统
```gdscript
# 为不同类型的掉落添加特殊动画
class AnimatedDroppedItem extends DroppedItem:
    @export var animation_type: String = "bounce"
    
    func _start_spawn_animation():
        match animation_type:
            "bounce":
                _play_bounce_animation()
            "float":
                _play_float_animation()
            "explode":
                _play_explode_animation()
```

### 网络同步
```gdscript
# 为多人游戏添加掉落同步
func sync_loot_spawn(loot_data: Dictionary, position: Vector2):
    # 发送到所有客户端
    rpc("spawn_loot_on_clients", loot_data, position)

@rpc("authority", "call_local")
func spawn_loot_on_clients(loot_data: Dictionary, position: Vector2):
    loot_generator.spawn_loot(loot_data, position)
```

## 注意事项

- LootTable 的 entries 数组中的条目顺序会影响加权随机
- DroppedItem 的碰撞层需要正确设置以检测玩家
- EnemyLootComponent 需要连接敌人的死亡信号
- 幸运值影响会显著改变掉落平衡，需要仔细调校
- 对象池大小应根据游戏中同时存在的掉落物数量调整
- 自动消失时间不宜过短，以免玩家错过拾取
- 磁吸范围过大会影响游戏体验
- 掉落表的测试需要大量样本才能获得准确的统计数据