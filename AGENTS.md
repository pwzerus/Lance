# GALUMU 项目协作

用户最新指示优先于 GDD 和技能。改游戏前读取 DESIGN_DECISIONS.md 中相关增补。动作与镜头任务使用 skills/joust-game-feel/SKILL.md；美术任务使用 skills/jousting-pixel-art/SKILL.md；里程碑验证使用 skills/godot-joust-review/SKILL.md。

维护 Godot 4.5.1 + GDScript 的 Windows 项目。使用隔离 QA 存档跑测试，保护玩家正式存档。不要覆盖上一版可运行发布包；新版本放入独立 builds 子目录。以引擎实际导入、运行及渲染证据报告验证范围。

玩家体验里程碑使用 skills/game-experience-critic/SKILL.md，区分玩家实际试玩、桌面输入、自动注入和规则模拟证据，不以测试断言数证明游戏好玩。

接手先读 HANDOFF.md 和 docs/collaboration/。开始修改前在 TASK_BOARD.md 登记任务与具体文件；交出修改时用 HANDOFF_TEMPLATE.md 记录功能、文件、基线、验证证据和剩余问题，更新 WORK_LOG.md 与 PROJECT_STATE.md。共享文件一次只由一位负责人修改，不覆盖对方未提交改动。

GitHub 仓库为 https://github.com/pwzerus/Lance，远程名 origin。每个版本使用一条 codex/vX.Y 分支；同版本修复、同一或相近功能在该分支内逐项 commit，不为小改动另开分支。大的结构性改动形成下一版本后再开新版本分支。里程碑提交后推送当前版本分支并核对远程 SHA；不 force push，不覆盖旧发布包。当前版本为 codex/v0.4。

## DOC-065：以实际最新工作区接手（2026-11-06）

每次开始任务，尤其用户告知 Claude 有新改动时，先核对分支、HEAD、远程状态、已跟踪文件差异和新增文件；读取最新交接、WORK_LOG、PROJECT_STATE、相关审查及运行日志，再阅读涉及功能的实际实现。未收到自动反馈不代表没有更新；Claude 可能只改本地而未提交，不能只看 git log 或聊天里记住的 Codex 版本。

开发基线由“实际 HEAD + 已确认归属的未提交工作区改动”共同组成。版本号和文件时间只是线索；源码、资源、启动器和交接须互相核对。后续在该基线上修改，不恢复旧快照，不用旧源码覆盖新实现，也不自动 pull/reset/stash 清理对方成果。归属已由用户或交接确认的改动直接保留；只有真实冲突或归属不明才协调。

开工时简要说明接手版本、Claude 最近改了什么、哪些尚未提交/复验以及本轮范围。缺失日志时从 diff 和实际文件恢复进度，明确证据缺口；读取记录不等于测试通过或审核放行。此核对在每次接手时执行，不承诺两次对话之间持续监听 Claude。
