class_name DroppedItem
extends Area2D
## 掉落物实体
##
## 表示场景中的掉落物品，玩家可以拾取
## 支持磁吸、自动消失、视觉效果等

## 掉落物状态
enum State {
	SPAWNING,     ## 生成中（抛出动画）
	IDLE,         ## 静止等待拾取
	ATTRACTING,   ## 被吸引中（磁吸效果）
	PICKED_UP,    ## 已被拾取
	DESPAWNING    ## 消失中
}

## ========== 信号 ==========
## 物品被拾取
signal item_picked_up(item: ItemInstance, picker: Node2D)
## 物品消失
signal item_despawned(item: ItemInstance)

## ========== 核心数据 ==========
## 物品实例
var item_instance: ItemInstance
## 金币数量（如果是金币掉落）
var gold_amount: int = 0
## 当前状态
var current_state: State = State.SPAWNING

## ========== 配置选项 ==========
@export_group("Pickup Settings")
## 玩家拾取层（collision layer）
@export_flags_2d_physics var player_layer: int = 1
## 拾取范围（Area2D 的碰撞半径）
@export var pickup_radius: float = 32.0
## 是否启用磁吸效果
@export var enable_magnetism: bool = true
## 磁吸范围（超过拾取范围）
@export var magnet_radius: float = 128.0
## 磁吸速度
@export var magnet_speed: float = 200.0

@export_group("Spawn Settings")
## 生成时的抛出力度
@export var spawn_force: Vector2 = Vector2(100, -200)
## 生成时的随机偏移
@export var spawn_randomness: float = 50.0
## 重力加速度
@export var item_gravity: float = 980.0
## 地面反弹系数
@export var bounce_damping: float = 0.5

@export_group("Despawn Settings")
## 是否自动消失
@export var auto_despawn: bool = true
## 自动消失时间（秒）
@export var despawn_time: float = 30.0
## 消失前闪烁时间（秒）
@export var blink_before_despawn: float = 5.0
## 闪烁频率（次/秒）
@export var blink_frequency: float = 4.0

@export_group("Visual Settings")
## 物品精灵节点路径
@export var sprite_path: NodePath = "Sprite2D"
## 稀有度光晕节点路径
@export var glow_path: NodePath = "Glow"
## 拾取粒子效果
@export var pickup_particles: PackedScene

## ========== 内部变量 ==========
var _velocity: Vector2 = Vector2.ZERO
var _is_on_ground: bool = false
var _spawn_timer: float = 0.0
var _despawn_timer: float = 0.0
var _blink_timer: float = 0.0
var _target_player: Node2D = null

## 节点引用
@onready var sprite: Sprite2D = get_node_or_null(sprite_path)
@onready var glow: Sprite2D = get_node_or_null(glow_path)
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready():
	# 设置碰撞层
	collision_layer = 0
	collision_mask = player_layer
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 初始化视觉效果
	_update_visual()
	
	# 开始生成动画
	_start_spawn_animation()


func _process(delta: float):
	match current_state:
		State.SPAWNING:
			_process_spawning(delta)
		State.IDLE:
			_process_idle(delta)
		State.ATTRACTING:
			_process_attracting(delta)
		State.DESPAWNING:
			_process_despawning(delta)


## ========== 初始化 ==========

## 设置物品实例
func setup_item(item: ItemInstance):
	item_instance = item
	gold_amount = 0
	_update_visual()


## 设置金币
func setup_gold(amount: int):
	item_instance = null
	gold_amount = amount
	_update_visual()


## ========== 状态处理 ==========

## 处理生成状态
func _process_spawning(delta: float):
	# 应用重力
	_velocity.y += item_gravity * delta
	
	# 更新位置
	position += _velocity * delta
	
	# 简单的地面碰撞检测（可以用 RayCast2D 改进）
	if position.y >= global_position.y + 10:  # 假设地面在这个位置
		position.y = global_position.y + 10
		_velocity.y *= -bounce_damping
		
		if abs(_velocity.y) < 50:  # 速度足够小时停止弹跳
			_velocity.y = 0
			_is_on_ground = true
			_change_state(State.IDLE)
	
	_spawn_timer += delta


