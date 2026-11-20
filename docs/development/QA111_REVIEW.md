# QA-111 Windows实际包验收（进行中）

QA-111第9项自2026-11-20 10:49:33 UTC开始，至少90分钟，最早12:19:33 UTC结束；此前UX最终a112cb3202712ab153aa67d834db2430b3e09ee3已推送并ls-remote核对。实际工作区仅原三份历史差异，无新Claude功能更改。Codex认领game/project.godot、game/export_presets.cfg、Play-Latest.cmd、launcher/发布说明与经证据需要的验包工具；game/tests/*111*、test_journey110仅隔离档路径扩展、test_parse065及直接相关实际包夹具；tools/qa111-*、docs/development/QA111_*、计划/设计/共享交接。生产战斗/动作/美术先只读，发现真实问题再追加对应文件认领并修复，不降质量/保护。GPU仍IsolatedDesktop，QA存档、1024/900MiB、500MiB系统预留、25%CPU/单实例/时限保持。新包候选v0.4.59-c1放独立目录，旧包不覆盖；全部五项后另60分钟，不能计入本项90分钟。

## 已读参考账本

| 参考 | 已读取 | 范围/未适用理由 |
| --- | --- | --- |
| C:/Users/yifei/.codex/skills/godot-qa-release/SKILL.md | 是 | 采用发布/画面/流程证据要求；项目固定Godot4.5.1，不按技能示例升级4.6 |
| references/qa-release-checklists.md | 是 | 上述技能目录；广泛QA前已读 |
| references/checklists/visual-verification.md | 是 | 实际GPU与原图；本项目已有受保护截图工具，不直接调用未隔离脚手架 |
| references/checklists/playtest-qa.md | 是 | 实际Main/Battle/结果/进度、失败重试、窗口边界 |
| references/checklists/release.md | 是 | 实际PCK、许可、ZIP迁移、入口保护 |
| skills/godot-joust-review/SKILL.md | 是 | 当前项目规则、同帧结局、有限枪盾、表现与证据界限 |
| 跨技能game-ui-quality/hud-readability/responsive-ui-fit | 否 | 当前技能目录没有这些引用文件；不伪称已读，以本项目实际窗口矩阵复核 |
| 3D/AAA/Web/mobile附加项 | 不适用 | 当前仅Windows2D；不声称AAA、跨机、真人或商店认证 |

## 顺序

1. 冻结已验证生产源码，准备.59-c1版本/独立包/玩家说明，受保护导出。
2. 资源/许可/源文件排除、实际PCK新档80关按钮成长和真实结算，保留自然失败。
3. 重装结果/重开性能、源代码UI新修复在包中的表现、旧档/坏档恢复、窗口/退出、ZIP中文空格路径和保护入口。
4. 有证据的修复单独记录并重验受影响项；本项至少90分钟结束后，另开≥60分钟不同配置/模式的综合长跑，不重复同一已过样例凑时长。

暂未导出或开始实际PCK运行；正式入口仍.58-c1。音频默认Dummy/静音，不声称硬件听感；不接管屏幕。

- 10:52 UTC：候选版本.59-c1与独立导出配置已准备；parse01受保护编译通过。test_journey110只抽出默认隔离存档前缀虚函数，UX默认路径不变；test_journey111覆盖QA111前缀并拒绝编辑器/错误包版本。外部测试脚本从文件系统加载，其res://引用来自实际PCK；运行目标/PCK SHA/源码版本写入每次target.json。原奖励/策略/AI不变。正式入口仍旧包。

- 候选源码e653fc940cf4acb1ed75e739e552cf60cec471ff；.59-c1独立导出/外层启动器/九文件清单完成，正式入口尚未切换。export01保护正常退出、采样峰620.6MiB，无SCRIPT ERROR/ERROR。bundle01由实际发布引擎/PCK读取版本、194物品、四国48盔甲/72枪、四马皮/15马衣与许可；开发/旧资源排除通过。当前开始qa111-journey01–16实际PCK自然成长长链，不把此前UX源码记录算作包验证。

- ZIP/迁移静态：qa111-package.py新建71279433字节ZIP，SHA256 511F852AF4A1AD2BB74190830B732BC5E4BDD75D474D540A54FA344251A01258，CRC与9个文件迁移散列通过；中文空格副本未运行前不标便携通过。7秒压缩与实际关卡功能测试并行，不拿这一段当帧率基准；后续性能专门串行测量。PCK38298216字节，相对.58-c1仅增加7888字节，未压低素材品质。

## 首个实际包失败：购买后测试点击过早

- qa111-journey02保留失败（退出1、隔离桌面关闭），6–10实际完成，但eng_lance_long_2购买后的装备断言两项失败；原图仍为“正在整理装备”。第10关已能装备，币款/真实首通/存档未丢失。
- qa111-shop-timing01在实际PCK以声明的交易夹具复核四件武具，详情到达97–272ms；重盾第10帧仍未就绪，第11帧可用并装备保存。没有证据支持把它当生产购买失效，原因是旧驱动把固定10帧当就绪信号。
- test_earned109驱动改为最多1秒等待实际details_ready与当前物品对应的可见按钮，排除已排队删除按钮，保留原有余额/收藏/配装/存档断言。每次等待时间记录到新journey报告，超时仍失败；没有加长引擎保护超时、删除断言或改UI分帧预算。
- 新目录qa111-journey-resume/qa_journey从journey01实际第5关final_profile精确复制，来源报告散列写入checkpoint.json。原失败流程/存档保持；journey02-retry01重新真实跑6–10，后续11–80从该新QA链继续。无捏造首通、钱、物品或胜利。代码包和PCK散列不变，仅外部QA驱动更新；新target.json记录驱动继承链散列。

- 2026-11-20 11:13 UTC QA-111检查点：实际.59-c1候选已导出/封包，源码e653fc940cf4acb1ed75e739e552cf60cec471ff，正式入口仍.58-c1。实际包1–10关通过（第6–10由第5关真实检查点重跑），原journey02十帧等待导致的两项QA失败保留；有界按钮就绪等待修正后retry01通过，账本/比分与存档一致。后续11–80及发布组合检查进行中，额外60分钟尚未开始。保护与后台隔离保持，未接管屏幕。
