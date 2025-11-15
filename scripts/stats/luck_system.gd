class_name LuckSystem
extends Node
## 幸运系统
##
## 提供幸运值影响各种随机事件的工具方法

## 幸运影响的事件类型
enum LuckEffect {
	CRITICAL_HIT,      # 暴击率
	DODGE,             # 闪避率
	BLOCK,             # 格挡率
	PROC_CHANCE,       # 特效触发率
	ITEM_DROP_RATE,    # 物品掉落率
	RARE_ITEM_CHANCE,  # 稀有度提升
	GOLD_AMOUNT,       # 金币数量
	EXTRA_DROP,        # 额外掉落
	ITEM_QUALITY,      # 物品品质
	AFFIX_COUNT,       # 词缀数量
	AFFIX_TIER,        # 词缀等级
	CHEST_QUALITY,     # 宝箱品质
	SHOP_REFRESH,      # 商店刷新品质
	CRAFTING_SUCCESS,  # 制作成功率
	UPGRADE_SUCCESS,   # 升级成功率
	SECRET_DISCOVERY,  # 发现隐藏内容
	TRAP_AVOIDANCE,    # 避免陷阱
	BETTER_ROLLS,      # 更好的随机结果
}


## 计算带幸运加成的概率
static func get_luck_modified_chance(
	base_chance: float,      # 基础概率 (0-1)
	luck_value: int,         # 幸运值
	luck_per_point: float,   # 每点幸运的加成
	max_chance: float = 1.0  # 最大概率上限
) -> float:
	var luck_bonus = luck_value * luck_per_point
	return min(base_chance + luck_bonus, max_chance)


## 幸运检定 - 判断是否触发
static func luck_check(
	base_chance: float,
	luck_value: int,
	luck_scaling: float = 0.01  # 默认每点幸运 +1%
) -> bool:
	var final_chance = get_luck_modified_chance(base_chance, luck_value, luck_scaling)
	return randf() < final_chance


## 计算幸运影响的数值(如金币数量)
static func apply_luck_to_value(
	base_value: float,
	luck_value: int,
	luck_scaling: float = 0.01  # 每点幸运 +1%
) -> float:
	var multiplier = 1.0 + (luck_value * luck_scaling)
	return base_value * multiplier


## 物品稀有度提升检定
static func get_luck_rarity_boost(luck_value: int) -> int:
	# 每20点幸运有10%概率提升一个稀有度等级
	var boost_chance = (luck_value / 20.0) * 0.1
	var boost_level = 0
	
	while randf() < boost_chance and boost_level < 3:  # 最多提升3级
		boost_level += 1
		boost_chance *= 0.5  # 每次提升后概率减半
	
	return boost_level


## 幸运值软上限 - 防止无限堆叠
static func get_effective_luck(raw_luck: int) -> float:
	if raw_luck <= 100:
		return raw_luck
	else:
		# 超过100后收益递减
		return 100.0 + sqrt(raw_luck - 100)


## 计算额外掉落概率
static func get_extra_drop_chance(luck_value: int) -> float:
	# 基础5% + 每10点幸运增加1%
	return 0.05 + (luck_value / 10.0) * 0.01


## 幸运影响物品品质 (属性范围)
static func get_quality_multiplier(luck_value: int, base_scaling: float = 0.002) -> float:
	# 每点幸运 +0.2% 品质
	return 1.0 + (luck_value * base_scaling)
