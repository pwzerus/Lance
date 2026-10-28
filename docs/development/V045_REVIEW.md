# v0.4.5 马匹动作审查

2026-10-28，DEV-045，Codex；版本分支 `codex/v0.4`，基线 `675f4ca`。本报告区分静态审查、已读日志、实际查看的渲染与尚待验收内容。用户要求一小时集中改进马匹动作；不是新增玩法或装备阶段。

## 结论与原因

旧版虽有马身升降，四腿仍是统一的两段骨骼，缺少前腕与后飞节的不同轮廓；疾驰提蹄高、前后步幅短；小跑骑手每步幅只响应一次，但马身有两次升降。新实现沿用原规则、贴图和世界锁脚，针对这些环节改进，没有推倒重写。

- 腿链增加近端关节与短系部，前肢后置肘、后肢前置膝和后置飞节方向分开。接地、收腿、前伸轮廓更清楚。前后段仍来自既有AI图集的程序变形，不宣称逐帧手绘或完整解剖仿真。
- 疾驰步频略降以拉长前后步幅，降低过高提蹄；摆腿目标预测落地时身体的位置，减少足部追逐当前马身造成的先停后甩。骑手随动改用同一马背高度曲线的相位延迟差，小跑两个对角拍都有吸震响应。
- 加减速改变名义落蹄相位曾提前截断摆腿。每腿缓存连续实际周期，以主步频的0.75–1.25倍追踪新步序；摆腿、卷蹄与IK共用实际进度，落地前展平。保留世界锁脚，重轮／主相位倒退清缓存。
- 颈头略前伸低伏，尾巴改向后拖曳；投影随离地高度轻微缩小淡化。身体与骑手仍通过 `Gait.body` 共用规则挂点，不把镜头或单独美术位移冒充命中运动。
- 后续修复回合交错后突然停马：`turn` 保持位移和步态，进入 `ready` 才统一复位；该分支在接触检测前返回，不增加交错后的伤害。终局只展示离场，比赛规则仍停止。
- R3进一步修正小跑高度反相：原曲线在支撑中段抬高、腾空时压低，与实测相反。仅小跑高度及延迟高度采样加 `.21` 周期偏移，支撑中段压缩，腾空附近升高；不盲目旋转微小俯仰曲线。

## 实际审查与证据

| 类别 | 已完成范围 | 限制 |
| --- | --- | --- |
| 静态审查 | 分阶段读 `horse_gait.gd`、`rider_view.gd`、`joust_match.gd`、`battle.gd` 的实际diff；追踪共享身体挂点、四段IK、锁脚／相位缓存、暂停、回合重整与终局时钟 | 静态正确不证明动作自然 |
| 规则模拟与源码引擎注入 | `transitions-04` 通过；十马、双向、30/120Hz反复加减速。R3源码 `motion-r3-01`、`support-rider-r3-01` 通过，含小跑支撑／腾空高度方向、四档支撑和复位缓存 | 不将通过项数当作真实感或好玩评分 |
| 首包实际EXE/PCK | `release-validation.json` 中motion、support_rider、integration、rules、cue_contacts均exit0；`release-smoke.log`完成竞技场／实战九图与结算 | 是首包证据，不能代替随后R2/R3验包 |
| R2实际EXE/PCK | `release-r2-validation.json` 中motion、support_rider、integration、rules均exit0；`release-r2-smoke.log`有九图 `SMOKE_TEST_COMPLETE` | R3小跑相位修正晚于此包 |
| R3最终EXE/PCK | dc09976运行代码；builds/LanceAndLaurel-v0.4.5-r3；motion、support_rider、transitions、integration、rules实际EXE均exit0，release-r3-validation.json全通过；release-r3-smoke.log双模式九图与结算COMPLETE | 最终EXE/PCK已实测；OS长按和真人体验仍未验收 |
| OS桌面输入 | 主负责人使用 `@oai/sky` 实际取得QA窗口状态并执行一次拖动；`desktop-04.jsonl`记录左键按下40907ms、释放40930ms，约23ms到达游戏 | 真实长按未验收；100ms状态采样未捕获持续held，最高速度210，不能称真实鼠标催马加速通过。`desktop-01`后台观察不当作OS操作证据 |
| 真人试玩 | 本轮无玩家新试玩结论 | 用户对旧版的“不真实”是本轮需求来源，不是新版满意度证据 |

本审查者实际查看过 `art01/gait_3.png`、`showcase02/frame_155.png`、`release/04_arena.png`：新前后肢折叠方向、前伸和尾部方向可读。主负责人另外查看过桌面即时画面。`release-showcase.log` 的360帧／30FPS／12秒录像属于Godot MovieMaker离线脚本驱动观察，不是实时性能或真人录屏；早期预览不能当R3最终画面。

