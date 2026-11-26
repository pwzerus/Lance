# PHYS-116 复验指南

本轮基于 codex/v0.5 的 bb0369741efb5d3c4bc22658a41463516d813b7f，保留 Claude 基线和未归属本轮的三个差异。所有引擎运行必须经 Start-MemoryBound，使用 --test-profile；实际画面加 -IsolatedDesktop。不要启动前台窗口或替用户关闭其他应用。

## 核心回归

统一入口：game/tests/run_phys115.ps1；每次 Name 必须是新的 phys115-* 名称，避免覆盖证据。一时只允许一个引擎实例。gpu 表示隔离桌面，只有捕获并检查 PNG 才可称画面验证。

- test_tail116.gd：默认原六例；扩展 --ids=41,44,79,115,1002,1003,1004,1005,101,52,0。1004 是0.85/flank、1005是1.0/head，朝向+1、lean1/guard0。原始构造直接重建，不用 JSON 回读作为输入。
- test_physical_fuzz115.gd --count=64：实际骑乘身体与冲量；检查同一身体/速度连续转移、四秒收势和真正足底支撑。
- test_fall_fuzz105.gd --count=128 -ReportOnly：人工极端捕获，不是玩家胜率或自然度评分。
- test_body114.gd、test_fall098.gd、test_shield105.gd：34身体、72盾尺度/姿态和18盾臂边界。
- test_energy115.gd、test_dissipation116.gd：单关节及整个内部阻尼的能量、动量、位置不变量。
- test_damping115.gd：等价肩角与跨PI连续性。旧2.6/24固定阻尼率已被按刚度和等效质量的耗能替换，旧失败日志仍保留。
- test_clock115.gd、test_controls098.gd、test_contact116.gd：步长、控制及姿势快照独立所有权。
- test_skinfloor115.gd：实际素材网格几何检查，脚本不输出PNG，不可称画面检查；test_slump113.gd、test_mounted_contact105.gd：实际GPU捕获并查看PNG。
- test_floor115.gd --count=4 --resize：实际主场景、对局/结算/重开以及四种窗口比例；不是OS键鼠或真人试玩。

## 性能与等价性

- test_perf116.gd：胸甲旧12次绘制与单次三角阵列的64幅逐像素对照。
- test_bootperf116.gd：--reference 指向从基线提取的 rider_rig115.gd，--candidate 指向当前文件；2048组姿势/98304点。不在共享工作区切换旧版本。
- test_bounds116.gd：147840个轮廓点，旧逐点旋转与统一旋转基的纵坐标比较。
- test_play087.gd --seconds=120 --mode=war --kit=heavy：实际重甲连续对局。需保留各阶段帧时，不能用局部计算节约或平均FPS冒充稳定60FPS。
- profile_result099.gd 同参数加 --trace099 仅用于定位，需明确跟踪开销。

## 发布

保持 Godot 4.5.1、120Hz和所有保护，不覆盖旧 builds。运行源码提交后再导出独立版本，完成保护外层、许可证、清单、ZIP和中文路径检查。使用 test_bundle115.gd 检查真正PCK，随后运行实际发布包对局。Play-Latest.cmd继续指向稳定c5；仅在新包复验后更新 Play-Physics-Preview.cmd。

本轮没有真实鼠标键盘操作、用户桌面接管或真人试听。完整动作自然度及稳定60FPS必须依最终交接中的实测结果判断，不能把此清单当作全部通过。
