## 战斗事件总线
## 用于战斗系统的事件通信
extends Node

## 单例实例
static var instance: Node = null

## ========== 战斗事件 ==========

## 战斗开始
signal combat_started(attacker: Node, defender: Node)

## 战斗结束
signal combat_ended(winner: Node, loser: Node)

## 造成伤害
signal damage_dealt(source: Node, target: Node, damage_info: DamageInfo)

## 受到伤害
signal damage_received(target: Node, source: Node, damage_info: DamageInfo)

## 暴击
signal critical_hit(attacker: Node, target: Node, damage: float)

## 闪避
signal attack_dodged(attacker: Node, target: Node)

## 格挡
signal attack_blocked(attacker: Node, target: Node)

## 击杀
signal entity_killed(killer: Node, victim: Node)

## ========== 技能事件 ==========

## 技能使用
signal skill_used(caster: Node, skill_id: String, target: Node)

## 技能命中
signal skill_hit(caster: Node, skill_id: String, target: Node)

## 技能未命中
signal skill_missed(caster: Node, skill_id: String, target: Node)

## ========== 状态效果事件 ==========

## 状态效果应用
signal status_effect_applied(target: Node, effect_id: String)

## 状态效果移除
signal status_effect_removed(target: Node, effect_id: String)

## 状态效果触发
signal status_effect_triggered(target: Node, effect_id: String)

## ========== 连击事件 ==========

## 连击达成
signal combo_achieved(attacker: Node, combo_count: int)

## 连击中断
signal combo_broken(attacker: Node, final_combo: int)

## ========== 元素反应事件 ==========

## 元素反应触发
signal elemental_reaction_triggered(target: Node, reaction_type: String, damage: float)

func _ready() -> void:
	if instance == null:
		instance = self
	else:
		push_warning("CombatEventBus instance already exists!")

## ========== 便捷方法 ==========

## 触发战斗开始事件
static func emit_combat_started(attacker: Node, defender: Node) -> void:
	if instance:
		instance.combat_started.emit(attacker, defender)

## 触发伤害造成事件
static func emit_damage_dealt(source: Node, target: Node, damage_info: DamageInfo) -> void:
	if instance:
		instance.damage_dealt.emit(source, target, damage_info)

## 触发暴击事件
static func emit_critical_hit(attacker: Node, target: Node, damage: float) -> void:
	if instance:
		instance.critical_hit.emit(attacker, target, damage)

## 触发击杀事件
static func emit_entity_killed(killer: Node, victim: Node) -> void:
	if instance:
		instance.entity_killed.emit(killer, victim)

## 触发技能使用事件
static func emit_skill_used(caster: Node, skill_id: String, target: Node = null) -> void:
	if instance:
		instance.skill_used.emit(caster, skill_id, target)

## 触发状态效果应用事件
static func emit_status_effect_applied(target: Node, effect_id: String) -> void:
	if instance:
		instance.status_effect_applied.emit(target, effect_id)

## 触发连击事件
static func emit_combo_achieved(attacker: Node, combo_count: int) -> void:
	if instance:
		instance.combo_achieved.emit(attacker, combo_count)

## 触发元素反应事件
static func emit_elemental_reaction(target: Node, reaction_type: String, damage: float) -> void:
	if instance:
		instance.elemental_reaction_triggered.emit(target, reaction_type, damage)
