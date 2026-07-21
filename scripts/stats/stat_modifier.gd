class_name StatModifier
extends Resource
## 属性修正器
##
## 用于临时或永久修改角色属性
## 支持固定值、百分比、覆盖三种类型

## 修正器类型
enum ModifierType {
	FLAT,       ## 固定值加成: +10 攻击力
	PERCENT,    ## 百分比加成: +20% 攻击力 (传入 0.2)
	OVERRIDE    ## 覆盖值: 直接设置为指定值
}

## 属性类型枚举
enum StatType {
	# 等级与成长
	LEVEL,              ## 角色等级
	EXPERIENCE,         ## 当前经验值
	STAT_POINTS,        ## 可分配的属性点
	
	# 核心属性
	STRENGTH,           ## 力量 - 影响物理伤害和生命值
	AGILITY,            ## 敏捷 - 影响攻速、闪避和暴击率
	INTELLIGENCE,       ## 智力 - 影响魔法伤害和法力值
	VITALITY,           ## 体质 - 影响生命值和防御力
	LUCK,               ## 幸运 - 影响暴击、闪避和掉落品质
	
	# 生存属性
	MAX_HEALTH,         ## 最大生命值
	MAX_MANA,           ## 最大法力值
	MAX_STAMINA,        ## 最大耐力值
	
	# 攻击属性
	PHYSICAL_DAMAGE,    ## 物理攻击力
	MAGIC_DAMAGE,       ## 魔法攻击力
	FIRE_DAMAGE,        ## 火焰伤害
	ICE_DAMAGE,         ## 冰霜伤害
	LIGHTNING_DAMAGE,   ## 闪电伤害
	POISON_DAMAGE,      ## 毒素伤害
	DARK_DAMAGE,        ## 暗影伤害
	HOLY_DAMAGE,        ## 神圣伤害
	ATTACK_SPEED,       ## 物理攻击速度(攻击/秒)
	CAST_SPEED,         ## 施法速度(倍率)
	CRIT_CHANCE,        ## 暴击率(0-1范围)
	CRIT_DAMAGE,        ## 暴击伤害倍率
	ACCURACY,           ## 命中率(0-1范围)
	
	# 物理防御
	ARMOR,              ## 物理护甲值
	DODGE_CHANCE,       ## 闪避率(通用,0-1范围)
	BLOCK_CHANCE,       ## 物理格挡率(主动格挡时生效,0-1范围)
	BLOCK_AMOUNT,       ## 物理格挡固定减伤值
	BLOCK_REDUCTION,    ## 物理格挡百分比减伤(0-1范围)
	PHYSICAL_DAMAGE_REDUCTION,  ## 物理伤害百分比减免(0-1范围)
	
	# 魔法防御
	MAGIC_RESIST,       ## 魔法抗性值
	SPELL_BLOCK_CHANCE, ## 法术格挡率(主动格挡时生效,0-1范围)
	MAGIC_DAMAGE_REDUCTION,     ## 魔法伤害百分比减免(0-1范围)
	
	# 元素抗性
	RES_FIRE,           ## 火焰抗性(0-1范围)
	RES_ICE,            ## 冰霜抗性(0-1范围)
	RES_LIGHTNING,      ## 闪电抗性(0-1范围)
	RES_POISON,         ## 毒素抗性(0-1范围)
	RES_DARK,           ## 暗影抗性(0-1范围)
	RES_HOLY,           ## 神圣抗性(0-1范围)
	RES_ALL,            ## 全元素抗性(0-1范围)
	
	# 状态抗性
	STATUS_RES_STUN,    ## 眩晕抗性(降低持续时间,0-1范围)
	STATUS_RES_FREEZE,  ## 冻结抗性(降低持续时间,0-1范围)
	STATUS_RES_BURN,    ## 灼烧抗性(降低持续时间,0-1范围)
	STATUS_RES_POISON,  ## 中毒抗性(降低持续时间,0-1范围)
	STATUS_RES_BLEED,   ## 流血抗性(降低持续时间,0-1范围)
	STATUS_RES_SLOW,    ## 减速抗性(降低持续时间,0-1范围)
	
	# 移动属性
	MOVE_SPEED,         ## 基础移动速度(像素/秒)
	SPRINT_SPEED,       ## 冲刺移动速度(像素/秒)
	DASH_SPEED,         ## 闪避突进速度(像素/秒)
	DASH_DISTANCE,      ## 闪避突进距离(像素)
	
