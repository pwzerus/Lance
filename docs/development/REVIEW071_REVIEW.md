# REVIEW-071 七项动态复验完成（2026-11-09）

接手855195e6b5b1cca5b386c23d7a098c2cd61ffd60 / codex/v0.4，源码v0.4.28。仅存在历史自动rules_v045_results差异，继续保留。读取REVIEW-070交接与现状后续验，未恢复旧源码。

## 内存保护

用户本轮明确要求给系统留1 GiB RAM。根目录Start-MemoryBound.ps1将启动预算和运行停止条件统一引用systemReserveMiB=1024。普通游戏启动需2304MiB可用RAM（系统1024+游戏1024+启动256）；几何诊断需1536MiB，512MiB诊断需1792MiB。

游戏1GiB Job硬限、900MiB提前停止、512MiB可用commit运行底线、单实例、25%CPU、Job关闭杀进程、有限QA超时和独立桌面限制均保留。系统其他软件仍会改变内存余量，1GiB保留线不能保证所有系统卡死都不会发生。没有主动耗尽内存去测试边界。

根目录Play-Latest.cmd使用此保护器。原发布目录内附的历史保护器不改写；通过旧包自身Play-Safe启动仍使用其旧设置。所有旧EXE/PCK未修改，.28 PCK仍为D468711A87DF0D7B9D9836A0791FD42F6D2E3DE1C336F4A49156695BAAB9DBC7。

## 实际复验

统一命令形式：Start-MemoryBound.ps1 -Executable tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe -GeometryDiagnostics -TimeoutSeconds 90；引擎参数--headless --path E:/GALUMU/game --script res://tests/对应脚本 --log-file 独立日志 -- --test-profile 加独立报告路径。七项串行，全部真实启动引擎。

| 脚本 | 实际结果 | 保护器墙钟 |
| --- | --- | --- |
| test_parse065 | PARSE065_RESULT failed=0 | 6.3s |
| test_equip066_rules | passed=true，failures=[] | 0.6s |
| test_arm068 | passed=true，failures=[] | 0.5s |
| test_horse_condition065 | passed=true，failures=[] | 33.8s |
| test_ai_v044 | AI_V044 passed=true，failures=[] | 0.6s |
| test_motion_regression061 | passed=true，failures=[] | 1.1s |
| test_rider_legs064 | passed=true，failures=[] | 1.6s |

每项进程退出码0；证据在docs/development/logs/receive071-*，JSON与逐项内存记录入库。短于一秒的运行未必取得内存样本，不能推断其峰值为0。已取得的一秒采样最高私有提交138.4MiB；无预算早停/超时，没有脚本错误。枪横扫0.7833s、疲劳时1.2417s，休息后臂力88.03；曲线连接速度差探针0.7935，头骨长度误差0.00003052，固定主网格2173顶点。

## 结论与范围

REVIEW-070的七项待验现已完成，本轮未发现需要修复的游戏代码问题。八份Claude交接补充真实复验结果，更新现状与开发日志。

本轮为当前源码的无界面引擎检查；未做可选渲染、OS鼠标输入或真人试玩，不将其称为正式发布包的完整验收。罩袍纹章、门槛17/臂力/疲劳的真人体验、重甲镜像组数据仍未完成。旧失败和内存预算拒绝证据不删除。
