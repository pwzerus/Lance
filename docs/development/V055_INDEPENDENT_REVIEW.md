# DEV-055 头脸佩戴独立复核

2026-10-30 EDT，fit_audit055 子代理。仅只读生产代码与已经存在的实际渲染图；未运行Godot、未操作桌面、未修改生产或存档。root执行本次OS试玩，后续新证据在取得后追加；当前静态推断不写成现场复现。

## 当前检查

读取`head_fit.gd`、`character_face.gd`、`rider_view.gd`及`equipment_fit_v052.json`。头与脸共用同一head_transform，颈根固定在未镜像的torso领口空间，颈顶随朝向；躯干、头和领口一起随Model.pose_angle旋转。因此单纯前后俯仰没有第二套独立头角度，也没有明显静态可证的头颈变换脱离。

新脸型仍使用旧32×40脸框和FaceSurface裁切；四脸型最低下巴为29或31行，头颈上端约在脸框27.6行并向上重叠3单位。新肖像肩衣仅在draw_portrait，骑乘和旧备用头部不调用它，未发现头像胸肩泄漏进盔孔的调用路径。上述是代码推断，不能代替实际任意姿态的图像判断。

实际查看旧证据：v054/poses01的it_helmet_3、de_helmet_5、eng_helmet_3、fr_helmet_5四脸型左右页；v054/export-wear01/dark_skin_high_collars；v053/allfit02/mixed_back与v054/poses01/fr_back_low。所看头颈/胸领未见明确新增分离，但旧开放盔脸孔页有长胡须，不能作为本轮无须脸适配的完整证据。

## 本轮手动/交互复验优先组合

| 组合 | 参数 | 原因 |
| --- | --- | --- |
| fr_helmet_0 + fr_armor_4 | 无须，浅/深肤，双向，前后极值 | 高立领与最开放脸，容易看出根部错缝或肤色不连续 |
| fr_helmet_0 + eng_armor_0 | 四脸型，双向，后仰 | 低领与下颌均可见，用户原反馈组合 |
| it_helmet_3 + it_armor_3 | 窄长脸，无须，双向 | T形盔孔，较短face_clip，应检查眼孔/下颌是否落在正确开口 |
| de_helmet_5 + de_armor_5 | 方颌，无须，双向 | face框最小，留意壳脸比例与脸颊裁切 |
| eng_helmet_3 + eng_armor_3 | 无须与长须，双向 | 下巴紧贴锁甲，能观察连接但容易被胡须掩盖 |

20件胸甲仍共用默认collar坐标，各开放盔脸框差异较大，跨装备混搭比只看原套装更容易发现问题。受击时胸甲有小幅顶点形变，而颈根按设计固定；前领覆绘使用相同形变函数，但高立领在最大recoil时仍值得观察。两项目前是复验优先级，未确认为生产缺陷。

## 已有可见问题，需与本轮连接检查区分

v054/poses01/fr_back_low.png中，`lean=-1`、低盾、`aim=.12`时，枪杆/后段跨过开放头盔面部，左右均可见。`rider_view.gd::_draw_rider`确实在头盔之后画整枪。前交接已保留此问题；它不是新脸或颈部断开回归。此观察仍需root在实际可操作姿态下区分合理的前景遮挡与显得穿面的材质关系。不能根据隐藏武器的头肩特写宣称正式战斗没有穿插。

## 本轮新证据

独立查看`v055/desktop02/01_home.png`、`02_battle.png`、`03_home.png`三张本轮实际渲染图。01的铁帽、03的尖顶开放盔，在菜单的右朝向和中立坐姿下，脸、短颈与胸领连续，未见明确悬空或脸越出盔壳。此处按图描述外观，最终装备ID应以root的操作记录核对。

02为练习场实际渲染，双方各自佩戴不同头盔；对手闭面盔不能替代同一新脸左朝向检查。普通战斗缩放下未见明显大面积断口，但截图也未证明前后俯仰已达极限，不据此判定极限姿态通过。本代理只查看root取得的图，不把它写成自己实施了OS输入。

后续同装束双向、无须和极限俯仰的交互QA图与参数复核见下。所有结论只覆盖所列范围，不代表真人满意或24×24装备及所有外观组合均无问题。

### 本轮复现：后柄横穿脸

