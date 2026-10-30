# 任务、审查建议与文件认领

最后整理：2026-10-30 EDT。DEV-051第三阶段已交付独立v0.4.11，运行代码22c8104；48件装备/考据、动态断枪和购装存档证据见DEV-051交接。第四阶段运动甲声仍未启动。旧阶段时间预算不沿用本轮。

当前版本分支为 `codex/v0.4`。同版本的修复、同一／相近功能继续在该分支提交 commit；大的结构性改动形成新版本时再创建新的版本分支。不按每个小任务新建分支。

## 当前文件占用

QA-051B / 2026-10-30 21:02 UTC：已完成原生鼠标购盔/装备/历史滚动/槽1保存，窗口被最小化且连续用户输入后停止前台操作，等待桌面可用回复。基线05bb448，修改仅test_desktop_v051.gd的隔离QA初始化/重载与验证文档/日志；生产功能未改。desktop_audit独立只读核对QA档与槽1一致。文件释放，后续继续同次QA档，不把未完成对冲记通过。

DEV-051完成：全部文件已释放。运行22c8104与QA/交接4b37a61已推送核对，独立.11实际包/解压双模式/26例真实接触已验。OS仅菜单观察，物理Esc后停止；真人与完整OS流程未验。下面认领段落保留为本轮责任历史。

DEV-051 / 第三阶段（2026-10-29 EDT，03:19:37 UTC开始）：基线7c727b2；root负责catalogue/equipment数据、equipment_art/rider_view/character_face及必要UI/存档挂点、版本/导出/启动器、专项测试和协作文档。motion_review仅负责新增docs/research/V051_EN_FR.md；motion_qa仅负责新增docs/research/V051_DE_IT.md；appearance048负责新pixel_v051/art_sources/v051素材与来源元数据（先诊断/等考据简报），不得改共享渲染器。引擎仅root串行QA。保留既有Claude脏文件；同版本codex/v0.4，拟独立v0.4.11。阶段四运动甲片声不在本轮。

DEV-051范围细分补充：motion_review可写新game/data/history_v051_en_fr.json，motion_qa可写history_v051_de_it.json（仅考据/命名/材质/图ID，不改旧数值）；root额外认领新visual/lance_art.gd及lance_shard、impact_fx和Battle仅武器碎片外观传递，保持碰撞/伤害不变。

DEV-051批量素材归属（首组已引擎验证）：appearance048负责pixel_v051/eng_*及fr_helmet_3的PNG/JSON，motion_review负责fr_*其余11件，motion_qa负责de_*12件，root负责it_*12件；各自同时持有art_sources/v051同ID的源图、提示与来源记录。总equipment_art_v051.json及game/tools/build_equipment_manifest_v051.py仅root合并，Godot仅root运行。EN/FR及DE/IT研究文档、24条覆盖JSON均已交回root。工具悬挂不算开发验证时长。

DEV-051审查归属：全部48件首稿交回root。motion_qa已交回V051_CODE_REVIEW；motion_review持有V051_HISTORY_REVIEW并仅修de_helmet_3独立护颏素材/JSON/source02；appearance048仅写V051_EXPERIENCE_REVIEW。root修复代码审查问题、开放脸孔注册与动态验收，不覆盖审查者仍持有的文件。

DEV-051验收补充：motion_qa仅持有新tests/test_equipment_battle_v051.gd；poses专项已交回root运行。appearance048只读新姿态图并更新体验审查。历史审查及de_helmet_3新稿已交回root；root负责最终导出、实际包专项与OS桌面验证。

DEV-051最终接手：motion_qa状态pending_init后已中断，root接手其已保存的test_equipment_battle_v051.gd作静态审查、运行和必要夹具修复。48件实际包加载/购装/读档已通过；OS工具收到物理Esc，本轮不再桌面操作，未做的OS验证如实留空。

DEV-050实施归属记录：root负责fallen_rider、生产镜头/血腥同步与导出；motion_review交回sound_bank、39 WAV/import、audio及camera测试；appearance048交回整马素材、fall-scene与血腥切换测试；motion_qa交回horse_gait、anatomy/catalogue、V050_HORSE_REVIEW及V050_VALIDATION。所有子任务已释放；root只做最终交接/提交收尾，不继续功能扩张。所有引擎由root串行运行，正式玩家档不使用。

