# 当前输入诊断：v0.4

以下操作现在指向v0.4最终发布复制件，入口仍为根目录 `Play-Input-Diagnostic.cmd`。窗口标题为 `Lance & Laurel v0.4 - Mouse input diagnostic`。等待首次左键点按才开始冲锋，便于记录起速。运行时位于 `builds/qa-v04-release/`，脚本为 `game/tests/manual_input_probe_v04.gd`，输出 `docs/development/logs/v04-user-mouse-input.jsonl`。重跑会覆盖该临时记录，已确认的证据已另存 `v04-desktop-click-confirmed.jsonl`。

新版OS级点按约0.43秒达到480，随后维持一段满速，第三秒约396；三秒持续按住在引擎输入测试中验证。详细范围见 `docs/development/V04_REVIEW.md`。正式存档继续隔离。

---

# v0.3 排查历史

玩家反馈左键没有效果，当前仍按未解决处理。不要用自动测试结论代替此投诉。

在本开发目录中双击 `Play-Input-Diagnostic.cmd`。窗口标题应为 `Lance & Laurel v0.3 - Mouse input diagnostic`，直接进入练习场，无需先点开始按钮。左上角显示收到的按下/松开次数、物理按住状态、冲刺命令、实际速度、阶段、暂停与最高速度。

按住左键约3秒，松开，然后用窗口右上角关闭。无需截图或手动上传日志。记录在 `docs/development/logs/v03-user-mouse-input.jsonl`，仅包含该游戏窗口输入与状态；不注入输入，不读取其他应用。诊断用 `qa_` 存档。

本开发机的诊断运行时位于 `builds/qa-v03/`，是最终v0.3 EXE/PCK的复制件，EXE命名触发隔离存档。正式Windows ZIP不包含此QA运行时，源码ZIP也不包含引擎；移到其他机器需要自行准备Godot4.5.1或同版本导出文件。未以诊断器加载成功声称真实鼠标通过。

定位依据：没有按下事件且物理状态一直false，查实际窗口/焦点/运行版本；有事件但boost不变，查场景输入与状态；boost为true且速度增长，继续查玩家看到的版本、镜头与速度反馈。根据记录定因，不预先认定玩家开错版本。

已观察到Explorer打开旧 `builds/LanceAndLaurel`，但用户具体运行的EXE尚未核实。桌面自动启动因物理Esc停止；恢复桌面操作需用户明确指示。
