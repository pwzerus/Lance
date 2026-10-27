# 当前实现与接手地图

2026-10-27：当前发布v0.4.2，仍在codex/v0.4。关节IK与贴图关节映射、左向镜像、规则共用步态起伏、支撑蹄世界锁定、超伸提前收腿、隔栏双跑道和分层落马已接入。新增72条四国骑枪、各24条甲胄／头盔／盾牌，共通马恰10种；总目录182条含旧收藏。没有刀剑或近战，起伏可预判且影响实际枪线。存档新增基础盾槽位并保留旧ID。验证与限制见[V042_REVIEW](../development/V042_REVIEW.md)、[装备清单](../development/EQUIPMENT_042.md)。后置40分钟计时20:57–21:37 UTC，完成回执见本轮交接。

基准更新：2026-10-26，当前v0.4.1，仍在`codex/v0.4`。功能里程碑`f1003ef`；美术与交付提交见本分支后续历史。沿用v0.4的伤害、输入、速度与AI时序，新增结算命中解释、非写实像素头像、长腿马匹分件与四拍腾空步态、落蹄同步尘土／声音。详情见[v0.4.1审查](../development/V041_REVIEW.md)及[本轮交接](handoffs/2026-10-26-DEV-ART-041-Codex.md)。需求取舍以用户最新指示和[DESIGN_DECISIONS](../../DESIGN_DECISIONS.md)为准。

## 启动与交付

| 用途 | 位置与说明 |
| --- | --- |
| 玩家启动 | [Play-Latest.cmd](../../Play-Latest.cmd)，指向 v0.4.2；正式试玩会使用玩家存档 |
| 正式发布文件夹 | [LanceAndLaurel-v0.4.2](../../builds/LanceAndLaurel-v0.4.2/)，EXE 和 PCK 必须同目录 |
| Windows 完整包 | [LanceAndLaurel-v0.4.2-Windows.zip](../../builds/LanceAndLaurel-v0.4.2-Windows.zip) |
| 源码快照 | [GALUMU-v0.4.2-source.zip](../../builds/GALUMU-v0.4.2-source.zip)，来自本轮交付提交；不含引擎、模板、builds 和 .godot |
| 发布身份与散列 | [release_manifest_v042.json](../../builds/release_manifest_v042.json)、[v0.4.2审查](../development/V042_REVIEW.md) |
| 可编辑项目 | [game/project.godot](../../game/project.godot)，Godot 4.5.1，GDScript，Windows x86_64，Compatibility 渲染 |
| 本机引擎 | `E:/GALUMU/tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe` |
| 本机导出模板 | `E:/GALUMU/tools/templates/windows_release_x86_64.exe` |
| 隔离输入诊断 | [Play-Input-Diagnostic.cmd](../../Play-Input-Diagnostic.cmd)，依赖本机 `builds/qa-v04-release/`，不在普通玩家包内 |

旧 v0.1、v0.2、v0.3 发布包保留。当前 EXE 是未修改的 Godot 模板，各版本 EXE 可完全相同；以路径、窗口／首页版本和 **PCK 散列**识别游戏版本。v0.4 PCK SHA256：`5F0C4988B62F566D7CAD2EFC2F4040D4FC278253499003F4AE9C8F9763ED0519`。Windows 文件属性不能单独证明游戏版本。

源码快照和 manifest 的生成时间不同；manifest 与干净解压导入日志是打包后旁附记录，源码 ZIP 不包含自身散列。不要为补交接文档覆盖现有 ZIP。`builds/v04-source-verification/` 是验包副本，不是开发源目录。

## 已实现功能

v0.4.1 PCK SHA256：`4BE52458C9F8F2FB5A47D1903BB97956F2585D0D87F2D95730C9B365DBE60ECB`。旧v0.4包散列未变，保留全部旧版。下方v0.4数值和证据继续作为继承基线，不替代本轮证据。

