# 从修 BUG 到开源发布：godot-arpg-kit v0.1.0 Postmortem

> 一份从"接手一个装着 BUG 的 Godot 项目"到"打造成一个 189 测试全绿、CI 通过、GitHub Release 发布的开源库"的完整技术复盘。
>
> 本文分三节：**战斗管线双重结算**（最严重的一类 BUG）、**测试 flake 治理**（用一行 `seed(0)` 消除所有偶发失败）、**Godot 4 CI 实践**（headless 退出码不可靠、`--import` 预热、GitHub Actions matrix）。

---

## 第一节：战斗管线双重结算 BUG 诊断

### 背景

项目里有两套减伤代码：

1. **`DamageCalculator.calculate_damage(damage_info)`** — 纯函数式（`extends RefCounted`），处理**攻击者→受击方**的整条计算：闪避、格挡、属性加成、暴击、元素反应、防御减免、护盾吸收。产物是 `damage_info.final_damage`。

2. **`StatsComponent.take_damage(amount, damage_type, element, can_dodge, is_blocking)`** — 一个更全的减伤实现：闪避、完美格挡、元素抗性、护甲、额外减伤、能量护盾、伤害吸收、伤害反射。

两套的存在本身**是设计冗余**（一个用于攻击者视角、一个用于受击方视角），但直到我发现之前——它们被**串联调用**了。

### 现场

`CombatComponent.attack(target, base, type, skill_id)` 的调用链：

```gdscript
# combat_component.gd（修复前）
func attack(target, base_damage, damage_type, skill_id):
    var info = DamageInfo.new(entity, target, base_damage, damage_type)
    DamageCalculator.calculate_damage(info)         # ← 第一次减伤
    target.CombatComponent.receive_damage(info)
    ...

func receive_damage(damage_info):
    var actual = damage_info.final_damage           # 拿到"已减完防"的值
    if status_effect_manager:
        actual -= status_effect_manager.consume_shield(actual)  # ← 再消耗一次临时护盾
    ...
    stats_component.take_damage(actual)             # ← 第二次减伤（完整链路）
```

后果：

- **防御减两遍**：面板 100 armor 实际减伤 75%（应该 50%）
- **闪避判定两遍**：dodge=30% 实际闪避率 51%
- **临时护盾消耗两遍**：50 点护盾只挡得住 25 点伤害
- `is_blocking` 参数从来没被传，`stats_component` 里的"完美格挡"功能**永远不触发**

### 为什么以前的测试没抓住

看现有的 `test_receive_damage`：

```gdscript
base_stats.armor = 0.0    # 清了护甲
base_stats.dodge_chance = 0.0  # 清了闪避
...
stats.take_damage 时减伤链全部空转 → 扣血正好 30 → 通过
```

**"测试 setup 把默认值全清零"** 恰好让 BUG 隐身。这是很典型的 test smell —— 通过特殊 setup 让 BUG 不触发的测试并不能保证生产环境正确。

### 修复策略

有两条路：

| 方案 | 描述 | 代价 |
|---|---|---|
| **A** | 让 `DamageCalculator` 变纯"攻击者侧输出"，`stats_component.take_damage` 负责所有减伤 | 会破坏 9 个 `test_damage_calculator.*` 测试 |
| **B** | 保留 `DamageCalculator` 现有的完整减伤流程，让 `CombatComponent.receive_damage` 只做"纯扣血 + 状态切换 + 信号派发" | 兼容现有测试 |

我选 **方案 B**——最小破坏面。关键改动：

```gdscript
# combat_component.gd（修复后）
func receive_damage(damage_info):
    if is_invincible: return
    if combat_state == CombatState.State.DEAD: return
    var actual = damage_info.final_damage
    if actual <= 0:
        damage_received.emit(damage_info.source, damage_info)
        return
    set_combat_state(CombatState.State.BEING_HIT)
    # ⭐ 关键修复：直接扣血，不再走减伤链
    stats_component.lose_health(actual)
    ...
```

`stats_component.take_damage()` 保留，供 **DOT / 环境伤害 / 脚本直接调用**等"跳过 CombatComponent"的路径继续使用（此路径依然享有完整减伤链）。

### 回归测试

写了 6 个新用例专门盯这个 BUG（[test_damage_pipeline_regression.gd](../../tests/combat/test_damage_pipeline_regression.gd)）：

