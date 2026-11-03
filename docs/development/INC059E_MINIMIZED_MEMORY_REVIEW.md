# INC-059E：最小化窗口的持续绘制导致原生内存暴涨

日期：2026-11-03；基线：5d3c2fd，分支 codex/v0.4。用户授权动态排查；始终单引擎、QA 存档、1 GiB Windows Job 硬限制，未让失控进程再次占到 40 GB。保护器不是根因修复。

## 已复现的因果链

1. 原版 v0.4.18 显示菜单四分钟未复现增长，说明此前短测/可见窗口测试不能覆盖故障。
2. `old-minimized-e01`：相同原版最小化后，已提交私有内存由第9秒683.6 MiB，经第10秒869.6 MiB，到第11秒1024 MiB；Job 阻止继续分配，保护器终止。显示帧号停止，资源数、纹理计数无相应增长。
3. `new-minimized-e01`：原 v0.4.19 候选虽然已经限制后台10FPS，仍从约613 MiB增至第30秒927.2 MiB并被终止。限帧只减慢问题，不能作为修复。
4. `old-frozen-e02`：原版，仅停止预览骑手 `_process`，其余窗口状态相同。最小化约48秒期间稳定约593 MiB，进程正常退出；包含启动阶段的峰值686.7 MiB。
5. `old-redraw-e01`：保持同一骑手动画停止，只每0.4秒调用一次 `queue_redraw()`。显示帧号保持245，绘制回调继续增加；私有内存增长至881.8 MiB。恢复窗口后回落至约599 MiB。这排除了“必须是动画状态数组持续增长”这一解释，定位到不可呈现窗口上持续重建绘制的路径。
6. `polygon-e01`：移除主场景、人物、贴图、蒙皮和战斗，只在 Node2D 绘制100个三角形。最小化时显示帧32不动、重绘计数增加，Godot静态内存约29.82MB、图形缓冲计数约6.41MB，Windows私有提交却持续升到957.1MiB而被保护器终止。`polygon-guard-e01`在同一夹具仅增加不可绘制判断，峰值386.2MiB，随后约381MiB稳定，恢复后约349MiB并正常退出。支持这是本机原生绘制路径的积压，而非骑手特有资源或游戏历史数组的增长。

以上是本机 Godot 4.5.1 / Intel OpenGL Compatibility 环境的实测，不把其他 Vulkan 报告直接当成证据。历史 Windows Event 2004 记录了原进程启动111秒已提交39.78 GB，但没有对应窗口状态或分配栈；可以确认并修复本轮重现的失控路径，不能据此断言历史每次系统卡死都只由这一条路径引起。

## 实现