| 系统 | 当前行为 | 边界 |
| --- | --- | --- |
| 核心对冲 | 自动前进，最多三轮；落马、失去战斗能力或死亡提前结束；三轮后比较 HP，相同 HP／双方同时败北为平局 | 固定分道，马匹不互撞；不是自由纵深或全战场模拟 |
| 竞技场 | 保证非致死；每轮自动换新枪，保留骑手伤情 | 不代表历史比武没有死亡 |
| 实战 | 允许死亡，断枪倾向低于竞技场；残柄跨轮保留到本局结束 | 死亡不删除收藏；没有永久伤残、延迟出血规则 |
| 命中 | 移动目标相对扫掠，枪尖旋转弧线细分；头、身、腰腹、盾区域；先收集双方接触再结算 | 圆形受击区，每攻击者每轮至多一次有效命中；不是连续材料仿真 |
| 攻防 | 头部不再固定秒杀；盾位、护甲、头盔、轴向相对速度、枪稳、姿态和平衡影响结果 | 不能据此宣布所有策略平衡完成 |
| AI | 三档独立装备与延迟观察；根据观察到的盾位、来枪和姿态选目标；标准／困难在近身承诺后停止新观察 | 精确脚本仍能稳定利用困难档换招窗口 |
| 练习 | 竞技场规则；对方高低盾按轮次交替，显示操作尝试提示，R 重开仍在练习 | 不发奖励、不计职业输赢；不是完整教学课程 |
| 反馈 | 两臂、盾与破损、枪分段飞出／木屑、受击回摆、关节落马、命中部位文案、蹄声／风声／冲击音 | 马匹是程序分件步态；声音为合成版本，未正式混音 |
| 血腥设置 | 默认关闭；开启显示伤口、血粒子与地面血迹；关掉清理对应表现 | 不改变伤害、死亡、胜负及规则随机结果；没有肢解 |
| 进度 | 34 件物品、购买装备、五年代声望门槛、自动存档与备份恢复 | 代表性内容，未做完整四国历代专属套装 |
| 场景与资料 | 竞技场／实战场景、首页、商店、设置、历史手记与来源链接 | 历史资料不是游戏伤害概率或价格的证据 |

## 输入、节奏与关键数值

| 项目 | v0.4 当前实现 |
| --- | --- |
| 调枪 | 鼠标上下决定枪尖高度；只在鼠标移动／触摸拖动时更新意图，静止鼠标不随镜头重算角度 |
| 催马 | 左键点按或持续按住，空格可替代；点按保持 2 游戏秒；倒计时点按保留到冲锋 |
| 防御 | 右键／Q 切换高低盾，约 0.36 游戏秒完成；高盾护头、低盾护腰腹，另一处暴露 |
| 倾身 | W/S 或上下箭头；前倾约 25°，后仰约 45°，带惯性；可选滚轮倾身、中键回正 |
| 其他 | H 显示真实受击范围，默认关；Esc 暂停，R 重开，F11 全屏 |
| 起跑与速度 | 双方起点 ±2200；巡航 210，疾驰 480，过阵短冲 515；加速度 600，滑行减速度 85 |
| 枪稳 | 交错前 1100 距离内调枪速度由 2.2 降至 0.95 rad/s；大幅转向失稳、停手恢复；后仰削弱支撑与平衡 |
| AI 时序 | 观察基准 1.0／0.65／0.34 游戏秒并 ±10% 变化；标准 800、困难 500 距离内承诺；简单档无同类承诺门槛 |
| 镜头 | 远景蓄势，随距离次线性放大到近景，保留可见接近运动；650 距离内、未接触时 0.72 倍时间 |
| 命中时间 | 身体顿帧约 65ms，盾约 40ms；之后约 0.20 倍时间至命中后约 510ms，真实时钟解除 |
| 设置边界 | 可关闭接近放缓和命中慢动作，短顿帧仍保留；暂停冻结世界和布偶，重开／退出恢复 time_scale |
| HUD | 实际游戏速度条，催马／减速中／巡航，盾位／耐久、枪稳、平衡、命中部位和练习提示 |

时间单位要区分：催马消耗游戏秒，顿帧和慢动作恢复使用真实时间。距离、速度、伤害、平衡、价格都是游戏参数，不是米、公里时速或历史实验数据。所有催马仍受耐力约束。