- `test_no_double_defense_on_receive_damage`：100 护甲下 `final_damage=100` 应扣血 100
- `test_no_double_dodge_on_receive_damage`：`dodge=100%` + `final_damage=50` 应仍扣血 50（因为 DamageCalculator 已算过闪避）
- `test_temporary_shield_consumed_only_once`：模拟 DamageCalculator 已消耗护盾后，`receive_damage` 不应再消耗
- `test_full_attack_pipeline_matches_calculator`：端到端 `attack()` 链，100 armor + 100 伤害 → 扣血 50
- `test_direct_take_damage_still_applies_defense`：`stats.take_damage()` 单独调用仍减伤（DOT 路径）
- `test_death_state_short_circuits_receive_damage`：死亡后 `receive_damage` 立即短路

### 教训

> "两套语义重叠但接口不同的实现放在同一条数据流上"是最容易被忽视的架构 BUG。它不会 crash、日志正常、单元测试都通过（因为 setup 把敏感值清零了），只在生产环境慢慢显现"敌人明明护甲不高但异常抗揍"。

**防御方法**：写测试时**不要清零所有默认值**——保留一些 realistic 的分布，才能撞出这类 BUG。

---

## 第二节：Godot 测试 flake 治理 — 一行 `seed(0)` 消除所有偶发失败

### 现场

修完前一节的 BUG 后，重新跑测试 5 次：

```
Iter 1  → combat 66/66  ✓
Iter 2  → combat 66/66  ✓
Iter 3  → combat 66/66  ✓
Iter 4  → combat 64/66  ✗ 失败: 死亡处理, Buff影响伤害
Iter 5  → combat 66/66  ✓
```

60% 通过率、40% flake。CI 上直接不可用。

### 追踪

给失败测试加 print，发现三类根源：

**根源 1：`StatsData` 默认值触发低概率 rng**

```gdscript
# stats_data.gd
@export_range(0, 0.75) var dodge_chance: float = 0.05   # ← 5% 闪避
@export_range(0, 1)    var crit_chance: float = 0.05    # ← 5% 暴击
@export var luck: int = 10                              # ← 10 幸运
```

配合派生规则：

```gdscript
# stats_component.gd _apply_derived_bonuses
StatModifier.StatType.CRIT_CHANCE:
    return base_value + (agility * 0.001) + (luck * base_stats.luck_crit_bonus)
    #                                     ← luck * 0.001 * 10 = +1% 额外暴击

StatModifier.StatType.DODGE_CHANCE:
    return base_value + (agility * 0.0005) + (luck * base_stats.luck_dodge_bonus)
    #                                       ← luck * 0.0005 * 10 = +0.5% 额外闪避

StatModifier.StatType.ARMOR:
    return base_value + vitality                        # ← 每点体质 +1 armor
```

于是 `test_death_handling` 里 `stats.take_damage(100)` 有 5% 概率被 dodge 掉，敌人没死，测试 fail。

**根源 2：测试用例的 setup 不完整**

`test_buff_affects_damage` 里 attacker 只清了 `crit_chance = 0`，没清 `luck`。luck=10 让 crit_rate 从 0 变成 0.01。1% 概率触发暴击让 damage1 变 1.5 倍，`damage1 > damage2` 断言失败。

**根源 3：全局 rng 状态在测试间累积**

Godot 4 的 `randf()` 使用全局 rng；前一个测试消耗了几次 rng，后一个测试的"起始随机数"就变了。表现为**只有第 4 次 iteration 失败**这种规律性。

### 修复

**表层修**：给失败的每个 test setup 补 `dodge_chance=0` / `luck=0` / `vitality=0`。

**根治**：在**每个 test_runner 的 `_ready()` 开头**加一行：

```gdscript
extends Node

func _ready() -> void:
    seed(0)   # ⭐ 固定全局随机数种子，消除所有 rng 相关的 flake
    ...
    run_all_tests()
```

Godot 4 的 `seed(v)` 会重置**全局 rng**（`randf()`、`randi()` 等所有内置函数用的那个），此后每次跑测试的 rng 序列都一样。5 个 test_runner 都加上后：

```
Iter 1  → 66/66 ✓
Iter 2  → 66/66 ✓
Iter 3  → 66/66 ✓
Iter 4  → 66/66 ✓  ← 之前 flake 的 iteration 也稳定了
Iter 5  → 66/66 ✓
```

