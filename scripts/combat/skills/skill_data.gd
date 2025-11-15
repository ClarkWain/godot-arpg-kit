## 技能数据
## Resource类，定义一个技能的配置
class_name SkillData
extends Resource

## 技能类型
enum SkillType {
	ACTIVE,      # 主动技能
	PASSIVE,     # 被动技能
	TOGGLE,      # 切换技能
	TRIGGERED    # 触发技能
}

## 目标类型
enum TargetType {
	SELF,           # 自身
	ENEMY,          # 敌人
	ALLY,           # 友方
	GROUND,         # 地面位置
	DIRECTION,      # 方向
	AREA            # 区域
}

## 技能唯一ID
@export var skill_id: String = ""

## 技能名称
@export var skill_name: String = ""

## 技能描述
@export var description: String = ""

## 技能图标
@export var icon: Texture2D = null

## 技能类型
@export var skill_type: SkillType = SkillType.ACTIVE

## 目标类型
@export var target_type: TargetType = TargetType.ENEMY

## 冷却时间（秒）
@export var cooldown: float = 5.0

## 魔法消耗
@export var mana_cost: float = 0.0

## 体力消耗
@export var stamina_cost: float = 0.0

## 施法时间（秒，0表示瞬发）
@export var cast_time: float = 0.0

## 引导时间（秒，持续施法）
@export var channel_time: float = 0.0

## 施法距离
@export var cast_range: float = 300.0

## 技能范围（用于AOE）
@export var skill_radius: float = 0.0

## 基础伤害
@export var base_damage: float = 0.0

## 伤害类型
@export var damage_type: DamageInfo.DamageType = DamageInfo.DamageType.PHYSICAL

## 伤害系数（属性加成）
@export var damage_scaling: float = 1.0

## 击退力度
@export var knockback_force: float = 0.0

## 附加状态效果
@export var status_effects: Array[String] = []

## 状态效果触发概率（0-1）
@export var status_effect_chance: float = 1.0

## 投射物场景（如果是投射物技能）
@export var projectile_scene: PackedScene = null

## 投射物速度
@export var projectile_speed: float = 500.0

## 投射物数量
@export var projectile_count: int = 1

## AOE场景（如果是范围技能）
@export var aoe_scene: PackedScene = null

## 特效场景
@export var vfx_scene: PackedScene = null

## 音效
@export var sfx: AudioStream = null

## 动画名称
@export var animation_name: String = ""

## 技能标签
@export var tags: Array[String] = []

## 是否可以移动施法
@export var can_cast_while_moving: bool = false

## 自定义数据
@export var custom_data: Dictionary = {}

## 验证数据
func validate() -> bool:
	if skill_id.is_empty():
		push_error("SkillData: skill_id is empty")
		return false
	
	if cooldown < 0:
		push_warning("SkillData: cooldown is negative for %s" % skill_id)
		cooldown = 0
	
	return true

## 获取完整描述（包含数值）
func get_full_description() -> String:
	var full_desc = description
	
	# 替换占位符
	full_desc = full_desc.replace("{damage}", str(base_damage))
	full_desc = full_desc.replace("{cooldown}", str(cooldown))
	full_desc = full_desc.replace("{mana}", str(mana_cost))
	full_desc = full_desc.replace("{range}", str(cast_range))
	
	return full_desc
