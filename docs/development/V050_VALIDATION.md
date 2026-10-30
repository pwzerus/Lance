# v0.4.10 验证记录

本记录汇总 DEV-050 两阶段的已完成证据，保留失败与验证边界。检查通过说明限定路径没有发现对应回归，不表示玩家已经认可撞击声音、落马表现或马匹自然感。

## 身份与交付状态

| 项目 | 当前记录 |
| --- | --- |
| 版本 / 分支 | 源工程 v0.4.10 / `codex/v0.4` |
| 运行代码提交 | `75153c47c93ed1983b465b9f78720a77c995cea3`；主负责人已推送并核对远程 |
| 引擎 | Godot 4.5.1 stable，Windows；GUI 日志为 OpenGL Compatibility / Intel Graphics |
| 隔离存档 | 专项脚本使用 `--test-profile`；桌面记录使用独立 `qa_desktop_v050_*.json` |
| 两阶段后置 QA | 2026-10-30 02:43:17–03:13:17 UTC；本稿写入时仍在进行 |
| 30 局 soak | `soak-01.json`通过，1040.522秒；30/30局、退出后28节点、0孤立节点；详见文末回执 |
| 最终 Windows EXE / PCK / ZIP | 独立v0.4.10已导出；音频/生产落马镜头实包通过，ZIP解压包两模式及9图通过；散列见文末 |
| 真人试玩 | 未执行；OS 工具操作与脚本均不能代替玩家手感结论 |

早期报告版本字段仍为 0.4.9，属于版本号更新前的源工程开发证据，不是最终发布包的重复验收。实现与排错细节见 [V050_REVIEW](E:/GALUMU/docs/development/V050_REVIEW.md) 与 [马匹审查](E:/GALUMU/docs/development/V050_HORSE_REVIEW.md)。本记录作者只读报告/日志并整理文档，没有另外启动引擎或游戏。

## 已完成证据总表

| 类别 / 最终记录 | 实际覆盖与结果 | 限定范围 |
| --- | --- | --- |
| 规则/时间模块：[timing-01](E:/GALUMU/docs/development/logs/v050/timing-01.json) | 生产 ExchangeDirector 的 30/60/120Hz 预算、暂停、重置、同批顺序、设置切换与大 delta；两模式真实 Model 扫掠错过通过。 | 命中预算部分使用明确合成事件；不是正式场景、OS 操作或渲染证据。 |
| 正式交锋：[exchange-scene-01](E:/GALUMU/docs/development/logs/v050/exchange-scene-01.json) | 真正 Model 接触/错过交给 BattleScene，慢动作开关、首个可见接触帧、枪盾连续限速、音效/文字暂停、终局/退出时间恢复、同批事件顺序通过。 | `--no-captures`；脚本/引擎处理函数输入，不是 OS。1HP 终局是模式契约，不证明满血平衡。 |
| 完整落马：[fall-02](E:/GALUMU/docs/development/logs/v050/fall-02.json) | 脚本完整人物姿态与落地演示，六种部位/方向组合及观察帧，无失败。 | 独立 articulated fixture；正式命中消费另由 fall-scene 验证。 |
| 正式落马矩阵：[fall-scene-02](E:/GALUMU/docs/development/logs/v050/fall-scene-02.json) | 竞技场/实战 × head/body/flank × 双方向 × 整枪/残枪，24 例真实 Model 扫掠事件、144 张阶段图，全部 grounded/settled/released，通过重开清理。 | 防守者 1HP、无盾、不还击；不是自然 AI 胜负率。截图相机为 QA 拟合，不能据此宣布生产镜头通过。 |
| 血腥切换：[fall-blood-toggle-01](E:/GALUMU/docs/development/logs/v050/fall-blood-toggle-01.json) | 两模式真实受伤/落马后，经已有暂停菜单信号关闭血腥；各例 12 个血粒子及 1 处血迹清为 0，伤情/胜负语义保留。 | 引擎 UI 属性/信号操作，非 OS。竞技场 dead=false，实战 dead=true，均为显式 1HP 契约场景。 |
| 正式落马镜头：[fall-camera-01](E:/GALUMU/docs/development/logs/v050/fall-camera-01.json) | 不覆盖相机位置/缩放/偏移；左右单 KO 与真实同一步双 KO 三例，通过完整身体包络及终局时序。 | 1440×810 逻辑视口；不保证每块飞出武器始终入镜，也不是全距离自然开局/所有装备矩阵。 |
| 骨架/支撑：[anatomy-05](E:/GALUMU/docs/development/logs/v050/anatomy-05.json) | 双向 30/60/120Hz、四档恒速暖机/观察、实际 Model 变速、锁蹄与重开缓存全部通过。 | 受控同步步长、默认 speed/stability 配置；headless 不证明蒙皮图像无孔洞。 |
| 十马变速：[catalogue-anatomy-04](E:/GALUMU/docs/development/logs/v050/catalogue-anatomy-04.json) | 实际 Catalogue 全十马，双向三种采样率真实按住/松开，达到 432–595.2 的各自疾驰速度；局部/参考世界/原始世界关节峰值均低于 2600。 | 不重复每马最高恒速两周期的落蹄矩阵；不是 OS 催马或真人动作评价。 |
| 整马渲染：[whole-horse04 report](E:/GALUMU/docs/development/screenshots/v050/whole-horse04/report.json) | `v0.4.10-final-core`、项目 0.4.10，真实 Rider 世界平移，双向四档、起步/催马/松手；480 帧固定 30fps 展示与 11 张指定图，报告无失败。 | 此次 report 的 `geometry=[]`；几何依据是独立 anatomy/catalogue。固定 MovieMaker 帧率不是机器实际 FPS，报告本身不等于逐帧目视通过。 |
| 音频：[audio-03](E:/GALUMU/docs/development/logs/v050/audio-03.json)、[audio-gui-01](E:/GALUMU/docs/development/logs/v050/audio-gui-01.json) | 实际素材/材质回退、39 个预烘焙接触/断枪声音、PCM/余量、选音不改原事件、音池/静音/暂停恢复；Dummy 与 Windows WASAPI 均通过。 | 无人耳音色/硬件响度结论；接触组预算不等于完整 Master 混音无削波。 |
| OS 源工程：[desktop-source-01](E:/GALUMU/docs/development/logs/v050/desktop-source-01.jsonl) | 无注入观察器记录真实桌面鼠标/按键、护头中间值、运动中暂停与菜单重开，详细数值见下文。 | 可执行路径为 Godot 工具运行源工程，不是最终发布 EXE；没有持续催马或真人评价。 |

