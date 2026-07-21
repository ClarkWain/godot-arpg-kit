# 快速入门：将 godot-arpg-kit 引入到你自己的项目

本教程带你在 15 分钟内把 `godot-arpg-kit` 的核心系统集成到一个新的或已有的 Godot 4 项目里，从零跑通「玩家攻击敌人 → 敌人受伤 → 死亡 → 掉落物品 → 玩家拾取」这条完整链路。

> **目标读者**：想在自己的 Godot 4 · 2D ARPG / Roguelike 项目里复用本套系统，而不是从零造轮子的开发者。

---

## 一、集成方式选择

按你的场景挑一种：

| 场景 | 推荐方式 | 优缺点 |
|---|---|---|
| 全新项目 | **方式 A：直接 fork** | 最快，测试 / CI / docs 全带上，但整个仓库结构固定 |
| 已有项目，只需部分系统 | **方式 B：子目录拷贝** | 灵活，只带走需要的模块 |
| 已有项目，希望持续跟进上游更新 | **方式 C：git subtree / submodule** | 可跟随 upstream 更新，但集成体积大 |
| 想按需接入且能一键更新 | **方式 D：Godot 4 addon** | 未来路线，当前不支持（各模块尚未打包成 addon） |

本教程以 **方式 B（子目录拷贝）** 为主。方式 A / C 见文末简述。

---

## 二、方式 B：子目录拷贝（推荐）

### 第 1 步：把需要的目录搬到自己的项目

以 「战斗 + 属性 + 状态效果 + 物品 + 背包」的最小组合为例：

```powershell
# 假设你的项目在 D:\MyGame，本 kit 在 D:\godot-arpg-kit
$src = 'D:\godot-arpg-kit'
$dst = 'D:\MyGame'

# 必需依赖：Stats（几乎所有系统都用）+ Items（Combat 里会 preload）
Copy-Item -Recurse "$src\scripts\stats"  "$dst\scripts\"
Copy-Item -Recurse "$src\scripts\items"  "$dst\scripts\"

# 战斗系统
Copy-Item -Recurse "$src\scripts\combat" "$dst\scripts\"

# 背包（可选）
Copy-Item -Recurse "$src\scripts\inventory" "$dst\scripts\"

# 装备（可选，依赖 inventory + items）
Copy-Item -Recurse "$src\scripts\equipment" "$dst\scripts\"

# 掉落（可选，依赖 items）
Copy-Item -Recurse "$src\scripts\loot" "$dst\scripts\"

# 任务（完全独立，可以单独用）
Copy-Item -Recurse "$src\scripts\quest" "$dst\scripts\"
```

**依赖关系速查**：

```
Combat  ── depends on ──> Stats, Items（DamageInfo.DamageType 会被 skill/item 引用）
Equipment ── depends on ──> Stats, Items, Inventory
Inventory ── depends on ──> Items (+ 可选 Equipment for 事务化装备)
Loot     ── depends on ──> Items
Quest    ── 完全独立
Skills   ── depends on ──> Combat, Stats
Status Effects ── depends on ──> Stats
```

如果不想漏拷，最省事的做法就是**整个 `scripts/` 目录一起复制**。

### 第 2 步：注册 Autoload

打开 `project.godot`，加：

```ini
[autoload]

CombatEventBus="*res://scripts/combat/combat_event_bus.gd"
QuestEventBus="*res://scripts/quest/quest_event_bus.gd"
```

或者在 Godot 编辑器：Project → Project Settings → Autoload → 加两行同名脚本。

> **重要**：如果不注册 autoload，`StatusEffectManager` 里的元素反应 debuff 会静默不生效，因为 `CombatEventBus._ready()` 负责注册 `shocked / burning / frozen` 三个默认效果。

### 第 3 步：给玩家 / 敌人接入组件

创建（或修改）玩家场景，节点结构如下：

```
Player (CharacterBody2D)
├─ Sprite2D / AnimatedSprite2D
├─ CollisionShape2D
├─ StatsComponent          [base_stats: your_player_stats.tres]
├─ CombatComponent          [entity: <auto>, stats_component: <auto>]
├─ StatusEffectManager      [entity: <auto>, stats_component: <auto>]
├─ InventoryManager         [slot_count: 20, equipment_manager: ↓]
└─ EquipmentManager         [stats_component: ↑, inventory: ↑]
```

**Inspector 里的关键连线**：

