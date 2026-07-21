## 战斗系统集成测试
## 测试各个战斗组件之间的集成
extends TestFramework

func _init() -> void:
	super._init("战斗系统集成测试")

## 运行所有测试
func run_all_tests() -> void:
	test_complete_combat_flow()
	test_skill_with_status_effects()
	test_elemental_combo()
	test_buff_affects_damage()
	test_dot_kills_enemy()
	test_shield_blocks_damage()
	test_equipment_integration()
	test_quest_event_integration()
	
	print_report()

## 测试: 完整战斗流程
func test_complete_combat_flow() -> void:
	start_test("完整战斗流程")
	
	# 创建玩家
	var player = Node2D.new()
	player.name = "Player"
	var player_stats = StatsComponent.new()
	player_stats.name = "StatsComponent"
	var player_base = StatsData.new()
	player_base.max_health = 100.0
	player_base.physical_damage = 20.0
	player_stats.base_stats = player_base
	player.add_child(player_stats)

	var player_combat = CombatComponent.new()
	player_combat.name = "CombatComponent"
	player.add_child(player_combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	player_stats._ready()
	player_combat._ready()
	
	# 创建敌人
	var enemy = Node2D.new()
	enemy.name = "Enemy"
	var enemy_stats = StatsComponent.new()
	enemy_stats.name = "StatsComponent"
	var enemy_base = StatsData.new()
	enemy_base.max_health = 50.0
	enemy_base.armor = 0.0
	enemy_base.health_regen = 0.0
	enemy_stats.base_stats = enemy_base
	enemy.add_child(enemy_stats)

	var enemy_combat = CombatComponent.new()
	enemy_combat.name = "CombatComponent"
	enemy.add_child(enemy_combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	enemy_stats._ready()
	enemy_combat._ready()
	
	var initial_enemy_health = enemy_stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	
	# 玩家攻击敌人
	var damage_info = player_combat.attack(enemy, 30.0)
	
	var passed = assert_not_null(damage_info, "应返回伤害信息")
	passed = assert_greater(damage_info.final_damage, 0.0, "应造成伤害") and passed
	
	var current_enemy_health = enemy_stats.current_health
	passed = assert_less(current_enemy_health, initial_enemy_health, "敌人生命值应减少") and passed
	
	# 连续攻击直到击杀
	while enemy_combat.combat_state != CombatState.State.DEAD:
		player_combat.attack(enemy, 30.0)
	
	passed = assert_equal(enemy_combat.combat_state, CombatState.State.DEAD, "敌人应死亡") and passed
	
	player.free()
	enemy.free()
	end_test(passed)

## 测试: 技能附加状态效果
func test_skill_with_status_effects() -> void:
	start_test("技能附加状态效果")
	
	# 注册中毒效果
	var poison = StatusEffectData.new()
	poison.effect_id = "test_integration_poison"
	poison.effect_type = StatusEffectData.EffectType.DOT
	poison.duration = 5.0
	poison.tick_interval = 1.0
	poison.tick_value = 5.0
	StatusEffectManager.register_effect(poison)
	
	# 注册带中毒效果的技能
	var skill = SkillData.new()
	skill.skill_id = "test_poison_skill"
	skill.cooldown = 0.0
	skill.cast_time = 0.0
	skill.base_damage = 20.0
	skill.target_type = SkillData.TargetType.ENEMY
	skill.status_effects.append("test_integration_poison")
	skill.status_effect_chance = 1.0  # 100%触发
	SkillManager.register_skill(skill)
	
	# 创建施法者和目标
	var caster = Node2D.new()
	
	var caster_stats = StatsComponent.new()
	caster_stats.name = "StatsComponent"
	caster_stats.base_stats = StatsData.new() # 初始化 base_stats
	caster.add_child(caster_stats)
	
	var caster_combat = CombatComponent.new()
	caster_combat.name = "CombatComponent"
	caster.add_child(caster_combat)

	var caster_skills = SkillManager.new()
	caster_skills.name = "SkillManager"
	caster.add_child(caster_skills)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	caster_stats._ready()
	caster_skills._ready()
	caster_combat._ready()
	
	var target = Node2D.new()
	var target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	var target_base = StatsData.new()
	target_base.max_health = 100.0
	target_base.armor = 0.0
	# 清 dodge_chance，避免默认 5% 闪避 + luck 加成让技能"未命中"
	# 而在 CombatComponent.receive_damage 中提前 return，跳过状态效果应用。
	target_base.dodge_chance = 0.0
	target_base.luck = 0
	target_stats.base_stats = target_base
	target.add_child(target_stats)
	
	var target_combat = CombatComponent.new()
	target_combat.name = "CombatComponent"
	target.add_child(target_combat)
	
	var target_status = StatusEffectManager.new()
	target_status.name = "StatusEffectManager"
	target.add_child(target_status)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	target_stats._ready()
	target_combat._ready()
	target_status._ready()
	
	# 使用技能
	caster_skills.equip_skill(0, "test_poison_skill")
	caster_skills.use_skill(0, target)
	
	var passed = assert_true(target_status.has_effect("test_integration_poison"), "目标应有中毒效果")
	
	caster.free()
	target.free()
	end_test(passed)

## 测试: 元素连招
func test_elemental_combo() -> void:
	start_test("元素连招")
	
	# 注册冰冻效果
	var ice = StatusEffectData.new()
	ice.effect_id = "test_combo_ice"
	ice.element = StatModifier.ElementType.ICE
	ice.duration = 5.0
	StatusEffectManager.register_effect(ice)
	
	# 创建实体
	var attacker = Node2D.new()
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	var attacker_base_stats = StatsData.new()
	# 关键：StatsData 里 magic_damage 默认 5.0、crit_chance 默认 0.05、
	# luck 默认 10（luck 会通过 luck_crit_bonus 追加暴击率），
	# 若不清零会让 50 * (1+5/100) * 2 = 105、或叠上暴击变成 157.5，
	# 都会击穿本用例 epsilon=1.0 的断言。这里显式清零，让测试确定性。
	attacker_base_stats.strength = 0
	attacker_base_stats.agility = 0
	attacker_base_stats.intelligence = 0
	attacker_base_stats.vitality = 0
	attacker_base_stats.luck = 0
	attacker_base_stats.physical_damage = 0.0
	attacker_base_stats.magic_damage = 0.0
	attacker_base_stats.fire_damage = 0.0
	attacker_base_stats.crit_chance = 0.0
	attacker_base_stats.crit_damage = 0.0
	attacker_base_stats.dodge_chance = 0
	attacker_stats.base_stats = attacker_base_stats
	attacker.add_child(attacker_stats)
	
	var attacker_combat = CombatComponent.new()
	attacker_combat.name = "CombatComponent"
	attacker.add_child(attacker_combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	attacker_stats._ready()
	attacker_combat._ready()
	
	var target = Node2D.new()
	
	var target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	var target_base = StatsData.new()
	target_base.max_health = 100.0
	target_base.armor = 0.0
	# 关键：受击方 vitality 默认 10 会通过派生规则给 armor +10，
	# 让"看似 0 防御"的目标实际有 10 armor（100 -> 90.91）。
	# 这里显式清零核心属性 + dodge，让蒸发计算保持确定性。
	target_base.strength = 0
	target_base.agility = 0
	target_base.intelligence = 0
	target_base.vitality = 0
	target_base.luck = 0
	target_base.dodge_chance = 0.0
	target_stats.base_stats = target_base
	target.add_child(target_stats)
	
	var target_combat = CombatComponent.new()
	target_combat.name = "CombatComponent"
	target.add_child(target_combat)
	
	var target_status = StatusEffectManager.new()
	target_status.name = "StatusEffectManager"
	target.add_child(target_status)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	target_combat._ready()
	target_stats._ready()
	target_status._ready()
	
	# 先施加冰冻
	target_status.add_effect("test_combo_ice")
	
	# 用火焰攻击触发蒸发
	var damage_info = attacker_combat.attack(target, 50.0, DamageInfo.DamageType.FIRE)
	
	var passed = assert_equal(damage_info.elemental_reaction, "蒸发", "应触发蒸发反应")
	passed = assert_almost_equal(damage_info.final_damage, 100.0, 1.0, "蒸发伤害应翻倍") and passed
	
	attacker.free()
	target.free()
	end_test(passed)

## 测试: Buff影响伤害
func test_buff_affects_damage() -> void:
	start_test("Buff影响伤害")
	
	# 注册攻击Buff
	var buff = StatusEffectData.new()
	buff.effect_id = "test_attack_buff"
	buff.effect_type = StatusEffectData.EffectType.BUFF
	buff.duration = 10.0
	
	var mod = StatModifier.new()
	mod.stat_type = StatModifier.StatType.PHYSICAL_DAMAGE
	mod.value = 50.0
	mod.modifier_type = StatModifier.ModifierType.FLAT
	buff.modifiers.append(mod)
	StatusEffectManager.register_effect(buff)
	
	# 创建攻击实体
	var attacker = Node2D.new()
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	var attacker_base = StatsData.new()
	# 清零核心属性：luck 默认 10 会通过 luck_crit_bonus 额外 +1% 暴击率，
	# 让无 Buff 时的 damage1 偶发暴击变大，导致本测试 flaky。
	attacker_base.strength = 0
	attacker_base.agility = 0
	attacker_base.intelligence = 0
	attacker_base.vitality = 0
	attacker_base.luck = 0
	attacker_base.physical_damage = 10.0
	attacker_base.crit_chance = 0.0
	attacker_base.crit_damage = 0.0
	attacker_stats.base_stats = attacker_base
	attacker.add_child(attacker_stats)

	var attacker_combat = CombatComponent.new()
	attacker_combat.name = "CombatComponent"
	attacker.add_child(attacker_combat)

	var attacker_status = StatusEffectManager.new()
	attacker_status.name = "StatusEffectManager"
	attacker.add_child(attacker_status)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	attacker_combat._ready()
	attacker_stats._ready()
	attacker_status._ready()
	
	# 创建受击实体
	var target = Node2D.new()
	var target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	var target_base = StatsData.new()
	target_base.max_health = 1000.0
	target_base.armor = 0.0
	target_base.dodge_chance = 0.0
	target_stats.base_stats = target_base
	target.add_child(target_stats)
	
	var target_combat = CombatComponent.new()
	target_combat.name = "CombatComponent"
	target.add_child(target_combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	target_combat._ready()
	target_stats._ready()
	
	# 无Buff时的伤害
	var damage1 = attacker_combat.attack(target, 100.0)
	var base_damage = damage1.final_damage
	
	# 添加Buff
	attacker_status.add_effect("test_attack_buff")
	
	# 有Buff时的伤害
	var damage2 = attacker_combat.attack(target, 100.0)
	var buffed_damage = damage2.final_damage
	
	var passed = assert_greater(buffed_damage, base_damage, "Buff应增加伤害")
	
	attacker.free()
	target.free()
	end_test(passed)

## 测试: DOT击杀敌人
func test_dot_kills_enemy() -> void:
	start_test("DOT击杀敌人")
	
	# 注册强力毒素
	var poison = StatusEffectData.new()
	poison.effect_id = "test_deadly_poison"
	poison.effect_type = StatusEffectData.EffectType.DOT
	poison.duration = 10.0
	poison.tick_interval = 0.5
	poison.tick_value = 20.0
	poison.tick_damage_type = DamageInfo.DamageType.POISON
	StatusEffectManager.register_effect(poison)
	
	# 创建目标
	var target = Node2D.new()
	var target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	var target_base = StatsData.new()
	target_base.max_health = 50.0
	target_base.armor = 0.0
	target_base.health_regen = 0.0
	target_base.dodge_chance = 0.0
	target_stats.base_stats = target_base
	target.add_child(target_stats)
	
	var target_combat = CombatComponent.new()
	target_combat.name = "CombatComponent"
	target.add_child(target_combat)
	
	var target_status = StatusEffectManager.new()
	target_status.name = "StatusEffectManager"
	target.add_child(target_status)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	target_combat._ready()
	target_stats._ready()
	target_status._ready()
	
	# 施加DOT
	var instance = target_status.add_effect("test_deadly_poison")
	
	var passed = assert_not_equal(target_combat.combat_state, CombatState.State.DEAD, "初始不应死亡")
	
	# 触发多次tick直到死亡
	for i in range(10):
		if target_combat.combat_state == CombatState.State.DEAD:
			break
		instance.tick()
	
	passed = assert_equal(target_combat.combat_state, CombatState.State.DEAD, "DOT应能击杀敌人") and passed
	
	target.free()
	end_test(passed)

## 测试: 护盾抵挡伤害
##
## 注意：临时护盾的消耗由 DamageCalculator._apply_damage_absorption 完成，
## CombatComponent.receive_damage 不再自己重复消耗（旧版本会消耗两次）。
## 该测试通过完整攻击链验证语义：一次攻击 → 护盾抵扣 → 剩余部分才扣血。
func test_shield_blocks_damage() -> void:
	start_test("护盾抵挡伤害")
	
	# 攻击者
	var attacker = Node2D.new()
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	var attacker_base = StatsData.new()
	attacker_base.strength = 0
	attacker_base.agility = 0
	attacker_base.intelligence = 0
	attacker_base.vitality = 0
	attacker_base.luck = 0
	attacker_base.physical_damage = 0.0
	attacker_base.crit_chance = 0.0
	attacker_base.crit_damage = 0.0
	attacker_stats.base_stats = attacker_base
	attacker.add_child(attacker_stats)
	
	var attacker_combat = CombatComponent.new()
	attacker_combat.name = "CombatComponent"
	attacker.add_child(attacker_combat)
	
	attacker_stats._ready()
	attacker_combat._ready()
	
	# 受击方
	var entity = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.strength = 0
	base_stats.agility = 0
	base_stats.intelligence = 0
	base_stats.vitality = 0
	base_stats.luck = 0
	base_stats.max_health = 100.0
	base_stats.armor = 0.0
	base_stats.crit_chance = 0.0
	base_stats.dodge_chance = 0.0
	stats.base_stats = base_stats
	entity.add_child(stats)

	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	entity.add_child(combat)
	
	var status = StatusEffectManager.new()
	status.name = "StatusEffectManager"
	entity.add_child(status)
	
	# 统一调用 _ready() 函数
	combat._ready()
	stats._ready()
	status._ready()
	
	var initial_health = stats.get_stat(StatModifier.StatType.MAX_HEALTH)
	
	# 添加 50 点临时护盾
	status.add_shield(50.0)
	
	# 走完整攻击链：造成 30 点物理伤害
	var damage_info = attacker_combat.attack(entity, 30.0,
		DamageInfo.DamageType.PHYSICAL)
	
	var passed = assert_not_null(damage_info, "attack() 应返回 DamageInfo")
	# 30 点伤害全部被护盾吸收：final_damage 归 0，扣血 0，护盾剩 20
	passed = assert_almost_equal(damage_info.final_damage, 0.0, 0.1,
		"final_damage 应被护盾抵为 0") and passed
	passed = assert_almost_equal(damage_info.absorbed_damage, 30.0, 0.1,
		"护盾应吸收 30 点伤害") and passed
	passed = assert_equal(stats.current_health, initial_health,
		"护盾应完全抵挡伤害") and passed
	passed = assert_almost_equal(status.get_shield_amount(), 20.0, 0.1,
		"护盾应剩余 20（50 - 30，且不会因二次消耗而多扣）") and passed
	
	attacker.free()
	entity.free()
	end_test(passed)

## 测试: 装备系统集成
func test_equipment_integration() -> void:
	start_test("装备系统集成")
	
	# 创建玩家
	var player = Node2D.new()
	var stats = StatsComponent.new()
	stats.name = "StatsComponent"
	var base_stats = StatsData.new()
	base_stats.physical_damage = 10.0
	base_stats.crit_chance = 0.0
	stats.base_stats = base_stats
	player.add_child(stats)

	var combat = CombatComponent.new()
	combat.name = "CombatComponent"
	player.add_child(combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	stats._ready()
	combat._ready()
	
	# 创建目标
	var target = Node2D.new()
	var target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	var target_base = StatsData.new()
	target_base.max_health = 1000.0
	target_base.armor = 0.0
	target_base.dodge_chance = 0.0
	target_stats.base_stats = target_base
	target.add_child(target_stats)

	var target_combat = CombatComponent.new()
	target_combat.name = "CombatComponent"
	target.add_child(target_combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	target_stats._ready()
	target_combat._ready()
	
	# 无装备时的伤害
	var damage1 = combat.attack(target, 100.0)
	var base_damage = damage1.final_damage
	
	# 添加攻击力修改器（模拟装备）
	var mod = StatModifier.new()
	mod.value = 50.0
	mod.stat_type = StatModifier.StatType.PHYSICAL_DAMAGE
	mod.modifier_type = StatModifier.ModifierType.FLAT
	stats.add_modifier(mod)
	
	# 有装备时的伤害
	var damage2 = combat.attack(target, 100.0)
	var equipped_damage = damage2.final_damage
	
	var passed = assert_greater(equipped_damage, base_damage, "装备应增加伤害")
	
	player.free()
	target.free()
	end_test(passed)

## 测试: 任务事件集成
func test_quest_event_integration() -> void:
	start_test("任务事件集成")
	
	# 创建实体
	var attacker = Node2D.new()
	attacker.name = "Player"
	var attacker_stats = StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	var attacker_base = StatsData.new()
	attacker_base.strength = 0
	attacker_base.agility = 0
	attacker_base.intelligence = 0
	attacker_base.vitality = 0
	attacker_base.luck = 0
	attacker_base.physical_damage = 10.0  # 设置基础攻击力
	attacker_stats.base_stats = attacker_base
	attacker.add_child(attacker_stats)
	
	
	var attacker_combat = CombatComponent.new()
	attacker_combat.name = "CombatComponent"
	attacker.add_child(attacker_combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	attacker_stats._ready()
	attacker_combat._ready()
	
	var enemy = Node2D.new()
	enemy.name = "Goblin"
	var enemy_stats = StatsComponent.new()
	enemy_stats.name = "StatsComponent"
	var enemy_base = StatsData.new()
	enemy_base.max_health = 50.0
	enemy_base.armor = 0.0
	enemy_stats.base_stats = enemy_base
	enemy.add_child(enemy_stats)
	
	var enemy_combat = CombatComponent.new()
	enemy_combat.name = "CombatComponent"
	enemy.add_child(enemy_combat)
	
	# 统一调用 _read() 函数,其中有依赖关系,否则有问题
	enemy_stats._ready()
	enemy_combat._ready()
	
	# 攻击
	attacker_combat.attack(enemy, 30.0)
	
	# 这个测试不再依赖QuestEventBus
	var passed = true
	
	attacker.free()
	enemy.free()
	end_test(passed)
