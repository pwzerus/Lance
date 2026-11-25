# PHYS-115 复验入口

## 当前 c3 复验

当前预览入口为 `Play-Physics-Preview.cmd`，使用独立 c3 保护外层；稳定入口仍为 c5。运行源码4ea911c，具体SHA/包散列见C3_DELIVERY。以下命令逐项串行执行，使用全新名称，保留所有保护；有GPU的检查仍在隔离桌面，不接管用户屏幕。

```powershell
$bundle='E:/GALUMU/builds/LanceAndLaurel-v0.5.0-c3'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
& ./launcher/Verify-Package.ps1 -Directory $bundle
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-version" -Script test_bundle115.gd -Target bundle -Bundle $bundle -Budget normal -Extra '--expected-version=0.5.0-c3'
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-physical" -Script test_physical_fuzz115.gd -Target bundle -Bundle $bundle -Budget normal -TimeoutSeconds 600
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-floor" -Script test_floor115.gd -Target bundle -Bundle $bundle -Budget gpu -Extra '--count=4 --gear=240 --resize' -TimeoutSeconds 600
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-profile" -Script profile_result099.gd -Target bundle -Bundle $bundle -Budget gpu -Extra '--seconds=120 --mode=war --kit=heavy --trace099' -TimeoutSeconds 300
```

修改身体求解后，还要完整运行原 `test_body114.gd`、`test_fall098.gd`、`test_fall_fuzz105.gd`、`test_shield105.gd`、`test_skinfloor115.gd` 和控制/滑落。原72当前预期两项四秒失败，原128当前预期41/44/79/115四项失败；不修改门槛。`test_extreme115.gd --input=E:/GALUMU/docs/development/PHYS115_C3_EDGE_FIXTURES.json --ids=41,44,79,115,1002,1003 --iterations=10 --seconds=8` 仅延长重建诊断，不是原完整矩阵替代；41号重建非位级相同。松脱枪杆在该诊断没有同步世界推进，不能据它评价枪杆落地。

优先关注：手/盾实际接触怎样传递至肩肘、紧凑躺姿的可读性、双跑道人体在画面中的叠层、ended阶段CPU耗时。保持24张头盔、原靴网格和采样点、120Hz以及全部内存/CPU/系统余量/单实例保护。原旧外层工具把已知隔离着色器缓存目录警告标为失败，应保留并单独审查，不改原回执为通过。

以下仅为旧 c2/c1 的复验记录，不能混入 c3 验收。

---


## 当前 c2 与最短复现路径

采用 `0.5.0-c2`，运行源码 `2894eb14a678766c463f95580688f436d580ae47`。`Play-Physics-Preview.cmd` 调用保护外层程序，`Play-Latest.cmd` 仍为稳定 c5。只在新 evidence 目录运行；以下每项单独串行执行。未通过的原四秒门必须保留，不因工具返回失败而改阈值。

```powershell
$bundle='E:/GALUMU/builds/LanceAndLaurel-v0.5.0-c2'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
& ./launcher/Verify-Package.ps1 -Directory $bundle
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-version" -Script test_bundle115.gd -Target bundle -Bundle $bundle -Budget normal -Extra '--expected-version=0.5.0-c2'
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-physical13" -Script test_physical_fuzz115.gd -Target bundle -Bundle $bundle -Budget normal -Extra '--ids=13' -TimeoutSeconds 300
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-extreme" -Script test_extreme115.gd -Target bundle -Bundle $bundle -Budget normal -Extra '--input=E:/GALUMU/docs/development/PHYS115_C2_EDGE_FIXTURES.json --ids=29,40,60,75,90,120 --iterations=10 --seconds=8' -TimeoutSeconds 300
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-games" -Script test_games115.gd -Target bundle -Bundle $bundle -Budget gpu -Extra '--count=4 --gear=240' -TimeoutSeconds 300
& ./game/tests/run_phys115.ps1 -Name "phys115-review-$stamp-profile" -Script profile_result099.gd -Target bundle -Bundle $bundle -Budget gpu -Extra '--seconds=120 --mode=war --kit=heavy --trace099' -TimeoutSeconds 240
```

`physical13` 当前预期失败：4.2秒收势超过原4秒；位置/速度交接、支撑、悬空腿门通过。`extreme` 是延长轨迹的诊断，退出0不代表通过四秒验收；`--iterations=10` 在该诊断对应生产每半轮五次约束，不能使用默认5与生产结果混比。要看这些姿势的画面，另开新命名运行，将Budget改为gpu，并在Extra追加一个尚不存在的 `--folder=E:/GALUMU/docs/development/logs/phys115-review-<新编号>-frames`。不使用 `-FolderOutput` 替换其必需报告参数。

完整回归仍需原34身体、72落地、18盾臂、全部64真实释放、128人工姿势、6靴面及控制/滑落；不要只复跑七个失败例就宣布通过。修地面联系先比较两跑道的实际Main双落马截图与物理地面/阴影坐标，不能强行把整人下移。

