# GALUMU 项目协作

用户最新指示优先于 GDD 和技能。改游戏前读取 DESIGN_DECISIONS.md 中相关增补。动作与镜头任务使用 skills/joust-game-feel/SKILL.md；美术任务使用 skills/jousting-pixel-art/SKILL.md；里程碑验证使用 skills/godot-joust-review/SKILL.md。

维护 Godot 4.5.1 + GDScript 的 Windows 项目。使用隔离 QA 存档跑测试，保护玩家正式存档。不要覆盖上一版可运行发布包；新版本放入独立 builds 子目录。以引擎实际导入、运行及渲染证据报告验证范围。

玩家体验里程碑使用 skills/game-experience-critic/SKILL.md，区分玩家实际试玩、桌面输入、自动注入和规则模拟证据，不以测试断言数证明游戏好玩。

接手先读 HANDOFF.md 和 docs/collaboration/。开始修改前在 TASK_BOARD.md 登记任务与具体文件；交出修改时用 HANDOFF_TEMPLATE.md 记录功能、文件、基线、验证证据和剩余问题，更新 WORK_LOG.md 与 PROJECT_STATE.md。共享文件一次只由一位负责人修改，不覆盖对方未提交改动。

GitHub 仓库为 https://github.com/pwzerus/Lance，远程名 origin。每个版本使用一条 codex/vX.Y 分支；同版本修复、同一或相近功能在该分支内逐项 commit，不为小改动另开分支。大的结构性改动形成下一版本后再开新版本分支。里程碑提交后推送当前版本分支并核对远程 SHA；不 force push，不覆盖旧发布包。当前版本为 codex/v0.4。