root通过OS输入操作交互QA查看器保存`v055/manual01/pose_002.png`与参数：`fr_helmet_0 + eng_armor_0`、无须、`lean=-1`、`aim=.12`、低盾。该查看器渲染生产RiderView，但不是实际比赛。本代理独立看图，确认双向后柄从开放脸前横穿；与旧图中的现象一致，现已具备本轮可操作姿态证据。头颈本身在图中仍连续，不能把枪杆遮挡误判成颈部缺口。

最小修复建议已交root：保留枪原有手点、surface/radius、长度与碰撞；仅把轴向[-67,0]后柄放到现有全部肩臂绘制之后、第二次颈/领/脸/盔绘制之前。前段[0,shaft_end]、护手与枪尖保留原前层及最后手指覆盖。不要把后柄放到整个躯干后，避免改变原胸肩遮挡；肩臂无需为此重新分层。LanceArt的全枪入口仍供独立/脱离枪调用；分段接缝不可额外画内部端帽，握柄缠线避免重复前绘后柄。broken残柄也适用同分层。此处是建议，生产实现与修复后证据由root负责。

### 追加极限姿态

独立查看`manual01/pose_003`—`pose_006`的PNG和JSON：`eng_helmet_0 + eng_armor_0`圆脸，以及`it_helmet_3 + it_armor_3`窄长脸，均无须、浅肤、双朝向、前倾25°及后仰45°。可见头壳/脸孔/领口保持相连，T形盔孔露肤在开口之内；这些组合中未见明确新增的头颈断口。003和006再次复现后柄在后仰时覆盖面部/盔壳；004/005前倾时横胸枪柄层次原本正常，支持只改变后柄相对头颈遮挡的修复范围。全部为root用OS操作的固定生产渲染姿态，不扩展为规则/碰撞或实战时序通过。

追加查看`manual01/pose_007`与`008`及JSON：`de_helmet_5 + de_armor_5`窄长无须脸，浅肤，双向前后极限。小脸孔内脸形与颈领未出现新明确断口；007仍有同一后柄遮挡问题。

### root修复静态复核

审查root对`lance_art.gd`与`rider_view.gd`的差异，未发现阻断缺陷：Layer.WHOLE默认保留独立枪；REAR与FRONT复用同一surface/radius及hand、aim、length，在0处分层；实际尾端和前端封口，内部接缝不封口；跨0的缠线以原线性斜率切分；REAR提前返回避免护手和枪尖重复。后柄在双向骑手局部坐标绘制后立即恢复torso_transform，再画颈领脸盔。残柄适用同分层，前段尖端及碰撞模型未改。静态复核不能证明视觉已解决，仍需修复后图确认脸前遮挡消失、握柄无裂缝、正常横胸后柄保留。

### 高领及修复后实际渲染复核

`manual01/pose_009`与`010`及JSON为`fr_helmet_0 + fr_armor_4`高领，深肤窄长脸、受击形变0.85：009无须前倾25°，010长须后仰45°，均双向。脸、颈肤与领口连续，长须在领前；未见额外断口。010来自仍运行的修复前实例，枪柄盖脸依然可见，不能混作修复后证据。

独立查看root运行取得的`layer01`四张新GPU渲染页（本代理没有执行引擎）：

| 图 | 独立目视结论 |
| --- | --- |
| `back_lean_whole.png` | 铁帽和鼻铁盔，双向中立、半后仰、极限后仰；后柄横胸保留，原脸前横穿段由脸、颈或盔正常遮挡；握柄处未见新黑端帽/断缝 |
| `back_lean_broken.png` | 相同姿态下残柄连续，后柄遮挡与完整枪一致，没有整条后柄消失 |
| `back_lean_aim_extremes.png` | 极限后仰下枪角-0.68、0.12、0.58；头轮廓之外的后柄照常延伸，脸前覆盖不再复现 |
| `released_whole_and_broken.png` | 竞技/实战、双向、完整/断枪的独立枪显示都保留后柄；完整枪尖形态仍分别为冠头和尖头 |

这些固定姿态的实际生产渲染证据支持关闭本轮确认的后柄盖脸问题；不是自由下落时序、碰撞、实战连续运动或所有装备组合的证明。就已列出的新脸/开放盔/高领/双向极限样本，没有另一个需要阻断交付的头颈连接缺陷。美术自然程度仍由用户试玩判断，不由测试数量代替。

## 退出警告的独立静态追踪（待定位）

root报告并在`logs/v055/desktop03.log`看到：实际v0.4.15竞技三轮（第三轮KO）、回营地、改方颌保存、再次进入/取消、保存退出后出现`ObjectDB instances leaked at exit`。同包直接进菜单退出的desktop04 verbose及独立角色UI回归face-exit01日志未复现。警告是真实未关闭事项，不能因退出码0或另一条短路径没有警告而忽略。

