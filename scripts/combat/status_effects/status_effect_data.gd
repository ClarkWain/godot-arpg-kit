## 状态效果数据
## Resource类，定义一个状态效果（Buff/Debuff）的配置
class_name StatusEffectData
extends Resource

## 状态效果类型
enum EffectType {
	BUFF,        # 增益
	DEBUFF,      # 减益
	CONTROL,     # 控制
	DOT,         # 持续伤害
	HOT,         # 持续治疗
	SPECIAL      # 特殊效果
}

## 叠加类型
enum StackType {
	NONE,           # 不可叠加（覆盖）
	STACK_COUNT,    # 叠加层数
	INDEPENDENT,    # 独立实例
	REFRESH         # 刷新时间
}

## 效果唯一ID
@export var effect_id: String = ""

## 效果名称
@export var effect_name: String = ""

## 效果描述
@export var description: String = ""

## 效果图标
@export var icon: Texture2D = null

## 效果类型
@export var effect_type: EffectType = EffectType.BUFF

## 持续时间（秒，0表示永久）
@export var duration: float = 10.0

## Tick间隔（秒，用于DOT/HOT）
@export var tick_interval: float = 1.0

## 叠加类型
@export var stack_type: StackType = StackType.REFRESH

## 最大叠加层数
@export var max_stacks: int = 1

## 属性修改器列表
@export var modifiers: Array[StatModifier] = []

## 每次Tick时的伤害/治疗量
@export var tick_value: float = 0.0

## Tick时的伤害类型（用于DOT）
@export var tick_damage_type: DamageInfo.DamageType = DamageInfo.DamageType.PHYSICAL

## 是否可以被净化
@export var can_be_cleansed: bool = true

## 是否隐藏（不显示在UI中）
@export var hidden: bool = false

## 优先级（用于排序显示）
@export var priority: int = 0

## 元素类型（用于元素反应）
@export var element: StatModifier.ElementType = StatModifier.ElementType.NONE

## 应用时触发的效果ID列表
@export var on_apply_effects: Array[String] = []

## 移除时触发的效果ID列表
@export var on_remove_effects: Array[String] = []

## 自定义数据
@export var custom_data: Dictionary = {}

## 获取效果类型颜色
func get_type_color() -> Color:
	match effect_type:
		EffectType.BUFF:
			return Color.GREEN
		EffectType.DEBUFF:
			return Color.RED
		EffectType.CONTROL:
			return Color.ORANGE
		EffectType.DOT:
			return Color.PURPLE
		EffectType.HOT:
			return Color.LIGHT_GREEN
		EffectType.SPECIAL:
			return Color.CYAN
		_:
			return Color.WHITE

## 验证数据完整性
func validate() -> bool:
	if effect_id.is_empty():
		push_error("StatusEffectData: effect_id is empty")
		return false
	
	if duration < 0:
		push_warning("StatusEffectData: duration is negative for %s" % effect_id)
		duration = 0
	
	if tick_interval <= 0 and (effect_type == EffectType.DOT or effect_type == EffectType.HOT):
		push_warning("StatusEffectData: tick_interval is invalid for DOT/HOT effect %s" % effect_id)
		tick_interval = 1.0
	
	return true
