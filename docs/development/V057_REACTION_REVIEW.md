# DEV-057 骑乘受力姿态交接

负责人sound056；基线7fe878f。持有rider_view.gd、lance_art.gd、test_reaction_v057.gd及本文；root负责core反应字段/演出时序、引擎和Git，motion056负责fallen_rider。遵循joust-game-feel、jousting-pixel-art、godot-joust-review及交接流程。本子任务未运行Godot、桌面或Git。

## 原因与本次修改

旧受击仅给Rider.impact_velocity冲量，随后把胸甲六条网格横向弯曲约5.5px；肩、头、实际握枪点和盾外轮廓均未后撤。旧重击几乎冻结游戏时间，恢复read阶段只累计很少游戏时间，局部弯曲在声音后才充分展开。这解释了为什么已经换过声音仍容易看成枪轻轻点上去。用户对“软绵绵”的判断属于实际试玩反馈，本记录不以测试数量否定它。

现在root新增core的reaction_angle/shift、shield_compression和lance_compression弹簧，命中只注入速度，后续用游戏时间连续推进。Rider.arm_pose改用Model.rider_origin和共享pose_angle，头胸肩与两臂跟着实际姿态移动；两只手继续由Model.hand_position/shield_position决定，不能通过画面位移假装受力或改变可见枪尖与判定之间的关系。

座点沿reaction_shift最多6px平移，两侧大腿hip同时跟随；膝和踝维持原马镫支撑位置，避免整个腿跟着座点滑动。原胸甲内部弯压到最多1.5px，骑枪弹性弯从14px压到最多6.5px，握点与枪尖两端仍准确固定。视觉重点改为共用关节受力和盾/枪握点回压，减轻橡皮网格的观感。

## 落马接口

`Rider.head_transform(pose,fighter)`返回最终头/头盔Transform2D。默认pose.head_rotation=0，公式沿用原torso+HeadFit.head_offset注册。fallen_rider可给相对torso、屏幕旋转符号的head_rotation，限制±0.2rad，绕实际胸甲collar.center+(0,2)转。`Rider.neck_geometry`给出torso局部颈根/颈顶/横轴等；绘制颈桥时下颌端随头转，颈根留在原领口下，原领口贴图仍覆盖桥底。mounted不加独立head_rotation，头部受力由共享core姿态驱动。

motion056已确认body_points调用同一head_transform构造盔壳边界。detached绘制只使用传入torso/arms/shield，枪方向用fallen提供的fighter.aim，不重复叠加快照中的mounted反应角/速度。初始头角为0，不切另一套人物素材。

## 验证入口与边界

`--script res://tests/test_reaction_v057.gd -- --test-profile --run-dir=E:/GALUMU/docs/development/logs/v057/reaction02`

必须使用不存在的绝对目录，结果为report.json及reaction_head/body/shield/flank.png；不支持旧夹具的--report/--captures。headless仅几何检查须再加--no-captures。外部发布包可把--script换为测试文件绝对路径，生产preload仍读实际包。

夹具以真实Model._apply_contact计算伤害、格挡、力度及弹簧注入，再用生产advance_reaction推进，不直接手填速度伪造动作。四部位×双向×三俯仰×三盾位共72例，记录frame0无位移、62.5ms共享受力位移、每小步位移、双臂骨长/握点、头胸实际目标、盾中心与可见枪尖一致、1.2秒恢复、轮间清零与不额外扣伤害。为专注骑乘姿态，夹具固定位置/步态、使用稳定性2和高耐久，不能当作真实sweep碰撞或正常完整比赛。

四张渲染姿态板使用真实Rider绘制，显示0、62.5、179.2ms的左右朝向；去掉马和环境便于观察关节，不冒充实战截图。头角0与旧公式比较，±.2角双向/俯仰几何检查已写入；极限颈桥还必须实际图检，不能仅凭几何断言判定美术自然。当前root已报告生产charge01有两次实际胸接触且候选导入无解析错误，反应专项结果待root运行后填写。无人工满意度结论。

## 交回状态

候选代码与测试已保存，root可串行导入/运行。未改声音、装备、护甲值、死亡率、存档或其他共享文件；.uid由引擎生成。需root观察姿态板和实际碰撞连续帧，motion056复核落马颈桥及身体边界；发现不可达手位或穿插后再做针对修复。提交、推送、发布及协作总文档由root统一处理。

## reaction02 与 fall-scene01 原图复核

root运行的reaction02/report.json通过，failures为空；共享挂点最大误差约0.0000432，手臂长度最大误差约0.0001144。中立姿态在62.5ms时，头部命中使头后撤约18.14、胸部命中后撤约21.18游戏单位；盾接触真实中心压缩约12.29、持枪手回压约5.58；腰腹命中为前折。它们是显式接触夹具的姿态数据，不是历史冲量单位、碰撞实战证据或体验评分。

