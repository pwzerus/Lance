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