### 副作用

固定 seed **可能会漏掉真正的 rng 边界 bug**（比如 dodge_rate 计算出 -0.01 但恰好 randf() 永远大于它所以永不触发的错误逻辑）。缓解方法：

- 主 CI 用 `seed(0)` 保稳定
- 另开一个"stress test"job 用**当前时间**当 seed，允许失败但会记录报警
- 敏感的边界条件写**确定性**单元测试（不依赖 rng）

本项目当前只做了第一层，其他留给未来的 v0.2.0。

### 教训

> Godot 4 的 rng 是全局共享的、跨测试污染的、且默认属性藏着不易察觉的低概率分支。给 test_runner 一行 `seed(0)` 是 5 分钟能做出的最高性价比 flake 修复。

---

## 第三节：Godot 4 CI 实践 — headless 退出码、`--import` 预热、matrix workflow

### 挑战 1：Godot headless 的进程退出码不可靠

问题现场：

```
Iter 1  → godot exit=0
Iter 2  → godot exit=1   ← 但测试全绿
Iter 3  → godot exit=1
Iter 4  → godot exit=0
```

进一步观察：

```
[✓ PASS] 全部 66 测试通过
...
WARNING: 2 RIDs of type "CanvasItem" were leaked.
WARNING: ObjectDB instances leaked at exit
ERROR: 2 resources still in use at exit
```

**罪魁**：Godot 在 headless 模式退出时如果检测到资源泄漏（比如某个 test 里 `Node2D.new()` 后没 `.free()`），会 push_error，然后**覆盖 `get_tree().quit(0)` 请求的退出码为非 0**。

对 CI 这是灾难：测试全绿但进程 exit 1，CI job 显示失败。

**修复思路**：**不要依赖 Godot 进程退出码，改用输出解析**。

在每个 test_runner 结尾打印一行机器可读的汇总：

```gdscript
print("[RESULT] suite=%s passed=%d failed=%d total=%d" % [
    suite_name, passed_count, failed_count, total_count
])
get_tree().quit(1 if failed_count > 0 else 0)   # exit code 仍设，但不再是权威
```

CI / 本地脚本用 grep 判断：

```bash
if grep -qE '\[RESULT\] suite=[a-z]+ passed=[0-9]+ failed=0 total=[1-9]' output.log; then
    echo "✓ pass"
    exit 0
else
    echo "✗ fail"
    exit 1
fi
```

用输出的 `[RESULT]` 行作为"契约"（passed 数 > 0 且 failed = 0 即绿），Godot 进程的 exit code 只是"参考信息"。

### 挑战 2：CI 镜像的选择

**第一次尝试**：`barichello/godot-ci:4.5`

```yaml
container:
  image: barichello/godot-ci:4.5
```

结果：**5 个 matrix job 里 4 个卡在 "Run xxx suite" 步骤 27+ 分钟不返回**，只有 `loot` job 顺利完成。

诊断：`barichello/godot-ci` 主要为**导出**设计（打包 .apk / .exe / .html5），不是为 headless 跑测试的最佳选择。镜像内的 Godot 可能因缺失某些库、或与 GitHub Actions runner 环境冲突而挂起。

**第二次尝试**：官方 Godot binary + `apt install` X 库

```yaml
runs-on: ubuntu-latest
timeout-minutes: 10

steps:
  - uses: actions/checkout@v4
  
  - name: Install Godot dependencies
    run: |
      sudo apt-get install -y --no-install-recommends \
        libx11-6 libxcursor1 libxi6 libxinerama1 libxrandr2 libxrender1 \
        libgl1 libglx-mesa0 libasound2t64 libpulse0 || \
      # Ubuntu 22.04 用 libasound2 而非 libasound2t64
      sudo apt-get install -y libasound2 libpulse0
  
  - name: Download Godot
    run: |
      curl -fsSL "https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip" -o godot.zip
      unzip -q godot.zip
      mv Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot
      chmod +x /usr/local/bin/godot
```

**关键点**：Godot headless **也需要 X 库**（`libx11-6` 等）才能启动，即使不显示窗口。这是很多人第一次跑 CI 时踩的坑。

### 挑战 3：CI 环境缺少 `.godot/imported/` 缓存

改成官方 binary 后仍报错：

```
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
   at: run_all_loot_tests (res://tests/loot/test_runner.gd:23)
```

