# v0.4.9 验证记录

本记录区分规则模拟、引擎脚本注入、实际渲染与 Windows 发布包运行。通过的自动检查说明这些限定场景没有发现对应回归；它们不代表玩家已经认可马匹真实感、命中张力或游戏趣味性。

## 发布身份与当前状态

| 项目 | 记录 |
| --- | --- |
| 版本 / 分支 | v0.4.9 / `codex/v0.4` |
| 发布运行时代码 | `8c9108834df2aadf4f97e389bdc85dab42d358b8` |
| 引擎 | Godot 4.5.1 stable，Windows；渲染日志为 OpenGL 3.3 / Intel Graphics |
| Windows 程序 | `E:/GALUMU/builds/LanceAndLaurel-v0.4.9/LanceAndLaurel.exe` |
| PCK SHA-256 | `E81C28C27650F06FE3D22F8C250F628CBE9A47F359BEA9BBFCE0F14AD6015307` |
| 导出 | 已完成；[export01.log](logs/v049/export01.log) |
| 实际 EXE 专项复验 | `release-scene01` 通过，版本字段为 0.4.9 |
| 实际 EXE 全流程冒烟 | `release-smoke01` 已完成，退出码 0，9 张截图及两模式结果界面 |
| 桌面实际输入 | `desktop01` / `desktop02` 已结束，退出码均为 0；限定证据见下文 |
| ZIP 解压校验 | CRC通过，三文件散列一致，解压EXE实际启动退出0；见下方归档段 |

专项脚本通过 `--test-profile` 使用隔离 QA 档；发布包冒烟使用下文记录的 `--smoke-test` 启动流程。早期源工程报告中的版本字段仍为 0.4.8，不能将它们描述成最终 EXE 的重复测试；最终发布包证据单独列出。

## 源工程证据

| 记录 | 结果与实际覆盖 | 边界 |
| --- | --- | --- |
| `skin01`–`skin05` | 五次开发过程记录均通过；真实 RiderView 双方向世界位移、30/60/120Hz 几何回归；每次另渲染 480 帧、8 张指定观察图，展示四档恒速、起步、持续催马和松手减速。 | 五次记录对应不同实现阶段，不能当成最终版本五次重复运行。固定 30fps 展示不等于机器实际能稳定达到 30fps。 |
| `arms01` | 双方向、双臂及俯仰/瞄准/盾位极值；实际有限速控制、IK 分支连续性、30/60/120Hz 收敛检查通过。盾牌全程升降各约 0.358 秒。 | 自动几何检查不等于人体美术已获玩家认可，也没有真实鼠标操作证据。 |
| `hud01` | 正式 BattleScene 两模式，在 1280×720、1440×810、1920×1080 项目拉伸配置下渲染；正常 HUD 与骑手马匹包络、抬盾近景、俯仰命中提示、canvas 坐标及按钮输入隔离通过。 | 本次三个窗口均为 16:9；不据此扩张为最小窗口、任意比例或连续镜头的全面验收。 |
| `timing01` | 纯生产 ExchangeDirector 在 30/60/120Hz 检查预算、暂停、回合切换、设置切换、大 delta、同批顺序和重复命中；两模式真正 Model 扫掠错过均无命中。 | 命中预算与控制限速部分使用明确的合成事件；正式 Battle/Engine.time_scale 的集成证据来自 scene 系列。 |
| `smoke01` / `smoke02` | 源工程流程运行均结束；`smoke02` 留下首页、军械库、历史、两模式战斗/命中/结果等 9 张图。 | 脚本流程与截图，不是玩家试玩或 Windows 原生鼠标输入验收。日志的瞬时 FPS 不能作为完整性能结论。 |

源报告：[skin01](logs/v049/skin01.json)、[skin02](logs/v049/skin02.json)、[skin03](logs/v049/skin03.json)、[skin04](logs/v049/skin04.json)、[skin05](logs/v049/skin05.json)、[arms01](logs/v049/arms01.json)、[hud01](logs/v049/hud01.json)、[timing01](logs/v049/timing01.json)。

