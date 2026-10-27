# 当前实现与接手地图

2026-10-27，DEV-043，当前发布 **v0.4.3-r2**，版本分支 `codex/v0.4`。本轮从 `84de76e` 改进 AI、开始／存档／退出流程、三档防御和枪线／命中提示。运行代码基线 `dad3db7`；后续只有测试、启动器和文档时无须重导。修复和证据见 [V043_REVIEW](../development/V043_REVIEW.md)，交接见 [DEV-043](handoffs/2026-10-27-DEV-043-Codex.md)。用户最新指示与 [DESIGN_DECISIONS](../../DESIGN_DECISIONS.md) 优先。

## 启动与版本身份

| 用途 | 位置与说明 |
| --- | --- |
| 玩家启动 | [Play-Latest.cmd](../../Play-Latest.cmd)，v0.4.3-r2，使用正式玩家存档 |
| Windows目录／压缩包 | [运行目录](../../builds/LanceAndLaurel-v0.4.3-r2/)、[Windows.zip](../../builds/LanceAndLaurel-v0.4.3-r2-Windows.zip)，EXE与PCK必须同目录 |
| 源码快照／身份 | [source.zip](../../builds/GALUMU-v0.4.3-r2-source.zip)、[manifest](../../builds/release_manifest_v043-r2.json)；最终SHA与验包记录见交接回执 |
| 可编辑项目 | [game/project.godot](../../game/project.godot)，Godot 4.5.1 / GDScript / Compatibility / Windows x86_64 |
| 本机引擎／模板 | `tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe`、`tools/templates/windows_release_x86_64.exe` |

v0.4.3-r2 PCK SHA256：`0B6742C495AF7C77D1FB9DC8AF3FAEA188B781547FFAE1FCB6F0217CF94741AE`。EXE是通用模板，不仅凭EXE哈希区分游戏版本。旧包保留；builds不随Git上传，不代表已发布GitHub Release。源码快照不包含自己的散列、后续验包日志或他人未提交文件。

## 当前功能与边界

| 系统 | 实现 | 边界 |
| --- | --- | --- |
| 对冲 | 固定双跑道、隔栏遮挡、最多三轮，落马／KO／死亡提前结束；三轮比较HP，平局有明确结果 | 不是自由纵深、马匹互撞或全战场模拟 |
| 两模式 | 竞技场非致死，每轮换枪不治疗；实战允许死亡、断枪倾向较低、残柄跨轮 | 死亡不删收藏；游戏参数不是中世纪统计 |
| 命中 | 枪尖旋转弧与相对运动扫掠，双向同时接触后统一结算，每攻击者每轮一次；人体圆区、盾共用多边形 | 不再固定戳头秒杀，非材料仿真 |
| 攻防 | 三档连续移盾；护甲、头盔、盾、枪稳、速度、姿态和平衡影响结果 | 不证明全部装备／策略已平衡 |
| AI | 初学／正规／老练，延迟可见信息与独立攻防承诺；老练可先示招后变招、参考上轮来枪 | 不读输入、不加血量伤害；脚本胜率不是真人难度 |
| 练习 | 按轮次护头／护胸／护腹，固定节奏，R重开仍为练习，无职业奖励／场次 | 有首次说明，尚无分步骤教程 |
| 反馈 | 枪尖菱形、目标角标、颜色+文字、实际命中部位色冲击环；双方命中分别显示 | 当前线不预测未来步态／盾位、不自动瞄准；设置可关闭 |
| 动作／美术 | IK双臂、两跑道分层、步态起伏影响真实枪线、支撑蹄世界锁定、断枪飞段和落马；盾朝对手收窄、加厚边握带 | 程序分件动画，仍有像素旋转闪烁；非手绘逐帧 |
| 血腥 | 默认关，可选伤口／血粒子／血迹，关闭清理，表现随机数独立 | 不改变伤害／死亡／胜负，无肢解 |
| 装备 | 182件含旧收藏；四国各3类骑枪×6档=72，各24甲胄／头盔／盾；共通马恰10种，速度稳定取舍 | 无刀剑／拔刀近战；不是所有器物都已逐图鉴定 |
| 菜单／进度 | 首页开始、存档／继续、军械库、历史、设置、保存退出；出战页模式／难度；自动档+3手动槽+备份 | 保存收藏装备设置养成，不保存战斗中途，无云同步 |
| 写盘故障 | 损坏主档不替换有效备份；读档保存失败回滚内存；购买装备失败回滚；退出保存失败保留窗口 | 奖励保存失败保留内存并提示，无跨进程交易日志 |