只读追踪结果：

- `main.gd`角色选项回调捕获的是字段字符串；`_clear_screen`对旧screen/preview执行queue_free，释放角色页引用字典。未发现把角色Canvas/OptionButton存进长期RefCounted字典的闭环。
- `_close_battle`对Battle remove_child后queue_free；world/effects及FallenRider均为子节点。FallenRider释放的loose_lance加入effects父节点，仍在Battle子树，不是脱离场景的孤立节点。
- `JoustMatch`为RefCounted，但fighters、events、result及姿态字典中未发现回指Model或场景所有者；FallenRider的fighter/initial_pose等是值副本。
- `ImpactFX.fall`的landed匿名回调捕获rider，但rider为随父树显式销毁的Node；仅凭捕获Node不能断言RefCounted循环。需要verbose具体泄漏对象支持。
- 声音Battle `_exit_tree`会stop并清wind.stream，SoundBank `stop_all`会停止music/voices并清各stream；静态shared_streams是应用缓存，菜单路径同样加载，暂不能归因为泄漏。

应由root的verbose最小复现按泄漏对象类型继续定位：AudioStreamPlayback类优先查声音退出；GDScriptFunctionState优先查外部QA观察器F8的`await RenderingServer.frame_post_draw`是否在退出时未完成；具体Node/FallenRider类检查树归属和延迟free队列。以上均为候选分支，尚无证据确认根因。此代理未修改生产、未执行引擎，不建议在无对象证据前盲加free/全局清缓存或吞掉警告。

### 音频对象证据收窄

root的`exit-smoke01.log`完整双模式自动回归复现两个AudioStreamWAV及两个AudioStreamPlaybackWAV泄漏，未列出角色/落马Node。随后`audio-exit01.log`打印shared_streams实例ID；将lute_loop的有符号ID `-9223371989593356877`转换为uint64得到`9223372084116194739`，与该轮唯一泄漏WAV完全匹配。该轮因此锁定鲁特琴背景音资源仍被播放对象持有，不能再把角色页循环当主要根因。

核对官方4.5.1源码：Player stop清除本地播放引用，而AudioServer停止过程经混音后延迟清理；WAV playback持有基础WAV引用。建议root比较“退出前停止并禁止新播放、保持主循环跨音频清理周期”与直接quit，不重复添加已有stop。[Player停止](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/audio/audio_stream_player_internal.cpp#L252)、[AudioServer删除](https://github.com/godotengine/godot/blob/4.5.1-stable/servers/audio_server.cpp#L661)、[WAV持有关系](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/resources/audio_stream_wav.cpp#L572)。这是结合对象证据提出的生命周期假设，最终仍以对照运行结果为准。

退出树顺序是先子节点再父脚本，所以SoundBank.stop_all位于music子节点EXIT暂停之后，未找到stop被同一子节点后续EXIT覆盖的直接逻辑错序。[节点退出顺序](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/main/node.cpp#L362)。Battle新建SoundBank时先自动play随后立即stop仍值得减少，但不是已经证明的泄漏根因。

### 退出生命周期修复复核

root的audio-exit02改变Battle音乐首帧启动仍复现，相关SoundBank/Battle试改已撤回；本代理通过diff确认生产仅保留main.gd的退出生命周期修复。保存成功后先置shutting_down守卫、停主声音并清理Battle，树继续运转120ms真实时间后quit，内置smoke最终退出也复用该入口。

静态审查：保存失败仍走原失败弹窗，未置shutting_down、未停音、未卸载比赛；成功后重复WM_CLOSE/保存退出被守卫拦住；先禁主sounds再_close_battle避免顺手重启菜单音乐；close恢复暂停/时间缩放，定时器独立真实时间。初审指出仅set_process(false)不能禁止子GUI按钮，root已补`get_viewport().gui_disable_input = true`，关闭窗口前的120ms不再接受GUI触发。没有要求盲清共享资源缓存或吞日志。

独立读取`audio-exit03.log`：两次比赛进入/退出后，修复路径结束无ObjectDB警告。`audio-exit04.log`同样完成两次循环并记录`paused=true`后干净退出；当前夹具还调用两次_save_and_exit检查重复请求。它们是自动生命周期验证，不是声音质量试听；最终导出包与完整比赛复验仍由root补充，不用这两条短夹具日志替代。
