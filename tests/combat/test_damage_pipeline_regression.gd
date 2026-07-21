## 伤害管线回归测试
##
## 覆盖历史 BUG："CombatComponent.receive_damage 会在 DamageCalculator 已经
## 计算好 final_damage 之后，再调用 stats_component.take_damage() 触发
## 一次完整的减伤链，导致防御/闪避/护盾被重复结算"。
##
## 修复后：CombatComponent.receive_damage 直接使用 damage_info.final_damage
## 调用 stats_component.lose_health() 纯扣血；stats_component.take_damage()
## 本身的减伤链仍保留给 DOT/环境伤害等 "跳过 CombatComponent" 的路径使用。
extends TestFramework

func _init() -> void:
	super._init("伤害管线回归测试")


func run_all_tests() -> void:
	test_no_double_defense_on_receive_damage()
	test_no_double_dodge_on_receive_damage()
	test_temporary_shield_consumed_only_once()
	test_full_attack_pipeline_matches_calculator()
	test_direct_take_damage_still_applies_defense()
	test_death_state_short_circuits_receive_damage()

	print_report()


# ---------------------------------------------------------------------------
# 辅助方法
# ---------------------------------------------------------------------------

## 构造一个含有 StatsComponent + CombatComponent 的最小可战斗实体
func _build_entity(max_health: float = 200.0, armor: float = 0.0,
		dodge_chance: float = 0.0) -> Dictionary:
	var entity := Node2D.new()

	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	var base := StatsData.new()
	base.strength = 0
	base.agility = 0
	base.intelligence = 0
	base.vitality = 0
	base.luck = 0
	base.physical_damage = 0.0
	base.crit_chance = 0.0
	base.crit_damage = 0.0
	base.max_health = max_health
	base.armor = armor
	base.dodge_chance = dodge_chance
	stats.base_stats = base
	entity.add_child(stats)
	stats._ready()

	var combat := CombatComponent.new()
	combat.name = "CombatComponent"
	combat.entity = entity
	combat.stats_component = stats
	entity.add_child(combat)
	combat._ready()

	return {
		"entity": entity,
		"stats": stats,
		"combat": combat,
	}


## 造一个已经"预计算过 final_damage"的 DamageInfo，模拟 DamageCalculator
## 在 CombatComponent.attack() 中先跑一遍后传入 receive_damage 的场景。
func _make_precomputed_damage(target: Node, final_damage: float,
		dtype: int = DamageInfo.DamageType.PHYSICAL) -> DamageInfo:
	var info := DamageInfo.new(null, target, final_damage, dtype)
	info.final_damage = final_damage
	return info


# ---------------------------------------------------------------------------
# 用例
# ---------------------------------------------------------------------------

## 【回归】受击方拥有护甲时，receive_damage 不应再扣一次防御。
##
## BUG 复现前预期： 扣血 = 100 * (1 - 100/(100+100)) = 50 （错，双重减防）
## 修复后预期：     扣血 = 100 （final_damage 直接扣血）
func test_no_double_defense_on_receive_damage() -> void:
	start_test("受击方护甲不再造成双重减防")

	var target = _build_entity(200.0, 100.0, 0.0)
	var stats: StatsComponent = target.stats
	var combat: CombatComponent = target.combat

	var initial := stats.current_health
	var info := _make_precomputed_damage(target.entity, 100.0)
	combat.receive_damage(info)

	var lost := initial - stats.current_health
	var passed := assert_almost_equal(lost, 100.0, 0.1,
		"receive_damage 应直接扣除 final_damage=100，而非再被护甲减一次")

	target.entity.free()
	end_test(passed)


## 【回归】受击方拥有 100% 闪避时，若 final_damage 已被 DamageCalculator 归零，
## receive_damage 只应"零伤害"通过，不应再触发第二次闪避判定/异常路径。
## 更关键地：final_damage>0 通过时，stats_component 内部不应因 100% 闪避
## 把这笔伤害再次抹掉——因为 CombatComponent 现在不走 take_damage。
func test_no_double_dodge_on_receive_damage() -> void:
	start_test("受击方 100% 闪避不再造成双重闪避判定")

	# 构造 dodge=100% 的目标；但 DamageCalculator 已经"没算过闪避"（我们
	# 直接手动预置 final_damage=50 模拟一个必中场景，例如穿透闪避的技能）。
	var target = _build_entity(200.0, 0.0, 1.0)
	var stats: StatsComponent = target.stats
	var combat: CombatComponent = target.combat

	var initial := stats.current_health
	var info := _make_precomputed_damage(target.entity, 50.0)
	combat.receive_damage(info)

	var lost := initial - stats.current_health
	var passed := assert_almost_equal(lost, 50.0, 0.1,
		"final_damage=50 应完整扣除，而非被受击方的 100% 闪避二次抹除")

	target.entity.free()
	end_test(passed)