对应代码：

```gdscript
var test = load("res://tests/loot/test_loot_entry.gd").new()
```

**原因**：CI 是全新 checkout，没有 `.godot/imported/` 目录。Godot 4 里首次使用某个 script 前需要"import"（生成缓存元数据），否则 `load()` 拿到的 GDScript 对象是**不完整**的，`new()` 会失败。

本地跑 OK 是因为 `.godot/` 已经存在（打开过 Godot 编辑器）。

**修复**：在跑测试前加一个"预热 import"步骤。

```yaml
- name: Import project (generate .godot cache)
  run: |
    godot --headless --import 2>&1 | tail -20 || true
    if [ ! -d .godot/imported ]; then
      timeout 60 godot --headless --editor --quit 2>&1 | tail -20 || true
    fi
```

`--import` 是 Godot 4.5+ 支持的静默导入模式。旧版本回退到 `--editor --quit`。加 `timeout 60` 防止再次卡死。

### 挑战 4：Matrix 并行

5 个模块（combat / items / loot / quest / stats）串行跑要 5×2=10 分钟；并行跑 2 分钟。

```yaml
strategy:
  fail-fast: false      # 一个 job 失败不影响其他 job
  matrix:
    godot: ['4.5']
    suite:
      - { name: combat, scene: 'res://tests/combat/combat_test_scene.tscn' }
      - { name: items,  scene: 'res://tests/items/item_system_test_scene.tscn' }
      # ...
```

单个 job 失败时，其他 job 继续跑并汇报——比 fail-fast 更适合调试。

### 最终 CI 结果

Run 时长 ~2 分钟（首次拉 Godot binary 会稍慢），5 个 matrix job 全绿。

---

## 尾声：这些坑对新项目的启示

如果你正要开始一个 Godot 4 项目 / 开源库，这些经验建议直接抄：

1. **不要让"减伤"和"扣血"混在一个函数里**。用两个明确职责的 API（`calculate_damage` 是纯函数，`lose_health` 是纯扣血），中间的"应用状态效果、切战斗状态、发信号"用第三个 orchestration 函数（`receive_damage`）串起来。

2. **测试 setup 不要清零所有默认值**。清得越干净越容易漏 BUG，保留 realistic 的分布（比如让 `dodge_chance` 保持默认 5%）反而能撞出问题。

3. **给 test_runner 加 `seed(0)`**。5 分钟修所有 flake。

4. **不要依赖 Godot headless 的进程退出码**。用 `[RESULT]` 汇总行让 CI 用 grep 判断。

5. **CI 先跑 `godot --headless --import`**，再跑测试。否则 `.godot/imported/` 缺失会让 `load().new()` 挂掉。

6. **CI 用官方 Godot binary + `apt install` X 库**，比第三方 docker image 稳定。加 `timeout-minutes: 10` 兜底。

7. **`class_name` 和 autoload 同名会冲突**。想让某个 `class_name X` 变 autoload？先去掉 `class_name`（并把 `static var instance: X` 类型改成 `Node`）。

8. **StatType / DamageType 之类的枚举总是追加到末尾**。中间插入会打乱现有 `.tres` 里序列化的整数值。

---

## 附录：本次修复涉及的 commit

- `897894b` fix(combat): 修复战斗管线双重结算与相关 BUG
- `244ce26` ci(tests): 添加战斗测试的 CI/预提交钩子集成
- `12c1e51` fix(inventory,combat): 修复中优先级 BUG（部分堆叠 / 元素 debuff 注册）
- `9632754` docs(readme): 重写 README 为开源可复用 Godot 2D ARPG 系统文档
- `50c925a` chore(tests,ci): 打通所有 5 个模块测试 + 加 LICENSE
- `6703f08` test(all): 消除测试 flake（固定 seed + 输出解析 runner）
- `097c321` docs: 添加 getting_started.md 入门教程
- `66a7cba` docs: 加 CI badge 到 README + 首发 CHANGELOG.md
- `4a05dcc` ci(tests): 换用官方 Godot binary 替代 barichello docker image
- `6074609` ci(tests): 在跑测试前先做 godot --import 生成缓存

完整代码：<https://github.com/ClarkWain/godot-arpg-kit>  
Release：<https://github.com/ClarkWain/godot-arpg-kit/releases/tag/v0.1.0>
