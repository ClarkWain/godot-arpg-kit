class_name LootEntry
extends Resource
## 掉落条目
##
## 表示掉落表中的单个条目，定义物品及其掉落参数

## 掉落数量模式
enum QuantityMode {
	FIXED,        ## 固定数量
	RANDOM,       ## 随机范围
	WEIGHTED      ## 加权随机（基于幸运值）
}

## ========== 物品配置 ==========
@export_group("Item Config")
## 掉落的物品数据
@export var item_data: ItemData
## 掉落概率 (0.0 - 1.0，1.0 = 100%)
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0
## 掉落权重（用于加权随机选择）
@export var weight: int = 100

## ========== 数量配置 ==========
@export_group("Quantity")
## 数量模式
@export var quantity_mode: QuantityMode = QuantityMode.FIXED
## 最小数量
@export var min_quantity: int = 1
## 最大数量
@export var max_quantity: int = 1
## 固定数量（当 quantity_mode = FIXED 时使用）
@export var fixed_quantity: int = 1

## ========== 条件配置 ==========
@export_group("Conditions")
## 最低玩家等级要求
@export var min_player_level: int = 1
## 最高玩家等级限制（0表示无限制）
@export var max_player_level: int = 0
## 需要的标签（所有标签都必须满足）
@export var required_tags: Array[String] = []
## 排除的标签（有任一标签则不掉落）
@export var excluded_tags: Array[String] = []

## ========== 幸运值影响 ==========
@export_group("Luck Influence")
## 幸运值是否影响掉落概率
@export var luck_affects_chance: bool = true
## 每点幸运值的概率加成（默认0.5%）
@export var luck_chance_scaling: float = 0.005
## 幸运值是否影响掉落数量
@export var luck_affects_quantity: bool = false
## 每点幸运值的数量加成（百分比）
@export var luck_quantity_scaling: float = 0.01

## ========== 特殊配置 ==========
@export_group("Special")
## 是否保证掉落（忽略概率，必定掉落）
@export var guaranteed: bool = false
## 是否为唯一掉落（在掉落表中只能选择一次）
@export var unique: bool = false
## 掉落组ID（同组内只掉落一个）
@export var group_id: String = ""


## 计算最终掉落概率（考虑幸运值）
func get_final_drop_chance(luck_value: int) -> float:
	if guaranteed:
		return 1.0
	
	var final_chance = drop_chance
	
	if luck_affects_chance and luck_value > 0:
		final_chance = LuckSystem.get_luck_modified_chance(
			drop_chance,
			luck_value,
			luck_chance_scaling,
			1.0
		)
	
	return final_chance


## 计算掉落数量（考虑幸运值）
func get_drop_quantity(luck_value: int = 0) -> int:
	var base_quantity: int
	
	match quantity_mode:
		QuantityMode.FIXED:
			base_quantity = fixed_quantity
		QuantityMode.RANDOM:
			base_quantity = randi_range(min_quantity, max_quantity)
		QuantityMode.WEIGHTED:
			# 加权随机，幸运值越高越接近最大值
			var weight_factor = randf()
			if luck_value > 0:
				weight_factor = pow(weight_factor, 1.0 / (1.0 + luck_value * 0.01))
			base_quantity = int(lerp(min_quantity, max_quantity, weight_factor))
	
	# 应用幸运值数量加成
	if luck_affects_quantity and luck_value > 0:
		var multiplier = 1.0 + (luck_value * luck_quantity_scaling)
		base_quantity = int(base_quantity * multiplier)
	
	return max(1, base_quantity)


## 检查条件是否满足
func check_conditions(player_level: int, context_tags: Array[String]) -> bool:
	# 检查等级要求
	if player_level < min_player_level:
		return false
	
	if max_player_level > 0 and player_level > max_player_level:
		return false
	
	# 检查必需标签
	for tag in required_tags:
		if tag not in context_tags:
			return false
	
	# 检查排除标签
	for tag in excluded_tags:
		if tag in context_tags:
			return false
	
	return true


## 检查是否触发掉落
func roll_drop(luck_value: int = 0) -> bool:
	if guaranteed:
		return true
	
	var chance = get_final_drop_chance(luck_value)
	return randf() < chance


## 创建物品实例
func create_item_instance(luck_value: int = 0) -> ItemInstance:
	if not item_data:
		return null
	
	var quantity = get_drop_quantity(luck_value)
	return ItemInstance.create(item_data, quantity)