1. `StatsComponent.base_stats` → 拖入一个 `StatsData.tres`（可以参考 [data/player_base_stats.tres](../data/player_base_stats.tres)）
2. `EquipmentManager.stats_component` → 拖入本节点的 `StatsComponent`
3. `EquipmentManager.inventory` → 拖入本节点的 `InventoryManager`
4. `InventoryManager.equipment_manager` → 拖入本节点的 `EquipmentManager`（启用装备事务化）

> **提示**：`CombatComponent` / `StatusEffectManager` 若不在 Inspector 里手动指定 `entity` / `stats_component`，它们会在 `_ready()` 里自动 `get_parent()` 和 `get_node("StatsComponent")`——所以你可以什么都不填。

### 第 4 步：在玩家脚本里发起攻击

```gdscript
extends CharacterBody2D

@onready var combat: CombatComponent = $CombatComponent
@onready var inventory: InventoryManager = $InventoryManager

func _unhandled_input(event: InputEvent):
    if event.is_action_pressed("attack"):
        var target = _find_nearest_enemy()
        if target:
            var info = combat.attack(target, 50.0, DamageInfo.DamageType.PHYSICAL)
            if info and info.is_critical:
                print("暴击 %d 伤害!" % info.final_damage)

    if event.is_action_pressed("use_potion"):
        inventory.use_item(0)   # 使用格子 0 的消耗品

func _find_nearest_enemy() -> Node:
    var enemies = get_tree().get_nodes_in_group("enemy")
    if enemies.is_empty():
        return null
    var nearest: Node = null
    var min_dist := INF
    for e in enemies:
        var d = global_position.distance_to(e.global_position)
        if d < min_dist:
            min_dist = d
            nearest = e
    return nearest
```

### 第 5 步：敌人挂上掉落 & 死亡

```
Enemy (CharacterBody2D)
├─ (add_to_group "enemy")
├─ StatsComponent           [base_stats: goblin_stats.tres]
├─ CombatComponent
├─ StatusEffectManager
└─ EnemyLootComponent       [main_loot_table: goblin_loot_table.tres]
```

`EnemyLootComponent._ready()` 会自动监听父节点的 `died` / `health_depleted` 信号；一旦敌人生命值归零就会通过 `LootGenerator` 生成掉落物。

如果你还没准备 `LootGenerator`，可以让它做全局 autoload：

```ini
[autoload]
CombatEventBus="*res://scripts/combat/combat_event_bus.gd"
QuestEventBus="*res://scripts/quest/quest_event_bus.gd"
LootGenerator="*res://scripts/loot/loot_generator.gd"
```

或者手工挂一个 `LootGenerator` 节点在你的关卡场景根。

### 第 6 步：验证

运行游戏，按你绑定的 attack 键：

- 敌人应该 `push_error` 或 `print` 显示掉血
- 敌人血量归零 → `died` 信号 → `EnemyLootComponent` 生成掉落物
- 玩家走过去撞到 `DroppedItem` → `InventoryManager.add_item(item)` → UI 刷新

---

## 三、方式 A：直接 fork（全新项目）

```bash
git clone https://github.com/ClarkWain/godot-arpg-kit my-game
cd my-game
rm -rf .git   # Windows: Remove-Item -Recurse -Force .git
git init
git add -A
git commit -m "chore: init from godot-arpg-kit"
```

修改 [project.godot](../project.godot) 里的：
- `config/name="ARPG_TEST"` → 你的游戏名
- `config/icon="res://icon.svg"` → 换成你的图标

然后正常开发。要拉上游更新时：

```bash
git remote add upstream https://github.com/ClarkWain/godot-arpg-kit.git
git fetch upstream
git merge upstream/master  # 或 cherry-pick 你需要的 commit
```

---

## 四、方式 C：git subtree（跟进上游）

如果你希望 kit 作为一个可更新的子模块存在于你的项目里：

```bash
cd my-existing-game
git subtree add --prefix=addons/godot-arpg-kit \
    https://github.com/ClarkWain/godot-arpg-kit.git master --squash
```

Godot 里把 `res://addons/godot-arpg-kit/scripts/**` 加入你的 preload 路径。

拉更新：

```bash
git subtree pull --prefix=addons/godot-arpg-kit \
    https://github.com/ClarkWain/godot-arpg-kit.git master --squash
```

**注意**：subtree 方式下你自己的项目结构不会污染 kit 的 `scripts/`，但 Godot 的相对 `res://scripts/...` preload 路径需要调整为 `res://addons/godot-arpg-kit/scripts/...`（这是本 kit 目前不完全适配 addon 用法的原因）。

