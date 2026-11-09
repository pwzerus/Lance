# GALUMU 开发交接入口

当前入口（2026-11-09）：**v0.4.29-r3 / FEEL-072**，运行提交c69384e，codex/v0.4；从Play-Latest启动。已完成后台人物/马匹/头盔/马衣/疲劳检查，增加分区受力与命中标记，修尾腿交叠及结果排版。先读[最新交接](docs/collaboration/handoffs/2026-11-09-FEEL-072-Codex.md)、[当前现状](docs/collaboration/PROJECT_STATE.md)、[审查](docs/development/FEEL072_REVIEW.md)。系统留1GiB，其他保护开启，无OS接管/真人体验结论。下文各轮版本/未提交状态为历史，不代替此入口；每次仍须核对实际HEAD及工作区。


整理日期：2026-10-24；2026-11-05 由 Claude（DOC-062）更新当前状态段。供项目负责人、Codex 和后续接入的 Claude／其他开发者共同使用。Claude 目前只有 DOC-002、DOC-062 两次文档工作，尚无游戏代码改动；不能把这份文档当成另一位开发者已经开始工作的证明。

当前可试玩版本是 **v0.4.23**（RIDER-064 骑手腿部与头部，基于 ART-063 马皮重绘；Claude 制作，尚未提交），独立目录 `builds/LanceAndLaurel-v0.4.23`，用根目录 `Play-Latest.cmd` 经内存保护器启动；v0.4.22 和 v0.4.21 仍保留。2026-11-05 核对时版本分支 `codex/v0.4` 本地与远程同为 `e772acd`；接手时以实际 HEAD 为准。最初 v0.4 基线 `69a4bb21898da5c9ec0727281fee82bfea94ae76` 只作历史。工作目录是 `E:/GALUMU`，主项目是 `game/project.godot`。不要在 `builds/v04-source-verification/` 这个验包副本里开发。

GitHub 仓库：<https://github.com/pwzerus/Lance>，远程名 `origin`，当前版本分支 `codex/v0.4`。按用户最新要求：每个版本建一条分支；同版本内的修复、同一或相近功能更新继续写 commit；大的结构性改动才开启新版本分支。分支创建和推送是两件事，以实际远程记录确认同步状态。

