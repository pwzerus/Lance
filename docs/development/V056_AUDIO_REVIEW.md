# DEV-056 接触声音诊断与交接

负责人 sound056；基线 11b9b1c。只持有 sound_bank、新 impact_v056 资产、生成工具、本次音频夹具与本文。不启动 Godot 或桌面，不改 battle/main，不提交 Git。运行证据由 root 补充，不能把生成成功写成游戏播放验收。

## 诊断

v050 的主能量来自56–192Hz的少数低音模态；头盔/胸板/木盾的大部分可辨音色依赖很轻、很快衰减的高模态和高通噪声。读取旧原始PCM得到的前16384采样Hann分析重心，头盔约91Hz、胸板69Hz、盾118Hz。这个结果支持“在低音不足的播放设备上，载荷与材质主体会弱”的推断，并不是硬件听音实测。真正命中已正确排队到首个可见帧，没有证据表明需要改碰撞触发。

## 当前改法

- 沿用39 cue、三变体、实材质路由、擦击/断枪分离、预加载、有限声池、接触组预算、暂停和退出清理。
- 新原创程序素材包含带限受力噪声、非谐波壳体/板体短模态、独立表面瞬态。头盔更紧实偏中频；胸甲有较低且宽的受力/板体形变；木盾为短木腔和受压纤维。锁甲/布垫/布面甲仍各用相符纹理，不都强行变成钢板。
- 同一输入力度下单独接触增益从 -12…-5dB 改为 -11.5…-2.5dB，擦击额外减2.2dB；音色改变是主项，增益只是让独立重击有混音位置。原0.78分组预算及重采样余量保留，不能把这个预算叫作整个Master绝不削波。
- 静态追踪另发现只有风声被接触包络压低，旧/新落蹄声仍抢占瞬态。新增set_movement_duck(amount)仅按既有包络衰减蹄声，最多18dB；保存每声原始增益，重复设置不累积，回0恢复，音高/落蹄时序不变，contact组不受此衰减。Battle接入由root持有文件完成。专项测试覆盖已有/新蹄声、重复设置、回0、contact不受影响及暂停/静音不重启。
- 使用固定种子的标准库Python离线生成，最终16位PCM峰值回写CONTACT_PEAKS，导入明确无压缩、不归一化、不裁切。不在实际命中帧合成或读文件。旧impact_v050保留。

## 本机写入兼容问题

系统Python写入一度产生`%TSD-Header`封装，普通文件API不能读取；已将仅本轮生成内容用正常文件写入重新落地，未改系统加密/安全设置，未改旧资产。推荐入口`game/tools/build_impact_audio_v056.ps1 -WriteBank`包含这一受限输出范围的处理和39个RIFF头复查；源码文本后续编辑使用apply_patch。生成器在无该软件的环境也能直接使用Python。

## 证据与边界

本轮资产分析/同数字增益旧新对照/峰值匹配旧新对照在`docs/development/audio/v056/`；顺序在asset-analysis.json内。峰值匹配对照用于将纹理差别与音量变化分开。分析不是LUFS、人耳评分、笔记本扬声器试听或录制材质证明。真实引擎导入、完整混音听感、同帧双击/断枪/暂停和退出结果待主负责人执行。

生成39个原始WAV，写入PCM的削波样本数为0，solid峰值0.63–0.68，glance为相应峰值的0.57，断枪峰值0.57。三种主材质的初版实测中频/峰值比：helmet 0.1225→0.1628，plate 0.1067→0.1823，shield_wood 0.1405→0.1590（第一变体、前120ms）。Hann分析中头盔中频约79%、胸板约59%、木盾约51%；描述数字不用于证明“声音已经好听”。木盾含短纤维纹理，锁甲/布面甲含更明显高频小件响动；都未加入骑乘甲片运动声。

主负责人已报告import01成功导入39个新WAV，无解析错误。专用验证入口`res://tests/test_impact_audio_v056.gd`继承v050的真实PCM/选音/分组/声音池和暂停测试，增加实际PCK新目录及旧新峰值匹配能量比较；必须`-- --test-profile --report-path=<新路径> --audio-dir=<新目录>`。可先Dummy再默认WASAPI，仅进程内静音，不能用它作耳听结论。脚本保留退出音频清理的真实时间等待，尚未由本子代理运行。