## 输入与参数

| 项目 | 当前值／语义 |
| --- | --- |
| 调枪 | 鼠标上下决定枪尖高度，静止鼠标不随镜头重算；大幅变招失稳 |
| 催马 | 左键／空格按住冲刺，点按2游戏秒，倒计时保留；盾按钮不催马、不改瞄准 |
| 防御 | 1/2/3护头／护胸／护腹，右键／Q循环，按钮可点／触；guard=1/.43/0，移动速率2.8×handling每游戏秒 |
| 倾身／其他 | W/S或上下键，前25°后45°且有惯性；可选滚轮倾身、中键回正；H判定、Esc暂停、R重开、F11全屏 |
| 起跑／速度 | ±2200，巡航210、疾驰480、过阵515，加速600、减速85；受装备耐力影响 |
| 枪稳 | 距离1100内调枪速率由2.2降至0.95rad/s；后仰削弱攻击支撑和平衡 |
| AI时序 | 观察延迟.72/.38/.20秒，思考.78/.40/.22秒±8%，进攻承诺距接触.85/.52/.30秒，防守.65/.35/.18秒 |
| 镜头／时间 | 次线性拉近；650内未接触时0.72倍；身体顿帧约65ms、盾40ms，之后约0.20倍至命中后约510ms，真实时钟解除 |
| 暂停／终局 | 暂停冻结世界；终局停控制但仍消费待发结果事件；结果隐藏HUD；重开退出恢复time_scale |

距离、速度、伤害、价格为游戏单位。年代1100–1300、1300–1400、1400–1470、1470–1530、1530–1600，时代声望门槛0/6/16/30/48，装备另有品质门槛。初始银币520；胜180银币+3声望，平110+1，负55+1，实战另加30银币。地区英格兰、法兰西、德意志、意大利，无现实付费。

## 文件职责（路径相对game/scripts）

| 文件 | 职责／联动 |
| --- | --- |
| core/joust_match.gd | 运动、步态挂点、扫掠、伤害、模式与终局；物理美术共用位置 |
| core/shield_geometry.gd | 三种盾形、投影、移动旋转扫掠；绘制、枪线、H同一轮廓 |
| core/opponent_ai.gd | 延迟快照、决策、攻防承诺与前轮记忆 |
| battle.gd | 输入、AI接线、镜头、时钟、HUD、反馈，共享热点 |
| main.gd | 菜单、出战、存档、商店、设置、历史、结算与生命周期，共享热点 |
| core/game_state.gd | 存档校验、备份、手动槽、购买回滚及奖励去重 |
| core/catalogue.gd + ../data/equipment*.json | 目录、属性合并、年代品质门槛、NPC装备；保留旧ID |
| visual/rider_view.gd、equipment_art.gd、horse_art.gd、horse_gait.gd | 分件、IK、双向、脚落点和装备；换图集须同步挂点 |
| visual/combat_cues.gd、hit_zone_overlay.gd | 只读枪线与实际判定，不改模型或规则随机数 |
| visual/impact_fx.gd、lance_shard.gd | 冲击、碎片、布偶、血迹和回收 |
| visual/sound_bank.gd、ui/ui_factory.gd、ui/combat_report.gd | 音频、控件与结算解释；注意控件最小尺寸和音频回收 |
| core/desktop_input_audit.gd | QA桌面采样，不是正式玩法 |