动作图存放于 [skin01](screenshots/v049/skin01)、[skin02](screenshots/v049/skin02)、[skin03](screenshots/v049/skin03)、[skin04](screenshots/v049/skin04)、[skin05](screenshots/v049/skin05)；HUD 图位于 [hud01](screenshots/v049/hud01)，源流程图位于 [smoke02](screenshots/v049/smoke02)。

### 马身与腿根回归的具体含义

`skin02`–`skin05` 的修订标签依次为 `v049-continuous-skin02`、`v049-skin02-optimized`、`v049-tapered-wrist`、`v049-four-leg-skin`。`skin01` 标签仍为 `0.4.8`。保留这条证据链，以便比较连续皮肤、优化及四腿覆盖过程，不将早期图冒充最后实现。

最终源展示 `skin05` 的双方向六组几何记录中，根连接误差为 0，最大支撑蹄世界滑移约 0.00391，最大蹄速度约 2182.97 单位/秒，最大脚尖角速度约 10.084 弧度/秒，均在既有限值内。四档恒速 110/210/340/480 的马身峰谷幅度分别约 2.99/6.39/10.65/15.13；慢步观察帧至少两蹄支持，其余步态包含腾空，各腿均记录落蹄。实际模型催马达到 480，松手降回 210。

这些数据保护原有根挂点、骨长和接地连续性，**不独立证明皮肤接缝肉眼不可见**。两方向、四步态及加减速的连续渲染和观察图才是检查腿根视觉接缝、前后遮挡与轮廓的材料；本记录不以拓扑或断言数量代替美术验收。

### 时间导演的规则范围

`timing01` 的离散采样中，无命中接近段最低 scale 为 0.45，减速加退出约 1.367–1.392 秒；真正 Model 错过最终均交错而过且 hit_count=0。合成命中从接触到退出的采样总时长不超过约 0.60 秒。还覆盖退出只剩约 20ms 时关闭慢动作，确认不会重新分配完整退出预算或回跳。

这些是给定 delta 的状态/预算检查，不能将某一离散采样归属阶段的时长直接称为屏幕实际停顿时长，也不能由此推断 GPU 帧率。

## 正式战斗集成：保留失败与测试修订

| 记录 | 结果 | 应如何解释 |
| --- | --- | --- |
| [scene01](logs/v049/scene01.json) | 失败：`An effect voice continued through pause`；保留 21 张图与原日志。 | 原测试对已结束/空闲音效池槽也要求 `stream_paused=true`，造成假阳性；没有据此修改生产音频逻辑。 |
| [scene02](logs/v049/scene02.json) | 修正活跃播放检查后通过，保留 21 张图。 | 音效状态证据有效，但“请求暂停 140ms”不是实际墙钟时长证据：整个暂停加恢复探针只记录 80ms。不能宣称这一轮证明了 140ms 暂停。 |
| [scene03](logs/v049/scene03.json) | 源工程 0.4.9 通过，`--no-captures`。 | 改用单调墙钟截止循环，实测暂停 143ms、恢复观察 83ms；首帧仍等待引擎绘制，只关闭同步 PNG 保存。 |
| [release-scene01](logs/v049/release-scene01.json) | 实际导出 EXE 通过，`--no-captures`。 | 同样的正式场景集成脚本从 EXE/PCK 加载生产资源；实测暂停 144ms、恢复观察 82ms。 |