参考：[Audient频段平衡说明](https://audient.com/tutorial/how-to-manage-low-mid-and-high-frequencies-in-the-mix/)解释低频重量、中频主体和高频存在感，以及频段遮蔽。对本游戏的具体模态、阻尼、增益选择属于设计推断。参阅[Chuck Russom的God of War原始访谈](https://designingsound.org/2010/04/13/chuck-russom-special-god-of-war-i-ii-exclusive-interview/)关于声音实施与动作标记配合；没有使用其游戏声音或声称复制内部配方。

## audio02 与 Battle 接入复核（2026-11-02 EST）

sound056只读检查root执行的`logs/v056/audio02.json/.log`及当前Battle/Exchange/main，不另外运行引擎或桌面，不修改生产文件。此段是对集成和已产生证据的复核，不是独立人耳试听。

- audio02明确WASAPI、48kHz设备混音，passed=true、failures为空；39个新资产均通过原PCM、精确峰值、选择不改规则和预烘焙来源检查。初始化约563ms包含原菜单等声音准备，不能当作整游戏启动速度。
- 实际旧/新蹄声衰减、重复设置不累积、归零恢复、contact不降、音高不变、暂停和关闭声音不重新播放的检查通过。连续两批真实播放声的接触组保守峰值和约0.779999999，仍在原0.78预算内。
- WASAPI暂停后记录有约11.6ms的缓冲粒度推进，恢复后继续向前，不是绝对采样级停表；符合原测试容差，不能写“暂停时零采样推进”。本次日志未见脚本错误或ObjectDB退出警告。
- Battle在`_advance_exchange`更新实际包络后，先调用`set_movement_duck`，再执行接触组限幅/播放。已有蹄声被同帧调整；随后发生的新落蹄也用当前衰减。没有把音效提前到预测相撞点，原首个可见命中帧预算保留。
- 暂停分支不推进包络，声音播放器与wind一起暂停，恢复重设视觉真实时钟；下一轮ready/turn使Exchange归零，Battle下一次_process恢复各蹄声原db。旧元数据不会因声音池复用而污染contact，因为play每次都覆盖cue和base_db。
- 场景退出停止wind并清stream，sound.stop_all清声音引用和movement_duck；main仍保留120ms真实退出清理及重复退出守卫。新duck是纯数值元数据，没有引入持有音频资源的新引用。

上述范围没有发现确定的P1/P2混音或生命周期故障。剩余边界：0.78是contact组的保守峰值和，不是整个Master输出测量；wind/hoof/菜单音和实际硬件仍未做总线录音/人耳接受度验收。近身/受击下的主观响度、金属质感以及木盾是否足够有重量，需要玩家试听，不以能量比或测试数量证明。最终PCK须重复运行新音频夹具；该次源码证据不能替代发布包身份核对。

## 实际 Master 混音录制夹具（待 root 运行）

新增自包含 `game/tests/test_contact_mix_v056.gd`，隔离QA入口 `--script res://tests/test_contact_mix_v056.gd -- --test-profile --run-dir=<不存在的绝对目录>`。现有目录即拒绝运行；输出每例WAV及report.json，不覆盖既有证据。发布包若排除tests，可用外部脚本绝对路径运行；其生产preload仍必须从该PCK读取。另将test_impact_audio_v056的旧夹具基类改为相对路径，使外部发布验证能找到同目录的v050测试。

夹具使用实际SoundBank、Exchange包络、同帧接触组预算和池；录制有风声/近远蹄声的头盔、胸板、木盾，双命中双断枪与胜负UI同帧边界，以及相隔65ms的两批接触+click。UI同帧属于明确的压力安排，不能说真实比赛必然这样播放。首个接触帧使用0时间推进，后续使用真实时钟恢复duck。没有改碰撞结果或生产增益。

依据[AudioEffectRecord文档](https://docs.godotengine.org/en/4.5/classes/class_audioeffectrecord.html)及[Godot 4.5.1音频服务源码](https://github.com/godotengine/godot/blob/4.5.1-stable/servers/audio_server.cpp#L507-L570)，Master效果处理先于最终mute/音量阶段；夹具在Master最后加入录制效果，并将Master最终mute。它要求录音实际非静音、mute后电平表保持静音，二者都成立才验证这个安排。录制结束把真实写出的RIFF/PCM重新读取，输出声道峰值、RMS、近满幅及削波样本数；退出移除临时效果并恢复总线状态，不改系统音量或音频布局文件。

这新增的是实际混音采样证据，不是分组保守上界，也不是麦克风/扬声器录制、人耳评价、LUFS、真峰值认证或全部可能游戏混音的证明。脚本完成静态复核；引擎结果待root执行后填写。

## master_mix01 录音独立复核与跨场景检查

root随后执行`docs/development/logs/v056/master_mix01/report.json`，结果WASAPI、48kHz、passed=true。sound056未再运行引擎，使用独立Node文件解析重新读取该目录7个WAV的RIFF块和全部16位PCM采样，并核对SHA256、帧数、峰值、RMS：均与报告一致（RMS浮点差小于5e-17）。这是对落盘证据的独立复算，不能改称为另一轮引擎运行。

| 录制场景 | PCM峰值 | 峰值dBFS |
| --- | ---: | ---: |
| mute前录制探针 | 0.180328 | -14.879 |
| 头盔+风/蹄 | 0.487976 | -6.232 |
| 胸板+风/蹄 | 0.515961 | -5.748 |
| 木盾+风/蹄 | 0.356171 | -8.967 |
| 双击/双断枪+胜利UI边界 | 0.546875 | -5.242 |
| 双击/双断枪+失败UI边界 | 0.411285 | -7.717 |
| 延迟第二批接触+click | 0.517395 | -5.724 |

7个文件均为48kHz/16位双声道；实际左右PCM完全相同，当前夹具没有空间声像差异。按夹具定义的满幅样本（绝对整数值≥32766）和近满幅样本（幅度≥0.98）都为0。录音非静音，所有录制期的mute后Master最大电平约-200dB，支持“效果链录到了mute前数据、最终输出静音”的实际结果。最大峰值只适用于这7个安排，不外推任意未来素材/混音/硬件系统音量。

追加只读检查Battle完整蹄声/风声生命周期、main菜单/重开/退出和GameState设置路径，未发现本次movement_duck造成的跨场景恢复缺陷：

- 蹄声只在charge且未暂停的落蹄信号上播放，使用现有速度增益与前后腿音高。duck仅是每个SoundBank实例和每个voice上的数值；共享静态字典只保存音频流，不保存duck或播放器增益。新Battle新建SoundBank，初始duck为0。
- 接触后同一Battle仍逐帧推进Exchange；ready/turn或新pass重置包络，下个_process重算蹄声原db，不会累计衰减。结束表现继续推进包络；结果UI使用main独立SoundBank，不会继承战斗蹄声duck。
- 暂停对wind、SoundBank和Exchange一起暂停；恢复沿用剩余包络并重置真实时间起点。暂停返回营地/重开经main.remove_child立即触发Battle退出，停止wind并清stream、stop_all清所有声流及duck；队列释放后新Battle不复用这些voice。
- 当前“音乐与音效”开关在营地设置页，回营地前Battle已经关闭。菜单开关及读取存档同步main音频；下一局从GameState重新读取enabled，false时wind不会启动，SoundBank.play拒绝播放。GameState本身仅改数据并发profile_changed，Battle不监听该信号；若以后增加战斗中切换声音的UI，需显式同步Battle sound及独立wind，不能只调用GameState.set_setting。当前暂停页没有该声音开关，所以这属于未来接入注意事项，不是现有玩家可触发回归。
- 应用退出先禁用main声音、stop_all，再关闭Battle；main仍等待120ms真实时间清理。只改set_movement_duck没有新增静态状态、音频资源持有或退出重启路径。

本次实际录音填补了上述“未做Master录音”的部分边界；仍未有人耳接受度验收，也不能以数值证明撞击足够重、三种材质听起来足够明显。发布PCK身份及最终发布回归由root记录。