本轮测试为game/tests/*v043*；导出预设排除测试，指向独立v0.4.3-r2。builds下验包副本不是开发源目录。新版本不得覆盖已验收包。

## 存档与复验

正式目录 `%APPDATA%/Godot/app_userdata/骑枪与桂冠 · Lance & Laurel/`：`profile_v1.json`、`profile_v1.backup.json`，手动槽`profile_v1_slot_1.json`至`_3.json`及各自`.json.backup`。不删除或重置玩家档。

`-- --test-profile`或`-- --smoke-test`使用`qa_profile_v1.json`；QA前缀EXE用`qa_desktop_profile.json`。专项脚本使用`qa_v043_suite`、`qa_v043_menu_flow`、`qa_v043_exit_*`、`qa_v043_soak`。手动槽从当前路径派生，不碰正式槽。共享QA与GUI测试串行。

源项目复验使用Godot的`--headless --editor --path E:/GALUMU/game --import --quit`，再以`--script res://tests/test_rules_v043.gd -- --test-profile`跑规则。实际EXE以`--script E:/GALUMU/game/tests/<脚本>.gd -- --test-profile`调用包内生产代码。GUI菜单测试为test_menu_flow_v043；`-- --smoke-test --screenshots <新建目录>`跑双模式。每次使用新日志与截图目录，先检查脚本输出路径，不覆盖历史证据。

## 证据与后续

源项目及实际v0.4.3 EXE已完成规则、AI、枪线盾轮廓、输入存档、终局奖励、退出失败、GUI菜单点击和三尺寸布局检查；实际包双模式九图通过。日志[v043](../development/logs/v043/)，截图[release](../development/screenshots/v043/release/)。候选02连续12场有渲染运行，回营节点稳定、孤立节点0；release引擎内存计数不可用，不以0值宣称零内存。首包另加6场171.407秒通过，回营节点27／孤立0；OS内存采样175次未见短运行逐场增长。首包源码a8e490c干净解压导入与规则／菜单／盾扫掠通过，两种ZIP CRC通过；见审查和交接回执。

本轮没有新OS桌面输入或真人试玩；上一轮物理Esc终止后的桌面操作未恢复。引擎点击、自动比赛、模拟和截图不等于玩家认可。其他机器、系统DPI、真实手机触控、长线经济未覆盖。下一步优先让玩家说清一次格挡／命中与一次失败原因，比较三档是否可读、有挑战。

旧证据保留于[V042_REVIEW](../development/V042_REVIEW.md)、[V041_REVIEW](../development/V041_REVIEW.md)、[V04_REVIEW](../development/V04_REVIEW.md)，旧参数不再代表当前版本。

## 资料与维护

史实编号见[历史研究](../HISTORICAL_RESEARCH.md)、[资产简报](../HISTORICAL_ASSET_BRIEFS.md)、[装备清单](../development/EQUIPMENT_042.md)。AI、护盾投影、颜色是游戏抽象，没有新增历史概率结论。公开评论见[竞品研究](../JOUSTING_GAME_BENCHMARKS.md)、[40条评论记录](../PLAYER_FEEDBACK_RESEARCH.md)，不等于40名独立玩家或本作试玩。

沿用pixel_v03与pixel_v041的AI辅助资产，非逐像素手绘。本轮改盾投影、边带和程序特效，无新栅格图。见[资产记录](../../game/art_sources/ASSET_MANIFEST.md)、[v041资产](../../art_sources/v041/README.md)。

文件认领与后续工作只在[TASK_BOARD](TASK_BOARD.md)登记，历史见[WORK_LOG](WORK_LOG.md)。没有联机、战役、军团、刀剑、肢解、永久伤残、付费、云存档或完整纹章编辑器。

R2补充：鼠标点暂停→Esc恢复后，HUD按钮曾保留焦点，Space会再次暂停。dad3db7仅关闭该战斗按钮的键盘焦点（Esc仍可用），版本标识改r2；空间键恢复后的实际催马回归纳入新包验证。初版与r2包都保留，最终身份见交接回执与V043_VALIDATION。
