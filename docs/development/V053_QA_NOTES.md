# DEV-053 佩戴观感夹具说明

2026-10-30 EDT，head_qa053子代理。仅新增`game/tests/test_head_wear_v053.gd`，由root串行运行真实Godot；本代理未启动引擎、未运行实际游戏、未访问或改变正式玩家存档。

用户截图的两种头盔按素材轮廓映射为`fr_helmet_0`与`eng_helmet_0`；胸甲仅凭截图无法唯一确定。默认以黑色领口的`eng_armor_0`为主复现，另以`fr_armor_0`生成替代首页。不是读取正式存档来声称精确还原玩家装备。

夹具直接实例化生产`main.tscn`，在隔离QA默认档内存中换两套胸甲和两头盔，输出四张1440×810首页。固定菜单RiderView的clock/stride，另以相同fighter绘制2.84倍特写，恰为菜单1.42倍的二倍，不编辑截图。附两种头盔各四脸型×三种胡须及双向中立/前倾/后仰图。最初baseline/candidate01–03共11图；后补`dark_skin_high_collars`覆盖最深肤色无须、铁帽与三种高领胸甲混搭和三种地区头胸套装，均双向，更新后默认12图。`--armor=<id>`可限制首页和脸型页为指定胸甲；专项高领页仍检查自己的六组搭配。

运行例：`Godot --path E:/GALUMU/game --minimized --script res://tests/test_head_wear_v053.gd --log-file <新日志> -- --test-profile --captures=<新目录> --report=<新JSON>`。实际发布包测试使用外部脚本绝对路径且不传`--path`，让`res://`来自PCK。路径必须每轮新建；脚本拒绝覆盖已有report。

`passed`仅确认合法夹具与PNG保存成功。它不判断头盔是否贴合、不以alpha连通或断言数量证明比例自然。必须由root和独立美术审查者检查实际首页、头肩特写与姿态图，分别记录本轮修改前后结论。所有步骤是固定引擎夹具，不是OS输入或真人试玩。脚本只替换并恢复QA内存profile，不主动写任何存档。

## 补充早期头盔真实接触

新增`test_head_contacts_v053.gd`以相对路径继承同目录`test_equipment_battle_v051.gd`，只覆盖`run`与`finish`，保留现有生产有限调枪/换盾、Model扫掠命中、Main/Battle事件消费、完整落马与物理脱手路径。覆盖eng/fr/de三国tier0头盔，各攻击方向一例，均war且防守方HP=1、盾禁用的明确夹具；并非“一级枪必秒杀”的平衡结论。总计6例，目标部位必须是head，每例保存实际命中和脱手截图供判断视觉偏移是否可接受。

参数继续为`-- --test-profile --captures=<新目录> --report=<新JSON>`，可选`--budget-ms=55000`。实际EXE使用脚本绝对路径，不传`--path`；父脚本通过同目录相对路径加载，生产`res://`仍来自PCK。已有报告或非空截图目录会拒绝覆盖。脚本创建时本代理未运行，root执行结果另记总验证。
