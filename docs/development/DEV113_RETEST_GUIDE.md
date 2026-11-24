# DEV-113 复验入口与证据边界

当前候选为`builds/LanceAndLaurel-v0.4.60-c3`，运行源码`76746a5276ab18810f02ac41ff7f309785ada74a`。默认入口尚待本轮收尾切换；以最终交接为准。不要覆盖已有证据目录或旧发布包。

## 玩家观察顺序

1. 从最外层保护启动器进入练习场。默认界面应简洁；在设置或暂停中开启“详细战斗信息”后才出现数字，再关闭应恢复简洁。
2. 比较胸击、腹击与头击：观察脱离马鞍、身体转动、手臂/双腿滞后及触地后屈曲，而不只看震屏。靴尖应不穿入地面，身体不因第一只脚落地就整体停止。
3. 比较能继续作战的受伤、马上失去意识、实际落马和实战阵亡。结算应说明实际原因；生命尚存可因受力失衡落马，低生命擦碰不应自动高抛。
4. 高速下短暂修正后回正应可恢复；持续大幅急摆会出现失稳，越过支撑边缘才滑脱。不要把任意一次倾身都理解成落马条件。
5. 比较同档轻重盾、盾心与盾缘。轻盾重击破损更快，碎裂后手上残块不再挡枪；强弱命中与结果应能对应。

以上真人自然度/听感尚未执行。后台引擎输入与规则证据详见DEV113_ACCEPTANCE.md，不应冒充玩家评价。

## 开发复验

保持Godot4.5.1、现有1024MiB进程组/900MiB早停/500MiB系统余量、CPU25%、单实例保护。GPU必须IsolatedDesktop，QA档和`--test-profile`。`tools/dev113-run.ps1`拒绝重复目录，新的验证应使用新的Name。

- 实际包：`-Target bundle -Bundle <完整新包路径>`，脚本从工作区读取，`res://`从PCK读取。每轮target.json记录PCK、源码和外部驱动散列。
- 状态与支撑：test_condition113、test_terminal113。终局输入按每次physics_frame调度，截图异步读取不能替代实际模拟时间。
- 落地：test_articulation113、test_boot113；test_fall_fuzz105覆盖极端姿势与`--broken-shield`，test_fall_v057比较步长/血腥开关，test_release105核对脱手速度。
- 实际对局：test_cinema099、test_motion105、profile_result099；后者采用正常Main结算/保存/重开，记录帧时间、资源和真实接触，不注入伤害。
- 完整成长：tools/dev113-journey.ps1。仅使用dev113-campaign/qa_journey隔离目录，通过正常奖励购买和解锁，失败不得赠送通关或金币。
- 连续配置：tools/dev113-soak.ps1八种有限配置，每种360秒、串行；不可称为同一个进程连续48分钟。
- 独立核账：tools/dev113-flow-evidence.py只读实际成长/连续对局报告，复算奖励、购买、每击得分、跨进程档案和配置；缺项显示未完成。--write仅写本轮证据汇总，不运行引擎、不改QA或正式档。
- 包与保护入口：launcher/Verify-Package.ps1、Test-Portable.ps1；外层实际GPU用Invoke-Perf088.ps1并明确传入本轮Bundle，不采用其旧默认包。

## 本轮参考检查表台账

| 已读取 | 路径 | 应用及限制 |
| --- | --- | --- |
| 是 | C:/Users/yifei/.codex/skills/godot-qa-release/references/qa-release-checklists.md | 实际游戏循环、故障/恢复、画面、资源和发布核对。 |
| 是 | 同目录checklists/visual-verification.md | GPU截图、窗口缩放、文字/人物遮挡；本项目用既有受保护夹具。 |
| 是 | 同目录checklists/playtest-qa.md | 受创、失败/重开、成长、暂停、输入与结果。 |
| 是 | 同目录checklists/release.md | 导出、实包资源、保护启动、包体积、许可和已知限制。 |
| 否 | godot-game-ui-designer/references/checklists/{game-ui-quality,hud-readability,responsive-ui-fit}.md | 引用的扩展文件未安装，项目与本机相关技能路径搜索未找到；未声称已按这些缺失清单认证。使用项目HUD实际窗口/开关/可读性检查。 |

通用技能里的Godot4.6、3D、移动端建议不覆盖项目明确的Godot4.5.1/2D/Windows范围。不运行未经保护的模板命令，不用手机测试或上架认证填充本轮结果。