- `core/window_activity.gd` 始终处理窗口状态，包括 SceneTree 暂停时。可见60FPS、不可呈现10FPS；战斗进入已有暂停流程，清除催马输入。恢复后保持暂停，玩家明确继续。
- `RiderView`、`BattleScene`、`ImpactFX` 在窗口不可呈现时停止持续更新/提交绘制；已排队的 `_draw` 也检查窗口状态。头部、马匹、特效与交锋规则没有重写。
- 恢复时递归请求一次 CanvasItem 重绘，避免暂停状态下角色 `_process` 不运行导致画面空白。headless 规则测试保留原处理语义。
- [`DisplayServerWindows::window_can_draw`](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/windows/display_server_windows.cpp#L2608)在此版本检查最小化状态。Godot 的[多边形绘制实现](https://github.com/godotengine/godot/blob/4.5.1-stable/drivers/gles3/rasterizer_canvas_gles3.cpp#L2191)会建立图形缓冲。下层分配未取得带符号堆栈，不把具体 Intel 驱动函数或第三方模块定为已证实责任方。

## 附加修复与保护范围

- 默认启动预算由固定4GiB改为2GiB系统保留+1GiB游戏硬上限+256MiB启动余量，即3328MiB；提交余量至少1280MiB。未提高游戏硬上限。运行仍在私有提交超过900MiB、可用RAM不足2GiB或可用提交不足512MiB时停止。
- 仅 `--headless` 诊断可用512MiB Job / 448MiB早停 / 2816MiB启动RAM预算。不能用于图形试玩；第一次误用此较低预算导出触发OOM，随后1GiB预算导出成功，失败证据保留。
- 默认启动写有界诊断日志，每个日志2MiB加一个历史轮替文件；不会把采样历史堆在RAM中。
- 拒绝 Godot `_console.exe` 包装器，避免只统计到约8MiB的父进程、漏看实际引擎。Job仍覆盖子进程，但进程级采样必须对主EXE；`fix-minimized-e01`因此主动终止，不用于报告内存峰值。
- 本轮沿用已完成的资源缩图、共享字体Theme、固定字体oversampling、12项装备纹理缓存和重复IK/蒙皮计算优化；这些有助于基础占用，但不是最小化暴涨的直接修复。

## 验证状态

- `fix-minimized-e02`：修复源码实际OpenGL，约270秒全程、约250秒最小化，启动峰值625.1MiB，最小化阶段590.7–590.9MiB，恢复后591.6MiB；EXIT 0。引擎静态内存约107MB、显示帧234、骑手重绘计数236在最小化阶段恒定。
- `suspend-cycle-e01`：源码真实窗口依次营地、军械库、捏脸、竞技场、实战、预先手动暂停，验证最小化停止模拟、暂停时10FPS、恢复60FPS、保持暂停、明确继续，以及最小化中关闭。约92秒，全部检查完成，EXIT 0；恢复截图已查看，人物与马仍可见。
- `package-suspend-e01`：最终独立EXE/PCK执行相同六种窗口/暂停/关闭回归；峰值682.3MiB，91.9秒正常EXIT 0，所有检查通过。
- `package-minimized-e02`：最终包约271秒全程，约250秒最小化，启动峰值约610MiB；最小化阶段575.9–576.1MiB，恢复后约580MiB，EXIT 0。节点28/资源81保持稳定；没有通过不断重启进程清掉内存。
- `package-replay-e02`：最终包连续约229秒，启动5局并自动重开4次、交替竞技场/实战练习，峰值662.5MiB，末段约605MiB，60FPS，节点66/资源81，正常EXIT 0。验证正常可见游玩路径没有被隐藏窗口修复停止。
- `post-exit-e03`：正常退出后又只读观察60秒，7次采样均无Lance/Godot进程；系统可用RAM3672–3794MiB，系统提交约18.89–18.99GB，未出现持续暴涨。系统计数包含其他软件，不当作本游戏占用。`post-exit-e02`的CIM查询被沙箱拒绝，内存字段null，明确排除该组内存结果。
- `export-fix-e01`：主Godot EXE受1GiB Job保护导出，峰值620MiB，EXIT 0，无脚本/导入/导出报错。使用独立目录，不覆盖原版和先前未修最小化问题的候选包。

最小化、连续对局、页面恢复及关闭均由同一个最终PCK验证；没有以进程强杀冒充正常退出。最终资源包34,282,416字节，相比原版73,656,200字节减少约53.5%；包含EXE的两文件体积由170.38MB减到131.01MB，约减少23.1%。基础资源优化来自本轮之前已保留的修复，本轮新工作是补齐后台绘制缺陷和最终发布验证。

自动化改变真实窗口状态属于引擎集成与真实图形运行，不属于真人手动试玩。没有启动其他人的应用或终止用户工作进程。

证据目录：`docs/development/logs/inc059b/`。保留失败日志。Windows正式玩家存档未用于本轮测试。

## 复验命令

必须使用新的report路径；夹具拒绝覆盖既有结果及非QA存档。下例路径中的 `RETEST` 每次更换。所有引擎命令串行运行。

```powershell
.\Start-MemoryBound.ps1 -Executable .\builds\LanceAndLaurel-v0.4.19-memoryfix\LanceAndLaurel.exe -Arguments '--script E:/GALUMU/game/tests/test_memory_windows_inc059.gd --log-file E:/GALUMU/docs/development/logs/inc059b/RETEST.log -- --test-profile --scenario=minimized --steps=360 --interval=0.6 --window-report=E:/GALUMU/docs/development/logs/inc059b/RETEST.jsonl' -TimeoutSeconds 285 -MemoryLog docs/development/logs/inc059b/RETEST-memory.txt
```

六种页面与战斗恢复使用 `test_window_suspend_inc059.gd`，传`--test-profile --window-report=新路径`，超时135秒。最小多边形对照使用主引擎`Godot_v4.5.1-stable_win64.exe --path E:/GALUMU/game --script E:/GALUMU/game/tests/test_minimized_polygon_inc059.gd`，同样传QA/report；加`--skip-hidden`为修复对照，遗漏此选项是故意触发已知故障，仍必须经过1GiB保护器。诊断脚本检查保护器环境标记，不要从普通未保护的Godot入口运行。