## 处理等待拾取状态
func _process_idle(delta: float):
	# 检查自动消失
	if auto_despawn:
		_despawn_timer += delta
		
		# 闪烁警告
		if _despawn_timer >= despawn_time - blink_before_despawn:
			_blink_timer += delta
			var blink_interval = 1.0 / blink_frequency
			var blink_phase = fmod(_blink_timer, blink_interval)
			if sprite:
				sprite.modulate.a = 1.0 if blink_phase < blink_interval * 0.5 else 0.5
		
		# 时间到，消失
		if _despawn_timer >= despawn_time:
			despawn()
	
	# 检查磁吸范围
	if enable_magnetism and _target_player:
		var distance = global_position.distance_to(_target_player.global_position)
		if distance <= magnet_radius:
			_change_state(State.ATTRACTING)


## 处理磁吸状态
func _process_attracting(delta: float):
	if not _target_player or not is_instance_valid(_target_player):
		_change_state(State.IDLE)
		return
	
	# 移动向玩家
	var direction = (global_position.direction_to(_target_player.global_position))
	position += direction * magnet_speed * delta
	
	# 检查是否足够接近
	var distance = global_position.distance_to(_target_player.global_position)
	if distance <= pickup_radius:
		_try_pickup(_target_player)


## 处理消失状态
func _process_despawning(delta: float):
	# 淡出效果
	if sprite:
		sprite.modulate.a = max(0, sprite.modulate.a - delta * 2)
	if glow:
		glow.modulate.a = max(0, glow.modulate.a - delta * 2)
	
	if sprite and sprite.modulate.a <= 0:
		queue_free()


## ========== 拾取逻辑 ==========

func _on_body_entered(body: Node2D):
	if current_state == State.PICKED_UP or current_state == State.DESPAWNING:
		return
	
	# 检查是否是玩家
	if _is_player(body):
		_try_pickup(body)


func _on_area_entered(area: Area2D):
	# 检测磁吸范围（如果玩家有磁吸Area2D）
	if enable_magnetism and current_state == State.IDLE:
		var body = area.get_parent()
		if _is_player(body):
			_target_player = body


## 尝试拾取
func _try_pickup(picker: Node2D):
	if current_state == State.PICKED_UP:
		return
	
	_change_state(State.PICKED_UP)
	
	# 播放拾取效果
	_play_pickup_effect()
	
	# 发出信号
	if item_instance:
		item_picked_up.emit(item_instance, picker)
	elif gold_amount > 0:
		# 金币作为特殊信号发出
		item_picked_up.emit(null, picker)
	
	# 延迟销毁（等待粒子效果播放完）
	await get_tree().create_timer(0.5).timeout
	queue_free()


## ========== 视觉效果 ==========

## 更新视觉表现
func _update_visual():
	if not sprite:
		return
	
	if item_instance and item_instance.item_data:
		# 设置物品图标
		sprite.texture = item_instance.item_data.icon
		
		# 设置稀有度光晕
		if glow:
			glow.modulate = item_instance.item_data.get_rarity_color()
			glow.visible = item_instance.item_data.rarity >= ItemData.Rarity.RARE
	
	elif gold_amount > 0:
		# 金币图标（需要预设）
		# sprite.texture = preload("res://assets/icons/gold_coin.png")
		if glow:
			glow.modulate = Color.GOLD
			glow.visible = gold_amount >= 100  # 大额金币显示光晕


## 播放拾取效果
func _play_pickup_effect():
	# 播放音效
	# AudioManager.play_sfx("item_pickup")
	
	# 生成粒子
	if pickup_particles:
		var particles = pickup_particles.instantiate()
		get_parent().add_child(particles)
		particles.global_position = global_position
		particles.emitting = true


## 生成动画
func _start_spawn_animation():
	# 随机抛出方向
	var random_angle = randf_range(-PI/4, PI/4)
	var force = spawn_force.rotated(random_angle)
	force += Vector2(randf_range(-spawn_randomness, spawn_randomness), 0)
	_velocity = force


## ========== 公共方法 ==========

## 改变状态
func _change_state(new_state: State):
	current_state = new_state


## 手动消失
func despawn():
	if current_state == State.DESPAWNING:
		return
	
	_change_state(State.DESPAWNING)
	
	if item_instance:
		item_despawned.emit(item_instance)


## 检查是否是玩家
func _is_player(node: Node) -> bool:
	# 检查节点是否有 "player" 组或特定类型
	return node.is_in_group("player")


## 设置目标玩家（用于磁吸）
func set_target_player(player: Node2D):
	_target_player = player


## 获取显示名称
func get_display_name() -> String:
	if item_instance and item_instance.item_data:
		var name_text = item_instance.item_data.item_name
		if item_instance.stack_count > 1:
			name_text += " x%d" % item_instance.stack_count
		return name_text
	elif gold_amount > 0:
		return "%d 金币" % gold_amount
	return "未知物品"