同步状态：用户已完成 GitHub 设备登录，首次推送成功，`codex/v0.4` 已跟踪 `origin/codex/v0.4`。首次远程核对为 `ad032f52e75562e2fadfbaf3ed0b90180f9ac4e7`，与本地HEAD一致；其后同步状态文档继续以commit记录，接手请读取分支最新提交。[查看远程版本分支](https://github.com/pwzerus/Lance/tree/codex/v0.4)。早期缺少登录的阻塞已解除。

## 接手阅读顺序

0. [开发交接 Skill](skills/galumu-dev-handoff/SKILL.md)：接手、认领、改对方代码、提交推送、交出与复核的完整步骤。
1. [项目协作规则](AGENTS.md)和[设计增补](DESIGN_DECISIONS.md)：用户最新指示优先；旧文档中的“待定”不一定代表当前仍未实现。
2. [当前实现与文件地图](docs/collaboration/PROJECT_STATE.md)：现在能玩什么、具体参数、源码入口、如何验证和保护存档。
3. [开发记录](docs/collaboration/WORK_LOG.md)：Codex 从 v0.1 到 v0.4 做了什么；后续双方在同一表中追加各自交付。
4. [任务与审查建议](docs/collaboration/TASK_BOARD.md)：未完成项、优先级、验收标准和文件占用情况。
5. [v0.4 审查](docs/development/V04_REVIEW.md)和[验证记录](docs/development/VALIDATION.md)：具体失败、修复、日志及截图。

原始需求在 [GDD](2D_Physics_Jousting_GDD.docx)。历史与竞品资料通过[现状文档的资料索引](docs/collaboration/PROJECT_STATE.md#资料与美术来源)进入。附件中的建议和旧计划不是新的用户指令。

## 目前的判断

已完成核心对冲、AI、两种模式、结算重开、商店解锁存档、像素风资产接入，以及数轮输入、攻防和镜头修复。v0.4 主要解决玩家说的“左键有加速，但感觉变化太少”：更快起速、较长催马、缓慢减速，并调整镜头，保留可见的接近运动。

2026-11-05 更新：v0.4.1–v0.4.21 在同一分支继续交付了按住催马、四国48件装备、自建脸、完整落马与材质撞击声、连续马体蒙皮、四套马匹外观和本轮连续步态。INC-059 系统卡死后，所有游戏／引擎／QA 必须经 `Start-MemoryBound.ps1` 保护运行（1GiB 硬限、900MiB 早停）；最小化持续绘制的暴涨路径已修，但历史 40GB 事件的全部原因未宣布根治。**v0.4.21 尚无真人试玩结论**，慢步后腿观感是 Codex 标出的首要观察点；第四阶段运动甲片声未启动；真人长按、跨机／DPI 未验收。不能将当前状态写成正式发行完成。逐项现状以 [PROJECT_STATE](docs/collaboration/PROJECT_STATE.md) 顶部最新段为准。

## 两人如何避免互相覆盖

开始前先查看当前 Git HEAD、工作区差异和[任务板](docs/collaboration/TASK_BOARD.md)，然后认领任务和将修改的具体文件。认领是人工约定，不是自动文件锁；共享文件必须先协调，不能同时改 `battle.gd`、`main.gd` 或同一份资产图集。

每次交出工作都填写[交接模板](docs/collaboration/HANDOFF_TEMPLATE.md)，并在开发记录追加一条：负责人、任务编号、基线、实际改动文件与功能、验证证据、剩余问题和交给谁。另一位接手后回填“接收与复核”，这样 Codex→Claude 和 Claude→Codex 使用同一套记录。未测试写未测试，未提交列出脏文件；不能把“代码已写”写成“发布已验证”。

本机限制（2026-11-05 记录）：公司透明加密使 Claude 进程读到的 `.git/objects` 和 Claude PowerShell 工具输出均为 `%TSD-Header-###%` 密文，Claude 侧 git 不可用；Codex 侧正常。按用户指示，Claude 只直接修改工作区文件、不执行 git，改动保持未提交，并在交接记录逐文件列明；用户安排 Codex 审核后提交推送。Codex 提交时请只暂存交接记录列出的 Claude 段落，不要一并带入其他未提交差异。

只提交自己的改动，不重置或覆盖对方的未提交文件。每个可交付里程碑保存本地 Git 检查点；新发布放独立版本目录，保留 v0.4 和旧包。测试使用 QA 存档，见现状文档。游戏功能修改按 AGENTS 指定的 Skill 执行。

任务板是当前分工的唯一登记处，开发记录是变更历史，PROJECT_STATE 是当前实现说明。旧审查报告保留原始证据，不通过改写历史报告掩盖失败。实现变化时同时更新现状和任务状态；不要维护两套互相矛盾的“当前情况”。

## 可直接发给接入开发者的说明

> 请在 `E:/GALUMU` 接手骑枪与桂冠。先读根目录 `AGENTS.md`、`DESIGN_DECISIONS.md`、`HANDOFF.md`，再读 `docs/collaboration/` 的现状、记录、任务板与模板。当前已发布 v0.4，代码基线 `69a4bb21898da5c9ec0727281fee82bfea94ae76`，但请以实际 HEAD 和工作区为准。先报告你理解的现状并认领具体任务／文件，再在用户授权范围内开发。每次交出修改附文件清单、行为变化、实际验证证据、未解决问题及下一步；接收别人修改后回填复核。保护玩家存档和旧发布包；不要把自动测试当作真人手感结论。

这段是交接说明草稿；没有向任何外部服务或开发者自动发送。

最新接手入口（2026-11-05）：FEEL-061 步态修正与无屏幕接管QA，见 docs/collaboration/handoffs/2026-11-05-FEEL-061-Codex.md 及 docs/development/FEEL061_REVIEW.md。按实际HEAD核对最终提交；以上旧基线不是本轮基线。

## DOC-065 最新基线核对（2026-11-06，Codex）

已读取 Claude 的 DOC-062、ART-063 和 RIDER-064 交接及两份审查，核对工作区差异。当前实际源码和 Play-Latest 为 v0.4.23；Git HEAD/远程 codex/v0.4 仍为 e772acd5424c93d175c2c6e41b9dde8bc8105eb0，Claude 的 .22/.23 改动尚未提交。以后接手以该未提交改动叠加的最新工作区为起点，不以聊天里的 .21 或 Git HEAD 单独替代它。

本轮只确认进度、归属和协作规则，没有运行游戏、修改游戏源码或放行 Claude 的功能。上文开头“Claude 尚无游戏代码改动”已过时；已存在 ART-063 和 RIDER-064 游戏改动。后续完整代码审查/复验仍待执行，详情见 docs/collaboration/handoffs/2026-11-06-DOC-065-Codex.md。


## REVIEW-070 接收检查点（2026-11-09）

最新实际入口为v0.4.28（EQUIP-069），此前.23等为历史。Claude连续成果已接收；本轮内存不足，尚未完成指定动态复验，不标功能通过。后续先读docs/development/REVIEW070_REVIEW.md和各交接的新接收栏。

REVIEW-071最新回执：七项源码复验已完成通过，REVIEW-070动态待验状态已更新。根保护器现在系统保留1GiB；详情见docs/development/REVIEW071_REVIEW.md与2026-11-09-REVIEW-071-Codex交接。