| 负责人 | 任务 | 占用文件 | 状态 |
| --- | --- | --- | --- |
| Codex | DEV-050：两阶段已完成，生产文件已释放；仅交接收尾 | battle、visual/{rider_view,impact_fx,horse_skin,horse_art,horse_gait,exchange_director,fallen_rider,sound_bank}、39音效及新整马素材、版本/导出/启动器、tests/*v050*及设计/协作/验证文档 | a4398d5→75153c4运行代码已推送；独立v0.4.10、30局、实际包/解压包/OS验证见交接。后置QA 02:43:17–03:13:17 UTC，结果单独记。旧包/正式档/Claude改动保留；第三四阶段未实施。 |
| Codex | REQ-050：需求整理完成，文件释放；实施待用户启动 | docs/requirements/IMPACT_FALL_HORSE_TWO_PHASES.md；DESIGN_DECISIONS.md；docs/collaboration/{TASK_BOARD,PROJECT_STATE,WORK_LOG}.md；handoffs/2026-10-29-REQ-050-Codex.md | 基线80ee402，2026-10-29；仅文档与静态核对，没有开发时长授权。不改代码/素材，不导出、不运行游戏。两阶段分别是撞击/完整落马、整马形体/步态；详见REQ-050交接。 |
| Codex | DEV-049：开发/试玩观察/审查完成，全部文件释放 | visual/{rider_view,horse_skin,exchange_director,impact_fx,sound_bank}.gd、mounted_pixel.gdshader、battle、main版本、core/desktop_input_audit、project/export/Play-Latest、pixel_v049/art_sources及来源、tests/*v049*、设计与协作文档 | 基线c2078b6→8c91088运行代码，ce06849与8c91088已推送核对；4.5小时上限内提前完成。独立v0.4.9实包专项/两模式/OS菜单调枪换盾暂停重开、ZIP解压启动通过；枪盾有限速、QA隔离、旧包/Claude既有改动保留。真人/持续OS长按未验收，见DEV-049交接。 |
| Codex | DEV-048：已完成，全部文件释放 | rider_view、core/character_appearance、visual/character_face、game_state、main、版本/导出/启动器、tests/*v048*及本轮证据和协作文档 | 基线a76a9df→ff8f85b运行代码，独立v0.4.8。实际EXE外观与双模式通过；解压Windows包以OS鼠标完成修改/保存/重开/取消/退出。保留旧档、枪盾限速、旧包和Claude改动。详情见DEV-048交接。 |
| Codex | DEV-047：已完成，全部文件已释放 | rider_view、rider_arm_art、新pixel_v047、battle、main、project/export、Play-Latest、tests/*v047*、协作文档与最终归档证据 | 基线fe94f9b→658b4c9运行代码；codex/v0.4，独立v0.4.7-r3。实包/OS/Windows及源码验包完成，91b7d63已推送核对，最后验包回执见HEAD；枪盾限速保留，马体/打击大修留下一次4.5小时，未自动开始。 |
| Codex | DEV-046：开发与验证完成，文件已释放 | 主负责人：game/scripts/visual/{horse_gait,horse_art,rider_view,sound_bank,impact_fx}.gd，core/joust_match.gd，battle.gd，main.gd，project.godot，export_presets.cfg，Play-Latest.cmd；game/tests/*v046*；DESIGN_DECISIONS.md；docs/collaboration/{TASK_BOARD,PROJECT_STATE,WORK_LOG}.md、handoffs/*046*；docs/development/*046*。motion_review只读研究与审查；motion_qa仅新test_motion_showcase_v046.gd及uid，须串行QA | 基线c255844，codex/v0.4。2026-10-28 22:44:33 UTC开始，2026-10-29 01:14:33 UTC截止。既有Claude文档与历史未跟踪证据保留。先改善已有结构，不重写玩法。 |
| Codex | DEV-045：已完成，文件已释放 | 主负责人：visual/{horse_gait,rider_view,horse_art}.gd、core/joust_match.gd、battle/main版本标识、project/export、Play-Latest、game/tests/test_*v045*、DESIGN_DECISIONS、协作与v045证据文档；子代理motion_review只读，motion_qa仅test_motion_showcase_v045.gd及uid | 2026-10-28 21:13:39 UTC开始，22:13:39 UTC停止扩展；基线675f4ca，codex/v0.4。既有Claude文档差异归属已知并保留；在原动作代码上修，不重写玩法。 |
| Codex | DEV-044：已完成，文件已释放 | game/scripts/{battle,main}.gd；core/{joust_match,opponent_ai,desktop_input_audit,game_state}.gd；visual/{horse_gait,horse_art,rider_view,impact_fx,sound_bank}.gd；game/tests/*044*；game/project.godot、export_presets.cfg；Play-Latest.cmd；DESIGN_DECISIONS.md；docs/collaboration/{TASK_BOARD,PROJECT_STATE,WORK_LOG}.md；handoffs/*044*；docs/development/*044*；新动作资产与来源（如需） | 2026-10-27 23:44:45 UTC开始，至2026-10-28 01:44:45 UTC；基线6ee235e，codex/v0.4。按住催马／松手减速替换旧点按缓冲，四步态及过渡和身体多部位随动，双臂对称骨长与左右职责。Claude既有文件保留。 |
| Codex | DEV-043 / R2：已完成，文件已释放 | 本轮登记的游戏源码、测试、启动器与协作文档，详见DEV-043交接 | 两小时上限内完成；最终运行dad3db7，源快照2f3a67d，独立v0.4.3-r2。两种ZIP验包及实际EXE输入／存档／双模式通过；真人未验收，Claude既有差异保留。 |
| Codex | DEV-042：已完成，文件已释放 | 本轮登记的源码、数据、测试、启动器和DEV-042文档 | 2026-10-27 21:47 UTC完成；基线92d7e15。后置审查20:57–21:47，独立v0.4.2包及源码快照已验收。详见DEV-042交接和V042_REVIEW；Claude既有文档改动保留。 |

DEV-049文件细分补充：root新增visual/horse_skin.gd与mounted_pixel.gdshader用于连续马体蒙皮，现接手exchange_director.gd；motion_review仅修改visual/sound_bank.gd；appearance新增素材已释放、转只读复核；motion_qa独占新增tests/test_exchange_timing_v049.gd、test_exchange_scene_v049.gd、test_mount_seams_v049.gd及UID。所有引擎运行由root串行执行，子任务不得并发写QA档。

DEV-049桌面复核补充：root认领core/desktop_input_audit.gd，仅给隔离QA日志增加实际时间缩放、演出阶段与枪盾/镜头记录；不改变输入行为或正式存档。

DEV-049发布复核：root新增tests/test_desktop_v049.gd，沿用v047的无注入桌面观察器，改为独立v049 QA路径和新日志；只记录原生桌面操作。

DEV-049证据整理完成：motion_qa交回V049_VALIDATION及desktop-summary，root补入归档/发布回执；上方DEV-049各细分认领全部释放。历史过程保留，不代表仍有后台任务运行。

认领前登记任务 ID、负责人、文件、开始时间与基线 SHA。修改范围扩大时先更新占用。完成／暂停／交出时释放，并留下具体交接记录。此表不是技术锁；`battle.gd`、`main.gd`、规则模型和同一图集禁止两人各改一套后互相覆盖。审查者先只读，修复需协调文件负责人。

DEV-042范围补充：Codex同时负责新增`game/data/equipment_expansion.json`、`docs/development/EQUIPMENT_042.md`及新的QA脚本；保留旧装备ID以兼容收藏。

DEV-042运行审查补充：`game/scripts/visual/impact_fx.gd`由Codex负责，给落马身体和碎片接入分跑道地面及遮挡，防止新分层与旧单地面冲突。

DEV-042输入诊断补充：Codex负责`game/scripts/core/desktop_input_audit.gd`，记录QA窗口收到的物理／逻辑键码以区分桌面工具投递和游戏处理。

## 建议顺序与验收标准

用户在DEV-050后的明确顺序（仅登记，未启动）：

| 阶段 | 目标 | 验收边界 | 状态 |
| --- | --- | --- | --- |
| 第三阶段：装备素材 | 德国、英国、意大利、法国各6种头盔/6种胸甲；有区别的素材、头/胸防护值和具体年代/用途/考据；骑枪外观更丰富 | 共24头盔+24胸甲，不能同图仅换属性；腿甲只外观/花纹，不另算护甲，不新增腿伤；保留已有收藏ID/存档 | DEV-051完成，独立v0.4.11；文件释放，验证边界见交接 |
| 第四阶段：运动甲声 | 由实际步态、起伏/冲击和材质驱动甲片碰撞声 | 停动安静、强弱随运动、有限叠音预算；区别于DEV-050的真实命中音 | 尚未实施、无文件占用 |

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
