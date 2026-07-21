# 2D ARPG 测试系统说明

## 快速运行

```powershell
# 一键跑所有模块（推荐）
pwsh tools/run_tests.ps1

# 只跑某个模块
pwsh tools/run_tests.ps1 -Only combat
```

详情见项目根 [README.md](../README.md#六测试与-ci) 的"测试与 CI"章节。

## 当前状态

**189 个测试全部通过**（Godot 4.5 headless 环境）：

| 模块 | 用例数 |
|---|---:|
| Combat（含伤害管线回归 + 高优先级 BUG 回归） | 66 |
| Items | 18 |
| Loot | 11 |
| Quest | 55 |
| Stats | 39 |

## 测试结构

项目包含完整的测试覆盖，测试代码组织如下：

```
tests/
├── base/
│   └── test_framework.gd          # 共用测试框架基类
├── quest/                          # 任务系统测试 (55 个测试)
│   ├── test_task_manager.gd       # TaskManager 测试
│   ├── test_task_instance.gd      # TaskInstance 测试
│   ├── test_objectives.gd         # Objective 测试
│   ├── test_conditions.gd         # Condition 测试
│   ├── test_rewards.gd            # Reward 测试
│   ├── test_integration.gd        # 集成测试
│   └── test_runner.gd             # 测试运行器
├── stats/                          # 属性系统测试 (39 个测试)
│   ├── test_stat_modifier.gd
│   ├── test_stats_data.gd
│   ├── test_stats_component.gd
│   ├── test_luck_system.gd
│   └── test_runner.gd
├── items/                          # 物品系统测试 (18 个测试)
│   ├── test_framework.gd          # Items 专用测试辅助
│   ├── test_item_data.gd
│   ├── test_item_instance.gd
│   ├── test_equipment_data.gd
│   ├── test_consumable_data.gd
│   ├── test_weapon_data.gd
│   └── test_runner.gd
├── loot/                           # 掉落系统测试 (11 个测试)
│   ├── test_loot_entry.gd
│   ├── test_loot_table.gd
│   └── test_runner.gd
└── combat/                         # 战斗系统测试 (66 个测试)
    ├── test_damage_calculator.gd              (9)
    ├── test_combat_component.gd               (9)
    ├── test_status_effect_manager.gd          (11)
    ├── test_skill_manager.gd                  (10)
    ├── test_integration.gd                    (8)
    ├── test_damage_pipeline_regression.gd     (6, 新)
    ├── test_high_priority_fixes.gd            (13, 新)
    ├── run_combat_tests.gd                    # 测试运行脚本
    └── combat_test_scene.tscn                 # 测试场景
```

## 测试框架

### 共用基类 (`tests/base/test_framework.gd`)

所有测试继承自 `TestFramework` 类，提供：

**断言方法：**
- `assert_equal(actual, expected, message)` - 断言相等
- `assert_not_equal(actual, expected, message)` - 断言不相等
- `assert_true(value, message)` - 断言为真
- `assert_false(value, message)` - 断言为假
- `assert_null(value, message)` - 断言为 null
- `assert_not_null(value, message)` - 断言不为 null
- `assert_almost_equal(actual, expected, epsilon, message)` - 浮点数近似相等
- `assert_contains(array, value, message)` - 数组包含元素
- `assert_not_contains(array, value, message)` - 数组不包含元素
- `assert_greater(actual, expected, message)` - 大于
- `assert_greater_equal(actual, expected, message)` - 大于等于
- `assert_less(actual, expected, message)` - 小于
- `assert_less_equal(actual, expected, message)` - 小于等于
- `assert_not_empty(value, message)` - 字符串不为空

**测试流程方法：**
- `start_test(test_name)` - 开始一个测试
- `end_test(passed)` - 结束测试并记录结果
- `print_report()` - 打印测试报告
- `get_test_summary()` - 获取测试摘要

## 运行测试

### 命令行方式

**Quest 系统测试：**
```bash
godot --headless scene/quest_system_test_scene.tscn
```

**Items 系统测试：**
```bash
godot --headless -s tests/items/run_item_tests.gd
# 或
godot --headless tests/items/item_system_test_scene.tscn
```

**Loot 系统测试：**
```bash
godot --headless -s tests/loot/run_loot_tests.gd
# 或
godot --headless tests/loot/loot_system_test_scene.tscn
```

**Stats 系统测试：**
```bash
godot --headless scene/stats_test_scene.tscn
```

**Combat 系统测试：**
```bash
godot --headless -s tests/combat/run_combat_tests.gd
# 或
godot --headless tests/combat/combat_test_scene.tscn
```

### 场景方式

在 Godot 编辑器中直接运行对应的测试场景文件：
- `scene/quest_system_test_scene.tscn`
- `tests/items/item_system_test_scene.tscn`
- `tests/loot/loot_system_test_scene.tscn`
- `scene/stats_test_scene.tscn`
- `tests/combat/combat_test_scene.tscn`

## 测试覆盖率

### Quest 系统 (96.4%)
- **总计**: 55 个测试，53 个通过
- **TaskManager**: 16/16 (100%)
- **TaskInstance**: 9/10 (90%) *
- **Objective**: 9/10 (90%) *
- **Condition**: 7/7 (100%)
- **Reward**: 6/6 (100%)
- **Integration**: 6/6 (100%)

\* 信号相关测试在命令行模式下可能不可靠，建议使用场景模式运行

### Items 系统 (100%)
- **总计**: 18 个测试，全部通过
- **ItemData**: 7/7 (100%)
- **ItemInstance**: 2/2 (100%)
- **EquipmentData**: 4/4 (100%)
- **ConsumableData**: 2/2 (100%)
- **WeaponData**: 3/3 (100%)

### Loot 系统 (100%)
- **总计**: 10 个测试，全部通过
- **LootEntry**: 5/5 (100%)
- **LootTable**: 5/5 (100%)

### Combat 系统 (新增)
- **总计**: 50 个测试
- **DamageCalculator**: 9 个测试
  - 基础伤害计算、属性加成、暴击、防御削减
  - 闪避/格挡、元素反应、护盾吸收
  - 护甲穿透、真实伤害
- **CombatComponent**: 9 个测试
  - 初始化、攻击目标、接收伤害
  - 状态转换、连击系统、无敌状态
  - 死亡处理、治疗、信号
- **StatusEffectManager**: 11 个测试
  - 注册/添加/移除效果、效果叠加
  - DOT/HOT效果、Buff属性修改
  - 护盾系统、净化、元素追踪、序列化
- **SkillManager**: 10 个测试
  - 注册/装备/卸载技能、使用技能
  - 冷却管理、资源消耗、施法时间
  - 施法距离、打断施法、序列化
- **Integration**: 8 个测试
  - 完整战斗流程、技能附加状态效果
  - 元素连招、Buff影响伤害
  - DOT击杀、护盾抵挡、装备集成、任务事件集成

## 已知限制

### 信号测试
使用 `await` 的信号测试（如 `test_signal_emission` 和 `test_objective_signals`）在命令行模式下可能不可靠，因为：
- 命令行模式下场景树的帧处理可能不完整
- `await Engine.get_main_loop().process_frame` 可能不会按预期工作

**解决方案**：在 Godot 编辑器中运行场景模式测试以验证信号功能。

### TaskManager 单例警告
在集成测试中可能会看到 "TaskManager instance already exists!" 警告。这是正常的，因为每个测试都会创建新的 TaskManager 实例。这不影响测试结果。

## 编写新测试

创建新测试文件的模板：

```gdscript
## 你的测试名称
extends TestFramework

func _init() -> void:
	super._init("你的测试名称")

## 运行所有测试
func run_all_tests() -> void:
	test_something()
	test_another_thing()
	print_report()

## 测试: 某个功能
func test_something() -> void:
	start_test("某个功能")
	
	# 测试代码
	var result = do_something()
	
	# 断言
	var passed = assert_equal(result, expected_value, "结果应该正确")
	
	end_test(passed)
```

## 测试报告

测试会生成详细的报告，包括：
- 每个测试套件的通过/失败统计
- 每个测试的执行时间
- 失败测试的错误信息
- 总体统计和成功率

Quest 系统测试报告保存在：`tests/quest/test_report.txt`
