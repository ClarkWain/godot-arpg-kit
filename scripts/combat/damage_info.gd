## 伤害信息数据类
## 封装一次攻击的所有伤害相关信息
class_name DamageInfo
extends RefCounted

## 伤害类型
enum DamageType {
	PHYSICAL,    # 物理伤害
	MAGICAL,     # 魔法伤害
	FIRE,        # 火焰伤害
	ICE,         # 冰霜伤害
	LIGHTNING,   # 雷电伤害
	POISON,      # 毒素伤害
	TRUE         # 真实伤害（无视防御）
}

## 攻击来源
var source: Node = null

## 攻击目标
var target: Node = null

## 基础伤害
var base_damage: float = 0.0

## 最终伤害
var final_damage: float = 0.0

## 伤害类型
var damage_type: DamageType = DamageType.PHYSICAL

## 是否暴击
var is_critical: bool = false

## 暴击倍率
var critical_multiplier: float = 1.0

## 击退力度
var knockback_force: Vector2 = Vector2.ZERO

## 击退方向
var knockback_direction: Vector2 = Vector2.ZERO

## 附加的状态效果ID列表
var status_effects: Array[String] = []

## 技能ID（如果来自技能）
var skill_id: String = ""

## 是否被格挡
var is_blocked: bool = false

## 是否被闪避
var is_dodged: bool = false

## 是否被吸收（护盾）
var is_absorbed: bool = false

## 吸收的伤害量
var absorbed_damage: float = 0.0

## 元素反应类型
var elemental_reaction: String = ""

## 额外数据
var metadata: Dictionary = {}

## 构造函数
func _init(src: Node = null, tgt: Node = null, dmg: float = 0.0, type: DamageType = DamageType.PHYSICAL) -> void:
	source = src
	target = tgt
	base_damage = dmg
	damage_type = type

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"base_damage": base_damage,
		"final_damage": final_damage,
		"damage_type": DamageType.keys()[damage_type],
		"is_critical": is_critical,
		"critical_multiplier": critical_multiplier,
		"knockback_force": knockback_force,
		"is_blocked": is_blocked,
		"is_dodged": is_dodged,
		"is_absorbed": is_absorbed,
		"absorbed_damage": absorbed_damage,
		"elemental_reaction": elemental_reaction,
		"status_effects": status_effects,
		"skill_id": skill_id
	}

## 获取伤害类型颜色（用于UI显示）
func get_damage_type_color() -> Color:
	match damage_type:
		DamageType.PHYSICAL:
			return Color.WHITE
		DamageType.MAGICAL:
			return Color.CYAN
		DamageType.FIRE:
			return Color.ORANGE_RED
		DamageType.ICE:
			return Color.LIGHT_BLUE
		DamageType.LIGHTNING:
			return Color.YELLOW
		DamageType.POISON:
			return Color.GREEN
		DamageType.TRUE:
			return Color.PURPLE
		_:
			return Color.WHITE
