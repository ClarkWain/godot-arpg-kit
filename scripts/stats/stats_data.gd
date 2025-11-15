class_name StatsData
extends Resource
## 角色属性数据资源
## 
## 存储角色的所有基础属性值,可以在编辑器中配置
## 不同的角色(玩家/敌人)可以使用不同的 StatsData 资源

## ========== 等级与成长 ==========
@export_group("Level & Growth")
## 当前等级
@export var level: int = 1
## 当前经验值
@export var experience: int = 0
## 升到下一级所需经验
@export var experience_to_next_level: int = 100
## 可分配的属性点数
@export var stat_points: int = 0

## ========== 核心属性 (影响其他派生属性) ==========
@export_group("Core Attributes")
## 力量 - 影响物理攻击力和暴击伤害
@export var strength: int = 10
## 敏捷 - 影响攻击速度、移动速度和闪避率
@export var agility: int = 10
## 智力 - 影响魔法攻击力和最大魔力值
@export var intelligence: int = 10
## 体质 - 影响物理防御和最大生命值
@export var vitality: int = 10
## 幸运 - 影响暴击率、掉落率、品质等随机事件
@export var luck: int = 10

## ========== 生存属性 ==========
@export_group("Survival Stats")
## 最大生命值
@export var max_health: float = 100.0
## 最大魔力值
@export var max_mana: float = 50.0
## 最大耐力值 - 用于冲刺、闪避和格挡等动作
@export var max_stamina: float = 100.0

## ========== 攻击属性 ==========
@export_group("Offense Stats")
## 物理攻击力 - 普通攻击和物理技能的基础伤害
@export var physical_damage: float = 10.0
## 魔法攻击力 - 魔法技能的基础伤害
@export var magic_damage: float = 5.0
## 火焰伤害 - 火焰元素攻击伤害
@export var fire_damage: float = 0.0
## 冰霜伤害 - 冰霜元素攻击伤害
@export var ice_damage: float = 0.0
## 闪电伤害 - 闪电元素攻击伤害
@export var lightning_damage: float = 0.0
## 毒素伤害 - 毒素元素攻击伤害
@export var poison_damage: float = 0.0
## 暗影伤害 - 暗影元素攻击伤害
@export var dark_damage: float = 0.0
## 神圣伤害 - 神圣元素攻击伤害
@export var holy_damage: float = 0.0
## 攻击速度倍率 - 1.0 为基础速度,数值越高攻击越快
@export var attack_speed: float = 1.0
## 施法速度倍率 - 影响技能施放速度
@export var cast_speed: float = 1.0
## 暴击率 - 触发暴击的概率 (0-1)
@export_range(0, 1) var crit_chance: float = 0.05
## 暴击伤害倍率 - 暴击时造成的伤害倍数
@export_range(1, 10) var crit_damage: float = 1.5
## 命中率 - 攻击命中目标的概率 (0-1)
@export_range(0, 1) var accuracy: float = 0.95

## ========== 防御属性 ==========
@export_group("Defense Stats")
## 闪避率 - 完全躲避物理和魔法攻击的概率 (0-0.75)
@export_range(0, 0.75) var dodge_chance: float = 0.05
## 格挡值 - 主动格挡时减少的固定伤害(物理和魔法通用)
@export var block_amount: float = 0.0
## 格挡减伤比例 - 主动格挡时减少的伤害百分比(物理和魔法通用) (0-1)
@export_range(0, 1) var block_reduction: float = 0.5

@export_group("Physical Defense")
## 护甲值 - 减少受到的物理伤害
@export var armor: float = 10.0
## 物理格挡率 - 主动格挡物理攻击时触发完美格挡的概率 (0-1)
@export_range(0, 1) var block_chance: float = 0.0
## 物理伤害减免 - 额外的物理伤害减免百分比 (0-0.9)
@export_range(0, 0.9) var physical_damage_reduction: float = 0.0

@export_group("Magic Defense")
## 魔法抗性 - 减少受到的魔法伤害
@export var magic_resist: float = 5.0
## 魔法格挡率 - 主动格挡魔法攻击时触发完美格挡的概率 (0-1)
@export_range(0, 1) var spell_block_chance: float = 0.0
## 魔法伤害减免 - 额外的魔法伤害减免百分比 (0-0.9)
@export_range(0, 0.9) var magic_damage_reduction: float = 0.0

## ========== 元素抗性 (-100 到 100) ==========
@export_group("Elemental Resistances", "res_")
## 火焰抗性 - 减少火焰伤害的百分比,负值表示弱点,0表示无抗性,正值表示抗性
@export_range(-100, 100) var res_fire: float = 0
## 冰霜抗性 - 减少冰霜伤害的百分比,负值表示弱点,0表示无抗性,正值表示抗性
@export_range(-100, 100) var res_ice: float = 0
## 雷电抗性 - 减少雷电伤害的百分比,负值表示弱点,0表示无抗性,正值表示抗性
@export_range(-100, 100) var res_lightning: float = 0
## 毒素抗性 - 减少毒素伤害的百分比,负值表示弱点,0表示无抗性,正值表示抗性
@export_range(-100, 100) var res_poison: float = 0
## 暗黑抗性 - 减少暗黑伤害的百分比,负值表示弱点,0表示无抗性,正值表示抗性
@export_range(-100, 100) var res_dark: float = 0
## 神圣抗性 - 减少神圣伤害的百分比,负值表示弱点,0表示无抗性,正值表示抗性
@export_range(-100, 100) var res_holy: float = 0
## 全元素抗性加成 - 对所有元素抗性的额外加成,负值表示弱点,0表示无抗性,正值表示抗性
@export_range(-100, 100) var res_all: float = 0

