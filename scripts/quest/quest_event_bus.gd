## 任务事件总线
## 用于游戏事件与任务系统之间的解耦通信
extends Node

## 单例实例
static var instance: QuestEventBus = null

## ========== 战斗相关事件 ==========

## 敌人被击杀
signal enemy_killed(enemy_type: String, enemy_id: String, enemy_level: int)

## 造成伤害
signal damage_dealt(target_type: String, damage: float)

## 受到伤害
signal damage_received(source_type: String, damage: float)

## ========== 收集相关事件 ==========

## 物品被收集
signal item_collected(item_id: String, quantity: int)

## 物品被使用
signal item_used(item_id: String, quantity: int)

## 物品被装备
signal item_equipped(item_id: String, slot: String)

## 物品被卸下
signal item_unequipped(item_id: String, slot: String)

## ========== 交互相关事件 ==========

## 与NPC对话
signal npc_talked(npc_id: String, dialogue_id: String)

## 与物体交互
signal object_interacted(object_id: String, interaction_type: String)

## 到达位置
signal location_reached(location_id: String, position: Vector2)

## ========== 玩家状态事件 ==========

## 等级提升
signal player_level_up(old_level: int, new_level: int)

## 属性变化
signal stat_changed(stat_name: String, old_value: float, new_value: float)

## 技能学习
signal skill_learned(skill_id: String)

## 技能使用
signal skill_used(skill_id: String, target: Node)

## ========== 任务相关事件 ==========

## 任务接取
signal quest_accepted(quest_id: String)

## 任务完成
signal quest_completed(quest_id: String)

## 任务失败
signal quest_failed(quest_id: String)

## ========== 其他事件 ==========

## 金币变化
signal currency_changed(currency_type: String, amount: int, total: int)

## 时间流逝
signal time_passed(hours: float)

## 自定义事件
signal custom_event(event_type: String, event_data: Dictionary)

func _ready() -> void:
	if instance == null:
		instance = self
		_connect_to_task_manager()
	else:
		push_warning("QuestEventBus instance already exists!")

## 连接到任务管理器
func _connect_to_task_manager() -> void:
	# 等待任务管理器准备好
	await get_tree().process_frame
	
	var task_manager = get_node_or_null("/root/TaskManager")
	if not task_manager:
		push_warning("TaskManager not found in scene tree")
		return
	
	# 连接所有事件到专用处理函数
	enemy_killed.connect(_on_enemy_killed)
	item_collected.connect(_on_item_collected)
	item_equipped.connect(_on_item_equipped)
	location_reached.connect(_on_location_reached)
	npc_talked.connect(_on_npc_talked)
	player_level_up.connect(_on_level_up)
	stat_changed.connect(_on_stat_changed)

## 敌人击杀事件处理
func _on_enemy_killed(enemy_type: String, enemy_id: String, enemy_level: int) -> void:
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.update_task_progress({
			"type": "kill_enemy",
			"target_id": enemy_type,
			"enemy_id": enemy_id,
			"enemy_level": enemy_level,
			"count": 1
		})

## 物品收集事件处理
func _on_item_collected(item_id: String, quantity: int) -> void:
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.update_task_progress({
			"type": "collect_item",
			"target_id": item_id,
			"count": quantity
		})

## 物品装备事件处理
func _on_item_equipped(item_id: String, slot: String) -> void:
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.update_task_progress({
			"type": "equip_item",
			"target_id": item_id,
			"slot": slot,
			"state": item_id
		})

## 位置到达事件处理
func _on_location_reached(location_id: String, position: Vector2) -> void:
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.update_task_progress({
			"type": "location",
			"target_id": location_id,
			"state": location_id,
			"position": position
		})

## NPC对话事件处理
func _on_npc_talked(npc_id: String, dialogue_id: String) -> void:
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.update_task_progress({
			"type": "talk_npc",
			"target_id": npc_id,
			"dialogue_id": dialogue_id,
			"count": 1
		})

## 等级提升事件处理
func _on_level_up(old_level: int, new_level: int) -> void:
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.update_task_progress({
			"type": "level",
			"state": str(new_level),
			"old_level": old_level,
			"new_level": new_level
		})

## 属性变化事件处理
func _on_stat_changed(stat_name: String, old_value: float, new_value: float) -> void:
	var task_manager = get_node_or_null("/root/TaskManager")
	if task_manager:
		task_manager.update_task_progress({
			"type": "stat",
			"target_id": stat_name,
			"state": str(new_value),
			"old_value": old_value,
			"new_value": new_value
		})

## ========== 便捷方法 ==========

## 触发敌人击杀事件
static func emit_enemy_killed(enemy_type: String, enemy_id: String = "", enemy_level: int = 1) -> void:
	if instance:
		instance.enemy_killed.emit(enemy_type, enemy_id, enemy_level)

## 触发物品收集事件
static func emit_item_collected(item_id: String, quantity: int = 1) -> void:
	if instance:
		instance.item_collected.emit(item_id, quantity)

## 触发位置到达事件
static func emit_location_reached(location_id: String, position: Vector2 = Vector2.ZERO) -> void:
	if instance:
		instance.location_reached.emit(location_id, position)

## 触发NPC对话事件
static func emit_npc_talked(npc_id: String, dialogue_id: String = "") -> void:
	if instance:
		instance.npc_talked.emit(npc_id, dialogue_id)

## 触发自定义事件
static func emit_custom(event_type: String, event_data: Dictionary = {}) -> void:
	if instance:
		instance.custom_event.emit(event_type, event_data)
		# 同时更新任务进度
		var task_manager = instance.get_node_or_null("/root/TaskManager")
		if task_manager:
			event_data["type"] = event_type
			task_manager.update_task_progress(event_data)