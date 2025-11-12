## 任务系统示例场景脚本
extends Node2D

@onready var task_manager: TaskManager = $TaskManager
@onready var event_bus: Node = $QuestEventBus
@onready var task_info: RichTextLabel = $UI/Panel/VBoxContainer/TaskInfo

var current_task_id: String = "kill_slimes"
var mock_player: Node = null

func _ready() -> void:
	# 创建模拟玩家
	mock_player = Node.new()
	mock_player.name = "MockPlayer"
	mock_player.set_script(preload("res://scripts/quest/examples/mock_player.gd"))
	add_child(mock_player)
	
	# 设置任务管理器的玩家引用
	task_manager.set_player(mock_player)
	
	# 注册示例任务
	var ExampleTasks = preload("res://scripts/quest/examples/example_tasks.gd")
	ExampleTasks.register_all_examples(task_manager)
	
	# 连接任务管理器信号
	task_manager.task_accepted.connect(_on_task_accepted)
	task_manager.task_updated.connect(_on_task_updated)
	task_manager.task_completed.connect(_on_task_completed)
	task_manager.task_claimed.connect(_on_task_claimed)
	
	# 更新UI
	_update_task_info()

func _on_accept_task_pressed() -> void:
	if task_manager.accept_task(current_task_id):
		_log("成功接取任务: " + current_task_id)
	else:
		_log("无法接取任务: " + current_task_id)
	_update_task_info()

func _on_kill_slime_pressed() -> void:
	# 模拟击杀史莱姆事件
	QuestEventBus.emit_enemy_killed("slime", "slime_001", 1)
	_log("击杀了1只史莱姆")
	_update_task_info()

func _on_complete_task_pressed() -> void:
	var instance = task_manager.get_task_instance(current_task_id)
	if instance and instance.state == TaskState.State.COMPLETED:
		_log("任务已完成,可以领取奖励")
	else:
		_log("任务尚未完成")
	_update_task_info()

func _on_claim_reward_pressed() -> void:
	if task_manager.claim_rewards(current_task_id):
		_log("成功领取奖励!")
	else:
		_log("无法领取奖励")
	_update_task_info()

func _on_task_accepted(task_id: String) -> void:
	_log("[事件] 任务已接取: " + task_id)

func _on_task_updated(task_id: String, progress: float) -> void:
	_log("[事件] 任务进度更新: %s - %.1f%%" % [task_id, progress * 100])

func _on_task_completed(task_id: String) -> void:
	_log("[事件] 任务已完成: " + task_id)

func _on_task_claimed(task_id: String) -> void:
	_log("[事件] 奖励已领取: " + task_id)

func _update_task_info() -> void:
	var instance = task_manager.get_task_instance(current_task_id)
	
	if not instance:
		task_info.text = "[color=yellow]任务尚未接取[/color]\n\n点击'接取任务'按钮开始。"
		return
	
	var task_data = instance.task_data
	var text = ""
	
	# 任务基本信息
	text += "[b][color=cyan]%s[/color][/b]\n" % task_data.task_name
	text += "[color=gray]%s[/color]\n\n" % task_data.description
	
	# 任务状态
	text += "[b]状态:[/b] [color=yellow]%s[/color]\n" % TaskState.get_state_name(instance.state)
	text += "[b]总进度:[/b] %.1f%%\n\n" % (instance.get_overall_progress() * 100)
	
	# 目标列表
	text += "[b]目标:[/b]\n"
	for obj in instance.objectives:
		var status = "[color=green]✓[/color]" if obj.is_completed else "[color=red]✗[/color]"
		var optional = " [color=gray](可选)[/color]" if obj.optional else ""
		text += "  %s %s - %s%s\n" % [status, obj.description, obj.get_progress_text(), optional]
	
	# 奖励列表
	if not task_data.rewards.is_empty():
		text += "\n[b]奖励:[/b]\n"
		for reward in task_data.rewards:
			text += "  • %s\n" % reward.get_preview_text()
	
	# 可选奖励
	if not task_data.optional_rewards.is_empty():
		text += "\n[b]可选奖励(选择其一):[/b]\n"
		for reward in task_data.optional_rewards:
			text += "  • %s\n" % reward.get_preview_text()
	
	task_info.text = text

func _log(message: String) -> void:
	print("[QuestExample] " + message)