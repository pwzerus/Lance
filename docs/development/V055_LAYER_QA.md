# DEV-055 枪柄遮挡回归夹具

用于复查本轮 OS 姿态检查发现的具体问题：骑手最大后仰、枪角约 `+.12` 时，握点后的枪柄曾画到面部上层。实际修复在生产绘制层；本夹具只调用生产 `RiderView`、`JoustMatch` 和 `FallenRider`，没有替代人体或枪的画法。

## 运行

由主负责人串行执行 Godot。先让正常导入生成脚本 UID；本说明不代表已经运行通过。

```powershell
& <Godot控制台程序或已导出的EXE> --path E:/GALUMU/game --script E:/GALUMU/game/tests/test_lance_layer_v055.gd -- --test-profile --captures=E:/GALUMU/docs/development/screenshots/v055/<新的run目录>/lance --report=E:/GALUMU/docs/development/logs/v055/<新的run名称>-lance.json
```

针对已导出 EXE 时省略 `--path`，其 `res://scripts` 应来自该包；测试入口仍是外部脚本。使用 GPU 窗口，不能用 headless。目录和报告必须是新路径，保护已有失败/成功证据。该脚本不修改 GameState.profile，不保存玩家进度。

## 证据范围

| 图 | 实际覆盖 | 需人工观察 |
| --- | --- | --- |
| `back_lean_whole.png` | 法国/英格兰入门开放盔，左右，中立/半后仰/最大后仰，枪角 +.12 | 后柄经过头颈区域时被人体正确遮挡，握枪处没有裂缝、前枪不消失 |
| `back_lean_broken.png` | 同上，但生产残枪长度 | 后柄与完整枪一致，断口和剩余前柄仍存在 |
| `back_lean_aim_extremes.png` | 最大后仰，左右，枪角 -.68 / +.12 / +.58 | 分层在高低瞄准边界不造成脸前残片或错误截断 |
| `released_whole_and_broken.png` | 左右、完整/断枪、竞技场/实战，production 独立落枪路径 | 武器的前段与后柄均存在；竞技场枪头/实战枪尖、断口没有因持枪拆层而缺失 |

持枪画面聚焦头肩，会裁掉部分远端枪尖；独立武器图保留完整武器。每个持枪样本记录绘制前后的规则手位/枪尖，并核对 `RiderView.arm_pose` 与规则握点一致。这只能证明绘制不修改挂点；不能凭此自动判定面部遮挡美观。需要原发布包对照时，可用同一夹具分别在原包和修复包运行，比较两个报告内同 ID 的 anchors。

独立落枪样本直接调用生产 `_release_lance()`，随后冻结刚体、隐藏已脱手人物，只观察这个释放边界的真实独立枪渲染。记录并核对释放前后手位和枪尖连续、原持枪图隐藏、独立绘制使用 `lance_only`。这不是实战命中、自然落马时序、自由落体物理或 OS 试玩证据；这些仍由主负责人的真实发布包操作和已有命中/落马测试覆盖。

## 交接

- 新文件：`game/tests/test_lance_layer_v055.gd`（UID 由引擎导入）、本文。
- 未改变生产实现、比赛规则、存档、装备和素材。
- 子代理只完成静态实现与自审，未启动引擎。运行结果、截图逐图判断和发现的修复由主负责人写入本轮审查/交接，不能将此说明当成通过记录。

## 主负责人实际运行回执

2026-10-30 EDT：root已串行运行源码layer01和最终v0.4.15-r2真实包export-layer01，两次均4图、44个夹具、退出0、failures为空，四图SHA逐一相同。root与独立fit_audit055审图，原后仰后柄遮脸消失，握点及独立完整/断枪未见新增截断。JSON的visual_acceptance=pending是工具有意不自动判定美术，人工结论写在本段及V055_INDEPENDENT_REVIEW，不改写自动结果。真实OS对照见manual01/02及V055_DESKTOP_PLAY。
