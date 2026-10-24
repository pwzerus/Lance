# v0.1 验收记录

环境：Godot 4.5.1 stable f62fdbde1，Windows x86_64，OpenGL Compatibility；本机 GPU 为 Intel Graphics。记录于 2026-10-24 UTC。

## 已通过

| 验证 | 结果 | 证据 |
| --- | --- | --- |
| 规则与目录断言 | 114 项，通过 | `game/tests/results.json`、`logs/rules-final.log` |
| 实际场景集成 | 40 项，通过 | `game/tests/integration_results.json`、`logs/integration-final-v2.log` |
| 独立 EXE + PCK 集成 | 相同 40 项，通过 | `logs/exported-integration.log`，工作目录为不含项目的 `builds/smoke_work/` |
| Windows 发布导出 | 成功 | `logs/export-final.log` |
| 独立程序自动试玩 | 主界面、军械库、历史、竞技场、结算、实战、结算 | `logs/exported-smoke-final.log`、`exported_screenshots/` |
| 中文段落与字体 | 389 像素段落正确换为三行，字重轴 500 | `logs/ui-metrics-v4.log` |
| 美术与界面 | 十组双向装备、首次说明、设置、后期装备、暂停 | `screenshots/08_*` 至 `13_*`、`logs/art-gallery-final.log`、`logs/ui-states.log` |
| 文本源文件编码 | 未发现无效 UTF-8 | 对游戏目录的 gd、tscn、json、py、md、svg、cfg 执行严格解码检查 |

114 为断言数量，包含装备 ID 与槽位校验，不等于 114 场真人对战。场景测试通过按钮回调、实际输入事件与时间等待覆盖不同系统之间的连接，也不替代真人手感测试。

## 覆盖的风险

- 平移与旋转枪尖扫掠、移动目标、短残柄弧线、高速命中与干净未命中的区别。
- 同帧命中、一次攻击去重、三轮上限、HP 决胜、竞技场新枪不回血、实战断枪持续、终止后不继续伤害、实战实际死亡与竞技场非致死。
- 慢动作不提前消耗过阵冲刺；顿帧真实时钟恢复；暂停冻结身体与镜头；终局马匹跟随时间效果；重开和返回营地恢复全局状态。
- 鼠标上下瞄准、持续左键与 W、释放恢复、滚轮与中键；Esc 与 R；三个触点 ID、跨屏区、抬起和取消。触控是合成事件，未通过手机实机。
- 购买、扣费、防重复购买、装备所有权与解锁、磁盘重载、存档字段类型损坏、无法写入时回滚、损坏主档回退备份、比赛奖励去重。
- 已有血迹和粒子清理，以及血腥视觉不消耗比赛规则随机数。

## 复现命令（PowerShell）

```powershell
$godotExe = 'E:/GALUMU/tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
& $godotExe --headless --editor --path E:/GALUMU/game --import --quit
& $godotExe --headless --path E:/GALUMU/game --script res://tests/test_rules.gd -- --test-profile
& $godotExe --path E:/GALUMU/game --script res://tests/test_integration.gd -- --test-profile
& $godotExe --headless --path E:/GALUMU/game --export-release 'Windows Desktop' E:/GALUMU/builds/LanceAndLaurel/LanceAndLaurel.exe
& 'E:/GALUMU/builds/LanceAndLaurel/LanceAndLaurel.exe' --script E:/GALUMU/game/tests/test_integration.gd --log-file E:/GALUMU/docs/development/logs/exported-integration.log -- --test-profile
```

自动截图通过主场景的 `--smoke-test --screenshots <已存在的目录>` 用户参数启动；程序自动使用 QA 存档。命令前的第二个 `--` 不能省略。发布版验收脚本从项目外部读取，测试脚本本身未打入 PCK；实际主场景、编译脚本、数据、字体和贴图均从 PCK 加载。

## 未验收和下一阶段

没有真人手感评分、跨设备性能基准、其他显卡/Windows 机器验收、手机设备测试、长期断电/磁盘硬件故障测试。合成声音已经接入，未作专业听感和混音验收。没有把历史启发图像称为完整结构复原。

下一阶段先根据实际试玩调整鼠标灵敏度、AI 的反应与攻击偏好、冲锋和重整节奏，再制作马匹逐帧步态、落马约束和更多按实物建档的防具组件。
