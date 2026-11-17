# 交接：BALANCE-103 第24关与周边难度过渡

- 日期／时区：2026-11-17，美国纽约；交出者Codex；接收者待后续开发者。
- 用户授权：把第24关和前后几关调顺，保留高低枪、前期简单，后台保护验证、独立导出、提交推送。
- 开始基线：codex/v0.4，c7028aa08a7ccf03627aec5baabda6bde411844b，ls-remote相同。
- 版本／源码：v0.4.55-c1，运行源码1a5d0461630315b25d6d2eb8d63af7c79ed43662。完整交付ec267823190892025df0845edb885b7a2e4aced2已推送并以ls-remote核对，详见下方回执。
- 保留历史差异：docs/development/V051_EXPERIENCE_REVIEW.md、V051_HISTORY_REVIEW.md、game/tests/rules_v045_results.json，另有build_queue.gd.uid及旧QA/UID；未reset/stash/pull或混入本轮提交。

## 实际改动与诊断

20冠军和23/24普通对手重复了重甲、粗枪、稳马的整套组合，21开始每轮变线，23再全套升级；慢输入代理即使护住身体也经常被两三次盾心承压击落。只削武器档次、只减少变线轮次都不足，最终同时调整装备进入节奏、对手组合和实际催马/收缰决策；统一伤害、双方物理与装备物品数值保持。

| 文件／接口 | 修改 |
| --- | --- |
| core/campaign.gd | 24改为均衡骑士，隔开连续重甲；18–30装备分阶段；18–28共同教习冲锋节奏，29–39缓慢退去；21–24仅第二轮变线、25–28第二/三轮，后续恢复原每轮一次；章节和对策说明同步 |
| core/opponent_ai.gd | 可选lesson_change_passes与pressure_ease，继续使用set_controls和已有催马滞回；观察延迟、定线和枪盾速度不变 |
| tests/test_curve103.gd | 同玩家套装/种子/侧向/输入节奏，逐关完整比赛、命中/落马与策略对照；中间失败保留 |
| tests/test_rules103.gd | 范围外旧源码等价、奖励/赛制/物品、54次实际接近中的高低变化/延迟/枪盾连续性 |
| tests/test_scene103.gd | 正常Main关卡、600ms引擎输入、GPU截图、结算/奖励/QA磁盘存档 |
| main.gd、ui/combat_status098.gd、test_result_text103.gd | 改善小字可读性：面板局部线性过滤、历史命中共享500字重。疑似动态丢字经原始PNG的45帧字形掩码核对未证实，预览误判已纠正。世界像素过滤保持 |
| tests/test_lesson_scene102.gd、test_parse065.gd | 旧GPU夹具按实际可变线轮次验收，编译登记新测试 |
| 版本/导出/入口、设计/共享记录 | 新包另目录，不覆盖.54-c1或玩家正式档 |

本次第24关对手称号随类型改变，地区、关卡ID、奖励/收藏/解锁保持。1–17尤其前五关和40–80的配置与实际短段AI与旧源码比较；自由AI没有这些可选配置时行为不变。不把降低难度做成玩家隐藏增伤或敌人隐藏减伤。

## 设计与验证范围

用户允许普通实现自行决定。这是游戏难度设计，不添加历史真实性结论。设计决定记DESIGN_DECISIONS；真实失败/中间曲线见BALANCE103_REVIEW，紧凑证据由collect_balance103_evidence.py生成，原始logs/balance103-*留本地。

全程后台、Start-MemoryBound、--test-profile，GPU使用-IsolatedDesktop。headless512MiB/448MiB早停，GPU/导入/导出1GiB/900MiB；CPU25%、500MiB系统保留、单实例、启动预算和超时保护保持。未接管屏幕、切桌面、操作真实鼠标键盘或正式存档。测试的QA路径为GameState默认qa_或报告目录下qa_profile.json。

