# Stats 系统使用文档

## 概述

Stats 系统是 2D ARPG 游戏的核心属性管理系统，提供了完整的角色属性、修正器、战斗计算、等级系统等功能。系统采用组件化设计，支持实时属性计算、多种修正器类型、多层防御系统等高级特性。

## 核心类结构

### StatModifier (属性修正器)
定义所有属性类型和修正器类型的基础类。

**修正器类型：**
- `FLAT`: 固定值加成 (+10 攻击力)
- `PERCENT`: 百分比加成 (+20% 攻击力)
- `OVERRIDE`: 覆盖值 (直接设置为指定值)

**主要属性类型：**
- **核心属性**: STRENGTH(力量), AGILITY(敏捷), INTELLIGENCE(智力), VITALITY(体质), LUCK(幸运)
- **生存属性**: MAX_HEALTH, MAX_MANA, MAX_STAMINA
- **攻击属性**: PHYSICAL_DAMAGE, MAGIC_DAMAGE, 各种元素伤害, CRIT_CHANCE, CRIT_DAMAGE
- **防御属性**: ARMOR, MAGIC_RESIST, DODGE_CHANCE, 各种抗性
- **移动属性**: MOVE_SPEED, SPRINT_SPEED, DASH_SPEED
- **特殊属性**: LIFE_STEAL, COOLDOWN_REDUCTION, GOLD_FIND 等

**创建修正器：**
```gdscript
# 创建固定值修正器
var strength_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 5.0, "sword")

# 创建百分比修正器
var health_mod = StatModifier.create_percent(StatModifier.StatType.MAX_HEALTH, 0.15, "amulet")

# 创建覆盖修正器
var speed_override = StatModifier.create_override(StatModifier.StatType.MOVE_SPEED, 0.0, "stun")
```

### StatsData (属性数据)
存储角色的基础属性值，可以在编辑器中创建 .tres 资源文件。

**主要属性分组：**
- **等级与成长**: level, experience, stat_points
- **核心属性**: strength, agility, intelligence, vitality, luck
- **生存属性**: max_health, max_mana, max_stamina
- **攻击属性**: physical_damage, magic_damage, crit_chance 等
- **防御属性**: armor, magic_resist, dodge_chance 等
- **元素抗性**: res_fire, res_ice 等
- **移动属性**: move_speed, sprint_speed, dash_speed
- **特殊属性**: life_steal, cooldown_reduction 等

**创建属性数据：**
```gdscript
# 在编辑器中创建 StatsData 资源，或代码创建
var player_stats = StatsData.new()
player_stats.strength = 15
player_stats.agility = 12
player_stats.intelligence = 10
player_stats.vitality = 14
player_stats.luck = 8
player_stats.max_health = 120
```

### StatsComponent (属性组件)
核心组件类，挂载到角色节点上管理所有属性逻辑。

**主要功能：**
- 属性值计算（包含修正器）
- 战斗伤害计算
- 等级和经验系统
- 回复系统
- 修正器管理

**基本使用：**
```gdscript
# 创建并配置组件
var stats_component = StatsComponent.new()
stats_component.base_stats = player_stats  # 分配基础属性
add_child(stats_component)

# 获取属性值
var current_health = stats_component.get_stat(StatModifier.StatType.MAX_HEALTH)
var attack_damage = stats_component.get_stat(StatModifier.StatType.PHYSICAL_DAMAGE)
```

## 修正器系统

### 添加修正器
```gdscript
# 添加临时修正器 (持续5秒)
var temp_buff = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "temp_buff")
temp_buff.set_duration(5.0)
stats_component.add_modifier(temp_buff)

# 添加永久修正器
var permanent_mod = StatModifier.create_percent(StatModifier.StatType.MAX_HEALTH, 0.2, "artifact")
stats_component.add_modifier(permanent_mod)
```

### 移除修正器
```gdscript
# 按来源移除所有修正器
stats_component.remove_modifiers_by_source("sword")

# 按标签移除修正器
stats_component.remove_modifiers_by_tag("temporary")

# 移除特定修正器
stats_component.remove_modifier(specific_modifier)
```