## ========== 状态抗性 (0 到 1) ==========
@export_group("Status Resistances", "status_res_")
## 晕眩抗性 - 抵抗晕眩效果的概率
@export_range(0, 1) var status_res_stun: float = 0.0
## 冰冻抗性 - 抵抗冰冻效果的概率
@export_range(0, 1) var status_res_freeze: float = 0.0
## 燃烧抗性 - 抵抗燃烧效果的概率
@export_range(0, 1) var status_res_burn: float = 0.0
## 中毒抗性 - 抵抗中毒效果的概率
@export_range(0, 1) var status_res_poison: float = 0.0
## 流血抗性 - 抵抗流血效果的概率
@export_range(0, 1) var status_res_bleed: float = 0.0
## 减速抗性 - 抵抗减速效果的概率
@export_range(0, 1) var status_res_slow: float = 0.0

## ========== 移动属性 ==========
@export_group("Movement")
## 基础移动速度 - 正常行走时的速度
@export var move_speed: float = 120.0
## 冲刺速度 - 冲刺时的移动速度
@export var sprint_speed: float = 180.0
## 闪避速度 - 执行闪避动作时的速度
@export var dash_speed: float = 180.0
## 闪避距离 - 单次闪避的移动距离
@export var dash_distance: float = 100.0

## ========== 多层防御系统 ==========
@export_group("Layered Defense")
## 最大能量护盾 - 在生命值之前承受伤害的护盾值
@export var max_energy_shield: float = 0.0
## 护盾回复速度 - 每秒恢复的护盾值
@export var energy_shield_regen: float = 0.0
## 护盾回复延迟 - 受伤后开始回复护盾的延迟时间(秒)
@export var energy_shield_recharge_delay: float = 2.0
## 伤害吸收值 - 每次受击吸收的固定伤害
@export var damage_absorb_amount: float = 0.0
## 伤害吸收比例 - 吸收受到伤害的百分比 (0-1)
@export_range(0, 1) var damage_absorb_percent: float = 0.0
## 伤害反射值 - 反弹给攻击者的固定伤害
@export var damage_reflect_amount: float = 0.0
## 伤害反射比例 - 反弹受到伤害的百分比 (0-1)
@export_range(0, 1) var damage_reflect_percent: float = 0.0

## ========== 回复属性 ==========
@export_group("Regeneration")
## 生命回复 - 每秒恢复的生命值
@export var health_regen: float = 1.0
## 魔力回复 - 每秒恢复的魔力值
@export var mana_regen: float = 2.0
## 耐力回复 - 每秒恢复的耐力值
@export var stamina_regen: float = 10.0

## ========== 特殊属性 ==========
@export_group("Special Stats")
## 生命偷取 - 造成伤害时转化为生命值的比例 (0-1)
@export_range(0, 1) var life_steal: float = 0.0
## 法力偷取 - 造成伤害时转化为魔力值的比例 (0-1)
@export_range(0, 1) var mana_steal: float = 0.0
## 冷却缩减 - 减少技能冷却时间的百分比 (0-0.8)
@export_range(0, 0.8) var cooldown_reduction: float = 0.0
## 技能范围倍率 - 技能作用范围的缩放倍数
@export var skill_range: float = 1.0
## 额外抛射物数量 - 技能发射额外弹道的数量
@export var projectile_count: int = 0
## 穿透次数 - 弹道可以穿透的敌人数量
@export var pierce_count: int = 0

## ========== 掉落与奖励 ==========
@export_group("Rewards")
## 金币掉落倍率 - 击败敌人时获得金币的倍数
@export var gold_find: float = 1.0
## 物品掉落倍率 - 击败敌人时掉落物品概率的倍数
@export var item_find: float = 1.0
## 经验获取倍率 - 获得经验值的倍数
@export var experience_gain: float = 1.0
## 物品品质加成 - 提升掉落物品品质的加成值
@export var item_quality: float = 0.0

## ========== 负重系统 ==========
@export_group("Inventory")
## 最大负重 - 角色能够携带物品的最大重量
@export var max_weight: float = 100.0
## 背包格子数 - 背包中可用的物品栏位数量
@export var inventory_slots: int = 20

## ========== 幸运影响系数 ==========
@export_group("Luck Scaling", "luck_")
## 幸运暴击加成 - 每点幸运值提升的暴击率
@export var luck_crit_bonus: float = 0.001
## 幸运闪避加成 - 每点幸运值提升的闪避率
@export var luck_dodge_bonus: float = 0.0005
## 幸运掉落加成 - 每点幸运值提升的物品掉落率
@export var luck_drop_bonus: float = 0.01
## 幸运品质加成 - 每点幸运值提升的物品品质
@export var luck_quality_bonus: float = 0.002


## 创建深拷贝
func duplicate_stats() -> StatsData:
	var copy = StatsData.new()
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copy.set(property.name, get(property.name))
	return copy
