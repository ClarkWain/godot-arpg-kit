# 战斗系统使用文档

## 概述

战斗系统是一个完整的、组件化的战斗框架，支持伤害计算、状态效果、技能系统等功能。系统采用事件驱动架构，与现有的 Stats、Equipment、Quest 系统深度集成。

### 主要特性

- **组件化设计**: 所有战斗功能通过组件实现，可灵活组合
- **伤害计算管道**: 多阶段伤害计算，支持暴击、元素反应、防御削减等
- **状态效果系统**: 支持 Buff/Debuff、DOT/HOT、控制效果
- **技能系统**: 完整的技能管理，支持施法、冷却、资源消耗
- **事件驱动**: 通过事件总线与其他系统解耦
- **深度集成**: 与 StatsComponent、EquipmentManager、QuestEventBus 无缝集成

## 核心组件

### 1. CombatComponent (战斗组件)

战斗系统的核心组件，管理战斗状态和伤害处理。

**文件**: `scripts/combat/combat_component.gd`

**主要功能**:
- 管理战斗状态（空闲、攻击、受击、死亡等）
- 发起攻击和接收伤害
- 连击系统
- 无敌时间管理

### 2. DamageCalculator (伤害计算器)

纯函数式的伤害计算服务，处理所有伤害计算逻辑。

**文件**: `scripts/combat/damage_calculator.gd`

**计算管道**:
1. 属性加成阶段
2. 暴击判定阶段
3. 元素反应阶段
4. 防御削减阶段
5. 伤害吸收阶段（护盾）

### 3. StatusEffectManager (状态效果管理器)

管理实体身上的所有状态效果（Buff/Debuff）。

**文件**: `scripts/combat/status_effects/status_effect_manager.gd`

**主要功能**:
- 添加/移除状态效果
- 管理效果叠加
- 处理 DOT/HOT
- 护盾系统
- 净化机制

### 4. SkillManager (技能管理器)

管理实体的技能槽位和技能使用。

**文件**: `scripts/combat/skills/skill_manager.gd`

**主要功能**:
- 技能装备/卸载
- 技能施法和冷却管理
- 资源消耗（魔法、体力）
- 技能效果执行

## 使用示例

### 1. 基础战斗实体设置

```gdscript
# 在场景中添加战斗组件
extends CharacterBody2D

func _ready() -> void:
    # 添加 StatsComponent
    var stats = StatsComponent.new()
    stats.name = "StatsComponent"
    add_child(stats)
    
    # 添加 CombatComponent
    var combat = CombatComponent.new()
    combat.name = "CombatComponent"
    combat.invincibility_duration = 0.2  # 受击后0.2秒无敌
    add_child(combat)
    
    # 添加 StatusEffectManager
    var status = StatusEffectManager.new()
    status.name = "StatusEffectManager"
    add_child(status)
```

### 2. 发起攻击

```gdscript
# 攻击敌人
func attack_enemy(enemy: Node) -> void:
    var combat = $CombatComponent
    
    # 基础攻击
    var damage_info = combat.attack(
        enemy,                              # 目标
        50.0,                               # 基础伤害
        DamageInfo.DamageType.PHYSICAL      # 伤害类型
    )
    
    if damage_info:
        print("造成了 %.1f 点伤害" % damage_info.final_damage)
        if damage_info.is_critical:
            print("暴击!")
```

### 3. 添加状态效果

```gdscript
# 创建中毒效果数据
var poison_effect = StatusEffectData.new()
poison_effect.effect_id = "poison"
poison_effect.effect_name = "中毒"
poison_effect.effect_type = StatusEffectData.EffectType.DOT
poison_effect.duration = 10.0
poison_effect.tick_interval = 1.0
poison_effect.tick_value = 5.0  # 每秒5点伤害
poison_effect.tick_damage_type = DamageInfo.DamageType.POISON
poison_effect.element = "poison"

# 注册效果
StatusEffectManager.register_effect(poison_effect)

# 应用到目标
var status_manager = target.get_node("StatusEffectManager")
status_manager.add_effect("poison", self)
```

### 4. 创建和使用技能

