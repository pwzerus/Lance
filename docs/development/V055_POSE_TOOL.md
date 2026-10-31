# DEV-055 交互头颈姿态查看器

`game/tests/test_head_manual_v055.gd`是外部QA脚本，仅用于鼠标操作固定姿态的生产骑手审图，**不是正式比赛，也不验证枪盾到位时间或碰撞**。由manual_pose055编写，未运行引擎；实际执行与图片判断由root记录。

启动实际包时不传`--path`，例如：

```text
LanceAndLaurel.exe --script E:/GALUMU/game/tests/test_head_manual_v055.gd -- --test-profile --captures=E:/GALUMU/docs/development/screenshots/v055/manual-pose01
```

输出目录必须不存在，脚本自行创建；测试必须GPU且GameState当前路径带`qa_`。脚本只加载Catalogue和内存Model，不更改GameState.profile，不调用任何存档写入，不注入输入，不自动切换装备或给审美打分。所有渲染使用发布包的`res://scripts/visual/rider_view.gd`，左右分别设置生产fighter.direction，而非镜像整张截图。

界面采用1440×810逻辑尺寸、1280×720窗口。上方选24头盔、24胸甲、四脸型、六肤色、五胡须；滑条覆盖lean[-1,1]、aim[-.68,.58]和guard[0,1]。中立/前倾/后仰按钮为固定姿态，受击按钮设置生产`impact_recoil=.85`供领口表面变形定格检查。视口固定生产头锚点附近，2.5倍缩放。Rider停用_process，只在手动控件改变后以0delta更新并重绘，避免不同观察帧的步态干扰。

“保存图”保存整个实际GPU视口为`pose_NNN.png`，同名JSON记录装备、外观、姿态、缩放、版本和时间。`events.jsonl`记录窗口输入事件、控件变化和每次截图的参数；输入标签表示窗口收到的OS事件，不声称是人类玩家生成。操作时通过Computer Use或用户鼠标控制，每一次选择的来源由root记录。渲染输入由控件直接设为静态值，与正式对局连续控制分开报告。

“退出QA”或关闭窗口结束会话。没有合格/不合格自动结论，图像连通或保存成功不能证明美术自然。

未覆盖：真实对冲、马匹速度/步态、完整落马、声音、头盔全部组合的自动穷举、真人满意度。其用途是补足正式游戏工具无法持续按住键时的左右极值和中间角度观察，不替代手动正式比赛。