上述最终专项日志均以各自 `passed=true` / 完成标记为准。`fall-scene-02`、血腥切换、生产落马镜头、交锋、Windows 音频和整马最终展示日志中没有发现 ERROR/WARNING 行；这不扩张为全部历史日志或尚在运行的 soak 无错误。

## 正式场景、渲染与时间证据

`fall-scene-02` 的接触来自真正 Model.step 搜索/重放，之后由正式 Battle 与普通落马/武器物理继续推进。每例经历 first_contact、airborne、released、landed、settled，并清理重开后的旧人/旧枪；竞技场非致死、实战允许死亡。三种区域是已有 head/body/flank，没有新增腿伤、马伤、刀剑或肢解。

落马矩阵图位于 [fall-scene02](E:/GALUMU/docs/development/screenshots/v050/fall-scene02)，血腥切换图位于 [fall-blood-toggle01](E:/GALUMU/docs/development/screenshots/v050/fall-blood-toggle01)。这两套使用 QA 拟合镜头让完整人物与武器容易观察；生产镜头由单独 `fall-camera-01` 验证，三例记录的身体边距均为正，最小上/下余量约 27.57 / 21.31 逻辑像素。

`exchange-scene-01` 实测暂停 142ms、恢复观察 83ms；所有命中/错过样例终态 `Engine.time_scale=1`。真实错过不进入接触演出，同批两个真实命中正/逆序结果一致。该次关闭 PNG 保存，以单调墙钟截止循环量时；不把含同步 PNG 编码的其他报告时间轴当作无阻塞演出时长，也不把样本密度当 GPU FPS。

整马 [whole-horse04](E:/GALUMU/docs/development/screenshots/v050/whole-horse04) 是新前送轨迹的渲染材料。审查者此前实际查看的是 `whole-horse03` 的 175/205：头颈连续，旧橙色臀/尾扇片明显消退；03 在最终前送修复前，不能用这两张旧图代替 04 全周期目视。最终自然感与每帧蒙皮检查由主负责人继续复核，玩家满意度仍未验收。

## 马匹最终数值与失败保留