```gdscript
# 创建火球术技能
var fireball = SkillData.new()
fireball.skill_id = "fireball"
fireball.skill_name = "火球术"
fireball.description = "发射一个火球，造成 {damage} 点火焰伤害"
fireball.skill_type = SkillData.SkillType.ACTIVE
fireball.target_type = SkillData.TargetType.ENEMY
fireball.cooldown = 3.0
fireball.mana_cost = 20.0
fireball.cast_time = 1.0
fireball.cast_range = 500.0
fireball.base_damage = 80.0
fireball.damage_type = DamageInfo.DamageType.FIRE
fireball.damage_scaling = 1.5  # 150%法术强度加成

# 注册技能
SkillManager.register_skill(fireball)

# 装备技能到槽位
var skill_manager = $SkillManager
skill_manager.equip_skill(0, "fireball")

# 使用技能
skill_manager.use_skill(0, enemy)
```

### 5. 创建 Buff 效果

```gdscript
# 创建力量祝福 Buff
var strength_buff = StatusEffectData.new()
strength_buff.effect_id = "strength_blessing"
strength_buff.effect_name = "力量祝福"
strength_buff.effect_type = StatusEffectData.EffectType.BUFF
strength_buff.duration = 30.0
strength_buff.stack_type = StatusEffectData.StackType.REFRESH

# 添加属性修改器（+20攻击力）
var mod = StatModifier.new()
mod.stat_name = "attack"
mod.value = 20.0
mod.modifier_type = StatModifier.ModifierType.FLAT
strength_buff.modifiers.append(mod)

# 注册并应用
StatusEffectManager.register_effect(strength_buff)
$StatusEffectManager.add_effect("strength_blessing")
```

### 6. 元素反应系统

```gdscript
# 先对敌人施加冰冻效果
var ice_effect = StatusEffectData.new()
ice_effect.effect_id = "frozen"
ice_effect.element = "ice"
ice_effect.duration = 5.0
StatusEffectManager.register_effect(ice_effect)
enemy.get_node("StatusEffectManager").add_effect("frozen")

# 然后用火焰攻击，触发"蒸发"反应（伤害x2）
var combat = $CombatComponent
var damage_info = combat.attack(
    enemy,
    100.0,
    DamageInfo.DamageType.FIRE
)

if damage_info.elemental_reaction == "蒸发":
    print("触发元素反应：蒸发！伤害翻倍！")
```

### 7. 连击系统

```gdscript
# 监听连击事件
$CombatComponent.combo_achieved.connect(_on_combo_achieved)

func _on_combo_achieved(combo_count: int) -> void:
    print("连击数: %d" % combo_count)
    
    # 根据连击数增加伤害
    if combo_count >= 3:
        # 触发特殊效果
        print("连击奖励！")
```

## API 参考

### CombatComponent

#### 属性
- `entity: Node` - 战斗实体引用
- `stats_component: Node` - StatsComponent 引用
- `status_effect_manager: Node` - StatusEffectManager 引用
- `combat_state: CombatState.State` - 当前战斗状态
- `combo_count: int` - 当前连击数
- `combo_window: float` - 连击窗口时间（秒）
- `invincibility_duration: float` - 受击后无敌时间（秒）

#### 方法
- `attack(target: Node, base_damage: float, damage_type: DamageInfo.DamageType, skill_id: String) -> DamageInfo` - 攻击目标
- `receive_damage(damage_info: DamageInfo)` - 接收伤害
- `heal(amount: float, source: Node) -> float` - 治疗
- `die(killer: Node)` - 死亡处理
- `can_attack() -> bool` - 检查是否可以攻击
- `can_move() -> bool` - 检查是否可以移动
- `set_combat_state(new_state: CombatState.State)` - 设置战斗状态

#### 信号
- `state_changed(old_state, new_state)` - 状态改变
- `damage_dealt(target, damage_info)` - 造成伤害
- `damage_received(source, damage_info)` - 受到伤害
- `combo_achieved(combo_count)` - 连击达成
- `died(killer)` - 死亡

### StatusEffectManager