c2证据：PHYS115_C2_AUDIT（22项、含失败）、C2_DELIVERY（包/ZIP/十保护检查/最后外层两场）、C2_VISUAL与C2_CAPTURES（原始实包图）、C2_EDGE_FIXTURES（六项原输入，真实13号独立再生）。完整日志留本机；Git中紧凑证据及测试入口供重现。CPU25%、1024MiB Job/900MiB提前保护、系统余量500MiB、单实例、超时与隔离QA保持。外层实际对局使用同等保护。


## 历史 c1 复验说明（仅用于旧包）

当前开发分支为 `codex/v0.5`。以实际 HEAD、工作区和最新交接为准。旧包与三份历史差异不得覆盖。

## 保护与证据

全部引擎运行使用 `Start-MemoryBound.ps1` 或已封装同等保护的包外层启动器。GPU 加 `-IsolatedDesktop`，使用 `-- --test-profile`；禁止抢焦点或操作真实键鼠。内存、CPU、500MiB 系统余量、单实例和超时保护均保持。

`game/tests/run_phys115.ps1` 为每次运行创建新目录，保存源码/包 SHA、外部测试脚本链、参数、内存与引擎日志及结果。名称必须唯一，不重用旧目录；多项测试串行执行。`receipt.json` 中 `guardian_exit_zero` 必须为真，GPU 的 `isolated_desktop_closed` 必须为真。测试报告失败、超时或非已分类的引擎错误均不得判通过。

## 实际候选包

```powershell
$bundle='E:/GALUMU/builds/LanceAndLaurel-v0.5.0-c1'
& ./launcher/Verify-Package.ps1 -Directory $bundle
& ./game/tests/run_phys115.ps1 -Name phys115-review-physical -Script test_physical_fuzz115.gd -Target bundle -Bundle $bundle -Budget normal -TimeoutSeconds 300
& ./game/tests/run_phys115.ps1 -Name phys115-review-games -Script test_games115.gd -Target bundle -Bundle $bundle -Budget gpu -Extra '--count=4 --gear=240' -TimeoutSeconds 300
& ./game/tests/run_phys115.ps1 -Name phys115-review-profile -Script profile_result099.gd -Target bundle -Bundle $bundle -Budget gpu -Extra '--seconds=120 --mode=war --kit=heavy --trace099' -TimeoutSeconds 180
```

`test_physical_fuzz115` 从真实骑乘状态施加命中点冲量并自然失去支撑，默认64组。它不强制落马、不扣血触发抛人。`test_games115` 使用实际 Main/Battle、AI、结算与保存；自动驾驶的胜率不等同真人难度。抓图与状态快照会影响计时，专门的 `profile_result099` 用于持续性能测量。`--trace099` 才是有效的内部追踪开关。

## 关节、画面和正常流程

| 测试 | 运行方式 | 核对内容 |
| --- | --- | --- |
| test_ankle115.gd | normal | 双向足部图形/接触登记与内部冲量 |
| test_damping115.gd | normal | 肩关节跨 PI 的普通/末端阻尼 |
| test_support115.gd | normal | 命中点冲量、支撑释放、位置/速度所有权交接 |
| test_rules115.gd | normal | 装备、伤情、物理离鞍及命中原因 |
| test_clock115.gd | normal | 固定游戏时钟与渲染步长 |
| test_irons115.gd | normal | 马镫固定在鞍具，催马不产生无击离鞍 |
| test_body114.gd / test_fall098.gd / test_shield105.gd | normal | 原身体、极端落地和盾臂连续性 |
| test_mounted_contact105.gd / test_slump113.gd | gpu | 骑乘受击、头盔/颈部、昏厥滑落；不能以 headless 运行 |
| test_skinfloor115.gd | normal 加 -FolderOutput | 独立读取贴图透明度边缘、实际三角网格变形与落地间隙 |
| test_frontdoor110.gd / test_flow082.gd | gpu | 新手入口、取消、练习、设置、暂停与返回 |
| test_journey115.gd | gpu | 正常奖励、购买和关卡成长；需要独立持久 QA 目录 |

成长示例：在 `-Extra` 中传 `--profile=E:/GALUMU/docs/development/logs/phys115-review-earned-qa_journey --first=1 --last=5 --attempts=3`。源码运行还要加 `--source-workspace`；发布包版本必须以 `0.5.0-` 开头。自然失利保留，不能给测试存档赠送金币或解锁来伪造通过。

## 已保留的失败

`test_fall_fuzz105.gd` 是旧的128组人工捕获姿势，区别于实际骑乘释放。155版本剩余10/75四秒收势、105/110躯干离地间隙失败；输入与结果摘要在 `PHYS115_EDGE_FIXTURES.json`。不修改原四秒/14px门槛。单向限位阻尼候选157/158导致更多失败，已否决；不要将候选结果归入交付代码。

全部失败、脚本参数错误、权限告警与修复记录在 `PHYS115_REVIEW.md`。引擎注入、后台画面、规则模拟、OS输入和真人试玩分别记录。没有真人动作、声音听感、第二台电脑或商店认证的通过结论。

最终采用c1源码bdcc2f4；165–172新增网格接地候选已否决，不能复用其通过结果作为c1证据。test_skinfloor115在c1仍有4/6例未过0.03px门，最大1.619px；失败必须保留。Play-Physics-Preview启动开发候选，Play-Latest继续稳定c5。