| 最终最大值 | 默认 anatomy-05 | 十马 catalogue-anatomy-04 |
| --- | --- | --- |
| 根部误差 | 0 | 0 |
| 骨长误差 | 0.00001526 | 0.00002289 |
| 支撑蹄滑移 | 0.00390625 | 0.00390625 |
| 蹄世界速度 | 1451.319 | 1661.965 |
| 原始关节世界速度 | 2345.878 | 2379.397 |
| 参考运输速度 480 的关节速度 | 2345.878 | 2350.683 |
| 局部关节速度 | 1868.715 | 1872.514 |
| 脚尖角速度（弧度/秒） | 10.482 | 10.531 |

默认慢步所有采样率、双方向每个观察帧均至少两蹄支持；恒速每腿两次落蹄，疾驰有腾空。原滑移≤0.08、蹄≤2600、toe≤12 的判据保留。关节保留原始值，对超过参考 480 的刚体水平运输单独校正，并新增局部动作≤2600；不按马匹倍率缩小关节动作。最终连未经校正的世界关节峰值也通过。

保留的开发失败包括：

- `anatomy-01`：慢步支撑不足与高速前腿只支持一帧；修正肩带支撑中段回零，未增大原压缩包络。
- `anatomy-02/03`：空中前送使腕目标与三骨链可达关系冲突，肘的解析方向快速塌陷；诊断最差关节后，按几何提前展开腕。
- `catalogue-anatomy-01`：高速马的刚体运输被误算为局部尖跳；校正参考坐标，并保留原始值。
- `catalogue-anatomy-02/03`：新增局部检查另外抓到 e3 在约 429 的速度下真实临落地尖跳。前送超过预测落点再回拉是根因；改为单调前送，保留抬腿曲线与所有马速，之后默认/十马通过。不能将这次真实问题也归为运输误报。
- 早期 whole-horse：后股骨过宽摆动、远臀整块跟腿与尾权重误吞飞节边缘共同形成扇片；分别修限位、根部混合和尾/腿边界。

完整诊断、解剖来源、toe_angle 已由 `ankle→foot` 轴隐式旋转的说明见 [V050_HORSE_REVIEW](E:/GALUMU/docs/development/V050_HORSE_REVIEW.md)。蹄底挂点到地不独立证明所有不透明蹄像素贴地，网格孔洞/像素闪烁及主观自然感保留为渲染复核边界。

## 音频失败与当前边界

保留 [audio-01](E:/GALUMU/docs/development/logs/v050/audio-01.json) 的恢复观察失败：Dummy 混音约 93ms 才更新一次，原 80ms 窗口不足，按驱动延长观察窗，而非改生产暂停。保留 [audio-02](E:/GALUMU/docs/development/logs/v050/audio-02.json) 的 PCM/导出检查失败：短 WAV 默认压缩格式与 PCM 检查不兼容，改明确无损导入。随后 audio-03 和 WASAPI GUI 均通过。

`audio-gui-01` 测试初始化约 669ms，不能当作完整游戏启动性能。接触组保守峰值预算约 0.78；39 声的 PCM 检查及组预算不覆盖音乐、风、蹄声合并后的整个 Master。WASAPI 五时点记录显示长音暂停后保留播放头、恢复后继续；本轮没有真人实听的音色/冲击力结论，也不声称这些声音是实地录制材质。

## OS 输入与真人范围

`desktop-source-01` 的身份记录为 Godot Windows 工具可执行文件、build 0.4.10、`injection=false`，独立 QA 存档。它属于主负责人桌面工具操作源工程，区别于引擎输入注入与最终发布包验收。

- logical=49 的护头键到达：guard_target 0.43→1，首个后续样本 guard=0.71，存在中间换盾过程。
- Esc 在第三轮 charge 中暂停；114 个暂停样本覆盖 11.533 秒，所有非时间戳状态字段不变，x=115.36056。之后菜单点击使场景变为 ready/pass1、x=−2200、speed=0，是暂停后的重开证据，不能描述为继续原轮恢复。
- 记录的五组左键按住仅 18–20ms，boost=true 样本为 0、速度最高 210。没有三秒 OS 长按或高速松手验证；脚本变速通过不能补成桌面长按已通过。
- 菜单/练习/调枪的画面含义来自主负责人操作观察；JSONL 本身主要记录输入与战斗状态，不能独立证明存档重载或玩家满意。