#### 方法
- `add_effect(effect_id: String, source: Node, custom_duration: float) -> StatusEffectInstance` - 添加状态效果
- `remove_effect(effect_id: String, remove_all: bool) -> bool` - 移除状态效果
- `remove_all_effects(only_type: StatusEffectData.EffectType)` - 移除所有效果
- `cleanse_debuffs(count: int) -> int` - 净化负面效果
- `has_effect(effect_id: String) -> bool` - 检查是否有某个效果
- `get_effect_stacks(effect_id: String) -> int` - 获取效果层数
- `get_active_element() -> String` - 获取当前元素状态
- `add_shield(amount: float)` - 添加护盾
- `consume_shield(amount: float) -> float` - 消耗护盾

#### 信号
- `effect_applied(effect_id, instance)` - 效果应用
- `effect_removed(effect_id, instance)` - 效果移除
- `effect_stacks_changed(effect_id, old_count, new_count)` - 层数改变
- `shield_changed(old_amount, new_amount)` - 护盾改变

### SkillManager

#### 方法
- `equip_skill(slot: int, skill_id: String) -> bool` - 装备技能
- `unequip_skill(slot: int) -> bool` - 卸载技能
- `use_skill(slot: int, target: Node, target_position: Vector2) -> bool` - 使用技能
- `interrupt_cast()` - 打断施法
- `get_skill_instance(slot: int) -> SkillInstance` - 获取技能实例
- `get_skill_data(slot: int) -> SkillData` - 获取技能数据

#### 信号
- `skill_equipped(slot, skill_id)` - 技能装备
- `skill_unequipped(slot, skill_id)` - 技能卸载
- `skill_used(skill_id)` - 技能使用
- `skill_cast_started(skill_id)` - 开始施法
- `skill_cast_finished(skill_id)` - 施法完成
- `skill_on_cooldown(skill_id, duration)` - 技能冷却

### DamageInfo

#### 属性
- `source: Node` - 攻击来源
- `target: Node` - 攻击目标
- `base_damage: float` - 基础伤害
- `final_damage: float` - 最终伤害
- `damage_type: DamageType` - 伤害类型
- `is_critical: bool` - 是否暴击
- `is_dodged: bool` - 是否闪避
- `is_blocked: bool` - 是否格挡
- `is_absorbed: bool` - 是否被吸收
- `elemental_reaction: String` - 元素反应类型
- `status_effects: Array[String]` - 附加状态效果

#### 方法
- `to_dict() -> Dictionary` - 转换为字典
- `get_damage_type_color() -> Color` - 获取伤害类型颜色

## 与其他系统的集成

### 与 StatsComponent 集成

战斗系统直接读取 StatsComponent 的属性：
- `attack` - 物理伤害加成
- `magic_power` - 魔法伤害加成
- `defense` - 伤害减免
- `critical_rate` - 暴击率
- `critical_damage` - 暴击伤害
- `dodge_rate` - 闪避率
- `armor_penetration` - 护甲穿透

```gdscript
# StatsComponent 自动影响战斗计算
var stats = $StatsComponent
stats.set_stat("attack", 100)  # 攻击力100
stats.set_stat("critical_rate", 25)  # 25%暴击率

# 攻击时自动应用这些属性
$CombatComponent.attack(enemy, 50, DamageInfo.DamageType.PHYSICAL)
```

### 与 EquipmentManager 集成

装备自动影响战斗属性：

```gdscript
# 装备武器后，攻击力提升
var equipment = $EquipmentManager
equipment.equip(weapon_item, EquipmentManager.EquipmentSlot.MAIN_HAND)

# 武器的 StatModifier 自动添加到 StatsComponent
# 战斗时自动使用提升后的属性
```

### 与 QuestEventBus 集成

战斗事件自动触发任务进度：

```gdscript
# 击杀敌人自动更新任务
$CombatComponent.died.connect(func(killer):
    # 自动触发 enemy_killed 事件
    # 任务系统会自动更新"击杀XX敌人"的进度
)

# 造成伤害也会触发任务事件
$CombatComponent.damage_dealt.connect(func(target, damage_info):
    # 触发 damage_dealt 事件
    # 可用于"造成XX点伤害"的任务
)
```