| 验证类别 | 实际结果 | 证据／限制 |
| --- | --- | --- |
| 规则模拟基线/迭代 | 已测原40场、首改40场、降速20场、中间宽范围136场、盾心/胸部20场、再次降速20场 | 多轮未达到目标的结果不隐去；final.json只是中间批次，最终应看release.json |
| 最终规则与输入 | 84场完整比赛、16场固定护胸对照、54次AI接近、12场初始套装新手、controls098和编译通过 | 代理不等于真人胜率；原final.json为中间失败方案，最终为release.json |
| GPU源码 | 完整23/24/25关、奖励和QA保存通过；发现结算小字问题后另做3次正常配置短结算复验 | 缩短夹具只验证显示，不代表比赛；源报告通过不覆盖随后发现的视觉问题 |
| 实际包 | 导出/保护入口/9文件完整性及23/24/25、1/3关完整GPU对局、奖励/保存/退出通过 | 实际PCK，峰731.3MiB，无OS输入/真人验收 |
| OS输入／真人试玩 | 未执行 | 不保证所有玩家与所有装备都适合，也不宣称已通过真人手感验收 |

QA比较旧关卡前，需从c7028aa基线按原字节恢复campaign.gd和opponent_ai.gd到docs/development/logs/balance103-old-campaign.gd、balance103-old-opponent_ai.gd，或用测试的--old-campaign/--old-ai传入对应路径。它们不是生产依赖，不进入PCK。所有测试串行启动并等引擎退出。

## 剩余问题与下一步

PERF-099原约94ms长帧仍未精确归因，本次仅处理结算文字采样，不声称解决性能尖峰。固定品质1套装的31/34/35/40关仍困难；需要用适配装备和真人反馈单独校准后段，不能称80关全已平衡。接手先读BALANCE103_REVIEW/EVIDENCE，核对实际HEAD与工作区，不复原旧版本。本轮文件认领全部释放；包与验证如下，提交推送回执在最后追加。

## 最终交付与复验入口

- 包：builds/LanceAndLaurel-v0.4.55-c1，PCK 38,122,748字节、SHA256 `5B71E24E77A64E0B2EDF215E9C78C95DCBCD659DC8CE994081090EEA7AFD4E4F`；源码1a5d046。Play-Latest已指向外层受保护EXE。旧包不覆盖，正式档未触碰。
- 实包GPU：test_scene103（23/24/25，190.5秒，峰731.3MiB）、test_beginner_ui100（1/3，125秒，峰691.9MiB），全部正常退出、隔离桌面关闭，未测真人/真实OS输入/硬件听感。最终证据BALANCE103_EVIDENCE.json；两份代表截图screenshots/balance103，原始日志仍在logs/balance103-*。
- GPU复验：Start-MemoryBound.ps1 -Executable <新包>/runtime/LanceAndLaurel.exe -IsolatedDesktop -TimeoutSeconds 400 -MemoryLog <新日志>，Arguments使用--path <新包>/runtime --script E:/GALUMU/game/tests/test_scene103.gd --log-file <新引擎日志> -- --test-profile --folder=<不存在的新QA目录>。新手同法替换test_beginner_ui100.gd。所有引擎串行、保护保持。
- 追加诊断test_result_text103支持--fixture=<实际scene103报告>，重放真实命中但缩短比赛等待，不算游戏规则证据；msdf/material等开关只用于诊断，不进入生产改动。原始像素45帧核对纠正预览误判，完整过程见审查。
- 共享HANDOFF/WORK_LOG/PROJECT_STATE/TASK_BOARD已更新，认领释放。只剩三份已知历史未提交差异及既存QA/UID，不混入本轮提交。远程只同步源码与文档，不声称上传了EXE Release。

## 推送回执

完整交付ec267823190892025df0845edb885b7a2e4aced2已推送origin codex/v0.4，并以ls-remote核对相同。运行源码1a5d046与实际复验的.55-c1包不变；本回执另作小型文档提交并推送。未上传EXE Release，保留本地旧包与正式档。

## 接收与复核（接收者追加）

- 接收者／日期：Codex，2026-11-17，FIX-104。
- 实际分支／SHA：codex/v0.4 / ea6506fcc45698302bcd74356f753356babb00dc，origin一致；保留历史工作区差异。
- 已读证据、执行复验与接受部分：读取BALANCE103审查/交接/状态与实际实现；接受已交付难度调整，本轮不重新宣称84场已复跑。实际复验转向用户指出的第二关持枪臂和败北画面，使用真实第二关装备与后台GPU；控制/落马/结算证据见FIX104交接。
- 新问题／下一步认领：FIX-104修复远侧持枪臂、整人alpha裁切消失、缩短KO特写；不改关卡AI或数值。
