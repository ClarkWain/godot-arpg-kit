# res://scripts/items/item_data.gd
class_name ItemData
extends Resource
## 物品基础数据类
##
## 所有物品的基类,定义物品的通用属性
## 使用 Resource 资源类型,可以在编辑器中创建 .tres 文件

## 物品类型枚举
enum ItemType {
	CONSUMABLE,   ## 消耗品 - 药水、食物等
	EQUIPMENT,    ## 装备 - 武器、防具、饰品
	MATERIAL,     ## 材料 - 合成材料、制作材料
	QUEST,        ## 任务物品 - 任务专用道具
	CURRENCY      ## 货币 - 金币、宝石等特殊货币
}

## 物品稀有度枚举
enum Rarity {
	COMMON,       ## 普通 (白色)
	UNCOMMON,     ## 非凡 (绿色)
	RARE,         ## 稀有 (蓝色)
	EPIC,         ## 史诗 (紫色)
	LEGENDARY,    ## 传说 (橙色)
	MYTHIC        ## 神话 (红色)
}

## ========== 基础信息 ==========
@export_group("Basic Info")
## 物品唯一标识符 (用于存档、网络同步等)
@export var id: String = ""
## 物品显示名称
@export var item_name: String = ""
## 物品描述文本
@export_multiline var description: String = ""
## 物品图标
@export var icon: Texture2D
## 物品类型
@export var item_type: ItemType = ItemType.MATERIAL
## 物品稀有度
@export var rarity: Rarity = Rarity.COMMON

## ========== 堆叠与重量 ==========
@export_group("Stack & Weight")
## 最大堆叠数量 (1 表示不可堆叠)
@export var max_stack: int = 1
## 单个物品重量
@export var weight: float = 0.0

## ========== 价值与交易 ==========
@export_group("Value & Trading")
## 基础价值(金币)
@export var base_value: int = 1
## 是否可以出售给商人
@export var can_sell: bool = true
## 是否可以丢弃
@export var can_drop: bool = true
## 是否可以交易给其他玩家
@export var can_trade: bool = true

## ========== 标签系统 ==========
@export_group("Tags")
## 物品标签 (用于分类、过滤、配方系统等)
@export var tags: Array[String] = []


## 获取稀有度对应的显示颜色
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color.WHITE
		Rarity.UNCOMMON: return Color.GREEN
		Rarity.RARE: return Color.DODGER_BLUE
		Rarity.EPIC: return Color.PURPLE
		Rarity.LEGENDARY: return Color.ORANGE
		Rarity.MYTHIC: return Color.RED
	return Color.WHITE


## 获取稀有度名称
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "普通"
		Rarity.UNCOMMON: return "非凡"
		Rarity.RARE: return "稀有"
		Rarity.EPIC: return "史诗"
		Rarity.LEGENDARY: return "传说"
		Rarity.MYTHIC: return "神话"
	return "未知"


## 获取出售价格 (通常是基础价值的50%)
func get_sell_price() -> int:
	if not can_sell:
		return 0
	return int(base_value * 0.5)


## 检查是否包含指定标签
func has_tag(tag: String) -> bool:
	return tag in tags


## 添加标签
func add_tag(tag: String) -> void:
	if not has_tag(tag):
		tags.append(tag)


## 移除标签
func remove_tag(tag: String) -> void:
	if has_tag(tag):
		tags.erase(tag)


## 获取完整的物品描述 (用于 UI 显示)
func get_full_description() -> String:
	var desc = "[b]%s[/b]\n" % item_name
	desc += "[color=#%s]%s[/color]\n" % [get_rarity_color().to_html(), get_rarity_name()]
	desc += "\n%s\n" % description
	
	if weight > 0:
		desc += "\n重量: %.1f" % weight
	
	if can_sell:
		desc += "\n售价: %d 金币" % get_sell_price()
	
	return desc
