# ANIM-105 外部技能接入

用户要求下载游戏设计/动作、游戏测试和开发技能。2026-11-17安装4个技能到本机Codex skills，并保留此项目副本供Codex/Claude阅读。固定上游提交、路径、文件散列和授权文本见SOURCES.json及各目录UPSTREAM-LICENSE；没有执行上游脚本或安装运行依赖。

| 技能 | 本项目使用方式 |
| --- | --- |
| game-designer | 将“动作自然”拆成可观察的重心、握点、可读准备和收势；遵循其playtesting参考，区分自动代理与真人体验 |
| godot-gamedev | 现有Godot系统的归属、生命周期、时间/状态切换、最小完整修改和实际场景验证 |
| godot-qa-release | 按实际玩家流程、错误日志、非空画面、HUD、导出实包进行验收；本轮已读qa-release-checklists、visual-verification、playtest-qa、release |
| game-feel | 用事件驱动分层反馈，检查动作时间、停顿、重叠和恢复；不把通用夸张参数生搬进骑马动作 |

## 适配边界

- 用户指示、AGENTS.md、设计增补和本项目安全保护优先。默认后台IsolatedDesktop；上游“run window/ask user play”不是桌面授权，不能绕过Start-MemoryBound。所有Godot调用串行、QA档、内存/CPU/单实例/超时保护保持。
- 工程固定Godot **4.5.1** / Compatibility / Windows / GDScript。上游godot-qa-release写4.6、game-feel例子写4.7；只采用兼容的验证和动画原则，API以4.5文档/现有引擎实测为准。不得因为技能升级引擎、导入未知插件、照搬稳定版新API。
- 现有角色是程序骨架和皮肤，并非AnimationTree工程，不因通用技能推倒重做。外部godot-animation候选依赖4.7语义，未安装；选择当前工程可用的动作原则。
- 当前任务不包含手机/Web/联网、AAA/商业上线认证；上游移动/3D/场景模板/外部付费资产生成条目不适用。不为补齐技能清单扩大功能，不把参考技能当作专业从业者或真人测试。
- 新技能会在下次对话进入自动技能目录；本轮已手动读取相关内容并按此适配使用。项目原有joust-game-feel、game-experience-critic、godot-joust-review及交接规则继续有效。

参考资料目录：`docs/development/ANIM105_MOTION_REVIEW.md`。本次来源审查和不适用项必须随证据保留，不隐去失败。
