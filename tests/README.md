# 测试与质量门槛

需要 **Godot 4.5 或更高、Python 3.9 或更高**。纯 GDScript，无第三方 addon 或 Python 包依赖。CI 固定验证 Godot 4.5 与 4.6.3；其他版本不等同于已经验证。

从仓库根目录运行（Windows 可将 `python3` 换成 `py -3`）：

```bash
python3 tools/run_tests.py
python3 tools/run_tests.py --only combat
python3 -m unittest discover -s tools/tests -v
```

PowerShell 使用相同实现：

```powershell
pwsh tools/run_tests.ps1
pwsh tools/run_tests.ps1 -Only combat
```

通过 `GODOT` 环境变量或 `--godot /path/to/godot` 指定引擎，默认从 PATH 查找 `godot`。支持 `--timeout 120` 和 `--output-dir /path/to/results`。

## 结果判定

入口先导入项目，再依次运行 Combat、Items、Loot、Quest、Stats 的真实测试场景。导入失败时不会继续。每个模块必须满足：

- 输出唯一、模块名称正确的 `[RESULT]` 汇总。
- 实际执行至少一个测试，计数一致且没有失败。
- Godot 退出码为 0，无意外引擎错误、脚本错误或资源泄漏。

只有 Items 的 `ItemInstance.create(null)` 和 Quest 的空任务 ID 测试允许各自的精确错误行；其他错误不能靠“汇总通过”掩盖。超时、零测试、重复或缺失汇总均返回失败。预期的业务警告保留在日志中。

每次运行创建独立的 `.godot/test-results/run-*/` 目录，保存导入日志、五个模块日志及机器可读 `summary.json`。实际测试数量以本次汇总为准，不读取历史报告。CI 上传这些文件作为构建产物。

Quest 与 Stats 的详细报告写到 Godot `user://quest_test_report.txt` 和 `user://stats_test_report.txt`，不会覆盖仓库文件。旧的仓库内报告仅是历史记录。

## 集成回归

Combat 模块包含两类任务集成检查：

- autoload 启动后创建、释放、重建 TaskManager，匹配事件只转发一次。
- 攻击敌人 → CombatComponent 死亡 → EnemyLootComponent 生成一个掉落物 → 拾取进入背包 → 装备移出背包并增加属性 → 击杀、收集、装备三个目标共同完成任务。

完整链路使用真实场景树和组件生命周期，并启用掉落对象池。业务层显式连接背包实际新增、装备、击杀信号到任务事件总线；核心组件不会替游戏决定任务规则。

图形交互、物理碰撞定位、平台导出与存档版本迁移仍需相应的专项验证，不能从 headless 测试通过推断。

## 添加测试

在相应模块的测试脚本中使用框架的 `start_test()`、断言和 `end_test()`，并把方法加入 `run_all_tests()`。新增测试文件需要加入模块 runner 的累计统计。异步测试必须由 runner `await` 到结束后再输出 `[RESULT]`；创建的节点、信号连接和计时器需要清理。

涉及组件集成时优先加入真实场景树，让 Godot 自动执行 `_ready()`，并验证状态、信号负载及实际副作用。不要用无断言的 `passed = true` 代替行为验证。


## 掉落运行时回归

Loot 模块还验证满包后的保留与重试、部分堆叠数量守恒、堆叠加新格子的事件数量、负重拒绝、缺少背包与自定义接收方、金币重复拾取、入包信号重入、对象复用状态复位、旧计时器取消、清场隔离、池满溢出、外部释放后补池、生成器销毁、无精灵消失及物品转金币的图标复位，以及真实物理碰撞触发拾取。Items 模块验证事件快照保留耐久、绑定、词缀和追踪 ID，且数量与嵌套数据互相隔离。


## 装备运行时回归

Items 模块验证满包卸装、空间预检查通过但实际入包拒绝、换装超重/等级失败的原位回滚、满格换装及重入、不同返还格子的通知、监听器填入原格子的通知隔离、背包和直接装备入口、缺少背包、重复实例、共享资源隔离、损坏/修理属性恢复，以及提交后通知中的正常监听器操作。


## 任务恢复回归

Quest 模块验证重复加载后的事件派发、旧实例信号隔离、空存档清场、损坏字段/未知任务/重复 ID 的失败保护，以及原生字典和 JSON 往返恢复、嵌套存档快照隔离。


## 物品存档恢复回归

Items 模块还覆盖物品字段校验、JSON 往返、存档字典隔离、重复背包格子和身份、失败保留金币与重量、装备错槽拒绝、重复恢复不叠加属性、损坏装备、重算套装件数、恢复通知与同步重入隔离。