	# 多层防御
	MAX_ENERGY_SHIELD,  ## 能量护盾最大值
	ENERGY_SHIELD_REGEN,            ## 能量护盾每秒回复量
	ENERGY_SHIELD_RECHARGE_DELAY,   ## 能量护盾充能延迟(秒)
	DAMAGE_ABSORB_AMOUNT,           ## 伤害吸收固定值
	DAMAGE_ABSORB_PERCENT,          ## 伤害吸收百分比(0-1范围)
	DAMAGE_REFLECT_AMOUNT,          ## 伤害反弹固定值
	DAMAGE_REFLECT_PERCENT,         ## 伤害反弹百分比(0-1范围)
	
	# 回复属性
	HEALTH_REGEN,       ## 生命回复(每秒)
	MANA_REGEN,         ## 魔力回复(每秒)
	STAMINA_REGEN,      ## 耐力回复(每秒)
	
	# 特殊属性
	LIFE_STEAL,         ## 生命偷取率(0-1范围)
	MANA_STEAL,         ## 法力偷取率(0-1范围)
	COOLDOWN_REDUCTION, ## 技能冷却缩减(0-1范围)
	SKILL_RANGE,        ## 技能范围倍率
	PROJECTILE_COUNT,   ## 额外投射物数量
	PIERCE_COUNT,       ## 投射物穿透次数
	
	# 掉落与奖励
	GOLD_FIND,          ## 金币掉落加成(倍率)
	ITEM_FIND,          ## 物品掉落率加成(倍率)
	EXPERIENCE_GAIN,    ## 经验获取加成(倍率)
	ITEM_QUALITY,       ## 物品品质加成(提升稀有度概率)
	
	# 负重系统
	MAX_WEIGHT,         ## 最大负重
	INVENTORY_SLOTS,    ## 背包格子数量

	# 攻击穿透（追加在末尾，避免打乱已有资源的枚举编号）
	ARMOR_PENETRATION,          ## 护甲穿透率(0-1范围) - 攻击者忽略目标护甲的百分比
	MAGIC_PENETRATION,          ## 法术穿透率(0-1范围) - 攻击者忽略目标魔抗的百分比
}

# 元素类型枚举
enum ElementType {
	NONE,		# 无元素
	FIRE,		# 火焰
	ICE,		# 冰霜
	LIGHTNING,	# 闪电
	POISON,		# 毒素
	DARK,		# 暗影
	HOLY,		# 神圣
}

## 修正的属性类型
@export var stat_type: StatType

## 修正器类型
@export var modifier_type: ModifierType

## 修正值
@export var value: float

## 来源标识 (用于移除特定来源的修正器)
@export var source_id: String = ""

## 标签 (用于分类和批量操作)
@export var tags: Array[String] = []

## 持续时间 (-1 表示永久)
@export var duration: float = -1.0

## 优先级 (数值越大越优先计算,用于特殊情况)
@export var priority: int = 0


## 工厂方法: 创建固定值修正器
static func create_flat(stat: StatType, new_value: float, source: String = "") -> StatModifier:
	var mod = StatModifier.new()
	mod.stat_type = stat
	mod.modifier_type = ModifierType.FLAT
	mod.value = new_value
	mod.source_id = source
	return mod


## 工厂方法: 创建百分比修正器
static func create_percent(stat: StatType, new_value: float, source: String = "") -> StatModifier:
	var mod = StatModifier.new()
	mod.stat_type = stat
	mod.modifier_type = ModifierType.PERCENT
	mod.value = new_value
	mod.source_id = source
	return mod


## 工厂方法: 创建覆盖值修正器
static func create_override(stat: StatType, new_value: float, source: String = "") -> StatModifier:
	var mod = StatModifier.new()
	mod.stat_type = stat
	mod.modifier_type = ModifierType.OVERRIDE
	mod.value = new_value
	mod.source_id = source
	return mod


## 添加标签
func add_tag(tag: String) -> StatModifier:
	if tag not in tags:
		tags.append(tag)
	return self


## 设置持续时间
func set_duration(time: float) -> StatModifier:
	duration = time
	return self


## 设置优先级
func set_priority(p: int) -> StatModifier:
	priority = p
	return self


## 获取描述文本
func get_description() -> String:
	var stat_name = StatType.keys()[stat_type]
	var mod_text = ""
	
	match modifier_type:
		ModifierType.FLAT:
			mod_text = "%+.1f" % value
		ModifierType.PERCENT:
			mod_text = "%+.1f%%" % (value * 100)
		ModifierType.OVERRIDE:
			mod_text = "= %.1f" % value
	
	return "%s %s" % [mod_text, stat_name]