### 与 LuckSystem 集成

幸运值影响战斗随机性：

```gdscript
# 幸运值自动影响暴击率
# 在 DamageCalculator 中自动调用
var crit_rate = stats_component.get_luck_modified_value(
    base_crit_rate,
    "critical_rate"
)
```

## 元素反应表

| 攻击元素 | 目标元素 | 反应名称 | 效果 |
|---------|---------|---------|------|
| 火 | 冰 | 蒸发 | 伤害 x2.0 |
| 冰 | 火 | 融化 | 伤害 x1.5 |
| 雷 | 水 | 感电 | 伤害 x1.2 + 感电状态 |
| 火 | 雷 | 超载 | 伤害 x1.5 + 燃烧状态 |
| 冰 | 雷 | 超导 | 伤害 x1.3 + 冰冻状态 |

## 战斗状态机

```
IDLE (空闲)
  ↓ 攻击输入
ATTACKING (攻击中)
  ↓ 攻击完成
RECOVERING (恢复中/后摇)
  ↓ 恢复完成
IDLE

任何状态 + 受击 → BEING_HIT (受击中) → IDLE
任何状态 + 控制效果 → STUNNED (眩晕) → IDLE
任何状态 + 生命值为0 → DEAD (死亡)
```

## 最佳实践

### 1. 战斗实体设置

```gdscript
# 完整的战斗实体设置
extends CharacterBody2D

func _ready() -> void:
    # 按顺序添加组件
    _setup_stats()
    _setup_combat()
    _setup_status_effects()
    _setup_skills()
    _connect_signals()

func _setup_stats() -> void:
    var stats = StatsComponent.new()
    stats.name = "StatsComponent"
    add_child(stats)

func _setup_combat() -> void:
    var combat = CombatComponent.new()
    combat.name = "CombatComponent"
    add_child(combat)

func _setup_status_effects() -> void:
    var status = StatusEffectManager.new()
    status.name = "StatusEffectManager"
    add_child(status)

func _setup_skills() -> void:
    var skills = SkillManager.new()
    skills.name = "SkillManager"
    add_child(skills)

func _connect_signals() -> void:
    $CombatComponent.died.connect(_on_died)
    $CombatComponent.damage_received.connect(_on_damage_received)
```

### 2. 性能优化

- 使用对象池管理投射物和特效
- 避免在每帧计算伤害，使用事件驱动
- 状态效果批量处理 Tick
- 缓存常用的组件引用

### 3. 平衡性调整

所有数值都在 Resource 文件中配置：
- 技能数据存储在 `.tres` 文件
- 状态效果数据存储在 `.tres` 文件
- 修改配置无需重新编译代码

### 4. 测试和调试

```gdscript
# 使用 DamageCalculator 进行伤害测试
var damage_info = DamageInfo.new(attacker, defender, 100, DamageInfo.DamageType.PHYSICAL)
DamageCalculator.calculate_damage(damage_info)
print("预期伤害: %.1f" % damage_info.final_damage)
```

## 常见问题

### Q: 如何创建自定义状态效果？

A: 创建 StatusEffectData Resource，配置属性和修改器即可。无需编写代码。

### Q: 技能伤害如何计算？

A: 技能伤害 = 基础伤害 + (属性值 × 伤害系数)，然后经过伤害计算管道。

### Q: 如何实现技能连招？

A: 监听技能使用信号，在特定时间窗口内使用下一个技能即可触发连招。

### Q: 状态效果如何叠加？

A: 通过 `stack_type` 配置：不叠加、叠加层数、独立实例、刷新时间。

### Q: 如何实现无敌效果？

A: 在 CombatComponent 中设置 `is_invincible = true` 或添加无敌状态效果。

## 扩展建议

未来可以添加的功能：
1. **AI 战斗系统** - 敌人自动使用技能
2. **战斗动画系统** - 动画与战斗状态联动
3. **命中判定系统** - 更精确的碰撞检测
4. **战斗特效系统** - 粒子特效和屏幕震动
5. **战斗音效系统** - 打击音效和语音
6. **战斗UI系统** - 伤害数字、血条、技能冷却显示