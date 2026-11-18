# ANIM-105 接手复验说明

当前事实先看 HANDOFF.md 和实际分支/HEAD/未提交差异。本说明是最小复验路径，不替下一位接收者填写“通过”。运行源码 ba0f558007e9aa8720a36af747391ef4bc16dd7f；交付入口/证据提交 2e2f375a52d3d4722da82bdbd16379f55ba5a178；后续回执提交不改变PCK。

## 发布与保护

- 本地包：`E:/GALUMU/builds/LanceAndLaurel-v0.4.57-c3`。用户启动 `E:/GALUMU/Play-Latest.cmd` 或包最外层EXE。runtime内EXE只供保护器调用。
- ZIP约67.87MiB；精确字节/散列见ANIM105_EVIDENCE.json。GitHub分支包含源码/文档/代表图片，不包含Windows Release下载附件。
- 任何Godot实例都经Start-MemoryBound。真实GPU必须加-IsolatedDesktop；系统余量500MiB、启动预算1780MiB、进程组1024MiB、900MiB提前停止、CPU25%、单实例和有限时长保持。只看headless不能验动作。
- QA均用--test-profile，日志目录每次新建；别覆盖正式档/旧包/已有日志。默认user:// QA写权限不足时记录失败；不得去掉QA标志改写正式档。

## 最小后台画面复验示例

```powershell
$env:GALUMU_MEMORY_BOUND='1024'
$qaRun='E:/GALUMU/docs/development/logs/anim105-receive-'+(Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Path $qaRun -ErrorAction Stop | Out-Null
./Start-MemoryBound.ps1 -Executable 'E:/GALUMU/builds/LanceAndLaurel-v0.4.57-c3/runtime/LanceAndLaurel.exe' -Arguments "--path E:/GALUMU/builds/LanceAndLaurel-v0.4.57-c3/runtime --script E:/GALUMU/game/tests/test_motion105.gd --audio-driver Dummy --log-file $qaRun/engine.log -- --test-profile --folder=$qaRun/qa --coats=bay,black,flaxen,grey --kinds=ride,lean" -IsolatedDesktop -TimeoutSeconds 150 -MemoryLog "$qaRun/memory.log"
```

必须先检查report.json的passed和failures，再查看GPU图、engine.log和memory.log；旧QA有的通过主场景正常关闭，因此exit0并不保证报告通过。等EXIT和QA_DESKTOP_CLOSED=True后才启动下一实例。看图片不能冒充真人连续试玩；未听声音不能宣称听感通过。

## 按变化选择检查，不全量重复

| 要改哪里 | 对应现有验证 | 注意 |
| --- | --- | --- |
| 肩肘/抬枪/俯仰 | test_arms_v047、test_motion105、test_mounted_contact105 | 真实握点影响CCD，需规则对照；组合受击是受控夹具 |
| 落马/盾/地面 | test_fall098、test_fall_v057、test_fall_fuzz105、test_shield105、test_scene104 | 使用新的--report/--captures证据路径；scene104 --part=battle是受控KO，不是自然死亡概率 |
| 脱手/断枪 | test_release105、test_fracture105、test_fracture_scene105 | 位置/方向/动量连续，保留原概率和规则随机数 |
| 马网格 | test_skin_cache105、profile_skin105、test_motion105 | 原参考从a4bd10b取horse_skin.gd；--reference传只读路径；不把老实现打入PCK |
| 窗口/资源释放 | test_interruption105、test_hidden_result087 | 后者--normal-hud --hidden-seconds=90，计数须非空再检查隐藏停止 |
| 连续关卡 | test_beginner_ui100 --levels=1,2,3,4,5 | 自然解锁；实际一次第五关5:6输，不能替换成“全部通过” |
| 单关差异定位 | test_beginner_ui100 --levels=5 --qa-unlock-before=5 | 明确合成解锁；新旧单关均可6:6胜，不是连续通关证据 |
| 发布库存/迁移 | test_bundle087 --version=0.4.57-c3；launcher/Test-Portable.ps1 | 清单194物品；迁移检查10项；前者headless不验证画面 |

表中脚本均在game/tests；运行前用实际文件确认，不盲用历史文档名。证据JSON中的candidate、version、源码阶段决定归属；c1、c2、源码结果不能改称c3测试。四小时是开发/审查窗口，不是单次游戏持续运行四小时。

## 当前待验体验

旧约94ms长帧没有稳定复现，c3本机重甲4分钟最大32.529ms只说明该次改善。真人确认动作自然感、头胸盾声音和第五关的盾缘反馈；另一台电脑/实际输入/DPI尚未验。没有新证据时保留未确认状态，不为写“全部通过”修改失败门槛、隐藏身体或降低美术。
