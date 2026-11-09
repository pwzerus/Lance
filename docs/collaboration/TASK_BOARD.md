# 任务、审查建议与文件认领

RULE-076交出（2026-11-09）：规则确认与实现完成，c9f5f0c / v0.4.31，后台实际包复验通过，全部认领释放。实战规则不再待选择；真人平衡、FEEL-075单次绘图告警及流畅度仍待继续。最新入口以RULE-076为准，以下认领与FEEL-075状态保留历史。

RULE-076 / Codex / 2026-11-09：用户已确认实战有效重击可一击结束、擦碰或头盔抵挡仍可存活；基线93476cde04426d2997c2554c8b949b62a1802cd4，远程相同。认领core/joust_match.gd、必要visual/combat_cues.gd与battle.gd、tests/*076*、版本/导出/启动器、DESIGN_DECISIONS及本轮审查/交接/状态记录。竞技场旧计分/非致死保持；后台保护验证，旧包/正式档/既有rules_v045差异保留。

最新交付（2026-11-09）：FEEL-075 / v0.4.30-r2，运行1013429，文件已释放。优先待办：定位单次多边形三角剖分告警（package-match01），然后确认用户对自然步态/材质音的实际体验；实战致命规则尚未确认。最新交接与审查为FEEL-075，以下旧抬头和认领均保留历史。

最后整理：2026-11-05（Claude DOC-062）。当前交付为FEEL-061/v0.4.21，Codex文件已全部释放；当前占用只有DOC-062的文档，见本页末条。本页认领段按时间顺序追加，以末尾最新条目为准。以下为2026-11-02原抬头，保留为历史：DEV-057接触传力与落马返工已完成，额外找错21:46:11–22:17:42 UTC；独立v0.4.17-r3，运行4ef9bd8。实际包末帧/ZIP/QA验证完成，生产/测试全部释放，root仅收尾提交推送。本轮桌面接口Transport closed，不能沿用QA-054B的OS证据充当本轮试玩。第四阶段运动甲声仍未启动。

当前版本分支为 `codex/v0.4`。同版本的修复、同一／相近功能继续在该分支提交 commit；大的结构性改动形成新版本时再创建新的版本分支。不按每个小任务新建分支。

## 当前文件占用

INC-059：Windows 两次系统卡死。11月3日纽约时间 09:44 与 14:56 的 Resource-Exhaustion-Detector 2004 指向 LanceAndLaurel.exe，分别约 40.8 GB 与 40.3 GB 虚拟内存，随后均有异常重启。上午 desktop04 隔离试玩日志停在主菜单。Codex 已停用 Play-Latest.cmd；暂缓游戏、引擎导入、导出及 DEV-058 发布。逐帧马匹网格更新是调查线索，尚未证实。恢复前先建立有系统级内存上限及超时的隔离运行，再定位分配来源并验证主菜单与实战内存稳定。【2026-11-05状态：保护器已建立，INC-059E修复不可呈现窗口持续绘制暴涨，Play-Latest已恢复并经Start-MemoryBound启动，现指v0.4.21；历史40GB全部原因仍未宣布根治。见本页INC-059E交出段。】

DEV-058验证扩展：motion056只持有新tests/test_feedback_v058.gd/.uid，继承原真实扫掠夹具，增加实际缩放差、逻辑像素震动/开关/暂停/双击稳定性和HUD/挂点观察；root继续独占引擎。其他代理不改生产。

DEV-058 / 2026-11-02 23:15:46 UTC：用户试玩.17后要求对冲瞬间更明显减速、镜头放大、撞击和震动。基线c3517a0，沿用codex/v0.4，拟独立v0.4.18。root认领battle.gd、visual/exchange_director.gd、必要impact_fx.gd及版本/导出/启动器/设计交接文档；timing056仅只读并写V058_INDEPENDENT_REVIEW，sound056仅只读并写V058_FEEL_REVIEW。root串行引擎/QA与桌面，保留正式档/旧包及Claude五项既有差异。目标强化实际命中后的时序与镜头，不加伤害，不瞬移枪盾，不重写已修落马。没有本轮额外时间额度要求。

DEV-057交出：motion056/sound056/timing056生产全部释放，以下认领段为历史。root完成最终文档/启动器/提交后释放本轮全部文件。具体修改、验证类型和下一步见DEV-057交接。

DEV-057后置极限检查补充：r2实际包24组姿态有3组低盾右向落地被长盾撑胸；motion056认领原fallen_rider/test_fall修复上肢地面可达候选，不放宽关节/骨长/支撑阈值。源码stress02及fall05通过后冻结，最终独立导出.17-r3，首包/r2保留。root继续独占最终包验证、启动器和交接。

DEV-057后置审查修复：motion056重新持有fallen_rider及其test，删除未参与靴贴片绘制的独立脚踝角，使foot地面包络跟随实际shin/靴朝向；不新造分件。首导出.17保留为候选，最终另导.17-r2。root负责导出路径更新与复验。

DEV-057后置专项从21:46:11 UTC至至少22:16:11 UTC：生产c51af0f已冻结待实际包复验；sound056仅新增tests/test_extreme_pose_v057.gd/.uid及自己的review，用真实渲染复核极限俯仰受击后柄和detached颈桥。motion056/timing056仅独立只读代码/图像审查。root持有最后导出、必要修复及文档，所有引擎串行。

DEV-057验证扩展：sound056另持有新tests/test_timing_v057.gd/.uid，保留旧v049测试，按contact先加载再冻结的新合约复用暂停/重开/30/60/120Hz限速及扫掠落空验证；root继续独占引擎。motion056优先修实际截图发现的单靴撑高躯干落地问题；不能以旧最下点不穿地断言当自然平躺通过。

DEV-057 / 2026-11-02 20:16:52 UTC：用户试玩.16后仍认为对冲软、死亡僵硬，要求按实际命中部位传递冲力及关节动作，完成后另计30分钟审查修复；主实现未另设截止。基线7fe878f，既有Claude/历史五项差异继续保留。root持有battle.gd、core/joust_match.gd（仅必要事件/受击状态）、visual/exchange_director.gd、impact_fx.gd、必要版本/导出/启动器及DEV-057设计/协作记录。motion056持有visual/fallen_rider.gd、新tests/test_fall_v057.gd/.uid和V057_FALL_REVIEW.md；sound056持有visual/rider_view.gd、必要lance_art.gd及新tests/test_reaction_v057.gd/.uid与V057_REACTION_REVIEW.md；timing056只读诊断碰撞/演出并持有新tests/test_impact_v057.gd/.uid和V057_INDEPENDENT_REVIEW.md。所有引擎/QA存档/桌面由root独占串行；不改正式档、旧包，不重写玩法或添加肢解。目标独立v0.4.17，同codex/v0.4；功能完成后单独记录后置30分钟开始/结束。

DEV-056完成：root、motion056、timing056、sound056所有生产、QA和审查文件已释放；root仅处理交付提交/推送。v0.4.16及ZIP实际包通过，正式档/旧包保留。后续优先补实际OS长按与人耳听感；不把自动运行当作玩家认可。以下DEV-056认领段保留为历史，不代表仍占用。

DEV-056 / 2026-11-02 11:32:16 EST：用户启动两小时冲锋手感阶段（首轮至13:32:16 EST，关键问题可延长，提前完成继续有依据试玩/审查/修复）。基线11b9b1c，现有Claude文档与rules_v045改动归属沿用并保留。root认领core/joust_match.gd、visual/horse_gait.gd、rider_view.gd、battle.gd、exchange_director.gd、impact_fx.gd及必要main版本入口、project/export/Play-Latest、设计与交接文档；不重写已验头颈与枪层。子代理sound056只持有visual/sound_bank.gd、新assets/audio/impact_v056/、相关生成工具/test_impact_audio_v056.gd/.uid和V056_AUDIO_REVIEW；motion056只读动作诊断及新test_charge_motion_v056.gd/.uid、V056_MOTION_REVIEW；timing056只读时间/镜头/输入审查及新test_exchange_v056.gd/.uid、V056_TIMING_REVIEW。引擎/桌面由root独占串行，隔离QA档。目标独立v0.4.16，同codex/v0.4分支，保护正式档与.15-r2。

DEV-056审查扩展 / 12:12 EST：motion056新增持有tests/test_terminal_pose_v056.gd/.uid，检查结果页冻结时骑手/马体步态标志不一致；root只在battle.gd作最小修复。sound056新增持有tests/test_contact_mix_v056.gd/.uid，录制隔离进程实际混音做峰值与材质预览。原桌面接口Transport closed，重试与重置失败，尚无本轮OS输入证据；不以自动渲染代替手动试玩。

DEV-056落马图像复核 / 12:12 EST：timing056新增tests/test_fall_layers_v056.gd/.uid，检查本轮实际接触图中近腿突然被马腹遮挡的同z绘制顺序；root仍只修改battle.gd场景排序，不扩大物理或死亡规则。

DEV-056整段对冲观察：timing056新增tests/test_full_charge_v056.gd/.uid，由真实Battle正常process/physics从倒计时到接触/交错运行，引擎派发一次按住/松开/再按住及盾位输入，补1900→1200镜头转场和连续帧证据；root串行引擎与最终包复验。

QA-054B完成：root、manual_pose055及fit_audit055文件全部释放，仅收尾提交/推送。最终.15-r2包含7e7686a与a6accff，源码/实际包四张枪层图一致，头部接触/落马、解压双模式及9图、实际OS暂停关闭干净。正式档和.14旧包保持原SHA。以下QA-054B段为认领历史，不代表仍占用；未声明全部外观或实战持续按键极限俯仰已验。

QA-054B / 2026-10-30 23:00 EDT：用户要求实际桌面手动换盔/左右/俯仰检查，完成后另做至少10分钟找错，发现问题继续修复不因10分钟结束而遗留。基线be84a03，实际包v0.4.14。root认领本轮桌面观察脚本/日志、必要character_face/head_fit/rider_view/fit数据修复、版本导出及交接文档；manual_pose055只写test_head_manual_v055.gd/.uid与V055_POSE_TOOL.md，fit_audit055只读审查并写V055_INDEPENDENT_REVIEW.md。实际比赛OS操作与交互QA姿态查看器分开报告；root独占引擎和桌面，不注入按键冒充手动。正式档/旧包/既有Claude改动保留。十分钟起点在首轮手动验证完成后记录，不用准备时间抵扣。

QA-054B具体观察文件：root仅新增game/tests/test_desktop_v055.gd/.uid（复用旧v051初始化和只读输入记录，补本轮外观/方向/俯仰状态与F8截图），docs/development/logs/v055/、screenshots/v055/和V055_DESKTOP_PLAY.md；不改生产desktop_input_audit。

QA-054B修复扩展（23:15 EDT）：OS交互姿态发现最大后仰、枪角+.12时后柄双向穿脸。root新增认领game/scripts/visual/lance_art.gd，与rider_view.gd就地调整后柄/前段遮挡，不改物理枪位或动作限速。manual_pose055仅新增test_lance_layer_v055.gd/.uid及V055_LAYER_QA.md，不跑引擎。拟独立v0.4.15修复包；.14保留。

QA-054B退出警告排查（23:28 EDT）：十分钟专项结束时发现比赛后退出泄漏，verbose证实AudioStreamWAV/PlaybackWAV，非脸部/模型。root新增认领tests/test_audio_exit_v055.gd/.uid及必要sound_bank.gd/battle.gd生命周期修复；先最小复现与定位，原有stop_all保留，不盲目删除资源。独立审查仍只读。

DEV-054完成：root与两位独立审查者全部文件释放，root仅收尾提交推送。新版.14实际包10张头像/选项图与源码SHA完全相同；最小化GPU自动QA，不代表OS输入或用户满意。既有Claude改动、正式档及.13旧包保留。下面为认领历史。

DEV-054 / 2026-10-30 22:40 EDT：用户否定自建像素脸五官与表情，基线aa753bc。root认领game/scripts/visual/character_face.gd、必要head_fit.gd适配、版本/导出/启动器与本任务设计/交接记录；face_art054只读美术并写V054_ART_REVIEW.md，face_qa054仅写test_face_design_v054.gd/.uid及V054_QA_REVIEW.md。现有脸型/肤色/眉毛/胡须/瞳色索引保持，改五官簇、三分之四比例和颌面层次，以实际自建UI、无须骑手双向戴盔和正常显示尺寸审图。root独占引擎串行隔离QA；旧包/正式档/既有Claude改动保留。此轮不开展后续加速或声音。

DEV-054补充：root认领main.gd的CharacterFaceCanvas调用，独立draw_portrait只在自建头像补短颈与胸肩，骑乘/旧备用头部不接入。QA脚本已由face_qa054交回，root改其sheet直接复用生产CharacterFaceCanvas，避免复制绘制调用或遗漏头像衣领。

DEV-053完成：所有生产/QA/审查文件已交回并释放，root仅作最终提交推送。独立v0.4.13源码dfde0ec；两反馈组合无须前后对照、全套/高领/深肤色、实际包头部命中与落马、ZIP双模式已验。旧.12与正式档保留；玩家对新版满意度未验收。下次加速/音效两小时没有启动。下方为认领历史。

DEV-053 / 2026-10-30 22:06:54–22:51:54 EDT：用户否定v0.4.12头颈佩戴观感，45分钟专项返工。基线25a2a04。root认领head_fit.gd、character_face.gd、rider_view.gd、equipment_fit_v052.json、必要装备佩戴元数据/素材、版本导出启动器、设计与交接文档；head_art_review053只读审查并写V053_ART_REVIEW.md；head_qa053仅写test_head_wear_v053.gd及.uid、V053_QA_NOTES.md。引擎由root串行。以用户两图实际尺寸/特写比例与自然接缝为验收，alpha连通不作为美术通过。保护既有Claude文档/正式档/旧包；拟独立v0.4.13，同分支。加速/音效不在本轮。

DEV-053范围补充：root同步fallen_rider.gd的视觉头框到领口水平偏移，并修受击时领口覆绘顶点；head_qa053新增独立V053_CODE_REVIEW.md、无须深肤色高领夹具，现脚本及审查已交回root。生产与引擎仍只有root操作。

DEV-053动态补验：head_qa053仅认领新test_head_contacts_v053.gd及.uid，复用旧生产接触夹具检查英/法/德0号头盔双向真实头部命中与落马；root独占实际EXE运行。针对本轮缩盔和头部小幅对中风险，不扩大玩法。

DEV-052完成：生产与QA修改已完成，所有文件释放。运行3a0487f、QA08e7f5b、日志ac1ab98已push且远程SHA核对；24头盔及脸/颈/领口注册、落马头框同步，最终源码与实际PCK渲染一致，ZIP解压双模式三轮及9张截图完成。正式档与.11旧包不变；本轮无OS输入或真人听音。下次两小时必须等用户启动，不因今晚提前完成而自动用掉。以下认领段保留为责任历史。

DEV-052 / 2026-10-30 21:10:40 EDT至22:40:40 EDT：Codex负责今晚90分钟头盔/头颈/胸甲适配。基线b8adf017；认领game/scripts/visual/{rider_view,equipment_art,character_face}.gd、必要新head_fit.gd及data/equipment_fit_v052.json、tests/*v052*、版本/导出/启动器和DEV-052设计/验证/交接文档。先定位固定头框与实际素材挂点差异，在原渲染链改进；仅在确有需要时扩展位图资源。保留Claude既有未提交文档与旧QA结果。加速颠簸/撞击声音和镜头留待下次用户启动两小时，本轮不改。所有引擎验证由Codex串行，隔离QA，拟独立v0.4.12，同分支codex/v0.4。

DEV-052范围补充：fallen_rider.gd仅同步视觉落地轮廓到新头盔佩戴尺寸，避免继续用固定旧头框；不改KO/死亡或玩法碰撞。代码与测试仍由Codex单独持有。

QA-051B补验已交出：desktop03–06完成购装/读档/三种模式结算/暂停继续重开/设置重启与保存退出，观察日志及QA独立复核，游戏已关闭。没有确认新生产阻断；持续OS长按/听感/真人保留未验。发布包未改，所有本任务文件释放。以下是认领与中断历史，不代表仍占用。

QA-051B最终补验（2026-10-30 EDT，基线8f4c068）：用户在物理Esc中断后重新明确“继续验证”“你继续进行测试”。root继续占用desktop03/04/05/06证据、V051_DESKTOP_PLAY、QA-051B交接及PROJECT_STATE/WORK_LOG的本任务条目；desktop_audit仅只读核对日志。仅补桌面操作和文档，不修改游戏代码/美术/正式存档，不重导旧包。

QA-051B续测：用户明确回复“可以，继续并恢复窗口”。root接续原QA档，认领本次desktop03/04日志、V051_DESKTOP_PLAY及QA-051B交接/现状/记录；仅原生桌面验证，生产代码/素材不改。旧窗口已自然退出，使用--resume-qa重新打开同一QA档。

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

INC-059修复认领：Codex负责Start-MemoryBound.ps1、Play-Latest.cmd、game/project.godot、export_presets.cfg、visual/horse_skin.gd、新内存QA和本次交接。先验证Job限制，再串行短时QA；禁止无界启动。
INC-059范围补充：Codex认领scripts/ui/ui_factory.gd、scripts/main.gd、tests/test_memory_inc059.gd；固定字体缓存/帧预算与Windows启动保护。
INC-059范围补充：equipment_art.gd及pixel_v051/*.png.import、字体import由Codex负责；装备运行纹理上限512，原图保留，缓存最多12项。
INC-059补充：equipment_art_v051.json添加原图尺寸，导入缩图后按比例保持裁切/挂点。
INC-059启动器范围补充：Play-Input-Diagnostic.cmd也改为受保护执行，关闭旧诊断脚本无界启动路径。

INC-059当前：防护与优化落地，独立memory2实际包四次往返验证；历史40GB根因仍开放P0，后续只能限额复现。生产文件本轮收尾后释放。详见2026-11-03-INC-059-Codex交接。

INC-059B / Codex接手2491ad9：继续定位40GB根因，手机内存预算考据。认领Start-MemoryBound.ps1、新内存隔离测试及INC059B报告；既有他人差异保留。系统事件新发现：上午进程创建到首次耗尽仅约111秒，下午约179秒，因此上一轮82–90秒测试不足以排除启动后延迟增长。

INC-059B暂停运行：只读检查约3.1GiB可用，保护器要求4GiB；用户释放内存后续240秒隔离。诊断工具代码已保存，Godot新夹具未验收，P0根因未解决。

INC-059B状态追加：240秒原版受限运行未复现；用户现要求仅静态排查，动态验证暂停，根因仍开放。

INC-059C / Codex / 基线01ec9fb：仅静态排查40GB与性能热点；认领visual/horse_skin.gd、visual/rider_view.gd、新静态资源审计脚本及INC059C交接文档。禁止运行Godot/游戏；不改动作曲线与规则。

INC-059C范围补充：battle.gd仅修_on_hoof_contact重复IK计算；tools/audit_memory_assets.py仅读取资源头、源代码引用与文件尺寸，不加载引擎或解码图片。

INC-059C交出：静态优化与资源审计已保存，生产文件释放；GDScript解析/运行待授权阶段。40GB根因P0不关闭，详见2026-11-03-INC-059C交接。

INC-059D / Codex接手8894b26：用户允许动态排查；认领新的窗口/场景内存压力QA、INC059D报告与必要的根因修复。先遵守现有1GiB Job及内存余量，单实例、隔离存档。

INC-059D检查点：已准备窗口/字体缓存QA，未运行；RAM低于现有启动线，用户选择释放内存后继续。等待，不关闭根因任务。

INC-059D动态检查点：见INC059D_DYNAMIC_REVIEW；下一步真实关闭路径与font-one隔离，等待用户再次释放内存。P0未解决。

INC-059E / Codex：接手5d3c2fd，用户已无其他窗口；核查仍有后台应用但不终止。认领Start-MemoryBound.ps1启动预算计算与close/paused-close验证；默认1GiB硬限/900MiB早停/2GiB运行保留不变，启动余量改为2GiB+1GiB+256MiB，增加提交余量检查。

INC-059E范围补充：main.gd/project.godot/export_presets.cfg仅更新候选0.4.19版本标识与独立目录；Play-Latest.cmd验证后指向新包。Start-MemoryBound为默认试玩保存有界诊断日志。根因仍开放，不将保护包装当作根治。

INC-059E根因修复扩展：旧版最小化立即暴涨，新候选10FPS仍增长；freeze-rider控制稳定。认领scripts/core/window_activity.gd、visual/rider_view.gd、visual/impact_fx.gd、visual/lance_shard.gd、battle.gd、main.gd、QA和独立v0.4.19修复包。停止不可见窗口的持续绘制与模拟，保留原战斗暂停语义。

INC-059E交出：5394dec代码修复已提交；实际v0.4.19-memoryfix完成271秒最小化、六种页面/战斗恢复、229秒连续5局/4重开、最小化关闭及退出后60秒观察。已复现的不可呈现窗口持续绘制暴涨路径修复闭环；保留1GiB保护。Play-Latest指向新包；释放本轮认领文件（lance_shard最终无需修改）。历史全部系统卡死条件/跨驱动行为仍未排除，详见INC059E审查。交接文档与证据同分支提交并按远程SHA核对交出。

ART-060 / Codex / 2026-11-04：基线868a337；认领horse_skin.gd、rider_view.gd、catalogue.gd、新horse_coats资源与QA、版本/导出入口、协作记录。四国共享多套独立马匹素材，保留十项属性取舍及内存保护。既有Claude文档差异保留。

ART-060静态交出：素材与源码已保存，释放文件认领；等待用户后续允许动态验证。资源预算不足时未启动引擎，用户随后选择仅静态。尚不能标记美术集成验收完成或新版本发布。

ART-060V / Codex / 2026-11-04：接手7e8ecf2，用户授权恢复保护下的运行验证、修复、独立导出和GitHub提交。认领horse_skin/rider_view必要修复、新动态QA、版本/导出/启动入口、协作记录。保留既有文档差异。

ART-060V交出：四套素材运行验证完成，三份导入配置修复，v0.4.20独立导出且实际包复验；释放认领文件。保护器未关闭或降限；测试存档与备份独立到工作目录。日志环境证书/编辑器设置权限提示及未做真人试玩的边界见ART060V_REVIEW。

FEEL-061 / Codex / 2026-11-05 10:01–12:01 EST：基线0e603cd，用户授权两小时专项改善步态，不接管屏幕。认领horse_gait.gd、horse_skin.gd、rider_view.gd、必要的joust_match.gd挂点/步态状态、新QA、Start-MemoryBound.ps1后台隔离桌面选项、版本/导出入口及协作文档。保留他人未提交文档，内存/CPU限额不变。

FEEL-061验证扩展：test_terminal_pose_v056.gd 比较项补充新增head自由度，检查结算冻结／模型与渲染一致；只改QA，不改变原结算规则。

FEEL-061交出：已修曲线突变、后蹄倒甩、肩部卸载和离地时序，减少整马弹跳并加入协调头部。原骨长／角度／脚锁阈值保留；实际.21包、四套外观/双朝向、30次催马切换不均匀帧率、结算冻结及两组约313秒重开/最小化均完成。Play-Latest已切换独立.21包，保护器持续开启。释放全部认领文件（joust_match最终无需修改）；文档和远程回执见FEEL061_REVIEW及本日交接。无人接管用户屏幕，真人观感未验收。

DOC-062 / Claude / 2026-11-05：接收FEEL-061并整理过时的当前状态文档。基线e772acd（读.git引用文件并经ls-remote核对，与origin/codex/v0.4一致）。认领HANDOFF.md、docs/collaboration/{PROJECT_STATE,TASK_BOARD,WORK_LOG}.md、handoffs/2026-11-05-FEEL-061-Codex.md的“接收与复核”栏、新handoffs/2026-11-05-DOC-062-Claude.md。只改文档，不改游戏源码、素材、启动器或发布包，不运行游戏。按用户指示Claude不执行git：改动留在工作区未提交，由用户安排Codex审核后提交推送。

DOC-062交出：FEEL-061接收回执已填写，HANDOFF／PROJECT_STATE／TASK_BOARD过时段已修正，WORK_LOG已登记；全部认领文件已释放。改动未提交，逐段清单见handoffs/2026-11-05-DOC-062-Claude.md。未运行游戏，未改源码或发布包。

ART-063 / Claude / 2026-11-05：用户反馈部分马匹皮毛呈密集裂纹、观感恶心，要求更真实好看；马匹动作与骨架更自然；部位拼接处仍有黑线；GPT生成图案差，要求Claude制作马匹美术。基线e772acd（另有DOC-062未提交文档）。认领game/scripts/visual/{horse_skin,horse_gait,rider_view}.gd、mounted_pixel.gdshader、新马皮素材目录game/assets/art/horse_coats063/及其生成脚本与来源记录、新tests/test_horse_art063.gd、必要的四套马皮.import、版本/导出入口(project.godot、export_presets.cfg、main.gd版本标识、Play-Latest.cmd)、DESIGN_DECISIONS增补与协作/审查文档。先诊断再就地改进，保留十匹马属性、四套外观映射、规则挂点与内存保护；不接管屏幕，运行一律经Start-MemoryBound隔离桌面。Claude不执行git，改动交Codex审核提交；拟独立v0.4.22，不覆盖.21。

RIDER-064 / Claude / 2026-11-06：用户反馈人物骨架与动作僵硬、不灵活、不丝滑。基线e772acd加ART-063未提交改动。认领game/scripts/visual/rider_view.gd（seated_leg_pose、_draw_seated_leg、_head_hinge、_draw_pose_neck）、新tests/test_rider_motion064.gd、test_rider_legs064.gd、版本/导出入口与协作文档。只改视觉骨架，模型的rider_origin/pose_angle/hand/shield/head命中锚点及姿态惯性不改；不接管屏幕；改动不提交，交Codex审核。

HORSE-065 / Claude / 2026-11-06：用户要求马皮去掉花纹与毛发纹理；马腿不要“往后弹”的假动作，参考RDR2自然动作；加入马匹疲劳（耐力、承载、盔甲重量、长时冲刺与速度）；之后再改人物脸部和长枪/盾/盔甲的辨识度。认领tools/horse_coat_v063.gd与horse_coats063素材、visual/horse_gait.gd、core/joust_match.gd（体力与速度规则）、新core/horse_condition.gd、core/opponent_ai.gd（体力判断）、battle.gd（耐力HUD文字）、新tests/*065*、版本/导出入口与文档。规则改动记入DESIGN_DECISIONS；不接管屏幕；改动不提交，交Codex审核。

RIDER-064交出：腿部IK与马镫挂马鞍、马镫随步态摆动、前后倾时蹬住马镫、骑乘时头部反向稳定；命中锚点未改。独立v0.4.23已导出复验（PCK 9DA780F9…），Play-Latest已切换；全部认领文件释放，改动未提交。详见handoffs/2026-11-06-RIDER-064-Claude.md。姿态切换速度与枪盾缓动待用户决定。

ART-063交出：四套马皮重绘并改用mipmap线性过滤；关节轮廓黑线和远侧前腿碎片已处理；系骨/硬蹄分段，承重时球节下沉。独立v0.4.22已导出并复验，Play-Latest已切换。另认领并修改了test_horse_coats060.gd（一行断言）和新的tools/package_v063.gd。全部认领文件已释放，改动未提交。逐文件清单、验证和提交建议见handoffs/2026-11-05-ART-063-Claude.md。OS输入和真人试玩未执行。

DOC-065 / Codex / 2026-11-06：用户明确要求每次接手先读Claude的新进度、改动和日志，以实际最新工作区继续开发，不能沿用聊天中旧版。基线e772acd叠加DOC-062、ART-063、RIDER-064未提交改动（本地v0.4.23）。仅认领AGENTS.md、HANDOFF.md、PROJECT_STATE.md、TASK_BOARD.md、WORK_LOG.md的本轮流程增补，以及DOC-062/ART-063/RIDER-064的接收栏、新DOC-065交接；不改游戏、不运行引擎、不将Claude未复核代码直接提交。

DOC-065交出：接手基线和每次核对规则已写明；只读接收汇总集中在DOC-065交接，未预填Claude三份记录中的完整复核/放行栏。未改源码、素材、测试或发布包。仅提交本轮追加的流程记录，Claude未提交内容保持原状；释放全部认领文件，完整代码审查与运行复验未执行。

HORSE-065交出：马匹疲劳（负重/承载/恢复/疲劳上限）、无花纹马皮、腿部摆动、半格脸部、盾牌与长枪辨识。独立v0.4.24已导出复验（PCK 140491FD…B606），Play-Latest已切换；改动未提交。详见handoffs/2026-11-06-HORSE-065-Claude.md与HORSE065_REVIEW.md。

EQUIP-066 / Claude / 2026-11-06：用户要求盔甲细节、纹章与盾牌纹章看得清；新增纯装饰、轻微负重的马衣；按真实装备设定重量并平衡轻重甲（重甲防御高、轻甲快，轻甲可凭技术战胜重甲）；评估需求、调研同类游戏与玩家反馈并给出建议。基线a5b0c2f（.git引用）叠加DOC-062/ART-063/RIDER-064/HORSE-065未提交改动。认领core/{catalogue,game_state,horse_condition,joust_match}.gd、visual/{heraldry(新),shield_art,horse_skin,rider_view}.gd、main.gd（军械库）、新data/{equipment_weights_v066,caparisons_v066}.json、新tools/caparison_v066.gd与assets/art/caparison066/、新tests/*066*、版本/导出入口、DESIGN_DECISIONS与EQUIP066文档。部分接手HIST-01中马衣与纹章一项。不接管屏幕；改动不提交，交Codex审核。

EQUIP-066交出：重量表、马衣槽（12 张蒙皮贴图）、纹章盾面、负重门槛／灵活度／坐稳／冲力、军械库重量与负重显示，以及调研和建议文档。独立v0.4.25已导出复验（PCK 6679791C…A456），Play-Latest已切换；全部认领文件释放，改动未提交。待用户决定：盔甲配置（同档轻重选择）、计分、马衣非战斗收益、前倾切换速度。详见handoffs/2026-11-06-EQUIP-066-Claude.md与EQUIP066_REVIEW.md。

EQUIP-067 / Claude / 2026-11-06（用户授权70分钟）：看得见的马匹疲劳、头盔"胖"，以及用户对待定事项回复"开始做"（计分、前倾速度、马衣收益、马衣镜像）。认领battle.gd、core/{joust_match,game_state}.gd、ui/combat_report.gd、visual/{head_fit,rider_view}.gd、main.gd、caparison工具与新贴图、tests/*067*、版本入口与文档。
EQUIP-069 / Claude / 2026-11-08：用户批准计分加入护甲实击门槛并重测。认领core/joust_match.gd、ui/combat_report.gd、main.gd、tests/test_balance066.gd、版本入口与文档。
EQUIP-069交出：v0.4.28已导出复验（PCK D468711A…），Play-Latest已切换；释放全部认领文件，改动未提交。见handoffs/2026-11-08-EQUIP-069-Claude.md。
EQUIP-068 / Claude / 2026-11-06：枪盾缓动、骑手臂力、马疲劳分档。认领core/{joust_match,horse_condition}.gd、battle.gd、tests/test_arm068.gd、版本入口与文档。
EQUIP-068交出：v0.4.27已导出复验（PCK A80B7531…），Play-Latest已切换；释放全部认领文件，改动未提交。见handoffs/2026-11-06-EQUIP-068-Claude.md。
EQUIP-067交出：v0.4.26已导出（PCK 36467CD9…），Play-Latest已切换；全部认领文件释放，改动未提交。罩袍纹章与枪盾缓动未做，计分后AI胜率未重测。详见handoffs/2026-11-06-EQUIP-067-Claude.md。

REVIEW-070 / Codex / 2026-11-09：基线a5b0c2f，接收DOC-062至EQUIP-069已确认归属Claude的工作区。认领各交接接收栏、现状/日志/任务板、本轮审查证据；复验后按文档、素材数据、代码工具、测试、版本入口分组提交，保留所有旧包及存档。必要缺陷修复先记录。

REVIEW-070检查点：静态接收及PCK核对完成，指定动态复验被保护器启动预算拒绝，等待内存余量。分组提交保存已有成果，未标里程碑动态验收完成。

REVIEW-071 / Codex / 2026-11-09：接续REVIEW-070，认领Start-MemoryBound.ps1系统余量由2GiB改为用户指定1GiB；游戏1GiB硬限/900MiB提前停止保持。复验七项、必要修复与接收栏/现状/日志/审查记录；不接管屏幕、不覆盖旧包。

REVIEW-071交出：七项复验全部通过、无游戏代码缺陷修复；根保护器系统保留1GiB，旧包不覆盖。接收栏/现状/日志/证据完成，释放认领；真人手感和未完美术范围继续保留。

FEEL-072 / Codex / 2026-11-09：基线03d450a，认领后台画面复验与命中部位/受力可读性修复。文件：game/scripts/core/{joust_match,shield_geometry}.gd、visual/{rider_view,shield_art,combat_cues,impact_fx,exchange_director}.gd、battle.gd，新增tests/*072*，相关现状/交接/审查/设计记录与必要版本入口。保护1GiB系统余量及全部限制；不接管桌面、不覆盖旧发布。历史rules_v045_results与旧未跟踪证据保留。

FEEL-072范围补充：盾牌受力偏转需同步visual/hit_zone_overlay.gd判定绘制和visual/fallen_rider.gd落地包络，认领这两文件，避免视觉偏转后沿用旧碰撞边界。

FEEL-072画面发现：慢步/快步部分相位尾巴与后腿出现梳齿状交叠，认领visual/horse_skin.gd，复核网格权重与透明缝，不改马匹属性或步态。另将ui/combat_report.gd同步命中部位名称。

FEEL-072保护器诊断修复：测试正常退出与采样读数竞争会抛Process has exited异常，认领Start-MemoryBound.ps1，只修退出竞态，所有预算/CPU/单实例/桌面约束保持。

FEEL-072交出（2026-11-09）：c69384e已推送核对，.29-r3完成后台GPU/有限控制/实际包三轮及长结果滚动复验。头盔/马衣样本已复核，修尾腿缝与疲劳显示，增加可读受力；全部认领文件释放。罩袍纹章、真人手感/材质听感及历史平衡缺口保留。详见FEEL072_REVIEW与交接。

QA-073 / Codex / 2026-11-09：基线18fb3ba，用户要求恢复后台画面验证，系统保留改500MB，其他保护保持；不接管桌面。认领Start-MemoryBound.ps1（500MiB系统底线/日志）、DESIGN_DECISIONS.md、HANDOFF.md、现状/任务板/日志、本轮QA073审查与交接及072接收栏、新logs/qa073-*。复验现有.29-r3实际PCK；如发现生产缺陷先追加具体文件认领。历史rules_v045_results和未跟踪材料保留。

QA-073交出：500 MiB根保护线已生效，12次实际包后台运行退出0，逐图审查马匹/头盔/纹章/疲劳/双向受击与正常三轮比赛，未复现新生产缺陷。游戏包未改，证据/交接已保存，认领文件全部释放；真人手感、音频、长测及罩袍纹章缺口保持。详见QA073_REVIEW。

DOC-074 / Codex / 2026-11-09：基线6b19841，按用户指示固化双方默认后台验证与真实桌面操作事先授权。认领AGENTS.md、HANDOFF.md、DESIGN_DECISIONS.md、docs/collaboration/{HANDOFF_TEMPLATE,PROJECT_STATE,WORK_LOG,TASK_BOARD}.md与新DOC-074交接；仅文档，不运行游戏。

DOC-074交出：双方默认后台验证及真实桌面操作事先授权已写入AGENTS、交接入口/模板与现状/设计记录。仅文档检查，无引擎或桌面操作；认领全部释放，既有游戏差异保留。

FEEL-075 / Codex / 2026-11-09：基线f8d9b40，接续.29-r3；认领visual/{horse_gait,rider_view,sound_bank,fallen_rider}.gd、core/joust_match.gd、必要battle/exchange_director、tests/*075*及音频资产/生成工具、版本导出入口与设计/审查/交接文档。先诊断连续起步/加减速，再改受力/声音；实战致命门槛待用户回复。全部后台经保护器/QA，旧包与遗留差异保留。

FEEL-075范围补充：长测关闭未退出，隔离QA存档残留tmp；认领core/game_state.gd的存档目录处理及tests/test_save075.gd。先定位异常，不替用户关闭程序，不碰正式存档。

FEEL-075交出：保存退出修复27e8388，动作/声音/发布1013429；独立.30-r2实际包验证和文档证据保存。RiderView/LanceArt/ShieldArt/HeadFit/RiderArmArt临时诊断全部移除，生产未改；battle/exchange_director未改。保留一次无法复现的三角剖分告警，未声称修好，详见FEEL075_REVIEW。系统500MiB及其余保护不变，无OS接管。全部认领释放，既有rules_v045与历史未跟踪材料不纳入提交；仍待用户确认的规则/真人体验不标完成。
