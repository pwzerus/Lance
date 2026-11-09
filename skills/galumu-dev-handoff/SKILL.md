---
name: galumu-dev-handoff
description: Run the GALUMU Codex↔Claude alternating development workflow — taking over the repo, claiming tasks and files, improving the other developer's code, committing on the version branch, handing off and reviewing the other side's handoff. Use at the start and end of every GALUMU development task, whenever taking over from or handing to Codex/Claude, and when reviewing the other developer's delivery.
---

# GALUMU 开发交接流程

项目根目录 `E:/GALUMU`。Codex 和 Claude 交替开发、互相审查同一个项目；用户是唯一的需求和授权来源。本 Skill 规定流程，事实以下列文档为准，不在这里另存一份“当前状态”：

| 文档 | 作用 |
| --- | --- |
| `HANDOFF.md` | 接手入口、当前判断、阅读顺序 |
| `docs/collaboration/PROJECT_STATE.md` | 当前实现、参数、文件地图、存档与验证命令 |
| `docs/collaboration/TASK_BOARD.md` | 唯一的任务与文件认领登记处 |
| `docs/collaboration/WORK_LOG.md` | 已经发生的变更历史 |
| `docs/collaboration/HANDOFF_TEMPLATE.md` | 交出／接收记录模板与 commit 约定 |
| `docs/collaboration/handoffs/` | 每次交接的具体记录 |
| `docs/development/VXX_REVIEW.md`、`VALIDATION.md` | 各版本审查、失败与修复证据 |

用户最新指示优先于 GDD、设计增补、任务板建议和本 Skill。

## 1. 接手

1. 核对仓库实际状态：当前分支、HEAD、工作区差异，以及 `origin/<版本分支>` 是否和本地一致。终端输出为空或乱码时，不能据此判断成功或失败；改为直接读 `.git/HEAD`、`.git/refs/heads/...`、`.git/refs/remotes/origin/...`，或用 `git ls-remote` 交叉核对。
2. 按 `HANDOFF.md` 的顺序阅读文档。只读与本次任务相关的审查和设计增补，不要把旧文档里的“待定”当成仍未实现。
3. 找到对方最近一次交接记录。如果“接收与复核”还空着，填写它：实际 SHA、读过的改动和证据、实际复验了什么或为什么没复验、发现的新问题。
4. 工作区里有对方未提交的改动时，不 reset、不 stash、不切分支，先问用户这些改动归谁。

## 2. 认领

开始修改前，在 `TASK_BOARD.md` 的“当前文件占用”表登记：任务 ID、负责人（Codex／Claude）、具体文件、开始时间、基线 SHA。没有现成 ID 时按任务板格式新建一个（如 `FEEL-02`），并写明完成标准。

- `battle.gd`、`main.gd`、`core/joust_match.gd` 和同一张图集，同一时间只能有一位负责人。
- 修改范围扩大时，先更新登记再改。
- 认领只是人工约定，不是文件锁。对方可能也在本机工作，改共享热点前再看一眼工作区。

## 3. 改对方写的功能

用户指出某个功能不好时，可以直接修改对方的代码，不用等用户批准。但要先找到原因，再在原有代码上改进，不要推倒重写：

1. 先读该功能的实现、WORK_LOG 的对应阶段、审查文档和相关测试，弄清当初为什么这样写、已经修过哪些问题。
2. 把用户的感受对应到具体代码：哪个参数、曲线、时序或表现导致了问题。写成能复述的诊断，例如“镜头缩放抵消了接近位移，所以角色主要在变大”。
3. 沿用已有的规则模型、挂点、测试和调好的参数，只改有问题的环节，保住已验证过的行为和修复。
4. 只有现有结构确实承载不了修复时才做结构替换，并在交接记录里说明为什么不能就地修。
5. 改完主动告诉用户三件事：改了什么、为什么改（诊断）、验证到哪一步。

动作与镜头任务读 `skills/joust-game-feel/SKILL.md`，美术任务读 `skills/jousting-pixel-art/SKILL.md`，里程碑审查读 `skills/godot-joust-review/SKILL.md`，玩家体验里程碑读 `skills/game-experience-critic/SKILL.md`。

## 4. 开发与验证

- 测试只用 QA 存档（`-- --test-profile`、`-- --smoke-test` 或 QA 前缀 EXE），不碰 `%APPDATA%` 下的正式玩家档。两位开发者不要同时跑同一套 QA。
- 日志和截图用新的 `$runId` 目录，保留旧证据，包括失败的证据。
- 新发布导出到新的 `builds/<版本>` 目录，先改 `export_presets.cfg` 和版本号，不重导、不覆盖旧包。
- 证据分四类，分别写，不能互相替代：规则模拟、引擎注入输入、OS 桌面输入、真人试玩。headless 启动成功不等于画面正确，断言数不等于好玩。

## 5. 提交与推送

- 每个版本一条 `codex/vX.Y` 分支。同版本内的修复和相近功能在该分支逐项 commit；大的结构性改动形成下一版本时才开新分支。分支名沿用 `codex/` 前缀，由 Claude 开发时也一样，不按开发者另开长期分支。
- 一个 commit 只表达一个能解释的变化（`fix:`、`feat:`、`docs:`），说明里写清原因、可见行为变化、已验证和未验证的内容。
- 只暂存自己改的具体文件，不用 `git add .`。
- 里程碑完成后推送当前版本分支，并核对远程 SHA 与本地 HEAD 一致。不 force push，不 `--no-verify`。
- `builds/`、`tools/`、`.godot/` 已被忽略，推送分支不等于上传了可执行包。

## 6. 交出

1. 复制 `HANDOFF_TEMPLATE.md` 的正文，存为 `docs/collaboration/handoffs/<日期>-<任务ID>-<负责人>.md` 并逐项填写。没跑的类别写“未执行”，不写“通过”。
2. 在 `WORK_LOG.md` 的“双方后续提交登记”表追加一行。
3. 实现变了就更新 `PROJECT_STATE.md` 的对应行（参数、文件职责、证据范围）。用户做出新的设计决定时，记进 `DESIGN_DECISIONS.md`。
4. 在 `TASK_BOARD.md` 释放文件占用，更新任务状态；新发现的问题登记为新任务。
5. 把这些文档和代码一起提交、推送，再核对远程 SHA。
6. 回复用户时说明：改了什么、为什么改、验证证据和范围、剩余问题、建议对方下一步做什么。

## 7. 审查对方

- 先只读：看实际 diff 和日志，不只看交接文字。能复验就复验，不能就写明原因。
- 发现问题时，写明严重程度、文件和行号、触发条件、预期与实际表现、证据。区分已复现、静态可证、设计未定义和未验证风险。
- 小问题直接在同一版本分支修，并按本流程认领和交接；涉及对方仍占用的文件，先协调。
- 不改写对方的历史审查报告来掩盖失败，在新记录里追加结论。

## 常见陷阱

- 把“代码写好了”写成“发布已验证”，或把自动点按写成真人手感认可。
- 只看交接摘要，不核对 HEAD 和工作区，就开始改。
- 为了一个小改动另开分支，或把结构重构混进普通调参 commit。
- 在 `builds/v04-source-verification/` 等验包副本里开发。
- 预填对方尚未完成的成果或接收回执。
