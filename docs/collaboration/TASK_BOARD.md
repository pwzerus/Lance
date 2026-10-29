# 任务、审查建议与文件认领

最后整理：2026-10-28。DEV-043的AI、菜单、存档和枪盾反馈已交付v0.4.3，审查、验包与文件释放见下表。其他建议尚未指派给Claude，不代表已在后台进行。

当前版本分支为 `codex/v0.4`。同版本的修复、同一／相近功能继续在该分支提交 commit；大的结构性改动形成新版本时再创建新的版本分支。不按每个小任务新建分支。

## 当前文件占用

| 负责人 | 任务 | 占用文件 | 状态 |
| --- | --- | --- | --- |
| Codex | DEV-046：开发与验证完成，文件已释放 | 主负责人：game/scripts/visual/{horse_gait,horse_art,rider_view,sound_bank,impact_fx}.gd，core/joust_match.gd，battle.gd，main.gd，project.godot，export_presets.cfg，Play-Latest.cmd；game/tests/*v046*；DESIGN_DECISIONS.md；docs/collaboration/{TASK_BOARD,PROJECT_STATE,WORK_LOG}.md、handoffs/*046*；docs/development/*046*。motion_review只读研究与审查；motion_qa仅新test_motion_showcase_v046.gd及uid，须串行QA | 基线c255844，codex/v0.4。2026-10-28 22:44:33 UTC开始，2026-10-29 01:14:33 UTC截止。既有Claude文档与历史未跟踪证据保留。先改善已有结构，不重写玩法。 |
| Codex | DEV-045：已完成，文件已释放 | 主负责人：visual/{horse_gait,rider_view,horse_art}.gd、core/joust_match.gd、battle/main版本标识、project/export、Play-Latest、game/tests/test_*v045*、DESIGN_DECISIONS、协作与v045证据文档；子代理motion_review只读，motion_qa仅test_motion_showcase_v045.gd及uid | 2026-10-28 21:13:39 UTC开始，22:13:39 UTC停止扩展；基线675f4ca，codex/v0.4。既有Claude文档差异归属已知并保留；在原动作代码上修，不重写玩法。 |
| Codex | DEV-044：已完成，文件已释放 | game/scripts/{battle,main}.gd；core/{joust_match,opponent_ai,desktop_input_audit,game_state}.gd；visual/{horse_gait,horse_art,rider_view,impact_fx,sound_bank}.gd；game/tests/*044*；game/project.godot、export_presets.cfg；Play-Latest.cmd；DESIGN_DECISIONS.md；docs/collaboration/{TASK_BOARD,PROJECT_STATE,WORK_LOG}.md；handoffs/*044*；docs/development/*044*；新动作资产与来源（如需） | 2026-10-27 23:44:45 UTC开始，至2026-10-28 01:44:45 UTC；基线6ee235e，codex/v0.4。按住催马／松手减速替换旧点按缓冲，四步态及过渡和身体多部位随动，双臂对称骨长与左右职责。Claude既有文件保留。 |
| Codex | DEV-043 / R2：已完成，文件已释放 | 本轮登记的游戏源码、测试、启动器与协作文档，详见DEV-043交接 | 两小时上限内完成；最终运行dad3db7，源快照2f3a67d，独立v0.4.3-r2。两种ZIP验包及实际EXE输入／存档／双模式通过；真人未验收，Claude既有差异保留。 |
| Codex | DEV-042：已完成，文件已释放 | 本轮登记的源码、数据、测试、启动器和DEV-042文档 | 2026-10-27 21:47 UTC完成；基线92d7e15。后置审查20:57–21:47，独立v0.4.2包及源码快照已验收。详见DEV-042交接和V042_REVIEW；Claude既有文档改动保留。 |

认领前登记任务 ID、负责人、文件、开始时间与基线 SHA。修改范围扩大时先更新占用。完成／暂停／交出时释放，并留下具体交接记录。此表不是技术锁；`battle.gd`、`main.gd`、规则模型和同一图集禁止两人各改一套后互相覆盖。审查者先只读，修复需协调文件负责人。

DEV-042范围补充：Codex同时负责新增`game/data/equipment_expansion.json`、`docs/development/EQUIPMENT_042.md`及新的QA脚本；保留旧装备ID以兼容收藏。

DEV-042运行审查补充：`game/scripts/visual/impact_fx.gd`由Codex负责，给落马身体和碎片接入分跑道地面及遮挡，防止新分层与旧单地面冲突。

DEV-042输入诊断补充：Codex负责`game/scripts/core/desktop_input_audit.gd`，记录QA窗口收到的物理／逻辑键码以区分桌面工具投递和游戏处理。

## 建议顺序与验收标准

当前玩家要求的AI难度、菜单存档与枪盾反馈由DEV-043实现；上一轮[REQ-042](../requirements/RIG_HORSE_EQUIPMENT_DRAFT.md)的人物、步态、双跑道与装备由DEV-042交付。下方列的是后续验收／维护，不覆盖用户新指示。

优先级表示建议顺序，不表示当前有阻塞启动的故障。状态分别注明实现与待验收范围，不能把建议当作已发生的验证。

| ID／顺序 | 问题与目标 | 范围／先读文件 | 具体完成标准 | 状态／负责人 |
| --- | --- | --- | --- |
| Codex | DEV-045：已完成，文件已释放 | 主负责人：visual/{horse_gait,rider_view,horse_art}.gd、core/joust_match.gd、battle/main版本标识、project/export、Play-Latest、game/tests/test_*v045*、DESIGN_DECISIONS、协作与v045证据文档；子代理motion_review只读，motion_qa仅test_motion_showcase_v045.gd及uid | 2026-10-28 21:13:39 UTC开始，22:13:39 UTC停止扩展；基线675f4ca，codex/v0.4。既有Claude文档差异归属已知并保留；在原动作代码上修，不重写玩法。 | --- |
| QA-01 / 1 | 收集 v0.4.3 真人手感，确认加速、命中和攻防是否可理解 | 最终v0.4.3包、输入诊断、V043_REVIEW；优先只记录，不先调数值 | 记录实际包PCK散列、显示缩放／窗口、左键点按与连续按住3秒、空格对照；15–30分钟体验中记录能否读盾、失败部位与下一局调整、慢动作开关体验。分清玩家原话与评审推断；无真人参与不能标完成 | 待认领／无 |
| AI-01 / 2 | 三档延迟AI已改，继续确认真人可读性与装备差异 | `battle.gd`、AI测试、策略基准 | 先复现并说明漏洞窗口；保留延迟观察／可见承诺，不用即时读输入或随机伤害掩盖；固定种子、同装备、交换双方条件对照；给出真人可读性证据。不能只追某个脚本目标胜率 | DEV-043代码与144局对照已完成；真人部分待认领 |
| FIX-01 / 2 | 定位部分测试／自动试玩退出时 ObjectDB 残留 | `main.gd`、`battle.gd`、FX／音频生命周期、已有日志 | 找到可重复退出路径和具体残留对象／引用；修复后相同退出、重开、暂停路径有前后日志。未定位时明确记录，不能从退出警告推断持续运行泄漏 | 短测试音频收尾与最终6场节点／进程采样已核对，未见增长；历史间歇路径若复现仍须定位 |
| ART-01 / 3 | 程序步态、旋转像素闪烁和挂点接缝影响质感 | 两个分件脚本、像素资产、像素美术Skill | 先做一套完整骑手＋马匹样张：左右双向、前25°／后45°、高低盾、断枪／受击；正常显示尺寸下双臂握持和盾清楚，裁切与挂点一致；再决定扩展其他套装。保留旧资产，记录AI生成／人工处理来源 | 待认领／无 |
| UX-01 / 3 | 命中与败北解释是否足以支持学习；练习是否仍枯燥 | 玩家体验Skill、评论研究、HUD／练习代码 | 用QA-01具体失败案例提出改动，说明玩家如何读懂盾位、接触部位和姿态代价；实际渲染后检查文字／遮挡；至少一个反馈循环有真人记录，不能靠提示数量或断言数证明好玩 | DEV-043三档盾控／颜色／菜单已完成；真人反馈闭环待认领 |
| ARCH-01 / 4 | `battle.gd` 和 `main.gd` 承担过多职责，协作冲突高 | 先根据前几项实际改动梳理接口 | 提出最小拆分方案与文件所有权，保持规则／渲染挂点和时钟边界；逐步迁移并跑相关回归，核对同种子结果和发布画面。大的结构重构应开启下一版本分支，不与普通调参混在同一提交 | 待认领／无 |
| HIST-01 / 4 | 扩充地区装备、马衣／马铠与纹章／印章；避免虚假历史标签 | 历史档案、资产简报、装备规划、catalogue与equipment数据 | 先选定小批具体物件，每件写年代／地区／用途／来源Sxx／哪些是游戏改编；设计与实装状态分开；新增物品可购买装备、双向挂点可读。不为四地区强行编造早期甲结构差异 | 待认领／无 |
| QA-02 / 5 | 其他Windows、DPI、帧率和真实触控未验收 | 发布包、UI状态和触控逻辑 | 记录机器／系统／DPI／输入设备／版本；覆盖菜单、冲锋、暂停、结果、保存重启；触控必须在实际设备验收。未具备设备时保持未验收 | 待认领／无 |

## 每个里程碑都要保留的核对

- 不改坏竞技场非致死、轮间新枪不治疗、实战可死亡与残柄跨轮、血腥设置不改变规则、同时命中和结算去重。
- 输入、时钟、碰撞或美术挂点有改动时，按 AGENTS 阅读对应 Skill，运行相关测试并查看实际渲染。证据分为规则模拟、引擎注入、OS桌面操作、真人试玩。
- 测试前检查 QA 路径，串行跑共享QA档；新日志／截图用新目录，保留旧失败。导出必须到独立版本目录，再对实际 EXE/PCK 复验。
- 完成后填写交接模板、更新现状、任务状态与开发记录，提交到当前版本分支。没有运行过的检查清楚写出。

## 暂不扩张的范围

联机、军团战、完整战役、肢解、永久伤残、真实付费、云存档不是当前任务。更多内容不能替代对现有加速、攻防与打击感的验收。若后续用户明确改变范围，在设计增补记下决定后再排期。

DEV-044：v0.4.4已导出，实际EXE四项专项/双模式九图完成；运行代码82b6027。停止功能扩展并释放文件。OS输入与真人、满血追头平衡未完成，详见DEV-044交接。


DEV-045范围补充：battle.gd离场步态/位移也由Codex认领，修终局1.4秒马匹高速直接静止的展示问题；模型结算不变。子代理motion_qa新建showcase/motion/transitions/support_rider v045测试，motion_review只读审查。

DEV-045后续审查：首个v0.4.5候选包保留。修两轮之间turn直接静止，改为规则暂停但实际跑出交锋区；终局跑出、地面投影随高度变化。最终另导出v0.4.5-r2，不覆盖候选。

DEV-045动作审查补充：确认小跑马背高度与承重反相，依据Rhodin2022/ClaytonSha2006修HEIGHTS采样+.21相位，骑手delayed_height同步，腿序与pitch不改。最终独立v0.4.5-r3；r2保留。

DEV-045完成：最终运行dc09976，v0.4.5-r3独立包五项专项、双模式九图及连续动作预览已验。停止扩展，生产文件释放；接下去仅归档/源码验包/提交推送。OS仅23ms按下抬起到达，真人长按待验；其他问题见DEV-045交接。


DEV-046完成：运行43a6058，独立v0.4.6-r3；r2五项实际EXE专项、r3双模式镜头/九图/连续预览/输入与集成、Windows ZIP解压实跑通过。原生桌面只验菜单/练习/暂停/重开，长按和真人手感未验收。文件释放；只剩源码归档与文档远程核对。近景HUD遮脚/命中横条遮下半身登记为后续构图P2，详见DEV-046交接。