日志统一在 [logs/v045](logs/v045/)，实际渲染在 [screenshots/v045](screenshots/v045/)。全部游戏验证使用隔离QA存档；未清除正式玩家进度。

## 失败保留与修复

- `transitions-01/02/03` 均保留了“摆腿蹄角在步态／支撑过渡突跳”的失败；实际进度共用仍不足以阻止名义周期提前wrap，随后加入连续周期缓存、低速卷蹄幅度及落地前展平。`transitions-04` 才通过，不改写早期失败。
- `support-01` 暴露过名义接地却因IK够不到而提早释放，部分前腿支持样本为0；关节位置与链条调整后，源码及发布包的真实 `RiderView` 支撑测试记录各腿落地，慢步保持支撑，疾驰有腾空。诊断数值仍不等于观感优秀。
- 小跑高度反相是在R2完成后发现，源码R3修正且相关motion/support通过；最终发布证据已追加在本报告末尾。
- 部分源码日志有 `Failed to read the root certificate store`，报告中不把它伪装成GDScript报错，也不凭本地测试通过声称联网证书功能正常。

## 原始资料与适用边界

- [Rhodin等，2022：Timing of Vertical Head, Withers and Pelvis Movements Relative to the Footfalls in Different Equine Gaits and Breeds](https://pubmed.ncbi.nlm.nih.gov/36359178/)，DOI `10.3390/ani12213053`。实际读取原研究摘要：三类共68匹马，以IMU记录步态；小跑等步态的肩隆／骨盆最低与支撑中段、最高与腾空开始紧密相关。用于确认小跑高度时序；不把游戏单位当实测毫米。
- [Clayton与Sha，2006：Head and body centre of mass movement in horses trotting on a circular path](https://pubmed.ncbi.nlm.nih.gov/17402467/)，DOI `10.1111/j.2042-3306.2006.tb05588.x`。实际读取原研究摘要：5匹马、75标记、120Hz，身体质心支撑起止高、中段低，每步幅两次垂直振荡。研究对象是绕圈小跑，不把圆周侧倾直接加到直线对冲。
- [University of Minnesota Veterinary Anatomy：Transverse Gallop](https://vanat.ahc.umn.edu/gaits/transGallop.html)。实际读取：四拍、领前肢之后腾空，后肢推进，躯干相对刚性而作前后摇摆。用于避免把马脊柱做成夸张软体伸缩。
- [Montana State University Extension：Horse Locomotion](https://animalrangeextension.montana.edu/equine/locomotion.html)。实际读取步拍和腾空差异，支持区分四拍慢步、对角小跑、三拍跑步和四拍疾驰。

此前看过的UC Davis真实跑台影像和连续摄影来源保留在 `HORSE_MOTION_044.md`。本轮未取得或阅读RDR2内部动作实现，不声称复现其算法；没有复制资料影像为游戏素材。

## 保留问题与下一步

1. 新版依旧是分件程序动画，快速旋转可能有像素边缘闪烁、局部比例／关节接缝；需要最终包连续真人观察，不能承诺已达到RDR2或真实马匹品质。
2. 旧版满血持续追头16种子未出现KO／死亡的平衡问题仍待独立复核。本轮规则日志明确以30HP伤员夹具验证实战允许致死；它不证明满血对局落马节奏已平衡，不通过改伤害掩盖动作问题。
3. P2：结果界面覆盖后，终局展示 `_process` 仍继续推进离场相位和位置，属无意义后台更新；不恢复接触检测，不是本轮交付阻断，后续可在 `is_finished` 后冻结。
4. 首要验收是最终R3真实鼠标按住／松手、双向四档连续运动、重整前后与暂停恢复；记录玩家能否看出蹬地、收腿、前伸和腾空，再按具体片段调曲线。

## 最终发布回填

- 最终运行commit：dc09976572d68f375f873d18a09e4a0c47500d37；目录builds/LanceAndLaurel-v0.4.5-r3；PCK SHA256：D223D4D4216331CDF512A316D5B3EDA483B876A6ACB1D1115EC51FE251F860D9。
- 最终实际EXE：五项专项全部通过；40组十马/双向/帧率变速，实际周期比0.75–1.25、最大支持滑移0.0078125游戏单位；双模式三轮与九张实际截图完成。12秒360帧连续观察输出到builds/LanceAndLaurel-v0.4.5-r3-motion-preview.avi，主负责人查看最终小跑与竞技场图。数值不代表真实感评分。
- 旧包与两次候选保留；Play-Latest已切最终r3。Windows与源码ZIP、推送SHA见本轮交付回执；GitHub不包含被忽略的builds。

- integration-01在普通sandbox写AppData QA受限，购买回滚后找不到装备按钮；停止该次后，同源码批准QA写权限重跑integration-02全通过。该失败不记为已修复的新菜单Bug，原日志保留。

