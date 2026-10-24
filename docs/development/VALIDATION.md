# v0.4 验收补充

本轮源项目规则114、战术19、AI观察5、集成43、动作30、响应16项通过。发布候选EXE/PCK集成43、动作30、响应16项也通过。日志均以 `logs/v04-` 开头；最终AI修复后的打包复验另记在 `V04_REVIEW.md` 附录。

最终交付导出为 `logs/v04-export-delivery.log`。结算遮挡修复后，同一EXE/PCK的43项集成通过，双模式与9张截图完成，分别见 `logs/v04-exported-integration-delivery.log`、`v04-exported-smoke-delivery.log`；最终动作专项在 `v04-exported-game-feel-delivery.log`。已目视确认最终胜负标题和两种模式说明。旧版校验和与发布包未覆盖。

`test_charge_response.gd` 覆盖起速/满速维持/缓降、超过点按缓冲的三秒长按、松开、实际控件最小尺寸不重叠、六组距离的镜头屏幕位移。第一次因为下拉框实际高度而失败，样式修正后通过；不是只检查设定坐标。

桌面证据 `logs/v04-desktop-click-confirmed.jsonl`、`screenshots/v04/16_desktop_tap.png` 来自OS级工具点按，不是引擎内部注入，也不是真人硬件操作。桌面短拖动只有约26ms；三秒长按来自引擎输入测试。不能将二者合称完整硬件验收。

复现新测试：`Godot_v4.5.1-stable_win64_console.exe --headless --path E:/GALUMU/game --script res://tests/test_charge_response.gd -- --test-profile`。GUI测试一次只跑一个。正式收藏存档不用于测试。

---

# v0.3 验收补充

环境：Godot4.5.1，Windows x86_64，Intel OpenGL Compatibility。全部使用隔离QA存档。导出包 `builds/LanceAndLaurel-v0.3/`，最终代码导出日志 `logs/v03-export-release.log`。

| 验证 | 结果与证据 |
| --- | --- |
| 规则与装备目录 | 114项通过，`logs/v03-rules-final.log` |
| 高低盾、支撑、后仰、两种模式 | 19项通过，`logs/v03-tactics-final.log` |
| AI延迟与近身承诺 | 5项通过，`logs/v03-ai-reaction.log` |
| 源项目集成 | 43项通过，`logs/v03-integration-final.log` |
| 源项目专项 | 30项通过，`logs/v03-game-feel-release.log` |
| 最终EXE/PCK集成 | 43项通过，`logs/v03-exported-integration-release.log` |
| 最终EXE/PCK专项 | 30项通过，`logs/v03-exported-game-feel.log` |
| 最终发布自动试玩 | 双模式、两次结算、9张截图，`logs/v03-exported-smoke-release.log`、`exported_screenshots/v03/` |
| 美术与UI | 十组双向装备及7张UI截图，`screenshots/v03/`、`logs/v03-gallery.log`、`v03-ui-states-release.log` |
| 测评Skill格式 | quick_validate.py通过，技能在 `skills/game-experience-critic/SKILL.md` |

规则对照12个孤立场景；正式AI的策略对照144次固定种子模拟，范围与限制见 `V03_REVIEW.md`。这些不是真人对战。发布运行约75秒，冲锋期间多数5秒采样为60FPS，退出阶段采样46FPS；没有跨机性能保证。

本轮未完成OS级鼠标点击：桌面接口应用授权超时两次。最早的鼠标探针仅记录无输入巡航，不能作为“已测真实左键”的证据。倒计时点按、持续按住、释放、鼠标移动、暂停及重开由引擎合成事件检查。手机同样只有合成触点。

早期专项在新催马语义下曾有1条失败断言：旧断言要求点按在倒计时就过期，和保留到起跑的修复目标冲突。后来改为先验证排队保留，再在冲锋验证过期与实际位移；最终30项通过。早期未正确镜像的对照夹具也已修为左右攻击者索引，未为夹具修改游戏终止条件。失败/诊断日志保留。

最初候选退出时有ObjectDB残留警告；最终verbose运行未再次出现该警告，仍记录一个 `Master` StringName未认领退出诊断。没有据此声称零退出诊断或长期无泄漏；比赛与写档检查通过。

复现时继续使用下面的PowerShell格式，把发布路径改为 `LanceAndLaurel-v0.3`；新脚本包括 `test_tactics.gd`、`test_ai_reaction.gd`、`tactics_benchmark.gd`、`strategy_benchmark.gd`。一次只运行一个图形测试，避免并发显存压力。

---

# v0.2 验收补充

新增冲锋、姿态、攻防、镜头、碎片和H显示专项测试 `game/tests/test_game_feel.gd`；同一高枪路径下验证站直中头、前倾盾挡、后仰闪避。规则114项、场景40项仍通过，发布包独立集成40项通过；最终EXE/PCK专项27项通过。日志分别为 `v02-rules-final.log`、`v02-integration.log`、`v02-exported-integration-retry.log`，专项结果见最终发布包的 `v02-exported-game-feel.log`。

最终交付程序位于 `builds/LanceAndLaurel-v0.2/`。完整发布包自动试玩已经完成双模式和两次结算、9张截图，日志 `logs/v02-exported-smoke.log`，截图 `exported_screenshots/v02/`。最后的教学圈上层显示修正另在发布包专项测试中验证。早期并发验收出现过一次分配/解码失败，独立重试通过；已如实记录在 `V02_REVIEW.md`。

专项测试命令与旧规则测试同样带 `-- --test-profile`；发布包通过 `--script E:/GALUMU/game/tests/test_game_feel.gd` 加载外部验收脚本，实际游戏代码、贴图与数据从 PCK 加载。QA存档与正式存档隔离。专项首次接触约3.925游戏秒，完整自动试玩冲锋期间的多数5秒采样为60FPS；这些不是历史单位或跨机性能保证。

---

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