### 修正器标签系统
```gdscript
# 创建带标签的修正器
var mod = StatModifier.create_flat(StatModifier.StatType.ATTACK_SPEED, 0.2, "coffee")
mod.add_tag("consumable")
mod.add_tag("buff")
stats_component.add_modifier(mod)

# 移除所有消耗品buff
stats_component.remove_modifiers_by_tag("consumable")
```

## 战斗系统

### 造成伤害
```gdscript
# 计算伤害 (不实际造成伤害)
var damage_calc = attacker.calculate_damage(
    50.0,                    # 基础伤害
    "physical",              # 伤害类型
    StatModifier.ElementType.FIRE,  # 元素类型
    true,                    # 可以暴击
    0.0,                     # 额外暴击率
    1.0                      # 伤害倍率
)

print("造成伤害: ", damage_calc.total_damage)
print("是否暴击: ", damage_calc.was_crit)
```

### 承受伤害
```gdscript
# 对目标造成完整伤害流程
var battle_result = attacker.deal_damage_to(
    target_stats,           # 目标 StatsComponent
    50.0,                   # 基础伤害
    "physical",             # 伤害类型
    StatModifier.ElementType.FIRE,  # 元素类型
    true,                   # 可以暴击
    true,                   # 可以闪避
    false                   # 是否格挡
)

print("最终伤害: ", battle_result.final_damage)
print("是否闪避: ", battle_result.was_dodged)
print("是否格挡: ", battle_result.was_blocked)
print("是否暴击: ", battle_result.was_crit)
```

### 直接伤害 (绕过防御)
```gdscript
# 直接扣除生命值 (用于中毒、流血等)
target.lose_health(20.0)

# 治疗生命值
target.heal(30.0)

# 消耗/恢复魔力
if target.consume_mana(25.0):
    print("魔力消耗成功")
else:
    print("魔力不足")

target.restore_mana(15.0)
```

## 等级与经验系统

### 获得经验
```gdscript
# 获得经验值
stats_component.gain_experience(150)

# 监听升级事件
stats_component.level_up.connect(func(new_level, points_gained):
    print("升级到等级 ", new_level, " 获得属性点 ", points_gained)
)
```

### 属性点分配
```gdscript
# 分配属性点到力量
if stats_component.allocate_stat_point(StatModifier.StatType.STRENGTH, 2):
    print("属性点分配成功")
else:
    print("属性点不足")

# 重置属性点
stats_component.reset_stat_points()

# 获取可用属性点
var available_points = stats_component.get_available_stat_points()
```

## 回复系统

### 自动回复
StatsComponent 会自动处理每秒的生命、魔力、耐力回复：

```gdscript
# 获取回复速率
var health_regen = stats_component.get_stat(StatModifier.StatType.HEALTH_REGEN)
var mana_regen = stats_component.get_stat(StatModifier.StatType.MANA_REGEN)
var stamina_regen = stats_component.get_stat(StatModifier.StatType.STAMINA_REGEN)
```

### 能量护盾系统
```gdscript
# 能量护盾有独立的回复机制
var shield_regen = stats_component.get_stat(StatModifier.StatType.ENERGY_SHIELD_REGEN)
var recharge_delay = stats_component.get_stat(StatModifier.StatType.ENERGY_SHIELD_RECHARGE_DELAY)
```

## 幸运系统

### 幸运影响随机事件
```gdscript
# 幸运检定
if LuckSystem.luck_check(0.1, player_luck, 0.005):  # 10%基础概率
    print("幸运触发!")

# 幸运影响数值
var gold_amount = LuckSystem.apply_luck_to_value(100, player_luck, 0.02)  # 金币数量

# 幸运提升物品品质
var quality_mult = LuckSystem.get_quality_multiplier(player_luck)
var final_damage = base_damage * quality_mult
```

### 幸运软上限
```gdscript
# 幸运值超过100后收益递减
var effective_luck = LuckSystem.get_effective_luck(raw_luck_value)
```

## 防御系统详解