年代窗口为 1100–1300、1300–1400、1400–1470、1470–1530、1530–1600；声望门槛 0／6／16／30／48。初始银币 520；胜 180 银币和 3 声望，平 110 和 1，负 55 和 1；实战另加 30 银币。地区线为英格兰、法兰西、德意志、意大利；没有现实付费。

## 源码分工地图

路径均相对根目录 `E:/GALUMU`；Godot `res://` 对应 `game/`。

| 文件／目录 | 负责内容 | 改动联动与风险 |
| --- | --- | --- |
| [core/joust_match.gd](../../game/scripts/core/joust_match.gd) | 规则、运动、扫掠、伤害、模式、结束；共用身体／手／盾／枪尖几何 | 物理与美术都使用这些挂点；同步验证双方向和极限姿态 |
| [battle.gd](../../game/scripts/battle.gd) | 输入、AI、时钟、镜头、HUD、反馈事件 | 多人冲突高发文件；一次只由一位负责人修改 |
| [main.gd](../../game/scripts/main.gd) | 首页、商店、设置、历史、结算、练习生命周期及自动试玩 | 同属共享热点；结果、奖励、重开要一起核对 |
| [core/game_state.gd](../../game/scripts/core/game_state.gd) | Autoload，存档、校验、备份、购买回滚、奖励去重 | 不用正式档测试；奖励保存失败仍保留内存并提示，未有跨进程交易日志 |
| [core/catalogue.gd](../../game/scripts/core/catalogue.gd)、[equipment.json](../../game/data/equipment.json) | 地区、年代、门槛、物品和战斗属性合并、NPC 配装 | 新物品要有有效 ID、槽位、时代与来源说明 |
| [visual/rider_view.gd](../../game/scripts/visual/rider_view.gd)、[equipment_art.gd](../../game/scripts/visual/equipment_art.gd) | 分件裁切、装备轮廓、近远遮挡、姿态与挂点 | 图集换尺寸／位置时必须联动裁切和挂点，不能只换 PNG |
| [visual/impact_fx.gd](../../game/scripts/visual/impact_fx.gd)、[lance_shard.gd](../../game/scripts/visual/lance_shard.gd) | 受击、布偶、血腥、断枪飞段、生命周期 | 检查暂停、重开、关闭血腥、退出清理 |
| [visual/hit_zone_overlay.gd](../../game/scripts/visual/hit_zone_overlay.gd) | H 实际受击区显示 | 图形、物理与镜头投影应一致 |
| [visual/sound_bank.gd](../../game/scripts/visual/sound_bank.gd)、[ui/ui_factory.gd](../../game/scripts/ui/ui_factory.gd) | 合成音频、UI 共用样式与控件 | 样式最小尺寸曾造成首页遮挡，不能只检查指定 rect |
| [core/desktop_input_audit.gd](../../game/scripts/core/desktop_input_audit.gd) | QA 输入采样日志 | 不是正式玩法，输入证据区分 OS 和引擎注入 |
| [game/tests](../../game/tests/) | 规则、战术、集成、动作、输入响应、AI、画面及策略模拟 | 部分输出路径固定为 v04，未来运行前改新目录，保留旧证据 |
| [export_presets.cfg](../../game/export_presets.cfg) | 导出模板、排除测试／美术源图、当前导出位置 | 默认仍指向 v0.4；新发布前必须改成新版本目录 |

## 存档与安全运行