sound056逐张查看reaction_head/body/shield/flank四张原图：两朝向的头盔—颈部—胸口保持可见连接，62.5ms盾压近身体、腰腹前折有可见轮廓差；未见这些取样里出现脱肩或肢体消失。头部与胸部的整体后撤轮廓仍很接近，不能据此宣称各部位动作已经十分鲜明。该组使用封闭式头盔、detached头角为0，仅证明这组绘制取样，不替代极限颈桥或真人冲击感判断。

另直接查看fall-scene01两朝向的airborne与settled共四张原图。两张airborne可见头盔/锁甲颈连到胸口，手臂与下肢仍完整；没有看到明确的头颈断开。日志该取样约0.091游戏秒，没有记录head_rotation，不能写成已经观察±0.2rad极限。实际绘制在早期锁甲盔下没有明显新增裸颈缝，但还需后续极限角捕图。

**落地视觉未通过。** right_whole_settled中躯干接近横躺，肩和胸明显离开地面，整人看起来被一只向下伸的靴子撑在空中；left_whole_settled虽被栅栏遮住中部，仍有相同悬高倾向。两例旧夹具grounded/settled及passed=true不能否定原图问题。已将双向现象交给root与motion056，建议把躯干/骨盆支撑独立于最低靴点验证，保留旧图并修复后重新捕图。本子任务此轮只读生产/测试并更新本文，未自行运行引擎。

body_points当前腿部取关节点，不能直接当完整靴子像素外轮廓；原图右向settled可见靴底比报告body_screen_bounds底更低。此为图像观察与静态边界实现的对应，未声称精确像素接地测量。修复应以身体稳定支撑和实际渲染为准，而不是只满足旧最低点断言。

## 后置复核：极限俯仰/颈桥图片夹具

新增test_extreme_pose_v057.gd，相对继承本轮reaction测试的生产引用、挂点检查与文字标注工具。入口`--script res://tests/test_extreme_pose_v057.gd -- --test-profile --run-dir=<新的绝对目录>`；要求GPU，离屏SubViewport生成extreme_open.png与extreme_closed.png两张1800×1480原图及report.json，不改变游戏窗口布局、玩家设置或生产代码。外部发布验证需同目录保留test_reaction_v057.gd。

两张分别使用开放护鼻盔helm_nasal和封闭盔helm_e2，胸甲均armor_e2；每张四行是双朝向×最大后仰/前倾输入，三列是detached head_rotation=-0.2/0/+0.2。每行先真实_apply_contact计算胸部受击，再按生产弹簧推进62.5ms，同一套骨架/握点只改变头部角度。持枪角固定+.12，以覆盖此前最大后仰后柄穿脸的关键组合；枪仍使用生产REAR/FRONT遮挡次序，不为QA隐藏枪。

图中不画马以便检查上身；极限头角是明确的detached人工姿态取样，不能冒充落马过程自然到达该角度。数值检查只保证同骨架、领口根不动及共享挂点，不能判定脖子自然或后柄遮挡正确。此处记录脚本交回，实际GPU运行及逐张图检结果仍待root执行。

### extreme01 实际原图查看结果

root已GPU执行extreme01，报告passed=true、failures为空，24个姿态及两张1800×1480PNG均落盘。sound056直接查看extreme_open.png、extreme_closed.png原图，另只读报告核对取样：实际胸接触62.5ms，reaction_angle约-0.1621rad、reaction_shift约-3.2717，手持枪角+.12，头相对角为-.2/0/+.2，双向最大前后倾。

这组原图没有看到头/颈/胸之间露背景的明确断缝。开放盔在最大后仰时，枪后柄经过颈后空间、靠近头部轮廓，构图显得拥挤；但可见脸和盔壳保持在柄前，没有看到旧式木杆横盖脸部的新增穿脸回归。封闭盔同样由盔壳遮住经过头后方的后柄。±.2极限头角下颈桥仍连着原胸甲领口，没有出现独立悬着的头或拉成细长裸颈杆。该结论来自两张实际渲染图的观察，不是shader编译、几何误差或passed字段推断。

本次有限图检可通过头颈连接与后柄分层这两项；范围仅为helm_nasal/helm_e2配armor_e2、所列枪角和固定取样，不外推所有装备、所有枪角、动态自然度或玩家满意度。它补齐此前“±.2极限颈桥未实际看图”的窄项，不替代落地支撑修复后复验；fall-scene01的悬空失败记录保持不变。本子任务只追加本文，未新增功能或修改生产/测试。
