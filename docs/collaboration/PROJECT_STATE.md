# 当前实现与接手地图

2026-10-28，DEV-045。当前已验证发布 **v0.4.5-r3**，运行代码 `dc09976572d68f375f873d18a09e4a0c47500d37`，分支仍为 `codex/v0.4`。本轮基线675f4ca，专注马匹动作；最终包验收回执见[DEV-045交接](handoffs/2026-10-28-DEV-045-Codex.md)和[V045审查](../development/V045_REVIEW.md)。旧版本的“当前情况”以各自交接作为历史记录，不能覆盖本文最新状态。

## 启动与版本身份

| 用途 | 位置 |
| --- | --- |
| 玩家启动 | [Play-Latest.cmd](../../Play-Latest.cmd)，正式存档；已指向v0.4.5-r3 |
| Windows包 | [运行目录](../../builds/LanceAndLaurel-v0.4.5-r3/)、[Windows ZIP](../../builds/LanceAndLaurel-v0.4.5-r3-Windows.zip)，EXE/PCK必须同目录 |
| 源码 | [game/project.godot](../../game/project.godot)，Godot4.5.1、GDScript、Compatibility、Windows x86_64；[源码ZIP](../../builds/GALUMU-v0.4.5-r3-source.zip) |
| 连续动作预览 | [12秒AVI](../../builds/LanceAndLaurel-v0.4.5-r3-motion-preview.avi)，最终EXE的固定30FPS离线程序观察，非真人录屏 |
| 本机工具 | tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe；tools/templates/windows_release_x86_64.exe |

## 当前功能与控制

核心对冲、三档延迟AI、竞技场/实战、三轮结算和重开、练习、购买解锁、自动存档与三个手动槽沿用现有实现。竞技场不死亡、轮间换新枪不回血；实战允许死亡、断枪跨轮且整体较不易断。血腥仅改变表现。没有刀剑或拔刀近战。

- 鼠标移动控制枪尖高度；按住左键/空格催马，松手立即开始惯性减速回巡航。点击释放不留两秒缓存。盾位按钮不催马，失焦取消按住并暂停。
- 1/2/3护头/胸/腹，右键或Q循环，盾平滑移动；W/S前俯约25°/后仰约45°，带姿态惯性。Esc暂停，R重开；H为显式调试范围。
- 巡航210、催马480乘马匹速度倍率；起跑0。催马加速度360、巡航起步180、减速220，命令变化率1300；这些是游戏参数，非现实测量单位。
- 四步态平滑混合。观察例速110/210/340/480；疾驰步频基数1.50、速度倍率最高1.12，完整周期约1.68Hz。快马仍有起伏，稳定属性仅适度减轻骑手传递，十马保留速度/稳定取舍。
- 四国每国三类骑枪各六品质共72条；甲胄/头盔/盾各国六档；十匹共通坐骑。保留旧装备ID与收藏；品质、时代与历史来源分别记录。

## DEV-045马匹动作

沿用原像素图集和规则，新增肩肘/膝、腕/飞节、下管骨及短系部的折叠轮廓。近端两肢方向不同，末段骨长固定；支撑蹄锁定世界坐标，摆腿预测落地身体位置。实际腿周期连续追踪名义步序，速度变化不倒转/跳过半个周期，卷蹄与摆腿共用真实进度，落地前展平。

小跑高度采样+.21周期：承重中段压低、接近腾空升高；骑手使用同一高度曲线的延迟差，两个对角拍都有响应。微小俯仰曲线保持原时序。颈头略前伸低伏，尾部随速度向后拖曳，地面投影随高度轻微变化。身体与骑手挂点由Gait.body共用，起伏适度影响枪线，不随机偏枪。

回合turn阶段停止命中检测但继续向外骑行，重整时统一复位速度/位置/挂点；终局规则冻结，仅演示跑出直至结果面板。沿用现有两臂44/46、右手枪左手盾，不以拉长一臂填补连接。

## 文件地图

| 文件 | 职责 |
| --- | --- |
| scripts/core/joust_match.gd | 比赛规则、速度、共享身体/枪盾挂点、扫掠、回合及终止 |
| scripts/visual/horse_gait.gd | 四步态高度/俯仰、骑手吸震、多段腿IK、支撑/摆腿 |
| scripts/visual/rider_view.gd | 实际腿周期、世界锁脚与预测摆腿，分件像素绘制、双臂、枪盾 |
| scripts/visual/horse_art.gd | 既有马匹图集区域与测量挂点；本轮未重绘位图 |
| scripts/battle.gd | 输入、摄影机、HUD、投影、回合与终局离场展示 |
| scripts/main.gd、core/game_state.gd | 菜单/保存/购买/比赛界面与持久化；本轮main仅版本标识 |
| data/equipment_expansion.json、core/catalogue.gd | 四国装备与十马目录/属性 |
| tests/*v045* | 按住松开、多段关节、四档真实支持、十马变速、重轮、双向连续预览与回归 |

## 存档和验证边界

正式档仍为GameState.SAVE_PATH（user://profile_v1.json），schema1不变，不重置玩家进度。所有测试使用-- --test-profile/--smoke-test，或脚本内qa_独立路径。共享QA串行跑；本轮桌面观察用qa_motion_desktop_v045，不写正式档。

引擎模拟、引擎注入、实际EXE渲染、OS桌面与真人反馈分别记录。OS仅确认一次约23ms拖动的按下/抬起到达，未验证真实长按加速；持续按住/松开由引擎注入验证。没有新版真人满意度结论。不能以测试数量证明动画自然或游戏好玩。

## 剩余问题与优先顺序

1. 先对最终包作真人四档连续运动、长按/松手及双向观察，按具体异常帧改；仍是分件程序动画，像素边缘闪烁/局部接缝及身体比例仍可改善，不宣称达到真实马或RDR2品质。
2. 旧满血持续追头16种子未落马的平衡问题独立待查。伤员30HP实战致死夹具通过，仅验证死亡允许性，不代表满血对局平衡。
3. 结果面板出现后，终局展示仍后台推进；可后续冻结以减少无意义更新。turn/terminal不恢复接触检测。
4. 跨机器/DPI/真实触控与长期游玩仍待验收。本轮不扩联机、战役、近战或更多装备。

## 资料与历史记录

历史见[HISTORICAL_RESEARCH](../HISTORICAL_RESEARCH.md)、[HISTORICAL_ASSET_BRIEFS](../HISTORICAL_ASSET_BRIEFS.md)、[EQUIPMENT_PROGRESSION](../EQUIPMENT_PROGRESSION.md)。动作原研究与适用边界见[V045_REVIEW](../development/V045_REVIEW.md)；此前真实马录像观察见[HORSE_MOTION_044](../development/HORSE_MOTION_044.md)。新参数是游戏抽象，不冒充史实或完整生物力学仿真。

旧版本按[WORK_LOG](WORK_LOG.md)与handoffs/追溯。TASK_BOARD是唯一认领表；根HANDOFF入口保留早期基线，实际版本先读本文及git状态。Claude既有未提交文档保留。

