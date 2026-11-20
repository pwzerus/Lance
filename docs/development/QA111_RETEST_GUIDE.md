# QA-111 复核入口

本文件说明怎样复核，不单独宣告通过。实际结果、失败与修复见QA111_REVIEW.md；所有阶段和额外一小时结束后才生成QA111_EVIDENCE.json。

## 固定目标

- 代码分支：codex/v0.4。接手仍核对实际HEAD、已知三份历史工作区差异及最新交接，不pull/reset/stash覆盖。
- 候选目录：E:/GALUMU/builds/LanceAndLaurel-v0.4.59-c1。
- 候选源码：e653fc940cf4acb1ed75e739e552cf60cec471ff；后续外部QA驱动修正不改变此PCK。
- PCK SHA256：65A6B6D8FF9C4F3B1CEA5E1FBD68E5AA2563FDD50C84870252742884FC9C539C。
- ZIP与中文空格迁移路径、散列在logs/qa111-archive01.json。不得往现有目录重新导出或改写已封包文件。

## 后台方式和边界

只经Start-MemoryBound运行，实际渲染带-IsolatedDesktop、--test-profile；保护参数保持。只允许一个引擎进程，前一项EXIT和QA_DESKTOP_CLOSED确认后再启动下一项。外层便携启动器使用--launcher-isolated和有限--launcher-timeout；不直接启动未保护的runtime EXE。

tools/qa111-run.ps1默认实际包；只有显式Target=source才使用源码引擎。每项生成新的target.json，记录实际EXE、PCK散列、源版本及外部测试继承链散列。后台注入不等于OS输入或真人试玩；Dummy/静音的声音检查不等于音箱听感。

## 各类证据

| 范围 | 入口 | 证据含义 |
| --- | --- | --- |
| 包内目录与素材 | test_bundle087.gd，指定version=0.4.59-c1 | 实际PCK的194物品、48盔甲、72骑枪、四马皮、15马衣、许可、测试/旧资源排除；不是画面验收 |
| 自然成长完整关卡 | qa111-journey.ps1 / test_journey111.gd | 从真实新档520银币开始，正常交易/结算/存档，无授予物品、强制胜利或模拟首通 |
| 发布性能 | profile_result099.gd，240秒重甲实战 | 实际Main/Battle、结果/重开、阶段帧间隔与可选trace；读回PNG发生在计时之后 |
| 结果边界 | test_result099.gd / test_result_gallery110.gd | 前者24次缩短等待的结果转换，后者历史/指定结果的UI呈现；不能当自然对局或落马动画证据 |
| 动作 | test_motion105.gd | 四马皮、双向、前后俯仰、加减速和疲劳的连续生产姿态采样与GPU图；仍非真人自然度评级 |
| 教学 | test_guide087.gd，两种输入方式 | 真实课目推进、暂停/续练、自然接触与防守，零奖励；视口和引擎输入 |
| 坏档与失败恢复 | test_save_ui087.gd | QA路径内损坏主档/备份、取消/恢复及明确两次blocked_backup失败；不可把这些预期错误删出原日志 |
| 窗口 | test_interruption105.gd / test_window087.gd | 隔离桌面中的最小化、暂停恢复、全屏/窗口大小；不切用户桌面，不声称多显示器/DPI认证 |
| 声音 | test_movement_audio106.gd | 实际包采样/材质/强度、声部池、暂停清理、骑乘甲片声；无真人听感结论 |
| 便携 | launcher/Test-Portable.ps1 / tools/outer-smoke-anim105.ps1 | 中文空格路径、PATH只保留System32、参数引用、重复启动/超时/清理及默认场景 |
| 额外综合期 | tools/qa111-integration.ps1 | 五阶段全部结束后才开，七种不同配装/模式/设置各8分钟，再加重甲全屏实战4分钟，合计至少60分钟实际对局，另做结果审查；每次有限进程，不冒称单进程连续一小时 |

## 已保留的失败和恢复链

qa111-journey02原6–10关交易驱动在固定10帧后查装备按钮，遇到分帧UI尚未就绪，产生两项断言失败。原报告、图片、存档和退出1完整保留。四武具实际PCK计时探针确认约97–272ms就绪并正常装备；修正驱动为最多一秒等待真实就绪，不改生产预算或规则。

qa111-journey02-retry01从journey01的真实final_profile精确复制到新的qa111-journey-resume/qa_journey后重跑；checkpoint.json保存来源报告散列。后续03–16继续该新链，原失败链不修改。

第15段在75关真实连输三次，正常退出且规则断言通过，但completed_requested_segment=false，只清到74关。保留这三场零奖励；qa111-journey75-defense01用原连续存档与同一合法装备、相同种子，--high-guard --low-line提前护头低攻，首场经盾面重击令对手失衡后胜利。16段从这个实际75关存档恢复默认策略，无授予奖励/装备或强制结局。规范账本采用01→02-retry01→03…15→75-defense01→16，每段初末档逐字段相等；原02单列为已诊断的早期测试失败。不可删掉failed/completed=false字段声称最初全部通过，也不能把自动策略反制当真人平衡验收。

## 接收者最后核对

读取最新handoff、QA111_REVIEW与EVIDENCE，检查阶段9和独立综合期的实际起止；核对Play-Latest实际指向、包清单、正式档只读前后散列与origin/codex/v0.4 SHA。没有实际运行证据的项保持“未验证”。另一台电脑、真实键鼠/听感、玩家难度与商业发行资格须另有真实证据。