---

## 五、常见踩坑清单

### 坑 1：`ItemInstance.create()` 提示 "data 不能为空"

原因：`item_data` 参数为 null。

```gdscript
# ❌ 错
var item = ItemInstance.create(null, 1)

# ✅ 对
var data: ItemData = preload("res://data/items/potion.tres")
var item = ItemInstance.create(data, 1)
```

### 坑 2：喝药水没回血

如果你走 `InventoryManager.use_item(slot)`，且 `InventoryManager` 挂在角色下（`get_parent()` = 角色本体），会自动定位 `StatsComponent`。若你的结构不同，显式传 target：

```gdscript
inventory.use_item(slot, player_node)   # target 参数
```

### 坑 3：伤害算出来是 0

多半是被闪避了。默认 `StatsData.dodge_chance = 0.05`。如果你在测试环境希望**确定命中**：

```gdscript
enemy_stats.dodge_chance = 0.0
```

生产环境是设计问题：要么给玩家加"命中率"字段（本 kit 未内置命中判定），要么调低敌人 dodge。

### 坑 4：装备后属性没变

- 装备前后需要 `StatsComponent` 自动刷新——本 kit 已经在 `add_modifier()` 里 `_mark_dirty()`，下一帧生效。
- 若装备后立即 `get_stat(...)` 拿到旧值：这是因为 `_mark_dirty()` 用 `call_deferred("_on_stats_recalculated")` 延迟到帧末。同帧内你可以主动调 `get_stat()`——它会检查 dirty 并强制重算。

### 坑 5：元素反应没 debuff

如果玩家火焰攻击带冰的敌人，应该触发"蒸发"（×2）+ 附加 `burning` debuff。若 debuff 没生效：

1. 检查 `CombatEventBus` 是否已 autoload（见 第 2 步）
2. 若你重写了 `_register_default_reaction_effects()`，确保 `burning` / `shocked` / `frozen` 三个 id 都注册了

### 坑 6：`class_name` 冲突

如果你自己项目里已经有 `class_name InventoryManager` / `EquipmentManager` / `CharacterStats`（老实说很有可能），Godot 编辑器会报**duplicate class name**。解决方式：

- **重命名你自己的旧类** — 推荐
- **重命名 kit 里的类** — 需要改多处引用，不推荐
- **只保留其中一份** — 二选一，把老的删了或改名 `class_name Legacy_InventoryManager`

### 坑 7：测试跑 flaky

Kit 自带的测试在 headless 下已经通过 `seed(0)` 消除了 flake。如果你**给 kit 加新测试**又出现 flake：

- 检查 test setup 里是否清零了 `StatsData` 的默认值（`dodge_chance=0.05` / `crit_chance=0.05` / `luck=10` 都会通过派生规则影响 rng-based 分支）
- 参考 [tests/combat/test_damage_calculator.gd](../tests/combat/test_damage_calculator.gd) 里对 attacker / defender 的完整清零模板

---

## 六、推荐的学习路径

1. **先跑通测试**：`pwsh tools/run_tests.ps1` → 66/66 combat 全绿
2. **看 [README.md](../README.md) 的伤害管线时序图**：理解 Attacker → DamageCalculator → Target 的数据流
3. **打开 [scene/inventory_example.tscn](../scene/inventory_example.tscn)** 等示例场景，F6 跑一下感受
4. **读 docs/ 各系统文档**：按你想接入的模块顺序
   - 只需要战斗？读 [docs/Combat战斗系统使用文档.md](Combat战斗系统使用文档.md) + [docs/Stats属性系统使用文档.md](Stats属性系统使用文档.md)
   - 需要背包 / 装备？加读 [docs/Items物品系统使用文档.md](Items物品系统使用文档.md) + [docs/Inventory背包系统使用文档.md](Inventory背包系统使用文档.md) + [docs/Equipment武器装备系统使用文档.md](Equipment武器装备系统使用文档.md)
   - 需要 loot / quest？加读对应文档
5. **写自己的 `.tres` 资源**：物品、掉落表、状态效果——本 kit 完全数据驱动
6. **跑 `pre-commit.ps1` 钩子**：让你的每次 commit 都自动验证测试

---

## 七、遇到问题

- 提 issue：https://github.com/ClarkWain/godot-arpg-kit/issues
- 或者直接 PR：欢迎补充其他集成方式的教程 / 修 bug / 加测试

祝你玩得开心！
