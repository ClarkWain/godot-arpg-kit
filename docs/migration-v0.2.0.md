# v0.2.0 升级与审核指南（尚未发布）

本轮目标是可靠、容易集成的 ARPG 核心库。`release/v0.2.0` 是供维护者审核的分支，目标版本为 v0.2.0；正式发布由维护者另行决定。本文面向从 v0.1.x 升级的项目。

## 本轮 feature / fix

| 类型 | 内容 |
|---|---|
| feature | Python 跨平台测试入口；PowerShell 与 CI 共享结果判定逻辑 |
| feature | Godot 4.5 / 4.6.3 测试矩阵、SHA-512 下载校验、当前运行日志与 JSON 汇总 |
| feature | 同步 `try_pickup()`、自定义 `pickup_handler`、`gold_picked_up` 通知 |
| feature | 背包、装备和任务恢复返回 `bool`；新增 `inventory_restored` / `equipment_restored` |
| fix | 死亡信号接入与带偏移父节点下的掉落位置 |
| fix | 部分堆叠数量、失败/重复/重入拾取及对象池生命周期 |
| fix | 卸装失败保护、换装原位回滚、重复实例与提交后的装备通知 |
| fix | 共享装备修正器隔离、损坏与修理属性恢复 |
| fix | 任务管理器延迟创建、销毁重建和读档后的事件索引及旧实例回调 |
| fix | 存档字段校验、加载失败保护、嵌套数据隔离、重复恢复属性与套装重建 |
| fix | 测试资源泄漏、报告位置及错误/超时/退出码质量门槛 |

## 1. 拾取信号改为转移后的通知

旧代码如果在 `loot_picked_up` 或 `item_picked_up` 回调中调用 `add_item()`，升级后可能重复入包。删除该转移逻辑，回调只用于 UI、声音和任务事件。

默认接收方为拾取角色下名为 `InventoryManager` 的子节点。需要其他接收规则时，在生成的掉落物上设置同步回调：

```gdscript
func receive_drop(drop: DroppedItem, picker: Node2D) -> bool:
    var target = picker.get_node_or_null("InventoryManager") as InventoryManager
    if not target:
        return false
    if drop.item_instance:
        return target.add_item(drop.item_instance)
    target.add_gold(drop.gold_amount)
    return true

# 在掉落物生成后、拾取前设置。
drop.pickup_handler = receive_drop
```

回调必须同步完成转移，不能等待异步结果。完整接收返回 `true`；拒绝返回 `false`。使用 `InventoryManager.add_item()` 时，部分接收会更新地面物品的剩余数量并返回 `false`，拾取通知报告实际转移数量；不要在旧通知中再次转移。

`try_pickup()` 的返回值表示是否完整接收，部分接收也可能已经发出通知。通知携带物品快照，不能将它当成背包中实际实例的引用。金币使用 `gold_picked_up(amount, picker)`；旧物品通知中的金币物品参数仍为 `null`。

## 2. 装备与背包双向连接

```gdscript
inventory.equipment_manager = equipment
equipment.inventory = inventory
```

配置实际 EquipmentManager 后，`InventoryManager.equip_item()` 要求这两个引用一致。默认卸装没有背包或背包不能接收时，返回失败并保留装备。手动接管物品时，先保存实例引用，再显式脱离：

```gdscript
var item = equipment.get_equipped(slot)
if equipment.unequip(slot, false):
    # 调用方从这里负责 item 的后续归属。
    hand_to_storage(item)
```

装备相关通知在转移提交后发出；同步重入的装备、卸装和耐久修改被拒绝。只提供 `equip()` 的旧通用适配器仍可使用，但不具备实际 EquipmentManager 的完整通知隔离约定。

## 3. 检查存档恢复返回值

已有合法存档字典格式继续支持，包括 JSON 中表示整数的浮点数；缺失物品实例 ID 的旧数据会生成新 ID。

```gdscript
if not inventory.from_dict(saved_inventory, item_database):
    show_load_error("背包恢复失败，当前背包保持")

if not equipment.from_dict(saved_equipment, item_database):
    show_load_error("装备恢复失败，当前装备保持")

# 调用前先注册存档涉及的全部 TaskData。
if not task_manager.load_data(saved_tasks):
    show_load_error("任务恢复失败，当前任务保持")
```

这些调用分别保证单模块失败时保留原状态。上面的示例展示各接口的返回值处理，不代表整份角色存档的联合事务。联合加载、跨模块重复物品身份检查与存档版本迁移仍由调用方协调。

未知物品或任务、重复实例/格子/任务 ID、错槽或非法字段，现在使整个模块恢复失败，替代过去跳过条目或静默截断数量的行为。`ItemInstance.from_dict()` 解码失败返回 `null`。旧存档存在这些问题时，应由游戏提供显式修复或迁移策略。

装备恢复保留存档中的绑定状态和耐久，不重新执行等级检查、装备绑定或背包转移。套装件数从实际装备重算；损坏装备不应用属性，其他来源修正器保持。

## 4. UI 监听恢复通知

| 模块 | 成功恢复通知 | 接入建议 |
|---|---|---|
| 背包 | `inventory_restored`、`gold_changed` | 重绘全部格子和金币；恢复不发出拾取/使用事件 |
| 装备 | `equipment_restored` | 重绘槽位；恢复不发出装备、卸装、变更或套装玩法事件 |
| 属性 | 装备恢复后一次 `modifiers_changed` | 读取提交后的属性；原先屏蔽的信号保持屏蔽 |
| 任务 | 不发送进度通知 | 恢复成功后重新获取实例并刷新任务 UI |

成功恢复后，通过管理器重新获取实例。旧任务实例不再向管理器发送回调。保存和恢复时，嵌套自定义数据、任务元数据及进度字典均使用深拷贝。

## 5. 验证范围

Godot 套件从历史记录的 189 项增加到 228 项：

| 模块 | 当前数量 | 本轮主要回归 |
|---|---:|---|
| Combat | 67 | TaskManager 延迟创建/重建；真实攻击→死亡→掉落→拾取→装备→属性→任务链路 |
| Items | 38 | 1 项物品快照、14 项装备运行时、5 项物品/背包/装备存档恢复 |
| Loot | 26 | 15 项拾取、对象池、金币及真实碰撞回归 |
| Quest | 58 | 3 项重复恢复、失败保护与快照隔离回归 |
| Stats | 39 | 属性套件继续通过 |
| 总计 | 228 | Godot 4.5 / 4.6.3 均已本地通过 |

另有 5 项 Python 测试验证测试工具的失败处理。完整链路替换了原有的空泛断言，并非所有改进都增加测试数量。主场景 headless 启动通过；图形交互、复杂碰撞布局、平台导出和真实旧项目迁移仍需专项验证。

运行方式见 [测试说明](../tests/README.md)。本分支推送会触发 CI；远端执行结果以 GitHub Actions 为准。