尚无玩家本人长时间试玩、连续音色比较、其他电脑/DPI/真实触控验证。

## 待主负责人补充

1. 后置 QA 在 03:13:17 UTC 的实际完成时间、这半小时内新发现/处理及遗留问题。
2. 30 局 soak 的最终 JSON/日志、完成局数、结算/重开/暂停/设置覆盖及资源/时间缩放结果；本稿不读取运行中片段充当最终通过。
3. 最终 EXE/PCK 路径与散列、实包外部脚本或冒烟结果、Windows ZIP 解压后启动证据。
4. `whole-horse04` 连续画面与正式战斗的最终目视回执，以及仍需玩家反馈的声音/完整落马/马匹自然感。

本记录没有提交 Git，也没有修改其他共享文档；后续新增证据应追加回执，保留现有失败与范围说明。

## 主负责人后置QA回执

30局连续渲染自动比赛完成，实际1040.522秒（约17.34分钟）。包含两模式、三档难度、声音/血腥/慢动作/瞄准提示组合及两局练习，练习不增加职业比赛数；每次退出时间缩放=1、没有暂停残留，所有结果正常到达。各局退出后节点28、孤立节点0。静态内存从110519415到110796131字节，增长276716字节；不将这次有限观察概括为不存在任何内存泄漏。

950次每秒FPS采样中位数60、P10=60、最低48；这不是逐帧p99时延，也不包含其他机器性能。此soak使用源项目真实渲染与自动操控，不能当成真人30局。日志无新增ERROR/WARNING；完整结果`logs/v050/soak-01.json`。

root查看最终whole-horse04的145/205及部分早期诊断图，最终图的头颈身与腿根连续，已定位的尾权重扇片消失；并查看fall-scene02完整落地画面。没有把11张抽样图或480个生成帧称为真人连续录像验收。

发布候选独立导出到`builds/LanceAndLaurel-v0.4.10/`，运行代码75153c4，旧v0.4.9 EXE/PCK散列未变。新PCK SHA256：`1852DF48A4D81734A9F75E5D8C634C1475E06C65B4FC3EB736AC62D3FC037B47`；EXE SHA256：`78CCC576E8F8BFFD7EF6AD6F36EBD72A41E609A1052225A55B3407C96EA84065`。EXE为相同Godot模板，版本内容身份以PCK及项目版本为准。

实际发布EXE运行外部`test_impact_audio_v050.gd`，未传`--path`，生产res资源来自PCK；`release-audio-01.json`通过，39声均验证为baked资源，初始化442.612ms，WASAPI播放/暂停/恢复/清理通过。不是备用现场合成掩盖缺包。

发布EXE另运行外部`test_fall_camera_v050.gd`，`release-camera-01.json`三例通过，实际生成9张PNG。root使用原生桌面捕获看到了双方落马的生产镜头画面，未向此自动专项注入输入。正式相机未做QA拟合；远侧身体可被近马暂时挡住，保留此可读性限制。

Windows ZIP：`builds/LanceAndLaurel-v0.4.10-Windows.zip`，SHA256 `599CBCF79805E60B163A3F357D55BAC3972FF6E64C9ADEA4B7C67160E8DFC42C`。解压到独立`builds/verify-v050-windows/`，PCK与原发布逐字散列一致。

`release-smoke-01`完整比赛结束，但因root忘记预建截图目录，所有PNG返回7。其完成列表不等于图片存在，该轮不能算渲染截图验收。失败日志保留，补建新目录后用解压包执行`release-smoke-02`，结果另记。

`release-smoke-02`已完成：首页/装备/历史、竞技场与实战各三轮和结果、两种命中图。9个PNG均实际存在且返回0，终局正常，日志无ERROR/WARNING。root查看最终竞技场命中图与生产镜头桌面图，马头颈身连续、双跑道层级和完整伤员可见；不代表所有帧都已人工检查。`Play-Latest.cmd`已改指向独立v0.4.10。

`desktop-release-01.jsonl`身份为ZIP解压目录下真实EXE，隔离`qa_desktop_v050_3840273.json`，injection=false。root通过OS鼠标进入对战/练习/首次说明，键盘1护头、Esc暂停，鼠标返回营地与保存退出；窗口/进程正常结束，日志无ERROR/WARNING。此轮没有持续左键长按，也没有玩家本人体验。正式玩家档和旧发布包未覆盖。