## 【回归】临时护盾（StatusEffectManager.consume_shield）只应被消耗一次。
## 修复前：DamageCalculator 已消耗一次，CombatComponent 又消耗一次，
## 共消耗 2 倍护盾值。
func test_temporary_shield_consumed_only_once() -> void:
	start_test("临时护盾仅消耗一次")

	var target = _build_entity(200.0, 0.0, 0.0)
	var entity: Node2D = target.entity

	# 附加一个 StatusEffectManager 并给 30 点护盾
	var sem := StatusEffectManager.new()
	sem.name = "StatusEffectManager"
	sem.entity = entity
	entity.add_child(sem)
	sem._ready()
	sem.add_shield(30.0)

	var combat: CombatComponent = target.combat
	combat.status_effect_manager = sem

	# 模拟 DamageCalculator 上游已经消费掉 30 点护盾并算出 final_damage=70
	sem.consume_shield(30.0)
	var info := _make_precomputed_damage(entity, 70.0)
	info.absorbed_damage = 30.0

	var initial: float = target.stats.current_health
	combat.receive_damage(info)
	var lost: float = initial - target.stats.current_health

	# 修复前会再消耗一次护盾（但护盾已为 0，此步 no-op），
	# 关键点是：actual_damage 不应因二次消耗而变化。
	var passed := assert_almost_equal(lost, 70.0, 0.1,
		"扣血应等于 final_damage=70，不应再被临时护盾二次抵消")
	passed = assert_almost_equal(sem.get_shield_amount(), 0.0, 0.1,
		"护盾应保持已耗尽（0），不应因二次消耗出现负数或异常") and passed

	entity.free()
	end_test(passed)


## 【端到端】走完整攻击链（DamageCalculator + CombatComponent），
## 验证：面对护甲 100 的目标，"面板 100 伤害" 的攻击最终扣血
## 与"只调用一次 DamageCalculator"的结果一致（不再翻倍减）。
func test_full_attack_pipeline_matches_calculator() -> void:
	start_test("端到端攻击链只走一次减伤")

	# 攻击者
	var attacker := Node2D.new()
	var atk_stats := StatsComponent.new()
	atk_stats.name = "StatsComponent"
	var atk_base := StatsData.new()
	atk_base.strength = 0
	atk_base.agility = 0
	atk_base.intelligence = 0
	atk_base.vitality = 0
	atk_base.luck = 0
	atk_base.physical_damage = 0.0
	atk_base.crit_chance = 0.0
	atk_base.crit_damage = 0.0
	atk_stats.base_stats = atk_base
	attacker.add_child(atk_stats)
	atk_stats._ready()
	var atk_combat := CombatComponent.new()
	atk_combat.name = "CombatComponent"
	atk_combat.entity = attacker
	atk_combat.stats_component = atk_stats
	attacker.add_child(atk_combat)
	atk_combat._ready()

	# 受击者：100 护甲，理论减伤 100/(100+100)=50%
	var target = _build_entity(500.0, 100.0, 0.0)

	# 走完整 attack() 链：DamageCalculator 内部会算防御，
	# 修复后 CombatComponent.receive_damage 不再二次算防御
	var initial: float = target.stats.current_health
	var info := atk_combat.attack(target.entity, 100.0,
		DamageInfo.DamageType.PHYSICAL)
	var lost: float = initial - target.stats.current_health

	# 理论最终伤害 = 100 * (1 - 100/(100+100)) = 50
	var passed := assert_not_null(info, "attack() 应返回 DamageInfo")
	passed = assert_almost_equal(info.final_damage, 50.0, 1.0,
		"DamageCalculator 应算出 50 伤害") and passed
	passed = assert_almost_equal(lost, 50.0, 1.0,
		"最终扣血应等于 DamageCalculator 的输出，不被二次减防") and passed

	attacker.free()
	target.entity.free()
	end_test(passed)


## 【保留能力】stats_component.take_damage 作为独立入口时，减伤链仍应生效。
## 用于 DOT、环境伤害、脚本直接调用等"跳过 CombatComponent"的场景。
func test_direct_take_damage_still_applies_defense() -> void:
	start_test("直接调用 stats.take_damage 仍保留减伤链")

	var target = _build_entity(500.0, 100.0, 0.0)
	var stats: StatsComponent = target.stats
	var initial := stats.current_health

	# 绕过 CombatComponent，直接把 100 点物理伤害交给 stats.take_damage
	var result: Dictionary = stats.take_damage(100.0, "physical")
	var lost := initial - stats.current_health

	# 走 stats 内部：100 * (1 - 100/(100+100)) = 50
	var passed := assert_almost_equal(result.final_damage, 50.0, 1.0,
		"stats.take_damage 内部减伤链应生效（防御 50%）")
	passed = assert_almost_equal(lost, 50.0, 1.0,
		"stats.take_damage 直接扣血也应符合减伤后数值") and passed

	target.entity.free()
	end_test(passed)


## 【回归】死亡状态下 receive_damage 应立即返回，不做扣血、不切状态。
func test_death_state_short_circuits_receive_damage() -> void:
	start_test("死亡状态下 receive_damage 不再执行")

	var target = _build_entity(100.0, 0.0, 0.0)
	var stats: StatsComponent = target.stats
	var combat: CombatComponent = target.combat

	# 打死
	combat.set_combat_state(CombatState.State.DEAD)
	var hp_before := stats.current_health

	var info := _make_precomputed_damage(target.entity, 999.0)
	combat.receive_damage(info)

	var passed := assert_almost_equal(stats.current_health, hp_before, 0.001,
		"死亡后不应再扣血")
	passed = assert_equal(combat.combat_state, CombatState.State.DEAD,
		"死亡状态不应因 receive_damage 而被切换") and passed

	target.entity.free()
	end_test(passed)