### 多层防御计算顺序
1. **闪避检定**: 概率完全躲避伤害
2. **主动格挡**: 减少伤害百分比，可能完美格挡
3. **元素抗性**: 减少元素伤害
4. **护甲/魔抗**: 基于防御值的伤害减免
5. **额外减免**: 额外的伤害减免百分比
6. **能量护盾**: 在生命值前吸收伤害
7. **伤害吸收**: 吸收固定/百分比伤害
8. **伤害反射**: 反弹伤害给攻击者

### 抗性计算
```gdscript
# 元素抗性 (-100 到 100)
# 负值表示弱点，正值表示抗性
var fire_resistance = stats_component.get_stat(StatModifier.StatType.RES_FIRE)
var damage_multiplier = 1.0 - (fire_resistance / 100.0)
```

## 序列化与存档

### 保存状态
```gdscript
# 导出当前状态
var save_data = stats_component.to_dict()

# 保存到文件
var file = FileAccess.open("user://player_stats.save", FileAccess.WRITE)
file.store_var(save_data)
```

### 加载状态
```gdscript
# 从文件加载
var file = FileAccess.open("user://player_stats.save", FileAccess.READ)
var save_data = file.get_var()

# 恢复状态
stats_component.from_dict(save_data)
```

## 信号系统

StatsComponent 提供了丰富的信号用于UI更新：

```gdscript
# 连接信号
stats_component.stat_changed.connect(_on_stat_changed)
stats_component.health_changed.connect(_on_health_changed)
stats_component.mana_changed.connect(_on_mana_changed)
stats_component.stamina_changed.connect(_on_stamina_changed)
stats_component.energy_shield_changed.connect(_on_shield_changed)
stats_component.level_up.connect(_on_level_up)
stats_component.experience_gained.connect(_on_exp_gained)
stats_component.modifiers_changed.connect(_on_modifiers_changed)
stats_component.health_depleted.connect(_on_death)

func _on_stat_changed(stat_type, old_value, new_value):
    print("属性变化: ", StatModifier.StatType.keys()[stat_type], " ", old_value, " -> ", new_value)
```

## 调试工具

### 打印属性状态
```gdscript
# 打印完整属性状态
stats_component.debug_print_stats()
```

### 获取属性详情
```gdscript
# 获取属性计算分解
var breakdown = stats_component.get_stat_breakdown(StatModifier.StatType.MAX_HEALTH)
print("生命值分解:")
print("  基础值: ", breakdown.base_value)
print("  派生加成: ", breakdown.derived_bonus)
print("  固定加成: ", breakdown.flat_bonus)
print("  百分比加成: ", breakdown.percent_bonus)
print("  最终值: ", breakdown.final_value)
```

## 性能优化

### 缓存系统
StatsComponent 使用内部缓存系统，只在修正器变化时重新计算属性值。

### 自动回复控制
```gdscript
# 禁用自动回复 (节省性能)
stats_component.set_auto_regeneration(false)

# 需要时手动触发回复
stats_component.restore_mana(5.0)
```

## 扩展建议

### 自定义属性类型
```gdscript
# 在 StatModifier 中添加新的属性类型
enum StatType {
    # ... 现有类型
    CUSTOM_STAT = 1000,  # 自定义属性从1000开始
}

# 在 StatsComponent 中添加对应的基础值和派生计算
```

### 高级修正器类型
```gdscript
# 创建条件修正器 (需要额外逻辑支持)
var conditional_mod = StatModifier.create_flat(StatModifier.StatType.STRENGTH, 10.0, "conditional")
conditional_mod.add_tag("condition:health_above_50%")
```

### 状态效果系统
```gdscript
# 基于修正器的状态效果
var stun_effect = StatModifier.create_override(StatModifier.StatType.MOVE_SPEED, 0.0, "stun")
stun_effect.set_duration(3.0)
stun_effect.add_tag("status_effect")
stun_effect.add_tag("stun")
stats_component.add_modifier(stun_effect)
```

## 注意事项

- 修正器按优先级排序，优先级高的后计算
- 覆盖类型修正器会忽略其他所有修正器
- 临时修正器会在持续时间结束后自动移除
- 核心属性会影响派生属性的计算
- 幸运值超过100后收益递减
- 能量护盾受伤后有回复延迟
- 属性点只能分配给核心属性 (力量/敏捷/智力/体质/幸运)