正式玩家档目录是 `%APPDATA%\Godot\app_userdata\骑枪与桂冠 · Lance & Laurel\`，文件 `profile_v1.json`、`profile_v1.backup.json`。不要删除、重置或用它做购买／损坏恢复测试。

参数 `-- --test-profile` 或 `-- --smoke-test` 使用 `qa_profile_v1.json` 与对应备份。文件名以 `LanceAndLaurel-QA` 开头的 QA EXE 使用 `qa_desktop_profile.json` 及对应备份。QA 档仍会被测试改写；两位开发者不要同时跑同一套 QA，用顺序运行或另行实现独立测试档。当前参数不是任意存档路径选择器。

以下命令在 PowerShell 使用。每次将 `$runId` 改为新编号，先确认输出目录不存在，避免覆盖旧验收。它们是接手参考，本次整理文档没有重跑这些游戏测试。

```powershell
$godotExe = 'E:/GALUMU/tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe'
$projectDir = 'E:/GALUMU/game'
$runId = 'handoff-next-01'
& $godotExe --headless --editor --path $projectDir --import --quit --log-file "E:/GALUMU/docs/development/logs/$runId-import.log"
& $godotExe --headless --path $projectDir --script res://tests/test_rules.gd --log-file "E:/GALUMU/docs/development/logs/$runId-rules.log" -- --test-profile
& $godotExe --path $projectDir --script res://tests/test_integration.gd --log-file "E:/GALUMU/docs/development/logs/$runId-integration.log" -- --test-profile
```

规则改动按需加 `test_tactics.gd`、`test_ai_reaction.gd`；动作／镜头／输入改动加 `test_game_feel.gd`、`test_charge_response.gd`，并实际渲染和桌面操作。先检查脚本中的 JSON、PNG 输出路径，不要改写 v0.4 证据。GUI 测试串行运行；多个引擎窗口曾影响显存分配与输入焦点。

新版本导出需先更新版本、导出预设及独立目录，再运行：

```powershell
# <new-version> 必须替换成未占用的版本目录；不要直接用 v0.4 重导。
& $godotExe --headless --path $projectDir --export-release 'Windows Desktop' 'E:/GALUMU/builds/<new-version>/LanceAndLaurel.exe' --log-file "E:/GALUMU/docs/development/logs/$runId-export.log"
```

对实际 EXE/PCK 用外部测试脚本复验（正式包排除了 tests），或用 `-- --smoke-test --screenshots <新的已建目录>` 自动跑双模式及结算。自动试玩使用 QA 档。先核对测试脚本引用和输出位置，查看日志错误与实际截图；仅 headless 启动不证明画面正确。导出后检查包内文件、散列和干净源码导入，具体流程见 [VALIDATION](../development/VALIDATION.md)。

## 最新验证证据及其范围

v0.4.1：实际导出EXE/PCK完成双模式九图、集成43项、真实渲染动作30项、响应16项、命中解释与步态专项；日志在`docs/development/logs/v041/`，发布截图在`exported_screenshots/v041/`。桌面工具实际点击练习、催马、结算重开和暂停；点按含过阵冲刺，不用于测起步曲线。OS工具Esc未触发暂停，注入Esc/R检查通过，两者不可混写为真实键盘已验收。没有本轮真人试玩评分。以下旧v0.4证据保持历史记录。

| 证据类别 | 现有证据 | 可以说明／不能说明 |
| --- | --- | --- |
| 规则模拟 | 114 规则、19 战术、5 AI 观察；[v04-rules.log](../development/logs/v04-rules.log)、[v04-tactics.log](../development/logs/v04-tactics.log)、[v04-ai-reaction.log](../development/logs/v04-ai-reaction.log) | 特定输入和种子的规则结果；不是真人胜率 |
| 最终 EXE/PCK 自动验证 | [集成43项](../development/logs/v04-exported-integration-delivery.log)、[动作30项](../development/logs/v04-exported-game-feel-delivery.log)、[响应16项](../development/logs/v04-exported-charge-delivery.log) | 输入事件链、长按状态、暂停、规则、画面关系等；不等同真实鼠标硬件和好玩程度 |
| 最终运行渲染 | [双模式日志](../development/logs/v04-exported-smoke-delivery.log)、[9张截图](../development/exported_screenshots/v04/)；结算图已目视检查 | 本机实际场景、结算和可见性；不是跨机器性能保证 |
| OS 工具点按 | [v04-desktop-click-confirmed.jsonl](../development/logs/v04-desktop-click-confirmed.jsonl)、[截图](../development/screenshots/v04/16_desktop_tap.png) | 候选包约 0.427 实秒到 480，约 1.9 秒仍疾驰；不是真人硬件三秒长按 |
| 长按 | 引擎注入持续三游戏秒，点按缓冲耗尽后仍保持 480 | 工具拖动实际仅约26ms，不把它说成 OS 长按验收 |
| 策略压力测试 | [strategy_benchmark.json](../../game/tests/strategy_benchmark.json)，144 次同默认装备固定种子模拟 | 标准档策略有差异；困难档被脚本适应策略12胜0负利用；不能泛化成玩家胜率 |
| 源码与发布身份 | [manifest](../../builds/release_manifest_v04.json)、[干净源码导入](../development/logs/v04-source-snapshot-import.log) | ZIP CRC、内含文件散列、干净导入与旧包未覆盖，已在交付时核对 |
| 玩家实际反馈 | 旧版被反馈加速不明显，催生 v0.4；v0.4 反馈尚待收集 | 不能把旧版反馈或自动点按写成玩家认可新版 |

OS 点按候选 PCK 为 `BA0669389C8FAA2A570A34A4AD9029D34FFE8D83A5D4DDB4C810193DF97D30DC`；之后改了 AI 采样与结算遮挡，催马／输入／镜头未变，最终包另有上表自动复验。不能说 OS 点按针对最终散列。帧率多为本机60FPS采样，命中采样曾44FPS。间歇 ObjectDB 退出残留警告尚未定位，不能称零泄漏或已证明持续运行泄漏。

## 资料与美术来源

新增头像与马匹分件使用`game/assets/art/pixel_v041/`两张图；提示词、尺寸、生成来源及大学兽医步态参考见[本轮资产记录](../../art_sources/v041/README.md)。其余背景、盔甲、盾牌沿用v0.3。程序步态在八相位、双向极限姿态及实际发布包冲锋中已查看，仍有旋转像素闪烁与简化关节，不宣称手工逐像素动画。

| 资料 | 用途与限制 |
| --- | --- |
| [历史研究](../HISTORICAL_RESEARCH.md)、[资产简报](../HISTORICAL_ASSET_BRIEFS.md) | 装备、历史身份、骑枪、纹章与印章来源；沿用 Sxx 编号，新增史实需有对应资料 |
| [装备进程规划](../EQUIPMENT_PROGRESSION.md) | 早期规划与长期方向，不能当作全部已实现；现有34件以代码和本页为准 |
| [竞品研究](../JOUSTING_GAME_BENCHMARKS.md) | 公开资料分析，没有下载试玩全部竞品；具体实现要回到本项目验证 |
| [玩家评论研究](../PLAYER_FEEDBACK_RESEARCH.md) | App Store 19、Steam 11、Reddit 10，共40条摘录记录；不等于40名独立玩家或统计样本，部分来自索引摘要 |
| [美术来源](../../game/art_sources/ASSET_MANIFEST.md)、[v0.3像素资产记录](../../game/art_sources/PIXEL_V03_MANIFEST.md) | 当前使用 `game/assets/art/pixel_v03/` 六张图；AI辅助生成，非逐像素手绘；基础骑手图仅有提示词摘要，不能声称所有提示词均完整存留 |
| [项目 Skills](../../skills/) | 动作、像素美术、Godot审查、玩家体验评审；按 AGENTS 对应任务阅读 |

当前采用横向 2D 规则与三分之四骑手分件，近远臂与深度遮挡，马匹接近侧面。不同年代胸甲／头盔有变化，四肢、马具及部分罩袍共用；盾徽是独立几何设计，不能包装成已复原真实贵族家族纹章。最近邻采样不消除非整数旋转／缩放造成的像素闪烁。后续逐件扩充前先完成一套双向、极限姿态样张。

## 未完成与维护责任

当前下一步及验收标准见[任务板](TASK_BOARD.md)，不在这里复制第二份任务状态。没有实现联机、战役、军团战、肢解、永久伤残、云存档、真实付费、完整印章编辑器；不要从评论研究自动扩张到这些系统。文档更新人须在[开发记录](WORK_LOG.md)留下任务与接手说明。