Godot 4.5.1 的空播放槽不会保存暂停状态；因此修订测试按实例 ID 保存播放列表、`has_stream_playback`、paused、playing 与播放位置，对仍存在的活跃播放要求暂停，并增加新播的 1.2 秒 horn 作为不会在观察窗口自然结束的控制组。结束/空闲槽不要求暂停为真。实现依据可查 [Godot 4.5.1 AudioStreamPlayerInternal](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/audio/audio_stream_player_internal.cpp#L164-L178)。

实际 EXE 的 horn 在立即暂停、144ms 后、立即恢复三个采样中的位置均约 0.01161 秒；恢复观察后约 0.09868 秒。测试允许 40ms 混音位置粒度误差，未要求逐音频采样精度。还核对暂停期间模型/步态/冲击偏移/焦点、命中文字剩余寿命及风声/音效的冻结与恢复。

### 最终 EXE 的实际模型事件

以下数值来自 `release-scene01`，事件均由 Model 的真实扫掠步骤生成，再由正式 BattleScene 消费；控制为脚本和引擎处理函数注入。

| 场景 | 实际事件 / 终态 | 接近已用预算 / 命中已用预算 |
| --- | --- | --- |
| 竞技场盾击，慢动作开 | shield，伤害约 1.014，未死亡；scale 恢复 1 | 0.466s / 0.56667s |
| 竞技场盾击，慢动作关 | shield，伤害约 1.018，未死亡；仍有短接触停顿后退出，scale 恢复 1 | 0 / 0.15668s |
| 实战躯干，慢动作开 | body，伤害约 40.151，未 KO；scale 恢复 1 | 0.583s / 0.600s |
| 竞技场错过，慢动作开 | 0 个接触事件，成功交错，未进入真实命中演出；scale 恢复 1 | 1.150s / 0 |
| 实战错过，慢动作关 | 0 个接触事件，成功交错；scale 保持/恢复 1 | 0 / 0 |
| 实战预设受伤者，慢动作开 | 防守者明确从 1HP 开始；body，KO/dead，phase=ended，演出结束 scale 恢复 1 | 0.581s / 0.600s |

表中是导演内部消耗的真实 delta 预算，不能当作一段无暂停、无测试开销的完整录像时长。1HP 场景验证终局恢复与允许死亡的模式契约，不证明满血平衡或头部一击必杀已解决。

额外集成检查包括：

- 同一 `Model.step` 产生两个真实盾击事件；将同一状态与这批事件正序/逆序交给正式场景，得到相同 contact 状态、scale、强度、焦点与预算，避免数组顺序决定演出。
- 首次接触后人为把上一视觉时间戳设为旧 150ms，首个真正绘制帧仍保留 contact，队列音效与冲击从首个可见帧开始。150ms 是注入的旧时间戳，**不是实际睡眠或低帧率运行证据**。
- 慢动作设置开/关下均保留枪与盾的有限速响应；没有以命中或慢动作为理由瞬移瞄准/护盾。
- 终局、离开场景和测试清理后恢复 `Engine.time_scale=1`；暂停/恢复不消耗命中剩余预算。

### PNG 观察与无截图计时不可混用

`scene01`、`scene02` 的 [观察图](screenshots/v049/scene02) 证明引擎渲染过对应状态。同步 PNG 编码/写盘会阻塞测试循环；随后一次 `_process` 可能一次消化较大的墙钟间隔。由这些图之间的时间差推断接触停顿、阅读段持续时间或真实帧率会产生偏差。

`scene03` 与 `release-scene01` 使用 `--no-captures`，消除 PNG 写盘停顿，并以 `Time.get_ticks_msec()` 截止循环测量暂停/恢复。它们仍包含测试驱动和渲染等待开销；采样密度不是 GPU FPS，也不是桌面人工试玩视频。图像可读性与时间预算分别引用各自的证据。

## 实际 EXE 全流程冒烟

`release-smoke01` 已结束，主负责人确认退出码 0。[运行日志](logs/v049/release-smoke01.log) 标识 `GALUMU_BUILD v0.4.9`，最后输出 `SMOKE_TEST_COMPLETE`；约 80 秒的流程覆盖首页、军械库、历史页、竞技场战斗/命中/结果，以及实战战斗/命中/结果，保存 [9 张截图](screenshots/v049/release-smoke01)。两模式均推进至第三轮并到达 ended，末次状态 scale=1。它补充了专项场景脚本未展示的正式 Main 结果界面证据。

以下为该次**已执行命令记录**；其中 `--screenshots` 和目录是分隔参数。原路径已有证据，再次运行时应换新日志与截图目录。

```powershell
& 'E:/GALUMU/builds/LanceAndLaurel-v0.4.9/LanceAndLaurel.exe' `
  --log-file 'E:/GALUMU/docs/development/logs/v049/release-smoke01.log' `
  -- --smoke-test `
  --screenshots 'E:/GALUMU/docs/development/screenshots/v049/release-smoke01'
```

该流程仍由游戏内冒烟脚本驱动，不是真实 OS 左键/鼠标输入，也不代表玩家试玩验收。日志中常见瞬时 60fps，另有 40/46fps 等采样；这不是帧时间分布、GPU 性能分析或全程稳定帧率结论。

## 可复现命令

以下为 PowerShell 复验命令，使用新的报告名，避免覆盖现存证据。发布包排除 `tests/*`，所以必须将脚本作为**绝对外部路径**传给实际 EXE；脚本加载的生产 `res://` 资源来自该 EXE 对应 PCK。不要把源工程运行写成发布包通过。

```powershell
& 'E:/GALUMU/builds/LanceAndLaurel-v0.4.9/LanceAndLaurel.exe' `
  --script 'E:/GALUMU/game/tests/test_exchange_scene_v049.gd' `
  --log-file 'E:/GALUMU/docs/development/logs/v049/recheck-release-scene.log' `
  -- --test-profile --no-captures `
  --report-path=E:/GALUMU/docs/development/logs/v049/recheck-release-scene.json
```

若需要另留图像证据，移除 `--no-captures` 并指定新目录；该运行的采样时间须标记为包含 PNG 保存停顿：

```powershell
& 'E:/GALUMU/builds/LanceAndLaurel-v0.4.9/LanceAndLaurel.exe' `
  --script 'E:/GALUMU/game/tests/test_exchange_scene_v049.gd' `
  --log-file 'E:/GALUMU/docs/development/logs/v049/recheck-release-captures.log' `
  -- --test-profile `
  --capture-dir=E:/GALUMU/docs/development/screenshots/v049/recheck-release-captures `
  --report-path=E:/GALUMU/docs/development/logs/v049/recheck-release-captures.json
```

上述命令是复验步骤，不表示本记录作者另外运行过一遍。已完成的实际 EXE 证据以 `release-scene01.log/json` 为准。

## Windows 桌面实际输入：desktop01 / desktop02

主负责人通过桌面工具操作正式 v0.4.9 EXE，加载只记录、不生成引擎输入事件的外部 `test_desktop_v049.gd`，使用 `--test-profile`。两次会话均已结束，主负责人确认退出码 0。[desktop01.jsonl](logs/v049/desktop01.jsonl) 与 [desktop02.jsonl](logs/v049/desktop02.jsonl) 记录正式 EXE 路径、`injection=false` 及不同的 `user://qa_desktop_v049_*.json` QA 存档路径。派生数值与原始事件见 [desktop-summary.json](logs/v049/desktop-summary.json)，其中保留原日志 SHA-256。

这是 Windows 桌面输入链路证据，和前面的引擎处理函数注入不同；它仍是开发者通过桌面工具验收，**不是玩家本人连续试玩或手感满意度评价**。状态约每 100ms 采样，不能由相邻记录证明每一渲染帧。

| 动作 | 日志核实的结果 | 限定范围 |
| --- | --- | --- |
| `desktop01` 菜单进入与调枪 | 三组菜单左键事件到达，随后进入 ready。主负责人观察到开始/练习/教程界面流程。鼠标拖动时，aim 从约 0.57997，经 0.50664、0.24997、0.02997、−0.19003、−0.41003 到 −0.59724。 | 菜单名称与画面对应由主负责人观察；JSONL 本身不记录页面标签，也没有单独记录鼠标 motion 事件。瞄准采样体现渐变，不是每帧角速度分析。 |
| `desktop01` 的 R 重开 | logical=82 到达；前一采样为 ended/pass3，之后 24ms 的首个采样已 ready/pass1，x=−2200、speed=0、scale=1。 | 证明该次结果后的重开，不扩大到所有退出/重开路径。 |
| 护腹键 3 | `desktop01` 及 `desktop02` 均收到 logical=51。第二次在冲锋中按下后，guard_target 从 0.43 改为 0；guard 记录为 0.43→0.19667→0，首次记录到 0 距按键 167ms。第一次也记录到中间值 0.24333。 | 确认预设护腹与有限速换盾到达；167ms 包含约 100ms 状态采样误差，不作为精确动画时长。 |
| `desktop02` 暂停 / 恢复 | 两次 Esc 按下相隔 32.233 秒；318 个暂停样本覆盖 32.119 秒，始终为 ready/pass3。x=−2200、speed=0、guard=0、gait/back_y/rider_y/pitch=0、aim≈0.57997、zoom≈0.80308、camera_offset 与 hits_seen 均不变。第二次 Esc 后首个采样 paused=false，随后恢复第三轮 charge 并重新加速。 | 主负责人连续两次截图也观察到相同准备画面。此处是在准备阶段暂停，不证明 OS 操作下命中瞬间或运动中暂停；后者仅有前述引擎专项证据。日志没有音频播放头。 |
| `desktop02` 护头键 1 | logical=49 到达，guard_target 从 0 改为 1；guard 采样为 0.04667→0.37333→0.70000→0.98000→1，首次记录到 1 距按键 428ms。 | 主负责人截图显示“换盾中”；日志与画面一致，未瞬移到目标。`desktop01` 的另一次键 1 发生在 ended，未改变护盾，不拿它充当战斗成功证据。 |
| 结算、回营与保存退出 | `desktop02` 最终到达 ended/pass3、scale=1，之后记录两组菜单点击；主负责人观察正常结算、回营地、保存退出。 | logger 不记录菜单标签、存档文件散列或重新加载结果，故不据此宣称持久化重载已验证。 |

### 催马桌面证据的实际边界

`desktop01` 唯一发生于战斗中的左键按下为 107462ms，释放为 107492ms，**实际仅 30ms，不是 3 秒长按**。107465ms 的采样中 `raw_button`、`mouse_held`、`boost` 同时为 true，速度从之前的 210 变为约 210.41667；107575ms 的下一采样已三项全 false、速度回到 210，距释放 83ms。`desktop02` 没有 boost=true 的样本。

这证明短按确实到达游戏，并在松开后解除催马；没有证明持续按住的加速幅度、最高冲刺速度、高速松手减速曲线或玩家能明显感到加速。`desktop01` 所有记录的速度范围为 0–210.41667，`desktop02` 为 0–210；这些是本次采样范围，**不是马匹速度上限**。连续 3 秒 OS 长按仍待专门验证，不能用规则模拟或拖动工具的名称补足这一证据缺口。

## Windows 归档与解压启动

`builds/LanceAndLaurel-v0.4.9-Windows.zip` 使用 PowerShell Compress-Archive 创建，三个条目为同一版本目录下的EXE、PCK和README；Python zipfile.testzip 返回 null（CRC未报错），PowerShell Expand-Archive 解压到新目录 `builds/verify-v049-windows`。三个解压文件SHA256均与发布目录一致，未覆盖旧发布或旧验证目录。

- ZIP SHA256：`F0149B02D21D8139772C1397210D73AFC7C62F77E825D6F0BBE538F28C29657C`。
- 解压EXE以 `--quit-after 120 -- --test-profile` 实际启动OpenGL窗口，自动退出0；[archive-start01.log](logs/v049/archive-start01.log) 标识v0.4.9且没有引擎错误/警告。此项是启动完整性检查，不是另一遍完整比赛或OS操控。
- [package-manifest.json](logs/v049/package-manifest.json) 记录EXE/PCK/README尺寸及两处散列；旧v0.4.8 PCK仍是 `B88FA47AC141A0B603E5214B1ADA08A472DCB4787F23609B91A669DD091CADD0`。
- Play-Latest已指向v0.4.9；GitHub版本分支含源码/文档/选定证据，Windows ZIP是本地交付，未创建GitHub Release。

## 尚未验收的范围

- Windows 桌面连续 3 秒催马、高速松手响应、运动/命中时暂停、真实听感与玩家连续战斗体感；现有短按和准备阶段暂停不能替代。
- 马匹与骑手的连续动作真实感、腿根和装备轮廓是否达到玩家要求，需要结合连续画面与玩家反馈。脚本限定场景通过不构成主观体验结论。
